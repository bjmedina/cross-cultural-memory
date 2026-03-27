function outs = runIntergroupCorrelationPipeline(baseDir, trial_type, condition, placeCodesA, placeCodesB, placeCodesC)
% runIntergroupCorrelationPipeline
%   Computes split-half reliabilities, intergroup itemwise correlations
%   (raw + attenuation-corrected) for three groups, and proper paired
%   bootstrap p-values for pairwise comparisons between group pairs.
%
%   v2: Uses participant-level bootstrap at actual sample sizes (not
%   nEqual=100 oversampling), Spearman-Brown corrected reliability for
%   attenuation correction, and paired bootstrap for p-values.
%
%   Bryan Medina -- Bolivia 2025 / Statistical fixes Feb 2026

    % ----- Configuration -----
    minISI0dprime = 2.0;
    isMultiISI  = false;
    nSplits     = 10000;
    splitDim    = 2;      % 1=participants, 2=stimuli
    nBoot       = 5000;

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

    % Use bootstrapIntergroupCorrelationSEM with proper settings:
    %   - BootstrapDim=1: resample participants (actual sample sizes)
    %   - ReliabilityMode='per-draw': recompute reliability each bootstrap
    %     iteration to propagate uncertainty into corrected CIs
    %   - UseSpearman=true: consistent with rest of pipeline
    bootOpts = {'BootstrapDim', 1, 'ReliabilityMode', 'per-draw', ...
                'CorrectAtten', true, 'UseSpearman', true, ...
                'nBoot', nBoot, 'SplitHalfRepeats', 200, ...
                'ReliabilitySplitDim', splitDim};

    ac = bootstrapIntergroupCorrelationSEM(outsA, outsC, trial_type, bootOpts{:});
    ab = bootstrapIntergroupCorrelationSEM(outsA, outsB, trial_type, bootOpts{:});
    bc = bootstrapIntergroupCorrelationSEM(outsB, outsC, trial_type, bootOpts{:});

    % ----- Step 3: Paired bootstrap p-values -----
    fprintf('\n=== Step 3: Paired bootstrap comparison ===\n');

    pvalsResult = pairedBootstrapCompareCorrelations(outsA, outsB, outsC, trial_type, ...
        'nBoot', nBoot, 'UseSpearman', true, 'BootstrapDim', 1);

    close all;
    % ----- Step 4: Plot summary with p-values -----
    fprintf('\n=== Step 4: Plotting summary ===\n');
    plotTripleIntergroupBar_v2(ac, ab, bc, condition, trial_type, baseDir, pvalsResult.pmat);

    % ----- Package output -----
    outs = struct();
    outs.ac = ac;
    outs.ab = ab;
    outs.bc = bc;
    outs.pvals = pvalsResult;
    outs.reliabilities = struct('A', outsA, 'B', outsB, 'C', outsC);

    fprintf('\nDone! Intergroup correlation pipeline complete.\n');
end
