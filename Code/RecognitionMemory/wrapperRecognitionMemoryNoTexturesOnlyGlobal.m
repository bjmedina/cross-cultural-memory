function wrapperRecognitionMemoryNoTexturesOnlyGlobal
    % Bryan Medina (17-07-2024)
    
    rng('shuffle')
    addpath(genpath('~/Tsimane2025/Support/'))
    addpath(genpath('~/Tsimane2025/Data/Fusion/'))
    addpath(genpath('~/Tsimane2025/Code/Fusion/'))

    addpath(genpath('~/Tsimane2025/Stimuli/'))
    LAST_DIRECTORY= '~/Tsimane2025/Data/Last/';  % directory for saving shared state (participant and station)


    LAST_FNAME=sprintf('%s/%s',LAST_DIRECTORY,'last-participant.mat'); % for a PC you might need to change the "/" direction
    [subject_name,~]=get_subject_name_last(LAST_FNAME);

    E_name = input('Enter the name of the EXPERIMENTER (TitleCase, WITHOUT SPACES): ','s');
    T_name = input('Enter the name of the TRANSLATOR (First Name, TitleCase, WITHOUT SPACES): ','s');

    %subject_name = [s_code '_' s_name '_' s_town ];
    %h_num = input('Enter the number of the computer you are using (must be 1, 2, 3, or 4): ','s');

    STATION_FNAME=sprintf('%s/%s',LAST_DIRECTORY,'last-station.mat'); % for a PC you might need to change the "/" direction
    STATION=get_station_code(STATION_FNAME);
    
    % Q is for "-Q-uestioning whether you heard this before"
    POLAROID_CODE = "Q";
    % commenting for historical reasons
