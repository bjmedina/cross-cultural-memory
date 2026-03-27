function outs = analyzePerformanceOverTime(baseDir, placeCodes, condition, minISI0dprime, isMultiISI, varargin)
% analyzePerformanceOverTime
%   Evaluate whether hit rate and false alarm rate change across the experiment.
%
%   Divides each participant's trials into equal sections (e.g., quartiles)
%   and computes mean hit and false alarm rates for each section.
%
% Inputs:
%   baseDir         : folder containing .mat files
%   placeCodes      : e.g. {'BOS','CAM'} or {'ALL'}
%   condition       : string to match in filename, e.g. 'Textures'
%   minISI0dprime   : numeric threshold for inclusion
%   isMultiISI      : logical flag (true = multi-ISI, false = single-ISI)
%
% Optional Name/Value pairs:
%   'nSections'     : number of experiment sections (default = 4)
%   'ShowPlot'      : show and save summary plots (default = true)
%
% Output struct fields:
%   outs.hit_rate_matrix  - [nSub x nSections]
%   outs.fa_rate_matrix   - [nSub x nSections]
%   outs.hit_mean         - group mean hit rate per section
%   outs.fa_mean          - group mean false alarm rate per section
%   outs.hit_sem          - SEM of hit rate per section
%   outs.fa_sem           - SEM of FA rate per section
%   outs.section_edges    - trial index edges used for binning
%   outs.files            - included .mat files
%
%   Bryan Medina ? November 2025

    % -----------------------------
    % parameters
    % -----------------------------
    epsilon = 1e-5;
    p = inputParser;
    addParameter(p, 'nSections', 4, @isscalar);
    addParameter(p, 'ShowPlot', true, @islogical);
    parse(p, varargin{:});
    nSections = p.Results.nSections;
    ShowPlot  = p.Results.ShowPlot;

    % -----------------------------
    % load filtered participants
    % -----------------------------
    files = UTILS_getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime, isMultiISI);
    if isempty(files)
        warning('No participants passed filters ? nothing to analyze.');
        outs = struct(); return;
    end

    % -----------------------------
    % accumulators
    % -----------------------------
    nSub = numel(files);
    hitMat = nan(nSub, nSections);
    faMat  = nan(nSub, nSections);

    % -----------------------------
    % per-participant stats
    % -----------------------------
    for i = 1:nSub
        S = load(files{i}, 'isResponseCorrect', 'repeatPosition');
        if ~isfield(S, 'isResponseCorrect') || isempty(S.isResponseCorrect)
            continue
        end

        nTrials = numel(S.isResponseCorrect);
        edges = round(linspace(1, nTrials+1, nSections+1));

        for s = 1:nSections
            idx = edges(s):(edges(s+1)-1);
            if isempty(idx) || max(idx) > nTrials, continue; end

            repeatMask = ~isnan(S.repeatPosition(idx));
            foilMask   = isnan(S.repeatPosition(idx));

            % --- hit rate ---
            if any(repeatMask)
                hr_raw = sum(S.isResponseCorrect(idx(repeatMask))) / sum(repeatMask);
                hitMat(i,s) = correctRate_clip(hr_raw, epsilon);
            end

            % --- false alarm rate ---
            if any(foilMask)
                fa_raw = sum(~S.isResponseCorrect(idx(foilMask))) / sum(foilMask);
                faMat(i,s) = correctRate_clip(fa_raw, epsilon);
            end
        end
    end

    % -----------------------------
    % group-level stats
    % -----------------------------
    hit_mean = nanmean(hitMat, 1);
    fa_mean  = nanmean(faMat, 1);
    hit_sem  = nanstd(hitMat, 0, 1) ./ sqrt(sum(~isnan(hitMat), 1));
    fa_sem   = nanstd(faMat, 0, 1) ./ sqrt(sum(~isnan(faMat), 1));

    % -----------------------------
    % optional plot
    % -----------------------------
    if ShowPlot
        figure('Color','w');
        hold on;
        errorbar(1:nSections, hit_mean, hit_sem, '-o', 'LineWidth', 2, 'DisplayName', 'Hit rate');
        errorbar(1:nSections, fa_mean, fa_sem, '-s', 'LineWidth', 2, 'DisplayName', 'False alarm rate');
        xlabel('Experiment Section');
        ylabel('Response Rate');
        ylim([0 1]);
        grid on;
        legend('Location','best');
        title(sprintf('Performance Drift Across Experiment ? %s (N=%d)', condition, nSub));

        % paired-sample t-test (first vs last section)
        [~,p_hit] = ttest(hitMat(:,1), hitMat(:,end), 'Tail','both');
        [~,p_fa]  = ttest(faMat(:,1),  faMat(:,end),  'Tail','both');
        text(1.2, max(hit_mean)+0.05, sprintf('?Hit p=%.3f | ?FA p=%.3f', p_hit, p_fa), 'FontSize',10);

        % save figure
        if any(strcmpi(placeCodes, 'ALL')), placeTag = 'ALL';
        else, placeTag = strjoin(placeCodes, '_'); end

        figDir = fullfile(baseDir, 'figures', condition);
        if ~exist(figDir, 'dir'), mkdir(figDir); end
        fname = sprintf('perf_over_time_%s_%s_%s.png', condition, placeTag, ternary(isMultiISI,'multiISI','singleISI'));
        saveas(gcf, fullfile(figDir, fname));
        fprintf('Saved performance-over-time plot to %s\n', fullfile(figDir, fname));
    end

    % -----------------------------
    % package outputs
    % -----------------------------
    outs = struct();
    outs.hit_rate_matrix = hitMat;
    outs.fa_rate_matrix  = faMat;
    outs.hit_mean        = hit_mean;
    outs.fa_mean         = fa_mean;
    outs.hit_sem         = hit_sem;
    outs.fa_sem          = fa_sem;
    outs.section_edges   = edges;
    outs.files           = files;
end

% ---------- Helper ----------
function val = correctRate_clip(hr, eps)
% Clamp response rate slightly away from 0 or 1
    val = min(max(hr, eps), 1 - eps);
end