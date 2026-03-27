function outs = simulateIntergroupItemwiseCorrelation(outsA, outsB, trialType, varargin)
% simulateIntergroupItemwiseCorrelation
%   Simulation-based CI for intergroup itemwise correlations using 
%   equal-coverage resampling at either participant or stimulus level.
%
%   'SubsampleLevel' : 'participant' (default) or 'stimulus'
%
%   Bryan Medina ? Bolivia 2025

    % -----------------------------
    % Parameters
    % -----------------------------
    p = inputParser;
    addParameter(p, 'nSim', 1000, @isscalar);
    addParameter(p, 'nEqual', 10, @isscalar);
    addParameter(p, 'UseSpearman', true, @islogical);
    addParameter(p, 'ApplyAttenuationCorrection', false, @islogical);
    addParameter(p, 'ShowPlot', true, @islogical);
    addParameter(p, 'SubsampleLevel', 'participant', ...
        @(s) any(strcmpi(s,{'participant','stimulus'})));
    parse(p, varargin{:});
    nSim        = p.Results.nSim;
    nEqual      = p.Results.nEqual;
    useSpearman = p.Results.UseSpearman;
    doAttenCorr = p.Results.ApplyAttenuationCorrection;
    showPlot    = p.Results.ShowPlot;
    level       = lower(p.Results.SubsampleLevel);

    trialType = lower(trialType);
    assert(ismember(trialType, {'hit','fa'}), 'trialType must be ''hit'' or ''fa''.');

    % -----------------------------
    % Extract itemwise participant data
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

    [sharedItems, ia, ib] = intersect(outsA.items, outsB.items, 'stable');
    dataA = dataA(:, ia);
    dataB = dataB(:, ib);

    % adaptive equal coverage if not given
    if isempty(p.Results.nEqual)
        nEqual = round(median([sum(~isnan(dataA),1) sum(~isnan(dataB),1)], 'all'));
    end

    nItems = numel(sharedItems);
    if nItems < 5
        warning('Too few shared items (N=%d).', nItems);
        outs = struct(); return;
    end

    % -----------------------------
    % Observed correlation (unequal coverage)
    % -----------------------------
    meanA = nanmean(dataA,1);
    meanB = nanmean(dataB,1);
    mask = ~isnan(meanA) & ~isnan(meanB);
    meanA = meanA(mask);
    meanB = meanB(mask);
    sharedItems = sharedItems(mask);
    nItems = numel(sharedItems);

    method = ternary(useSpearman,'Spearman','Pearson');
    [r_raw, pval_param] = corr(meanA(:),meanB(:),'Type',method,'Rows','pairwise');

    % optional attenuation correction
    if doAttenCorr
        geomRel = sqrt(relA*relB);
        if any(isnan([relA relB])) || geomRel<=0
            geomRel=NaN; r_corr=NaN;
        else
            r_corr = r_raw/geomRel;
        end
    else
        geomRel=NaN; r_corr=NaN;
    end

    % -----------------------------
    % Simulation procedure
    % -----------------------------
    rng('shuffle');
    sim_r_raw = nan(nSim,1);
    sim_r_corr= nan(nSim,1);

    [nSubA,~]=size(dataA); [nSubB,~]=size(dataB);

    for s=1:nSim
        switch level
            case 'participant'
                % --- resample participants within each item ---
                simA = nan(1,nItems); simB = nan(1,nItems);
                for i=1:nItems
                    xA=dataA(:,i); xB=dataB(:,i);
                    xA=xA(~isnan(xA)); xB=xB(~isnan(xB));
                    if isempty(xA)||isempty(xB), continue; end
                    idxA=randsample(numel(xA),nEqual,numel(xA)<nEqual);
                    idxB=randsample(numel(xB),nEqual,numel(xB)<nEqual);
                    simA(i)=mean(xA(idxA));
                    simB(i)=mean(xB(idxB));
                end

            case 'stimulus'
                % --- resample items as a whole (bootstrap items) ---
                idxItems = randsample(nItems,nItems,true);
                simA = mean(dataA(:,idxItems),'omitnan');
                simB = mean(dataB(:,idxItems),'omitnan');
        end

        valid=~isnan(simA)&~isnan(simB);
        if sum(valid)>=3
            sim_r_raw(s)=corr(simA(valid)',simB(valid)','Type',method,'Rows','pairwise');
            if doAttenCorr && ~isnan(geomRel)
                sim_r_corr(s)=sim_r_raw(s)/geomRel;
            end
        end
    end

    % -----------------------------
    % Summary stats
    % -----------------------------
    ci_raw   = prctile(sim_r_raw, [2.5 97.5]);
    sem_raw  = std(sim_r_raw, 'omitnan');
    mean_sim = mean(sim_r_raw, 'omitnan');
    median_sim = median(sim_r_raw, 'omitnan');

    if doAttenCorr
        ci_corr   = prctile(sim_r_corr, [2.5 97.5]);
        sem_corr  = std(sim_r_corr, 'omitnan');
        mean_corr = mean(sim_r_corr, 'omitnan');
        median_corr = median(sim_r_corr, 'omitnan');
    else
        ci_corr = [NaN NaN];
        sem_corr = NaN;
        mean_corr = NaN;
        median_corr = NaN;
    end

    % -----------------------------
    % Plot
    % -----------------------------
    if showPlot
        figure('Color','w'); hold on;
        histogram(sim_r_raw, 30, 'FaceAlpha',0.7, 'FaceColor',[0.3 0.4 0.8], 'EdgeColor','none');
        xline(r_raw, 'r--', 'LineWidth', 2, 'DisplayName','Observed r');
        xline(mean_sim, 'k-', 'LineWidth', 2, 'DisplayName','Mean simulated r');
        xlabel('Simulated r'); ylabel('Frequency');
        title(sprintf('Simulated Intergroup %s Correlation (%s-level, %s)', ...
            upper(trialType), level, method));
        legend('sim r','raw r','mean sim r');
        grid on; hold off;
    end

    % -----------------------------
    % Package outputs
    % -----------------------------
    outs = struct();
    outs.trialType      = trialType;
    outs.method         = method;
    outs.level          = level;
    outs.nItems         = nItems;
    outs.r_raw          = r_raw;
    outs.r_corrected    = r_corr;
    outs.r_sim_mean     = mean_sim;
    outs.r_sim_median   = median_sim;
    outs.r_corr_mean    = mean_corr;     % <-- mean of corrected sims
    outs.r_corr_median  = median_corr;   % <-- median of corrected sims
    outs.geomRel        = geomRel;
    outs.ci_raw         = ci_raw;
    outs.ci_corr        = ci_corr;       % <-- corrected CI
    outs.sem_raw        = sem_raw;
    outs.sem_corr       = sem_corr;      % <-- corrected SEM
    outs.reliability_A  = relA;
    outs.reliability_B  = relB;
    outs.shared_items   = sharedItems;
    outs.nEqual         = nEqual;
    outs.nSim           = nSim;

    % store full simulation distributions
    outs.sim_r_raw      = sim_r_raw;
    outs.sim_r_corr     = sim_r_corr;

    fprintf(['Level=%s | Observed r=%.3f | Mean(sim)=%.3f | SEM=%.3f | ', ...
             'Corrected r=%.3f | Mean(sim_corr)=%.3f | SEM_corr=%.3f | ', ...
             '95%% CI=[%.3f, %.3f]\n'], ...
             level, r_raw, mean_sim, sem_raw, r_corr, mean_corr, sem_corr, ci_raw(1), ci_raw(2));
end

% -----------------------------
function out=ternary(cond,a,b)
    if cond,out=a;else,out=b;end
end