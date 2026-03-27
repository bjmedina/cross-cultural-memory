function returnSequenceToPoolISI(block, group_id, computer_id, seq_idx, isi_val)
% returnSequenceToPool  Re-adds a previously used sequence to the available pool
%
% Inputs:
%   block        - experiment block ID
%   group_id     - numeric group ID
%   computer_id  - computer ID (1?6)
%   seq_idx      - index of the sequence to return
%   isi_val      - (optional) ISI value (default = 16)
%
% Logs are stored in:
%   ~/static2025/Stimuli/RecognitionMemory/<exp_name>/sequences/isi_<isi_val>/len120_bolivia/used_logs/isi_<isi_val>

    if nargin < 5
        isi_val = 16;  % Default for backward compatibility
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

    % Build path to ISI-specific log file
    expPath = fullfile(basePath, expRelPath, 'sequences', ...
                       sprintf('isi_%d', isi_val), 'len120_bolivia');
    logDir = fullfile(expPath, 'used_logs', sprintf('isi_%d', isi_val));
    logFile = fullfile(logDir, sprintf('used_seq_group%02d_comp%02d.mat', group_id, computer_id));

    % Load log and remove sequence index
    if exist(logFile, 'file')
        data = load(logFile);
        if isfield(data, 'used_idx')
            used_idx = data.used_idx;
            if any(used_idx == seq_idx)
                used_idx(used_idx == seq_idx) = [];  % remove it
                save(logFile, 'used_idx');
                fprintf('? Sequence %d returned to pool for group %d, computer %d (ISI = %d).\n', ...
                        seq_idx, group_id, computer_id, isi_val);
            else
                warning('Sequence %d not found in used_idx ? nothing to return.', seq_idx);
            end
        else
            warning('No used_idx found in log file: %s', logFile);
        end
    else
        warning('Log file does not exist: %s', logFile);
    end
end