%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Nori Jacoby's audio library
% Please don't use it without Nori's permision...
% For more information please contact: nori.viola@gmail.com
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This function play a wavefile (y) with sample rate fs0 and record
% simulteneous into a stereo file
% This might only work in a mac, since PC requires full duplex (but perhaps
% not in advance ASIO drivers).
% context suppose to be initialize by nori_sound_card_init
%
function rec=nori_sound_card_do_play_record(context,y,fs0)
% Using the device name 'DEV'
% verbosity is 0 for minimal output (a bit from psychtoolbox)
% verbosity is 1 for text output and 2 for also running plot
% BEG are some additional safety silence added to the wavfile before and
% after (both in the recording and the playback)
verbosity=context.verbosity;
BEG=context.BEG + 0.1;
mydev=context.mydev;
mydev_input=context.mydev_input;
fs=context.fs;
nrchannels=context.nrchannels;
if nargin < 2
    fprintf('wrong number of inputs!\n');
    assert(1==0);
end



if (size(y,2)==1) ||(size(y,2)==2)
    y=y';
end

if size(y,1)==1
    y=[y;y];
end
nrchannels = 2;
wavedata=[];
for l=1:2,
    wavedata=[wavedata;resample(y(l,:),fs,fs0)];
end

size(wavedata)
wavedata=[zeros(2,round(fs*BEG)+1),wavedata];


MAXSECS=max(size(y))/fs0 +BEG*2;


repetitions=1; %repeat once audio file

if isfield(context,'pout') && (~isnan(context.pout))
    pout=context.pout; % init suppose to open this channel
else
    pout = PsychPortAudio('Open',mydev, [], 0, fs, nrchannels);
end

if isfield(context,'pin') && (~isnan(context.pin))
    pin=context.pin; % init suppose to open this channel
else
    pin = PsychPortAudio('Open',mydev_input, [], 0, fs, nrchannels);
end

% open second channel for input...
%pin= PsychPortAudio('Open',mydev_input, 2, 0, fs, nrchannels);
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

% Stay in a little loop until keypress:
while ~KbCheck && ((length(recordedaudio) / s.SampleRate) < MAXSECS)
    % Wait a second...
    WaitSecs(1);
    
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
PsychPortAudio('Stop', pout);
%PsychPortAudio('Close', pout);


rec=recordedaudio';
rec=resample(rec,fs0,fs);

% Done.
if verbosity>=1
    fprintf('stopped playing overall playing/recording %6.4g seconds of the %6.4g file\n',size(rec,1)/fs,max(size(wavedata))/fs);
end
