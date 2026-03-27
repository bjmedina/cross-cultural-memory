function initializeGroup(group_id, sourceSeqDir)
% initializeGroup  Copies all JSON sequences into a group-specific folder
%
% Inputs:
%   group_id      - numeric group ID (e.g., 1)
%   sourceSeqDir  - full path to source sequences (unpartitioned master list)

    % Destination folder: group-<id>
    baseGroupDir = fullfile(sourceSeqDir, sprintf('group-%d', group_id));

    % Create group folder if needed
    if ~isfolder(baseGroupDir)
        fprintf(' Creating group folder: %s\n', baseGroupDir);
        mkdir(baseGroupDir);
    else
        fprintf('?  Group folder already exists: %s\n', baseGroupDir);
    end

    % Get all JSON sequence files
    jsonFiles = dir(fullfile(sourceSeqDir, 'seq*_len120_s*_isi*.json'));
    if isempty(jsonFiles)
        error('No JSON files found in %s\n', sourceSeqDir);
    end

    % Copy each sequence into the new group folder
    for i = 1:numel(jsonFiles)
        src = fullfile(sourceSeqDir, jsonFiles(i).name);
        dst = fullfile(baseGroupDir, jsonFiles(i).name);
        copyfile(src, dst);
    end

    fprintf('? Copied %d JSON sequences to group-%d\n', numel(jsonFiles), group_id);
end
