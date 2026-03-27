function outs = calculateStimulusTypeHitRates(baseDir, placeCodes, condition, minISI0dprime, isMultiISI, varargin)
% calculateStimulusTypeHitRates
%   Aggregate hit rate at nonzero ISIs by stimulus type (e.g., Dance, Story, Nature)
%
%   outs = calculateStimulusTypeHitRates(baseDir, placeCodes, condition, minISI0dprime, isMultiISI, ...)
%
%   Inputs:
%     baseDir         - folder containing your .mat files
%     placeCodes      - e.g. {'BOS','CAM'} or {'ALL'}
%     condition       - condition name in filenames (e.g. 'Industrial-Nature')
%     minISI0dprime   - numeric threshold for d' at ISI=0
%     isMultiISI      - logical flag (true = multi-ISI, false = single-ISI)
%
%   Optional Name/Value pairs:
%     'ShowPlot'      - whether to display & save figure (default = true)
%
%   Output struct fields:
%     outs.types          - string array of stimulus type labels
%     outs.mean_hit_rate  - mean hit rate per type
%     outs.sem_hit_rate   - SEM per type
%     outs.subject_matrix - [nSub x nTypes] matrix of hit rates
%     outs.files          - included .mat files
%     outs.nSubjects      - number of included participants
%
%   Bryan Medina ? October 28th, 2025

    % -----------------------------
    % parameters & options
    % -----------------------------
    epsilon = 1e-5;
    p = inputParser;
    addParameter(p, 'ShowPlot', true, @islogical);
    parse(p, varargin{:});
    ShowPlot = p.Results.ShowPlot;

    % -----------------------------
    % 1) get filtered files
    % -----------------------------
    files = UTILS_getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime, isMultiISI);
    if isempty(files)
        warning('No participants passed filters ? nothing to compute.');
        outs = struct(); return;
    end

    % -----------------------------
    % 2) collect union of all stimulus types
    % -----------------------------
    allTypes = string([]);
    for i = 1:numel(files)
        S = load(files{i}, 'repeatPosition', 'stimuli_type');
        if ~isfield(S, 'stimuli_type') || isempty(S.stimuli_type)
            continue
        end
        rp = S.repeatPosition;
        stype = string(S.stimuli_type(:));
        valid = ~isnan(rp) & (rp > 0); % nonzero-ISI trials only
        allTypes = union(allTypes, unique(stype(valid)));
    end

    if isempty(allTypes)
        warning('No valid stimulus types found across participants.');
        outs = struct(); return;
    end

    % -----------------------------
    % 3) compute per-subject hit-rate matrix [nSub x nTypes]
    % -----------------------------
    nSub   = numel(files);
    nTypes = numel(allTypes);
    M      = nan(nSub, nTypes);

    for i = 1:nSub
        S = load(files{i}, 'repeatPosition', 'isResponseCorrect', 'stimuli_type');
        if ~isfield(S, 'stimuli_type') || isempty(S.stimuli_type)
            continue
        end
        rp    = S.repeatPosition;
        corr  = S.isResponseCorrect;
        stype = string(S.stimuli_type(:));
        valid = ~isnan(rp) & (rp > 0); % nonzero ISI

        for t = 1:nTypes
            maskType = valid & (stype == allTypes(t));
            nTrials  = sum(maskType);
            if nTrials > 0
                hr_raw = sum(corr(maskType)) / nTrials;
                M(i, t) = correctRate_clip(hr_raw, epsilon);
            end
        end
    end

    % -----------------------------
    % 4) aggregate group stats
    % -----------------------------
    muHit  = nanmean(M, 1);
    semHit = nanstd(M, 0, 1) ./ sqrt(sum(~isnan(M), 1));

    % -----------------------------
    % 5) optional plot
    % -----------------------------
    if ShowPlot
        figure('Color', 'w');
        x = 1:nTypes;
        bar(x, muHit, 'FaceAlpha', 0.85); hold on;
        errorbar(x, muHit, semHit, 'k', 'LineStyle', 'none', 'LineWidth', 1.5);
        hold off;

        xticks(x);
        xticklabels(allTypes);
        xtickangle(20);
        xlabel('Stimulus Type');
        ylabel('Hit Rate (nonzero ISI)');
        ylim([0 1]);
        grid on;
        title(sprintf('Hit Rate by Stimulus Type ? %s (N=%d)', condition, nSub));

        if any(strcmpi(placeCodes, 'ALL')), placeTag = 'ALL';
        else, placeTag = strjoin(placeCodes, '_'); end

        figDir = UTILS_buildOutputDir(baseDir, condition);
        fname = sprintf('aggStimulusTypeHitRate_%s_%s_%s.png', ...
            condition, placeTag, ternary(isMultiISI, 'multiISI', 'singleISI'));
        saveas(gcf, fullfile(figDir, fname));
        fprintf('Saved stimulus-type hit-rate plot to %s\n', fullfile(figDir, fname));
    end

    % -----------------------------
    % 6) package outputs
    % -----------------------------
    outs = struct();
    outs.types           = allTypes;
    outs.mean_hit_rate   = muHit;
    outs.sem_hit_rate    = semHit;
    outs.subject_matrix  = M;
    outs.files           = files;
    outs.nSubjects       = nSub;
end