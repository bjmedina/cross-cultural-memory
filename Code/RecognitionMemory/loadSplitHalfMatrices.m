function [hits, fas, allItems, files] = loadSplitHalfMatrices(baseDir, placeCodes, condition, minISI0dprime)
% loadSplitHalfMatrices
%   Loads and constructs hits and false alarm matrices for split-half analysis.
%
%   Inputs:
%     baseDir         - path to .mat files
%     placeCodes      - cell array of site codes, e.g. {'ALL'} or {'NYC','BOS'}
%     condition       - substring to match in filenames (e.g. 'Globalized-Music')
%     minISI0dprime   - threshold to filter participants by ISI=0 sensitivity
%
%   Outputs:
%     hits      - [nParticipants x nItems] matrix, 1=correct on ISI>0 repeat
%     fas       - [nParticipants x nItems] matrix, 1=correct on lure (non-repeat)
%     allItems  - list of item IDs used as columns
%     files     - list of participant file paths

    files = getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime);
    if isempty(files)
        warning('No participants passed your filters. Returning empty.');
        hits = []; fas = []; allItems = string([]);
        return
    end

    allItems = string([]);
    nSub     = numel(files);

    % First pass: gather unique ISI>0 repeat stimuli
    for i = 1:nSub
        S = load(files{i}, 'stimulusPresented','repeatPosition');
        stims = string(S.stimulusPresented);
        rp    = S.repeatPosition;
        valid = ~isnan(rp) & rp > 1; % ISI>0 repeats only
        allItems = union(allItems, unique(stims(valid)));
    end

    if isempty(allItems)
        warning('No usable items found across participants.');
        hits = []; fas = [];
        return
    end

    % Allocate participant × item matrices
    nItems = numel(allItems);
    hits   = nan(nSub, nItems);
    fas    = nan(nSub, nItems);

    % Second pass: fill matrices with binary responses
    for i = 1:nSub
        S     = load(files{i}, 'stimulusPresented','repeatPosition','isResponseCorrect');
        stims = string(S.stimulusPresented);
        rp    = S.repeatPosition;
        corr  = S.isResponseCorrect;

        for t = 1:numel(stims)
            stim = stims(t);
            idx = find(allItems == stim, 1);

            if isempty(idx), continue; end

            % Hit: ISI>0 repeat trial
            if ~isnan(rp(t)) && rp(t) > 1
                hits(i, idx) = corr(t);

            % FA: non-repeat trial
            elseif isnan(rp(t))
                fas(i, idx) = corr(t);
            end
        end
    end
end