function [sequence, types_order, seq_idx, stim_folder] = getUniqueSequence(block, group_id, computer_id)
% getUniqueSequence  Select a non-repeating sequence from a computer-specific slice
%
% Inputs:
%   block        - experiment block ID
%   group_id     - numeric group ID
%   computer_id  - which computer (1?6) determines which 104 files to use
% 
%
% Outputs:
%   sequence     - stimulus ID vector
%   types_order  - cell array of stimulus type labels
%   seq_idx      - index into this computer's slice (1?110)
%   stim_folder  - base path for this stimulus set

    basePath = '~/static2025/Stimuli/RecognitionMemory';

    % Map block to experiment folder name
    switch block
        case 1, expName = 'nhs-region-n_80';
        case 2, expName = 'mem_exp_ind-nature_2025';
        case 3, expName = 'mem_exp_atexts_2025';
        case 4, expName = 'global-music-2025-n_80';
        otherwise, error('Invalid block ID: %d', block);
    end
%     switch block
%         case 1, expName = 'nhs-region-n_80/sequences/isi_16/len120_bolivia';
%         case 2, expName = 'mem_exp_ind-nature_2025/sequences/isi_16/len120_bolivia';
%         case 3, expName = 'mem_exp_atexts_2025/sequences/isi_16/len120_bolivia';
%         case 4, expName = 'global-music-2025-n_80/sequences/isi_16/len120_bolivia';
%         case 5, expName = 'global-music-2025-n_80/sequences/isi_8/len120_bolivia';
%         otherwise, error('Invalid block ID: %d', block);
%     end  

    sourceDir   = fullfile(basePath, expName);
    groupDir      = fullfile(sourceDir, sprintf('group-%d', group_id));

    % Load all available JSONs
    jsonFiles = dir(fullfile(sourceDir, 'seq*_len120_s*_isi*.json'));
    if isempty(jsonFiles)
        error('No JSON files found in %s\n', sourceDir);
    end

    % Sort alphabetically (assumes numbering is consistent like seq001, seq002, etc.)
    jsonFiles = sortStructByName(jsonFiles);

    % Partition logic // based on computer id it will select 104
    % sequences from a grand set to place available on this computer
    filesPerComputer = 104;
    startIdx = (computer_id - 1) * filesPerComputer + 1;
    endIdx = min(computer_id * filesPerComputer, numel(jsonFiles));
    if startIdx > numel(jsonFiles)
        error('Computer %d has no assigned sequences ? check total file count.', computer_id);
    end
    slice = jsonFiles(startIdx:endIdx);
    sliceCount = numel(slice);

    % Create group folder if it doesn't exist, and populate with only the assigned slice
    if ~isfolder(groupDir)
        fprintf('? Creating and populating: %s\n', groupDir);
        mkdir(groupDir);
        for i = 1:sliceCount
            src = fullfile(sourceDir, slice(i).name);
            dst = fullfile(groupDir, slice(i).name);
            copyfile(src, dst);
        end
        fprintf('? Group-%d initialized with %d files for computer %d\n', group_id, sliceCount, computer_id);
    end

    % List files in group folder
    jsonFiles = dir(fullfile(groupDir, 'seq*_len120_s*_isi*.json'));
    numSeq = numel(jsonFiles);

    % Load usage log
    logDir = fullfile(stim_folder, 'used_logs');
    if ~exist(logDir, 'dir'), mkdir(logDir); end
    logFile = fullfile(logDir, sprintf('used_seq_group%02d_comp%02d.mat', group_id, computer_id));

    used_idx = [];
    if isfile(logFile)
        data = load(logFile);
        if isfield(data, 'used_idx'), used_idx = data.used_idx; end
    end

    available_idx = setdiff(1:numSeq, used_idx);
    if isempty(available_idx)
        error('All sequences used for group %d on computer %d.', group_id, computer_id);
    end

    % Randomly select from available
    % pick = available_idx(randi(numel(available_idx)));
    pick = available_idx(1);
    jsonPath = fullfile(groupDir, jsonFiles(pick).name);

    fid = fopen(jsonPath, 'r');
    if fid == -1, error('Could not open JSON: %s', jsonPath); end
    raw = fread(fid, inf); str = char(raw'); fclose(fid);
    seqData = jsondecode(str);

    sequence = seqData.order;
    types_order = seqData.types_order;
    seq_idx = pick;

    % Save usage
    used_idx(end+1) = pick;
    save(logFile, 'used_idx');
end

function sortedStruct = sortStructByName(structArray)
% Helper: sort struct array by .name field (ascending)
    [~, idx] = sort({structArray.name});
    sortedStruct = structArray(idx);
end
