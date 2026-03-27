function [repeat_corrs, non_repeat_corrs] = split_half_reliability_by_stimulus(PLACE_CODES, PASSING_DPRIME)
    
    %experiment_strings = {"NaturalSoundsFirstFixed", "NaturalSoundsSecondFixed", "NaturalSoundsRandom", "Music"};
    experiment_strings = {"NaturalSoundsRandom", "MusicFirstFixed", "MusicSecondFixed", "MusicRandom"};

    if nargin == 0
        PLACE_CODES = {"MAR"};
    elseif nargin == 1
        PASSING_DPRIME = 2.0;
    end

    file_suffix = strjoin("~/Tsimane2023/Data/RecognitionMemory/Results/*%s*block*", "");

    all_placefiles = [];
    
    for code_i=1:length(PLACE_CODES)
        place_filenames = sprintf(file_suffix, string(PLACE_CODES(code_i)));

        place_response_files = dir(place_filenames);
        all_placefiles = [all_placefiles; place_response_files];
    end
    
    % some of these variables are common amongst all participants (ISIs,
    % etc). So just extract that now.
    participantData   = load(all_placefiles(1).name);
    repeatPosition    = participantData.repeatPosition;
    uniquePositions = unique(repeatPosition(~isnan(repeatPosition)));       
    numPositions = length(uniquePositions);
    isis = uniquePositions - 1;
    
    blocks = [1,4];
    
    for block_number=1:2
        
        response_matrix_1 = [];
        response_matrix_2 = [];
        goodParticipants = 0;
        
        % seperate out sequence responses
        for i=1:length(all_placefiles)
            participantData   = load(all_placefiles(i).name);

            splitFName= split(all_placefiles(i).name, "_");
            fileID    = splitFName{1};
            
            containsRepeat_1 = [];
            containsRepeat_2 = [];
            
            stimPresented_1 = [];
            stimPresented_2 = [];
            
            NRstimPresented_1 = [];
            NRstimPresented_2 = [];

            if goodParticipantCheck(fileID, PLACE_CODES, PASSING_DPRIME) && contains(all_placefiles(i).name, sprintf("block-%d", blocks(block_number)))
                containsRepeat       = participantData.containsRepeat;
                isResponseCorrect    = participantData.isResponseCorrect;
                repeatPosition       = participantData.repeatPosition;
                participantResponses = participantData.participantResponses;
                coin_flip_           = participantData.coin_flip;
                stimulusPresented    = participantData.stimulusPresented;

                if coin_flip_ == 1
                    response_matrix_1 = [response_matrix_1 participantResponses];
                    containsRepeat_1  = containsRepeat;
                    stimPresented_1   = stimulusPresented(containsRepeat_1);
                    NRstimPresented_1   = stimulusPresented(~containsRepeat_1);
                    goodParticipants = goodParticipants + 1;
                elseif coin_flip_ == 2
                    response_matrix_2 = [response_matrix_2 participantResponses];
                    goodParticipants = goodParticipants + 1;
                    containsRepeat_2  = containsRepeat;
                    stimPresented_2   = stimulusPresented(containsRepeat_2);
                    NRstimPresented_2 = stimulusPresented(~containsRepeat_2);

                end
            end
        end

        % grabbing responses on repeat and nonrepeat for the first sequence
        repeat_trials_1 = response_matrix_1(containsRepeat_1,:);
        nonrepeat_trials_1 = ~response_matrix_1(~containsRepeat_1,:);
        
        % grabbing responses on repeat and nonrepeat for the second sequence
        repeat_trials_2 = response_matrix_2(containsRepeat_2,:);
        nonrepeat_trials_2 = ~response_matrix_2(~containsRepeat_2,:);
            
        numSplits = 10000; % Number of random splits

        repeat_corrs = [];
        non_repeat_corrs = [];
        
        % figure out repeat stimuli
        repeat_stimuli_1 = stimPresented_1;
        repeat_stimuli_2 = stimPresented_2;
        
        % figure out nonrepeat stimuli
        nonrepeat_stimuli_1 = NRstimPresented_1;
        nonrepeat_stimuli_2 = NRstimPresented_2;
        
        for k=1:numSplits
            
            repeat_means_1 = [];
            repeat_means_2 = [];

            % do this for repeats
            for stim_idx=1:length(repeat_stimuli_1)
                target = repeat_stimuli_1{stim_idx};
                indexInArray1 = find(strcmp(repeat_stimuli_1, target), 1);
                indexInArray2 = find(strcmp(repeat_stimuli_2, target), 1);

                if ~isempty(indexInArray1) && ~isempty(indexInArray2)
                    r1 = repeat_trials_1(indexInArray1, :);
                    r2 = repeat_trials_2(indexInArray2, :);

                    combined_responses = [r1 r2];

                    numParts = length(combined_responses);

                    shuffledResponses = combined_responses(randperm(numParts));

                    % Split the shuffled responses into two halves
                    half1 = shuffledResponses(1:numParts/2);
                    half2 = shuffledResponses(numParts/2+1:end);

                    repeat_means_1 = [repeat_means_1 mean(half1)];
                    repeat_means_2 = [repeat_means_2 mean(half2)];
                    
                end
            end
            
            r_corr = corr(repeat_means_1', repeat_means_2');
            repeat_corrs = [repeat_corrs r_corr];
            
            nonrepeat_means_1 = [];
            nonrepeat_means_2 = [];
            
            % do this for repeats
            for stim_idx=1:length(nonrepeat_stimuli_1)
                target = nonrepeat_stimuli_1{stim_idx};
                indexInArray1 = find(strcmp(nonrepeat_stimuli_1, target), 1);
                indexInArray2 = find(strcmp(nonrepeat_stimuli_2, target), 1);

                if ~isempty(indexInArray1) && ~isempty(indexInArray2)
                    r1 = nonrepeat_trials_1(indexInArray1, :);
                    r2 = nonrepeat_trials_2(indexInArray2, :);

                    combined_responses = [r1 r2];

                    numParts = length(combined_responses);


                    shuffledResponses = combined_responses(randperm(numParts));

                    % Split the shuffled responses into two halves
                    half1 = shuffledResponses(1:numParts/2);
                    half2 = shuffledResponses(numParts/2+1:end);

                    nonrepeat_means_1 = [nonrepeat_means_1 mean(half1)];
                    nonrepeat_means_2 = [nonrepeat_means_2 mean(half2)];
                    
                end
            end
            
            nr_corr = corr(nonrepeat_means_1', nonrepeat_means_2');
            non_repeat_corrs = [non_repeat_corrs nr_corr];
        end
        
        disp(["block ", blocks(block_number), " hit consistency ", mean(repeat_corrs), " fa consistency ", mean(non_repeat_corrs)]);
    end
end

