% This function record stimulus from psychophsics toolbox.
% Using the device name 'DEV' 
% sampling rate is f0 (may be different from the device sampling rate)

function rec=nori_do_record_fbeg(fs0,MAXSECS,DEV)

% check with these two lines the name of your builtin sound card
%InitializePsychSound();
%devs=PsychPortAudio('GetDevices'); 
% currently set to mac defualt internal soundcard :'Built-in Microph'
%fs0=44100;
%MAXSECS=5;
%DEV=nan;

if (nargin<3)||(isempty(DEV))
    DEV='Scarlett 2i2 USB'; %find the device.
end

if (length(DEV)==1) && isnan(DEV)
    DEV='Built-in Microph'; %find audio output (normal)
end

verbosity = 0;
WAIT_BEGINING=0.051; % (in seconds) need to be a larger than 0 otherwise because of the keyboard press of the command in matlab you will quit imidiately.

%default_name='Built-in Microph';
default_name='Scarlett 2i2 USB';


if nargin < 1
    fprintf('wrong number of inputs!\n');
    assert(1==0);
end

if (nargin<2)||(isempty(DEV))
    %DEV='Scarlett 2i2 USB'; %for Nori's Bolivia experiments
    DEV=default_name; %find audio output (normal)
end

if length(DEV)==1
    DEV=default_name; %find audio output (normal)
end

if (isempty(verbosity))
    verbosity=0;
end

if verbosity>=1
    fprintf('Initializing sound card...\n');
end

InitializePsychSound();

devs=PsychPortAudio('GetDevices');
isfound=false;
for I=1:length(devs)
    if verbosity>=1
        fprintf('scan devices found %s as # %d (searching for %s)\n',devs(I).DeviceName,I,DEV);
    end
    if strcmp(strrep(devs(I).DeviceName,' ',''),strrep(DEV,' ','')) && (devs(I).NrInputChannels>0)
        mydev=devs(I).DeviceIndex;
        fs=devs(I).DefaultSampleRate;
        if verbosity>=1
            fprintf('found device %s as device index %d\n',devs(I).DeviceName,mydev);
        end
        isfound=true;
        break;
    end
end
if ~isfound
    fprintf('did not find the proper device %s ',DEV);
    assert(1==0);
end

if verbosity>=1
    fprintf('prepare audio...\n');
end

nrchannels=2;

% open two channels for input and output
pin= PsychPortAudio('Open',mydev, 2, 0, fs, nrchannels);

% Preallocate an internal audio recording  buffer with a capacity of 10 seconds:
PsychPortAudio('GetAudioData', pin, 10);

% Start audio playback for 'repetitions' repetitions of the sound data,
% start it immediately (0) and wait for the playback to start, return onset
% timestamp.
t1in  = PsychPortAudio('Start', pin, 0, 0, 1);
recordedaudio = [];

% We retrieve status once to get access to SampleRate:
s = PsychPortAudio('GetStatus', pin);

%sprintf('--->%g of %g...\n', (length(recordedaudio) / s.SampleRate), MAXSECS)

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
PsychPortAudio('Close', pin);

rec=recordedaudio';
rec=resample(rec,fs0,fs);

% Done.
if verbosity>=1
    fprintf('stopped playing overall recording %6.4g seconds of the file\n',size(rec,1)/fs);
end
