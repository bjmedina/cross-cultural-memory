function plotTripleIntergroupBar_v2(ac, ab, bc, condition, trial_type, baseDir, pmat)
% plotTripleIntergroupBar_v2
%   Compare intergroup itemwise correlations (raw & attenuation-corrected)
%   using 95% CIs from bootstrap distributions. Optionally shows p-value
%   brackets from pairedBootstrapCompareCorrelations.
%
%   v2: Supports both old simulation outputs (r_raw, sem_raw) and new
%   bootstrap outputs (point_raw, ci_raw).
%
%   Bryan Medina -- Bolivia 2025 / Statistical fixes Feb 2026

    if nargin < 7, pmat = []; end

    % -----------------------------
    % prepare data (handle both old and new output formats)
    % -----------------------------
    % Order matches the function arguments: (ac, ab, bc) = [A-C, A-B, B-C]
    % where A=US, B=San Borja, C=Tsimane
    pairs = {'US-Tsimane', 'US-San Borja', 'San Borja-Tsimane'};
    x = 1:3; w = 0.35;

    [rawAC, corrAC, ciRawAC, ciCorrAC] = extract_vals(ac);
    [rawAB, corrAB, ciRawAB, ciCorrAB] = extract_vals(ab);
    [rawBC, corrBC, ciRawBC, ciCorrBC] = extract_vals(bc);

    rawVals  = [rawAC,  rawAB,  rawBC];
    corrVals = [corrAC, corrAB, corrBC];

    ciRaw  = [ciRawAC; ciRawAB; ciRawBC];     % 3x2
    ciCorr = [ciCorrAC; ciCorrAB; ciCorrBC];   % 3x2

    errRawNeg  = rawVals(:)  - ciRaw(:,1);
    errRawPos  = ciRaw(:,2)  - rawVals(:);
    errCorrNeg = corrVals(:) - ciCorr(:,1);
    errCorrPos = ciCorr(:,2) - corrVals(:);

    % -----------------------------
    % figure setup
    % -----------------------------
    figure('Color','w','Position',[100 100 750 540]); hold on;

    bar(x-w/2, rawVals,  w, 'FaceColor',[0.7 0.8 1.0], 'EdgeColor','none');
    bar(x+w/2, corrVals, w, 'FaceColor',[0.3 0.55 0.9], 'EdgeColor','none');

    % 95% CI error bars (asymmetric)
    errorbar(x-w/2, rawVals, errRawNeg', errRawPos', 'k', 'LineStyle','none', 'LineWidth',1.3);
    errorbar(x+w/2, corrVals, errCorrNeg', errCorrPos', 'k', 'LineStyle','none', 'LineWidth',1.3);

    % -----------------------------
    % formatting
    % -----------------------------
    set(gca,'XTick',x,'XTickLabel',pairs,'FontSize',12);
    xtickangle(15);
    ylabel('Itemwise Spearman correlation');
    title(sprintf('Intergroup %s correlations - %s', upper(trial_type), condition), ...
        'Interpreter','none');

    allUpper = [rawVals(:) + errRawPos; corrVals(:) + errCorrPos];
    yMax = max(allUpper, [], 'all', 'omitnan');
    if isnan(yMax), yMax = 1; end

    grid on; box off;
    legend({'Raw','Atten.-Corrected'},'Location','northoutside','Orientation','horizontal');

    % -----------------------------
    % annotate text above bars
    % -----------------------------
    for i = 1:numel(x)
        text(x(i)-w/2, rawVals(i)+errRawPos(i)+0.02, sprintf('%.2f', rawVals(i)), ...
            'HorizontalAlignment','center', 'FontWeight','bold', 'FontSize',10);
        text(x(i)+w/2, corrVals(i)+errCorrPos(i)+0.02, sprintf('%.2f', corrVals(i)), ...
            'HorizontalAlignment','center', 'FontWeight','bold', 'FontSize',10);
    end

    % -----------------------------
    % p-value brackets (if provided)
    % -----------------------------
    if ~isempty(pmat) && isnumeric(pmat) && all(size(pmat) >= [3 3])
        ypad = 0.04;
        base = yMax + 0.08;

        draw_p(gca, 1, 2, base + 0*ypad, safe_p(pmat,1,2));
        draw_p(gca, 1, 3, base + 1*ypad, safe_p(pmat,1,3));
        draw_p(gca, 2, 3, base + 2*ypad, safe_p(pmat,2,3));

        ylim([0  base + 4*ypad]);
    else
        ylim([0 yMax * 1.25]);
    end

    % -----------------------------
    % save figure
    % -----------------------------
    if nargin > 5 && ~isempty(baseDir)
        outDir = UTILS_buildOutputDir(baseDir, condition);
        if ~exist(outDir, 'dir'), mkdir(outDir); end
        fname = sprintf('triple_intergroup_%s_%s_v2.png', trial_type, condition);
        saveas(gcf, fullfile(outDir, fname));
        fprintf('Saved plot to %s\n', fullfile(outDir, fname));
    end

    % -----------------------------
    % console summary
    % -----------------------------
    fprintf('\n=== Intergroup %s correlations (%s) ===\n', upper(trial_type), condition);
    for i = 1:3
        fprintf('%s:\t r = %.3f [%.3f, %.3f] (corr = %.3f [%.3f, %.3f])\n', ...
            pairs{i}, rawVals(i), ciRaw(i,1), ciRaw(i,2), ...
            corrVals(i), ciCorr(i,1), ciCorr(i,2));
    end
