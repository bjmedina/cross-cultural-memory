function outs = bootstrapIntergroupItemwiseCorrelation(outsA, outsB, trialType, varargin)
% bootstrapIntergroupItemwiseCorrelation
%   Bootstrap SEM / CI for intergroup itemwise correlations with optional
%   attenuation correction using reliabilities estimated in outsA/outsB.
%   If multiple intergroup results are passed via 'CompareTo', performs
%   bootstrap difference tests between them.
%
%   Bryan Medina ? Bolivia 2025

    % -----------------------------
    % Parameters
    % -----------------------------
    p = inputParser;
    addParameter(p, 'nBoot', 1000, @isscalar);
    addParameter(p, 'UseSpearman', true, @islogical);
    addParameter(p, 'ApplyAttenuationCorrection', false, @islogical);
    addParameter(p, 'ShowPlot', true, @islogical);
    addParameter(p, 'CompareTo', {}, @(x) iscell(x) || isempty(x));  % optional comparisons
    parse(p, varargin{:});
    nBoot     = p.Results.nBoot;
    useSpearman = p.Results.UseSpearman;
    doAttenCorr = p.Results.ApplyAttenuationCorrection;
    showPlot  = p.Results.ShowPlot;
    compareTo = p.Results.CompareTo;

    trialType = lower(trialType);
    assert(ismember(trialType, {'hit','fa'}), 'trialType must be ''hit'' or ''fa''.');

    % -----------------------------
    % Extract itemwise data
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

    meanA = nanmean(dataA, 1);
    meanB = nanmean(dataB, 1);

    [sharedItems, ia, ib] = intersect(outsA.items, outsB.items, 'stable');
    valsA = meanA(ia);
    valsB = meanB(ib);
    mask = ~isnan(valsA) & ~isnan(valsB);
    valsA = valsA(mask);
    valsB = valsB(mask);
    sharedItems = sharedItems(mask);

    nItems = numel(sharedItems);
    if nItems < 5
        warning('Too few shared items for reliable bootstrap (N=%d).', nItems);
        outs = struct(); return;
    end

    % -----------------------------
    % Base correlation + parametric p-value
    % -----------------------------
    method = ternary(useSpearman, 'Spearman', 'Pearson');
    [r_raw, pval_param] = corr(valsA(:), valsB(:), 'Type', method, 'Rows','pairwise');

    % Optional attenuation correction
    if doAttenCorr
        geomRel = sqrt(relA * relB);
        if any(isnan([relA relB])) || geomRel <= 0
            warning('Invalid reliabilities; skipping correction.');
            geomRel = NaN; r_corr = NaN;
        else
            r_corr = r_raw / geomRel;
        end
    else
        geomRel = NaN; r_corr = NaN;
    end

    % -----------------------------
    % Bootstrap procedure
    % -----------------------------
    rng('shuffle');
    boot_r_raw = nan(nBoot,1);
    boot_r_corr = nan(nBoot,1);

    for b = 1:nBoot
        idx = randi(nItems, [nItems 1]);
        vA = valsA(idx);
        vB = valsB(idx);

        rb = corr(vA(:), vB(:), 'Type', method, 'Rows','pairwise');
        boot_r_raw(b) = rb;

        if doAttenCorr && ~isnan(geomRel)
            boot_r_corr(b) = rb / geomRel;
        end
    end

    % summary stats
    ci_raw = prctile(boot_r_raw, [2.5 97.5]);
    sem_raw = std(boot_r_raw, 'omitnan');
    if doAttenCorr
        ci_corr = prctile(boot_r_corr, [2.5 97.5]);
        sem_corr = std(boot_r_corr, 'omitnan');
    else
        ci_corr = [NaN NaN]; sem_corr = NaN;
    end

    % -----------------------------
    % Bootstrap significance (is r > 0?)
    % -----------------------------
    p_boot = 2 * min( mean(boot_r_raw > 0), mean(boot_r_raw < 0) );

    % -----------------------------
    % Compare to other intergroup results if provided
    % -----------------------------
    compResults = struct();
    if ~isempty(compareTo)
        for c = 1:numel(compareTo)
            cmp = compareTo{c};
            % choose same length
            nCmp = min(numel(boot_r_raw), numel(cmp.boot_dist_raw));
            diffDist = boot_r_raw(1:nCmp) - cmp.boot_dist_raw(1:nCmp);
            pDiff = 2 * min( mean(diffDist > 0), mean(diffDist < 0) );
            ciDiff = prctile(diffDist, [2.5 97.5]);
            compResults(c).name = sprintf('vs_%d', c);
            compResults(c).p_value = pDiff;
            compResults(c).diff_mean = mean(diffDist, 'omitnan');
            compResults(c).ci_diff = ciDiff;
        end
    end

    % -----------------------------
    % Plot
    % -----------------------------
    if showPlot
        figure('Color','w'); hold on;
        histogram(boot_r_raw, 30, 'FaceAlpha',0.7, 'FaceColor',[0.2 0.4 0.7], 'EdgeColor','none');
        xline(r_raw, 'r--', 'LineWidth', 2, 'DisplayName','Observed r');
        xlabel('Bootstrapped r'); ylabel('Frequency');
        title(sprintf('Bootstrap Intergroup %s Correlation (%s, p=%.3f)', ...
            upper(trialType), method, p_boot));
        grid on;
        if doAttenCorr
            xline(r_corr, 'k-', 'LineWidth', 2, 'DisplayName','Atten.-corrected');
            legend('boot r', 'raw r', 'r_{corr}');
        else
            legend('boot r', 'raw r');
        end
        hold off;
    end

    % -----------------------------
    % Package outputs
    % -----------------------------
    outs = struct();
    outs.trialType       = trialType;
    outs.method          = method;
    outs.nItems          = nItems;
    outs.r_raw           = r_raw;
    outs.r_corrected     = r_corr;
    outs.geomRel         = geomRel;
    outs.pval_param      = pval_param;
    outs.pval_boot       = p_boot;
    outs.boot_dist_raw   = boot_r_raw;
    outs.boot_dist_corr  = boot_r_corr;
    outs.ci_raw          = ci_raw;
    outs.ci_corr         = ci_corr;
    outs.sem_raw         = sem_raw;
    outs.sem_corr        = sem_corr;
    outs.reliability_A   = relA;
    outs.reliability_B   = relB;
    outs.shared_items    = sharedItems;
    outs.compareResults  = compResults;   % p-values vs other intergroup results
