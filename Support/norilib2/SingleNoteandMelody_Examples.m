%% Make single tone 
%Malinda McPherson, November 2015

mel = [0]; %Mel is a vector of semitones; can also be a single tone. 
f0 = 200; % the F0 of the 0 value in the Mel input 
harm_nums = [1:1:100]; %Include harmonics 1 to 100. Harmonics above the nyquist limit will be removed to avoid aliasing.
jitt_amt = .5; % Can range from 0 to 1. .5 is a 50% jitter of the F0. Unused if Jitt =0;
jitt = 0; %0 is harmonic, 1 is a 'fixed jitter' (the same jitter vector is used for all notes in the melody, 
% 3 is a 'changing jitter, a different jitter vector is generated for each
% note. 
dur_s = [.4]; % In seconds. Vector (one value for each note in mel) 
sr = 48000; % Sample Rate
dist = 1; % 0 = exponential spectral envelope, 1 = gaussian spectral envelope, 2 = flat spectral envelope. 
centroid = 2500;  %Center of gaussian spectral envelope (unused if dist = 0 or 2).  


mel1 = make_mel_version5(mel, f0, harm_nums, jitt_amt,jitt, dur_s, sr, dist, centroid);
soundsc(mel1, sr)

%% Make Melody

mel = [0 0 7 7 9 9 7]; %Mel is a vector of semitones; can also be a single tone. This melody is twinkle twinkle little star 
f0 = 200; % the F0 of the 0 value in the Mel input 
harm_nums = [1:1:100]; %Include harmonics 1 to 100. Harmonics above the nyquist limit will be removed to avoid aliasing.
jitt_amt = .5; % Can range from 0 to 1. .5 is a 50% jitter of the F0. Unused if Jitt =0;
jitt = 0; %0 is harmonic, 1 is a 'fixed jitter' (the same jitter vector is used for all notes in the melody, 
% 3 is a 'changing jitter, a different jitter vector is generated for each
% note. 
dur_s = [.4 .4 .4 .4 .4 .4 .8]; % In seconds. Vector (one value for each note in mel) 
sr = 48000; % Sample Rate
dist = 1; % 0 = exponential spectral envelope, 1 = gaussian spectral envelope, 2 = flat spectral envelope. 
centroid = 2500;  %Center of gaussian spectral envelope (unused if dist = 0 or 2).  


mel1 = make_mel_version5(mel, f0, harm_nums, jitt_amt,jitt, dur_s, sr, dist, centroid);
soundsc(mel1, sr)
