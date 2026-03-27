function runAllAnalysis(placeCodes, minISI0dprime)
% runAllAnalysis  Run the full suite of aggregate analyses for all conditions
%
%   runAllAnalysis(baseDir, placeCodes, minISI0dprime)
%
%   Inputs:
%     baseDir         ? (optional) root folder containing your .mat files.
%                       Default: ~/Tsimane2025/Data/RecognitionMemory/Results
%     placeCodes      ? (optional) cell array of place codes, e.g. {'BOS','CAM'} or {'ALL'}
%                       Default: {'ALL'}
%     minISI0dprime   ? (optional) numeric threshold for d' at ISI=0.
%                       Default: 0
%
%   Bryan Medina - 06-01-25
    % ??? Defaults ???
    
    nSplits = 1000; % number of splits for split half reliability calculations
    
    % THIS IS SUBJECT to change, so please change it here if need be
    baseDir = fullfile(getenv('HOME'), 'Documents', 'School', 'MIT', 'labs', 'mcdermott', 'Tsimane2025', 'Data', ...
                           'RecognitionMemory', 'Results');
    
    if nargin<1 || isempty(placeCodes)
        placeCodes = {'ALL'};
    end
    if nargin<2 || isempty(minISI0dprime)
        minISI0dprime = 2.0;
    end

    % the set of conditions to process
    conditions = {'NHS', 'Industrial-Nature', 'Globalized-Music'};
    %conditions = {'Globalized-Music'};


    for c = 1:numel(conditions)
        cond = conditions{c};
        fprintf('\n=== Processing condition: %s ===\n', cond);

        % 1) aggregate d? vs ISI
        plotAggregateDprime_pythonPolicy(baseDir, placeCodes, cond, minISI0dprime);

        % 2) aggregate hit rate vs ISI
        plotAggregateHitRate(baseDir, placeCodes, cond, minISI0dprime);

        % 3) aggregate false?alarm rates
        plotAggregateFalseAlarms(baseDir, placeCodes, cond, minISI0dprime);
        
        % 4) stimulus types hit rates
        plotStimulusTypeHitRates(baseDir, placeCodes, cond, minISI0dprime);
        
        % 5) item wise split half reliability of hit rates and false alarm
        % rates
        plotSplitHalfReliabilityNonzeroISI(baseDir, placeCodes, cond, minISI0dprime, nSplits);
        
%         % 6) item wise split half reliability of hit rates and false alarm
%         % rates
%         runSplitHalfPowerAnalysis(baseDir, placeCodes, cond, minISI0dprime)
    end
    
    % build place tag
    if any(strcmpi(placeCodes,'ALL'))
        placeTag = 'ALL';
    else
        placeTag = strjoin(placeCodes, '_');
    end

    fprintf('\n\nAll analyses complete.\n');
    fprintf('To view these, type the command below into the command window:\n\n');
    fprintf('+++++++++++++++++\n');
    fprintf("===> !open %s <===\n", fullfile(baseDir,'figures') );
    fprintf('+++++++++++++++++\n');
    fprintf("A finder window will open.\n");

    close all
end