end

% ---- helpers ----

function [rRaw, rCorr, ciRaw, ciCorr] = extract_vals(s)
% Extract raw/corrected values and CIs from either old (sim) or new (boot) format.
    if isfield(s, 'point_raw')
        % New bootstrap format (from bootstrapIntergroupCorrelationSEM)
        rRaw  = s.point_raw;
        rCorr = s.point_corr;
        if isfield(s, 'ci_raw') && numel(s.ci_raw) == 2
            ciRaw = s.ci_raw(:)';
        else
            ciRaw = [rRaw rRaw];
        end
        if isfield(s, 'ci_corr') && numel(s.ci_corr) == 2
            ciCorr = s.ci_corr(:)';
        else
            ciCorr = [rCorr rCorr];
        end
    elseif isfield(s, 'r_raw')
        % Old simulation format (from simulateIntergroupItemwiseCorrelation)
        rRaw  = s.r_raw;
        rCorr = s.r_corrected;
        if isfield(s, 'sem_raw')
            ciRaw  = [rRaw - 1.96*s.sem_raw,  rRaw + 1.96*s.sem_raw];
            ciCorr = [rCorr - 1.96*s.sem_corr, rCorr + 1.96*s.sem_corr];
        else
            ciRaw = [rRaw rRaw]; ciCorr = [rCorr rCorr];
        end
    else
        error('Unrecognized intergroup output struct format.');
    end
end

function draw_p(ax, i, j, y, p)
    if isnan(p), txt = 'p = n/a';
    elseif p < 1e-3, txt = 'p < 0.001';
    else, txt = sprintf('p = %.3f', p);
    end
    plot(ax, [i j], [y y], 'k-', 'LineWidth', 1.0);
    tick = 0.015 * max(1, abs(y));
    plot(ax, [i i], [y y - tick], 'k-', 'LineWidth', 1.0);
    plot(ax, [j j], [y y - tick], 'k-', 'LineWidth', 1.0);
    text(ax, (i + j)/2, y + tick, txt, 'HorizontalAlignment','center', 'VerticalAlignment','bottom');
end

function p = safe_p(P,i,j)
    if isempty(P) || any(size(P) < [i j]) || ~isfinite(P(i,j)), p = NaN;
    else, p = P(i,j);
    end
end
