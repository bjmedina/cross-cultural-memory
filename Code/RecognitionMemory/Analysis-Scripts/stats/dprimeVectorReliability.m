function rel = dprimeVectorReliability(R_hit, R_fa, nSplits)
% dprimeVectorReliability
%   Computes split-half reliability of the *itemwise d? vector*.
%
% Inputs:
%   R_hit   : participants x items hit rate matrix
%   R_fa    : participants x items false alarm matrix
%   nSplits : number of random splits (default 1000)
%
% Output struct rel:
%   .raw_r  : array of split-half correlations
%   .mean_r : mean correlation across splits
%   .ci     : 95% confidence interval
%   .sb     : Spearman?Brown corrected reliability
%
% Bryan Medina (2025)

    if nargin < 3, nSplits = 1000; end

    R_hit = double(R_hit);
    R_fa  = double(R_fa);

    nP = size(R_hit,1);
    half = floor(nP/2);

    raw_r = nan(nSplits,1);

    for s = 1:nSplits
        idx = randperm(nP);
        g1 = idx(1:half);
        g2 = idx(half+1 : 2*half);

        % recompute itemwise means per split
        h1 = mean(R_hit(g1,:), 'omitnan');
        h2 = mean(R_hit(g2,:), 'omitnan');

        f1 = mean(R_fa(g1,:),  'omitnan');
        f2 = mean(R_fa(g2,:),  'omitnan');

        % d' for each half
        dp1 = computeDprime(h1, f1);
        dp2 = computeDprime(h2, f2);

        % correlation of the itemwise d? vectors
        raw_r(s) = corr(dp1(:), dp2(:), 'type','Pearson','rows','complete');
    end

    % Spearman?Brown correction
    sb = @(r) (2*r)./(1+r);

    rel.raw_r  = raw_r;
    rel.mean_r = mean(raw_r,'omitnan');
    rel.ci     = quantile(raw_r,[0.025 0.975]);
    rel.sb     = sb(rel.mean_r);
end

function dp = computeDprime(hit, fa)
    eps = 1e-2;
    hit = min(max(hit, eps),1-eps);
    fa  = min(max(fa,  eps),1-eps);
    dp = norminv(hit) - norminv(fa);
end