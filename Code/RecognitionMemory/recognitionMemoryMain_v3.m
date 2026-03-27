% recognitionMemoryMain_v3(subject, STATION, sequence, condition, block, stimuli_type, dice_roll, stim_folder, group_id, computer_id)
%
% Runs a recognition memory experiment block, playing a predefined sequence 
% of audio stimuli and collecting recognition responses.
%
% Inputs
% ======
% - subject (str): A unique string identifying the participant.
%
% - STATION (str): A label for the computer or station used (e.g., color name).
%
% - sequence (array-like): A list of integers defining the order of stimuli to play.
%   For example, if sequence = [1, 2, 3, 1], the stimuli will be presented in that order.
%
% - condition (str): Human-readable label for the condition.
%   Options: "NHS-Globalized", "Industrial-Nature", "Textures"
%
% - block (int): Indicates which block this is (usually: number of breaks + 1).
%
% - stimuli_type (str): Specifies the type of audio stimuli (e.g., redundant with 'condition';
%   used for file or data bookkeeping).
%
% - dice_roll (int or bool): Optional randomization parameter used internally for counterbalancing.
%
% - stim_folder (str): Full path to the folder containing the audio stimuli for this block and group.
%
% - group_id (int): Numeric ID identifying the cultural group being tested.
%
% - computer_id (int): Numeric ID (1?4) identifying which computer/station is running the experiment;
%   used to restrict each computer to a fixed partition of sequences.
%
% Outputs
% =======
% - uniquePositions (vector): The positions in the sequence where repeats occurred.
%
% - dprimeByPosition (vector): Computed d-prime values for recognition accuracy at each repeat position.
%
% -------------------------------------------------------------------------
% June 20, 2025 -- Bryan Medina (bjmedina@mit.edu)


