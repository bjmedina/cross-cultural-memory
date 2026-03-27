function globalMinAll = computeGlobalMinAcrossGroups(baseDir, allGroups, condition, minISI0dprime)
% allGroups is a cell array, e.g. {{'PRO'}, {'BOS'}, {'TSI'}, {'SBO'}}
    trialTypes = {'hit','fa'};
    allCounts = [];

    for t = 1:numel(trialTypes)
        trialType = trialTypes{t};
        for g = 1:numel(allGroups)
            files = getRecognitionMemFiles(baseDir, allGroups{g}, condition, minISI0dprime);
            if isempty(files), continue; end
            items = unionOfItems(files, trialType);
            R = participantItemRates(files, items, trialType);
            allCounts = [allCounts, sum(~isnan(R), 1)]; 
        end
    end

    globalMinAll = min(allCounts(:));
    fprintf('Completely global MinN across all groups and trial types = %d\n', globalMinAll);
end