function outs = calculateSplitHalfReliability(baseDir, placeCodes, condition, minISI0dprime, isMultiISI, nSplits, splitDim, top)
% calculateSplitHalfReliability
%   Compute split-half reliability of hit and false-alarm rates
%   using nonzero-ISI repeat trials (hits) and non-repeats (FAs).
%   Can split across participants (default) or across stimuli.
%
%   outs = calculateSplitHalfReliability(baseDir, placeCodes, condition, ...
%                minISI0dprime, isMultiISI, nSplits, splitDim)
%
%   Inputs:
%     baseDir         - folder with .mat files
%     placeCodes      - e.g. {'BOS','CAM'} or {'ALL'}
%     condition       - string to match in filename (e.g. 'Industrial-Nature')
%     minISI0dprime   - threshold for d' at ISI=0 (filters participants)
%     isMultiISI      - logical flag (true = multi-ISI, false = single-ISI)
%     nSplits         - number of random split-halves (e.g. 1000)
%     splitDim        - dimension to split along:
%                         1 = participants (default)
%                         2 = stimuli
%
%   Output struct fields:
%     outs.r_hit, outs.r_fa           - raw reliabilities
%     outs.sb_hit, outs.sb_fa         - Spearman-Brown corrected reliabilities
%     outs.itemwise_hits, itemwise_fas- [nSub � nItems] matrices
%     outs.items                      - string array of item names
%     outs.nSubjects, outs.files      - metadata for tracking
%
%   Bryan Medina ? October 30 2025

    if nargin < 7, splitDim = 1; end  % Default: split across participants
    display(strjoin(placeCodes,'_'));
    % -----------------------------
    % 1) Get filtered files
    % -----------------------------
    
    if top
        files = UTILS_getTopPerformers_ISI16_pythonPolicy(baseDir, placeCodes, condition, minISI0dprime, isMultiISI);
    else
        [files, ~] = UTILS_getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime, isMultiISI);
    end
    
    if isempty(files)
        warning('No participants passed filters ? nothing to compute.');
        outs = struct(); return;
    end

    nSub = numel(files);
    allItems = string([]);

    % -----------------------------
    % 2) Collect union of all item IDs (nonzero-ISI repeats)
    % -----------------------------
    for i = 1:nSub
        S = load(files{i}, 'stimulusPresented','repeatPosition');
        stims = S.stimulusPresented;

        % Strip directory path safely (MATLAB 2018 compatible)
        stims = cellfun(@(x) char(x(max(strfind(x, filesep)) + 1:end)), stims, 'UniformOutput', false);

        rp = S.repeatPosition;
        valid = ~isnan(rp) & rp > 1; % nonzero-ISI repeat trials only
        allItems = union(allItems, unique(string(stims(valid))));
    end

    if isempty(allItems)
        warning('No usable items found across participants.');
        outs = struct(); return;
    end

    nItems = numel(allItems);
    hits   = nan(nSub, nItems);
    fas    = nan(nSub, nItems);

    % -----------------------------
    % 3) Build participant � item matrices
    % -----------------------------
    for i = 1:nSub
        S = load(files{i}, 'stimulusPresented','repeatPosition','isResponseCorrect');
        stims = S.stimulusPresented;
        stims = cellfun(@(x) char(x(max(strfind(x, filesep)) + 1:end)), stims, 'UniformOutput', false);
        rp    = S.repeatPosition;
        corr  = S.isResponseCorrect;

        for t = 1:numel(stims)
            stim = string(stims{t});
            idx  = find(allItems == stim, 1);

            % Nonzero-ISI repeat trial ? hit
            if ~isnan(rp(t)) && rp(t) > 1 && ~isempty(idx)
                hits(i, idx) = corr(t);

            % Non-repeat trial -> FA rate (1 - isResponseCorrect)
            % isResponseCorrect=1 means correct rejection, =0 means false alarm
            % We store the FA rate so that higher values = more false alarms
            elseif isnan(rp(t)) && ~isempty(idx)
                fas(i, idx) = 1 - corr(t);
            end
        end
    end

    % -----------------------------
    % 4) Compute split-half reliabilities
    % -----------------------------
    [r_hit, r_hit_std] = estimateSplitHalfFlexible(hits, nSplits, splitDim);
    [r_fa,  r_fa_std]  = estimateSplitHalfFlexible(fas,  nSplits, splitDim);

    % Spearman?Brown correction
    sb_hit = (2 * r_hit) / (1 + r_hit);
    sb_fa  = (2 * r_fa)  / (1 + r_fa);

    % -----------------------------
    % 5) Display summary
    % -----------------------------
    dimLabel = ternary(splitDim == 1, 'participants', 'stimuli');
    fprintf('\nSplit-half reliability (%s split; nonzero ISI trials only):\n', dimLabel);
    fprintf('  Hits:         r = %.3f � %.3f  | SB-corrected = %.3f\n', r_hit, r_hit_std, sb_hit);
    fprintf('  False Alarms: r = %.3f � %.3f  | SB-corrected = %.3f\n', r_fa, r_fa_std, sb_fa);

    % -----------------------------
    % 6) Plot with error bars
    % -----------------------------
    figure('Color','w');

    vals = [r_hit, sb_hit, r_fa, sb_fa];
    errs = [r_hit_std, r_hit_std, r_fa_std, r_fa_std];

    bar(vals, 'FaceColor',[0.4 0.6 0.8]); hold on;
    errorbar(1:numel(vals), vals, errs, 'k.', 'LineWidth',1.2, 'CapSize',10);

    set(gca, 'XTick', 1:numel(vals), ...
             'XTickLabel', {'Hits','SB-Corrected Hit','False Alarms','SB-Corrected FA'}, ...
             'FontSize',11);
    ylabel('Split-Half Reliability (+STD)');
    ylim([0 1]);
    title(sprintf('Split-Half Reliability ? %s (%s split, N=%d)', condition, dimLabel, nSub));
    grid on; box off;

    for i = 1:numel(vals)
        text(i, vals(i)+0.03, sprintf('%.2f', vals(i)), ...
             'HorizontalAlignment','center', 'FontWeight','bold', 'FontSize',10);
    end
    hold off;

    % -----------------------------
    % 7) Save plot
    % -----------------------------
    if any(strcmpi(placeCodes,'ALL')), placeTag = 'ALL';
    else, placeTag = strjoin(placeCodes,'_'); end

    outDir = UTILS_buildOutputDir(baseDir, condition);
    fname = sprintf('SHR_%s_%s_%s_splitDim%d.png', ...
        condition, placeTag, ternary(isMultiISI, 'multiISI', 'singleISI'), splitDim);
    saveas(gcf, fullfile(outDir, fname));
    fprintf('Saved plot to %s\n', fullfile(outDir, fname));

    % -----------------------------
    % 8) Package outputs
    % -----------------------------
    outs = struct();
    outs.r_hit         = r_hit;
    outs.r_fa          = r_fa;
    outs.sb_hit        = sb_hit;
    outs.sb_fa         = sb_fa;
    outs.itemwise_hits = hits;
    outs.itemwise_fas  = fas;
    outs.items         = allItems;
    outs.nSubjects     = nSub;
    outs.files         = files;
    outs.splitDim      = splitDim;
    outs.splitLabel    = dimLabel;
end