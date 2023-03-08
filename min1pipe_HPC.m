function [file_name_to_save, filename_raw, filename_reg] = min1pipe_HPC(Fsi, Fsi_new, spatialr, se, ismc, flag, path_name, file_name)
% main_processing
%   need to decide whether to use parallel computing
%   Fsi: raw sampling rate
%   Fsi_new: in use sampling rate
%   spatialr: spatial downsampling factor
%   Jinghao Lu 06/10/2016

    %% configure paths %%
    min1pipe_init;
    
    %% initialize parameters %%
    defpar = default_parameters;
    aflag = false;
    if nargin < 1 || isempty(Fsi)
        Fsi = defpar.Fsi;
    end
    
    if nargin < 2 || isempty(Fsi_new)
        Fsi_new = defpar.Fsi_new;
    end
    
    if nargin < 3 || isempty(spatialr)
        spatialr = defpar.spatialr;
        aflag = true;
    end
    
    if nargin < 4 || isempty(se)
        se = defpar.neuron_size;
        aflag = true;
    end
    
    if nargin < 5 || isempty(ismc)
        ismc = true;
    end
    
    if nargin < 6 || isempty(flag)
        flag = 1;
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%% parameters %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% user defined parameters %%%                                     %%%
    Params.Fsi = Fsi;                                                   %%%
    Params.Fsi_new = Fsi_new;                                           %%%
    Params.spatialr = spatialr;                                         %%%
    Params.neuron_size = se; %%% half neuron size; 9 for Inscopix and 5 %%%
                            %%% for UCLA, with 0.5 spatialr separately  %%%
                                                                        %%%
    %%% fixed parameters (change not recommanded) %%%                   %%%
    Params.anidenoise_iter = 4;                   %%% denoise iteration %%%
    Params.anidenoise_dt = 1/7;                   %%% denoise step size %%%
    Params.anidenoise_kappa = 0.5;       %%% denoise gradient threshold %%%
    Params.anidenoise_opt = 1;                %%% denoise kernel choice %%%
    Params.anidenoise_ispara = 1;             %%% if parallel (denoise) %%%   
    Params.bg_remove_ispara = 1;    %%% if parallel (backgrond removal) %%%
    Params.mc_scl = 0.004;      %%% movement correction threshold scale %%%
    Params.mc_sigma_x = 5;  %%% movement correction spatial uncertainty %%%
    Params.mc_sigma_f = 10;    %%% movement correction fluid reg weight %%%
    Params.mc_sigma_d = 1; %%% movement correction diffusion reg weight %%%
    Params.pix_select_sigthres = 0.8;     %%% seeds select signal level %%%
    Params.pix_select_corrthres = 0.6; %%% merge correlation threshold1 %%%
    Params.refine_roi_ispara = 1;          %%% if parallel (refine roi) %%%
    Params.merge_roi_corrthres = 0.9;  %%% merge correlation threshold2 %%% 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %% get dataset info %%
    [path_name, file_base, file_fmt] = data_info_HPC(file_name, path_name);
    
    hpipe = tic;
    for i = 1: length(file_base)       
        %%% judge whether do the processing %%%
        filecur = [path_name, file_base{i}, '_data_processed.mat'];
        msg = 'Redo the analysis? (y/n)';
        overwrite_flag = judge_file(filecur, msg);
        
        if overwrite_flag
            %% data cat %%
            Fsi = Params.Fsi;
            Fsi_new = Params.Fsi_new;
            spatialr = 1;
            [m, filename_raw, imaxn, imeanf, pixh, pixw, nf, imx1, imn1] = data_cat(path_name, file_base{i}, file_fmt{i}, Fsi, Fsi_new, spatialr);
            
            %%% remove dead pixels %%%
            [m, imaxn] = remove_dp(m, 'frame_allt');
            
            %%% spatial downsampling after auto-detection %%%
            [m, Params, pixh, pixw] = downsamp(path_name, file_base{i}, m, Params, aflag, imaxn);
            
            %% neural enhancing batch version %%
            filename_reg = [path_name, file_base{i}, '_reg.mat'];
            [m, imaxy1, overwrite_flag, imx2, imn2, ibmean] = neural_enhance(m, filename_reg, Params);
            
            %% neural enhancing postprocess %%
            if overwrite_flag
                nflag = 1;
                m = noise_suppress(m, imaxy1, Fsi_new, nflag);
            end
            
            %% movement correction %%
            if ismc
                if overwrite_flag
                    pixs = min(pixh, pixw);
                    Params.mc_pixs = pixs;
                    Fsi_new = Params.Fsi_new;
                    scl = Params.neuron_size / (7 * pixs);
                    sigma_x = Params.mc_sigma_x;
                    sigma_f = Params.mc_sigma_f;
                    sigma_d = Params.mc_sigma_d;
                    se = Params.neuron_size;
                    [m, corr_score, raw_score, scl, imaxy] = frame_reg(m, imaxy1, se, Fsi_new, pixs, scl, sigma_x, sigma_f, sigma_d);
                    Params.mc_scl = scl; %%% update latest scl %%%
                    
