function [sh, sh_shift] = StraightCopy2_pitch_shift(x,fs,pitch_shift_st)
% [sh, sh_shift] = StraightCopy2_pitch_shift(x,fs,pitch_shift_st)
%    x is a speech waveform at sample rate fs.
%
%    sh is a harmonic reconstruction, intended to be very close
%      to the original.
%    sh_shift is a pitch-flattened harmonic version.  
%
% 2014-04-27 Josh McDermott

if nargin < 3
    pitch_shift_st = 12;
end

%%
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
    @minimumPhaseResponse,@deterministicExcitationR2,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% Shifted resynthesis
testSubstrate.f0 = sourceStructure.f0*2^(pitch_shift_st/12);

syn_Harm_Shifted = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitationR2,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

%%

sg_Harm = stftSpectrogramStructure(syn_Harm.synthesisOut,fs,80,1,'nuttallwin12');
sg_Harm_Shifted = stftSpectrogramStructure(syn_Harm_Shifted.synthesisOut,fs,80,1,'nuttallwin12');

%figure;
subplot(211);
imagesc([0 sg_Harm.temporalPositions(end)],[0 fs/2],max(-90,sg_Harm.dBspectrogram));
axis([0 sg_Harm.temporalPositions(end) 0 1000]);
title('Harmonic synthesis');
axis('xy');colorbar; grid

subplot(212);
imagesc([0 sg_Harm_Shifted.temporalPositions(end)],[0 fs/2],max(-90,sg_Harm_Shifted.dBspectrogram));
axis([0 sg_Harm_Shifted.temporalPositions(end) 0 1000]);
title('Pitch Shifted');
axis('xy');colorbar; grid

sh = syn_Harm.synthesisOut;
sh_shift = syn_Harm_Shifted.synthesisOut;

