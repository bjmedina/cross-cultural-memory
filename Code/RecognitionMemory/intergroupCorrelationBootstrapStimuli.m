function [rBoot, summary, itemsShared] = intergroupCorrelationBootstrapStimuli( ...
    baseDir, placeCodesA, placeCodesB, condition, minISI0dprime, trialType, varargin)
% intergroupCorrelationBootstrapStimuli
%   Bootstraps inter-group itemwise correlation by resampling *stimuli*.
%
% Steps:
%   1. Load participant × item response matrices for each group.
%   2. Compute item-level means for each group.
%   3. Bootstrap across stimuli (resample item indices with replacement).
%   4. Compute Spearman correlation for each bootstrap.
%
% Inputs:
%   baseDir, placeCodesA/B, condition, minISI0dprime, trialType
%
% Optional name/value:
%   'NBoot'   : number of bootstrap samples (default = 1000)
%   'RngSeed' : integer for reproducibility (default = [])
%
% Outputs:
%   rBoot       : nBoot × 1 vector of Spearman correlations
%   summary     : struct with r_true, r_mean, r_median, r_ci
%   itemsShared : shared stimulus IDs
%
% Bryan Medina ? Oct 2025

    % ---------- optional args ----------
    p = inputParser;
    addParameter(p, 'NBoot', 1000, @(x)isnumeric(x) && isscalar(x) && x>1);
    addParameter(p, 'RngSeed', [], @(x)isempty(x) || isnumeric(x));
    parse(p, varargin{:});
    nBoot = p.Results.NBoot;
    if ~isempty(p.Results.RngSeed)
        rng(p.Results.RngSeed);
    end

    % ---------- get files ----------
    filesA = getRecognitionMemFiles(baseDir, placeCodesA, condition, minISI0dprime);
    filesB = getRecognitionMemFiles(baseDir, placeCodesB, condition, minISI0dprime);
    if isempty(filesA) || isempty(filesB)
        warning('No files for one or both groups.');
        rBoot = nan(nBoot,1); summary = struct(); itemsShared = string([]); return;
    end

    % ---------- shared items ----------
    itemsA = unionOfItems(filesA, trialType);
    itemsB = unionOfItems(filesB, trialType);
    [itemsShared, ~, ~] = intersect(itemsA, itemsB, 'stable');
    nItems = numel(itemsShared);
    if nItems < 3
        warning('Too few shared items.');
        rBoot = nan(nBoot,1); summary = struct(); return;
    end

    % ---------- participant × item matrices ----------
    Ra = participantItemRates(filesA, itemsShared, trialType);
    Rb = participantItemRates(filesB, itemsShared, trialType);

    % ---------- compute per-item means ----------
    meanA = mean(Ra, 'omitnan');
    meanB = mean(Rb, 'omitnan');

    valid = ~isnan(meanA) & ~isnan(meanB);
    meanA = meanA(valid);
    meanB = meanB(valid);
    nItemsValid = numel(meanA);

    if nItemsValid < 3
        warning('Too few valid items for correlation.');
        rBoot = nan(nBoot,1); summary = struct(); return;
    end

    % Ensure column vectors for safety
    meanA = meanA(:);
    meanB = meanB(:);
%     
%     disp(itemsShared(1:10))
%     disp(itemsA(1:10))
%     disp(itemsB(1:10))

    % ---------- true correlation ----------
    r_true = corr(meanA, meanB, 'type', 'Spearman', 'rows', 'pairwise');

    % ---------- bootstrap across stimuli ----------
    rBoot = nan(nBoot,1);
    for b = 1:nBoot
        idx = randi(nItemsValid, [nItemsValid, 1]);  % resample items
        xa = meanA(idx);
        xb = meanB(idx);
        if numel(unique(xa)) > 1 && numel(unique(xb)) > 1
            rBoot(b) = corr(xa, xb, 'type', 'Spearman', 'rows', 'pairwise');
        else
            rBoot(b) = NaN; % skip degenerate draws
        end
        
        %display(rBoot(b));
    end

    % ---------- summarize ----------
    summary = struct();
    summary.r_true   = r_true;
    summary.r_mean   = mean(rBoot, 'omitnan');
    summary.r_median = median(rBoot, 'omitnan');
    summary.r_ci     = quantile(rBoot(~isnan(rBoot)), [0.025 0.975]);

    % ---------- diagnostic plot ----------
    figure('Color','w');
    histogram(rBoot, 'BinWidth',0.02, 'FaceAlpha',0.7);
    xlabel('Inter-group correlation (Spearman)');
    ylabel('Count');
    title(sprintf('Intergroup correlation ? %s (%s)', ...
        condition, trialType), 'Interpreter','none');
    grid on;
    xline(summary.r_true, 'r-', 'LineWidth',1.5, ...
        'Label', sprintf('true = %.3f', summary.r_true), ...
        'LabelOrientation','horizontal', 'LabelVerticalAlignment','bottom');
end