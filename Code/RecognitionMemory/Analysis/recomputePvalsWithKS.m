function outs = recomputePvalsWithKS(outs, varargin)
% recomputePvalsWithKS
%   Recompute pairwise p-values BETWEEN THE THREE BARS using a **two-sample KS test**
%   on the underlying bootstrap distributions in outs.*.rBoots. Also (re)computes
%   SEMs from the bootstrap SDs (i.e., sem = std(boots), *no* /sqrt(nBoot)).
%
% Usage:
%   outs = recomputePvalsWithKS(outs);                      % default: permutation KS, 20k perms
%   outs = recomputePvalsWithKS(outs,'Method','matlab');    % MATLAB's kstest2() p-values
%   outs = recomputePvalsWithKS(outs,'Method','perm','NPerm',50000); % perm KS with 50k perms
%
% Inputs:
%   outs : struct with fields like outs.hit.rBoots = {rAC,rAB,rBC}, outs.fa.rBoots = {...}
%
% Name/Value options:
%   'Method' : 'perm' (default; label-permutation KS) or 'matlab' (calls kstest2)
%   'NPerm'  : integer, # permutations for 'perm' method (default 20000)
%
% Output (mutates & returns `outs`):
%   - outs.hit.sems / outs.fa.sems           : 1x3 vector of SEMs (= std of boots)
%   - outs.hit.pvals / outs.fa.pvals         : 3x3 matrix of KS p-values
%   - outs.hit.ksD   / outs.fa.ksD           : 3x3 matrix of KS D statistics
%
% Notes:
%   ? KS compares **entire distributions**, not just means.
%   ? The permutation KS is distribution-free and respects different sample sizes.
%   ? Bootstrap vectors may contain ties; KS handles this fine (perm method is safest).

    % -------- options --------
    p = inputParser;
    addParameter(p, 'Method', 'perm', @(s) any(strcmpi(s,{'perm','matlab'})));
    addParameter(p, 'NPerm', 20000, @(x) isnumeric(x) && isscalar(x) && x>0);
    parse(p, varargin{:});
    method = lower(p.Results.Method);
    nperm  = p.Results.NPerm;

    % Recompute for both sections if present
    if isfield(outs,'hit')
        [P,D,SEMs] = section_ks(outs.hit.rBoots, method, nperm);
        outs.hit.pvals = P;
        outs.hit.ksD   = D;
        outs.hit.sems  = SEMs;
    end
    if isfield(outs,'fa')
        [P,D,SEMs] = section_ks(outs.fa.rBoots, method, nperm);
        outs.fa.pvals = P;
        outs.fa.ksD   = D;
        outs.fa.sems  = SEMs;
    end
end

% ======================== helpers ========================

function [P,D,SEMs] = section_ks(rBootCell, method, nperm)
% Compute pairwise KS p-values (and D stats) for the 3 bars; also SEMs.
% rBootCell must be {r1, r2, r3} corresponding to bars [A?C, A?B, B?C].
    if ~iscell(rBootCell) || numel(rBootCell) ~= 3
        error('Expected rBootCell to be a 1x3 cell array of bootstrap vectors.');
    end
    % Clean boots + SEMs
    boots = cell(1,3);
    SEMs  = nan(1,3);
    for k = 1:3
        v = rBootCell{k};
        v = v(~isnan(v));
        boots{k} = v(:);
        if isempty(v), SEMs(k) = NaN; else, SEMs(k) = std(v); end   % bootstrap SE = SD of boots
    end

    % Pairwise KS
    P = zeros(3); D = zeros(3);
    pairs = [1 2; 1 3; 2 3];
    for p = 1:size(pairs,1)
        i = pairs(p,1); j = pairs(p,2);
        a = boots{i}; b = boots{j};
        if isempty(a) || isempty(b)
            pij = NaN; dij = NaN;
        else
            switch method
                case 'matlab'
                    % MATLAB's two-sample KS test (asymptotic p)
                    [~, pij, dij] = kstest2(a, b, 'Alpha', 0.05); 
                case 'perm'
                    % Permutation KS: exact-by-simulation p-value
                    [pij, dij] = ks_perm(a, b, nperm);
            end
        end
        P(i,j) = pij; P(j,i) = pij;
        D(i,j) = dij; D(j,i) = dij;
    end
end

function [pval, Dobs] = ks_perm(a, b, nperm)
% Permutation KS between vectors a and b.
% Returns two-sided p-value and observed KS statistic D.
    a = a(:); b = b(:);
    Dobs = ks_stat(a, b);

    pool = [a; b];
    na = numel(a); nb = numel(b);
    Dnull = zeros(nperm,1);

    % Pre-generate permutations efficiently
    for t = 1:nperm
        perm = randperm(na+nb);
        ai = pool(perm(1:na));
        bi = pool(perm(na+1:end));
        Dnull(t) = ks_stat(ai, bi);
    end
    % Two-sided p-value as tail prob
    pval = mean(Dnull >= Dobs);
    pval = min(max(pval,0),1);
end

function D = ks_stat(a, b)
% Compute the Kolmogorov?Smirnov D statistic between samples a and b.
% Uses ECDFs evaluated at all pooled unique points.
    a = sort(a(:)); b = sort(b(:));
    z = unique([a; b]);
    Fa = ecdf_at(a, z);
    Fb = ecdf_at(b, z);
    D  = max(abs(Fa - Fb));
end

function F = ecdf_at(sample_sorted, grid_sorted_unique)
% Fast ECDF evaluation at a given grid for pre-sorted samples.
    % For each grid point z_k, count how many sample values <= z_k.
    idx = discretize(grid_sorted_unique, [-inf; sample_sorted; inf]);
    % idx(k) gives 1 + count(sample <= z_k). Convert to counts:
    counts = max(idx-1, 0);
    F = counts / numel(sample_sorted);
end