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

function demoExperiment_v1(sequence, demo_experiment_number, STATION)
    % Store the current warning state
    originalWarningState = warning('query', 'all');

    % Turn off all warnings
    warning('off', 'all');

    % sequence: A list of indices that define the order of stimuli to be presented
    numTrials = length(sequence);
    
    % always use natural sounds for demos
    condition = "demo";
    
    sr = 48000;
    nchannels = 2;
    pahandle = PsychPortAudio('Open', [], [], 0, sr, nchannels);
    
    % Initialize variables to store data
    participantResponses = nan(numTrials, 1);
    stimulusPresented = cell(numTrials, 1);
    responseTime = nan(numTrials, 1);
    isResponseCorrect = nan(numTrials, 1);
    containsRepeat = false(numTrials, 1);
    repeatPosition = nan(numTrials, 1);
    
    % str for repeat or not
    repeat_strings = {"is not a repeat", "is a repeat"};
    
    % Run the experiment
    for trial = 1:numTrials
        % Get the stimulus index for this trial from the sequence
        stimulusIndex = sequence(trial);
        
        % Generate the filename for this stimulus using the stimulusIndex
        
        % TODO: change this to be different, better sounds
        stimulusFilename = sprintf('~/static2025/Stimuli/RecognitionMemory/%s/mem_stim_%d.wav', condition, stimulusIndex);
        
        % set desired level
        desired_level = 75;

        % Play the sound stimulus at the appropriate level
        [y, sr] = audioread(stimulusFilename);
        OutWav=set_level_wrapper(y,sr,desired_level,[STATION, '']); %sound input needs to be n*1 dim matrix

        PsychPortAudio('FillBuffer', pahandle, OutWav');
        t1 = PsychPortAudio('Start', pahandle, 1, 0, 1);
   
        % Present the stimulus and record the time
        stimulusStart = GetSecs(); % Assuming you have Psychtoolbox for timing
        
        expectedResponse = ismember(stimulusIndex, sequence(1:trial-1));

        % Wait for participant response via the command prompt
        fprintf('Trial %d of %d: Did you hear this sound before? ', trial, numTrials);
        fprintf('%s ', string(repeat_strings(expectedResponse+1))); 
        pause(2);
        participantResponses(trial) = checkResponse();
        % This checks to see if the response was valid
            
        responseTime(trial) = GetSecs() - stimulusStart;
        
        % Check if the response is correct
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
    
end
