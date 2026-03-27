
baseDir = fullfile(getenv('HOME'), 'Documents', 'School', 'MIT', 'labs', 'mcdermott', 'Tsimane2025', 'Data', ...
'RecognitionMemory', 'Results');

minISI0dprime = 2.0;

placeCodesA = {'BOS', 'CAM'};
placeCodesB = {'MAN','MAJ','NVM','NUM','NUV','CVR'};
placeCodesC = {'SBO'};
placeCodesD = {'PRO'};


[itemStats, summary] = groupItemPerformanceSummary(baseDir, ...
    placeCodesA, 'NHS', 0.5, 'hit', 'TopK', 10, 'ShowPlot', true);

[itemStats, summary] = groupItemPerformanceSummary(baseDir, ...
    placeCodesB, 'NHS', 0.5, 'hit', 'TopK', 10, 'ShowPlot', true);

[itemStats, summary] = groupItemPerformanceSummary(baseDir, ...
    placeCodesC, 'NHS', 0.5, 'hit', 'TopK', 10, 'ShowPlot', true);