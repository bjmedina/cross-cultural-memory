function wrapperRecognitionMemoryTexturesOnly
    % Bryan Medina (17-07-2024) - Simplified version for Textures experiment only

    rng('shuffle')
    addpath(genpath('~/Tsimane2025/Support/'))
    addpath(genpath('~/Tsimane2025/Data/Fusion/'))
    addpath(genpath('~/Tsimane2025/Code/Fusion/'))
    addpath(genpath('~/Tsimane2025/Stimuli/'))

    LAST_DIRECTORY = '~/Tsimane2025/Data/Last/';
    LAST_FNAME = fullfile(LAST_DIRECTORY, 'last-participant.mat');
    STATION_FNAME = fullfile(LAST_DIRECTORY, 'last-station.mat');

    [subject_name, ~] = get_subject_name_last(LAST_FNAME);
    STATION = get_station_code(STATION_FNAME);

    E_name = input('Enter the name of the EXPERIMENTER (TitleCase, WITHOUT SPACES): ', 's');
    T_name = input('Enter the name of the TRANSLATOR (First Name, TitleCase, WITHOUT SPACES): ', 's');

    order_dir = '~/Tsimane2025/Data/RecognitionMemory/ExperimentOrders/';
    nam_path = fullfile(order_dir, [subject_name '.nam']);

    % Save experiment info
    fid = fopen(nam_path, 'wt');
    fprintf(fid, 'Experimenter: %s\n', E_name);
    fprintf(fid, 'Translator: %s\n', T_name);
    fprintf(fid, 'Experiment began at %s\n', datestr(clock, 0));
    fclose(fid);
    
    % RUN DEMO EXPERIMENTS IF YOU WANT
    runDemoExperiments(STATION);

    input('\nGive Experiment Instructions.\n');
    input('\nFamiliarize participant with headphones.\n');

    [group_id, group_name] = promptGroup();
    computer_id = getComputerID();
    texture_block_id = 3;  % "Textures" corresponds to index 3
    [seq_for_exp, stimuli_type, dice_roll, stim_folder] = getUniqueSequence(texture_block_id, group_id, computer_id);

    fprintf('\nCurrent experiment: Textures\n');
    input('Press Enter once instructions have been given.\n');

    tstart = tic;
    recognitionMemoryMain_v3(subject_name, STATION, seq_for_exp, "Textures", texture_block_id, ...
                              stimuli_type, dice_roll, stim_folder, group_id, computer_id);
    expmt_dur = toc(tstart)/60;

    % Post-block comments
    fid = fopen(nam_path, 'at');
    was_there_noise = input('Was there noise (children, rain, animals?) (1 = yes, 0 = no): ');
    if isempty(was_there_noise)
        was_there_noise = 2;
    end
    while ~(was_there_noise == 1 || was_there_noise == 0)
        fprintf('Answer must be 0 or 1!\n');
        was_there_noise = input('Was there noise? (1 = yes, 0 = no): ');
    end
    if was_there_noise == 1
        fprintf(fid, 'NOISE\n');
    end
    fclose(fid);

    % Comments
    fid = fopen(nam_path, 'at');
    done = false;
    while ~done
        cmt = input('Comments? (Enter 0 to finish):\n', 's');
        if strcmp(cmt, '0')
            done = true;
        else
            fprintf(fid, '%s\n', cmt);
        end
    end
    fclose(fid);

    input(sprintf('\nExperiment Code for Polaroid: T'));
    fprintf('\n\nEnd of Session!\n\n');
end