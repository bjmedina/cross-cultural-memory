function [files_kept, files_removed, perfVals] = UTILS_getTopPerformers_ISI16_pythonPolicy(baseDir, placeCodes, condition, minISI0dprime, isMultiISI)
% UTILS_getTopPerformers_ISI16_pythonPolicy
%   Selects top 2/3 participants based on d' at ISI=16 (Python-style policy).
%
%   Policy:
%     ? False alarms = ALL non-repeat trials (isnan(repeatPosition))
%     ?g Clip proportions with epsilon=1e-5
%     ? ISI = repeatPosition - 1
%
%   Inputs:
%     baseDir         - folder with .mat files
%     placeCodes      - e.g. {'TSI'} or {'BOS'}
%     condition       - condition string (e.g. 'Globalized-Music')
%     minISI0dprime   - minimal d' at ISI=0 for inclusion
%     isMultiISI      - true for multi-ISI experiments
%
%   Outputs:
%     files_kept, files_removed : cell arrays of filepaths
%     perfVals : participant-level d' at ISI=16
%
%   Bryan Medina ? Bolivia 2025

    epsilon   = 1e-5;
    allowedISI = [0 1 2 4 8 16 32 64];
    listing   = dir(fullfile(baseDir, '*.mat'));
    allPlaces = any(strcmpi(placeCodes, 'ALL'));

    files_all = {};
    perfVals  = [];

    for k = 1:numel(listing)
        fn = listing(k).name;

        % --- Filter by place, condition, ISI type ---
        if allPlaces
            placeMatch = true;
        else
            placeMatch = any(contains(fn, placeCodes, 'IgnoreCase', false));
        end
        condMatch = contains(fn, condition, 'IgnoreCase', true);
        hasMultiTag = contains(fn, '_Multi-p', 'IgnoreCase', true);
        if isMultiISI
            isiMatch = hasMultiTag;
        else
            isiMatch = ~hasMultiTag;
        end
        isOld = contains(fn, '-original.', 'IgnoreCase', true);
        if ~(placeMatch && condMatch && isiMatch && ~isOld)
            continue
        end

        % --- Load relevant data ---
        S = load(fullfile(baseDir, fn), ...
            'repeatPosition','isResponseCorrect','stimulusPresented');
        N = numel(S.stimulusPresented);

        % --- define trial masks (Python policy) ---
        repeatTrials = ~isnan(S.repeatPosition);
        noiseTrials  = isnan(S.repeatPosition);

        if ~any(repeatTrials) || ~any(noiseTrials)
            continue
        end

        % --- compute FA rate ---
        fa_yes = sum(~S.isResponseCorrect(noiseTrials), 'omitnan');
        fa_tot = sum(noiseTrials);
        rawFA  = fa_yes / max(fa_tot, 1);
        fa     = correctRate_clip(rawFA, epsilon);

        % --- compute hit rates per repeatPosition ---
        upr_all = unique(S.repeatPosition(repeatTrials));
        ISI_vals = upr_all - 1;
        keepIdx = ismember(ISI_vals, allowedISI);
        upr = upr_all(keepIdx);

        hitByPos = nan(numel(upr),1);
        for j = 1:numel(upr)
            idx = (S.repeatPosition == upr(j));
            hr_raw = sum(S.isResponseCorrect(idx),'omitnan') / max(sum(idx),1);
            hitByPos(j) = correctRate_clip(hr_raw, epsilon);
        end

        % --- compute d' per ISI ---
        zH = norminv(hitByPos);
        zF = norminv(fa);
        dp = zH - zF;

        % --- find d' for ISI=0 and ISI=16 ---
        ISIs = upr - 1;
        dprime0  = dp(ISIs==0);
        dprime16 = dp(ISIs==16);

        if isempty(dprime0) || isempty(dprime16)
            continue
        end

        % --- enforce minimum ISI=0 criterion ---
        if dprime0 < minISI0dprime
            continue
        end

        % --- record participant performance at ISI=16 ---
        files_all{end+1,1} = fullfile(baseDir, fn);
        perfVals(end+1,1)  = dprime16;
    end

    % -----------------------------
    % rank participants by ISI=16 d'
    % -----------------------------
    if isempty(perfVals)
        warning('No participants had valid ISI=16 d'' values.');
        files_kept = {}; files_removed = {};
        return
    end

    [sortedPerf, sortIdx] = sort(perfVals, 'descend');
    nTotal = numel(sortedPerf);
    nKeep  = ceil((2/3)*nTotal);

    keepIdx   = sortIdx(1:nKeep);
    removeIdx = sortIdx(nKeep+1:end);

    files_kept    = files_all(keepIdx);
    files_removed = files_all(removeIdx);

    fprintf('Filtered %d participants ? kept top %d (%.0f%%)\n', ...
        nTotal, nKeep, (nKeep/nTotal)*100);
    fprintf('Mean d?16 kept = %.2f, removed = %.2f\n', ...
        mean(perfVals(keepIdx),'omitnan'), mean(perfVals(removeIdx),'omitnan'));

    % -----------------------------
    % plot histogram
    % -----------------------------
    figure('Color','w','Position',[300 200 600 400]); hold on;
    histogram(perfVals, 'FaceColor',[0.6 0.7 0.9], 'EdgeColor','none');
    xline(min(perfVals(keepIdx)), 'r--', 'LineWidth', 2, ...
        'DisplayName', 'Cutoff (bottom 1/3)');
    xlabel('Participant d? (ISI=16)');
    ylabel('Count');
    title(sprintf('Participant d?(ISI=16) Distribution ? %s', strrep(condition,'_',' ')));
    grid on; box off;
    legend('show');
    hold off;

end

% -----------------------------
function p = correctRate_clip(p_raw, eps_val)
% clamp probabilities away from 0 and 1
    if isnan(p_raw)
        p = NaN;
    else
        p = min(max(p_raw, eps_val), 1 - eps_val);
    end
end