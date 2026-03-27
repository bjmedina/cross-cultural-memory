function outs = intergroupTripleReliabilityPlot( ...
    baseDir, placeCodesA, placeCodesB, placeCodesC, ...
    condition, minISI0dprime, nBoot, globalMin)
% intergroupTripleReliabilityPlot
%   Compute and plot intergroup reliability for three groups (A,B,C) using
%   your existing intergroupReliabilityBootstrap() function.
%
%   Produces TWO figures: one for 'hit' and one for 'fa'.
%   Each figure shows three bars (in this exact order): A?C, A?B, B?C,
%   with 95% CI error bars and pairwise p-values annotated above bars.
%
% Inputs:
%   baseDir         : folder containing .mat files
%   placeCodesA     : cellstr for Group A (e.g., {'BOS','CAM'} or {'ALL'})
%   placeCodesB     : cellstr for Group B (e.g., {'TSI'} or {'ALL'})
%   placeCodesC     : cellstr for Group C (e.g., {'MAN','NUV'} or {'ALL'})
%   condition       : string to match in filename (e.g., 'Industrial-Nature')
%   minISI0dprime   : numeric threshold (filters participants)
%   nBoot           : number of bootstrap replicates (e.g., 10_000)
%
% Output:
%   outs : struct with fields:
%          outs.hit.rBoots = {rAC, rAB, rBC};
%          outs.hit.summary = struct array for each pair;
%          outs.hit.pvals = 3x3 matrix of pairwise p-values between bars;
%          outs.fa.(...) same as above for 'fa'.
%
% Dependencies (must be on MATLAB path):
%   - intergroupReliabilityBootstrap.m
%
% Notes:
%   - p-values are computed via a bootstrap-of-differences between bar means.
%   - Error bars are 95% bootstrap CIs returned by intergroupReliabilityBootstrap.
%   - Bars are strictly ordered [A?C, A?B, B?C] to match your request.

    % -------- HIT FIGURE --------
    [rAC_hit, sumAC_hit] = pair_boot_stim(baseDir, placeCodesA, placeCodesC, condition, minISI0dprime, nBoot, 'hit', globalMin);
    [rAB_hit, sumAB_hit] = pair_boot_stim(baseDir, placeCodesA, placeCodesB, condition, minISI0dprime, nBoot, 'hit', globalMin);
    [rBC_hit, sumBC_hit] = pair_boot_stim(baseDir, placeCodesB, placeCodesC, condition, minISI0dprime, nBoot, 'hit', globalMin);

    means_hit = [sumAC_hit.r_true, sumAB_hit.r_true, sumBC_hit.r_true];
    cis_hit   = [sumAC_hit.r_ci;   sumAB_hit.r_ci;   sumBC_hit.r_ci];   % 3x2
    errs_hit  = [means_hit(:) - cis_hit(:,1),  cis_hit(:,2) - means_hit(:)]; % 3x2 [neg,pos]

    p_hit = pairwise_pvals_from_boot_means({rAC_hit, rAB_hit, rBC_hit}); % 3x3


    % -------- FA FIGURE --------
    [rAC_fa, sumAC_fa] = pair_boot_stim(baseDir, placeCodesA, placeCodesC, condition, minISI0dprime, nBoot, 'fa', globalMin);
    [rAB_fa, sumAB_fa] = pair_boot_stim(baseDir, placeCodesA, placeCodesB, condition, minISI0dprime, nBoot, 'fa', globalMin);
    [rBC_fa, sumBC_fa] = pair_boot_stim(baseDir, placeCodesB, placeCodesC, condition, minISI0dprime, nBoot, 'fa', globalMin);

    means_fa = [sumAC_fa.r_true, sumAB_fa.r_true, sumBC_fa.r_true];
    cis_fa   = [sumAC_fa.r_ci;   sumAB_fa.r_ci;   sumBC_fa.r_ci];       % 3x2
    errs_fa  = [means_fa(:) - cis_fa(:,1),  cis_fa(:,2) - means_fa(:)]; % 3x2 [neg,pos]

    p_fa = pairwise_pvals_from_boot_means({rAC_fa, rAB_fa, rBC_fa});     % 3x3


    % -------- OUTPUT PACK --------
    outs = struct();
    outs.hit = struct('rBoots', {{rAC_hit, rAB_hit, rBC_hit}}, ...
                      'summary', { [sumAC_hit, sumAB_hit, sumBC_hit] }, ...
                      'pvals', p_hit);
    outs.fa  = struct('rBoots', {{rAC_fa, rAB_fa, rBC_fa}}, ...
                      'summary', { [sumAC_fa, sumAB_fa, sumBC_fa] }, ...
                      'pvals', p_fa);
                  
                  
    outs = recomputePvalsWithKS(outs, 'Method','perm', 'NPerm', 20000);
end

% ============================ HELPERS ============================

function tag = labs(pA, pB)
% Build a compact label "A?B" from place-code lists.
    tagA = tag_from_places(pA);
    tagB = tag_from_places(pB);
    tag  = sprintf('%s?%s', tagA, tagB);
end

function tag = tag_from_places(pc)
% Turn placeCodes (cellstr) into a short label.
    if any(strcmpi(pc,'ALL')), tag = 'ALL';
    else, tag = strjoin(pc,'_'); end
end

