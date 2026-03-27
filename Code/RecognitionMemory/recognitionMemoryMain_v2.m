% recognitionMemoryMain_v2(subject, STATION, sequence, condition, block, coin_flip)
%
% presents stimuli of sounds from a given condition in a particular order
% (as defined in 'sequence') and then asks the user to make a recognition
% judgement.
%
% Input(s)
% ========
% -`subject` (str): subject string
%
% -`STATION` (str): station color
%
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
% -`coin_flip` (int): if experiment requires a random order, then this will
% tell us which order it is (for saving purposes)
%
% July 25, 2023 -- Bryan Medina (bjmedina@mit.edu)

function [uniquePositions, dprimeByPosition] = recognitionMemoryMain_v2(subject, STATION, sequence, condition, block, coin_flip)
    % Store the current warning state
    originalWarningState = warning('query', 'all');

    % Turn off all warnings
    warning('off', 'all');
    rng('shuffle') % or add randomization hash to get same randomizations
    Screen('Preference', 'SkipSyncTests', 1);
    oldEnableFlag = Screen('Preference', 'SuppressAllWarnings');
    InitializePsychSound;
    warning('off','all');
    
    % Turn off Psychtoolbox informational messages (PTB-INFO)
    warning('off', 'Psychtoolbox:PsychSound:InitializeFailed');
    warning('off', 'Psychtoolbox:AudioDeviceStopError');
    
    sr = 48000;
    nchannels = 2;
    pahandle = PsychPortAudio('Open', [], [], 0, sr, nchannels);

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
    
    switch true
        case contains(condition, "Music")
            stim_type = "Music";
        case contains(condition, "Textures")
            stim_type = "Textures";
        otherwise
            stim_type = "NaturalSounds";
    end
    
    feedback = {"Response on last trial is incorrect", "response on last trial is correct"};
    
    % Run the experiment
    for trial = 1:numTrials
        % Get the stimulus index for this trial from the sequence
        stimulusIndex = sequence(trial);
        
        % Generate the filename for this stimulus using the stimulusIndex
        stimulusFilename = sprintf('~/static2024/Stimuli/RecognitionMemory/%s/mem_exp_stim_%d.wav', stim_type, stimulusIndex);
        
        % set desired level
        desired_level = 75;

        % Play the sound stimulus at the appropriate level
        [y, sr] = audioread(stimulusFilename);
        OutWav=set_level_wrapper(y,sr,desired_level,[STATION, '']); %sound input needs to be n*1 dim matrix

        PsychPortAudio('FillBuffer', pahandle, OutWav');
        t1 = PsychPortAudio('Start', pahandle, 1, 0, 1);
   
        % Present the stimulus and record the time
        stimulusStart = GetSecs(); % Assuming you have Psychtoolbox for timing
        
        % Wait for participant response via the command prompt
        fprintf('Trial %d of %d: Did you hear this sound before? ', trial, numTrials);
        pause(2);
        %participantResponses(trial) = double(input(''));
        user_response = checkResponse();
        
        % TODO: check if 'user_response' is a repeat
        
        if ismember(user_response, {'r'})
            % Play the sound stimulus at the appropriate level
            [y, sr] = audioread(stimulusFilename);
            OutWav=set_level_wrapper(y,sr,desired_level,[STATION, '']); %sound input needs to be n*1 dim matrix

            PsychPortAudio('FillBuffer', pahandle, OutWav');
            t1 = PsychPortAudio('Start', pahandle, 1, 0, 1);

            % Present the stimulus and record the time
            stimulusStart = GetSecs(); % Assuming you have Psychtoolbox for timing

            % Wait for participant response via the command prompt
            fprintf('Trial %d of %d: Did you hear this sound before? ', trial, numTrials);
            pause(2);
            %participantResponses(trial) = double(input(''));
            user_response = checkResponse();
        end
        
        participantResponses(trial) = user_response;
        
        %participantResponses(trial) = checkResponse();
        responseTime(trial) = GetSecs() - stimulusStart;
        
        % Check if the response is correct
        expectedResponse = ismember(stimulusIndex, sequence(1:trial-1));

        isResponseCorrect(trial) = (participantResponses(trial) == expectedResponse);
        
        disp(string(feedback(isResponseCorrect(trial) + 1)));
        input('');
        
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
    
    expmt_suffix = ['_RecognitionMem_v2_' date];

    % Save data to a file
    % saves one file per participant PER block. (the wrapper script will
    % take care of combining all the blocks)
    saveDestination = ['~/Tsimane2023/Data/RecognitionMemory/Results/' subject expmt_suffix sprintf('_block-%d.mat', block)];
    save(saveDestination, 'blockNumber', 'stimulusPresented', 'participantResponses', 'responseTime', 'isResponseCorrect', 'containsRepeat', 'repeatPosition', 'coin_flip');
    
    % Display some summary statistics
    meanReactionTime = mean(responseTime);
    disp(['Mean Reaction Time: ' num2str(meanReactionTime) ' seconds']);
    
    % Calculate hit rate and false alarm rate for the overall experiment
    overallHitRate = sum(isResponseCorrect & containsRepeat) / sum(containsRepeat);
    overallFalseAlarmRate = sum(~isResponseCorrect & ~containsRepeat) / sum(~containsRepeat);

    % Small ass number
    epsilon = 0.01;
    
    % We don't want nans or infs in d' (which happens if the hit rate is 1 or 0).
    % So let's cap the hit rate to be 0.99 if too high and 0 if too low.
    overallHitRate = correctRate(overallHitRate, epsilon);
    
    % Let's do a similar thing to the false alarm rates
    overallFalseAlarmRate = correctRate(overallFalseAlarmRate, epsilon);
    
    % Calculate hit rate and false alarm rate for each unique position of the repeat
    uniquePositions = unique(repeatPosition(~isnan(repeatPosition)));
    numPositions = length(uniquePositions);
    hitRateByPosition = zeros(numPositions, 1);
    
    for i = 1:numPositions
        position = uniquePositions(i);
        hitRateByPosition(i) = sum(isResponseCorrect(repeatPosition == position)) / sum(repeatPosition == position);
        
        % We don't want nans or infs in d' (which happens if the hit rate is 1 or 0).
        % So let's cap the hit rate to be 0.99 if too high and 0 if too low.
        hitRateByPosition(i) = correctRate(hitRateByPosition(i), epsilon);
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
    disp(['Mean d prime: ' num2str(dprimeOverall)]);

    dprimeByPosition = zHitByPosition - zFalseAlarmByPosition;
    
    
    % QUICK SUMMARY PLOTS 
    
    % Plot d-prime as a function of the ISI
    figure;
    
    % The interstimulus interval (isi) is just 'uniquePositions' minus 1
    isis = uniquePositions - 1;
    %plot(isis, dprimeByPosition, 'o-', 'LineWidth', 2);
    bar(isis, dprimeByPosition);
    xlabel('Interstimulus Interval (ISI)');
    ylabel("d'");
    title(sprintf("d' vs Interstimulus Interval - %s", condition));
    grid on;
    xlim([min(isis) - 2, max(isis) + 2]);
    
    figure; 
    bar(isis, hitRateByPosition);
    xlabel('Interstimulus Interval (ISI)');
    ylabel("Hit Rate");
    title(sprintf("Hit rate vs Interstimulus Interval - %s", condition));
    grid on;
    
    figure;
    bar(0, overallHitRate);
    hold on;
    bar(1, overallFalseAlarmRate);
    legend({'hit rate','fa rate'});
    title(sprintf("Avg. Hit rate and FA rate - %s", condition));
    ylim([0, 1]);
    grid on;

end
