function [sh, si_jitt, si_jitt_res, si_jitt_unres, sh_res, sh_unres] = StraightCopy2_expmt_conds_v4_1(x,fs,jitter_amts,highest_res_harm_n, plot_sg)
%FUNCTION [SH, SI_JITT, SI_JITT_RES, SI_JITT_UNRES, SH_RES, SH_UNRES] = STRAIGHTCOPY2_EXPMT_CONDS_V4_1(X,FS,JITTER_AMTS,HIGHEST_RES_HARM_N, PLOT_SG)
%   This function generates different versions of a speech utterance, to be
%   used in segregation experiments
%    X is a speech waveform at sample rate FS.
%    Use STRAIGHT to decompose into voiced and unvoiced parts, and
%    produce three new reconstructions, with a sinusoidal model of
%    the voiced portion:
%    SH is a harmonic reconstruction, intended to be very close
%      to the original.
%    SI_JITT is an inharmonic versions.  Each harmonic is displaced by
%      jitter_amts.
%    SI_JITT_RES has the resolved harmonics (numbered less than or equal to
%    HIGHEST_RES_HARM_N) jittered, and the unresolved harmonics left
%    harmonic.
%    SI_JITT_UNRES has the unresolved harmonics (numbered greater than
%    HIGHEST_RES_HARM_N) jittered, and the resolved harmonics left
%    harmonic.
%    SH_RES has only resolved harmonics, at the usual frequencies.
%    SH_UNRES has only unresolved harmonics, at the usual frequencies.
%
% 2012-03-30 Dan Ellis dpwe@ee.columbia.edu
% modified 2012-08-31 by Josh McDermott to do multiple variants at once
% modified 2012-10-11 by Josh McDermott to add a second jittered variant
% modified 2013-7-1 by Josh McDermott to add experimental conditions

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
    @minimumPhaseResponse,@deterministicExcitationR4,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% Noise part only
syn_Noise = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@noiseBurstInFrequencyWhisper,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% Inharmonic - jittered
option.deterministicHandleOption.biasFactor = jitter_amts;
syn_Inharm_jitt = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitationR4,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% Inharmonic - jittered resolved components
option.deterministicHandleOption.biasFactor = jitter_amts(1:highest_res_harm_n);
syn_Inharm_jitt_res = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitationR4,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% Inharmonic - jittered unresolved components
temp = jitter_amts;
temp(1:highest_res_harm_n) = 0;
option.deterministicHandleOption.biasFactor = temp;
syn_Inharm_jitt_unres = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitationR4,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% unresolved harmonics only
option.deterministicHandleOption.sourceType = 'cosUnres';
option.deterministicHandleOption.biasFactor = [highest_res_harm_n+1];
syn_Harmonic_Unres = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitationR4,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% resolved harmonics only
option.deterministicHandleOption.sourceType = 'cosRes';
option.deterministicHandleOption.biasFactor = [highest_res_harm_n];
syn_Harmonic_Res = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitationR4,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

%%

sh = syn_Harm.synthesisOut;
si_jitt = syn_Inharm_jitt.synthesisOut;
si_jitt_res = syn_Inharm_jitt_res.synthesisOut;
si_jitt_unres = syn_Inharm_jitt_unres.synthesisOut;
sh_res = syn_Harmonic_Res.synthesisOut;
sh_unres = syn_Harmonic_Unres.synthesisOut;

% Simulated whisper
syn_Whisper = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@noiseBurstInFrequencyWhisper,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

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
    sg_Jitt = stftSpectrogramStructure(si_jitt,fs,80,1,'nuttallwin12');
    sg_Jitt_Res = stftSpectrogramStructure(si_jitt_res,fs,80,1,'nuttallwin12');
    sg_Jitt_Unres = stftSpectrogramStructure(si_jitt_unres,fs,80,1,'nuttallwin12');
    sg_HarmUnres = stftSpectrogramStructure(sh_unres,fs,80,1,'nuttallwin12');
    sg_HarmRes = stftSpectrogramStructure(sh_res,fs,80,1,'nuttallwin12');
    
    %figure;
    subplot(331);
    imagesc([0 sg_Harm.temporalPositions(end)],[0 fs/2],max(-90,sg_Harm.dBspectrogram));
    axis([0 sg_Harm.temporalPositions(end) 0 max_f_Hz]);
    title('Harmonic synthesis');
    axis('xy');colorbar; grid
    
    subplot(332);
    imagesc([0 sg_Whisper.temporalPositions(end)],[0 fs/2],max(-90,sg_Whisper.dBspectrogram));
    axis([0 sg_Whisper.temporalPositions(end) 0 max_f_Hz]);
    title('Sim Whisper');
    axis('xy');colorbar; grid
    
    subplot(334);
    imagesc([0 sg_Jitt.temporalPositions(end)],[0 fs/2],max(-90,sg_Jitt.dBspectrogram));
    axis([0 sg_Jitt.temporalPositions(end) 0 max_f_Hz]);
    title('Inarmonic');
    axis('xy');colorbar; grid

    subplot(335);
    imagesc([0 sg_Jitt_Res.temporalPositions(end)],[0 fs/2],max(-90,sg_Jitt_Res.dBspectrogram));
    axis([0 sg_Jitt_Res.temporalPositions(end) 0 max_f_Hz]);
    title(['Jittered Resolved (below ' num2str(highest_res_harm_n) ')']);
    axis('xy');colorbar; grid

    subplot(336);
    imagesc([0 sg_Jitt_Unres.temporalPositions(end)],[0 fs/2],max(-90,sg_Jitt_Unres.dBspectrogram));
    axis([0 sg_Jitt_Unres.temporalPositions(end) 0 max_f_Hz]);
    title('Jittered Unresolved');
    axis('xy');colorbar; grid

    subplot(338);
    imagesc([0 sg_HarmRes.temporalPositions(end)],[0 fs/2],max(-90,sg_HarmRes.dBspectrogram));
    axis([0 sg_HarmRes.temporalPositions(end) 0 max_f_Hz]);
    title(['Resolved - Highest Harmonic # = ',num2str(highest_res_harm_n)]);
    axis('xy');colorbar; grid

    subplot(339);
    imagesc([0 sg_HarmUnres.temporalPositions(end)],[0 fs/2],max(-90,sg_HarmUnres.dBspectrogram));
    axis([0 sg_HarmUnres.temporalPositions(end) 0 max_f_Hz]);
    title(['Unresolved - Lowest Harmonic # = ',num2str(highest_res_harm_n+1)]);
    axis('xy');colorbar; grid

end

