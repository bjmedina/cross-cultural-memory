function figs = plotIntergroupTripleFromOuts(outs, labels, condition, varargin)
% plotIntergroupTripleFromOuts
%   Re-plot the three bars (A?C, A?B, B?C) from `outs` with **SEMs** by default.
%   Makes TWO figures: one for hits and one for false alarms.
%
% Usage:
%   labels = {'A?C','A?B','B?C'};
%   figs = plotIntergroupTripleFromOuts(outs, labels, 'Industrial-Nature', ...
%       'SaveDir', fullfile(baseDir,'figures','Industrial-Nature'), ...
%       'Prefix', 'intergroup-reliability', ...
%       'ErrorType', 'sem');   % 'sem' (default) or 'ci'
%
% Inputs:
%   outs       : struct from intergroupTripleReliabilityPlot (has .hit and .fa)
%   labels     : 1x3 cellstr in order {A?C, A?B, B?C}
%   condition  : string for titles (optional)
%   Name/Value :
%       'SaveDir'  : folder to save PNGs (default: [])
%       'Prefix'   : filename stem (default: 'intergroup')
%       'ErrorType': 'sem' (default) for standard error of bootstrap means,
%                    or 'ci' to reuse the stored 95% CIs in outs.*.summary
%
% Output:
%   figs : struct with handles figs.hit and figs.fa

    % -------- options parsing --------
    p = inputParser;
    addParameter(p, 'SaveDir', [], @(s) isempty(s) || ischar(s) || isstring(s));
    addParameter(p, 'Prefix', 'intergroup', @(s) ischar(s) || isstring(s));
    addParameter(p, 'ErrorType', 'sem', @(s) any(strcmpi(s,{'sem','ci'})));
    parse(p, varargin{:});
    saveDir   = p.Results.SaveDir;
    prefix    = char(p.Results.Prefix);
    errorType = lower(p.Results.ErrorType);

    if nargin < 3 || isempty(condition), condition = ''; end
    if nargin < 2 || numel(labels) ~= 3
        error('Provide 3 x-axis labels for bars in order {A?C, A?B, B?C}.');
    end

    figs = struct();

    % -------- HITS --------
    if isfield(outs, 'hit')
        [means_hit, errs_hit] = get_means_and_errors(outs.hit, errorType);
        if all(isnan(means_hit))
            warning('HITS: all means are NaN. Skipping plot.');
        else
            figs.hit = figure('Color','w','Name','Intergroup reliability (hits)');
            bar_with_ci_and_pvals(means_hit, errs_hit, safe_field(outs.hit,'pvals'), labels, ...
                title_str('Intergroup reliability (hits)', condition), errorType);
            maybe_save(figs.hit, saveDir, sprintf('%s-hits', prefix));
        end
    else
        warning('`outs.hit` missing or incomplete; no hits plot generated.');
    end

    % -------- FALSE ALARMS --------
    if isfield(outs, 'fa')
        [means_fa, errs_fa] = get_means_and_errors(outs.fa, errorType);
        if all(isnan(means_fa))
            warning('FAs: all means are NaN. Skipping plot.');
        else
            figs.fa = figure('Color','w','Name','Intergroup reliability (false alarms)');
            bar_with_ci_and_pvals(means_fa, errs_fa, safe_field(outs.fa,'pvals'), labels, ...
                title_str('Intergroup reliability (false alarms)', condition), errorType);
            maybe_save(figs.fa, saveDir, sprintf('%s-false-alarms', prefix));
        end
    else
        warning('`outs.fa` missing or incomplete; no false-alarms plot generated.');
    end
end

% ====================== helpers ======================

function [means3, errs3] = get_means_and_errors(section, errorType)
% Build bar heights and error bars from a section (outs.hit or outs.fa).
% If 'sem': compute means and SEMs from rBoots directly.
% If 'ci' : reuse stored 95% CIs in summary.
    means3 = nan(1,3);
    errs3  = zeros(3,2); % [neg,pos]; for SEM we make it symmetric later

    hasBoots  = isfield(section,'rBoots')  && numel(section.rBoots) == 3;
    hasSumm   = isfield(section,'summary') && numel(section.summary) == 3;

    switch errorType
        case 'sem'
            if ~hasBoots
                warning('SEM requested but rBoots missing; falling back to CI.');
                [means3, errs3] = from_summary_ci(section);
                return;
            end
            for k = 1:3
                rk = section.rBoots{k};
                rk = rk(~isnan(rk));
                if isempty(rk)
                    means3(k) = NaN;
                    errs3(k,:) = 0;
                else
                    m   = mean(rk);
                    se  = std(rk) / sqrt(numel(rk));
                    means3(k)  = m;
                    errs3(k,:) = [se se]; % symmetric SEM
                end
            end
        case 'ci'
            if ~hasSumm
                warning('CI requested but summary missing; falling back to SEM if boots exist.');
                if hasBoots
                    errorType = 'sem'; %#ok<NASGU>
                    [means3, errs3] = get_means_and_errors(section, 'sem');
                    return;
                else
                    % Nothing to compute
                    return;
                end
            end
            [means3, errs3] = from_summary_ci(section);
    end
