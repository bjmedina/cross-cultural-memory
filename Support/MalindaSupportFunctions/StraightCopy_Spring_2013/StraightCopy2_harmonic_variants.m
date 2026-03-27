function [sh, sh_odd, sh_even, sh_third, sh_missing_third] = ...
    StraightCopy2_harmonic_variants(x, fs, plot_sg)
%FUNCTION [SH, SH_ODD, SH_EVEN, SH_THIRD, SH_MISSING_THIRD] = ...
%    STRAIGHTCOPY2_HARMONIC_VARIANTS(X, FS, PLOT_SG)
%   This function generates different versions of a speech utterance, to be
%   used in segregation experiments
%    x is a speech waveform at sample rate fs.
%    Use STRAIGHT to decompose into voiced and unvoiced parts, and
%    produce three new reconstructions, with a sinusoidal model of
%    the voiced portion:
%    sh is a harmonic reconstruction, intended to be very close
%      to the original.
%    sh_odd contains only odd harmonics.
%    sh_even contains only even harmonics.
%    sh_third contains every third harmonic.
%    sh_missing_third is missing every third harmonic.
%
% modified 2013-07-25 by Josh McDermott to include only harmonic variants


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
    @minimumPhaseResponse,@deterministicExcitation_harm_variants,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% Noise part only
syn_Noise = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@noiseBurstInFrequencyWhisper,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

option.deterministicHandleOption.sourceType = 'cosPlusBias';


%odd harmonics
option.deterministicHandleOption.sourceType = 'cosOddOnly';
syn_Harmonic_Odd = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_harm_variants,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

%even harmonics
option.deterministicHandleOption.sourceType = 'cosEvenOnly';
syn_Harmonic_Even = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_harm_variants,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

%every third harmonic
option.deterministicHandleOption.sourceType = 'cosThirdOnly';
syn_Harmonic_Third = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_harm_variants,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

%missing every third harmonic
option.deterministicHandleOption.sourceType = 'cosMissingThird';
syn_Harmonic_MissingThird = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_harm_variants,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

%%

sh = syn_Harm.synthesisOut;
sh_odd = syn_Harmonic_Odd.synthesisOut;
sh_even = syn_Harmonic_Even.synthesisOut;
sh_third = syn_Harmonic_Third.synthesisOut;
sh_missing_third = syn_Harmonic_MissingThird.synthesisOut;



if plot_sg
    max_f_Hz = 4000;
    sg_Harm = stftSpectrogramStructure(sh,fs,80,1,'nuttallwin12');
    sg_HarmOdd = stftSpectrogramStructure(sh_odd,fs,80,1,'nuttallwin12');
    sg_HarmEven = stftSpectrogramStructure(sh_even,fs,80,1,'nuttallwin12');
    sg_HarmThird = stftSpectrogramStructure(sh_third,fs,80,1,'nuttallwin12');
    sg_HarmMissingThird = stftSpectrogramStructure(sh_missing_third,fs,80,1,'nuttallwin12');
    
    %figure;
    subplot(321);
    imagesc([0 sg_Harm.temporalPositions(end)],[0 fs/2],max(-90,sg_Harm.dBspectrogram));
    axis([0 sg_Harm.temporalPositions(end) 0 max_f_Hz]);
    title('Harmonic synthesis');
    axis('xy');colorbar; grid
    
    subplot(323);
    imagesc([0 sg_HarmOdd.temporalPositions(end)],[0 fs/2],max(-90,sg_HarmOdd.dBspectrogram));
    axis([0 sg_HarmOdd.temporalPositions(end) 0 max_f_Hz]);
    title('Odd Harmonics');
    axis('xy');colorbar; grid

    subplot(324);
    imagesc([0 sg_HarmEven.temporalPositions(end)],[0 fs/2],max(-90,sg_HarmEven.dBspectrogram));
    axis([0 sg_HarmEven.temporalPositions(end) 0 max_f_Hz]);
    title('Even Harmonics');
    axis('xy');colorbar; grid
    
    subplot(325);
    imagesc([0 sg_HarmThird.temporalPositions(end)],[0 fs/2],max(-90,sg_HarmThird.dBspectrogram));
    axis([0 sg_HarmThird.temporalPositions(end) 0 max_f_Hz]);
    title('Third Harmonics');
    axis('xy');colorbar; grid

    subplot(326);
    imagesc([0 sg_HarmMissingThird.temporalPositions(end)],[0 fs/2],max(-90,sg_HarmMissingThird.dBspectrogram));
    axis([0 sg_HarmMissingThird.temporalPositions(end) 0 max_f_Hz]);
    title('Missing Third Harmonics');
    axis('xy');colorbar; grid
end

