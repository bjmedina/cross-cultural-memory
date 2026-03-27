function [containsRepeat, response_matrix] = split_half_reliability_by_participant(PLACE_CODES, PASSING_DPRIME)
    
experiment_strings = {"NaturalSoundsFirstFixed", "NaturalSoundsSecondFixed", "NaturalSoundsRandom", "Music"};
%experiment_strings = {"NaturalSoundsRandom", "MusicFirstFixed", "MusicSecondFixed", "MusicRandom"};

if nargin == 0
    PLACE_CODES = {"MAR"};
elseif nargin == 1
    PASSING_DPRIME = 2.0;
end

file_suffix = strjoin("~/Tsimane2023/Data/RecognitionMemory/Results/*%s*v1*block*", "");

all_placefiles = [];
for code_i=1:length(PLACE_CODES)
    % get filenames for village
%         village_files = sprintf("*%s*", string(PLACE_CODES(code_i)));
%         all_filenames = dir([file_suffix village_files]);
%         disp(all_filenames);
    place_filenames = sprintf(file_suffix, string(PLACE_CODES(code_i)));

    place_response_files = dir(place_filenames);
    all_placefiles = [all_placefiles; place_response_files];
end

participantData   = load(all_placefiles(1).name);
repeatPosition    = participantData.repeatPosition;
uniquePositions = unique(repeatPosition(~isnan(repeatPosition)));       
numPositions = length(uniquePositions);
isis = uniquePositions -1;

%dprimes = zeros(numPositions,1);


for block_number=2:3
    
    response_matrix = [];
    goodParticipants = 0;


    for i=1:length(all_placefiles)
        participantData   = load(all_placefiles(i).name);

        splitFName= split(all_placefiles(i).name, "_");
        fileID    = splitFName{1};

        if goodParticipantCheck(fileID, PLACE_CODES, PASSING_DPRIME) && contains(all_placefiles(i).name, sprintf("block-%d", block_number))
            containsRepeat    = participantData.containsRepeat;
            isResponseCorrect = participantData.isResponseCorrect;
            repeatPosition    = participantData.repeatPosition;
            participantResponses = participantData.participantResponses;
            
            response_matrix = [response_matrix participantResponses];
            goodParticipants = goodParticipants + 1;
        end
    end
    
    % grabbing responses on repeat and nonrepeat
    repeat_trials = response_matrix(containsRepeat,:);
    nonrepeat_trials = ~response_matrix(~containsRepeat,:);
    
    
    numSplits = 100; % Number of random splits
    
    repeat_corrs = [];
    non_repeat_corrs = [];

    for split_num = 1:numSplits
        % repeat trials
        numParts = size(repeat_trials,2);

        % Randomly shuffle the responses
        shuffledResponses = repeat_trials(:, randperm(numParts));

        % Split the shuffled responses into two halves
        half1 = shuffledResponses(:,1:numParts/2);
        half2 = shuffledResponses(:,numParts/2:end);

        hit_consistency1 = mean(half1, 2);
        hit_consistency2 = mean(half2, 2);

        % Calculate the reliability coefficient (e.g., Pearson correlation)
        repeat_corrs = [repeat_corrs corr(hit_consistency1, hit_consistency2)];
        
        % Randomly shuffle the responses
        shuffledResponses = nonrepeat_trials(:, randperm(numParts));

        % Split the shuffled responses into two halves
        half1 = shuffledResponses(:,1:numParts/2);
        half2 = shuffledResponses(:,numParts/2:end);

        fa_consistency1 = mean(half1, 2);
        fa_consistency2 = mean(half2, 2);
        
        non_repeat_corrs = [non_repeat_corrs corr(fa_consistency1, fa_consistency2)];
    end
    
    disp(sprintf("Block %d Repeat correlation: %f\n", block_number, mean(repeat_corrs)));
    disp(sprintf("Block %d Nonrepeat correlation: %f\n\n",block_number,  mean(non_repeat_corrs)));
    
end


% 
%     % Calculate the mean reliability across splits for each pair of files
%     meanReliability = mean(reliabilityMatrix, 3);
%     ts()