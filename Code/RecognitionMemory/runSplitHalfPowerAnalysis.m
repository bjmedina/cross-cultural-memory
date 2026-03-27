function runSplitHalfPowerAnalysis(baseDir, placeCodes, condition, minISI0dprime, varargin)
% runSplitHalfPowerAnalysis
%   Computes and plots split-half reliability power curves for hits and FAs
%   using ISI > 0 repeat trials and non-repeats.
%
%   Inputs:
%     baseDir         - directory with participant .mat files
%     placeCodes      - cell array of place/site codes (e.g., {'ALL'} or {'NYC','BOS'})
%     condition       - string used to filter filenames (e.g., 'Globalized-Music')
%     minISI0dprime   - minimum d' threshold for ISI = 0 filtering
%
%   Name-Value Pairs:
%     'nRepeats'      - number of bootstrap repeats per sample size (default: 20)
%     'nSplits'       - number of split-half estimates per repeat (default: 50)
%     'step'          - step size for N in power curve (default: 5)
%     'seed'          - random seed (default: 42)

    % Parse options
    p = inputParser;
    addParameter(p, 'nRepeats', 32);
    addParameter(p, 'nSplits', 100);
    addParameter(p, 'step', 5);
    addParameter(p, 'seed', 0);
    parse(p, varargin{:});
    opts = p.Results;

    % Load matrices
    [hits, fas, ~, files] = loadSplitHalfMatrices(baseDir, placeCodes, condition, minISI0dprime);
    if isempty(hits)
        warning('No usable data found. Aborting power analysis.');
        return
    end

    fprintf('Running power curve estimation on %d participants...\n', numel(files));

    % Run power curves
    [sizes_hit, means_hit, stds_hit] = computePowerCurveSplitHalf(hits, ...
        'nRepeats', opts.nRepeats, 'nSplits', opts.nSplits, ...
        'step', opts.step, 'seed', opts.seed);

    [sizes_fa, means_fa, stds_fa] = computePowerCurveSplitHalf(fas, ...
        'nRepeats', opts.nRepeats, 'nSplits', opts.nSplits, ...
        'step', opts.step, 'seed', opts.seed);

    % Plot
    figure;
    hold on;
    errorbar(sizes_hit, means_hit, stds_hit, '-o', 'LineWidth', 1.5, 'DisplayName', 'Hits');
    errorbar(sizes_fa, means_fa, stds_fa, '-o', 'LineWidth', 1.5, 'DisplayName', 'FAs');
    xlabel('Number of Participants');
    ylabel('Split-Half Reliability');
    title(sprintf('Power Curve ? %s', condition), 'Interpreter', 'none');
    legend('Location', 'southeast');
    ylim([0, 1]);

    grid on;

    % Save
    tag = strjoin(placeCodes, '_');
    outDir = fullfile(baseDir, 'figures', condition);
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    fname = sprintf('PowerCurve-%s-sens%.2f.png', tag, minISI0dprime);
    saveas(gcf, fullfile(outDir, fname));
    fprintf('Saved figure to %s\n', fullfile(outDir, fname));
end