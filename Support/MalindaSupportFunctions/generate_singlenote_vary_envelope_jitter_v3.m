%[signal, jitter_m] = generate_singlenote_vary_envelope_jitter(f0, harm_nums, jitt_amt,jitt, dur_s, sr, dist,JitterString, centroid)
% 
% Generates complex tone with an envelope centered at f_c and frequency
% components given by freqs (a row vector), with modifiable jitter
% The lowest harmonic is always set to the value f0 (not jittered). 
% This function saves an output signal and a vector of jitters for each note 

% Arguments explained below 
%
% sigma_factor should be in the vicinity of .5
%
% modified from spectral_note from Psych Science melodic contour paper
%
% Nov 25 2015 -- Josh McDermott
% Additions, Nov 29, Malinda McPherson 

% Arguments:

% f0 - in Hz

% harm_nums - Vector (ex. [1:1:100] - 100 harmonics. Harmonics above the
% nyquist limit are set to 0. 

% jitt_amt - scalar, ranging from 0 (harmonic) to 1. 

% jitt - 0 if no jitter (harmonid) 1 if same/fixed jitter, 2 if random jitter 
% If jitt =1, jitter must be set by 'JitterString', string of jitters used for each note, 
%otherwise if jitt=2, Jitters are recalculated for each note. 

% dur_s - duration of notes

% sr - Generally using 48000

% sigma_factor - .05 - Parameter for Gaussian Spectral envelope

% dist - controls amplitude of harmonics. 1 = gaussian, 0, exponential
% decay, 2 all harmonics equal amplitude 

% JitterString - An addition from the make_mel function that can give a
% consistent string of jitters to use for the entire melody. Only used when
% jitt = 1. JitterString is built into function make_mel_version5. 

% centroid - Mean of Gaussian spectral envelope 


function [signal, jitter_m] = generate_singlenote_vary_envelope_jitter_v2_demos(f0, harm_nums, jitt_amt,jitt, dur_s, sr, dist,JitterString, centroid, atten)


sigma_factor = .5;

%Make time vector
t=[1:round(dur_s*sr)]/sr;

freqs = [];

%% Set jitter of harmonics 
if jitt==0 % Harmonic
for h = 1:length(harm_nums)
f = f0*harm_nums(h); %add h to jitt_amt if you want to input a vector of jitters
freqs = [freqs;f];
end
elseif jitt==1 %Use the same jitter values for an entire sequence of notes (input: JitterString)
for h = 1:length(harm_nums)
jitt_amt_str = JitterString; %if using make_mel.m
f = f0*harm_nums(h) + f0*jitt_amt_str(h); %add h to jitt_amt if you want to input a vector of jitters
freqs = [freqs;f];
end
elseif jitt==2 % Generate new jitters for each note 
for h = 1:length(harm_nums)
jitt_amt_str = make_jittered_harmonics2(f0, harm_nums,jitt_amt);
f = f0*harm_nums(h) + f0*jitt_amt_str(h); %add h to jitt_amt if you want to input a vector of jitters
freqs = [freqs;f];
end
elseif jitt==3 % Shepard
jitt_amt_str = JitterString;
shift_ratio = 1;
f=f0*2.^(shift_ratio*(harm_nums-4));
freqs = f+f0*jitt_amt_str.*(2.^(shift_ratio*(harm_nums-4)))/2;
elseif jitt==4 % Shepard - Major 3rd
jitt_amt_str = JitterString;
shift_ratio = 1/3;
f=f0*2.^(shift_ratio*(harm_nums-4));
freqs = f+f0*jitt_amt_str.*(2.^(shift_ratio*(harm_nums-4)))/2;
elseif jitt==5 % Shepard - Tritone
jitt_amt_str = JitterString;
shift_ratio = .5;
f=f0*2.^(shift_ratio*(harm_nums-4));
freqs = f+f0*jitt_amt_str.*(2.^(shift_ratio*(harm_nums-4)))/2;

end

if size(freqs,1)==1
    freqs = freqs';
end

%Check for frequencies above the Nyquist limit and set to zero to prevent aliasing.  
ind = find(freqs>sr/2);
freqs(ind)=0;

% Save vector of harmonics 
jitter_m = freqs; 

%% Set distribution of harmonics
if dist == 1 %Gaussian spectral envelope - Mean of envelope set by 'centroid' input
harmonics = sin(2*pi*freqs*t);
f_c = centroid;
spec_env = exp(-((log2(freqs)-log2(f_c)).^2)/(2*log2(sigma_factor)^2));
spec_env = spec_env/sum(spec_env);
s = sum((spec_env*ones(1,length(t))).*harmonics,1);
%amp_env = exp(-4*t);
signal = s;
elseif dist == 0  %Exponential spectral Envelope 
harmonics = sin(2*pi*freqs*t);
%atten = -12;
spec_env = 10.^(atten*log2([1:length(freqs)]')/20);
s = sum((spec_env*ones(1,length(t))).*harmonics,1);
amp_env = exp(-4*t);
signal = hann(s.*amp_env,20,sr);
elseif dist ==2 %All harmonics equal amplitude 
harmonics = sin(2*pi*freqs*t);
s = sum(harmonics);
 signal = hann(s,20,sr);   
end
