function norm_frame = normalize_intensity(frame_in, dim)
% norm_frame = normalize intensity to [0, 1]
%   frame_in is input frame or video
%   dim is dimension flag, optional
%   Jinghao Lu 01/16/2016

% Function name is changed from normalize to normalize_intensity to avoid conflict with built-in function normalize in MATLAB 2021b
% Vincent Prevosto 03/2024 

    if nargin < 2
        dim = 4; %%% treat the tensor as a whole %%%
    end
    if dim == 4
        mn = nanmin(nanmin(nanmin(frame_in)));
        norm_frame = frame_in - mn;
        mx = nanmax(nanmax(nanmax(norm_frame)));
        norm_frame = norm_frame / mx;
    else
        norm_frame = frame_in - repmat(nanmin(frame_in, [], dim), 1, size(frame_in, dim));
        norm_frame = norm_frame ./ (repmat(nanmax(norm_frame, [], dim), 1, size(frame_in, dim)));
    end
end