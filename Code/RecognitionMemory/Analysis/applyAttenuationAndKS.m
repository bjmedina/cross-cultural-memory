function outs = applyAttenuationAndKS(outs, baseDir, placeCodesA, placeCodesB, placeCodesC, ...
                                      condition, minISI0dprime, nSplits, varargin)
% applyAttenuationAndKS
%   Take your existing `outs` (with outs.hit.rBoots / outs.fa.rBoots),
%   (1) estimate **Spearman?Brown?corrected split-half reliability** for A,B,C
%       separately for hits and FAs,
%   (2) **attenuation-correct** each intergroup bootstrap r by
%       r_corrected = r_observed / sqrt(reliab_i * reliab_j),
%   (3) recompute **SEMs** as std of the corrected bootstrap vectors, and
%   (4) recompute **pairwise p-values** using a **permutation KS test**
%       on the corrected bootstrap distributions.
%
% Usage:
%   outs = applyAttenuationAndKS(outs, baseDir, A, B, C, condition, thr, 5000, ...
%                                'NPerm', 20000, 'Clip', 0.999, 'Verbose', true);
%
% Name/Value:
%   'NPerm'   : # permutations for KS (default 20000)
%   'Clip'    : clip |r| after correction to avoid inf Fisher-z (default 0.999)
%   'Verbose' : print reliabilities and factors (default false)
%
% Output:
%   Adds two sections per trial type (`hit`, `fa`) under:
%     outs.hit_corr / outs.fa_corr with fields:
%       .rBoots   : 1x3 cell of corrected bootstrap vectors (order A?C, A?B, B?C)
%       .means    : 1x3 corrected means
%       .sems     : 1x3 corrected SEMs (= std of boots)
%       .pvals    : 3x3 pairwise KS permutation p-values on corrected boots
%       .ksD      : 3x3 KS D statistics
%       .reliab   : struct with fields A,B,C (SB-corrected SHR used)
%       .labels   : {'A?C','A?B','B?C'}
%
% Notes:
%   - Reliability for each group/condition is computed **from individuals**:
%       build (participant x item) matrices and split participants into halves
%       nSplits times; Spearman r across items ? mean r; Spearman?Brown applied.
%   - Attenuation correction divides intergroup r by sqrt(rho_i * rho_j).
%   - After correction, values are clipped to [-Clip, +Clip] to be well-defined.

    % ---------- options ----------
    p = inputParser;
    addParameter(p, 'NPerm', 20000, @(x) isnumeric(x) && isscalar(x) && x>0);
    addParameter(p, 'Clip',  0.999,  @(x) isnumeric(x) && isscalar(x) && x>0 && x<=1);
    addParameter(p, 'Verbose', false, @(x) islogical(x) || isnumeric(x));
    parse(p, varargin{:});
    NPERM   = p.Results.NPerm;
    CLIP    = p.Results.Clip;
    VERBOSE = logical(p.Results.Verbose);

    % ---------- do both trial types if present ----------
    if isfield(outs,'hit')
        outs = handle_one_type('hit', outs, baseDir, placeCodesA, placeCodesB, placeCodesC, ...
                               condition, minISI0dprime, nSplits, NPERM, CLIP, VERBOSE);
    end
    if isfield(outs,'fa')
        outs = handle_one_type('fa', outs, baseDir, placeCodesA, placeCodesB, placeCodesC, ...
                               condition, minISI0dprime, nSplits, NPERM, CLIP, VERBOSE);
    end
end

% ============================ core ============================

function outs = handle_one_type(ttype, outs, baseDir, A, B, C, condition, thr, nSplits, NPERM, CLIP, VERBOSE)
% Process one trialType ('hit' or 'fa'): reliabilities, attenuation, KS.

    % 1) SB-corrected split-half reliability per group using SAME trialType
    rhoA = group_reliability_SB(baseDir, A, condition, thr, ttype, nSplits);
    rhoB = group_reliability_SB(baseDir, B, condition, thr, ttype, nSplits);
    rhoC = group_reliability_SB(baseDir, C, condition, thr, ttype, nSplits);

    if VERBOSE
        fprintf('[%s] SB reliabilities:  A=%.3f  B=%.3f  C=%.3f\n', ttype, rhoA, rhoB, rhoC);
    end

    % 2) Pull original rBoots in strict order [A?C, A?B, B?C]
    boots_in = outs.(ttype).rBoots;
    if numel(boots_in) ~= 3
        error('outs.%s.rBoots must be a 1x3 cell array in order {A?C, A?B, B?C}.', ttype);
    end

    % 3) Attenuation-correct each pair
    fAC = sqrt(rhoA * rhoC); fAB = sqrt(rhoA * rhoB); fBC = sqrt(rhoB * rhoC);
    rAC = clip_corr(boots_in{1} ./ max(fAC, eps), CLIP);
    rAB = clip_corr(boots_in{2} ./ max(fAB, eps), CLIP);
    rBC = clip_corr(boots_in{3} ./ max(fBC, eps), CLIP);

    % 4) Recompute means/SEMs on corrected vectors
    mu  = [mean(rAC,'omitnan'), mean(rAB,'omitnan'), mean(rBC,'omitnan')];
    sem = [std(rAC,'omitnan'),  std(rAB,'omitnan'),  std(rBC,'omitnan')];

    % 5) KS permutation p-values on corrected distributions
    [P, D] = ks_perm_3({rAC, rAB, rBC}, NPERM);

    % 6) Pack outputs in outs.<ttype>_corr (keep originals untouched)
    lbls = {'A?C','A?B','B?C'};
    outs.([ttype '_corr']) = struct( ...
        'rBoots', {{rAC, rAB, rBC}}, ...
        'means',  mu, ...
        'sems',   sem, ...
        'pvals',  P, ...
        'ksD',    D, ...
        'reliab', struct('A',rhoA,'B',rhoB,'C',rhoC), ...
        'labels', {lbls});
