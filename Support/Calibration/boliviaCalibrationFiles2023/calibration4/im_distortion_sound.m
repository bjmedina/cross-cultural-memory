function p = im_distortion_sound(device, ear, varargin)
% p = im_distortion_sound(device, ear)
%
% Plays a series of harmonic complexes at different frequencies
% used to measure the distortion characteristics of headphones
% in conjunction with the im_distortion_analysis script.
% 
% Device is a string specifying the headphone.
% The transfer function of the headphone needs to have
% already been measured with the noise_calibration scripts.
%
% Ear is a string ('L' or 'R') specifying whether the left or
% right headphone is being used.
% 
% Returns a structure, which is used by im_distortion_analysis
% 
% Last edited by Sam Norman-Haignere on 12/13/14

%% parameters that can be manipulated

% the level of the complexes in dB SPL
p.spl = [80 90];

% the lowest frequency in each octave-band harmonic complex
% p.lowfreqs = [100 200 400 800 1600 3200 6400];
% p.lowfreqs = [250 500 1000 2000 4000];
p.lowfreqs = [1000];

% the number of harmonics in each complex
% the F0 is determined by the lowest frequency
% F0 = lowfreq / lowharms
p.lowharms = 10;

% the phase relationship of tones
% for "schroeder-phase" harmonics put 'schr-nharms'
p.phaserel = {'sine'};

%% these parameters are assumed to be fixed
p.sr = 48000;
p.dur = 1.2;
p.filt_atten = inf;
p.bw = 2;
p.semijitter = 0;

%% Create stimulus

nstims = length(p.lowfreqs) * length(p.lowharms) * length(p.semijitter) * length(p.spl) * length(p.phaserel);
total_smps = round(p.sr * p.dur * nstims);

p.lowfreqs_order = nan(nstims,1);
p.lowharms_order = nan(nstims,1);
p.semijitter_order = nan(nstims,1);
p.spl_order = nan(nstims,1);
p.phaserel_order = cell(nstims,1);
p.f0_order = nan(nstims,1);

fprintf('Total duration: %.2f seconds\n', nstims * p.dur);

tf = load(['tf-' device '-ear' ear '.mat']);
stim = zeros(total_smps, 1);
index = 0;
for i = 1:length(p.lowfreqs)
    for j = 1:length(p.lowharms)
        for k = 1:length(p.semijitter)
            for m = 1:length(p.spl)
                for n = 1:length(p.phaserel)
                    
                    index = index + 1;
                    
                    f0 = round( (p.lowfreqs(i)/p.lowharms(j)) * 2^(p.semijitter(k)/12) );
                    
                    if ~optInputs(varargin, 'nosound')
                        stim( round((1:p.dur*p.sr) + (index-1)*p.dur*p.sr) ) = synth_harm_note_mono( f0, f0*[p.lowharms(j), p.lowharms(j)*p.bw], p.phaserel{n}, p.dur, p.sr, p.spl(m), tf, p.filt_atten );
                    end
                    
                    p.f0_order(index) = f0;
                    p.lowfreqs_order(index) = p.lowfreqs(i);
                    p.lowharms_order(index) = p.lowharms(j);
                    p.semijitter_order(index) = p.semijitter(k);
                    p.spl_order(index) = p.spl(m);
                    p.phaserel_order{index} = p.phaserel{n};
                    
                end
            end
        end
    end
end

if optInputs(varargin, 'nosound')
    return;
end

%% Play stimulus

stim_stereo = zeros(2,size(stim,1));
stim_stereo(strcmp(ear,{'L','R'}),:) = stim;

if any(abs(stim_stereo(:))>1)
    error('Clipping');
end

fprintf('Press any key to start stimulus\n'); drawnow;
FlushEvents('keyDown');
GetChar;

% open audio device
deviceid = 1;
playbackmode = 1;
latencyclass = 1; % controls how agressive PTB is in ensuring timing precicions
nchannels = 2;
PsychPortAudio('Close');
pahandle = PsychPortAudio('Open',deviceid,playbackmode,latencyclass,p.sr,nchannels);
PsychPortAudio('FillBuffer',pahandle,stim_stereo);
PsychPortAudio('Start', pahandle);
