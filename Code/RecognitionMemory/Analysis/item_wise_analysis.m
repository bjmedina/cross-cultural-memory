% item_wise_analysis(condition, PLACE_CODES, block)
%
% in progress
%
% July 31, 2023 -- Bryan Medina (bjmedina@mit.edu)
function [repeat_agreement nonrepeat_agreement] = item_wise_analysis(block, PLACE_CODES)
    PASSING_DPRIME = 1.5;
    experiment_strings = {"NaturalSoundsFirstFixed", "NaturalSoundsSecondFixed", "NaturalSoundsRandom", "Music"};

    
    if nargin == 1
        PLACE_CODES = {"MAR"};
    end
    
    file_suffix = strjoin("~/Tsimane2023/Data/RecognitionMemory/Results/*%s*block-%d*", "");
    
    all_placefiles = [];
    for code_i=1:length(PLACE_CODES)
        % get filenames for village
%         village_files = sprintf("*%s*", string(PLACE_CODES(code_i)));
%         all_filenames = dir([file_suffix village_files]);
%         disp(all_filenames);
        place_filenames = sprintf(file_suffix, string(PLACE_CODES(code_i)), block);        
    end

    place_response_files = dir(place_filenames);

    participantData     = load(place_response_files(1).name);
    containsRepeat      = participantData.containsRepeat;
    stimulusPresented   = participantData.stimulusPresented;   
    
    % need to make associations between stim filename and label
    % first load in metadata.csv
    metadata = readtable('metadata.csv');
    
    %then create a mapping between filenames and labels
    %filename_to_label_map = containers.Map(metadata.filename, metadata.labels);
    
    repeat_agreement = zeros(sum(containsRepeat), 1);
    nonrepeat_agreement = zeros(sum(~containsRepeat), 1);

    for i=1:length(place_response_files)
        nonrepeat_i = 1;
        repeat_i    = 1;
    
        participantData   = load(place_response_files(i).name);
        isResponseCorrect = participantData.isResponseCorrect;
        
        for j=1:length(containsRepeat)
            if containsRepeat(j)
                repeat_agreement(repeat_i) = repeat_agreement(repeat_i) + isResponseCorrect(j);
                repeat_i = repeat_i + 1;
            else
                nonrepeat_agreement(nonrepeat_i) = nonrepeat_agreement(nonrepeat_i) + isResponseCorrect(j);
                nonrepeat_i = nonrepeat_i + 1;
            end
        end
    end
    
    repeat_agreement = repeat_agreement / length(place_response_files);
    nonrepeat_agreement = nonrepeat_agreement / length(place_response_files);
    
    figure;
    plot(repeat_agreement);
    title(sprintf("%s:Repeat trial response consistency. Mean: %f", mean(repeat_agreement)));
    
    figure;
    plot(nonrepeat_agreement);
    title(sprintf("%s: Nonepeat trial response consistency. Mean: %f", mean(nonrepeat_agreement)));
    