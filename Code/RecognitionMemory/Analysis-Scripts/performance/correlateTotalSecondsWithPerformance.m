function outs = correlateTotalSecondsWithPerformance(baseDir, placeCodes, condition, minISI0dprime, isMultiISI)
% correlateTotalSecondsWithPerformance
%   Correlate total experiment duration (totalSeconds) with mean d' across ISIs.
%
%   Uses the same participant filtering policy as calculateAggregateDprime.m.
%   Computes per-subject d' vs ISI, averages across nonzero ISIs,
%   and correlates with each participant's totalSeconds.
%
% Inputs:
%   baseDir         : folder containing your .mat files
%   placeCodes      : e.g. {'BOS','CAM'} or {'ALL'}
%   condition       : condition name in filenames, e.g. 'Globalized-Music'
%   minISI0dprime   : numeric threshold for d' at ISI=0
%   isMultiISI      : logical flag (true = multi-ISI, false = single-ISI)
%
% Output struct fields:
%   outs.totalSeconds     - vector of total experiment durations
%   outs.mean_dprime      - mean d' per participant
%   outs.r_spearman       - Spearman correlation coefficient
%   outs.p_spearman       - corresponding p-value
%   outs.r_pearson        - Pearson correlation coefficient
%   outs.p_pearson        - corresponding p-value
%   outs.files            - included .mat files
%   outs.nSubjects        - number of participants included
%
%   Bryan Medina ? November 2025

    % --------------------------
    % parameters
    % --------------------------
    epsilon = 1e-5;

    % --------------------------
    % get filtered participant files
    % --------------------------
    files = UTILS_getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime, isMultiISI);
    if isempty(files)
        warning('No participants passed filters ? nothing to correlate.');
        outs = struct(); return;
    end

    % --------------------------
    % per-participant d' and time
    % --------------------------
    totalSeconds = nan(numel(files), 1);
    meanDprime   = nan(numel(files), 1);

    for i = 1:numel(files)
        S = load(files{i}, 'repeatPosition', 'isResponseCorrect', 'stimulusPresented', 'totalSeconds');
        if ~isfield(S, 'repeatPosition') || isempty(S.repeatPosition)
            continue
        end
        repeatTrials = ~isnan(S.repeatPosition);
        noiseTrials  = isnan(S.repeatPosition);
        if ~any(repeatTrials) || ~any(noiseTrials)
            continue
        end

        % --- False alarm rate ---
        fa_yes = sum(~S.isResponseCorrect(noiseTrials), 'omitnan');
        fa_tot = sum(noiseTrials);
        rawFA  = fa_yes / max(fa_tot, 1);
        fa     = correctRate_clip(rawFA, epsilon);

        % --- Hit rate per position ---
        upr_all = unique(S.repeatPosition(repeatTrials));
        hitByPos = zeros(numel(upr_all), 1);
        for j = 1:numel(upr_all)
            idx = (S.repeatPosition == upr_all(j));
            hr_raw = sum(S.isResponseCorrect(idx), 'omitnan') / max(sum(idx), 1);
            hitByPos(j) = correctRate_clip(hr_raw, epsilon);
        end

        % --- Compute d' per ISI ---
        zH = norminv(hitByPos);
        zF = norminv(fa);
        dp = zH - zF;

        % --- Average across nonzero ISIs (skip ISI=0) ---
        isiVals = upr_all - 1;
        mask = isiVals > 0;
        if any(mask)
            meanDprime(i) = mean(dp(mask), 'omitnan');
        else
            meanDprime(i) = mean(dp, 'omitnan');
        end

        % --- totalSeconds ---
        if isfield(S, 'totalSeconds')
            totalSeconds(i) = S.totalSeconds;
        end
    end

    % --------------------------
    % correlation analysis
    % --------------------------
    mask = ~isnan(meanDprime) & ~isnan(totalSeconds);
    nSub = sum(mask);
    if nSub < 3
        warning('Not enough valid participants for correlation analysis.');
        outs = struct(); return;
    end

    [r_s, p_s] = corr(totalSeconds(mask), meanDprime(mask), 'type', 'Spearman');
    [r_p, p_p] = corr(totalSeconds(mask), meanDprime(mask), 'type', 'Pearson');
    fprintf('Spearman r=%.3f, p=%.3f | Pearson r=%.3f, p=%.3f (N=%d)\n', r_s, p_s, r_p, p_p, nSub);

    % --------------------------
    % plot correlation
    % --------------------------
    figure('Color','w');
    scatter(totalSeconds(mask)/60, meanDprime(mask), 70, 'filled'); hold on;
    lsline; % least-squares fit
    xlabel('Total Duration (minutes)');
    ylabel('Mean d^{\prime} (nonzero ISIs)');
    title(sprintf('%s ? Duration vs Performance (N=%d)', condition, nSub));
    grid on;
    text(min(totalSeconds(mask))/60, max(meanDprime(mask)), ...
        sprintf('Spearman r=%.2f, p=%.3f', r_s, p_s), ...
        'VerticalAlignment','top','FontSize',10);

    % output directory & save
    if any(strcmpi(placeCodes, 'ALL')), placeTag = 'ALL';
    else, placeTag = strjoin(placeCodes, '_'); end

    figDir = fullfile(baseDir, 'figures', condition);
    if ~exist(figDir, 'dir'), mkdir(figDir); end

    fname = sprintf('corr_totalSeconds_dprime_%s_%s_%s.png', ...
        condition, placeTag, ternary(isMultiISI,'multiISI','singleISI'));
    saveas(gcf, fullfile(figDir, fname));
    fprintf('Saved duration-performance correlation plot to %s\n', fullfile(figDir, fname));

    % --------------------------
    % package outputs
    % --------------------------
    outs = struct();
    outs.totalSeconds   = totalSeconds;
    outs.mean_dprime    = meanDprime;
    outs.r_spearman     = r_s;
    outs.p_spearman     = p_s;
    outs.r_pearson      = r_p;
    outs.p_pearson      = p_p;
    outs.files          = files;
    outs.nSubjects      = nSub;
end


% ---------- Helper ----------
function val = correctRate_clip(hr, eps)
% Clamp hit rate slightly away from 0 or 1
    val = min(max(hr, eps), 1 - eps);
end