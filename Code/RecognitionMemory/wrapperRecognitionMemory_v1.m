function wrapperRecognitionMemory_v1
    % give instructions on the experiment
    % run the first demo 
    % run the second demo
    % run the main experiment (a few times)
    % (main experiment should be ran in blocks. 
    % potentially there should be 8 blocks (128 stimuli each)
    % grand total of 1024 trials. 
    % each block of 128 should equally represent each ISI condition. 
    % TODO: have a function that spits out a predefined sequence. 
    % TODO: what do we SAVE? append to the matfile? can we turn matfiles
    % into CSVs?
    
    rng('shuffle')
    addpath(genpath('~/Tsimane2023/Support/'))
    addpath(genpath('~/Tsimane2023/Data/Fusion/'))
    addpath(genpath('~/Tsimane2023/Code/Fusion/'))

    addpath('~/Tsimane2023/Code/Demography/')
    addpath(genpath('~/Tsimane2023/Stimuli/'))
    LAST_DIRECTORY= '~/Tsimane2023/Data/Last/';  % directory for saving shared state (participant and station)


    LAST_FNAME=sprintf('%s/%s',LAST_DIRECTORY,'last-participant.mat'); % for a PC you might need to change the "/" direction
    [subject_name,~]=get_subject_name_last(LAST_FNAME);

    E_name = input('Enter the name of the EXPERIMENTER (TitleCase, WITHOUT SPACES): ','s');
    T_name = input('Enter the name of the TRANSLATOR (First Name, TitleCase, WITHOUT SPACES): ','s');

    %subject_name = [s_code '_' s_name '_' s_town ];
    %h_num = input('Enter the number of the computer you are using (must be 1, 2, 3, or 4): ','s');

    LAST_DIRECTORY= '~/Tsimane2023/Data/Last/';  % directory for saving shared state (participant and station)
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
     
    % Note - need to figure out easiest place to put the wrapper script for
    % people to be able to run it quickly. Right now it sits in
    % ~/Tsimane2023/Code/Fusion

    %s = pwd;
    %if ~strcmp(s,'/Users/jacoby/Documents/Bolivia_Experiments_2017/')
    %    cd ~/Documents/Bolivia_Experiments_2017/
    %end
    
    %experiment_strings = {"NaturalSounds", "Music", "Textures"};
    % just one condition for now
    
    % v1
    experiment_strings = {"NaturalSoundsFirstFixed", "NaturalSoundsSecondFixed", "NaturalSoundsRandom", "Music"};
    
    % v2
    %experiment_strings = {"NaturalSoundsRandom", "MusicFirstFixed", "MusicSecondFixed", "MusicRandom"};

    
    order_dir = '~/Tsimane2023/Data/RecognitionMemory/ExperimentOrders/';
    
    %% MAIN EXPERIMENTS

    %check for existing experiment files
    fid=fopen([order_dir subject_name '.ord'],'r+t');
    if fid~=-1   %if files exist, load them
        disp("\nExperiment order file found\n");
        fclose(fid);
        current_block = load([order_dir subject_name '.cur']);
        block_order = load([order_dir subject_name '.ord']);
        curr_block_idx = 1;
        
        for b=1:length(block_order)
            if block_order(b) == current_block
                break
            else
                curr_block_idx = curr_block_idx + 1;
            end
        end
        expmt_order = [1];
    else  %otherwise generate experiment parameters and initialize files

        %expmt_order = [1,2,3];
        disp("\nExperiment order not file found. Creating one now.\n");

        expmt_order = [1];
        
        curr_block_idx = 1;
        
        %Block structure within each experimental condition should be
        %random
        block_order = randperm(4);

        %save order to .ord file
        save([order_dir subject_name '.ord'],'block_order','-ASCII');

        %initialize .nam file
        fid = fopen([order_dir subject_name '.nam'],'wt');
        fprintf(fid,'Experiment Order for %s:\n',subject_name);
        fprintf(fid,'Experimenter: %s\n',E_name);
        fprintf(fid,'Translator: %s\n',T_name);
        fclose(fid);
        
        %% DEMO EXPERIMENTS. SHOW GIVE THEM FEEDBACK
        %have translators explain that not all repetitions will happen b2b
        fprintf("Explain the instructions. have translators explain that not all repetitions will happen b2b\n\n ")

        fprintf("\n we will now do some demo experiments \n")
        input('\n\nPress enter to continue to the first (back to back only):')
        % one back to back repetition %       
        demoExperiment_v1([414,417,417], 1, STATION)

        % slightly longer -- only back to back repetitions
        input('\n\nPress enter to continue to the second (longer -- back to back only):')
        demoExperiment_v1([439,439,440,442,442], 1, STATION)

        % longer experiments - one back to back, one non-b2b
        input('\n\nPress enter to continue to the third (longer -- one back to back, one non back to back):')
        demoExperiment_v1([451,465,473,451,481,482,482], 1, STATION)

        % longer harder version - make this harder
        input('\n\nPress enter to continue to the fourth (longer -- no back to back):')
        demoExperiment_v1([493,495,502,493,502,512,513,502,512,519,513], 1, STATION)

        demo_seq = [747   748   748   752   753   758   760   761   752   753   763   765   766   767   758   763   768 771   773   777   779   785   791   802   803   804   785   773   805   815   767   824   828   829  832   832   777   779   833   834   802   803   829   833   844   846   815   847   834   844];

        input('\n\nPress enter to continue to the last (longest -- mimics actual):')
        demoExperiment_v1(demo_seq, 1, STATION)

        input('\n\nNOTE: If you believe they did not do well on the above, DONT RUN on main experiment (by pressing ctrl-c)\nPRESS ENTER TO CONTINUE\n\n');
    end
    
    % tell the user what is going to happen
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

    % cycling through all the blocks
    for block_number = curr_block_idx:length(block_order)

        % grab the current block (due to randomization)
        current_block = block_order(block_number); 
        current_experiment = string(experiment_strings(current_block));
        
        % save it as the current block
        save([order_dir subject_name '.cur'],'current_block','-ASCII');

        % print out the block
        fprintf('\nCurrent experiment: %s\n\n', current_experiment);

        % press enter to continue to that experiment
        input('Press Enter once instructions have been given.\n');

        % save time
        expmt_n = expmt_order(1);
        tstart = tic;

        % run the main experimental logic
        [seq_for_exp, coin_flip] = getUniqueSequence(current_block);
        recognitionMemoryMain_v1(subject_name, STATION, seq_for_exp, current_experiment, current_block,coin_flip)
        fprintf('\n\n\n');        
    
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

