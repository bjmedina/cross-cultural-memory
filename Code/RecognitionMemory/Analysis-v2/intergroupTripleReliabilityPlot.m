function outs = intergroupTripleReliabilityPlot( ...
    baseDir, placeCodesA, placeCodesB, placeCodesC, ...
    condition, minISI0dprime, nBoot, globalMin)
% intergroupTripleReliabilityPlot
%   Compute and plot intergroup reliability for three groups (A,B,C).
%
%   Produces TWO figures: one for 'hit' and one for 'fa'.
%   Each figure shows three bars (in this exact order): A-C, A-B, B-C,
%   with 95% CI error bars and pairwise p-values annotated above bars.
%
%   v2: P-values computed via PAIRED stimulus-level bootstrap (shared
%   stimulus resample across all pairs within each iteration). This
%   replaces the invalid KS-on-independent-bootstraps approach.
%
% Inputs:
%   baseDir         : folder containing .mat files
%   placeCodesA     : cellstr for Group A (e.g., {'BOS','CAM'} or {'ALL'})
%   placeCodesB     : cellstr for Group B
%   placeCodesC     : cellstr for Group C
%   condition       : string to match in filename (e.g., 'Industrial-Nature')
%   minISI0dprime   : numeric threshold (filters participants)
%   nBoot           : number of bootstrap replicates (e.g., 10000)
%   globalMin       : (unused, kept for backward compatibility)
%
% Output:
%   outs : struct with fields:
%          outs.hit.rBoots = {rAC, rAB, rBC};
%          outs.hit.summary = struct array for each pair;
%          outs.hit.pvals = 3x3 matrix of pairwise p-values;
%          outs.fa.(...) same as above for 'fa'.
%
% Bryan Medina -- Bolivia 2025 / Statistical fixes Feb 2026

    % -------- Per-pair stimulus bootstrap for CIs --------
    % HIT
    [rAC_hit, sumAC_hit] = pair_boot_stim(baseDir, placeCodesA, placeCodesC, condition, minISI0dprime, nBoot, 'hit');
    [rAB_hit, sumAB_hit] = pair_boot_stim(baseDir, placeCodesA, placeCodesB, condition, minISI0dprime, nBoot, 'hit');
    [rBC_hit, sumBC_hit] = pair_boot_stim(baseDir, placeCodesB, placeCodesC, condition, minISI0dprime, nBoot, 'hit');

    % FA
    [rAC_fa, sumAC_fa] = pair_boot_stim(baseDir, placeCodesA, placeCodesC, condition, minISI0dprime, nBoot, 'fa');
    [rAB_fa, sumAB_fa] = pair_boot_stim(baseDir, placeCodesA, placeCodesB, condition, minISI0dprime, nBoot, 'fa');
    [rBC_fa, sumBC_fa] = pair_boot_stim(baseDir, placeCodesB, placeCodesC, condition, minISI0dprime, nBoot, 'fa');

    % -------- Paired bootstrap p-values (stimulus-level) --------
    % Build participant x item matrices for each group via calculateSplitHalfReliability.
    % This gives us the raw data needed for a paired stimulus-level bootstrap.
    fprintf('Computing paired bootstrap p-values (stimulus-level)...\n');
    isMultiISI = false;
    nSplits = 1000;  % just need the matrices, split-half values not critical here
    splitDim = 1;

    outsA = calculateSplitHalfReliability(baseDir, placeCodesA, condition, ...
        minISI0dprime, isMultiISI, nSplits, splitDim, false);
    outsB = calculateSplitHalfReliability(baseDir, placeCodesB, condition, ...
        minISI0dprime, isMultiISI, nSplits, splitDim, false);
    outsC = calculateSplitHalfReliability(baseDir, placeCodesC, condition, ...
        minISI0dprime, isMultiISI, nSplits, splitDim, false);

    % Paired bootstrap with shared stimulus resample (BootstrapDim=2)
    pvals_hit = pairedBootstrapCompareCorrelations(outsA, outsB, outsC, 'hit', ...
        'nBoot', nBoot, 'UseSpearman', true, 'BootstrapDim', 2);

    pvals_fa = pairedBootstrapCompareCorrelations(outsA, outsB, outsC, 'fa', ...
        'nBoot', nBoot, 'UseSpearman', true, 'BootstrapDim', 2);

    p_hit = pvals_hit.pmat;
    p_fa  = pvals_fa.pmat;

    % -------- OUTPUT PACK --------
    outs = struct();
    outs.hit = struct('rBoots', {{rAC_hit, rAB_hit, rBC_hit}}, ...
                      'summary', { [sumAC_hit, sumAB_hit, sumBC_hit] }, ...
                      'pvals', p_hit, ...
                      'pairedBootstrap', pvals_hit);
    outs.fa  = struct('rBoots', {{rAC_fa, rAB_fa, rBC_fa}}, ...
                      'summary', { [sumAC_fa, sumAB_fa, sumBC_fa] }, ...
                      'pvals', p_fa, ...
                      'pairedBootstrap', pvals_fa);
end

% ============================ HELPERS ============================

function [rBoot, summary] = pair_boot_stim(baseDir, pX, pY, condition, minISI0dprime, nBoot, trialType)
% Wrapper to call the stimulus-level intergroup correlation bootstrap.
    [rBoot, summary] = intergroupCorrelationBootstrapStimuli( ...
        baseDir, pX, pY, condition, minISI0dprime, trialType, ...
        'NBoot', nBoot);
end
