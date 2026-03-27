function nori_do_play_soundcard_fbeg(y,fs0,DEV)
verbosity=-1;
Screen('Preference','SuppressAllWarnings', 1);

if nargin < 2
    fprintf('wrong number of inputs!\n');
    assert(1==0);
end



if (nargin<3)||(isempty(DEV))
    DEV='Scarlett 2i2 USB'; %find the device.
end


BEG=0.030; % limit output file length


repetitions=1; %repeat once audio file


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
    if strcmp(strrep(devs(I).DeviceName,' ',''),strrep(DEV,' ','')) && (devs(I).NrOutputChannels>0)
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
    fprintf('\n\n ****** did not find the proper device %s  ******\n\n',DEV);
    assert(1==0);
end

if verbosity>=1
    fprintf('prepare audio...\n');
end


if (size(y,1)==1) ||(size(y,1)==2)
    y=y';
end

wavedata=resample(y,fs,fs0);
nrchannels=size(y,2);
if nrchannels < 2
    wavedata = [wavedata ; wavedata];
    nrchannels = 2;
end


assert(nrchannels==2);
wavedata=wavedata';
wavedata=[zeros(2,round(fs*BEG)+1),wavedata];

% open two channels for input and output
pout = PsychPortAudio('Open',mydev, [], 0, fs, nrchannels);
%pin= PsychPortAudio('Open',mydev, 2, 0, fs, nrchannels);
% Preallocate an internal audio recording  buffer with a capacity of 10 seconds:
%PsychPortAudio('GetAudioData', pin, 10);


% Fill the audio playback buffer with the audio data 'wavedata':
PsychPortAudio('FillBuffer', pout, wavedata);

% Start audio playback for 'repetitions' repetitions of the sound data,
% start it immediately (0) and wait for the playback to start, return onset
% timestamp.
t1out = PsychPortAudio('Start', pout, repetitions, 0, 1);
%t1in  = PsychPortAudio('Start', pin, 0, 0, 1);
%recordedaudio = [];
WaitSecs(BEG*2+length(y)/fs0);

% Close the audio device:

PsychPortAudio('Stop', pout);
PsychPortAudio('Close', pout);

