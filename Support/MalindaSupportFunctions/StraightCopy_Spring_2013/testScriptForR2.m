%%  Test script for new framework
%   by Hideki Kawahara
%   26/Mar./2012

[x,fs] = wavread('../baseTamdemSTRAIGHTV009ag3/openTheCrate.wav');

r = exF0candidatesTSTRAIGHTGB(x,fs)
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

syn_Normal = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@f0AdaptiveDClessPulseR2,@noiseBurstInFrequencyR2, ...
    @generateBaseShifterSigmoid,testSubstrate);

option.deterministicHandleOption.biasFactor = 0;
option.feedingHandleOption.frameRateInSecond = 0.005;
option.deterministicHandleOption.sourceType = 'cosPlusBias';

syn_Fix = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitationR2,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

syn_Fix0 = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitationR2,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

%zeroPhaseResponse
syn_Fix0zoroPhase = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @zeroPhaseResponse,@deterministicExcitationR2,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option)

option.deterministicHandleOption.biasFactor = 0.25;
syn_Fix100 = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitationR2,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

syn_Fix100zoroPhase = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @zeroPhaseResponse,@deterministicExcitationR2,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option)

%%

sg_Normal = stftSpectrogramStructure(syn_Normal.synthesisOut,fs,80,1,'nuttallwin12');

sg_Fix = stftSpectrogramStructure(syn_Fix.synthesisOut,fs,80,1,'nuttallwin12');

sg_Fix100 = stftSpectrogramStructure(syn_Fix100.synthesisOut,fs,80,1,'nuttallwin12');

%figure;
subplot(311);
imagesc([0 sg_Normal.temporalPositions(end)],[0 fs/2],max(-90,sg_Normal.dBspectrogram));
axis([0 sg_Normal.temporalPositions(end) 0 1000]);
title('reference STRAIGHT synthesis');
axis('xy');colorbar; grid

subplot(312);
imagesc([0 sg_Fix.temporalPositions(end)],[0 fs/2],max(-90,sg_Fix.dBspectrogram));
axis([0 sg_Normal.temporalPositions(end) 0 1000]);
title(['frequency biasFactor = ',num2str(option.deterministicHandleOption.biasFactor)]);
axis('xy');colorbar; grid

subplot(313);
imagesc([0 sg_Fix100.temporalPositions(end)],[0 fs/2],max(-90,sg_Fix100.dBspectrogram));
axis([0 sg_Normal.temporalPositions(end) 0 1000]);
title('frequency bias = 100 Hz');
axis('xy');colorbar; grid

%%

wavwrite(syn_Normal.synthesisOut/max(abs(syn_Normal.synthesisOut))*0.8,fs,'syn_Normal.wav');
wavwrite(syn_Fix.synthesisOut/max(abs(syn_Fix.synthesisOut))*0.8,fs,'syn_Fix50r.wav');
wavwrite(syn_Fix0.synthesisOut/max(abs(syn_Fix0.synthesisOut))*0.8,fs,'syn_Fix0.wav');
wavwrite(syn_Fix0zoroPhase.synthesisOut/max(abs(syn_Fix0zoroPhase.synthesisOut))*0.8,fs,'syn_Fix0zoroPhase.wav');
wavwrite(syn_Fix100.synthesisOut/max(abs(syn_Fix100.synthesisOut))*0.8,fs,'syn_Fix100r.wav');
wavwrite(syn_Fix100zoroPhase.synthesisOut/max(abs(syn_Fix100zoroPhase.synthesisOut))*0.8,fs,'syn_Fix3pc.wav');
