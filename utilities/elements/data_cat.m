function [m, filename, imaxf, imeanf, pixh, pixw, nf, imx1, imn1] = data_cat(path_name, file_base, file_fmt, Fsi, Fsi_new, ratio, ttype)
% Concatinate data pieces from raw 4GB-tif chunks,
%   new tiff files,
%   or avi files from UCLA miniscope
%   parallel or serial version supported
%   Jinghao Lu 01/16/2016

    hcat = tic;
    %% initialization %%
    %%% initialize parameters %%%
    if nargin < 4 || isempty(Fsi)
        defpar = default_parameters;
        Fsi = defpar.Fsi;
    end

    if nargin < 5 || isempty(Fsi_new)
        defpar = default_parameters;
        Fsi_new = defpar.Fsi_new;
    end

    if nargin < 6 || isempty(ratio)
        defpar = default_parameters;
        ratio = defpar.spatialr;
    end
    
    if nargin < 7 || isempty(ttype)
        defpar = default_parameters;
        ttype = defpar.ttype;
    end
        
    if ~contains(file_fmt, 'mat')
        filename = fullfile(path_name, [file_base, '_frame_allt.mat']);
        if exist(filename, 'file')
            overwrite_flag = false;
        else
            overwrite_flag = true;
        end
        
        if overwrite_flag
            if exist(filename, 'file')
                delete(filename);
            end

            %% initialize to get info %%
            if contains(file_fmt, 'avi')
                dirst = [dir(fullfile(path_name, [file_base, '.avi'])); dir(fullfile(path_name, [file_base, '*', '.avi']))];
            elseif contains(file_fmt, 'tiff')
                dirst = [dir(fullfile(path_name, [file_base, '.tiff'])); dir(fullfile(path_name, [file_base, '-*', '.tiff']))];
            elseif contains(file_fmt, 'tif')
                dirst = [dir(fullfile(path_name, [file_base '.tif'])); dir(fullfile(path_name, [file_base, '-*', '.tif']))];
            end
            dirs = cell(1, length(dirst));
            nft = zeros(1, length(dirst));
            idx = zeros(1, length(dirst));
            
            %% get info %%
            disp('Begin collecting datasets info')
            for i = 1: length(dirst)
                dirs{i} = dirst(i).name;
                if contains(file_fmt, 'avi')
%                     info = matlab.internal.VideoReader([path_name, dirs{i}]);
%                     ts = info.Timestamps;
%                     nft(i) = length(ts);
                    info = aviinfo([path_name, dirs{i}]);
                    nft(i) = info.NumFrames;
                    temp1 = strfind(dirs{i}, file_base);
                    temp2 = strfind(dirs{i}, '.');
                    idx(i) = str2double(dirst(i).name(temp1 + length(file_base): temp2 - 1));
                else
                    info = imfinfo(fullfile(path_name, dirs{i}));
                    nft(i) = numel(info);
                    temp1 = strfind(dirst(i).name, '-');
                    temp2 = strfind(dirs{i}, '.');
                    if isempty(temp1)
                        idx(i) = 0;
                    else
                        idx(i) = str2double(dirst(i).name(temp1 + 1: temp2 - 1));
                    end
                end
            end
            time = toc(hcat);
            disp(['Done collecting datasets info, time: ', num2str(time)])
            
            %% initialization to get frames %%
            if contains(file_fmt, 'avi')
                try
                    info = VideoReader([path_name, dirs{1}]);
                    dtype = ['uint', num2str(info.BitsPerPixel)];
                    vfmt = info.VideoFormat;
                catch
                    info = aviinfo([path_name, dirs{1}]);
                    dt = info.FileSize / (info.NumFrames * info.Width * info.Height);
                    dtype = ['uint', num2str(round(dt) * 8)];
                    vfmt = info.ImageType;
                end
                if strcmp(vfmt, 'RGB24')
                    dtype = 'uint8';
                end
            else
                info = imfinfo(fullfile(path_name, dirs{1}));
                dtype = ['uint', num2str(info(1).BitDepth)];
            end
