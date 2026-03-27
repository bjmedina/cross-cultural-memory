function [sequence, types_order, seq_idx, stim_folder] = getUniqueSequenceISI(block, group_id, computer_id, isi_val)
% getUniqueSequence  Select a non-repeating sequence from a computer-specific slice
%
% Inputs:
%   block        - experiment block ID
%   group_id     - numeric group ID
%   computer_id  - which computer (1?6) determines which 104 files to use
%   isi_val      - ISI value (optional, default = 16)
% 
% Outputs:
%   sequence     - stimulus ID vector
%   types_order  - cell array of stimulus type labels
%   seq_idx      - index into this computer's slice (1?104)
%   stim_folder  - base path for this stimulus set (for saving logs, etc.)

    if nargin < 4
        isi_val = 16;  % default to ISI=16 for backward compatibility
    end

    basePath = '~/static2025/Stimuli/RecognitionMemory';

    % Map block to experiment folder name
    switch block
        case 1, expRelPath = 'nhs-region-n_80';
        case 2, expRelPath = 'mem_exp_ind-nature_2025';
        case 3, expRelPath = 'mem_exp_atexts_2025';
        case 4, expRelPath = 'global-music-2025-n_80';
        otherwise, error('Invalid block ID: %d', block);
    end

    expName = sprintf('%s/sequences/isi_%d/len120_bolivia', expRelPath, isi_val);
    sourceDir = fullfile(basePath, expName);
    stim_folder = sourceDir;

    % ISI-specific group folder
    groupDir = fullfile(sourceDir, sprintf('isi%d_group-%d', isi_val, group_id));

    % Load all available JSONs
    jsonFiles = dir(fullfile(sourceDir, 'seq*_len120_s*_isi*.json'));
    if isempty(jsonFiles)
        error('No JSON files found in %s\n', sourceDir);
    end
    jsonFiles = sortStructByName(jsonFiles);

    % Partition logic: assign 104 sequences per computer
    filesPerComputer = 104;
    startIdx = (computer_id - 1) * filesPerComputer + 1;
    endIdx = min(computer_id * filesPerComputer, numel(jsonFiles));
    if startIdx > numel(jsonFiles)
        error('Computer %d has no assigned sequences. Check total file count.', computer_id);
    end
    slice = jsonFiles(startIdx:endIdx);

    % Populate groupDir if needed
    if ~isfolder(groupDir)
        fprintf('? Creating and populating: %s\n', groupDir);
        mkdir(groupDir);
        for i = 1:numel(slice)
            src = fullfile(sourceDir, slice(i).name);
            dst = fullfile(groupDir, slice(i).name);
            copyfile(src, dst);
        end
        fprintf('? Group-%d initialized with %d files for computer %d (ISI=%d)\n', group_id, numel(slice), computer_id, isi_val);
    end

    % Load JSONs from groupDir
    jsonFiles = dir(fullfile(groupDir, 'seq*_len120_s*_isi*.json'));
    numSeq = numel(jsonFiles);

    % ISI-specific log folder
    logDir = fullfile(stim_folder, 'used_logs', sprintf('isi_%d', isi_val));
    if ~exist(logDir, 'dir'), mkdir(logDir); end
    logFile = fullfile(logDir, sprintf('used_seq_group%02d_comp%02d.mat', group_id, computer_id));

    used_idx = [];
    if isfile(logFile)
        data = load(logFile);
        if isfield(data, 'used_idx'), used_idx = data.used_idx; end
    end

    available_idx = setdiff(1:numSeq, used_idx);
    if isempty(available_idx)
        error('All sequences used for group %d on computer %d at ISI=%d.', group_id, computer_id, isi_val);
    end

    % Choose the next available sequence
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