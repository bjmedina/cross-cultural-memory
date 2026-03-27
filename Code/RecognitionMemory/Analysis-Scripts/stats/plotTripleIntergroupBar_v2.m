function plotTripleIntergroupBar_v2(ac, ab, bc, condition, trial_type, baseDir)
% plotTripleIntergroupBar_v2
%   Compare intergroup itemwise correlations (raw & attenuation-corrected)
%   using SEMs from simulated distributions.
%
%   Automatically saves to a subfolder labeled by the simulation level
%   (e.g., "participant_splits" or "stimulus_splits").
%
%   Bryan Medina ? Bolivia 2025

    % -----------------------------
    % determine split level (participant vs stimulus)
    % -----------------------------
    if isfield(ac,'level')
        level = ac.level;
    else
        level = 'unknown';
    end

    % -----------------------------
    % prepare data
    % -----------------------------
    pairs = {'Boston?San Borja','Boston?Tsimane','Tsimane?San Borja'};
    x = 1:3; w = 0.35;

    rawVals  = [ac.r_raw,  ab.r_raw,  bc.r_raw];
    corrVals = [ac.r_corrected, ab.r_corrected, bc.r_corrected];
    semRaw   = [ac.sem_raw,  ab.sem_raw,  bc.sem_raw];
    semCorr  = [ac.sem_corr, ab.sem_corr, bc.sem_corr];

    % -----------------------------
    % figure setup
    % -----------------------------
    figure('Color','w','Position',[100 100 750 480]); hold on;

    % bars
    bar(x-w/2, rawVals,  w, 'FaceColor',[0.7 0.8 1.0], 'EdgeColor','none');
    bar(x+w/2, corrVals, w, 'FaceColor',[0.3 0.55 0.9], 'EdgeColor','none');

    % SEM error bars
    errorbar(x-w/2, rawVals, semRaw, 'k', 'LineStyle','none', 'LineWidth',1.3);
    errorbar(x+w/2, corrVals, semCorr, 'k', 'LineStyle','none', 'LineWidth',1.3);

    % -----------------------------
    % formatting
    % -----------------------------
    set(gca,'XTick',x,'XTickLabel',pairs,'FontSize',12);
    xtickangle(15);
    ylabel('Itemwise Spearman correlation (r)');
    title(sprintf('Intergroup Itemwise %s Correlations ? %s (%s-level)', ...
        upper(trial_type), condition, level));

    % auto y-limits
    yMax = max([rawVals + semRaw, corrVals + semCorr], [], 'all', 'omitnan') * 1.3;
    ylim([0 yMax]);
    grid on; box off;
    legend({'Raw','Atten.-Corrected'},'Location','northoutside','Orientation','horizontal');

    % -----------------------------
    % annotate text above bars
    % -----------------------------
    for i = 1:numel(x)
        text(x(i)-w/2, rawVals(i)+semRaw(i)+0.02*yMax, sprintf('%.2f', rawVals(i)), ...
            'HorizontalAlignment','center', 'FontWeight','bold', 'FontSize',10);
        text(x(i)+w/2, corrVals(i)+semCorr(i)+0.02*yMax, sprintf('%.2f', corrVals(i)), ...
            'HorizontalAlignment','center', 'FontWeight','bold', 'FontSize',10);
    end

    % -----------------------------
    % save figure
    % -----------------------------
    if nargin > 5 && ~isempty(baseDir)
        %outDir = fullfile(baseDir, sprintf('figures_%s_splits', level));
        outDir = UTILS_buildOutputDir(baseDir, condition);
        if ~exist(outDir, 'dir'), mkdir(outDir); end
        fname = sprintf('triple_intergroup_%s_%s_%s_SEM.png', trial_type, condition, level);
        saveas(gcf, fullfile(outDir, fname));
        fprintf('Saved SEM plot to %s\n', fullfile(outDir, fname));
    end

    % -----------------------------
    % console summary
    % -----------------------------
    fprintf('\n=== Intergroup %s correlations (%s, %s-level) ===\n', ...
        upper(trial_type), condition, level);
    for i = 1:3
        fprintf('%s:\t r = %.3f ± %.3f (corr = %.3f ± %.3f)\n', ...
            pairs{i}, rawVals(i), semRaw(i), corrVals(i), semCorr(i));
    end
end