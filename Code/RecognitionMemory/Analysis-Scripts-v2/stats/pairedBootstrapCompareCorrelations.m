function pvals = pairedBootstrapCompareCorrelations(outsA, outsB, outsC, trialType, varargin)
% pairedBootstrapCompareCorrelations
%   Properly compare intergroup correlations using a PAIRED bootstrap.
%
%   The key insight: when comparing r(A,B) vs r(A,C), group A is shared.
%   A valid test must resample group A ONCE and use the same resample for
%   both correlations. This preserves the dependence between the two
%   estimates and produces a valid null distribution for their difference.
%
%   pvals = pairedBootstrapCompareCorrelations(outsA, outsB, outsC, trialType, ...)
%
%   Inputs:
%     outsA, outsB, outsC : structs from calculateSplitHalfReliability
%                           (must contain .itemwise_hits, .itemwise_fas, .items)
%     trialType           : 'hit' or 'fa'
%
%   Optional Name/Value:
%     'nBoot'        : number of bootstrap iterations (default 5000)
%     'UseSpearman'  : true/false (default true)
%     'BootstrapDim' : 1 = resample participants (default), 2 = resample stimuli
%     'minResp'      : min non-NaN observations per stimulus per group (default 2)
%     'Verbose'      : true/false (default true)
%
%   Output:
%     pvals : struct with fields:
%       .AB_vs_AC : p-value for r(A,B) != r(A,C)
%       .AB_vs_BC : p-value for r(A,B) != r(B,C)
%       .AC_vs_BC : p-value for r(A,C) != r(B,C)
%       .pmat     : 3x3 symmetric matrix (bar order: [AB, AC, BC])
%       .diffs    : struct with bootstrap difference distributions
%       .ci       : struct with 95% CIs for each difference
%
%   Bryan Medina -- Feb 2026 (statistical fix), Mar 2026 (minResp, bar order)

    % ---------- parse options ----------
    p = inputParser;
    addParameter(p, 'nBoot', 5000, @isscalar);
    addParameter(p, 'UseSpearman', true, @islogical);
    addParameter(p, 'BootstrapDim', 1, @isscalar);
    addParameter(p, 'minResp', 2, @isscalar);
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});
    nBoot   = p.Results.nBoot;
    useSpearman = p.Results.UseSpearman;
    bootDim = p.Results.BootstrapDim;
    minResp = p.Results.minResp;
    verbose = p.Results.Verbose;

    method = ternary(useSpearman, 'Spearman', 'Pearson');
    trialType = lower(trialType);
    assert(ismember(trialType, {'hit','fa'}), 'trialType must be ''hit'' or ''fa''.');

    % ---------- extract data ----------
    switch trialType
        case 'hit'
            XA = outsA.itemwise_hits;
            XB = outsB.itemwise_hits;
            XC = outsC.itemwise_hits;
        case 'fa'
            XA = outsA.itemwise_fas;
            XB = outsB.itemwise_fas;
            XC = outsC.itemwise_fas;
    end

    % ---------- align to shared items across ALL three groups ----------
    [sharedAB, iaAB, ibAB] = intersect(outsA.items, outsB.items, 'stable');
    [sharedItems, iABC, icABC] = intersect(sharedAB, outsC.items, 'stable');

    XA = XA(:, iaAB(iABC));
    XB = XB(:, ibAB(iABC));
    XC = XC(:, icABC);

    [nA, nItems] = size(XA);
    nB = size(XB, 1);
    nC = size(XC, 1);

    if nItems < 5
        warning('Too few shared items across all 3 groups (N=%d).', nItems);
        pvals = struct('pmat', nan(3), 'AB_vs_AC', NaN, 'AB_vs_BC', NaN, 'AC_vs_BC', NaN);
        return;
    end

    % ---------- observed correlations ----------
    meanA = nanmean(XA, 1); meanB = nanmean(XB, 1); meanC = nanmean(XC, 1);
    nObsA_full = sum(~isnan(XA), 1);
    nObsB_full = sum(~isnan(XB), 1);
    nObsC_full = sum(~isnan(XC), 1);
    valid = (nObsA_full >= minResp) & (nObsB_full >= minResp) & (nObsC_full >= minResp);

    r_AB_obs = corr(meanA(valid)', meanB(valid)', 'Type', method, 'Rows', 'pairwise');
    r_AC_obs = corr(meanA(valid)', meanC(valid)', 'Type', method, 'Rows', 'pairwise');
    r_BC_obs = corr(meanB(valid)', meanC(valid)', 'Type', method, 'Rows', 'pairwise');

    % ---------- bootstrap ----------
    rng('shuffle');
    r_AB_boot = nan(nBoot, 1);
    r_AC_boot = nan(nBoot, 1);
    r_BC_boot = nan(nBoot, 1);

    for b = 1:nBoot
        switch bootDim
            case 1  % resample participants within each group
                idxA = randi(nA, [nA, 1]);
                idxB = randi(nB, [nB, 1]);
                idxC = randi(nC, [nC, 1]);

                mA = nanmean(XA(idxA, :), 1);
                mB = nanmean(XB(idxB, :), 1);
                mC = nanmean(XC(idxC, :), 1);

                nOA = sum(~isnan(XA(idxA, :)), 1);
                nOB = sum(~isnan(XB(idxB, :)), 1);
                nOC = sum(~isnan(XC(idxC, :)), 1);

            case 2  % resample stimuli (shared across all pairs!)
                idxStim = randi(nItems, [nItems, 1]);

                mA = nanmean(XA(:, idxStim), 1);
                mB = nanmean(XB(:, idxStim), 1);
                mC = nanmean(XC(:, idxStim), 1);

                nOA = sum(~isnan(XA(:, idxStim)), 1);
                nOB = sum(~isnan(XB(:, idxStim)), 1);
                nOC = sum(~isnan(XC(:, idxStim)), 1);

            otherwise
                error('BootstrapDim must be 1 or 2.');
        end

        v = (nOA >= minResp) & (nOB >= minResp) & (nOC >= minResp);
        if sum(v) < 5, continue; end

        r_AB_boot(b) = corr(mA(v)', mB(v)', 'Type', method, 'Rows', 'pairwise');
        r_AC_boot(b) = corr(mA(v)', mC(v)', 'Type', method, 'Rows', 'pairwise');
        r_BC_boot(b) = corr(mB(v)', mC(v)', 'Type', method, 'Rows', 'pairwise');
    end

    % ---------- compute differences ----------
    diff_AB_AC = r_AB_boot - r_AC_boot;  % r(A,B) - r(A,C)
    diff_AB_BC = r_AB_boot - r_BC_boot;  % r(A,B) - r(B,C)
    diff_AC_BC = r_AC_boot - r_BC_boot;  % r(A,C) - r(B,C)

    % ---------- two-sided p-values ----------
    p_AB_AC = compute_2sided_p(diff_AB_AC);
    p_AB_BC = compute_2sided_p(diff_AB_BC);
    p_AC_BC = compute_2sided_p(diff_AC_BC);

    % ---------- build p-value matrix ----------
    % Bar order in plots: [AB, AC, BC] (indices 1, 2, 3)
    pmat = zeros(3);
    pmat(1,2) = p_AB_AC; pmat(2,1) = p_AB_AC;  % AB vs AC
    pmat(1,3) = p_AB_BC; pmat(3,1) = p_AB_BC;  % AB vs BC
    pmat(2,3) = p_AC_BC; pmat(3,2) = p_AC_BC;  % AC vs BC

    % ---------- CIs ----------
    ci_AB_AC = prctile(diff_AB_AC, [2.5 97.5]);
    ci_AB_BC = prctile(diff_AB_BC, [2.5 97.5]);
    ci_AC_BC = prctile(diff_AC_BC, [2.5 97.5]);

    % ---------- package ----------
    pvals = struct();
    pvals.AB_vs_AC = p_AB_AC;
    pvals.AB_vs_BC = p_AB_BC;
    pvals.AC_vs_BC = p_AC_BC;
    pvals.pmat = pmat;

    pvals.observed = struct('r_AB', r_AB_obs, 'r_AC', r_AC_obs, 'r_BC', r_BC_obs);

    pvals.diffs = struct( ...
        'AB_minus_AC', diff_AB_AC, ...
        'AB_minus_BC', diff_AB_BC, ...
        'AC_minus_BC', diff_AC_BC);

    pvals.ci = struct( ...
        'AB_minus_AC', ci_AB_AC, ...
        'AB_minus_BC', ci_AB_BC, ...
        'AC_minus_BC', ci_AC_BC);

    pvals.nBoot = nBoot;
    pvals.nItems = nItems;
    pvals.bootDim = bootDim;
    pvals.minResp = minResp;

    % ---------- console output ----------
    if verbose
        dimLabel = ternary(bootDim == 1, 'participant', 'stimulus');
        fprintf('\n=== Paired Bootstrap Comparison (%s, %s-level, %s, nBoot=%d, minResp=%d) ===\n', ...
            upper(trialType), dimLabel, method, nBoot, minResp);
        fprintf('Observed: r(A,B)=%.3f  r(A,C)=%.3f  r(B,C)=%.3f\n', ...
            r_AB_obs, r_AC_obs, r_BC_obs);
        fprintf('r(A,B) vs r(A,C):  diff=%.3f  95%%CI=[%.3f, %.3f]  p=%.4f\n', ...
            mean(diff_AB_AC,'omitnan'), ci_AB_AC(1), ci_AB_AC(2), p_AB_AC);
        fprintf('r(A,B) vs r(B,C):  diff=%.3f  95%%CI=[%.3f, %.3f]  p=%.4f\n', ...
            mean(diff_AB_BC,'omitnan'), ci_AB_BC(1), ci_AB_BC(2), p_AB_BC);
        fprintf('r(A,C) vs r(B,C):  diff=%.3f  95%%CI=[%.3f, %.3f]  p=%.4f\n', ...
            mean(diff_AC_BC,'omitnan'), ci_AC_BC(1), ci_AC_BC(2), p_AC_BC);
    end
end

% ---- helpers ----
function p = compute_2sided_p(diffs)
    diffs = diffs(~isnan(diffs));
    if isempty(diffs), p = NaN; return; end
    p = 2 * min(mean(diffs > 0), mean(diffs < 0));
    p = min(p, 1);
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
