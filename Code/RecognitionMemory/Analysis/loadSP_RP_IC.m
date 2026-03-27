function [SP, rp, ic] = loadSP_RP_IC(file)
    Sraw = load(file,'-mat');
    if isfield(Sraw,'data'), D = Sraw.data; else, D = Sraw; end
    SP = D.stimulusPresented; rp = D.repeatPosition; ic = D.isResponseCorrect;
    
    % Strip directory paths (MATLAB 2018 safe)
    SP = cellfun(@(x) x(max(strfind(x, filesep)) + 1:end), SP, 'UniformOutput', false);

    % Ensure they?re char arrays, not strings
    SP = cellfun(@char, SP, 'UniformOutput', false);
    
end
