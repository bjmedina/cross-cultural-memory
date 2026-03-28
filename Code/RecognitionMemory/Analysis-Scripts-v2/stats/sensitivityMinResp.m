function results = sensitivityMinResp(baseDir, trial_type, condition, ...
    placeCodesA, placeCodesB, placeCodesC, minRespVals)
% sensitivityMinResp
%   Sweep minResp values and show how intergroup correlations and CIs change.
%
%   As minResp increases:
%     - Stimuli with sparse coverage are excluded
%     - Per-stimulus means are based on more observations (less noisy)
%     - But fewer stimuli survive -> correlation based on fewer items
%
%   results = sensitivityMinResp(baseDir, trial_type, condition, ...
%       placeCodesA, placeCodesB, placeCodesC, minRespVals)
%
%   Inputs:
%     baseDir          - folder with .mat files
%     trial_type       - 'hit' or 'fa'
%     condition        - e.g. 'Globalized-Music'
%     placeCodesA/B/C  - cell arrays of site codes
%     minRespVals      - vector of minResp values to test (e.g. [2 3 5 8 10])
%
%   Bryan Medina -- Mar 2026

    % ----- Fixed parameters -----
    minISI0dprime = 2.0;
    isMultiISI    = false;
    nSplits       = 10000;
    splitDim      = 1;
    nBoot         = 5000;

    % ----- Step 1: Split-half reliabilities (computed once) -----
    fprintf('Computing split-half reliabilities...\n');
    outsA = calculateSplitHalfReliability(baseDir, placeCodesA, condition, ...
        minISI0dprime, isMultiISI, nSplits, splitDim, false);
    outsB = calculateSplitHalfReliability(baseDir, placeCodesB, condition, ...
        minISI0dprime, isMultiISI, nSplits, splitDim, false);
    outsC = calculateSplitHalfReliability(baseDir, placeCodesC, condition, ...
        minISI0dprime, isMultiISI, nSplits, splitDim, false);

    close all;

    nVals = numel(minRespVals);
    pairLabels = {'US-San Borja (AB)', 'US-Tsimane'' (AC)', 'San Borja-Tsimane'' (BC)'};

    % Preallocate: [nVals x 3 pairs]
    point_raw = nan(nVals, 3);
    ci_lo     = nan(nVals, 3);
    ci_hi     = nan(nVals, 3);
    nItems    = nan(nVals, 3);

    % ----- Step 2: Sweep minResp -----
    for mi = 1:nVals
        mr = minRespVals(mi);
        fprintf('\n--- minResp = %d ---\n', mr);

        bootOpts = {'BootstrapDim', 1, 'ReliabilityMode', 'per-draw', ...
                    'CorrectAtten', false, 'UseSpearman', true, ...
                    'nBoot', nBoot, 'SplitHalfRepeats', 200, ...
                    'ReliabilitySplitDim', splitDim, ...
                    'minResp', mr, 'Verbose', false};

        ab = bootstrapIntergroupCorrelationSEM(outsA, outsB, trial_type, bootOpts{:});
        ac = bootstrapIntergroupCorrelationSEM(outsA, outsC, trial_type, bootOpts{:});
        bc = bootstrapIntergroupCorrelationSEM(outsB, outsC, trial_type, bootOpts{:});

        close all;

        point_raw(mi,:) = [ab.point_raw, ac.point_raw, bc.point_raw];
        ci_lo(mi,:)     = [ab.ci_raw(1), ac.ci_raw(1), bc.ci_raw(1)];
        ci_hi(mi,:)     = [ab.ci_raw(2), ac.ci_raw(2), bc.ci_raw(2)];
        nItems(mi,:)    = [ab.point_itemsN, ac.point_itemsN, bc.point_itemsN];

        fprintf('  AB: r=%.3f [%.3f, %.3f]  N=%d items\n', ...
            ab.point_raw, ab.ci_raw(1), ab.ci_raw(2), ab.point_itemsN);
        fprintf('  AC: r=%.3f [%.3f, %.3f]  N=%d items\n', ...
            ac.point_raw, ac.ci_raw(1), ac.ci_raw(2), ac.point_itemsN);
        fprintf('  BC: r=%.3f [%.3f, %.3f]  N=%d items\n', ...
            bc.point_raw, bc.ci_raw(1), bc.ci_raw(2), bc.point_itemsN);
    end

    % ----- Step 3: Plot -----
    colors = [0.3 0.55 0.9; 0.9 0.4 0.3; 0.4 0.75 0.4];

    figure('Color','w','Position',[100 100 900 400]);

    % Left panel: correlation +/- CI vs minResp
    subplot(1,2,1); hold on;
    for pi = 1:3
        fill([minRespVals(:); flipud(minRespVals(:))], ...
             [ci_lo(:,pi); flipud(ci_hi(:,pi))], ...
             colors(pi,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none');
        plot(minRespVals, point_raw(:,pi), '-o', 'Color', colors(pi,:), ...
             'LineWidth', 1.5, 'MarkerSize', 6, 'MarkerFaceColor', colors(pi,:));
    end
    xlabel('minResp threshold'); ylabel('Spearman correlation (raw)');
    title(sprintf('%s %s: correlation vs minResp', condition, upper(trial_type)), ...
        'Interpreter', 'none');
    legend(pairLabels, 'Location', 'best');
    grid on; box off;

    % Right panel: number of surviving stimuli vs minResp
    subplot(1,2,2); hold on;
    for pi = 1:3
        plot(minRespVals, nItems(:,pi), '-s', 'Color', colors(pi,:), ...
             'LineWidth', 1.5, 'MarkerSize', 6, 'MarkerFaceColor', colors(pi,:));
    end
    xlabel('minResp threshold'); ylabel('N stimuli surviving filter');
    title('Stimulus count vs minResp');
    legend(pairLabels, 'Location', 'best');
    grid on; box off;

    % Save
    outDir = UTILS_buildOutputDir(baseDir, condition);
    fname = sprintf('sensitivity_minResp_%s_%s.png', trial_type, condition);
    saveas(gcf, fullfile(outDir, fname));
    fprintf('\nSaved sensitivity plot to %s\n', fullfile(outDir, fname));

    % ----- Package output -----
    results = struct();
    results.minRespVals = minRespVals;
    results.point_raw   = point_raw;
    results.ci_lo       = ci_lo;
    results.ci_hi       = ci_hi;
    results.nItems      = nItems;
    results.pairLabels  = pairLabels;
end