%             pixwo = info(1,1).Width;
%             pixho = info(1,1).Height;
            pixwo = info.Width;
            pixho = info.Height;
            pixw = round(pixwo * ratio);
            pixh = round(pixho * ratio);
            ds = Fsi / Fsi_new;
            [~, induse] = sort(idx);
            dirs = dirs(induse);
            nft = nft(induse);
            nf = sum(nft);
            f_idx = zeros(1, nf);
            dir_idx = cell(1, nf);
            for i = 1: length(nft)
                f_idx(sum(nft(1: i - 1)) + 1: sum(nft(1: i))) = 1: nft(i);
                dir_idx(sum(nft(1: i - 1)) + 1: sum(nft(1: i))) = repmat(dirs(i), 1, nft(i));
            end
            f_use = 1: ds: nf;
            f_idx = f_idx(f_use);
            dir_idx = dir_idx(f_use);
            nf = length(f_use);
            cnft = unique([find(diff(f_idx) < 0), nf]);
            dir_uset = unique(dir_idx, 'stable');
            %     dir_idt = [dir_idt; nf + 1];
            
            %%% clear some variables %%%
            clear info
            
            %% batch configuration %%
            %%% parameters %%%
            stype = parse_type(ttype);
            nsize = pixh * pixw * nf * stype; %%% size of single %%%
            nbatch = batch_compute(nsize);
            ebatch = ceil(nf / nbatch);
            
            %%% extract batch-wise frame info %%%
            idbatch = [1: ebatch: nf, nf + 1];
            nbatch = length(idbatch) - 1;
            rg = sort([cnft + 1, idbatch(1: end-1)]);
            bcount = 1;
            dir_use = cell(1, nbatch);
            dir_nft = cell(1, nbatch);
            
            for i = 1: length(rg) - 1
                dirtmp = dir_idx(rg(i): rg(i + 1) - 1);
                dir_use{bcount} = [dir_use{bcount}, unique(dirtmp)];
                dir_nft{bcount} = [dir_nft{bcount}, rg(i + 1) - rg(i)];
                if idbatch(bcount + 1) == rg(i + 1)
                    bcount = bcount + 1;
                end
            end
            
            %%% clear some variables %%%
            clear dir_idx
        
            %% collect data %%
            disp('Begin data cat')
            
            %%% save data to the .mat file %%%
            imaxf = zeros(pixh, pixw);
            iminf = zeros(pixh, pixw);
            imeanf = zeros(pixh, pixw);

            rgcount = 1;
            stto = [];
            fname_useo = [];
            for ib = 1: nbatch
                frame_allt = zeros(pixh, pixw, idbatch(ib + 1) - idbatch(ib), dtype);
                if contains(file_fmt, 'avi')
                    for i = 1: length(dir_use{ib})
                        %%% prepare file %%%
                        m = memmapfile([path_name, dir_use{ib}{i}], 'format', dtype);
                        d_raw = m.Data;
                        
                        %%% get key header info %%%
                        if strcmp(dir_use{ib}{i}, fname_useo)
                            stt = stto;
                        else
                            hstep1 = 20;
                            hstep2 = 20000;
                            hstep2t = 200000;
                            headert = d_raw(1: hstep2t)';
                            h1 = strfind(headert, 'movi00db');
                            targetlist = '00db';
                            if isempty(h1)
                                h1 = strfind(headert, 'movi00dc');
                                targetlist = '00dc';
                            end
                            dlen = headert(h1 + 8: h1 + 11);
                            ndframe = double(typecast(dlen, 'uint32'));
                            stt1 = h1 + 11;
                            idt = find(strcmp(dir_uset, dir_use{ib}{i}));
                            stt = zeros(nft(idt), 1);
                            stt(1) = stt1;
                            stp = stt1 + ndframe;
                            target = [targetlist, char(dlen)];
                            for ii = 2: nft(idt)
                                headert = d_raw(stp + 1: stp + hstep1)';
                                h1 = strfind(headert, target);
                                if isempty(h1)
                                    while isempty(h1)
                                        headert = d_raw(stp + 1: stp + hstep2)';
                                        h1 = strfind(headert, target);
                                        stp = stp + hstep2;
                                    end
                                    stp = stp - hstep2;
                                end
                                stt1 = h1 + 7;
                                stt(ii) = stt1 + stp;
                                stp = stt(ii) + ndframe;
                            end
                            stto = stt;
                        end
                        fname_useo = dir_use{ib}{i};
                        
                        %%% create frames %%%
                        for ii = rg(rgcount): rg(rgcount + 1) - 1
                            frame = flipud(reshape(d_raw(stt(f_idx(ii)) + 1: stt(f_idx(ii)) + ndframe), pixwo, pixho)');
                            frame_allt(:, :, ii - idbatch(ib) + 1) = imresize(frame, [pixh, pixw]);
                            if mod(ii, 100) == 0
                                disp(num2str(ii))
                            end
                        end
                        
                        %%% update counter %%%
                        rgcount = rgcount + 1;
                    end
                elseif contains(file_fmt, 'tif') || contains(file_fmt, 'tiff')
                    for i = 1: length(dir_use{ib})
                        %%% prepare file %%%
                        info = imfinfo(fullfile(path_name, dir_use{ib}{i}));
%                         m = memmapfile([path_name, dir_use{ib}{i}], 'format', dtype);
                        m = memmapfile(fullfile(path_name, dir_use{ib}{i}), 'format', 'uint8');
                        d_raw = m.Data;
                        
                        %%% get key header info %%%
                        if strcmp(dir_use{ib}{i}, fname_useo)
                            stt = stto;
                        else
                            idt = find(strcmp(dir_uset, dir_use{ib}{i}));
                            stt = zeros(nft(idt), 1);
                            for ii = 1: nft(idt)
                                stt(ii) = info(ii).StripOffsets(1);
                            end
                            stto = stt;
                        end
                        fname_useo = dir_use{ib}{i};
                        
                        %%% create frames %%%
                        scl = info(1).BitDepth / 8;
%                         stt = stt / scl;
                        ndframe = pixho * pixwo * scl;
                        for ii = rg(rgcount): rg(rgcount + 1) - 1
                            ftmp = typecast(d_raw(stt(f_idx(ii)) + 1: stt(f_idx(ii)) + ndframe), dtype);
                            if strcmp(info(1).ByteOrder, 'big-endian')
                                ftmp = swapbytes(ftmp);
                            end
                            frame = reshape(ftmp, pixwo, pixho)';
                            frame_allt(:, :, ii - idbatch(ib) + 1) = imresize(frame, [pixh, pixw]);
                            if mod(ii, 100) == 0
                                disp(num2str(ii))
                            end
                        end
                        
                        %%% update counter %%%
                        rgcount = rgcount + 1;
                    end
                end
                
                %%% save to .mat file of the current batch %%%
                eval(['frame_allt = ', ttype, '(frame_allt);'])
                imaxf = max(cat(3, max(frame_allt, [], 3), imaxf), [], 3);
                iminf = min(cat(3, min(frame_allt, [], 3), iminf), [], 3);
                imeanf = (imeanf * (idbatch(ib) - idbatch(1)) + sum(frame_allt, 3)) / (idbatch(ib + 1) - idbatch(1));
                savef(filename, 2, 'frame_allt')
            end
            
            %%% normalize batch version %%%
            imx1 = max(imaxf(:));
            imn1 = min(iminf(:));
            m = normalize_batch(filename, 'frame_allt', imx1, imn1, idbatch);
            save(fullfile(path_name, [file_base, '_supporting.mat']), 'imx1', 'imn1')
        else %%% get outputs from the saved data file %%%
            load(fullfile(path_name, [file_base, '_supporting.mat']), 'imx1', 'imn1')
            m = matfile(filename);
            [pixh, pixw, nf] = size(m, 'frame_allt');
            imaxf = zeros(pixh, pixw);
            imeanf = zeros(pixh, pixw);
            stype = parse_type(ttype);
            nsize = pixh * pixw * nf * stype; %%% size of single %%%
            nbatch = batch_compute(nsize);
            ebatch = ceil(nf / nbatch);
            idbatch = [1: ebatch: nf, nf + 1];
            nbatch = length(idbatch) - 1;
            for i = 1: nbatch
                tmp = m.frame_allt(1: pixh, 1: pixw, idbatch(i): idbatch(i + 1) - 1);
                imaxf = max(cat(3, max(tmp, [], 3), imaxf), [], 3);
                imeanf = (imeanf * (idbatch(i) - idbatch(1)) + sum(tmp, 3)) / (idbatch(i + 1) - idbatch(1));
            end
        end
    else %%% get .mat format %%%
        %%% get file info %%%
        fname = fullfile(path_name, [file_base, '.mat']);
        mm = matfile(fname);
        vnames = who(mm);
        eval(['dtype = class(mm.', vnames{1}, '(:, :, 1));'])
        [pixh, pixw, nff] = size(mm, vnames{1}); %%% assume only one variable %%%
        tratio = Fsi / Fsi_new;
        idd = false(1, nff);
        idd(1: tratio: nff) = true;
        nf = sum(idd);
        stype = parse_type(ttype);
        nsize = pixh * pixw * nff * stype; %%% size of single %%%
        nbatch = batch_compute(nsize);
        ebatch = ceil(nff / nbatch);
        
        %%% collect batch-wise frames %%%
        idbatch = [1: ebatch: nff, nff + 1];
        disp('Begin data cat')
        filename = fullfile(path_name, [file_base, '_frame_allt.mat']);
        msg = 'Overwrite raw .mat file (data)? (y/n)';
        overwrite_flag = judge_file(filename, msg);
        
        %%% save data to the .mat file %%%
        imaxf = zeros(pixh, pixw);
        iminf = zeros(pixh, pixw);
        imeanf = zeros(pixh, pixw);
        idbatchn = ones(size(idbatch));
        if overwrite_flag
            if exist(filename, 'file')
                delete(filename);
            end
            for ib = 1: nbatch
                iddt = idd(idbatch(ib): idbatch(ib + 1) - 1);
                eval(['tmp = mm.', vnames{1}, '(1: pixh, 1: pixw, idbatch(ib): idbatch(ib + 1) - 1);'])
                frame_allt = tmp(:, :, iddt);
                eval(['frame_allt = ', ttype, '(frame_allt);'])
                imaxf = max(cat(3, max(frame_allt, [], 3), imaxf), [], 3);
                iminf = min(cat(3, min(frame_allt, [], 3), iminf), [], 3);
                imeanf = (imeanf * (idbatch(ib) - idbatch(1)) + sum(frame_allt, 3)) / (idbatch(ib + 1) - idbatch(1));
                savef(filename, 2, 'frame_allt')
                idbatchn(ib + 1) = idbatchn(ib) + sum(iddt);
            end
            
            %%% normalize %%%
            imx1 = max(imaxf(:));
            imn1 = min(iminf(:));
            idbatch = idbatchn;
            m = normalize_batch(filename, 'frame_allt', imx1, imn1, idbatch);
            save([path_name, file_base, '_supporting.mat'], 'imx1', 'imn1')
        else
            load([path_name, file_base, '_supporting.mat'], 'imx1', 'imn1')
            m = matfile(filename);
            imaxf = zeros(pixh, pixw);
            for i = 1: nbatch
                tmp = m.frame_allt(1: pixh, 1: pixw, idbatch(i): idbatch(i + 1) - 1);
                imaxf = max(cat(3, max(tmp, [], 3), imaxf), [], 3);
                imeanf = (imeanf * (idbatch(i) - idbatch(1)) + sum(tmp, 3)) / (idbatch(i + 1) - idbatch(1));
            end
        end
    end
    
    time = toc(hcat);
    disp(['Done data cat, time: ', num2str(time)])
end



