% TE_noise(duration_ms,l_co[Hz],h_co[Hz],[Level(dB)],[circular(0/1)],[SAMPLERATE])
%  Generates threshold equalizing (TEN) noise in the spectral domain
% with specified duration, cut-off frequencies
% and level (dB rms re 1. Default = -20).
%   If circular is selected (1), then the buffer is periodic.
% Otherwise (0) the fft is done on a power-of-2 vector and
% then truncated to the desired length (faster).
%
%   TEN produces equal masked thresholds for normal hearing listeners for all
% frequencies between 0.125 and 15 kHz.
%   Assumption: Power of the signal at threshold (Ps) is given by the
% equation, Ps = No*K*ERB, where No is the noise power spectral density and
% K is the snr at the output of the auditory filter required for threshold.
%   TEN is spectrally shaped so that No*K*ERB is constant.  Values for K
% and ERB are taken from Moore et al. (1997).  
% !!!IMPORTANT!!! TEN level is specified in terms of the level in a one-ERB wide band
% around 1000 Hz, NOT in terms of overall level.
%
%Last modified by A. Oxenham Jan 30, 2007
%

function noise = TE_noise(duration_ms,lco,hco,level,circular,SAMPLERATE)

if nargin < 3
   help TE_noise
   return
elseif nargin < 4
  level = -20; circular = 0; SAMPLERATE = 48000;
elseif nargin < 5
   circular = 0; SAMPLERATE = 48000;
elseif nargin < 6
   SAMPLERATE = 48000;
end

dur_smp = round(duration_ms * SAMPLERATE / 1000);
bandwidth = hco - lco;
max_bw = SAMPLERATE / 2;

if (circular==1)
   fftpts = dur_smp;
else
   fftpts = findnextpow2(dur_smp);
end

binfactor = fftpts / SAMPLERATE;
LPbin = round(lco*binfactor) + 1;
HPbin = round(hco*binfactor) + 1;

a = zeros(1,fftpts);
b = a;

a(LPbin:HPbin) = randn(1,HPbin-LPbin+1);
b(LPbin:HPbin) = randn(1,HPbin-LPbin+1);

fspec = a + i*b;


local_freq_bin = [LPbin:HPbin];
frequency = ((local_freq_bin-1)/binfactor)/1000;
all_freqs = ([1:fftpts]/binfactor)/1000;

%all_freqs = frequency;
% K values are from a personal correspondence with B.C.J. Moore.  A figure
% also appears in Moore et al. (1997).

K = [0.0500   13.5000
    0.0630   10.0000
    0.0800    7.2000
    0.1000    4.9000
    0.1250    3.1000
    0.1600    1.6000
    0.2000    0.4000
    0.2500   -0.4000
    0.3150   -1.2000
    0.4000   -1.8500
    0.5000   -2.4000
    0.6300   -2.7000
    0.7500   -2.8500
    0.8000   -2.9000
    1.0000   -3.0000
    1.1000   -3.0000
    2.0000   -3.0000
    4.0000   -3.0000
    8.0000   -3.0000
   10.0000   -3.0000
   15.0000   -3.0000];


% K values are interpolated between 0.125 and 15 kHz.
KdB = spline(K(:,1),K(:,2),all_freqs')';


%plot(all_freqs,KdB);
%pause;
% Calculate ERB at each freq.
ERB = 24.7*((4.37*all_freqs)+1);
cr_erb= KdB + (10*log10(ERB));
TEN_No =  -cr_erb;
%plot(all_freqs, TEN_No)


index1kERB = find(all_freqs > 0.935 & all_freqs < 1.0681);  %Cams for 1 kHz +- 0.5 Cams
total_level_dB = 10.*log10(sum(10.^(TEN_No/10)));
total_level_1k = 10.*log10(sum(10.^(TEN_No(index1kERB)/10)));
ratio_1k_dB = total_level_dB - total_level_1k;

magnitude_TEN = mean(10.^(TEN_No/10));              %Average power
magnitude_ratio_dB = 10*log10(magnitude_TEN) + 3;  %Average power in dB (half the full buffer size)

fspecfilt = fspec;

fspecfilt(LPbin:HPbin) = fspecfilt(LPbin:HPbin) .* 10.^(TEN_No(LPbin:HPbin)/20);
%lengths = [length(LPbin:HPbin) length(10.^(TEN_No/20))]

%fspecfilt(LPbin:HPbin) = fspecfilt(LPbin:HPbin) .* 10.^(TEN_No/20);


noise = ifft(fspecfilt);
noise = real(noise(1:dur_smp));

%noise2 = ifft(fspec);
%noise2 = real(noise2(1:dur_smp));

%normalize level
noise = noise .* sqrt(2*fftpts) ./ (10.^(magnitude_ratio_dB/20)) * 10.^(ratio_1k_dB/20);
%noise = noise .* sqrt(2*fftpts) .* 10.^(ratio_1k_dB/20);

noise = scale(noise,level);

% eof