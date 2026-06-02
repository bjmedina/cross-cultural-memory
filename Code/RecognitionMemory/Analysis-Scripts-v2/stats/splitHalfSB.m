function SB = splitHalfSB(M, corrType, nRep, splitDim)
% splitHalfSB
%   Spearman-Brown corrected split-half reliability for a single matrix M
%   ([nSub x nItems], NaN for missing). Thin wrapper around
%   estimateSplitHalfFlexible that returns SB directly with plotting off.
%
%   SB = splitHalfSB(M, corrType, nRep, splitDim)
%
%   corrType : 'Spearman' (default) or 'Pearson'
%   nRep     : number of random splits (default 200)
%   splitDim : 1 = split across participants (default), 2 = across stimuli
%
%   Returns NaN if M is empty or has too few rows/columns to split.
%
%   Shared helper used by bootstrapIntergroupCorrelationSEM (reliabilities
%   for attenuation correction) and the Python twin.

    if nargin < 2, corrType = 'Spearman'; end
    if nargin < 3, nRep     = 200; end
    if nargin < 4, splitDim = 1; end

    if isempty(M), SB = NaN; return; end
    [nSub, nItems] = size(M);
    if (splitDim == 1 && nSub < 4) || (splitDim == 2 && nItems < 4)
        SB = NaN; return
    end

    % point_r is the MEDIAN of per-split correlations (see
    % estimateSplitHalfFlexible).
    point_r = estimateSplitHalfFlexible(M, nRep, splitDim, corrType, false);
    if isnan(point_r)
        SB = NaN; return
    end
    SB = (2 * point_r) / (1 + point_r);
end
