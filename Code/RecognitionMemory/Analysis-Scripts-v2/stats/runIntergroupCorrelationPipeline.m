function outs = runIntergroupCorrelationPipeline(baseDir, trial_type, condition, placeCodesA, placeCodesB, placeCodesC, varargin)
% runIntergroupCorrelationPipeline
%   Computes split-half reliabilities, intergroup itemwise correlations
%   (raw + attenuation-corrected) for three groups, and proper paired
%   bootstrap p-values for pairwise comparisons between group pairs.
%
%   v3: participant-split reliability (splitDim=1) to match stimulus-level
%   intergroup correlations; configurable minResp; bar order [AB, AC, BC].
%
%   Optional Name/Value:
%     'minResp'  (2)  - min non-NaN observations per stimulus per group
%                       in each bootstrap draw
%
%   Bryan Medina -- Bolivia 2025 / Statistical fixes Feb-Mar 2026

    % ----- Parse optional arguments -----
    p = inputParser;
    addParameter(p, 'minResp', 2, @isscalar);
    parse(p, varargin{:});
    minResp = p.Results.minResp;

    % ----- Configuration -----
    minISI0dprime = 2.0;
    isMultiISI  = false;
    nSplits     = 10000;
    splitDim    = 1;      % participant split -> stimulus-level reliability
    nBoot       = 5000;

    labelA = strjoin(placeCodesA, '/');
    labelB = strjoin(placeCodesB, '/');
    labelC = strjoin(placeCodesC, '/');

    % ----- Step 1: Split-half reliabilities -----
    fprintf('\n=== Step 1: Split-half reliabilities ===\n');

    outsA = calculateSplitHalfReliability(baseDir, placeCodesA, condition, ...
        minISI0dprime, isMultiISI, nSplits, splitDim, false);

    outsB = calculateSplitHalfReliability(baseDir, placeCodesB, condition, ...
        minISI0dprime, isMultiISI, nSplits, splitDim, false);

    outsC = calculateSplitHalfReliability(baseDir, placeCodesC, condition, ...
        minISI0dprime, isMultiISI, nSplits, splitDim, false);

    % ----- Step 2: Intergroup correlations via participant-level bootstrap -----
    fprintf('\n=== Step 2: Intergroup itemwise correlations (bootstrap) ===\n');

    bootOpts = {'BootstrapDim', 1, 'ReliabilityMode', 'per-draw', ...
                'CorrectAtten', true, 'UseSpearman', true, ...
                'nBoot', nBoot, 'SplitHalfRepeats', 200, ...
                'ReliabilitySplitDim', splitDim, ...
                'minResp', minResp};

    fprintf('  %s vs %s ...\n', labelA, labelC);
    ac = bootstrapIntergroupCorrelationSEM(outsA, outsC, trial_type, bootOpts{:});

    fprintf('  %s vs %s ...\n', labelA, labelB);
    ab = bootstrapIntergroupCorrelationSEM(outsA, outsB, trial_type, bootOpts{:});

    fprintf('  %s vs %s ...\n', labelB, labelC);
    bc = bootstrapIntergroupCorrelationSEM(outsB, outsC, trial_type, bootOpts{:});

    % ----- Step 3: Paired bootstrap p-values -----
    fprintf('\n=== Step 3: Paired bootstrap comparison ===\n');

    pvalsResult = pairedBootstrapCompareCorrelations(outsA, outsB, outsC, trial_type, ...
        'nBoot', nBoot, 'UseSpearman', true, 'BootstrapDim', 1, 'minResp', minResp);

    close all;
    % ----- Step 4: Plot summary with p-values -----
    fprintf('\n=== Step 4: Plotting summary ===\n');
    % Bar order: [AB, AC, BC] so US-Tsimane' is in the center
    plotTripleIntergroupBar_v2(ab, ac, bc, condition, trial_type, baseDir, pvalsResult.pmat);

    % ----- Package output -----
    outs = struct();
    outs.ac = ac;
    outs.ab = ab;
    outs.bc = bc;
    outs.pvals = pvalsResult;
    outs.reliabilities = struct('A', outsA, 'B', outsB, 'C', outsC);

    fprintf('\nDone! Intergroup correlation pipeline complete.\n');
end