%                     file_name_to_save = [path_name, file_base{i}, '_data_processed.mat'];
%                     if exist(file_name_to_save, 'file')
%                         delete(file_name_to_save)
%                     end
                    save(m.Properties.Source, 'corr_score', 'raw_score', 'imaxy',  '-v7.3', '-append');
                else
                    imaxy = m.imaxy;
                end
            else
                if overwrite_flag
                    m = frame_stab(m); %%% spatiotemporal stabilization %%%
                end
                imaxy = imaxy1;
            end
            
            %% movement correction postprocess %%
            %%% --------- 3rd section ---------- %%%
            nflag = 2;
            filename_reg_post = [path_name, file_base{i}, '_reg_post.mat'];
            m = noise_suppress(m, imaxy, Fsi_new, nflag, filename_reg_post);
            
            %% get rough roi domain %%
            mask = dominant_patch(imaxy);
            
            %% parameter init %%
            [P, options] = par_init(m);
            
            %% select pixel %%
            [sigrf, roirf, seedsupdt, bgrf, bgfrf, datasmthf1, cutofff1, pkcutofff1] = iter_seeds_select(m, mask, Params, P, options, flag);
            
            %% merge roi %%
            corrthres = Params.merge_roi_corrthres;
            [roimrg, sigmrg, seedsmrg, datasmthf2, cutofff2, pkcutofff2] = merge_roi(m, roirf, sigrf, seedsupdt, imaxy, datasmthf1, cutofff1, pkcutofff1, corrthres);
    
%             %% 2nd step clean seeds %%
%             sz = Params.neuron_size;
%             [roic, sigc, seedsc, datasmthc, cutoffc, pkcutoffc] = final_seeds_select(m, roimrg, sigmrg, seedsmrg, datasmthf2, cutofff2, pkcutofff2, sz, imax);
            
            %% refine roi again %%
            noise = P.sn;
            Puse.p = 0;
            Puse.options = options;
            Puse.noise = noise;
            ispara = Params.refine_roi_ispara;
            [roifn1, sigfn1, seedsfn1, datasmthfn1, cutofffn1, pkcutofffn1] = refine_roi(m, sigmrg, bgfrf, roimrg, seedsmrg, Puse.noise, datasmthf2, cutofff2, pkcutofff2, ispara);
            [bgfn, bgffn] = bg_update(m, roifn1, sigfn1);
                         
            %% refine sig again %%
            Puse.p = 2; %%% 2nd ar model used %%%
            Puse.options.p = 2;
            Puse.options.temporal_iter = 1;
            [sigfn1, bgffn, roifn1, seedsfn1, datasmthfn1, cutofffn1, pkcutofffn1] = refine_sig(m, roifn1, bgfn, sigfn1, bgffn, seedsfn1, datasmthfn1, cutofffn1, pkcutofffn1, Puse.p, Puse.options);
                        
            %% final clean seeds %%
            sz = Params.neuron_size;
            [roifn, sigfn, seedsfn, datasmthfn, cutofffn, pkcutofffn] = final_seeds_select(m, roifn1, sigfn1, seedsfn1, datasmthfn1, cutofffn1, pkcutofffn1, sz, imaxy);

            %% final trace clean %%
            tflag = 2;
            sigfn = trace_clean(sigfn, Fsi_new, tflag);
                        
            %% final refine sig %%
            [sigfn, spkfn] = pure_refine_sig(sigfn, Puse.options);
            
            %% final clean outputs %%
            sigfn = max(roifn, [], 1)' .* sigfn;
            roifn = roifn ./ max(roifn, [], 1);
