function noise_calibration_test(device,ear,output_spl)
% noise_calibration_test(device,ear,output_spl)
%
% Used to test whether the transfer function measured
% using noise_calibration_sound/noise_calibration_analysis
% is accurate. Plays a pink, gaussian noise stimulus, with a spectrum
% shaped to have equal power in 1/3-octave bands, and with a specified
% SPL level. The spectrum on the sound meter should appear flat 
% (because the power is measured in 1/3-octave bands), and the total
% "Z-weighted" SPL level on the meter should equal the level specified
% in the output_spl argument.
% 
% device should be the same as that used for noise_calibration_analysis
% 
% ear is a string ('L' or 'R') specifying which headphone is being tested
%
% Last modified by Sam Norman-Haignere on 12/13/14

sr =  48000;
dur = 30;
passband = [20,10000];

tf = load(['tf-' device '-ear' ear '.mat']);
stim = gnoise_SNH(passband(1), passband(2), 0, 75, dur, sr, 'tf', tf, 'spec_atten', 10*log10(2), 'spl', output_spl);

% play sound to appropriate ear
stim_stereo = zeros(2,dur*sr);
stim_stereo(strcmp(ear,{'L','R'}),:) = stim;

if any(abs(stim_stereo(:))>1)
    error('Clipping');
end

% open audio device
deviceid = 2;
playbackmode = 2;
latencyclass = 1; % controls how agressive PTB is in ensuring timing precicions
nchannels = 2;
PsychPortAudio('Close');
pahandle = PsychPortAudio('Open',deviceid,playbackmode,latencyclass,sr,nchannels);
PsychPortAudio('FillBuffer',pahandle,stim_stereo);
PsychPortAudio('Start', pahandle);