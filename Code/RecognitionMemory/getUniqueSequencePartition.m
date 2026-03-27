function [sequence, types_order, seq_idx, stim_folder] = getUniqueSequencePartition(block, group_id, partition_id)
% getUniqueSequence  Select a non-repeating sequence from a group/partition pool
%
% Inputs:
%   block         - experiment block (1 = NHS-Globalized, 2 = Industrial-Nature, 3 = Textures, 4 = Globalized music)
%   group_id      - number representing cultural group (e.g., '1')
%   partition_id  - string or number representing partition (partitions are
%   random)
%
% Outputs:
%   sequence      - vector of stimulus IDs
%   types_order   - cell array of stimulus type strings
%   seq_idx       - index of the chosen JSON file
%   stim_folder   - full path to the stimuli folder for the selected block

    basePath = '~/static2025/Stimuli/RecognitionMemory';

    % 1) Map block to experiment folder name
    switch block
        case 1, expName = 'nhs-region-n_80';
        case 2, expName = 'mem_exp_ind-nature_2025';
        case 3, expName = 'mem_exp_atexts_2025';
        case 4, expName = 'global-music-2025-n_80'; 
        otherwise, error('Invalid block ID: %d', block);
    end

    stim_folder = fullfile(basePath, expName);
    seqDir   = fullfile(stim_folder, 'sequences/isi_16/len120_bolivia');
    groupDir = fullfile(seqDir, sprintf('group-%d', group_id));
    partitionDir = fullfile(groupDir, sprintf('partition-%d', partition_id));

    if ~isfolder(groupDir)
        fprintf('Group directory not found. Creating: %s\n', groupDir);
        initializeGroupPartitions(groupDir, seqDir);
    end
    
    % 2) Locate JSONs
    jsonFiles = dir(fullfile(partitionDir, 'seq*_len120_s*_isi*json'));
    if isempty(jsonFiles)
        error('No sequence JSON files found in %s', partitionDir);
    end
    numSeq = numel(jsonFiles);

    % 3) Load usage log
    logDir = fullfile(stim_folder, 'used_logs');
    if ~exist(logDir, 'dir'), mkdir(logDir); end
    logFile = fullfile(logDir, sprintf('used_seq_group%s_part%s.mat', string(group_id), string(partition_id)));

    used_idx = [];
    if isfile(logFile)
        data = load(logFile);
        if isfield(data, 'used_idx'), used_idx = data.used_idx; end
    end

    available_idx = setdiff(1:numSeq, used_idx);
    if isempty(available_idx)
        fprintf('All sequences used for group %s partition %s.\n', string(group_id), string(partition_id));
        choice = input('Enter a new partition ID to continue (or 0 to exit): ', 's');
        choice_num = str2double(choice);
        if isnan(choice_num)
            error('Invalid input: must be a number or 0.');
        elseif choice_num == 0
            error('No sequences left and user opted to exit.');
        else
            [sequence, types_order, seq_idx, stim_folder] = getUniqueSequencePartition(block, group_id, choice_num);
            return;
        end
    end

    % 4) Randomly select unused sequence
    pick = available_idx(randi(numel(available_idx)));
    jsonPath = fullfile(seqDir, jsonFiles(pick).name);

    fid = fopen(jsonPath, 'r');
    if fid == -1, error('Could not open JSON: %s', jsonPath); end
    raw = fread(fid, inf);
    str = char(raw');
    fclose(fid);

    seqData = jsondecode(str);
    sequence = seqData.order;
    types_order = seqData.types_order;
    seq_idx = pick;

    % 5) Save updated log
    used_idx(end+1) = pick;
    save(logFile, 'used_idx');
end