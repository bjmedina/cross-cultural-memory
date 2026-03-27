% demoExperiment1_v1()
%
% presents stimuli of sounds from a given condition in a particular order
% (as defined in 'sequence') and then asks the user to make a recognition
% judgement.
%
% Input(s)
% ========
% -`sequence` (array-like): a list of integers, from 1 to N, that defines
% the sequence of stimuli to play. For example, if sequence=[1,2,3,1], then
% stimulus 1 will be played first, then stimulus 2, then stimulus 3, then
% stimulus 1 (then the experiment will end). 
%
% -`condition` (str): a string that specifies what types of sounds to play.
% Possible options are: "Textures", "NaturalSounds", and "Music. 
%
% -`block` (int): indicates which block we're on (essentially, this number is related to how many
% breaks the participant has had. so the block number should be (number of
% breaks + 1).
%
% July 25, 2023 -- Bryan Medina (bjmedina@mit.edu)

function demoExperiment2_v1()

    % TODO: predefine very SIMPLE sequence

    % sequence: A list of indices that define the order of stimuli to be presented
    numTrials = length(sequence);
    
    % Initialize variables to store data
    participantResponses = nan(numTrials, 1);
    stimulusPresented = cell(numTrials, 1);
    responseTime = nan(numTrials, 1);
    isResponseCorrect = nan(numTrials, 1);
    containsRepeat = false(numTrials, 1);
    repeatPosition = nan(numTrials, 1);
    blockNumber    = zeros(numTrials, 1) + block;
    
    % Run the experiment
    for trial = 1:numTrials
        % Get the stimulus index for this trial from the sequence
        stimulusIndex = sequence(trial);
        
        % Generate the filename for this stimulus using the stimulusIndex
        %stimulusFilename = sprintf('/Users/nori/Tsimane2023_Temp/Data/RecognitionMemory/%s/mem_exp_stim_%d.wav', condition, stimulusIndex);
        stimulusFilename = sprintf('/Users/nori/static2023/Data/RecognitionMemory/%s/mem_exp_stim_%d.wav', condition, stimulusIndex);

        % Play the sound stimulus (code to play the sound goes here)
        % For example, you can use the `audioplayer` function:
        [y, Fs] = audioread(stimulusFilename);
        player = audioplayer(y, Fs);
        play(player);
        
        % Present the stimulus and record the time
        stimulusStart = GetSecs(); % Assuming you have Psychtoolbox for timing
        % Code to present the stimulus to the participant goes here
        
        % Wait for participant response via the command prompt
        fprintf('Trial %d of %d: Did you hear this sound before? (Enter 0 for "No" or 1 for "Yes"): ', trial, numTrials);
        participantResponses(trial) = input('');
        responseTime(trial) = GetSecs() - stimulusStart;
        
        % Check if the response is correct
        expectedResponse = ismember(stimulusIndex, sequence(1:trial-1));
        isResponseCorrect(trial) = (participantResponses(trial) == expectedResponse);
        
        % Save the stimulus presented for this trial
        stimulusPresented{trial} = stimulusFilename;
        
        % Check if this trial contains a repeat stimulus and record the position of the repeat
        if trial > 1
            repeatIdx = find(sequence(1:trial-1) == stimulusIndex, 1, 'last');
            containsRepeat(trial) = ~isempty(repeatIdx);
            if containsRepeat(trial)
                repeatPosition(trial) = trial - repeatIdx;
            end
        end
    end
    
    % Save data to a file
    saveDestination = sprintf('/Users/nori/Tsimane2023_Temp/Data/RecognitionMemory/%s/Results/experiment_data.mat', condition);
    save(saveDestination, 'blockNumber', 'stimulusPresented', 'participantResponses', 'responseTime', 'isResponseCorrect', 'containsRepeat', 'repeatPosition');
    
    % Display some summary statistics
    meanReactionTime = mean(responseTime);
    disp(['Mean Reaction Time: ' num2str(meanReactionTime) ' seconds']);
    
    % Calculate hit rate and false alarm rate for the overall experiment
    overallHitRate = sum(isResponseCorrect & containsRepeat) / sum(containsRepeat);
    overallFalseAlarmRate = sum(~isResponseCorrect & ~containsRepeat) / sum(~containsRepeat);

    % Small ass number
    epsilon = 0.0001;
    
    % We don't want nans or infs (which happens if the hit rate is 1 or 0).
    % So let's cap the hit rate to be 0.99 if too high and 0 if too low.
    if overallHitRate >= 1-epsilon
        overallHitRate = 1-epsilon;
    elseif overallHitRate <= epsilon
        overallHitRate = epsilon;
    end 
    
    
    % Let's do a similar thing to the false alarm rates
    if overallFalseAlarmRate >= 1-epsilon
        overallFalseAlarmRate = 1-epsilon;
    elseif overallFalseAlarmRate <= epsilon
        overallFalseAlarmRate = epsilon;
    end
    
    % Calculate hit rate and false alarm rate for each unique position of the repeat
    uniquePositions = unique(repeatPosition(~isnan(repeatPosition)));
    numPositions = length(uniquePositions);
    hitRateByPosition = zeros(numPositions, 1);
    falseAlarmRateByPosition = zeros(numPositions, 1);
    
    for i = 1:numPositions
        position = uniquePositions(i);
        hitRateByPosition(i) = sum(isResponseCorrect(repeatPosition == position)) / sum(repeatPosition == position);
        falseAlarmRateByPosition(i) = overallFalseAlarmRate;
        
        % We don't want nans or infs (which happens if the hit rate is 1 or 0).
        % So let's cap the hit rate to be 0.99 if too high and 0 if too low.
        if hitRateByPosition(i) >= 1-epsilon
            hitRateByPosition(i) = 1-epsilon;
        elseif hitRateByPosition(i) <= epsilon
            hitRateByPosition(i) = epsilon;
        end 
        
        % Let's do a similar thing to the false alarm rates
        if falseAlarmRateByPosition(i) >= 1-epsilon
            falseAlarmRateByPosition(i) = 1-epsilon;
        elseif falseAlarmRateByPosition(i) <= epsilon
            falseAlarmRateByPosition(i) = epsilon;
        end
    
    end
    
    % Calculate z-scores for the overall experiment
    zHitOverall = norminv(overallHitRate);
    zFalseAlarmOverall = norminv(overallFalseAlarmRate);
    
    % Calculate z-scores for each unique position of the repeat
    zHitByPosition = norminv(hitRateByPosition);
    zFalseAlarmByPosition = norminv(falseAlarmRateByPosition);
    
    % Compute d' for the overall experiment and each unique position of the repeat
    dprimeOverall = zHitOverall - zFalseAlarmOverall;
    disp(['Mean d prime: ' num2str(dprimeOverall)]);

    dprimeByPosition = zHitByPosition - zFalseAlarmByPosition;
    
    % Plot d-prime as a function of the ISI
    figure;
    
    % The interstimulus interval (isi) is just 'uniquePositions' minus 1
    %
    isis = uniquePositions - 1;
    %plot(isis, dprimeByPosition, 'o-', 'LineWidth', 2);
    bar(isis, dprimeByPosition);
    xlabel('Position of Repeat');
    ylabel('d-prime');
    title('d-prime as a function of Interstimulus Interval');
    grid on;
    xlim([min(isis) - 1, max(isis) + 1]);
end