end

function [means3, errs3] = from_summary_ci(section)
% Use stored means and 95% CIs from summary.
    s = section.summary;
    means3 = [s(1).r_mean, s(2).r_mean, s(3).r_mean];
    ci     = vertcat(s.r_ci);                 % [low high] per row
    errs3  = [means3(:) - ci(:,1), ci(:,2) - means3(:)]; % asymmetric
    bad    = any(isnan(errs3),2);
    errs3(bad,:) = 0;
end

function t = title_str(base, condition)
% Build title string.
    if isempty(condition), t = base;
    else, t = sprintf('%s ? %s', base, condition);
    end
end

function maybe_save(figH, saveDir, stem)
% Save figure if path provided.
    if ~isempty(saveDir)
        if ~exist(saveDir, 'dir'), mkdir(saveDir); end
        out = fullfile(saveDir, sprintf('%s.png', stem));
        saveas(figH, out);
        fprintf('Saved %s\n', out);
    end
end

function P = safe_field(s, fname)
% Safely fetch p-value matrix; return [] if absent.
    if isfield(s, fname), P = s.(fname); else, P = []; end
end

function bar_with_ci_and_pvals(means3, errs3, pmat3, xlabels, figTitle, errorType)
% Bar plot with error bars and pairwise p-value brackets.
% - means3: 1x3 vector [A?C, A?B, B?C]
% - errs3 : 3x2 [neg,pos] (for SEM, symmetric)
% - pmat3 : 3x3 p-value matrix (optional; [] allowed)
% - xlabels: 1x3 cellstr
% - figTitle: string
% - errorType: 'sem' or 'ci' (used only for y-label detail)

    ax = gca; hold(ax, 'on');
    bar(ax, 1:3, means3, 'FaceColor', [0.78 0.78 0.78], 'EdgeColor', 'k');

    % Convert to vectors for errorbar
    neg = errs3(:,1)'; pos = errs3(:,2)';
    errorbar(ax, 1:3, means3, neg, pos, 'k', 'LineStyle', 'none', 'LineWidth', 1.5);

    xlim([0.5 3.5]); ax.XTick = 1:3; ax.XTickLabel = xlabels;
    switch errorType
        case 'sem',  ylab = 'Intergroup item-wise r  (±SEM)';
        case 'ci',   ylab = 'Intergroup item-wise r  (95% CI)';
        otherwise,   ylab = 'Intergroup item-wise r';
    end
    ylabel(ylab);
    title(figTitle, 'Interpreter','none');
    grid on;

    ymax = max(means3 + pos);
    if ~isfinite(ymax), ymax = max(means3); end
    if ~isfinite(ymax), ymax = 0.1; end
    ypad = max(0.02, 0.05*range([0,ymax]));
    base = ymax + ypad;

    if ~isempty(pmat3)
        draw_p(ax, 1, 2, base + 0*ypad, safe_p(pmat3,1,2));
        draw_p(ax, 1, 3, base + 1*ypad, safe_p(pmat3,1,3));
        draw_p(ax, 2, 3, base + 2*ypad, safe_p(pmat3,2,3));
        ylim([min(0, min(means3 - neg))  base + 3.5*ypad]);
    else
        ylim([min(0, min(means3 - neg))  base + 1.5*ypad]);
    end
    hold(ax, 'off');
end

function p = safe_p(P,i,j)
% Return printable p (or NaN if unavailable).
    if isempty(P) || any(size(P) < [i j]) || ~isfinite(P(i,j)), p = NaN;
    else, p = P(i,j);
    end
end

function draw_p(ax, i, j, y, p)
% Draw significance bracket with "p=..." text.
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