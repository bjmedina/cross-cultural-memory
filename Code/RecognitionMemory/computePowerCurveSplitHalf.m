function [sizes, means, stds] = computePowerCurveSplitHalf(data, varargin)
% computePowerCurveSplitHalf
%   Computes split-half power curve by bootstrapping over increasing participant sample sizes.
%
%   Inputs:
%     data - [N_subjects x N_items] response matrix with NaNs
%
%   Optional Name-Value Pairs:
%     'nRepeats' (default: 20)
%     'nSplits'  (default: 50)
%     'step'     (default: 5)
%     'seed'     (default: 42)
%
%   Outputs:
%     sizes - participant counts used
%     means - average split-half reliability at each count
%     stds  - std dev of reliability estimates

    % Parse inputs
    p = inputParser;
    addParameter(p, 'nRepeats', 20);
    addParameter(p, 'nSplits', 50);
    addParameter(p, 'step', 5);
    addParameter(p, 'seed', 42);
    parse(p, varargin{:});
    opts = p.Results;

    rng(opts.seed);
    nTotal = size(data, 1);
    sizes = opts.step:opts.step:nTotal;

    % Ensure full sample size is included (if not already)
    if sizes(end) < nTotal
        sizes(end+1) = nTotal;
    end

    means = nan(size(sizes));
    stds  = nan(size(sizes));

    for i = 1:numel(sizes)
        n = sizes(i);
        rs = nan(opts.nRepeats, 1);

        for j = 1:opts.nRepeats
            idx = randperm(nTotal, n);
            sampleData = data(idx, :);
            [r, ~] = estimateSplitHalf(sampleData, opts.nSplits);
            rs(j) = (2*r)/(1+r);
        end

        means(i) = mean(rs, 'omitnan');
        stds(i)  = std(rs, 'omitnan');
    end
end