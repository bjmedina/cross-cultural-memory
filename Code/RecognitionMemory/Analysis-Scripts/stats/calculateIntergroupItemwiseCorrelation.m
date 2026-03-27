function outs = calculateIntergroupItemwiseCorrelation(outsA, outsB, trialType, varargin)
% calculateIntergroupItemwiseCorrelation
%   Compute itemwise intergroup correlations for hit or false-alarm rates.
%   Handles attenuation correction using reliability from participant- or stimulus-split.
%
%   outs = calculateIntergroupItemwiseCorrelation(outsA, outsB, trialType, ...)
%
%   Inputs:
%     outsA, outsB  - structs from calculateSplitHalfReliability (new version)
%     trialType     - 'hit' or 'fa' (case-insensitive)
%
%   Optional Name/Value pairs:
%     'UseSpearman' - true/false (default = true)
%     'ApplyAttenuationCorrection' - true/false (default = false)
%     'ShowPlot'    - true/false (default = true)
%
%   Output fields:
%     outs.r_raw, outs.r_corrected, outs.pval
%     outs.shared_items, outs.valuesA, outs.valuesB
%     outs.reliability_A, outs.reliability_B, outs.geomRel
%
%   Bryan Medina ? Bolivia 2025

    % -----------------------------
    % 1) Parse options
    % -----------------------------
    p = inputParser;
    addParameter(p, 'UseSpearman', true, @islogical);
    addParameter(p, 'ApplyAttenuationCorrection', false, @islogical);
    addParameter(p, 'ShowPlot', true, @islogical);
    parse(p, varargin{:});

    useSpearman = p.Results.UseSpearman;
    doAttenCorr = p.Results.ApplyAttenuationCorrection;
    showPlot    = p.Results.ShowPlot;

    trialType = lower(trialType);
    validTypes = {'hit','fa'};
    assert(ismember(trialType, validTypes), 'trialType must be ''hit'' or ''fa''.');

    % -----------------------------
    % 2) Extract itemwise data
    % -----------------------------
    switch trialType
        case 'hit'
            dataA = outsA.itemwise_hits;
            dataB = outsB.itemwise_hits;
            relA  = outsA.r_hit;
            relB  = outsB.r_hit;
        case 'fa'
            dataA = outsA.itemwise_fas;
            dataB = outsB.itemwise_fas;
            relA  = outsA.r_fa;
            relB  = outsB.r_fa;
    end

    % Average across participants
    meanA = nanmean(dataA, 1);
    meanB = nanmean(dataB, 1);

    % Align shared items
    [sharedItems, ia, ib] = intersect(outsA.items, outsB.items, 'stable');
    valsA = meanA(ia);
    valsB = meanB(ib);
    mask = ~isnan(valsA) & ~isnan(valsB);
    valsA = valsA(mask);
    valsB = valsB(mask);
    sharedItems = sharedItems(mask);

    if numel(sharedItems) < 5
        warning('Too few shared items for reliable correlation (N=%d).', numel(sharedItems));
        outs = struct(); return;
    end

    % -----------------------------
    % 3) Compute correlation
    % -----------------------------
    method = ternary(useSpearman, 'Spearman', 'Pearson');
    [r_raw, pval] = corr(valsA', valsB', 'Type', method, 'Rows','pairwise');

    % Optional attenuation correction (using *raw* reliabilities)
    if doAttenCorr
        if any(isnan([relA, relB])) || relA <= 0 || relB <= 0
            warning('Reliabilities missing or invalid ? cannot apply correction.');
            r_corr = NaN;
            geomRel = NaN;
        else
            geomRel = sqrt(relA * relB);
            r_corr = r_raw / geomRel;
        end
    else
        r_corr = NaN;
        geomRel = NaN;
    end

    % -----------------------------
    % 4) Plot
    % -----------------------------
    if showPlot
        figure('Color', 'w');
        scatter(valsA, valsB, 45, 'filled', 'MarkerFaceAlpha', 0.7);
        hold on;
        lsline;
        xlabel(sprintf('Group A mean %s rate', trialType));
        ylabel(sprintf('Group B mean %s rate', trialType));

        % label split type in title
        if isfield(outsA,'splitLabel')
            splitLabel = sprintf(' (%s split)', outsA.splitLabel);
        else
            splitLabel = '';
        end
        title(sprintf('Intergroup Itemwise %s Correlation%s (N=%d)', ...
            upper(trialType), splitLabel, numel(sharedItems)));

        grid on; axis square;

        % annotate text box
        txt = sprintf('r = %.3f', r_raw);
        if doAttenCorr && ~isnan(r_corr)
            txt = sprintf('%s\nr_{corr} = %.3f\ngeomRel = %.3f', ...
                txt, r_corr, geomRel);
        end
        text(0.05, 0.95, txt, 'Units','normalized', ...
             'FontWeight','bold', 'VerticalAlignment','top', ...
             'FontSize', 11, 'BackgroundColor',[1 1 1 0.65], 'Margin', 4);
        hold off;
    end

    % -----------------------------
    % 5) Package outputs
    % -----------------------------
    outs = struct();
    outs.r_raw        = r_raw;
    outs.r_corrected  = r_corr;
    outs.pval         = pval;
    outs.shared_items = sharedItems;
    outs.nItems       = numel(sharedItems);
    outs.valuesA      = valsA;
    outs.valuesB      = valsB;
    outs.reliability_A = relA;
    outs.reliability_B = relB;
    outs.geomRel       = geomRel;
    outs.splitType     = ternary(isfield(outsA,'splitLabel'), outsA.splitLabel, 'unknown');
end