end

% function outs = bootstrapIntergroupItemwiseCorrelation(outsA, outsB, trialType, varargin)
% % bootstrapIntergroupItemwiseCorrelation
% %   Bootstrap SEM / CI for intergroup itemwise correlations with optional
% %   attenuation correction using reliabilities estimated in outsA/outsB.
% %
% %   Bryan Medina ? Bolivia 2025
% 
%     % -----------------------------
%     % Parameters
%     % -----------------------------
%     p = inputParser;
%     addParameter(p, 'nBoot', 1000, @isscalar);
%     addParameter(p, 'UseSpearman', true, @islogical);
%     addParameter(p, 'ApplyAttenuationCorrection', false, @islogical);
%     addParameter(p, 'ShowPlot', true, @islogical);
%     parse(p, varargin{:});
%     nBoot     = p.Results.nBoot;
%     useSpearman = p.Results.UseSpearman;
%     doAttenCorr = p.Results.ApplyAttenuationCorrection;
%     showPlot  = p.Results.ShowPlot;
% 
%     trialType = lower(trialType);
%     assert(ismember(trialType, {'hit','fa'}), 'trialType must be ''hit'' or ''fa''.');
% 
%     % -----------------------------
%     % Extract itemwise data
%     % -----------------------------
%     switch trialType
%         case 'hit'
%             dataA = outsA.itemwise_hits;
%             dataB = outsB.itemwise_hits;
%             relA  = outsA.r_hit;
%             relB  = outsB.r_hit;
%         case 'fa'
%             dataA = outsA.itemwise_fas;
%             dataB = outsB.itemwise_fas;
%             relA  = outsA.r_fa;
%             relB  = outsB.r_fa;
%     end
% 
%     meanA = nanmean(dataA, 1);
%     meanB = nanmean(dataB, 1);
% 
%     [sharedItems, ia, ib] = intersect(outsA.items, outsB.items, 'stable');
%     valsA = meanA(ia);
%     valsB = meanB(ib);
%     mask = ~isnan(valsA) & ~isnan(valsB);
%     valsA = valsA(mask);
%     valsB = valsB(mask);
%     sharedItems = sharedItems(mask);
% 
%     nItems = numel(sharedItems);
%     if nItems < 5
%         warning('Too few shared items for reliable bootstrap (N=%d).', nItems);
%         outs = struct(); return;
%     end
% 
%     % -----------------------------
%     % Base correlation
%     % -----------------------------
%     method = ternary(useSpearman, 'Spearman', 'Pearson');
%     Rmat = corr([valsA(:), valsB(:)], 'Type', method, 'Rows','pairwise');
%     r_raw = Rmat(1,2);
%     pval = NaN; % (not computed by corr with two columns)
% 
%     % Optional attenuation correction
%     if doAttenCorr
%         geomRel = sqrt(relA * relB);
%         if any(isnan([relA relB])) || geomRel <= 0
%             warning('Invalid reliabilities; skipping correction.');
%             geomRel = NaN; r_corr = NaN;
%         else
%             r_corr = r_raw / geomRel;
%         end
%     else
%         geomRel = NaN; r_corr = NaN;
%     end
% 
%     % -----------------------------
%     % Bootstrap procedure
%     % -----------------------------
%     rng('shuffle');
%     boot_r_raw = nan(nBoot,1);
%     boot_r_corr = nan(nBoot,1);
% 
%     for b = 1:nBoot
%         idx = randi(nItems, [nItems 1]);
%         vA = valsA(idx);
%         vB = valsB(idx);
% 
%         vA = vA(:); vB = vB(:);
%         rmat = corr([vA, vB], 'Type', method, 'Rows','pairwise');
%         rb = rmat(1,2);
% 
%         boot_r_raw(b) = rb;
% 
%         if doAttenCorr && ~isnan(geomRel)
%             boot_r_corr(b) = rb / geomRel;
%         end
%     end
% 
%     % summary stats
%     ci_raw = prctile(boot_r_raw, [2.5 97.5]);
%     sem_raw = std(boot_r_raw, 'omitnan');
%     if doAttenCorr
%         ci_corr = prctile(boot_r_corr, [2.5 97.5]);
%         sem_corr = std(boot_r_corr, 'omitnan');
%     else
%         ci_corr = [NaN NaN]; sem_corr = NaN;
%     end
% 
%     % -----------------------------
%     % Plot
%     % -----------------------------
%     if showPlot
%         figure('Color','w'); hold on;
%         histogram(boot_r_raw, 30, 'FaceAlpha',0.7, 'FaceColor',[0.2 0.4 0.7], 'EdgeColor','none');
%         xline(r_raw, 'r--', 'LineWidth', 2, 'DisplayName','Observed r');
%         xlabel('Bootstrapped r'); ylabel('Frequency');
%         title(sprintf('Bootstrap Intergroup %s Correlation (%s)', ...
%             upper(trialType), method));
%         grid on;
%         if doAttenCorr
%             xline(r_corr, 'k-', 'LineWidth', 2, 'DisplayName','Atten.-corrected');
%             legend('boot r', 'raw r', 'r_{corr}');
%         else
%             legend('boot r', 'raw r');
%         end
%         hold off;
%     end
% 
%     % -----------------------------
%     % Package outputs
%     % -----------------------------
%     outs = struct();
%     outs.trialType       = trialType;
%     outs.method          = method;
%     outs.nItems          = nItems;
%     outs.r_raw           = r_raw;
%     outs.r_corrected     = r_corr;
%     outs.geomRel         = geomRel;
%     outs.pval            = pval;
%     outs.boot_dist_raw   = boot_r_raw;
%     outs.boot_dist_corr  = boot_r_corr;
%     outs.ci_raw          = ci_raw;
%     outs.ci_corr         = ci_corr;
%     outs.sem_raw         = sem_raw;
%     outs.sem_corr        = sem_corr;
%     outs.reliability_A   = relA;
%     outs.reliability_B   = relB;
%     outs.shared_items    = sharedItems;
% end