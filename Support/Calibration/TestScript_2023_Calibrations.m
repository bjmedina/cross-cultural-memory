clc
soundcard =0; 

sr = 44100;
t = 0:1/sr:15;
tone = sin(2*pi*5000*t);
Stim = set_level_wrapper(tone',sr, 110,'BLACK-Soundcard');

which_ear = 0; % 1 = left
if which_ear ==1
    Stim(:,2) = 0;
else
    Stim(:,1) = 0;
end

if soundcard ==0
bit_depth = 16;
nchannels = 2;
%opening PsychPortAudio handle
pahandle = PsychPortAudio('Open', [], [], 0, sr, nchannels);


PsychPortAudio('FillBuffer', pahandle, Stim');
t1 = PsychPortAudio('Start', pahandle, 1, 0, 1);
else

 DEV='Scarlett 2i2 USB'; %find the device.
nori_do_play_soundcard_fbeg(Stim',sr,DEV)
end