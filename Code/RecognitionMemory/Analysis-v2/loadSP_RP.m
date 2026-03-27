% function [SP, rp] = loadSP_RP(file)
%     Sraw = load(file,'-mat');
%     if isfield(Sraw,'data'), D = Sraw.data; else, D = Sraw; end
%     SP = D.stimulusPresented; rp = D.repeatPosition;
% end
function [SP, rp] = loadSP_RP(file)
    % loadSP_RP  Load stimulusPresented and repeatPosition, stripping paths.
    % MATLAB 2018 compatible ? keeps filenames as char arrays.
    %
    % Returns:
    %   SP - cell array of char filenames (no paths)
    %   rp - repeat positions

    Sraw = load(file, '-mat');
    if isfield(Sraw, 'data')
        D = Sraw.data;
    else
        D = Sraw;
    end

    SP = D.stimulusPresented;
    rp = D.repeatPosition;

    % Strip directory paths (MATLAB 2018 safe)
    SP = cellfun(@(x) x(max(strfind(x, filesep)) + 1:end), SP, 'UniformOutput', false);

    % Ensure they?re char arrays, not strings
    SP = cellfun(@char, SP, 'UniformOutput', false);
end