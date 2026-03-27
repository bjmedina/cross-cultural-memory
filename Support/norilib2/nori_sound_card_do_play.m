%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Nori Jacoby's audio library
% Please don't use it without Nori's permision...
% For more information please contact: nori.viola@gmail.com
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function nori_sound_card_do_play(context,y,fs0)
fs=context.fs;
pout=context.pout;
%devs=context.devs;


verbosity=context.verbosity;
BEG=context.BEG;
Screen('Preference','SuppressAllWarnings', 1);



%BEG=0.1; % limit output file length
repetitions=1; %repeat once audio file


if verbosity>=1
    fprintf('prepare audio...\n');
end


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
%pout = PsychPortAudio('Open',mydev, [], 0, fs, nrchannels);
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
%PsychPortAudio('Close', context.pout);

