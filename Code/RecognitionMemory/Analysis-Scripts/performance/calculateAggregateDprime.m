function outs = calculateAggregateDprime(baseDir, placeCodes, condition, minISI0dprime, isMultiISI)
% calculateAggregateDprime
%   Aggregates d' vs ISI across filtered participants using the SAME policy as your Python code.
%   Returns a struct with dprime values and saves a plot.
%
% Inputs:
%   baseDir         : folder containing your .mat files
%   placeCodes      : cell array of place codes, e.g. {'BOS','CAM'} or {'ALL'}
%   condition       : string to match in filename, e.g. 'Textures'
%   minISI0dprime   : numeric threshold for d' at ISI=0
%   isMultiISI      : logical flag (true = multi-ISI, false = single-ISI)
%
% Output:
%   outs            : struct containing per-subject and aggregate d' data
%
%   Bryan Medina ? Bolivia 2025

    % --------------------------
    % parameters
    % --------------------------
    epsilon = 1e-5;  % python-style clipping

    % --------------------------
    % get filtered participant files
    % --------------------------
    files = UTILS_getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime, isMultiISI);
    if isempty(files)
        warning('No participants passed filters ? nothing to plot.');
        outs = struct(); return;
    end

    % --------------------------
    % accumulators
    % --------------------------
    subjPos     = {};  % per-subject unique repeatPositions
    subjDprimes = {};  % per-subject d' at each position
    allPos      = [];  % union of all positions across subjects

    % --------------------------
    % iterate over participants
    % --------------------------
    for i = 1:numel(files)
        S = load(files{i}, 'repeatPosition', 'isResponseCorrect', 'stimulusPresented');
        if ~isfield(S, 'repeatPosition') || isempty(S.repeatPosition)
            continue
        end

        repeatTrials = ~isnan(S.repeatPosition);
        noiseTrials  = isnan(S.repeatPosition);
        if ~any(repeatTrials) || ~any(noiseTrials)
            continue
        end

        % --- false alarm rate (python policy)
        fa_yes = sum(~S.isResponseCorrect(noiseTrials), 'omitnan');
        fa_tot = sum(noiseTrials);
        rawFA  = fa_yes / max(fa_tot, 1);
        fa     = correctRate_clip(rawFA, epsilon);

        % --- hit rate by position
        upr_all = unique(S.repeatPosition(repeatTrials));
        hitByPos = zeros(numel(upr_all), 1);
        for j = 1:numel(upr_all)
            idx = (S.repeatPosition == upr_all(j));
            hr_raw = sum(S.isResponseCorrect(idx), 'omitnan') / max(sum(idx), 1);
            hitByPos(j) = correctRate_clip(hr_raw, epsilon);
        end

        % --- compute d' per position
        zH = norminv(hitByPos);
        zF = norminv(fa);
        dp = zH - zF;

        % store
        subjPos{end+1}     = upr_all(:);
        subjDprimes{end+1} = dp(:);
        allPos = union(allPos, upr_all(:)');
    end

    if isempty(allPos)
        warning('No valid repeat positions found.');
        outs = struct(); return;
    end

    % --------------------------
    % assemble [subjects x positions] matrix
    % --------------------------
    nSub = numel(subjDprimes);
    nPos = numel(allPos);
    M    = nan(nSub, nPos);

    for i = 1:nSub
        pos_i = subjPos{i};
        dp_i  = subjDprimes{i};
        for j = 1:numel(pos_i)
            col = find(allPos == pos_i(j), 1);
            if ~isempty(col)
                M(i, col) = dp_i(j);
            end
        end
    end

    % --------------------------
    % compute aggregate stats
    % --------------------------
    mu  = nanmean(M, 1);
    sem = nanstd(M, 0, 1) ./ sqrt(sum(~isnan(M), 1));
    ISI = allPos - 1;

    % --------------------------
    % plotting
    % --------------------------
    figure('Color', 'w');
    errorbar(ISI, mu, sem, 'o-', 'LineWidth', 2);
    xlabel('Interstimulus Interval (trials-between)');
    ylabel('Mean d^{\prime}');
    title(sprintf('Aggregate d'' vs ISI ? %s (N=%d)', condition, nSub));
    grid on;
    if numel(ISI) > 1, xlim([min(ISI)-1, max(ISI)+1]); end

    % --------------------------
    % output paths
    % --------------------------
    if any(strcmpi(placeCodes, 'ALL')), placeTag = 'ALL';
    else, placeTag = strjoin(placeCodes, '_'); end

    figDir = fullfile(baseDir, 'figures', condition);
    if ~exist(figDir, 'dir'), mkdir(figDir); end

    fname = sprintf('aggDprime_python_%s_%s_%s.png', condition, placeTag, ternary(isMultiISI,'multiISI','singleISI'));
    saveas(gcf, fullfile(figDir, fname));
    fprintf('Saved aggregate plot to %s\n', fullfile(figDir, fname));

    % --------------------------
    % package outputs for downstream use
    % --------------------------
    outs = struct();
    outs.ISI           = ISI;
    outs.dprime_mean   = mu;
    outs.dprime_sem    = sem;
    outs.subject_dprime = M;
    outs.subject_positions = subjPos;
    outs.files          = files;
    outs.nSubjects      = nSub;
end