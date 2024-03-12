function [m_out, Params, pixh, pixw] = downsamp(path_name, file_base, m_in, Params, aflag, imaxn, overwrite_flag)
    filename = fullfile(path_name, [file_base, '_frame_all.mat']);
    
    if nargin < 7
        overwrite_flag = [];
    end
    
    if isempty(overwrite_flag)
        msg = 'Overwrite downsampled .mat file (data)? (y/n)';
        overwrite_flag = judge_file(filename, msg);
    end

    if overwrite_flag
        if exist(filename, 'file')
            delete(filename);
        end
        if aflag
            [se, spatialr] = auto_detect_params(imaxn);
            Params.neuron_size = se;
            Params.spatialr = spatialr;
            [m_out, pixh, pixw] = downsamp_unit(m_in, spatialr);
        else
            [m_out, pixh, pixw] = downsamp_unit(m_in, Params.spatialr);
        end
    else
        m_out = matfile(filename, 'Writable', true);
        [pixh, pixw, ~] = size(m_out, 'frame_all');
    end
end
