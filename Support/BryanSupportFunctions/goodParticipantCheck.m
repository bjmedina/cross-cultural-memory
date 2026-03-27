function [isGood] = goodParticipantCheck(ID, PLACE_CODES, PASSING_DPRIME)
    if nargin == 2
        PASSING_DPRIME = 3;
    end
    
    filesWithID = [];
    
    file_suffix = strjoin("~/Tsimane2024/Data/VisualRecognitionMemory/Results/*%s*block*", "");
    
    all_placefiles = [];
    for code_i=1:length(PLACE_CODES)
        % get filenames for village
        place_filenames = sprintf(file_suffix, string(PLACE_CODES(code_i)));
            place_response_files = dir(place_filenames);
        all_placefiles = [all_placefiles; place_response_files];
    end
    
    % loop through all filenames and take out the files that contain the ID
    for i=1:length(all_placefiles)
        splitFName = string(all_placefiles(i).name);
        if contains(splitFName, ID)
            filesWithID = [filesWithID; string(all_placefiles(i).name)];
        end
    end
    
    CATCHTRIALS_DPRIMES = [];
    for i=1:length(filesWithID)
        participantData   = load(string(filesWithID(i)));
        containsRepeat    = participantData.containsRepeat;
        isResponseCorrect = participantData.isResponseCorrect;
        repeatPosition    = participantData.repeatPosition;
        
        overallHitRate = sum(isResponseCorrect & containsRepeat) / sum(containsRepeat);
        overallFalseAlarmRate = sum(~isResponseCorrect & ~containsRepeat) / sum(~containsRepeat);
        
        % Small ass number
        epsilon = 0.01;
        
        % correcting the different rates (cant be arbitrarily close to 
        % 0 or 1)
        overallHitRate = correctRate(overallHitRate, epsilon);
        overallFalseAlarmRate = correctRate(overallFalseAlarmRate, epsilon);
        
        % figure out the set of ISIs used in the experiment
        uniquePositions = unique(repeatPosition(~isnan(repeatPosition)));
        numPositions = length(uniquePositions);
        hitRateByPosition = zeros(numPositions, 1);

        for j = 1:numPositions
            position = uniquePositions(j);
            hitRateByPosition(j) = sum(isResponseCorrect(repeatPosition == position)) / sum(repeatPosition == position);
            %falseAlarmRateByPosition(i) = sum(~isResponseCorrect(repeatPosition ~= position)) / overallFalseAlarmRate;

            % We don't want nans or infs in d' (which happens if the hit rate is 1 or 0).
            % So let's cap the hit rate to be 0.99 if too high and 0 if too low.
            hitRateByPosition(j) = correctRate(hitRateByPosition(j), epsilon);
        end
        
        % Calculate z-scores for the overall experiment
        zHitOverall = norminv(overallHitRate);
        zFalseAlarmOverall = norminv(overallFalseAlarmRate);

        % Calculate z-scores for each unique position of the repeat
        zHitByPosition = norminv(hitRateByPosition);
        %zFalseAlarmByPosition = norminv(falseAlarmRateByPosition);
        zFalseAlarmByPosition = norminv(zeros(numPositions,1) + overallFalseAlarmRate);

        % Compute d' for the overall experiment and each unique position of the repeat
        dprimeOverall = zHitOverall - zFalseAlarmOverall;
        

        dprimeByPosition = zHitByPosition - zFalseAlarmByPosition;
        
        CATCHTRIALS_DPRIMES = [CATCHTRIALS_DPRIMES dprimeByPosition(1)];
        
    end
    
    if mean(CATCHTRIALS_DPRIMES) > PASSING_DPRIME
        isGood = 1;
    else
        isGood = 0;
    end
    
    
    if length(CATCHTRIALS_DPRIMES) < 2
        isGood = 0;
    end
end