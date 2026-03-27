function noise_calibration_sound(ear, input_speclevel)
% Plays a pink, Gaussian noise stimulus used to calibrate the headphones.
% 
% ear (either 'L' or 'R') determines from which headphone the sound is played
% 
% 'input_speclevel' determines the spectrum level (power per 1 Hz band) of
% the frequency component with the highest level, in unreferenced dB units: 10*log10(power)
% because the spectrum is pink, the lowest frequency component in practice has the highest level
%
% Last edited by SNH on 12/13/14

% sampling rate
sr =  48000;

% duration of the noise stimulus
dur = 120+20;

% frequency range of the noise stimulus
passband = [20,sr/2];

% pink gaussian noise with 6 dB per octave attenuation
stim = gnoise_SNH(passband(1), passband(2), input_speclevel, 75, dur, sr, 'spec_atten', 6);

% play sound to appropriate ear
stim_stereo = zeros(2,dur*sr);
stim_stereo(strcmp(ear,{'L','R'}),:) = stim;

if any(abs(stim_stereo(:))>1)
    error('Clipping');
end

% open audio device
playbackmode = 1;
latencyclass = 1; % controls how agressive PTB is in ensuring timing precicions
nchannels = 2;
PsychPortAudio('Close');
pahandle = PsychPortAudio('Open',[],playbackmode,latencyclass,sr,nchannels);
PsychPortAudio('FillBuffer',pahandle,stim_stereo);
PsychPortAudio('Start', pahandle);