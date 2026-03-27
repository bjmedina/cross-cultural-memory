function plotAggregateDprime_pythonPolicy(baseDir, placeCodes, condition, minISI0dprime, isMultiISI)
% plotAggregateDprime_pythonPolicy
% Aggregates d' vs ISI across filtered participants using the SAME policy as your Python code:
%   - Noise/FA: ALL non-repeat trials (isnan(repeatPosition))
%   - Edge clipping: epsilon = 1e-5 (like np.clip(..., 1e-5, 1-1e-5))
%   - ISI: trials-between = repeatPosition - 1
%
% Inputs:
%   baseDir         : folder containing your .mat files
%   placeCodes      : cell array of place codes, e.g. {'BOS','CAM'} or {'ALL'}
%   condition       : string to match in filename, e.g. 'Textures'
%   minISI0dprime   : numeric threshold for d' at ISI=0
%
% Saves a PNG under baseDir/figures/<condition>/ with naming consistent with prior code.

    % --------------------------
    % parameters / constants
    % --------------------------
    epsilon = 1e-5;                         % python-style clipping
    allowedISI = [0 1 2 4 8 16 32 64];    % match your Python allowed_isi (exclude -1; that's noise bucket)

    % --------------------------
    % get filtered participant files
    % --------------------------
    files = UTILS_getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime, isMultiISI);
    if isempty(files)
        warning('No participants passed your filters ? nothing to plot.');
        return
    end

    % --------------------------
    % accumulators
    % --------------------------
    subjPos     = {};   % per-subject unique repeatPositions (kept as positions first)
    subjDprimes = {};   % per-subject d' at each position in subjPos{i}
    allPos      = [];   % union of positions across subjects

    % --------------------------
    % iterate over participants
    % --------------------------
    for i = 1:numel(files)
        % Load required fields (assumes these exist in your .mat files)
        S = load(files{i}, 'repeatPosition', 'isResponseCorrect', 'stimulusPresented');
        N = numel(S.stimulusPresented);

        % ---------- define masks ----------
        % Repeats are trials where repeatPosition is finite
        repeatTrials = ~isnan(S.repeatPosition);
        % Noise is ALL non-repeat trials (python policy)
        noiseTrials  = isnan(S.repeatPosition);

        % If no repeats or no noise, skip (cannot compute d')
        if ~any(repeatTrials) || ~any(noiseTrials)
            continue
        end

        % ---------- false-alarm rate (python policy) ----------
        % On non-repeat trials, "yes" responses are false alarms.
        % In your data, isResponseCorrect==1 typically means the correct response for that trial type.
        % For non-repeats, the correct response is "No", so ~isResponseCorrect marks a "Yes".
        fa_yes = sum(~S.isResponseCorrect(noiseTrials), 'omitnan');  % count "Yes" on noise
        fa_tot = sum(noiseTrials);
        rawFA  = fa_yes / max(fa_tot, 1);                           % guard divide-by-zero
        fa     = correctRate_clip(rawFA, epsilon);                   % clip like Python

        % ---------- hit rates per repeatPosition ----------
        upr_all = unique(S.repeatPosition(repeatTrials));            % positions present
        % Map to ISI = position - 1 and keep only allowed ISIs
        ISI_vals = upr_all - 1;
        keepIdx  = ismember(ISI_vals, allowedISI);
        upr      = upr_all(keepIdx);
        if isempty(upr)
            continue
        end

        hitByPos = zeros(numel(upr), 1);
        for j = 1:numel(upr)
            idx_at_pos = (S.repeatPosition == upr(j));
            % hit rate = proportion of "Yes" on repeats
            % For repeat trials, "Yes" is the correct response, so isResponseCorrect==1 counts hits
            hr_raw = sum(S.isResponseCorrect(idx_at_pos), 'omitnan') / max(sum(idx_at_pos), 1);
            hitByPos(j) = correctRate_clip(hr_raw, epsilon);
        end

        % ---------- compute d' at each position ----------
        zH = norminv(hitByPos);
        zF = norminv(fa);
        dp = zH - zF;

        % ---------- store ----------
        subjPos{end+1}     = upr;   % store positions (not ISI) to keep alignment
        subjDprimes{end+1} = dp;
        allPos             = union(allPos, upr); 
    end

    if isempty(allPos)
        warning('No valid repeat positions found across any participants.');
        return
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
    % aggregate and plot
    % --------------------------
    mu  = nanmean(M, 1);
    sem = nanstd(M, 0, 1) ./ sqrt(sum(~isnan(M), 1));
    ISI = allPos - 1;  % convert positions to ISI for x-axis

    figure('Color', 'w');
    errorbar(ISI, mu, sem, 'o-', 'LineWidth', 2);
    xlabel('Interstimulus Interval (trials-between)');
    ylabel('Mean d^{\prime}');
    title(sprintf('Aggregate d'' vs ISI ? %s (N=%d; python policy)', condition, nSub));
    grid on;

    if numel(ISI) > 1
        xlim([min(ISI)-1, max(ISI)+1]);
    end

    % --------------------------
    % output path (same style as before)
    % --------------------------
    if any(strcmpi(placeCodes, 'ALL'))
        placeTag = 'ALL';
    else
        placeTag = strjoin(placeCodes, '_');
    end

    outputFolder = fullfile(baseDir, 'figures', condition);
    if ~exist(outputFolder, 'dir'), mkdir(outputFolder); end

    outname = sprintf('%s-%s-catchtrial-sens-%.2f.png', 'aggDprime_python', placeTag, minISI0dprime);
    saveas(gcf, fullfile(outputFolder, outname));
    fprintf('Saved aggregate plot to %s\n', fullfile(outputFolder, outname));
end

% --------------------------
% utilities
% --------------------------
function p = correctRate_clip(p_raw, eps_val)
% correctRate_clip  Clip proportions away from 0 and 1, like Python's np.clip(..., 1e-5, 1-1e-5).
    if isnan(p_raw)
        p = NaN;
    else
        p = min(max(p_raw, eps_val), 1 - eps_val);
    end
end