function [jk_raw, jk_corr] = jackknifeIntergroupCorr(A, B, varargin)
% jackknifeIntergroupCorr
%   Leave-one-out intergroup correlations at the same resampling level as
%   the cluster bootstrap. Used by ciBCa for its acceleration term.
%
%   [jk_raw, jk_corr] = jackknifeIntergroupCorr(A, B, Name, Value, ...)
%
%   A, B     : group matrices [n_g x n_items] aligned on shared items.
%
%   Name/Value:
%     'Dim'      (1)    1 = jackknife participants (drop one from A, then
%                       one from B, concatenate -> length n_A + n_B);
%                       2 = jackknife stimuli (drop one column at a time
%                       -> length n_items).
%     'CorrType' ('Spearman') passed to itemwiseCorr
%     'MinResp'  (2)    passed to itemwiseCorr
%     'MinItems' (5)    passed to itemwiseCorr
%     'SB_A','SB_B'  : if both provided and finite, jk_corr is the
%                      attenuation-corrected jackknife distribution; else NaN.

    p = inputParser;
    addParameter(p, 'Dim', 1, @isscalar);
    addParameter(p, 'CorrType', 'Spearman');
    addParameter(p, 'MinResp', 2, @isscalar);
    addParameter(p, 'MinItems', 5, @isscalar);
    addParameter(p, 'SB_A', NaN);
    addParameter(p, 'SB_B', NaN);
    parse(p, varargin{:});
    o = p.Results;

    [nA, nItems] = size(A);
    nB = size(B, 1);

    if o.Dim == 1
        jk_raw = nan(nA + nB, 1);
        for i = 1:nA
            keep = true(nA, 1); keep(i) = false;
            jk_raw(i) = itemwiseCorr(A(keep, :), B, o.CorrType, o.MinResp, o.MinItems);
        end
        for j = 1:nB
            keep = true(nB, 1); keep(j) = false;
            jk_raw(nA + j) = itemwiseCorr(A, B(keep, :), o.CorrType, o.MinResp, o.MinItems);
        end
    elseif o.Dim == 2
        jk_raw = nan(nItems, 1);
        for j = 1:nItems
            keep = true(nItems, 1); keep(j) = false;
            jk_raw(j) = itemwiseCorr(A(:, keep), B(:, keep), o.CorrType, o.MinResp, o.MinItems);
        end
    else
        error('Dim must be 1 (participants) or 2 (stimuli).');
    end

    if isfinite(o.SB_A) && isfinite(o.SB_B)
        denom = max(sqrt(max(o.SB_A * o.SB_B, 0)), eps);
        jk_corr = max(-1, min(1, jk_raw / denom));
    else
        jk_corr = nan(size(jk_raw));
    end
end
