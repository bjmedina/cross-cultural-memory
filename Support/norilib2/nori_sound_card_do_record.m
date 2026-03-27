%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Nori Jacoby's audio library
% Please don't use it without Nori's permision...
% For more information please contact: nori.viola@gmail.com
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This function record stimulus from psychophsics toolbox.
% Using the device name 'DEV' 
% sampling rate is f0 (may be different from the device sampling rate)

function rec=nori_sound_card_do_record(context,fs0,MAXSECS)

verbosity=context.verbosity;
WAIT_BEGINING=0.1; % (in seconds) need to be a larger than 0 otherwise because of the keyboard press of the command in matlab you will quit imidiately.

%BEG=context.BEG;
BEG=0; % initial slack in the begining. (no need to be larger than 0
nrchannels=2;

fs=context.fs;

if isfield(context,'pin') && (~isnan(context.pin))
    pin=context.pin; % init suppose to open this channel
else
    pin = PsychPortAudio('Open',mydev_input, [], 0, fs, nrchannels);
end

% open two channels for input and output
%pin= PsychPortAudio('Open',context.mydev_input, 2, 0, fs, nrchannels);

% Preallocate an internal audio recording  buffer with a capacity of 10 seconds:
PsychPortAudio('GetAudioData', pin, 10);

% Start audio playback for 'repetitions' repetitions of the sound data,
% start it immediately (0) and wait for the playback to start, return onset
% timestamp.
t1in  = PsychPortAudio('Start', pin, 0, 0, 1);
recordedaudio = [];

% We retrieve status once to get access to SampleRate:
s = PsychPortAudio('GetStatus', pin);

%sprintf('--->%g of %g...\n', (length(recordedaudio) / s.SampleRate), MAXSECS);

WaitSecs(WAIT_BEGINING); %wait a little bit before starting...

% Stay in a little loop until keypress:
while ~KbCheck && ((length(recordedaudio) / s.SampleRate) < MAXSECS)
    
    if verbosity>=1
        sprintf('%g of %g...\n', (length(recordedaudio) / s.SampleRate), MAXSECS)
    end
    
    % Wait a second...
    WaitSecs(1); %recduce to get faster latency
    
    if verbosity>=1
        
        s = PsychPortAudio('GetStatus', pin);
        
        % Print it:
        fprintf('\n\nAudio capture started, press any key for about 1 second to quit.\n');
        fprintf('This is some status output of PsychPortAudio:\n');
        disp(s);
    end
    
    % Retrieve pending audio data from the drivers internal ringbuffer:
    audiodata = PsychPortAudio('GetAudioData', pin);
    nrsamples = size(audiodata, 2);
    if verbosity>=2
        % Plot it, just for the fun of it:
        plot(1:nrsamples, audiodata(1,:), 'r', 1:nrsamples, audiodata(2,:), 'b');
        drawnow;
    end
    
    % And attach it to our full sound vector:
    recordedaudio = [recordedaudio audiodata]; %#ok<AGROW>
end

% Stop capture:
PsychPortAudio('Stop', pin);

% Perform a last fetch operation to get all remaining data from the capture engine:
audiodata = PsychPortAudio('GetAudioData', pin);

% Attach it to our full sound vector:
recordedaudio = [recordedaudio audiodata];

% Close the audio device:
%PsychPortAudio('Close', pin);

rec=recordedaudio';
rec=resample(rec,fs0,fs);

% Done.
if verbosity>=1
    fprintf('stopped playing overall recording %6.4g seconds of the file\n',size(rec,1)/fs);
end
