function plotTripleIntergroupBar(ac, ab, bc, condition, trial_type, baseDir)
% plotTripleIntergroupBar
%   Compare intergroup itemwise correlations (raw & attenuation-corrected)
%   for three group pairs, optionally with bootstrap error bars.
%
%   Inputs:
%     ac, ab, bc : outputs from bootstrapIntergroupItemwiseCorrelation
%     condition  : string condition label (e.g. 'Globalized-Music')
%     trial_type : 'hit' or 'fa'
%     baseDir    : base directory for saving figure
%
%   Bryan Medina ? Bolivia 2025

    % -----------------------------
    % prepare data
    % -----------------------------
    pairs = {'Boston?San Borja','Boston?Tsimane','Tsimane?San Borja'};
    x = 1:3; w = 0.35;

    rawVals  = [ac.r_raw,  ab.r_raw,  bc.r_raw];
    corrVals = [ac.r_corrected, ab.r_corrected, bc.r_corrected];

    % optional SEM / CI if bootstrapped
    if isfield(ac,'sem_raw')
        semRaw  = [ac.sem_raw,  ab.sem_raw,  bc.sem_raw];
        semCorr = [ac.sem_corr, ab.sem_corr, bc.sem_corr];
    else
        semRaw  = nan(1,3);
        semCorr = nan(1,3);
    end

    % -----------------------------
    % plot
    % -----------------------------
    figure('Color','w','Position',[100 100 650 400]); hold on;
    b1 = bar(x-w/2, rawVals,  w, 'FaceColor',[0.7 0.8 1.0], 'EdgeColor','none');
    b2 = bar(x+w/2, corrVals, w, 'FaceColor',[0.3 0.55 0.9], 'EdgeColor','none');

    % error bars if available
    if any(~isnan(semRaw))
        errorbar(x-w/2, rawVals, semRaw, 'k', 'LineStyle','none', 'LineWidth',1.3);
        errorbar(x+w/2, corrVals, semCorr, 'k', 'LineStyle','none', 'LineWidth',1.3);
    elseif isfield(ac,'ci_raw')
        % optional 95% CI bars
        ciRawLow  = [ac.ci_raw(1),  ab.ci_raw(1),  bc.ci_raw(1)];
        ciRawHigh = [ac.ci_raw(2),  ab.ci_raw(2),  bc.ci_raw(2)];
        ciCorrLow  = [ac.ci_corr(1), ab.ci_corr(1), bc.ci_corr(1)];
        ciCorrHigh = [ac.ci_corr(2), ab.ci_corr(2), bc.ci_corr(2)];
        errorbar(x-w/2, rawVals, rawVals-ciRawLow, ciRawHigh-rawVals, ...
            'k','LineStyle','none','LineWidth',1.3);
        errorbar(x+w/2, corrVals, corrVals-ciCorrLow, ciCorrHigh-corrVals, ...
            'k','LineStyle','none','LineWidth',1.3);
    end

    % axes & labels
    set(gca,'XTick',x,'XTickLabel',pairs,'FontSize',12);
    xtickangle(15);
    ylabel('Itemwise Spearman correlation (r)');
    title(sprintf('Intergroup Itemwise %s Correlations ? %s', upper(trial_type), condition));
    % --- determine y-limits dynamically including error bars ---
    allY = [rawVals, corrVals];
    if any(~isnan(semRaw))
        upperErr = [rawVals + semRaw, corrVals + semCorr];
    elseif exist('ciRawHigh','var')
        upperErr = [ciRawHigh, ciCorrHigh];
    else
        upperErr = allY;
    end

    yMax = max(upperErr,[],'all','omitnan');
    yMax = yMax * 1.15;  % add 15% padding
    ylim([0 yMax]);
    grid on; box off;
    legend({'Raw','Atten.-Corrected'},'Location','northoutside','Orientation','horizontal');
    
    % annotate text above bars
    for i = 1:numel(x)
        text(x(i)-w/2, rawVals(i)+0.025, sprintf('%.2f', rawVals(i)), ...
            'HorizontalAlignment','center', 'FontWeight','bold', 'FontSize',10);
        text(x(i)+w/2, corrVals(i)+0.025, sprintf('%.2f', corrVals(i)), ...
            'HorizontalAlignment','center', 'FontWeight','bold', 'FontSize',10);
    end

    hold off;

    % -----------------------------
    % save figure
    % -----------------------------
    outDir = UTILS_buildOutputDir(baseDir, condition);
    fname = sprintf('triple_intergroup_%s_%s.png', trial_type, condition);
    saveas(gcf, fullfile(outDir, fname));
    fprintf('Saved triple intergroup correlation plot to %s\n', fullfile(outDir, fname));

    % -----------------------------
    % optional console summary
    % -----------------------------
    fprintf('\n=== Intergroup %s correlations (%s) ===\n', upper(trial_type), condition);
    for i = 1:3
        fprintf('%s:\t r = %.3f (corr = %.3f)\n', pairs{i}, rawVals(i), corrVals(i));
    end
end