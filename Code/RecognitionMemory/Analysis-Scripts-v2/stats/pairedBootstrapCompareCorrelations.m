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
%       .AB_vs_AC : recentered-null p-value for r(A,B) != r(A,C)
%       .AB_vs_BC : recentered-null p-value for r(A,B) != r(B,C)
%       .AC_vs_BC : recentered-null p-value for r(A,C) != r(B,C)
%       .pmat     : 3x3 symmetric matrix (recentered-null; bar order [AB,AC,BC])
%       .straddle : struct holding legacy percentile-style p-values and pmat
%       .diffs    : struct with bootstrap difference distributions
%       .ci       : struct with 95% CIs for each difference
%       .observed : struct with sample r(A,B), r(A,C), r(B,C)
%       .observed_diffs : struct with sample r(A,B)-r(A,C) etc.
%
%   Two-sided p-values are reported under two definitions:
%     (1) Recentered-null (default, .AB_vs_AC etc.): construct a null by
%         subtracting the bootstrap mean from each diff, then compute
%         P(|null| >= |observed_diff|). Bootstrap analogue of a permutation
%         test under H0 : delta = 0.
%     (2) Straddle-zero (.straddle.*): p = 2*min(P(d>0), P(d<0)). Legacy
%         percentile-style p-value; biased under skew at small N. Kept for
%         comparability with prior pipeline runs.
%
%   Bryan Medina -- Feb 2026 (statistical fix), Mar 2026 (minResp, bar order),
%                   May 2026 (recentered-null p-value)

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

    % observed differences (from the original sample)
    d_AB_AC_obs = r_AB_obs - r_AC_obs;
    d_AB_BC_obs = r_AB_obs - r_BC_obs;
    d_AC_BC_obs = r_AC_obs - r_BC_obs;

    % ---------- two-sided p-values: percentile / straddle-zero variant ----------
    % p = 2*min(P(d>0), P(d<0)). Asks: does the bootstrap CI of the diff
    % cross zero? Biased under skew at small N. Kept for backwards
    % compatibility with prior pipeline outputs.
    p_AB_AC = compute_2sided_p(diff_AB_AC);
    p_AB_BC = compute_2sided_p(diff_AB_BC);
    p_AC_BC = compute_2sided_p(diff_AC_BC);

    % ---------- two-sided p-values: recentered-null variant ----------
    % Construct a null distribution by recentering each bootstrap diff
    % distribution at zero (subtract its mean). Compare |observed diff|
    % against |null|. This is the rigorous bootstrap analogue of a
    % permutation test under H0: true_diff = 0.
    p_AB_AC_null = compute_recentered_p(diff_AB_AC, d_AB_AC_obs);
    p_AB_BC_null = compute_recentered_p(diff_AB_BC, d_AB_BC_obs);
    p_AC_BC_null = compute_recentered_p(diff_AC_BC, d_AC_BC_obs);

    % ---------- build p-value matrix (default = recentered-null) ----------
    % Bar order in plots: [AB, AC, BC] (indices 1, 2, 3).
    % pmat uses the recentered-null variant because it is the test we
    % recommend reporting. pmat_straddle holds the legacy percentile-style p.
    pmat = zeros(3);
    pmat(1,2) = p_AB_AC_null; pmat(2,1) = p_AB_AC_null;  % AB vs AC
    pmat(1,3) = p_AB_BC_null; pmat(3,1) = p_AB_BC_null;  % AB vs BC
    pmat(2,3) = p_AC_BC_null; pmat(3,2) = p_AC_BC_null;  % AC vs BC

    pmat_straddle = zeros(3);
    pmat_straddle(1,2) = p_AB_AC; pmat_straddle(2,1) = p_AB_AC;
    pmat_straddle(1,3) = p_AB_BC; pmat_straddle(3,1) = p_AB_BC;
    pmat_straddle(2,3) = p_AC_BC; pmat_straddle(3,2) = p_AC_BC;

    % ---------- CIs ----------
    ci_AB_AC = prctile(diff_AB_AC, [2.5 97.5]);
    ci_AB_BC = prctile(diff_AB_BC, [2.5 97.5]);
    ci_AC_BC = prctile(diff_AC_BC, [2.5 97.5]);

    % ---------- package ----------
    pvals = struct();
    % Default p-values use the recentered-null variant.
    pvals.AB_vs_AC = p_AB_AC_null;
    pvals.AB_vs_BC = p_AB_BC_null;
    pvals.AC_vs_BC = p_AC_BC_null;
    pvals.pmat     = pmat;

    % Legacy percentile-style p-values (kept for back-compat / comparison).
    pvals.straddle = struct( ...
        'AB_vs_AC', p_AB_AC, ...
        'AB_vs_BC', p_AB_BC, ...
        'AC_vs_BC', p_AC_BC, ...
        'pmat',     pmat_straddle);

    pvals.observed = struct('r_AB', r_AB_obs, 'r_AC', r_AC_obs, 'r_BC', r_BC_obs);
    pvals.observed_diffs = struct( ...
        'AB_minus_AC', d_AB_AC_obs, ...
        'AB_minus_BC', d_AB_BC_obs, ...
        'AC_minus_BC', d_AC_BC_obs);

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
        fprintf('                                                     p (null)  p (straddle)\n');
        fprintf('r(A,B) vs r(A,C):  diff=%.3f  95%%CI=[%.3f, %.3f]  %8.4f  %8.4f\n', ...
            d_AB_AC_obs, ci_AB_AC(1), ci_AB_AC(2), p_AB_AC_null, p_AB_AC);
        fprintf('r(A,B) vs r(B,C):  diff=%.3f  95%%CI=[%.3f, %.3f]  %8.4f  %8.4f\n', ...
            d_AB_BC_obs, ci_AB_BC(1), ci_AB_BC(2), p_AB_BC_null, p_AB_BC);
        fprintf('r(A,C) vs r(B,C):  diff=%.3f  95%%CI=[%.3f, %.3f]  %8.4f  %8.4f\n', ...
            d_AC_BC_obs, ci_AC_BC(1), ci_AC_BC(2), p_AC_BC_null, p_AC_BC);
    end
end

% ---- helpers ----
function p = compute_2sided_p(diffs)
    % Percentile / "straddle zero" p-value.
    diffs = diffs(~isnan(diffs));
    if isempty(diffs), p = NaN; return; end
    p = 2 * min(mean(diffs > 0), mean(diffs < 0));
    p = min(p, 1);
end

function p = compute_recentered_p(diffs, obs)
    % Recentered-null two-sided p-value. Recenter the bootstrap diff
    % distribution at 0 to approximate the null, then compute the
    % probability of obtaining a difference at least as extreme (in
    % absolute value) as `obs`.
    diffs = diffs(~isnan(diffs));
    if isempty(diffs) || isnan(obs), p = NaN; return; end
    null_dist = diffs - mean(diffs);
    p = mean(abs(null_dist) >= abs(obs));
    p = min(max(p, 1/(numel(null_dist)+1)), 1);  % floor at 1/(B+1)
end

% ternary lives in utils/ternary.m; relied upon via the addpath in
% run_cross_cultural_analysis.m.
