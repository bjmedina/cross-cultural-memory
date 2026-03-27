function [files_kept, files_removed, perfVals] = UTILS_getRecognitionMemFiles_top2thirds(baseDir, placeCodes, condition, minISI0dprime, isMultiISI)
% UTILS_getRecognitionMemFiles_top2thirds
%   Returns only the top two-thirds of participants (by overall performance)
%   after applying standard ISI=0 d' threshold and condition filters.
%
%   Inputs:
%     baseDir         : folder containing .mat subject files
%     placeCodes      : e.g. {'BOS'} or {'TSI'}
%     condition       : condition string to match, e.g. 'Globalized-Music'
%     minISI0dprime   : threshold on ISI=0 d'
%     isMultiISI      : logical, true for multi-ISI experiments
%
%   Outputs:
%     files_kept      : cell array of full paths for top 2/3 performers
%     files_removed   : cell array of full paths for bottom 1/3 performers
%     perfVals        : vector of average d' values for all participants kept/removed
%
%   Bryan Medina ? Bolivia 2025

    epsilon   = 1e-5;  
    listing   = dir(fullfile(baseDir, '*.mat'));
    allPlaces = any(strcmpi(placeCodes, 'ALL'));

    files_all = {};
    perfVals  = [];

    for k = 1:numel(listing)
        fn = listing(k).name;

        % --- (1) Place filter ---
        if allPlaces
            placeMatch = true;
        else
            placeMatch = any(contains(fn, placeCodes, 'IgnoreCase', false));
        end

        % --- (2) Condition filter ---
        condMatch = contains(fn, condition, 'IgnoreCase', true);

        % --- (3) ISI-type filter ---
        hasMultiTag = contains(fn, '_Multi-p', 'IgnoreCase', true);
        if isMultiISI
            isiMatch = hasMultiTag;
        else
            isiMatch = ~hasMultiTag;
        end

        % skip old files
        isOld = contains(fn, '-original.', 'IgnoreCase', true);
        if ~(placeMatch && condMatch && isiMatch && ~isOld)
            continue
        end

        % --- (4) Load minimal vars ---
        S = load(fullfile(baseDir, fn), ...
            'repeatPosition','isResponseCorrect','stimulusPresented');

        nTrials = numel(S.stimulusPresented);
        SP = string(S.stimulusPresented);
        willRepeatFirst  = false(nTrials,1);
        neverRepeatFirst = false(nTrials,1);
        for id = unique(SP).'
            maskAll = SP == id;
            firstI  = find(maskAll,1,'first');
            if nnz(maskAll) > 1
                willRepeatFirst(firstI) = true;
            else
                neverRepeatFirst(firstI) = true;
            end
        end

        % --- compute FA + hit ---
        rawFA_wr  = sum(~S.isResponseCorrect(willRepeatFirst)) / sum(willRepeatFirst);
        faRate_wr = correctRate_clip(rawFA_wr, epsilon);

        repeatTrials = ~(willRepeatFirst | neverRepeatFirst);
        uniqPos  = unique(S.repeatPosition(repeatTrials));
        hitByPos = zeros(numel(uniqPos),1);
        for i = 1:numel(uniqPos)
            idx = S.repeatPosition == uniqPos(i);
            hitByPos(i) = correctRate_clip(sum(S.isResponseCorrect(idx))/sum(idx), epsilon);
        end

        % --- compute d' ---
        zH = norminv(hitByPos);
        zFA = norminv(faRate_wr);
        dprimeByPos = zH - zFA;

        % --- threshold by ISI=0 performance ---
        idx0 = find(uniqPos == 1, 1);
        if isempty(idx0)
            continue
        end
        if dprimeByPos(idx0) < minISI0dprime
            continue
        end

        % --- passed threshold, record file and avg performance ---
        files_all{end+1,1} = fullfile(baseDir, fn);
        perfVals(end+1,1)  = mean(dprimeByPos(~isnan(dprimeByPos)));
    end

    % -----------------------------
    % rank participants & split into top 2/3
    % -----------------------------
    if isempty(perfVals)
        warning('No participants met ISI=0 d'' threshold.');
        files_kept = {};
        files_removed = {};
        return;
    end

    [sortedPerf, sortIdx] = sort(perfVals, 'descend');
    nTotal = numel(sortedPerf);
    nKeep  = ceil((2/3) * nTotal);

    keepIdx    = sortIdx(end-nKeep+1:end);
    removeIdx  = sortIdx(1:(nTotal - nKeep));

    files_kept   = files_all(keepIdx);
    files_removed = files_all(removeIdx);

    % print summary
    fprintf('Filtered %d participants ? kept top %d (%.0f%%)\n', ...
        nTotal, nKeep, (nKeep/nTotal)*100);
    fprintf('Mean d'' kept = %.2f, removed = %.2f\n', ...
        mean(sortedPerf(keepIdx)), mean(sortedPerf(removeIdx)));
end

% -----------------------------
function r = correctRate_clip(rate, eps)
% Clamp probabilities to avoid inf z-scores
    rate = min(max(rate, eps), 1 - eps);
    r = rate;
end