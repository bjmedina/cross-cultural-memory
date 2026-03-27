function initializeGroupPartitions(baseGroupDir, sourceSeqDir)
% initializeGroupPartitions  Partition JSON sequence files into 4 subfolders
%
% Inputs:
%   baseGroupDir   - Full path to target group directory (e.g., '.../group-1')
%   sourceSeqDir   - Directory containing all unpartitioned JSON files

    % Step 1: Create group directory if needed
    if ~isfolder(baseGroupDir)
        fprintf('Creating group folder: %s\n', baseGroupDir);
        mkdir(baseGroupDir);
    end

    % Step 2: Load all .json sequence files from source
    jsonFiles = dir(fullfile(sourceSeqDir, 'seq*_len120_s*_isi*.json'));
    if isempty(jsonFiles)
        error('No sequence JSON files found in %s', sourceSeqDir);
    end

    % Step 3: Shuffle indices
    totalFiles = numel(jsonFiles);
    randIdx = randperm(totalFiles);

    % Step 4: Create and distribute to 4 partitions
    numPartitions = 4;
    chunkSize = ceil(totalFiles / numPartitions);

    for p = 1:numPartitions
        partName = sprintf('partition-%d', p);
        partDir = fullfile(baseGroupDir, partName);

        if ~isfolder(partDir)
            mkdir(partDir);
            fprintf('? Created %s\n', partDir);
        end

        % Assign files
        range = randIdx((p-1)*chunkSize+1 : min(p*chunkSize, totalFiles));
        for r = range
            src = fullfile(sourceSeqDir, jsonFiles(r).name);
            dst = fullfile(partDir, jsonFiles(r).name);
            copyfile(src, dst);
        end
    end

    fprintf('? Successfully initialized partitions for %s\n', baseGroupDir);
end