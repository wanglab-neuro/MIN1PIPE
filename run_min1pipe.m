function run_min1pipe(filePath, overwrite)

% Example usage:
% run_min1pipe('./demo/demo_data.tif')

% on the HPC, you can run this function with the following command:
% sbatch --mem=16G --time=1:00:00 --wrap="matlab -nodisplay -r 'run_min1pipe('./demo/demo_data.tif'); exit;'"
% If parpool doesn't work on the HPC, rename the .matlab directory to get a clean environment:
% cd ~
% mv .matlab .matlab.bak

if nargin < 2
    overwrite = false;
end

%  if mp_pathdef exists, run it to set the MATLAB path
if exist('mp_pathdef.m', 'file')
    path(pathdef, path); 
    run('mp_pathdef.m');
end

%% session-specific parameter initialization %%
Fsi = 20;
Fsi_new = 20; %%% no temporal downsampling if set to the same value as Fsi %%%
spatialr = 1; %%% no spatial downsampling %%% If commented, will be set to default, which is 0.5. If data is already downsampled, set to 1. 
% se = 5; %%% structure element for background removal %%% If commented, will be set to default, which is 5. This is supposed to be the setting for the UCLA miniscope, but works for the Inscopix miniscope as well with the 1mm lens. Set 7 for the 600 um lens (~depending on brain region too - this needs to be measured).
ismc = true; %%% run movement correction %%%
flag = 1; %%% use auto seeds selection; 2 if manual %%%
% isvis = true; %%% do visualize %%%
ifpost = false; %%% set true if want to see post-process %%%

% Display the parameters and the file path
disp('Running MIN1PIPE using parameters:')
fprintf('Fsi: %d\n', Fsi);
fprintf('Fsi_new: %d\n', Fsi_new);
fprintf('ismc: %d\n', ismc);
fprintf('flag: %d\n', flag);
fprintf('ifpost: %d\n', ifpost);
fprintf('filePath: %s\n', filePath);

%% main program %%
[path_name, file_name, file_format] = fileparts(filePath);
[fname, frawname, fregname] = min1pipe_HPC(Fsi, Fsi_new, spatialr, [], ismc, flag, path_name, [file_name file_format], overwrite);

if ifpost
    load(fname)
    figure(1)
    clf
    %%% raw max %%%
    subplot(2, 3, 1, 'align')
    imagesc(imaxn)
    axis square
    title('Raw')
    
    %%% neural enhanced before movement correction %%%
    subplot(2, 3, 2, 'align')
    imagesc(imaxy)
    axis square
    title('Before MC')
    
    %%% neural enhanced after movement correction %%%
    subplot(2, 3, 3, 'align')
    imagesc(imax)
    axis square
    title('After MC')
    
    %%% contour %%%
    subplot(2, 3, 4, 'align')
    plot_contour(roifn, sigfn, seedsfn, imax, pixh, pixw)
    axis square
    
    %%% movement measurement %%%
    subplot(2, 3, 5, 'align')
    axis off
    if ismc
        plot(raw_score); hold on; plot(corr_score); hold off;
        axis square
        title('MC Scores')
    else
        title('MC skipped')
    end
    
    %%% all identified traces %%%
    subplot(2, 3, 6, 'align')
    sigt = sigfn;
    for i = 1: size(sigt, 1)
        sigt(i, :) = normalize_intensity(sigt(i, :));
    end
    plot((sigt + (1: size(sigt, 1))')')
    axis tight
    axis square
    title('Traces')
    
    %% make a movie %%
    load(fname)
    mraw = matfile(frawname);
    mreg = matfile(fregname);
    id = find(fname == filesep, 1, 'last');
    fmovie = [fname(1: id), 'demo_vid.avi'];
    v = VideoWriter(fmovie);
    v.FrameRate = Fsi_new;
    v.Quality = 100;
    open(v)
    
    %%% compute batch %%%
    ttype = class(mraw.frame_all(1, 1, 1));
    stype = parse_type(ttype);
    dss = 2;
    dst = 2;
    nf = size(sigfn, 2);
    nsize = pixh * pixw * nf * stype * 6 / (dss ^ 2); %%% size of single %%%
    nbatch = batch_compute(nsize);
    ebatch = ceil(nf / nbatch);
    idbatch = [1: ebatch: nf, nf + 1];
    nbatch = length(idbatch) - 1;
    
    %%% make movie %%%
    figure(2)
    set(gcf, 'Units', 'normalized', 'position', [0.5, 0.1, 0.4, 0.2])
    for ii = 1: nbatch
        dataraw = mraw.frame_all(1: dss: pixh, 1: dss: pixw, idbatch(ii): idbatch(ii + 1) - 1);
        datareg = mreg.reg(1: dss: pixh, 1: dss: pixw, idbatch(ii): idbatch(ii + 1) - 1);
        datar = reshape(roifn * sigfn(:, idbatch(ii): idbatch(ii + 1) - 1), pixh, pixw, []);
        datar = datar(1: dss: end, 1: dss: end, :);
        for i = 1: dst: size(dataraw, 3)
            clf
            subplot(1, 3, 1, 'align')
            imagesc(dataraw(:, :, i + idbatch(ii) - 1), [0, 1])
            axis off
            axis square
            title('Raw')
            
            subplot(1, 3, 2, 'align')
            imagesc(datareg(:, :, i + idbatch(ii) - 1), [0, 1])
            axis off
            axis square
            title('After MC')
            
            subplot(1, 3, 3, 'align')
            imagesc(datar(:, :, i + idbatch(ii) - 1), [0, 1])
            axis off
            axis square
            title('Processed')
            
            suptitle(['Frame #', num2str(i)])
            
            movtmp = getframe(gcf);
            writeVideo(v, movtmp);
        end
    end
    close(v)
    
end

%% post-process %%
if ifpost
    real_neuron_select
end