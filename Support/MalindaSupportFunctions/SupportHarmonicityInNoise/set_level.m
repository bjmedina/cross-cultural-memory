function new_s = set_level(s,sr,desired_spl,booth_ear_string)

% FUNCTION NEW_S = SET_LEVEL(S,SR,DESIRED_SPL,BOOTH_EAR_STRING)
%
% returns normalized copy of waveform S with the level specified in
% DESIRED_SPL. SR is the sampling rate
%
% user must specify the booth and ear in the string BOOTH_EAR_STRING
% ('BoothALeft', 'BoothARight', etc...)
%
% uses normalization functions written by Sam Norman-Haignere in spring
% 2013
%
% June 25 2013 -- Josh McDermott
%
% April 23 2015 -- Sara Popham;  Calibration Update with new TFs
%
% June 28 2015 -- Sam Norman-Haignere;  Changed calibration files for
% Booth D, also cleaned up the code a bit, and added an example usage.
%
% June 06, 2017 -- Ray Gonzalez raysgon@yahoo.com; Calibrated booths
% with transfer functions and distortion measurements.
% -- Example --
%
% booth = 'BoothD';
% [wav,sr] = audioread('example_sound.wav');
% wav_75dB_left = set_level(wav, sr, 75, [booth 'Left']);
% wav_75dB_right = set_level(wav, sr, 75, [booth 'Right']);
% sound([wav_75dB_left,wav_75dB_right],sr);

tf = booth_transfer_functions(booth_ear_string);
new_s = wavnorm(s, desired_spl, tf, sr);
