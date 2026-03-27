function wrapperRecognitionMemoryNoTextures_GMISI8
% wrapperRecognitionMemoryNoTextures_GMISI8 ->
% Runs memory experiment, excluding textures
% Globalized Music (block 4) uses ISI = 8; all others use ISI = 16
% Bryan Medina (07-28-2025)

    rng('shuffle')

    addpath(genpath('~/Tsimane2025/Support/'))
    addpath(genpath('~/Tsimane2025/Data/Fusion/'))
    addpath(genpath('~/Tsimane2025/Code/Fusion/'))
    addpath(genpath('~/Tsimane2025/Stimuli/'))

    LAST_DIRECTORY = '~/Tsimane2025/Data/Last/';
    LAST_FNAME = fullfile(LAST_DIRECTORY, 'last-participant.mat');
    [subject_name, ~] = get_subject_name_last(LAST_FNAME);

    E_name = input('Enter the name of the EXPERIMENTER (TitleCase, WITHOUT SPACES): ', 's');
    T_name = input('Enter the name of the TRANSLATOR (First Name, TitleCase, WITHOUT SPACES): ', 's');

    STATION_FNAME = fullfile(LAST_DIRECTORY, 'last-station.mat');
    STATION = get_station_code(STATION_FNAME);

    POLAROID_CODE = "Q";

    experiment_strings = {"NHS", "Industrial-Nature", "Globalized-Music"};
    order_dir = '~/Tsimane2025/Data/RecognitionMemory/ExperimentOrders/';
    
    %% Check for existing participant experiment order
    ord_path = fullfile(order_dir, subject_name + ".ord");
    cur_path = fullfile(order_dir, subject_name + ".cur");

    fid = fopen(ord_path, 'r+t');
    if fid ~= -1
        disp("\nExperiment order file found\n");
        fclose(fid);
        current_block = load(cur_path);
        block_order   = load(ord_path);
        curr_block_idx = find(block_order == current_block, 1);
        expmt_order = [1, 2, 4]; % textures excluded
    else
        disp("\nExperiment order file not found. Creating one now.\n");
        expmt_order = [1, 2, 4];
        block_order = randperm(length(expmt_order));
        curr_block_idx = 1;

        save(ord_path, 'block_order', '-ASCII');
        fid = fopen(fullfile(order_dir, subject_name + ".nam"), 'wt');
        fprintf(fid, 'Experiment Order for %s:\n', subject_name);
        fprintf(fid, 'Experimenter: %s\n', E_name);
        fprintf(fid, 'Translator: %s\n', T_name);
        fclose(fid);

        runDemoExperiments(STATION);
    end

    fprintf('\n\nMemory Experiments Order for %s:\n', subject_name);
    for k = 1:length(block_order)
        fprintf('%d. %s\n', k, string(experiment_strings(block_order(k))));
    end

    input('\nGive Experiment Instructions.\n');
    input('\nFamiliarize participant with headphones.\n');

    fid = fopen(fullfile(order_dir, subject_name + ".nam"), 'at');
    fprintf(fid, 'Experiment began at %s\n', datestr(clock, 0));
    fclose(fid);

    [group_id, group_name] = promptGroup();
    computer_id = getComputerID();  

    for block_number = curr_block_idx:length(block_order)
        fprintf('\n\nMemory Experiments Order for %s:\n', subject_name);
        for k = block_number:length(block_order)
            fprintf('%d. %s\n', k, string(experiment_strings(block_order(k))));
        end

        current_block = block_order(block_number); 
        current_experiment = string(experiment_strings(current_block));

        % Set ISI based on experiment type
        if current_block == 4
            isi_val = 8;  % Globalized Music
        else
            isi_val = 16; % All other experiments
        end

        % Load a unique stimulus sequence
        [seq_for_exp, stimuli_type, dice_roll, stim_folder] = ...
            getUniqueSequenceISI(current_block, group_id, computer_id, isi_val);

        save(cur_path, 'current_block', '-ASCII');

        fprintf('\nCurrent experiment: %s\n\n', current_experiment);
        input('Press Enter once instructions have been given.\n');

        tstart = tic;

        fprintf("==========");
        fprintf('\nCurrent block: %d \ngroup id: %d\ncomputer id: %d\nsequence ID: %d\nISI: %d\n', ...
                current_block, group_id, computer_id, dice_roll, isi_val);
        fprintf("==========\n\n");

        recognitionMemoryMain_v3(subject_name, STATION, seq_for_exp, current_experiment, ...
                                  current_block, stimuli_type, dice_roll, stim_folder, ...
                                  group_id, computer_id);

        expmt_dur = toc(tstart)/60;
        fid = fopen(fullfile(order_dir, subject_name + ".nam"), 'at');
        fprintf(fid, '\n');

        % Noise log
        was_there_noise = input('Was there noise (children, rain, animals?) during the experiment? (1 = yes, 0 = no): ');
        if isempty(was_there_noise), was_there_noise = 2; end
        while ~(was_there_noise == 1 || was_there_noise == 0)
            fprintf('Answer must be 0 or 1!\n');
            was_there_noise = input('Was there noise (children, rain, animals?) during the experiment? (1 = yes, 0 = no): ');
            if isempty(was_there_noise), was_there_noise = 2; end
        end
        if was_there_noise == 1, fprintf(fid, 'NOISE\n'); end
        fclose(fid);

        % Optional: return sequence if something went wrong
        % returnSequenceToPoolISI(current_block, group_id, computer_id, dice_roll, isi_val);

        % Session comments
        fid = fopen(fullfile(order_dir, subject_name + ".nam"), 'at');
        done_w_comments = false;
        while ~done_w_comments
            overall_comments_text = input('Overall comments about this subject or session? (Enter 0 to finish):\n  ', 's');
            if strcmp(overall_comments_text, '0')
                done_w_comments = true;
            else
                fprintf(fid, '%s\n', overall_comments_text);
            end
        end
        fclose(fid);
    end

    input(sprintf('\nExperiment Code for Polaroid: %s', POLAROID_CODE));
    fprintf('\n\nEnd of Session!\n\n');
end