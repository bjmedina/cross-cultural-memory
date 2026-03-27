function plotTripleIntergroupBar(ac, ab, bc, condition, trial_type, baseDir)
% plotTripleIntergroupBar
%   Bar plot comparing raw and attenuation-corrected intergroup correlations.

    figure('Color','w'); hold on;

    labels = {'Boston?San Borja','Boston?Tsimane','Tsimane?San Borja'};
    x = 1:3;
    w = 0.35;

    rawVals  = [ac.r_raw,  ab.r_raw,  bc.r_raw];
    corrVals = [ac.r_corrected, ab.r_corrected, bc.r_corrected];

    % plot bars
    b1 = bar(x-w/2, rawVals,  w, 'FaceColor',[0.6 0.7 0.9], 'EdgeColor','none');
    b2 = bar(x+w/2, corrVals, w, 'FaceColor',[0.3 0.5 0.8], 'EdgeColor','none');

    % labels and style
    set(gca,'XTick',x,'XTickLabel',labels,'FontSize',12);
    ylabel('Itemwise Spearman correlation (r)');
    title(sprintf('Intergroup Itemwise Correlations on %s ? %s', trial_type, condition));
    %ylim([0 1.2]); 
    grid on; box off;
    legend({'Raw','Corrected'},'Location','northoutside','Orientation','horizontal');
    
    outDir = UTILS_buildOutputDir(baseDir, condition);
    fname = sprintf('%s_intergroup_correlation_%s.png', ...
        trial_type, condition);
    saveas(gcf, fullfile(outDir, fname));
    fprintf('Saved plot to %s\n', fullfile(outDir, fname));

    % annotate values
    for i = 1:numel(x)
        text(x(i)-w/2, rawVals(i)+0.03, sprintf('%.2f', rawVals(i)), ...
            'HorizontalAlignment','center', 'FontWeight','bold', 'FontSize',10);
        text(x(i)+w/2, corrVals(i)+0.03, sprintf('%.2f', corrVals(i)), ...
            'HorizontalAlignment','center', 'FontWeight','bold', 'FontSize',10);
    end
    hold off;
end