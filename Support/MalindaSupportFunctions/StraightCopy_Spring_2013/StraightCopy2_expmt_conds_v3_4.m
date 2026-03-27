function [sh, sw, sh_odd, si_str, si_cmp] = ...
    StraightCopy2_expmt_conds_v3_4(x, fs, stretch_factor, cmp_vars, plot_sg)
%FUNCTION [SH, SW, SH_ODD, SI_STR, SI_CMP] = ...
%    STRAIGHTCOPY2_EXPMT_CONDS_V3_4(X, FS, STRETCH_FACTOR, CMP_VARS, PLOT_SG)
%   This function generates different versions of a speech utterance, to be
%   used in segregation experiments
%    x is a speech waveform at sample rate fs.
%    Use STRAIGHT to decompose into voiced and unvoiced parts, and
%    produce three new reconstructions, with a sinusoidal model of
%    the voiced portion:
%    sh is a harmonic reconstruction, intended to be very close
%      to the original.
%    sw is a simulated whisper with noise replacing the voiced
%      component, and the combined result gently high-pass filtered
%      to be 3 dB down at 1600 Hz, 10 dB down at 1000 Hz, and 40 dB
%      down at 100 Hz.
%    sh_odd contains only odd harmonics.
%    si_str is a "stretched" inharmonic version with frequency components
%       altered by n*(n-1)*STRETCH_FACTOR*F0 over their harmonic
%       frequency
%    si_cmp is a "compressed" inharmonic version with frequency components
%       altered such that the inter-component spacing is CMP_VARS(1)
%       between harmonics 1 and 2, and linearly increases to the F0 by
%       harmonic number CMP_VARS(2)%
%
% 2012-03-30 Dan Ellis dpwe@ee.columbia.edu
% modified 2012-08-31 by Josh McDermott to do multiple variants at once
% modified 2012-10-11 by Josh McDermott to add a second jittered variant
% modified 2013-03-24 by Josh McDermott to incorporate alternative variants
% modified 2013-05-29 by Josh McDermott to fix compressed variant
% modified 2013-07-1 by Josh McDermott to leave only the variants needed
% for sparsity experiment


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
option.deterministicHandleOption.sourceType = 'cos';

% Regular resynthesis
syn_Harm = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitationR3,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% Noise part only
syn_Noise = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@noiseBurstInFrequencyWhisper,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

option.deterministicHandleOption.sourceType = 'cosPlusBias';

% Inharmonic - stretched
if length(stretch_factor)==1
    harm_nums = 1:60;
    stretch_factors = harm_nums.*(harm_nums-1)*stretch_factor;
    option.deterministicHandleOption.biasFactor = stretch_factors;
else
    error([],'There should be a single shift factor');
end
syn_Inharm_stretch = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitationR3,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% Inharmonic - compressed
if length(cmp_vars)==2
    harm_nums = 1:60;
    start_int = cmp_vars(1);
    N = cmp_vars(2);
    freq_ratios = 1 + [0 cumsum([start_int : (1-start_int)/(N-2) : 1])];
    freq_ratios = [freq_ratios max(freq_ratios)+[1:max(harm_nums)-N] ];
    
    cmp_factors = freq_ratios - harm_nums;
    option.deterministicHandleOption.biasFactor = cmp_factors;
else
    error([],'There should be two compression-related variables');
end
syn_Inharm_cmp = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitationR3,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

%odd harmonics
option.deterministicHandleOption.sourceType = 'cosOddOnly';
syn_Harmonic_Odd = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitationR3,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% Simulated whisper
syn_Whisper = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@noiseBurstInFrequencyWhisper,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

%%

sh = syn_Harm.synthesisOut;
sh_odd = syn_Harmonic_Odd.synthesisOut;
si_str = syn_Inharm_stretch.synthesisOut;
si_cmp = syn_Inharm_cmp.synthesisOut;

% filter is HPF'd version of voice-spectrum noise-excited
% 2nd order butterworth with 3dB point at 1200 Hz is empirically set
% 2012-08-29 dpwe@ee.columbia.edu
f_c = 1200;
f_nyq = fs/2;
filt_order = 2;
[fb,fa] = butter(filt_order, f_c/f_nyq, 'high');
% but back off the zeros from the unit circle??
zero_radius = 0.95;
fb2 = fb(1)*poly([zero_radius;zero_radius]);
sw = filter(fb2,fa,syn_Whisper.synthesisOut);


if plot_sg
    max_f_Hz = 4000;
    sg_Harm = stftSpectrogramStructure(sh,fs,80,1,'nuttallwin12');
    sg_Whisper = stftSpectrogramStructure(sw,fs,80,1,'nuttallwin12');
    sg_HarmOdd = stftSpectrogramStructure(sh_odd,fs,80,1,'nuttallwin12');
    sg_Stretched = stftSpectrogramStructure(si_str,fs,80,1,'nuttallwin12');
    sg_Compressed = stftSpectrogramStructure(si_cmp,fs,80,1,'nuttallwin12');
    
    %figure;
    subplot(231);
    imagesc([0 sg_Harm.temporalPositions(end)],[0 fs/2],max(-90,sg_Harm.dBspectrogram));
    axis([0 sg_Harm.temporalPositions(end) 0 max_f_Hz]);
    title('Harmonic synthesis');
    axis('xy');colorbar; grid
    
    subplot(232);
    imagesc([0 sg_Whisper.temporalPositions(end)],[0 fs/2],max(-90,sg_Whisper.dBspectrogram));
    axis([0 sg_Whisper.temporalPositions(end) 0 max_f_Hz]);
    title('Sim Whisper');
    axis('xy');colorbar; grid
    
    subplot(233);
    imagesc([0 sg_HarmOdd.temporalPositions(end)],[0 fs/2],max(-90,sg_HarmOdd.dBspectrogram));
    axis([0 sg_HarmOdd.temporalPositions(end) 0 max_f_Hz]);
    title('Odd Harmonics');
    axis('xy');colorbar; grid

    subplot(234);
    imagesc([0 sg_Stretched.temporalPositions(end)],[0 fs/2],max(-90,sg_Stretched.dBspectrogram));
    axis([0 sg_Stretched.temporalPositions(end) 0 max_f_Hz]);
    title(['Stretched Inharmonic, biasFactor = ',num2str(stretch_factor)]);
    axis('xy');colorbar; grid

    subplot(235);
    imagesc([0 sg_Compressed.temporalPositions(end)],[0 fs/2],max(-90,sg_Compressed.dBspectrogram));
    axis([0 sg_Compressed.temporalPositions(end) 0 max_f_Hz]);
    title(['Compressed Inharmonic, starting int = ',num2str(cmp_vars(1))]);
    axis('xy');colorbar; grid
    
end

