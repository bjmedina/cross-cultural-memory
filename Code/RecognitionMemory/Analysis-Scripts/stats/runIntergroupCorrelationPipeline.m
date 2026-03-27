function runIntergroupCorrelationPipeline(baseDir, trial_type, condition, placeCodesA, placeCodesB, placeCodesC)
% runIntergroupCorrelationPipeline
%   Computes split-half reliabilities and intergroup itemwise correlations
%   (raw + attenuation-corrected) for three groups.
%
%   No bootstrapping ? just point estimates and a summary bar plot.
%
%   Bryan Medina ? Bolivia 2025

    % ----- Configuration -----
    %condition     = 'Industrial-Nature';
    minISI0dprime = 2.0;
    isMultiISI  = false;
    nSplits     = 10000;
    splitDim    = 1;      % 1=participants, 2=stimuli
    
%     runAllAnalysis(placeCodesA, minISI0dprime); %all analysis for an individual group...
%     runAllAnalysis(placeCodesB, minISI0dprime);
%     runAllAnalysis(placeCodesC, minISI0dprime);

    % ----- Step 1: Split-half reliabilities -----
    fprintf('\n=== Step 1: Split-half reliabilities ===\n');

    a = calculateSplitHalfReliability(baseDir, placeCodesA, condition, ...
        minISI0dprime, isMultiISI, nSplits, splitDim, false);

    b = calculateSplitHalfReliability(baseDir, placeCodesB, condition, ...
        minISI0dprime, isMultiISI, nSplits, splitDim, false);

    c = calculateSplitHalfReliability(baseDir, placeCodesC, condition, ...
        minISI0dprime, isMultiISI, nSplits, splitDim, false);

    % ----- Step 2: Intergroup correlations -----
    fprintf('\n=== Step 2: Intergroup itemwise correlations  ===\n');

%     ac = bootstrapIntergroupItemwiseCorrelation(a, c, trial_type, ...
%         'ApplyAttenuationCorrection', true, 'ShowPlot', false);
% 
%     ab = bootstrapIntergroupItemwiseCorrelation(a, b, trial_type, ...
%         'ApplyAttenuationCorrection', true, 'ShowPlot', falcse);
% 
%     bc = bootstrapIntergroupItemwiseCorrelation(b, c, trial_type, ...
%         'ApplyAttenuationCorrection', true, 'ShowPlot', false);
%     
    
    ac = simulateIntergroupItemwiseCorrelation(a, c, trial_type, ...
        'ApplyAttenuationCorrection', true, 'ShowPlot', false, 'nEqual', 100, 'nSim', 5000, 'SubsampleLevel', 'participant');

    ab = simulateIntergroupItemwiseCorrelation(a, b, trial_type, ...
        'ApplyAttenuationCorrection', true, 'ShowPlot', false, 'nEqual', 100, 'nSim', 5000, 'SubsampleLevel', 'participant');

    bc = simulateIntergroupItemwiseCorrelation(b, c, trial_type, ...
        'ApplyAttenuationCorrection', true, 'ShowPlot', false, 'nEqual', 100, 'nSim', 5000, 'SubsampleLevel', 'participant');


    close all; 
    % ----- Step 3: Plot summary -----
    fprintf('\n=== Step 3: Plotting summary ===\n');
    plotTripleIntergroupBar_v2(ac, ab, bc, condition, trial_type, baseDir);

    fprintf('\n? Done! Intergroup correlation pipeline (no bootstrap) complete.\n');
end