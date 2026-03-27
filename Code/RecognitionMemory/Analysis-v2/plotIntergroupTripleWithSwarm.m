function figs = plotIntergroupTripleWithSwarm(outs, labels, condition, saveDir, varargin)
% plotIntergroupTripleWithSwarm
%   Plot three bars (A?C, A?B, B?C) for both HITS and FAs with either
%   ±SEM or 95% CIs AND overlay the full bootstrap distributions as swarm dots.
%
% Usage:
%   labels = {'Prolific?San Borja', 'Prolific?Tsimane', 'Tsimane?San Borja'};
%   figs = plotIntergroupTripleWithSwarm(outs, labels, 'NHS', ...
%       'ErrorType','sem', ...         % 'sem' or 'ci'
%       'SwarmAlpha',0.25, ...         % dot transparency
%       'SwarmSize',12, ...            % dot size
%       'SaveDir', fullfile(baseDir,'figures','NHS'), ...
%       'Prefix', 'intergroup-reliability');
%
% Inputs:
%   outs      : struct from your earlier code (must have outs.hit and outs.fa)
%   labels    : 1x3 cellstr in order {A?C, A?B, B?C}
%   condition : string for figure titles
%
% Name/Value options:
%   'ErrorType' : 'sem' (default) or 'ci'
%   'SwarmAlpha': 0..1 transparency for dots (default 0.25)
%   'SwarmSize' : marker size (default 12)
%   'SaveDir'   : optional folder to save PNGs (default [])
%   'Prefix'    : filename stem (default 'intergroup')
%
% Output:
%   figs : struct with handles figs.hit and figs.fa
%
% Notes:
%   - Swarm dots are plotted using `swarmchart` when available (R2019b+);
%     otherwise a light jittered scatter fallback is used.
%   - p-values are taken from outs.*.pvals; bars are ordered [A?C, A?B, B?C].

    % ---------- options ----------
    p = inputParser;
    addParameter(p, 'ErrorType', 'sem', @(s) any(strcmpi(s,{'sem','ci'})));
    addParameter(p, 'SwarmAlpha', 0.25, @(x) isnumeric(x) && isscalar(x) && x>=0 && x<=1);
    addParameter(p, 'SwarmSize', 12, @(x) isnumeric(x) && isscalar(x) && x>0);
    %addParameter(p, 'SaveDir', [], @(s) isempty(s) || ischar(s) || isstring(s));
    addParameter(p, 'Prefix', 'intergroup', @(s) ischar(s) || isstring(s));
    parse(p, varargin{:});
    errType   = lower(p.Results.ErrorType);
    swarmA    = p.Results.SwarmAlpha;
    swarmSz   = p.Results.SwarmSize;
    %saveDir   = p.Results.SaveDir;
    prefix    = char(p.Results.Prefix);
    
    % ---------- validate args ----------
    if nargin < 3 || isempty(condition), condition = ''; end
    if nargin < 2 || numel(labels) ~= 3
        error('Provide 3 x-axis labels for bars in order {A?C, A?B, B?C}.');
    end

    % ---------- derive unique group names from pair labels ----------
    % Extract words separated by '?', '?', or '-' and collect unique group names
    allTokens = regexp(strjoin(labels, ' '), '[A-Za-z0-9]+', 'match');
    uniqueGroups = unique(allTokens, 'stable');

    % Build safe filename and readable title versions
    group_prefix = strjoin(uniqueGroups, '-');             % e.g., "Prolific-Tsimane-SanBorja"
    group_prefix = regexprep(group_prefix, '[^\w-]', '');  % remove special chars
    group_title  = strjoin(uniqueGroups, '?');             % nice en-dash for title

    fullPrefix = sprintf('%s_%s_%s', prefix, condition, group_prefix);

    figs = struct();

    % ---------- HITS ----------
    if isfield(outs,'hit')
        figs.hit = figure('Color','w','Name','Intergroup Correlation (hits)');
        [means_hit, errs_hit, boots_hit, p_hit] = extract_for_section(outs.hit, errType);
        bar_swarm_pvals(means_hit, errs_hit, boots_hit, p_hit, labels, ...
            title_str(sprintf('Intergroup Correlation (hits) [%s]', group_title), condition), ...
            errType, swarmA, swarmSz);
        maybe_save(figs.hit, saveDir, sprintf('%s-hits', fullPrefix));
    end

    % ---------- FAs ----------
    if isfield(outs,'fa')
        figs.fa = figure('Color','w','Name','Intergroup Correlation (false alarms)');
        [means_fa, errs_fa, boots_fa, p_fa] = extract_for_section(outs.fa, errType);
        bar_swarm_pvals(means_fa, errs_fa, boots_fa, p_fa, labels, ...
            title_str(sprintf('Intergroup Correlation (false alarms) [%s]', group_title), condition), ...
            errType, swarmA, swarmSz);
        maybe_save(figs.fa, saveDir, sprintf('%s-false-alarms', fullPrefix));
    end
end

% ====================== helpers ======================