%             dff = compute_dff(sigfn, bgfn, bgffn, seedsfn);

            %%% estimate df/f %%%
            imcur = normalize(imaxy1);
            imref = normalize(imaxy);
            [img, sx, sy] = logdemons_unit(imref, imcur);
            for ii = 1: length(sx)
                ibmean = iminterpolate(ibmean, sx{ii}, sy{ii});
            end
            
            x = (imx1 - imn1) * (imx2 - imn2) + imn1;
            roifnt = roifn;
            roifnt = roifnt ./ sum(roifnt, 1);
            bguse1 = ibmean(:)' * roifnt;
            bguse2 = min(sigfn, [], 2) * x;
            bguse = bguse1(:) * (imx1 - imn1) + bguse2(:);
            dff = double(full((sigfn - min(sigfn, [], 2)) * x ./ bguse));
            
            %% save data %%
            stype = parse_type(class(m.reg(1, 1, 1)));
            nsize = pixh * pixw * nf * stype; %%% size of single %%%
            nbatch = batch_compute(nsize);
            ebatch = ceil(nf / nbatch);
            idbatch = [1: ebatch: nf, nf + 1];
            nbatch = length(idbatch) - 1;
            imax = zeros(pixh, pixw);
            for j = 1: nbatch
                tmp = m.reg(1: pixh, 1: pixw, idbatch(j): idbatch(j + 1) - 1);
                imax = max(cat(3, max(tmp, [], 3), imax), [], 3);
            end
            
            file_name_to_save = [path_name, file_base{i}, '_data_processed.mat'];
            if exist(file_name_to_save, 'file')
%                 if ismc
%                     load(file_name_to_save, 'raw_score', 'corr_score')
%                 end
                delete(file_name_to_save)
            end
            
            if ismc
                load(m.Properties.Source, 'raw_score', 'corr_score')
                save(file_name_to_save, 'roifn', 'sigfn', 'dff', 'seedsfn', 'spkfn', 'bgfn', 'bgffn', 'imax', 'pixh', 'pixw', 'corr_score', 'raw_score', 'Params', '-v7.3');
            else
                save(file_name_to_save, 'roifn', 'sigfn', 'dff', 'seedsfn', 'spkfn', 'bgfn', 'bgffn', 'imax', 'pixh', 'pixw', 'Params', '-v7.3');
            end
            
            save(file_name_to_save, 'imaxn', 'imaxy', '-append');
            time1 = toc(hpipe);
            disp(['Done all, total time: ', num2str(time1), ' seconds'])
        else
            filename_raw = [path_name, file_base{i}, '_frame_all.mat'];
            filename_reg = [path_name, file_base{i}, '_reg.mat'];
            file_name_to_save = filecur;
            
            time1 = toc(hpipe);
            disp(['Done all, total time: ', num2str(time1), ' seconds'])
        end
    end
end

function min1pipe_init
% parse path, and install cvx if not
%   Jinghao Lu, 11/10/2017

    %%% prepare main folder %%%
    pathname = mfilename('fullpath');
    mns = mfilename;
    lname = length(mns);
    pathtop1 = pathname(1: end - lname);
    
    %%% check if on path %%%
    pathCell = regexp(path, pathsep, 'split');
    if ispc  % Windows is not case-sensitive
        onPath = any(strcmpi(pathtop1(1: end - 1), pathCell)); %%% get rid of filesep %%%
    else
        onPath = any(strcmp(pathtop1(1: end - 1), pathCell));
    end
    
    %%% set path and setup cvx if not on path %%%
    if ~onPath
        pathall = genpath(pathtop1);
        addpath(pathall)
        cvx_dir = [pathtop1, 'utilities'];
        if ~exist([cvx_dir, filesep, 'cvx'], 'dir')
            if ispc
                cvxl = 'http://web.cvxr.com/cvx/cvx-w64.zip';
            elseif isunix
                cvxl = 'http://web.cvxr.com/cvx/cvx-a64.zip';
            elseif ismac
                cvxl = 'http://web.cvxr.com/cvx/cvx-maci64.zip';
            end
            disp('Downloading CVX');
            unzip(cvxl, cvx_dir);
        end
        pathcvx = [cvx_dir, filesep, 'cvx', filesep, 'cvx_setup.m'];
        run(pathcvx)
    end
end






