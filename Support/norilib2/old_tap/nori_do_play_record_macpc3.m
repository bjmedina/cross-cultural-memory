%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Nori Jacoby's audio library
% Please don't use it without Nori's permision...
% For more information please contact: nori.viola@gmail.com
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This function play a wavefile (y) with sample rate fs0 and record
% simulteneous into a stereo file
% This might only work in a mac, since PC requires full duplex (but perhaps
% not in advance ASIO drivers).
%
% Using the device name 'DEV'
% verbosity is 0 for minimal output (a bit from psychtoolbox)
% verbosity is 1 for text output and 2 for also running plot
% BEG are some additional safety silence added to the wavfile before and
% after (both in the recording and the playback)
function rec=nori_do_play_record_macpc3(y,fs0,DEV,verbosity,BEG)

nargin;
if nargin < 2
    fprintf('wrong number of inputs!\n');
    assert(1==0);
end



if (nargin<3)||(isempty(DEV))
    DEVi={'Scarlett 2i2 USB'}; %find the device.
    DEVo={'Scarlett 2i2 USB'};
elseif length(DEV)==1
    DEVo={'Built-in Output'}; %find audio output (normal)
    DEVi={'Built-in Microph'};
elseif iscell(DEV)
    if (sum(size(DEV)==[1,2])==2)
        DEVi={DEV{1}};
        DEVo={DEV{2}};
        if verbosity>=1
            fprintf('WARNING:This form is used to specify stereo device, to specify list of optional sound card provide cell column array!\n');
            DEV
        end
    else
        DEVi=DEV;
        DEVo=DEV;
        if verbosity>=1
            fprintf('WARNING:specifying list of possible sound cards!\n');
            DEV
        end
    end
else
    DEVi={DEV};
    DEVo={DEV};
end

if (nargin<4)||(isempty(verbosity))
    verbosity=0;
end

if (nargin<5)||(isempty(BEG))
    BEG=0.5; % limit output file length
end
MAXSECS=max(size(y))/fs0 +BEG*2;


% if ismac()
%     quitKey = KbName('ESCAPE');
% else
quitKey = 27;
%end

repetitions=1; %repeat once audio file


if verbosity>=1
    fprintf('Initializing sound card to find devices:\n');
    DEV
end
InitializePsychSound();
devs=PsychPortAudio('GetDevices');

isfound=false;
for I=1:length(devs)
    if isfound
        break
    end
    if verbosity>=1
        fprintf('scan devices found %s as # %d\n',devs(I).DeviceName,I);
        
    end
    if devs(I).NrInputChannels==0
        continue
    end
    
    
    for K=1:numel(DEVi)
        
        %if ~isempty(strfind(devs(I).DeviceName,DEVi))
        if strcmp(strrep(devs(I).DeviceName,' ',''),strrep(DEVi{K},' ',''))
            mydev_i=devs(I).DeviceIndex;
            fs_i=devs(I).DefaultSampleRate;
            if verbosity>=1
                fprintf('found input device %s as device index %d (cell pos %d)\n\n',devs(I).DeviceName,mydev_i,K);
            end
            isfound=true;
            break;
        end
    end
end
if ~isfound
    fprintf('did not find the proper device: ');
    DEVi
    assert(1==0);
end

isfound=false;
for I=1:length(devs)
    if isfound
        break
    end
    if verbosity>=1
        fprintf('scan devices found %s as # %d \n',devs(I).DeviceName,I);
        
    end
    
    
    if devs(I).NrOutputChannels==0
        continue
    end
    
    for K=1:numel(DEVo)
        
        %if ~isempty(strfind(devs(I).DeviceName,DEVo))
        if strcmp(strrep(devs(I).DeviceName,' ',''),strrep(DEVo{K},' ',''))
            mydev_o=devs(I).DeviceIndex;
            fs_o=devs(I).DefaultSampleRate;
            if verbosity>=1
                fprintf('found output device %s as device index %d(cell pos %d)\n\n',devs(I).DeviceName,mydev_o,K);
            end
            isfound=true;
            break;
        end
    end
end
if ~isfound
    fprintf('did not find the proper device:');
    DEVo
    assert(1==0);
end



assert(fs_i==fs_o);
fs=fs_i;

if (size(y,2)==1) ||(size(y,2)==2)
    y=y';
end

wavedata=resample(y,fs,fs0);


nrchannels=size(y,1);
if nrchannels < 2
    wavedata = [wavedata ; wavedata];
    nrchannels = 2;
end
assert(nrchannels==2);
wavedata=[zeros(2,round(fs*BEG)+1),wavedata];

% open two channels for input and output
pout = PsychPortAudio('Open',mydev_o, [], 0, fs, nrchannels);
pin= PsychPortAudio('Open',mydev_i, 2, 0, fs, nrchannels);
% Preallocate an internal audio recording  buffer with a capacity of 10 seconds:
PsychPortAudio('GetAudioData', pin, 10);


% Fill the audio playback buffer with the audio data 'wavedata':
PsychPortAudio('FillBuffer', pout, wavedata);

% Start audio playback for 'repetitions' repetitions of the sound data,
% start it immediately (0) and wait for the playback to start, return onset
% timestamp.
t1out = PsychPortAudio('Start', pout, repetitions, 0, 1);
t1in  = PsychPortAudio('Start', pin, 0, 0, 1);
recordedaudio = [];

% We retrieve status once to get access to SampleRate:
s = PsychPortAudio('GetStatus', pin);

[~, ~, KeyCode]=KbCheck;
% Stay in a little loop until keypress:
while  ((length(recordedaudio) / s.SampleRate) < MAXSECS)
    % Wait a second...
    WaitSecs(1);
    [~, ~, KeyCode]=KbCheck;
    
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
PsychPortAudio('Stop', pout);
PsychPortAudio('Close', pout);


rec=recordedaudio';
rec=resample(rec,fs0,fs);
% Done.
if verbosity>=1
    fprintf('stopped playing overall playing/recording %6.4g seconds of the %6.4g file\n',size(rec,1)/fs,max(size(wavedata))/fs);
end

%%%% this show how to do additional stuff: currently not required.

% Replay recorded data: Open default device for output, push recorded sound
% data into its output buffer:
% pin = PsychPortAudio('Open', [], 1, 0, 44100, 2);
% PsychPortAudio('FillBuffer', pin, recordedaudio);
%
% % Start playback immediately, wait for start, play once:
% PsychPortAudio('Start', pin, 1, 0, 1);
%
% % Wait for end of playback, then stop engine:
% PsychPortAudio('Stop', pin, 1);
%
% % Close the audio device:
% PsychPortAudio('Close', pin);