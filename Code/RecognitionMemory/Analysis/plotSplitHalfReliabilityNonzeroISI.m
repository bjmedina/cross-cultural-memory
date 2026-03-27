function plotSplitHalfReliabilityNonzeroISI(baseDir, placeCodes, condition, minISI0dprime, nSplits)
% plotSplitHalfReliabilityNonzeroISI
%   Computes and plots split-half reliability of hit and FA rates
%   using nonzero ISI repeat trials (hits) and non-repeats (FAs).
%
%   Inputs:
%     baseDir         ? folder with your .mat files
%     placeCodes      ? cell array of place codes, e.g. {'BOS','CAM'} or {'ALL'}
%     condition       ? string to match in filename, e.g. 'Industrial-Nature'
%     minISI0dprime   ? threshold for d' at ISI=0 (filters participants)

    files = getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime);
    if isempty(files)
        warning('No participants passed your filters?nothing to plot.');
        return
    end

    allItems = string([]);
    nSub     = numel(files);

    % First pass: get union of all sound IDs (items)
    for i = 1:nSub
        S = load(files{i}, 'stimulusPresented','repeatPosition');
        stims = S.stimulusPresented;
        
        % Strip directory paths (MATLAB 2018 safe)
        stims = cellfun(@(x) x(max(strfind(x, filesep)) + 1:end), stims, 'UniformOutput', false);

        % Ensure they?re char arrays, not strings
        stims = cellfun(@char, stims, 'UniformOutput', false);
        rp    = S.repeatPosition;
        valid = ~isnan(rp) & rp > 1; % nonzero-ISI repeat trials
        allItems = union(allItems, unique(stims(valid)));
    end

    if isempty(allItems)
        warning('No usable items found across participants.');
        return
    end

    % Build item x participant response matrices
    nItems = numel(allItems);
    hits   = nan(nSub, nItems);
    fas    = nan(nSub, nItems);

    for i = 1:nSub
        S     = load(files{i}, 'stimulusPresented','repeatPosition','isResponseCorrect');
        stims = S.stimulusPresented;        % Strip directory paths (MATLAB 2018 safe)
        stims = cellfun(@(x) x(max(strfind(x, filesep)) + 1:end), stims, 'UniformOutput', false);

        % Ensure they?re char arrays, not strings
        stims = cellfun(@char, stims, 'UniformOutput', false);
        rp    = S.repeatPosition;
        corr  = S.isResponseCorrect;

        for t = 1:numel(stims)
            stim = stims(t);

            % ISI > 0 repeat trial (hit)
            if ~isnan(rp(t)) && rp(t) > 1
                idx = find(allItems == stim);
                hits(i, idx) = corr(t);

            % Non-repeat trial (FA)
            elseif isnan(rp(t))
                idx = find(allItems == stim);
                fas(i, idx) = corr(t);
            end
        end
    end

    % Compute split-half reliability
    [r_hit, ~] = estimateSplitHalf(hits, nSplits);
    [r_fa,  ~] = estimateSplitHalf(fas, nSplits);

    fprintf("Split-half reliability (nonzero ISI trials only):\n");
    fprintf("  Hits:         r = %.3f\n", r_hit);
    fprintf("  False Alarms: r = %.3f\n", r_fa);
    
    % spearman brown correction:
    sb_r_hit = (2  * r_hit) / (1 + r_hit);
    sb_r_fa = (2  * r_fa) / (1 + r_fa);
    fprintf("  SB Hits:         r = %.3f\n", sb_r_hit);
    fprintf("  SB False Alarms: r = %.3f\n", sb_r_fa);
    
    % Plot results
    figure;
    bar([r_hit, sb_r_hit, r_fa, sb_r_fa]);
    set(gca, 'XTickLabel', { ...
        'Hits', ...
        sprintf('SB-Corrected Hit'), ...
        'False Alarms', ...
        sprintf('SB-Corrected FA')});  
    
    ylabel('Split-Half Reliability');
    ylim([0, 1]);
    title(sprintf('SHR by Trial Type ? %s (N=%d)', condition, nSub));
    grid on;

    % Save plot
    if any(strcmpi(placeCodes,'ALL')), placeTag='ALL';
    else placeTag = strjoin(placeCodes,'_'); end

    outDir = fullfile(baseDir, 'figures', condition);
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    fname = sprintf('%s-%s-catchtrial-sens-%.2f.png', 'SHR', placeTag, minISI0dprime);
    saveas(gcf, fullfile(outDir, fname));
    fprintf('Saved plot to %s\n', fullfile(outDir, fname));

end
