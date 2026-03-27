function plotAggregateDprime_twoCurves(baseDir, placeCodes, condition, minISI0dprime)
% plotAggregateDprime_twoCurves
%   Wrapper that loads recognition-memory data via UTILS_getRecognitionMemFiles
%   and plots a single figure with p1 and p2 aggregate d? curves.
%
%   plotAggregateDprime_twoCurves(baseDir, placeCodes, condition, minISI0dprime, isMultiISI)
%
%   Inputs:
%     baseDir         - folder containing .mat files
%     placeCodes      - e.g., {'BOS','CAM'} or {'ALL'}
%     condition       - string, e.g., 'Industrial-Nature'
%     minISI0dprime   - minimum d? at ISI=0 (or avg of 0&1 if multi-ISI)
%     isMultiISI      - true = multi-ISI dataset
%
%   Bryan Medina ? Nov 2025

    % --- Gather data
    [f, outs] = UTILS_getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime, true);

    dprimeP1 = outs.dprimeP1;
    dprimeP2 = outs.dprimeP2;

    if isempty(dprimeP1) && isempty(dprimeP2)
        warning('No data found matching criteria.');
        return;
    end

    % ----- Determine ISIs from whichever set is nonempty -----
    if ~isempty(dprimeP1)
        nPos = size(dprimeP1, 2);
    else
        nPos = size(dprimeP2, 2);
    end

    % Convert repeat positions ? ISIs
    % NOTE: repeatPosition==1 ? ISI=0
    ISIs = (1:nPos) - 1;

    % ----- Plot -----
    figure('Color','w'); hold on;

    % P1
    if ~isempty(dprimeP1)
        m1 = nanmean(dprimeP1,1);
        s1 = nanstd(dprimeP1,[],1) ./ sqrt(sum(~isnan(dprimeP1),1));
        fill([ISIs fliplr(ISIs)], [m1+s1 fliplr(m1-s1)], ...
             [0.7 0.8 1], 'EdgeColor','none', 'FaceAlpha',0.3);
        plot(ISIs, m1, 'b-o', 'LineWidth',1.8, 'MarkerFaceColor','b', 'DisplayName','p1');
    end

    % P2
    if ~isempty(dprimeP2)
        m2 = nanmean(dprimeP2,1);
        s2 = nanstd(dprimeP2,[],1) ./ sqrt(sum(~isnan(dprimeP2),1));
        fill([ISIs fliplr(ISIs)], [m2+s2 fliplr(m2-s2)], ...
             [1 0.8 0.8], 'EdgeColor','none', 'FaceAlpha',0.3);
        plot(ISIs, m2, 'r-o', 'LineWidth',1.8, 'MarkerFaceColor','r', 'DisplayName','p2');
    end

    xlabel('ISI (trials)');
    ylabel('d?');
    title(sprintf('%s ? mean d? curves (p1 vs p2)', condition), 'Interpreter','none');
    legend('show','Location','best');
    grid on; box on;

    % Subject counts
    text(0.98, 0.02, sprintf('n_{p1}=%d, n_{p2}=%d', size(dprimeP1,1), size(dprimeP2,1)), ...
        'Units','normalized', 'HorizontalAlignment','right', 'VerticalAlignment','bottom');
end