function [m, ok] = mean_with_min_coverage(Rhalf, minSubs)
% Column-wise mean requiring >= minSubs non-NaN observations.
    nPerItem = sum(~isnan(Rhalf), 1);
    ok = nPerItem >= minSubs;
    m  = nan(1, size(Rhalf,2));
    m(ok) = mean(Rhalf(:, ok), 'omitnan');
end