function [rBoot, summary] = pair_boot(baseDir, pX, pY, condition, minISI0dprime, nBoot, trialType, globalMin)
% Thin wrapper to call your provided intergroupReliabilityBootstrap().
%     [rBoot, summary] = intergroupReliabilityBootstrap( ...
%         baseDir, pX, pY, condition, minISI0dprime, nBoot, trialType);

    [rBoot, summary] = intergroupCorrelationBootstrap( ...
        baseDir, pX, pY, condition, minISI0dprime, nBoot, trialType);

end

function P = pairwise_pvals_from_boot_means(rBootCell)
% Compute two-sided p-values between the THREE bars using bootstrap-of-differences.
% rBootCell should be {r1, r2, r3} in the same bar order used for plotting.
% Returns a 3x3 symmetric matrix P with zeros on diagonal.
    K = numel(rBootCell);
    P = zeros(K);
    % Precompute clean bootstrap means arrays.
    clean = cell(1,K);
    for k = 1:K
        rk = rBootCell{k};
        rk = rk(~isnan(rk));                  % drop NaNs
        if isempty(rk), rk = NaN; end
        clean{k} = rk;
    end
    % For each pair (i,j), build empirical null of mean differences by resampling with replacement.
    % Using M draws keeps it fast but stable.
    M = 20000; % number of bootstrap-of-bootstrap draws for p-estimation
    for i = 1:K
        for j = i+1:K
            a = clean{i}; b = clean{j};
            if any(isnan([a(:); b(:)]))
                p = NaN;
            else
                % Sample M draws from each bootstrap distribution (with replacement).
                ai = a(randi(numel(a), M, 1)); 
                bj = b(randi(numel(b), M, 1)); 
                d  = mean(ai) - mean(bj);      % observed difference in means
                % Build reference by pairing individual draws into M pseudo-samples of means.
                % Here we also compute a distribution of differences across random draws.
                dd = ai - bj;
                % Two-sided p as fraction of draws as or more extreme than observed.
                p  = 2 * min(mean(dd >= d), mean(dd <= d));
                p  = min(max(p, 0), 1);
            end
            P(i,j) = p; P(j,i) = p;
        end
    end
end

function bar_with_ci_and_pvals(means3, errs3, pmat3, xlabels, figTitle)
% Make bar plot with 95% CI error bars for three bars and annotate all pairwise p-values.
% means3: 1x3
% errs3 : 3x2 [neg,pos] CI errors
% pmat3 : 3x3 matrix of p-values between bars
% xlabels: 1x3 cellstr
% figTitle: title string
    % Basic bar plot.
    ax = gca;
    hold(ax, 'on');
    bh = bar(ax, 1:3, means3, 'FaceColor', [0.7 0.7 0.7], 'EdgeColor', 'k'); %#ok<NASGU>
    % Error bars (asymmetric).
    er = errorbar(ax, 1:3, means3, errs3(:,1)', errs3(:,2)', ...
        'k', 'LineStyle', 'none', 'LineWidth', 1.5); %#ok<NASGU>
    xlim([0.5 3.5]);
    ax.XTick = 1:3; ax.XTickLabel = xlabels;
    ylabel('Intergroup item-wise r');
    title(figTitle, 'Interpreter', 'none');
    grid on;

    % Compute a reasonable top for p-value brackets.
    ymax = max(means3 + errs3(:,2)');
    ypad = max(0.02, 0.05*range([0,ymax]));
    base = ymax + ypad;

    % Annotate all pairwise comparisons (1-2, 1-3, 2-3).
    draw_p(ax, 1, 2, base + 0*ypad, pmat3(1,2));
    draw_p(ax, 1, 3, base + 1*ypad, pmat3(1,3));
    draw_p(ax, 2, 3, base + 2*ypad, pmat3(2,3));

    % Tidy limits.
    ylim([min(0, min(means3 - errs3(:,1)'))  base + 3.5*ypad]);
    hold(ax, 'off');
end

function [rBoot, summary] = pair_boot_stim(baseDir, pX, pY, condition, minISI0dprime, nBoot, trialType, ~)
% pair_boot  Helper for intergroupTripleReliabilityPlot
%   Wrapper to call the stimulus-level intergroup correlation bootstrap.
%
% Inputs:
%   baseDir, pX, pY, condition, minISI0dprime, nBoot, trialType
%
% Outputs:
%   rBoot, summary ? outputs from intergroupCorrelationBootstrapStimuli
%
% Notes:
%   - Uses item-level bootstrapping (not participant-level)
%   - Ignores the globalMin argument for backward compatibility

    % ---- call new version (stimulus bootstrap) ----
    [rBoot, summary] = intergroupCorrelationBootstrapStimuli( ...
        baseDir, pX, pY, condition, minISI0dprime, trialType, ...
        'NBoot', nBoot);

end

function draw_p(ax, i, j, y, p)
% Draw a significance bracket between bars i and j at height y with text "p=...".
    if isnan(p), txt = 'p = n/a';
    elseif p < 1e-3, txt = 'p < 0.001';
    else, txt = sprintf('p = %.3f', p);
    end
    % Horizontal bracket.
    plot(ax, [i j], [y y], 'k-', 'LineWidth', 1.0);
    % Small vertical ticks.
    tick = 0.01 * max(1, y);
    plot(ax, [i i], [y y - tick], 'k-', 'LineWidth', 1.0);
    plot(ax, [j j], [y y - tick], 'k-', 'LineWidth', 1.0);
    % Text centered.
    xmid = (i + j)/2;
    text(ax, xmid, y + tick, txt, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end