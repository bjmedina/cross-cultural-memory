baseDir = fullfile(getenv('HOME'), 'Documents', 'School', 'MIT', 'labs', 'mcdermott', 'Tsimane2025', 'Data', ...
'RecognitionMemory', 'Results');

stimDir = fullfile(getenv('HOME'), 'Documents', 'School', 'MIT', 'labs', 'mcdermott', 'Tsimane2025', 'Data', ...
'RecognitionMemory', 'Results');

minISI0dprime = 2.0;

nBoot   = 2000;
nSplits = 50000;

placeCodesA = {'BOS', 'CAM'};
placeCodesB = {'PRO'};
placeCodesC = {'SBO'};

labels = {'Boston?San Borja','Boston?Prolific','Prolific?San Borja'};  

stim_type = 'Globalized-Music';

% DETERMINE WHAT THE GLOBAL MINIMUM IS
% ====================================
allGroups = {placeCodesA, placeCodesB, placeCodesC};
globalMinAll = computeGlobalMinAcrossGroups(baseDir, allGroups, stim_type, minISI0dprime);


outs = intergroupTripleReliabilityPlot( ...
baseDir, placeCodesA, placeCodesB, placeCodesC, ...
stim_type, 2.0, nBoot, globalMinAll);


outs = applyAttenuationAndKS(outs, baseDir, placeCodesA, placeCodesB, placeCodesC, stim_type, 2.0, nSplits, ...
                             'NPerm', 2000, 'Clip', 0.9999, 'Verbose', true);
                         
figs = plotIntergroupTripleWithSwarm( ...
    struct('hit', outs.hit_corr, 'fa', outs.fa_corr), ...
    labels, stim_type, baseDir, 'ErrorType','sem');  % sems are std of corrected boots