end

% ============================ reliability ============================

function rho_SB = group_reliability_SB(baseDir, placeCodes, condition, thr, trialType, nSplits)
% Compute SB-corrected split-half reliability for one group & trialType.

    files = getRecognitionMemFiles(baseDir, placeCodes, condition, thr);
    if isempty(files), rho_SB = NaN; return; end

    % Build participant x item matrix for the union of eligible items in this group
    items = unionOfItems(files, trialType);
    if isempty(items), rho_SB = NaN; return; end
    R = participantItemRates(files, items, trialType);  % nSub x nItems

    % Split-half across participants, Spearman r across items, average over splits
    r = nan(nSplits,1);
    n = size(R,1);
    if n < 4, rho_SB = NaN; return; end  % too few subs for reliable splitting
    for s = 1:nSplits
        idx = randperm(n);
        half1 = R(idx(1:floor(n/2)), :);
        half2 = R(idx(floor(n/2)+1:end), :);
        m1 = mean(half1, 1, 'omitnan');
        m2 = mean(half2, 1, 'omitnan');
        v  = ~isnan(m1) & ~isnan(m2);
        if nnz(v) >= 3
            r(s) = corr(m1(v).', m2(v).', 'type','Spearman', 'rows','pairwise');
        end
    end
    rbar = mean(r,'omitnan');

    % Spearman?Brown correction
    if isnan(rbar)
        rho_SB = NaN;
    else
        rho_SB = (2 * rbar) / (1 + rbar);
        rho_SB = min(max(rho_SB, 0), 0.9999); % keep in [0,1) for stability
    end
end

% ============================ KS permutation ============================

function [P, D] = ks_perm_3(bootsCell, nperm)
% Pairwise KS permutation p-values/D for three corrected bootstrap vectors.
    P = zeros(3); D = zeros(3);
    pairs = [1 2; 1 3; 2 3];
    for k = 1:size(pairs,1)
        i = pairs(k,1); j = pairs(k,2);
        a = bootsCell{i}; b = bootsCell{j};
        a = a(~isnan(a)); b = b(~isnan(b));
        if isempty(a) || isempty(b)
            pij = NaN; dij = NaN;
        else
            [pij, dij] = ks_perm(a, b, nperm);
        end
        P(i,j) = pij; P(j,i) = pij;
        D(i,j) = dij; D(j,i) = dij;
    end
end

function [pval, Dobs] = ks_perm(a, b, nperm)
% Two-sample KS test via label permutation.
    a = a(:); b = b(:);
    Dobs = ks_stat(a, b);
    pool = [a; b]; na = numel(a);
    Dnull = zeros(nperm,1);
    for t = 1:nperm
        perm = randperm(numel(pool));
        ai = pool(perm(1:na)); bi = pool(perm(na+1:end));
        Dnull(t) = ks_stat(ai, bi);
    end
    pval = mean(Dnull >= Dobs);
    pval = min(max(pval,0),1);
end

function D = ks_stat(a, b)
% KS D statistic between two samples (ECDF sup norm).
    a = sort(a(:)); b = sort(b(:));
    z = unique([a; b]);
    Fa = ecdf_at(a, z);
    Fb = ecdf_at(b, z);
    D  = max(abs(Fa - Fb));
end

function F = ecdf_at(sample_sorted, grid_sorted_unique)
% ECDF values at grid points (sample and grid are sorted).
    idx = discretize(grid_sorted_unique, [-inf; sample_sorted; inf]);
    counts = max(idx-1, 0);
    F = counts / numel(sample_sorted);
end

% ============================ utilities ============================

function r = clip_corr(r, CLIP)
% Clip correlations to [-CLIP, +CLIP] to avoid infinities after correction.
    r = max(min(r, CLIP), -CLIP);
end
