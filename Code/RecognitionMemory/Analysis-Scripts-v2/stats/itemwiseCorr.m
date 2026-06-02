function [r, valid] = itemwiseCorr(A, B, corrType, minResp, minItems)
% itemwiseCorr
%   Item-level correlation between two group matrices A, B (size
%   [nSub_g x nItems], NaN for unobserved). Keeps only items meeting
%   `minResp` non-NaN observations in each group; requires `minItems`
%   surviving items, else returns NaN.
%
%   [r, valid] = itemwiseCorr(A, B, corrType, minResp, minItems)
%
%   corrType : 'Spearman' (default) or 'Pearson'
%   minResp  : per-item min non-NaN obs per group (default 2)
%   minItems : min surviving items required (default 5)
%
%   r     : item-level group-mean correlation
%   valid : logical row vector of items retained
%
%   Shared helper used by bootstrapIntergroupCorrelationSEM,
%   pairedBootstrapCompareCorrelations, and the Python twins.

    if nargin < 3, corrType = 'Spearman'; end
    if nargin < 4, minResp  = 2; end
    if nargin < 5, minItems = 5; end

    nObsA = sum(~isnan(A), 1);
    nObsB = sum(~isnan(B), 1);
    valid = (nObsA >= minResp) & (nObsB >= minResp);

    if sum(valid) < minItems
        r = NaN;
        return
    end

    meanA = nanmean(A(:, valid), 1)';
    meanB = nanmean(B(:, valid), 1)';
    r = corr(meanA, meanB, 'Type', corrType, 'Rows', 'pairwise');
end
