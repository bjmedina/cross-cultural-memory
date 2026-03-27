function [sh, sh_odd, sh_even, sh_shf, sh_odd_shf, sh_even_shf] = ...
    StraightCopy2_harmonic_variants_shifted_formants(x, fs, plot_sg)
%FUNCTION [SH, SH_ODD, SH_EVEN, SH_SHF, SH_ODD_SHF, SH_EVEN_SHF] = ...
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
%    _shf denotes reconstructions with shifted formants (25% higher)
%
% modified 2014-01-23 by Josh McDermott to shift formants as well as alter
% harmonics

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

num_f = size(filterStructure.spectrogramSTRAIGHT,1);
num_t = size(filterStructure.spectrogramSTRAIGHT,2);

for t = 1:num_t
    stretched_filter(:,t) = resample(filterStructure.spectrogramSTRAIGHT(:,t),5,4);
end
stretched_filter = stretched_filter(1:num_f,:);

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

altered_testSubstrate = testSubstrate;
altered_testSubstrate.spectrogramSTRAIGHT = stretched_filter;

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

% All harmonics resynthesis, shifted formants
syn_Harm_ShF = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_harm_variants,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,altered_testSubstrate,option);

% Noise part only
syn_Noise = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@noiseBurstInFrequencyWhisper,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);


%odd harmonics
option.deterministicHandleOption.sourceType = 'cosOddOnly';
syn_Harmonic_Odd = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_harm_variants,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

%odd harmonics, shifted formants
option.deterministicHandleOption.sourceType = 'cosOddOnly';
syn_Harmonic_Odd_ShF = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_harm_variants,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,altered_testSubstrate,option);

%even harmonics
option.deterministicHandleOption.sourceType = 'cosEvenOnly';
syn_Harmonic_Even = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_harm_variants,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

%even harmonics, shifted formants
option.deterministicHandleOption.sourceType = 'cosEvenOnly';
syn_Harmonic_Even_ShF = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_harm_variants,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,altered_testSubstrate,option);


%%

sh = syn_Harm.synthesisOut;
sh_odd = syn_Harmonic_Odd.synthesisOut;
sh_even = syn_Harmonic_Even.synthesisOut;
sh_shf = syn_Harm_ShF.synthesisOut;
sh_odd_shf = syn_Harmonic_Odd_ShF.synthesisOut;
sh_even_shf = syn_Harmonic_Even_ShF.synthesisOut;



if plot_sg
    max_f_Hz = 4000;
    sg_Harm = stftSpectrogramStructure(sh,fs,80,1,'nuttallwin12');
    sg_HarmOdd = stftSpectrogramStructure(sh_odd,fs,80,1,'nuttallwin12');
    sg_HarmEven = stftSpectrogramStructure(sh_even,fs,80,1,'nuttallwin12');
    sg_Harm_ShF = stftSpectrogramStructure(sh_shf,fs,80,1,'nuttallwin12');
    sg_HarmOdd_ShF = stftSpectrogramStructure(sh_odd_shf,fs,80,1,'nuttallwin12');
    sg_HarmEven_ShF = stftSpectrogramStructure(sh_even_shf,fs,80,1,'nuttallwin12');
    
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

    subplot(325);
    imagesc([0 sg_HarmEven.temporalPositions(end)],[0 fs/2],max(-90,sg_HarmEven.dBspectrogram));
    axis([0 sg_HarmEven.temporalPositions(end) 0 max_f_Hz]);
    title('Even Harmonics');
    axis('xy');colorbar; grid
    
    subplot(322);
    imagesc([0 sg_Harm_ShF.temporalPositions(end)],[0 fs/2],max(-90,sg_Harm_ShF.dBspectrogram));
    axis([0 sg_Harm_ShF.temporalPositions(end) 0 max_f_Hz]);
    title('All Harmonics, Shifted Formants');
    axis('xy');colorbar; grid

    subplot(324);
    imagesc([0 sg_HarmOdd_ShF.temporalPositions(end)],[0 fs/2],max(-90,sg_HarmOdd_ShF.dBspectrogram));
    axis([0 sg_HarmOdd_ShF.temporalPositions(end) 0 max_f_Hz]);
    title('Odd Harmonics, Shifted Formants');
    axis('xy');colorbar; grid

    subplot(326);
    imagesc([0 sg_HarmEven_ShF.temporalPositions(end)],[0 fs/2],max(-90,sg_HarmEven_ShF.dBspectrogram));
    axis([0 sg_HarmEven_ShF.temporalPositions(end) 0 max_f_Hz]);
    title('Even Harmonics, Shifted Formants');
    axis('xy');colorbar; grid
end

