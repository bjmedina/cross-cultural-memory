function [sh, sh_odd, sh_odd_low] = StraightCopy2_odd_harmonic_variants(x, fs, plot_sg)
%FUNCTION [SH, SH_ODD, SH_ODD_LOW] = ...
%    STRAIGHTCOPY2_ODD_HARMONIC_VARIANTS(X, FS, PLOT_SG)
%   This function generates different versions of a speech utterance, to be
%   used in segregation experiments
%    x is a speech waveform at sample rate fs.
%    Use STRAIGHT to decompose into voiced and unvoiced parts, and
%    produce three new reconstructions, with a sinusoidal model of
%    the voiced portion:
%    sh is a harmonic reconstruction, intended to be very close
%      to the original.
%    sh_odd contains only odd harmonics.
%    sh_odd_low contains only odd harmonics of f0/2.
%
% modified 2014-08-14 by Josh McDermott to include only odd harmonic variants


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

%first, make noise component
syn_common_AP = generalSTRAIGHTsynthesisFrameworkR2AP(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_harm_variants,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% Regular resynthesis
syn_Harm_P = generalSTRAIGHTsynthesisFrameworkR2DP(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_harm_variants,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

%odd harmonics
option.deterministicHandleOption.sourceType = 'cosOddOnly';
syn_Harmonic_Odd = generalSTRAIGHTsynthesisFrameworkR2DP(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_harm_variants,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

%odd harmonics of f0/2
%testSubstrate.f0 = sourceStructure.f0*.5;
%option.deterministicHandleOption.sourceType = 'cosOddOnly';
option.deterministicHandleOption.sourceType = 'cosOddLow';
syn_Harmonic_Odd_Low = generalSTRAIGHTsynthesisFrameworkR2DP(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_harm_variants,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

%%

sh = syn_Harm_P.synthesisOut + syn_common_AP.synthesisOut;
sh_odd = syn_Harmonic_Odd.synthesisOut + syn_common_AP.synthesisOut;
sh_odd_low = syn_Harmonic_Odd_Low.synthesisOut + syn_common_AP.synthesisOut;

if plot_sg
    max_f_Hz = 4000;
    sg_Harm = stftSpectrogramStructure(sh,fs,80,1,'nuttallwin12');
    sg_HarmOdd = stftSpectrogramStructure(sh_odd,fs,80,1,'nuttallwin12');
    sg_HarmOddLow = stftSpectrogramStructure(sh_odd_low,fs,80,1,'nuttallwin12');
    
    %figure;
    subplot(311);
    imagesc([0 sg_Harm.temporalPositions(end)],[0 fs/2],max(-90,sg_Harm.dBspectrogram),[-90 0]);
    axis([0 sg_Harm.temporalPositions(end) 0 max_f_Hz]);
    title('Harmonic synthesis');
    axis('xy');colorbar; grid
    
    subplot(312);
    imagesc([0 sg_HarmOdd.temporalPositions(end)],[0 fs/2],max(-90,sg_HarmOdd.dBspectrogram),[-90 0]);
    axis([0 sg_HarmOdd.temporalPositions(end) 0 max_f_Hz]);
    title('Odd Harmonics');
    axis('xy');colorbar; grid

    subplot(313);
    imagesc([0 sg_HarmOddLow.temporalPositions(end)],[0 fs/2],max(-90,sg_HarmOddLow.dBspectrogram),[-90 0]);
    axis([0 sg_HarmOddLow.temporalPositions(end) 0 max_f_Hz]);
    title('Odd Harmonics of f0/2');
    axis('xy');colorbar; grid
end