%     switch condition
%         case "Textures"
%             POLAROID_CODE = "T";
%         case "NaturalSounds"
%             POLAROID_CODE = "Q";
%         case "Music"
%             POLAROID_CODE = "R";
%     end
    

    % IF YOU WANT TO ADD MORE EXPERIMENTS, ADD THE NAME TO THIS CELL ARRAY
    % AND FOLDER NAME TO "getUniqueSequence.m" (IN SWITCH CASE COMMAND)
    % AND TO THE "runAllAnalysis.m" SCRIPT
    experiment_strings = {"Globalized-Music"};

    order_dir = '~/Tsimane2025/Data/RecognitionMemory/ExperimentOrders/';
    
    %% MAIN EXPERIMENTS

    %check for existing experiment files
    fid=fopen([order_dir subject_name '.ord'],'r+t');
    if fid~=-1   %if files exist, load them
        disp("\nExperiment order file found\n");
        fclose(fid);
        current_block = load([order_dir subject_name '.cur']);
        block_order   = load([order_dir subject_name '.ord']);
        curr_block_idx = 1;
        
        for b=1:length(block_order)
            if block_order(b) == current_block
                break
            else
                curr_block_idx = curr_block_idx + 1;
            end
        end
        expmt_order = [1]; % '3' is associated with textures, so just omit that
    else  %otherwise generate experiment parameters and initialize files

        %expmt_order = [1,2,3];
        disp("\nExperiment order not file found. Creating one now.\n");

        expmt_order = [1]; % '3' is associated with textures, so just omit that
        
        curr_block_idx = 1;
        
        %Block structure within each experimental condition should be
        %random
        block_order = randperm(length(expmt_order));

        %save order to .ord file
        save([order_dir subject_name '.ord'],'block_order','-ASCII');

        %initialize .nam file
        fid = fopen([order_dir subject_name '.nam'],'wt');
        fprintf(fid,'Experiment Order for %s:\n',subject_name);
        fprintf(fid,'Experimenter: %s\n',E_name);
        fprintf(fid,'Translator: %s\n',T_name);
        fclose(fid);
        
        %% DEMO EXPERIMENTS. SHOW GIVE THEM FEEDBACK
        runDemoExperiments(STATION);
    end
    
    % tell the user (not necessarily the participant) what is going to happen
    fprintf('\n\nMemory Experiments Order for %s:\n', subject_name);
    for k=1:length(block_order)
        fprintf('%d. %s\n',k,string(experiment_strings(block_order(k))));
    end

    input('\nGive Experiment Instructions.\n');

    input('\nFamiliarize participant with headphones (Demonstrate how to put on, say they will do no harm).\n');

    fid = fopen([order_dir subject_name '.nam'],'at');
    fprintf(fid,'Experiment began at %22s %2d',datestr(clock,0));
    fprintf(fid,'\n');
    fclose(fid);
    
    
    % prompt user for computer and group information (for sequence
    % generation later)
    [group_id, group_name] = promptGroup();
    computer_id = getComputerID();  

    % cycling through all the blocks
    for block_number = curr_block_idx:length(block_order)
        % tell the user (not necessarily the participant) what is going to happen
        fprintf('\n\nMemory Experiments Order for %s:\n', subject_name);
        for k=block_number:length(block_order)
            fprintf('%d. %s\n',k,string(experiment_strings(block_order(k))));
        end

        % grab the current block (due to randomization)
        current_block = expmt_order(block_order(block_number)); 
        fprintf("%d", current_block);
        current_experiment = string(experiment_strings(block_order(block_number)));
                
        % sequence and stimuli selection
        [seq_for_exp, stimuli_type, dice_roll, stim_folder] = getUniqueSequence(current_block, group_id, computer_id);
        
        % save it as the current block
        save([order_dir subject_name '.cur'],'current_block','-ASCII');

        % print out the block
        fprintf('\nCurrent experiment: %s\n\n', current_experiment);

        % press enter to continue to that experiment
        input('Press Enter once instructions have been given.\n');

        % save time
        expmt_n = expmt_order(block_number);
        tstart = tic;
        
        fprintf("==========");
        fprintf('\nCurrent block: %d \ngroup id: %d\ncomputer id: %d\nsequence ID: %d\n', current_block, group_id, computer_id, dice_roll);
        fprintf("==========\n\n");

        recognitionMemoryMain_v3(subject_name, STATION, seq_for_exp, current_experiment, current_block, stimuli_type, dice_roll, stim_folder, group_id, computer_id);
      
        % save time
        expmt_dur = toc(tstart)/60;
        fid = fopen([order_dir subject_name '.nam'],'at');
        %fprintf(fid,'%d. %s - duration = %2.2f min - finished at %22s %2d',k,experiment_strings{k},expmt_dur,datestr(clock,0));
        fprintf(fid,'\n');
        
        %% prompt to add some comments after the block is up.
        was_there_noise = input('Was there noise (children, rain, animals?) during the experiment that was just completed? (1 = yes, 0 = no)  ');
        if isempty(was_there_noise)
            was_there_noise=2;
        end
        
        while ~(was_there_noise==1 || was_there_noise==0)
            fprintf('Answer must be 0 or 1!\n');
            was_there_noise = input('Was there noise (children, rain, animals?) during the experiment that was just completed? (1 = yes, 0 = no)  ');
            if isempty(was_there_noise)
                was_there_noise=2;
            end
        end
        if was_there_noise==1
            fprintf(fid,'NOISE\n');
        end
        fclose(fid);

        %% save 
        fid = fopen([order_dir subject_name '.nam'],'at');
        done_w_comments = 0;
        while ~done_w_comments
            overall_comments_text = input('Overall comments about this subject or session? Describe noise if present. \nWas the participant tired/drowsy? \nWere they not following instructions? \n(enter 0 to finish):\n  ','s');
            if overall_comments_text=='0'
                done_w_comments=1;
            else
                fprintf(fid,'%s',overall_comments_text);
                fprintf(fid,'\n');
            end
        end
        fclose(fid);
     end
    %% END
    input(sprintf('\nExperiment Code for Polaroid: %s', POLAROID_CODE))
    fprintf('\n\nEnd of Session!\n\n');
    
end

