function returnSequenceToPool(block, group_id, computer_id, seq_idx)
    basePath = '~/static2025/Stimuli/RecognitionMemory';

    % Map block to experiment folder name
    switch block
        case 1, expName = 'nhs-region-n_80';
        case 2, expName = 'mem_exp_ind-nature_2025';
        case 3, expName = 'mem_exp_atexts_2025';
        case 4, expName = 'global-music-2025-n_80';
        otherwise, error('Invalid block ID: %d', block);
    end
    
    % group IDs
    % 
    % 
    % computer ids
    %  'grey', 'mahogany', 'cyan', 'red', 'orange', 'black'
    %   1           2         3        4     5          6 

    logFile = fullfile(basePath, expName, 'used_logs', ...
                       sprintf('used_seq_group%02d_comp%02d.mat', group_id, computer_id));

    if exist(logFile, 'file')
        data = load(logFile);
        if isfield(data, 'used_idx')
            used_idx = data.used_idx;
            used_idx(used_idx == seq_idx) = []; % remove the sequence
            save(logFile, 'used_idx');
            fprintf('? Sequence %d returned to pool.\n', seq_idx);
        else
            warning('No used_idx found in log file.');
        end
    else
        warning('Log file does not exist: %s', logFile);
    end
end