function [means3, errs3, boots3, pmat3] = extract_for_section(section, errType)
% Build bar heights, error bars, bootstrap arrays, and p-matrix for a section.
    if ~isfield(section,'rBoots') || numel(section.rBoots) ~= 3
        error('Section missing rBoots for 3 pairs.');
    end
    boots3 = cell(1,3);
    means3 = nan(1,3);
    errs3  = zeros(3,2);
    for k = 1:3
        rk = section.rBoots{k};
        rk = rk(~isnan(rk));
        boots3{k} = rk;
        if isempty(rk)
            means3(k) = NaN;
            errs3(k,:) = 0;
        else
            means3(k) = mean(rk);
            if strcmp(errType,'sem')
                se = std(rk) / sqrt(numel(rk));
                errs3(k,:) = [se se];            % symmetric ±SEM
            else
                % Use stored CI if available; else compute percentile CI.
                if isfield(section,'summary') && numel(section.summary) == 3 ...
                        && isfield(section.summary(k),'r_ci') && all(isfinite(section.summary(k).r_ci))
                    ci = section.summary(k).r_ci;
                else
                    ci = quantile(rk,[0.025 0.975]);
                end
                errs3(k,:) = [means3(k)-ci(1), ci(2)-means3(k)]; % asymmetric CI
            end
        end
    end
    if isfield(section,'pvals'), pmat3 = section.pvals; else, pmat3 = []; end
end

function bar_swarm_pvals(means3, errs3, boots3, pmat3, xlabels, figTitle, errType, swarmA, swarmSz)
% Draw bars + error bars + swarm dots of bootstrap distributions + p-value brackets.
    ax = gca; hold(ax,'on');

    % Bars
    bar(ax, 1:3, means3, 'FaceColor', [0.78 0.78 0.78], 'EdgeColor', 'k');

    % Error bars
    errorbar(ax, 1:3, means3, errs3(:,1)', errs3(:,2)', ...
        'k', 'LineStyle','none', 'LineWidth',1.5);

    % Swarm dots (subsample to avoid clutter)
    maxY = -inf;
    maxDots = 150;  % ? limit number of points per bar (adjust as desired)

    for k = 1:3
        rk = boots3{k};
        if isempty(rk), continue; end

        % --- Subsample for visualization only ---
        if numel(rk) > maxDots
            rk = rk(randsample(numel(rk), maxDots, false));  % random subset
        end

        xk = k * ones(size(rk));
        if exist('swarmchart','file') == 2
            h = swarmchart(ax, xk, rk, swarmSz, 'filled', ...
                'MarkerFaceAlpha', swarmA, 'MarkerEdgeAlpha', swarmA);
        else
            xjit = (rand(size(xk))-0.5) * 0.2;
            h = scatter(ax, xk + xjit, rk, swarmSz, 'filled', ...
                'MarkerFaceAlpha', swarmA, 'MarkerEdgeAlpha', swarmA);
        end
        h.MarkerFaceColor = [0.2 0.2 0.2];
        h.MarkerEdgeColor = 'none';
        maxY = max(maxY, max(rk));
    end

    % Axis cosmetics
    xlim([0.5 3.5]); ax.XTick = 1:3; ax.XTickLabel = xlabels;
    switch errType
        case 'sem', ylab = 'Inter-group item-wise correlation  (±SEM)'; 
        case 'ci',  ylab = 'Inter-group item-wise correlation  (95% CI)';
    end
    ylabel(ylab);
    title(figTitle, 'Interpreter','none');
    grid on;

    %% --- Y-axis limits and p-value brackets ---
    % Force common upper limit of 1
    yLower = min(0, min(means3 - errs3(:,1)'));
    yUpper = 1.0;
    ylim(ax, [yLower yUpper]);

    % Vertical spacing for brackets, scaled to the [0,1] range
    ypad = 0.03;
    base = min(0.9, max(means3) + 0.05); % start brackets below 1

    if ~isempty(pmat3)
        draw_p(ax, 1, 2, base + 0*ypad, safe_p(pmat3,1,2));
        draw_p(ax, 1, 3, base + 1*ypad, safe_p(pmat3,1,3));
        draw_p(ax, 2, 3, base + 2*ypad, safe_p(pmat3,2,3));
    end

    hold(ax,'off');
end

function draw_p(ax, i, j, y, p)
% Draw a lightweight significance bracket with p-text.
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
% Safe indexing of p-value matrix.
    if isempty(P) || any(size(P) < [i j]) || ~isfinite(P(i,j)), p = NaN;
    else, p = P(i,j);
    end
end

function t = title_str(base, condition)
% Compose a neat title.
    if isempty(condition), t = base; else, t = sprintf('%s ? %s', base, condition); end
end

function maybe_save(figH, saveDir, stem)
% Save figure if a folder is provided.
    if ~isempty(saveDir)
        if ~exist(saveDir, 'dir'), mkdir(saveDir); end
        out = fullfile(saveDir, sprintf('%s.png', stem));
        saveas(figH, out);
        fprintf('Saved %s\n', out);
    end
end