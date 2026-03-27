function [sh, si, sw] = StraightCopy2(x,fs,bias)
% [sh, si, sw] = StraightCopy2(x,fs,bias)
%    x is a speech waveform at sample rate fs.
%    Use STRAIGHT to decompose into voiced and unvoiced parts, and
%    produce three new reconstructions, with a sinusoidal model of
%    the voiced portion:
%    sh is a harmonic reconstruction, intended to be very close
%      to the original.
%    si is an inharmonic version.  Each harmonic is displaced by
%      bias x f0. (If bias is a vector, it gives separate offsets
%      for some number of individual harmonics).
%    sw is a simulated whisper with noise replacing the voiced
%      component, and the combined result gently high-pass filtered
%      to be 3 dB down at 1600 Hz, 10 dB down at 1000 Hz, and 40 dB
%      down at 100 Hz.
%    For McDermott, Ellis & Kawahara, Interspeech 2012.
% 2012-03-30 Dan Ellis dpwe@ee.columbia.edu

if nargin < 3
    bias = 0.1;
end

%%  After testScriptForR2.m
%   Test script for new framework
%   by Hideki Kawahara
%   26/Mar./2012

%[x,fs] = wavread('../baseTamdemSTRAIGHTV009ag3/openTheCrate.wav');

r = exF0candidatesTSTRAIGHTGB(x,fs);
rc = r;
rc = autoF0Tracking(r,x);
rc.vuv = refineVoicingDecision(x,rc);
sourceStructure = aperiodicityRatioSigmoid(x,rc,1,2,0);
filterStructure = exSpectrumTSTRAIGHTGB(x,fs,sourceStructure);
%%

testSubstrate.samplingFrequency = sourceStructure.samplingFrequency;
testSubstrate.sigmoidParameter = sourceStructure.sigmoidParameter;
testSubstrate.vuv = sourceStructure.vuv;
testSubstrate.f0 = sourceStructure.f0;
testSubstrate.temporalPositions = sourceStructure.temporalPositions;
testSubstrate.cutOffListFix = sourceStructure.cutOffListFix;
testSubstrate.targetF0 = sourceStructure.targetF0;
testSubstrate.exponent = sourceStructure.exponent;
testSubstrate.spectrogramSTRAIGHT = filterStructure.spectrogramSTRAIGHT;

testSubstrate.transitionWidth = 0.15;
testSubstrate.sourceOption = (1-0.5*sourceStructure.vuv');

%syn_Normal = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
%    @minimumPhaseResponse,@f0AdaptiveDClessPulseR2,@noiseBurstInFrequencyR2, ...
%    @generateBaseShifterSigmoid,testSubstrate);

option.deterministicHandleOption.biasFactor = 0;
option.feedingHandleOption.frameRateInSecond = 0.005;
option.deterministicHandleOption.sourceType = 'cosPlusBias';

% Regular resynthesis
syn_Harm = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitationR2,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% Simulated whisper
syn_Whisper = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@noiseBurstInFrequencyWhisper,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% Inharmonic - stretch
option.deterministicHandleOption.biasFactor = bias;
syn_Inharm = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitationR2,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

%%

sg_Harm = stftSpectrogramStructure(syn_Harm.synthesisOut,fs,80,1,'nuttallwin12');
sg_Whisper = stftSpectrogramStructure(syn_Whisper.synthesisOut,fs,80,1,'nuttallwin12');
sg_Inharm = stftSpectrogramStructure(syn_Inharm.synthesisOut,fs,80,1,'nuttallwin12');

%figure;
subplot(311);
imagesc([0 sg_Harm.temporalPositions(end)],[0 fs/2],max(-90,sg_Harm.dBspectrogram));
axis([0 sg_Harm.temporalPositions(end) 0 1000]);
title('Harmonic synthesis');
axis('xy');colorbar; grid

subplot(312);
imagesc([0 sg_Whisper.temporalPositions(end)],[0 fs/2],max(-90,sg_Whisper.dBspectrogram));
axis([0 sg_Whisper.temporalPositions(end) 0 1000]);
title('Sim Whisper');
axis('xy');colorbar; grid

subplot(313);
imagesc([0 sg_Inharm.temporalPositions(end)],[0 fs/2],max(-90,sg_Inharm.dBspectrogram));
axis([0 sg_Inharm.temporalPositions(end) 0 1000]);
title(['Inharm biasFactor = ',num2str(option.deterministicHandleOption.biasFactor)]);
axis('xy');colorbar; grid

sh = syn_Harm.synthesisOut;
si = syn_Inharm.synthesisOut;

% filter is HPF'd version of voice-spectrum noise-excited
% 2nd order butterworth with 3dB point at 1200 Hz is empirically set
% 2012-08-29 dpwe@ee.columbia.edu
f_c = 1200;
f_nyq = fs/2;
filt_order = 2;
[fb,fa] = butter(filt_order, f_c/f_nyq, 'high');
% but back off the zeros from the unit circle??
zero_radius = 0.95;
fb2 = fb(1)*poly([zero_radius;zero_radius])
sw = filter(fb2,fa,syn_Whisper.synthesisOut);