function [uniquePositions, dprimeByPosition] = recognitionMemoryMain_v3(subject, STATION, sequence, condition, block, stimuli_type, dice_roll, stim_folder, group_id, computer_id)
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
    stimulusPresented    = cell(numTrials, 1);
    responseTime         = nan(numTrials, 1);
    isResponseCorrect    = nan(numTrials, 1);
    containsRepeat       = false(numTrials, 1);
    repeatPosition       = nan(numTrials, 1);
    blockNumber          = zeros(numTrials, 1) + block;
    
    stim_type = stim_folder;
    
    feedback = {"Response on last trial is incorrect", "Response on last trial is correct"};
    
    startTime = datetime('now');
    
    % Run the experiment
    for trial = 1:numTrials
        
        % Get the stimulus index for this trial from the sequence
        stimulusIndex = sequence(trial);
        
        % Generate the filename for this stimulus using the stimulusIndex
        stimulusFilename = sprintf('%s/mem_stim_%d.wav', stim_folder, stimulusIndex);
        
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
        
        participantResponses(trial) = user_response;
        
        %participantResponses(trial) = checkResponse();
        responseTime(trial) = GetSecs() - stimulusStart;
        
        % Check if the response is correct
        expectedResponse = ismember(stimulusIndex, sequence(1:trial-1));

        isResponseCorrect(trial) = (participantResponses(trial) == expectedResponse);
        
        disp(string(feedback(isResponseCorrect(trial) + 1)));
        
        try
            dummy_response = input('', 's');  % Always get a string... 'user_response' is never used
        catch
            dummy_response = '';
        end
        
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
    
    % Record the end time
    endTime = datetime('now');

    % Calculate the total duration
    duration = endTime - startTime;

    % Convert duration to seconds, minutes, hours, etc.
    totalSeconds = seconds(duration);
    totalMinutes = minutes(duration);
    
    expmt_suffix = ['_RecognitionMem_' date];

    % Save data to a file
    % saves one file per participant PER block. (the wrapper script will
    % take care of combining all the blocks)
    saveDestination = ['~/Tsimane2025/Data/RecognitionMemory/Results/' subject expmt_suffix sprintf('_%s.mat', condition)];
    save(saveDestination, 'blockNumber', 'stimulusPresented', 'participantResponses', 'responseTime', 'isResponseCorrect', 'containsRepeat', 'repeatPosition', 'stimuli_type', 'dice_roll',  'totalMinutes', 'totalSeconds', 'condition', 'subject', 'group_id', 'computer_id');
    
    % base directory for saving (only by subject now)
    saveBase = fullfile(getenv('HOME'), 'Tsimane2025', 'Data', 'RecognitionMemory', 'Results', 'figures', 'individual');
    saveDir  = fullfile(saveBase, subject, condition);
    if ~exist(saveDir, 'dir')
        mkdir(saveDir);
    end

    nTrials = numel(repeatPosition);
    
    epsilon = 0.01;

    %% 1) Overall hit & FA rates
    firstTrials           = isnan(repeatPosition);
    rawFA_overall         = sum(~isResponseCorrect(firstTrials)) / sum(firstTrials);
    overallFalseAlarmRate = correctRate(rawFA_overall, epsilon);
    repeatTrials          = ~firstTrials;
    rawHitOverall         = sum(isResponseCorrect(repeatTrials)) / sum(repeatTrials);
    overallHitRate        = correctRate(rawHitOverall, epsilon);

    %% 2) Hit rates by repeat-position
    uniquePositions   = unique(repeatPosition(repeatTrials));
    numPositions      = numel(uniquePositions);
    hitRateByPosition = zeros(numPositions,1);
    for i = 1:numPositions
        pos = uniquePositions(i);
        idx = (repeatPosition == pos);
        hr  = sum(isResponseCorrect(idx)) / sum(idx);
        hitRateByPosition(i) = correctRate(hr, epsilon);
    end

    %% 3) FA rates for will-repeat vs never-repeat
    % Build ?first?presentation? masks via stimulusPresented 
    % stimulusPresented is an N×1 cell-array of char or string array,
    % e.g. {'mem_stim_0','mem_stim_3','mem_stim_0',?}

    nTrials = numel(stimulusPresented);
    % make sure it?s a string array for easy comparison
    stimulusPresented = string(stimulusPresented);

    willRepeatFirst  = false(nTrials,1);
    neverRepeatFirst = false(nTrials,1);

    uniqueIDs = unique(stimulusPresented);
    for s = 1:numel(uniqueIDs)
        thisID = uniqueIDs(s);
        idx    = (stimulusPresented == thisID);     % logical mask of all presentations
        firstI = find(idx,1,'first');               % index of the first presentation
        if nnz(idx) > 1 % tracks the number of nonzero elements in X. 
            % for the length of the sequence, if this number is greater
            % than 1, then a sound repeated (it shows up in two places in
            % the sequence)
            willRepeatFirst(firstI) = true;         % this item repeats
        else
            neverRepeatFirst(firstI) = true;        % this item never repeats
        end
    end

    % OPTIONAL SANITY?CHECK: these should cover exactly your NaN?repeat trials
    firstTrials = isnan(repeatPosition);
    assert( all((willRepeatFirst|neverRepeatFirst) == firstTrials), ...
        'Mask mismatch: some first?presentation trials were lost.' )

    % ?? Compute FA rates for each subset ??
    rawFA_willRepeat   = sum(~isResponseCorrect(willRepeatFirst))  / sum(willRepeatFirst);
    faRate_willRepeat  = correctRate(rawFA_willRepeat, epsilon);

    rawFA_neverRepeat  = sum(~isResponseCorrect(neverRepeatFirst)) / sum(neverRepeatFirst);
    faRate_neverRepeat = correctRate(rawFA_neverRepeat, epsilon);

    % ?? Force the overall FA to be their weighted average ??
    Nw = sum(willRepeatFirst);
    Nn = sum(neverRepeatFirst);

    overallFalseAlarmRate = (faRate_willRepeat * Nw + faRate_neverRepeat * Nn) ...
                           / (Nw + Nn);
    overallFalseAlarmRate = correctRate(overallFalseAlarmRate, epsilon);
    
    %% 4) d' using will-repeat FA
    zHitOverall    = norminv(overallHitRate);
    zHitByPosition = norminv(hitRateByPosition);
    zFA_willRepeat = norminv(faRate_willRepeat);

    dprimeOverall    = zHitOverall - zFA_willRepeat;
    dprimeByPosition = zHitByPosition - repmat(zFA_willRepeat, numPositions,1);
    disp(['Mean d? (using will-repeat FA): ' num2str(dprimeOverall)]);

    %% 5) PLOTS + SAVE each one as PNG

    isis = uniquePositions - 1;

    % ---- d' vs ISI ----
    figure;
    bar(isis, dprimeByPosition);
    xlabel('Interstimulus Interval (ISI)');
    ylabel("Sensitivity (d')");
    title(sprintf('d'' vs ISI ? %s', condition));
    grid on;
    the_name = 'dprime_vs_ISI';
    saveas(gcf, fullfile(saveDir, sprintf('%s_%s.png', condition, the_name)));

    % ---- Hit rate vs ISI ----
    figure;
    bar(isis, hitRateByPosition);
    xlabel('Interstimulus Interval (ISI)');
    ylabel('Hit Rate');
    title(sprintf('Hit Rate vs ISI ? %s', condition));
    ylim([0,1])
    grid on;
    the_name = 'hit_rate_vs_ISI';
    saveas(gcf, fullfile(saveDir, sprintf('%s_%s.png', condition, the_name)));

    % ---- Overall hit vs FA (will-repeat) ----
    figure;
    bar([overallHitRate, faRate_willRepeat],'grouped');
    set(gca,'XTickLabel',{'Hit Rate','FA (will-repeat)'});
    title(sprintf('Overall Rates ? %s', condition));
    ylim([0 1]); grid on;
    the_name = 'overall_rates';
    saveas(gcf, fullfile(saveDir, sprintf('%s_%s.png', condition, the_name)));

    % ---- FA rate comparison ----
    figure;
    bar([faRate_willRepeat, faRate_neverRepeat, overallFalseAlarmRate]);
    set(gca,'XTick',1:3,'XTickLabel',{'Will-Repeat','Never-Repeat','Overall'});
    ylabel('False-Alarm Rate');
    title(sprintf('FA Rate Comparison ? %s', condition));
    ylim([0 1]); grid on;
    the_name = 'fa_rate_comparison';
    saveas(gcf, fullfile(saveDir, sprintf('%s_%s.png', condition, the_name)));

end
