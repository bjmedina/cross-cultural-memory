function outs = analyzePerformanceByRT(baseDir, placeCodes, condition, minISI0dprime, isMultiISI, varargin)
% analyzePerformanceByRT
%   Analyze hit and false alarm rates as a function of response time (RT).
%
%   Divides all trials into equal-size RT bins across subjects, and computes
%   average hit and false alarm rates per bin.
%
% Inputs:
%   baseDir         : folder containing your .mat files
%   placeCodes      : e.g. {'BOS','CAM'} or {'ALL'}
%   condition       : string to match in filename, e.g. 'Globalized-Music'
%   minISI0dprime   : numeric threshold for d' at ISI=0
%   isMultiISI      : logical flag (true = multi-ISI, false = single-ISI)
%
% Optional Name/Value pairs:
%   'nBins'         : number of RT bins (default = 5)
%   'ShowPlot'      : whether to display & save figures (default = true)
%
% Outputs:
%   outs.rt_bins        - RT bin edges (s)
%   outs.hit_mean       - mean hit rate per bin
%   outs.fa_mean        - mean false alarm rate per bin
%   outs.hit_sem        - SEM of hit rate
%   outs.fa_sem         - SEM of false alarm rate
%   outs.subject_hitMat  - [nSub x nBins] matrix of hit rates
%   outs.subject_faMat   - [nSub x nBins] matrix of FA rates
%
%   Bryan Medina ? November 2025

    % -----------------------------
    % parameters
    % -----------------------------
    epsilon = 1e-5;
    p = inputParser;
    addParameter(p, 'nBins', 5, @isscalar);
    addParameter(p, 'ShowPlot', true, @islogical);
    parse(p, varargin{:});
    nBins = p.Results.nBins;
    ShowPlot = p.Results.ShowPlot;

    % -----------------------------
    % load filtered participant files
    % -----------------------------
    files = UTILS_getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime, isMultiISI);
    if isempty(files)
        warning('No valid participants found.'); outs = struct(); return;
    end
    nSub = numel(files);

    % -----------------------------
    % per-subject hit/FA by RT bin
    % -----------------------------
    allRT = [];  % collect RTs for global bin edges
    for i = 1:nSub
        S = load(files{i}, 'responseTime');
        if isfield(S, 'responseTime')
            allRT = [allRT; S.responseTime(:)];
        end
    end
    allRT = allRT(allRT > 0.2 & allRT < 8); % trim extremes
    edges = quantile(allRT, linspace(0,1,nBins+1));

    hitMat = nan(nSub, nBins);
    faMat  = nan(nSub, nBins);

    for i = 1:nSub
        S = load(files{i}, 'isResponseCorrect', 'repeatPosition', 'responseTime');
        if ~isfield(S, 'responseTime') || isempty(S.responseTime), continue; end

        rt = S.responseTime(:);
        corr = S.isResponseCorrect(:);
        rp = S.repeatPosition(:);
        valid = rt > 0.2 & rt < 8 & ~isnan(corr);

        for b = 1:nBins
            inBin = valid & rt >= edges(b) & rt < edges(b+1);
            if ~any(inBin), continue; end

            % --- hit rate ---
            hitMask = inBin & ~isnan(rp);
            if any(hitMask)
                hr_raw = mean(corr(hitMask));
                hitMat(i,b) = correctRate_clip(hr_raw, epsilon);
            end

            % --- false alarm rate ---
            faMask = inBin & isnan(rp);
            if any(faMask)
                fa_raw = mean(~corr(faMask));
                faMat(i,b) = correctRate_clip(fa_raw, epsilon);
            end
        end
    end

    % -----------------------------
    % aggregate across participants
    % -----------------------------
    hit_mean = nanmean(hitMat, 1);
    fa_mean  = nanmean(faMat, 1);
    hit_sem  = nanstd(hitMat, 0, 1) ./ sqrt(sum(~isnan(hitMat), 1));
    fa_sem   = nanstd(faMat, 0, 1) ./ sqrt(sum(~isnan(faMat), 1));

    % -----------------------------
    % plot
    % -----------------------------
    if ShowPlot
        binCenters = movmean(edges,2,'Endpoints','discard');
        figure('Color','w');
        hold on;
        errorbar(binCenters, hit_mean, hit_sem, '-o', 'LineWidth', 2, 'DisplayName', 'Hit rate');
        errorbar(binCenters, fa_mean, fa_sem, '-s', 'LineWidth', 2, 'DisplayName', 'False alarm');
        xlabel('Response Time (s)');
        ylabel('Rate');
        ylim([0 1]);
        legend('Location','best');
        grid on;
        title(sprintf('Performance by Response Time ? %s (N=%d)', condition, nSub));

        if any(strcmpi(placeCodes, 'ALL')), placeTag = 'ALL';
        else, placeTag = strjoin(placeCodes, '_'); end

        figDir = fullfile(baseDir, 'figures', condition);
        if ~exist(figDir, 'dir'), mkdir(figDir); end
        fname = sprintf('perf_by_RT_%s_%s_%s.png', ...
            condition, placeTag, ternary(isMultiISI,'multiISI','singleISI'));
        saveas(gcf, fullfile(figDir, fname));
        fprintf('Saved performance-by-RT plot to %s\n', fullfile(figDir, fname));
    end

    % -----------------------------
    % package outputs
    % -----------------------------
    outs = struct();
    outs.rt_bins         = edges;
    outs.hit_mean        = hit_mean;
    outs.fa_mean         = fa_mean;
    outs.hit_sem         = hit_sem;
    outs.fa_sem          = fa_sem;
    outs.subject_hitMat  = hitMat;
    outs.subject_faMat   = faMat;
    outs.files           = files;
end

% ---------- Helper ----------
function val = correctRate_clip(hr, eps)
% Clamp rate slightly away from 0 and 1
    val = min(max(hr, eps), 1 - eps);
end