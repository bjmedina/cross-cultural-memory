function [sh, si_jitt, sh_fm, sh_fm_fixed, sh_ifm, sh_ifm_scaled, si_jitt_fm, si_jitt_fm_fixed, si_jitt_ifm, si_jitt_ifm_scaled, utterance_flag] = ...
    StraightCopy2_harm_jitt_fm(x,fs,jitter_amts,fm_amp,fm_cutoffs,critical_spacing,plot_sg)
%FUNCTION [sh, si_jitt, sh_fm, sh_fm_fixed, sh_ifm, sh_ifm_scaled, si_jitt_fm, si_jitt_fm_fixed, si_jitt_ifm, si_jitt_ifm_scaled] = ...
%    StraightCopy2_harm_jitt_fm(x,fs,jitter_amts,fm_amp,fm_cutoffs,critical_spacing,plot_sg)
%
%   This function generates different versions of a speech utterance, to be
%   used in segregation experiments
%    X is a speech waveform at sample rate FS.
%
%    Use STRAIGHT to decompose into voiced and unvoiced parts, and
%    produce three new reconstructions, with a sinusoidal model of
%    the voiced portion:
%    SH is a harmonic reconstruction, intended to be very close
%      to the original.
%    SI_JITT is an inharmonic versions.  Each harmonic is displaced by
%      jitter_amts.
%    SH_FM has random frequency modulation added to the f0 contour.
%    SH_FM_FIXED has random frequency modulation (fixed amplitude in Hz) added to each harmonic's contour.
%    SH_IFM has incoherent random frequency modulation added to each
%    harmonic's contour (fixed amplitude in Hz).
%    SH_IFM_SCALED has incoherent random frequency modulation added to each
%    harmonic's contour, with the amplitude scaled by the harmonic number.
%    SI_JITT_FM has random (coherent) frequency modulation added to each
%    component's contour, with amplitude proportional to the harmonic number.
%    SI_JITT_FM_FIXED has random (coherent) frequency modulation added to each
%    component's contour, fixed in Hz.
%    SI_JITT_IFM has random incoherent frequency modulation added to each
%    component's contour (fixed amplitude in Hz).
%    SI_JITT_IFM_SCALED has random incoherent frequency modulation added to each
%    component's contour, with amplitude proportional to the harmonic number.
%
%    Separately generates noise component to ensure that it is identical
%    across all variants.
%
%   Flags utterances for which the frequency contours do not respect the
%   critical spacing.
%
%  2014-8-22 -- Josh McDermott <jhm@mit.edu>

if nargin < 3
    bias = 0.1;
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

option.deterministicHandleOption.biasFactor = 0;
option.feedingHandleOption.frameRateInSecond = 0.005;
option.deterministicHandleOption.sourceType = 'cosPlusBias';
option.deterministicHandleOption.returnFreqContours = 0;

%first, make noise component
syn_common_AP = generalSTRAIGHTsynthesisFrameworkR2AP(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_harm_variants,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% Regular resynthesis
syn_Harm = generalSTRAIGHTsynthesisFrameworkR2_fm_DP(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_w_fm,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% Inharmonic - jittered
option.deterministicHandleOption.biasFactor = jitter_amts;
syn_Inharm_jitt = generalSTRAIGHTsynthesisFrameworkR2_fm_DP(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_w_fm,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

option.deterministicHandleOption.sourceType = 'cosPlusBiasPlusCohFM';
option.deterministicHandleOption.FM_parameters = [fm_amp fm_cutoffs];
option.deterministicHandleOption.returnFreqContours = 0;
% Harmonic - coherent FM
option.deterministicHandleOption.biasFactor = 0;
syn_Harm_CohFM = generalSTRAIGHTsynthesisFrameworkR2_fm_DP(@interpFetcherFixRate, ... %use R2_fm here and below to get freq_contours back
    @minimumPhaseResponse,@deterministicExcitation_w_fm,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% Inharmonic - coherent FM
option.deterministicHandleOption.biasFactor = jitter_amts;
syn_Inharm_CohFM = generalSTRAIGHTsynthesisFrameworkR2_fm_DP(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_w_fm,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

option.deterministicHandleOption.sourceType = 'cosPlusBiasPlusCohFMFixedHz';
option.deterministicHandleOption.FM_parameters = [fm_amp fm_cutoffs];
option.deterministicHandleOption.returnFreqContours = 1;
% Harmonic - coherent FM, fixed in Hz
option.deterministicHandleOption.biasFactor = 0;
syn_Harm_CohFMFixedHz = generalSTRAIGHTsynthesisFrameworkR2_fm_DP(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_w_fm,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% Inharmonic - coherent FM, fixed in Hz
option.deterministicHandleOption.biasFactor = jitter_amts;
syn_Inharm_CohFMFixedHz = generalSTRAIGHTsynthesisFrameworkR2_fm_DP(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_w_fm,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

option.deterministicHandleOption.sourceType = 'cosPlusBiasPlusIncFM';
option.deterministicHandleOption.criticalSpacing = critical_spacing;
option.deterministicHandleOption.vuv = sourceStructure.vuv;
% Harmonic - incoherent FM
option.deterministicHandleOption.biasFactor = 0;
syn_Harm_IncFM = generalSTRAIGHTsynthesisFrameworkR2_fm_DP(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_w_fm,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% Inharmonic - incoherent FM
option.deterministicHandleOption.biasFactor = jitter_amts;
syn_Inharm_IncFM = generalSTRAIGHTsynthesisFrameworkR2_fm_DP(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_w_fm,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);


option.deterministicHandleOption.sourceType = 'cosPlusBiasPlusIncFMScaled';
% Harmonic - incoherent FM, scaled with harmonic number
option.deterministicHandleOption.biasFactor = 0;
syn_Harm_IncFMScaled = generalSTRAIGHTsynthesisFrameworkR2_fm_DP(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_w_fm,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% Inharmonic - incoherent FM, scaled with harmonic number
option.deterministicHandleOption.biasFactor = jitter_amts;
syn_Inharm_IncFMScaled = generalSTRAIGHTsynthesisFrameworkR2_fm_DP(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitation_w_fm,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);


%%

sh = syn_Harm.synthesisOut + syn_common_AP.synthesisOut;
sh_fm = syn_Harm_CohFM.synthesisOut + syn_common_AP.synthesisOut;
sh_fm_fixed = syn_Harm_CohFMFixedHz.synthesisOut + syn_common_AP.synthesisOut;
sh_ifm = syn_Harm_IncFM.synthesisOut + syn_common_AP.synthesisOut;
sh_ifm_scaled = syn_Harm_IncFMScaled.synthesisOut + syn_common_AP.synthesisOut;
si_jitt = syn_Inharm_jitt.synthesisOut + syn_common_AP.synthesisOut;
si_jitt_fm = syn_Inharm_CohFM.synthesisOut + syn_common_AP.synthesisOut;
si_jitt_fm_fixed = syn_Inharm_CohFMFixedHz.synthesisOut + syn_common_AP.synthesisOut;
si_jitt_ifm = syn_Inharm_IncFM.synthesisOut + syn_common_AP.synthesisOut;
si_jitt_ifm_scaled = syn_Inharm_IncFMScaled.synthesisOut + syn_common_AP.synthesisOut;

utterance_flag = max([syn_Inharm_IncFM.flag syn_Harm_IncFM.flag]);

% timeBase = (0:1/sourceStructure.samplingFrequency:sourceStructure.temporalPositions(end))';
% vuvInterpolated = interp1(sourceStructure.temporalPositions,sourceStructure.vuv,timeBase,'linear','extrap');
% 
% sh_ifm_freq_contours = syn_Harm_IncFM.freqContours(find(vuvInterpolated),:);
% si_ifm_freq_contours = syn_Inharm_IncFM.freqContours(find(vuvInterpolated),:);
% sh_ifm_fixed_freq_contours = syn_Harm_CohFMFixedHz.freqContours(find(vuvInterpolated),:);
% si_ifm_fixed_freq_contours = syn_Inharm_CohFMFixedHz.freqContours(find(vuvInterpolated),:);
% 
% sh_ifm_freq_diffs = sh_ifm_freq_contours(:,2:end)-sh_ifm_freq_contours(:,1:end-1);
% si_ifm_freq_diffs = si_ifm_freq_contours(:,2:end)-si_ifm_freq_contours(:,1:end-1);

% figure(1);
% subplot(2,1,1);
% hist(sh_ifm_freq_diffs(:),[0:10:400]);
% set(gca,'XLim',[0 300]);title('Harmonic')
% subplot(2,1,2);
% hist(si_ifm_freq_diffs(:),[0:10:400]);
% set(gca,'XLim',[0 300]);title('Inharmonic');
% xlabel('Difference between Adjacent Component Frequencies (Hz)');


if plot_sg

    max_f_Hz = 4000;
    sg_Harm = stftSpectrogramStructure(sh,fs,80,1,'nuttallwin12');
    sg_Jitt = stftSpectrogramStructure(si_jitt,fs,80,1,'nuttallwin12');
    sg_Harm_FM = stftSpectrogramStructure(sh_fm,fs,80,1,'nuttallwin12');
    sg_Jitt_FM = stftSpectrogramStructure(si_jitt_fm,fs,80,1,'nuttallwin12');
    sg_Harm_iFM = stftSpectrogramStructure(sh_ifm,fs,80,1,'nuttallwin12');
    sg_Jitt_iFM = stftSpectrogramStructure(si_jitt_ifm,fs,80,1,'nuttallwin12');
    
    %figure;
    subplot(321);
    imagesc([0 sg_Harm.temporalPositions(end)],[0 fs/2],max(-90,sg_Harm.dBspectrogram));
    axis([0 sg_Harm.temporalPositions(end) 0 max_f_Hz]);
    title('Harmonic');
    axis('xy');colorbar; grid
    
    subplot(322);
    imagesc([0 sg_Jitt.temporalPositions(end)],[0 fs/2],max(-90,sg_Jitt.dBspectrogram));
    axis([0 sg_Jitt.temporalPositions(end) 0 max_f_Hz]);
    title('Inharmonic');
    axis('xy');colorbar; grid

    subplot(323);
    imagesc([0 sg_Harm_FM.temporalPositions(end)],[0 fs/2],max(-90,sg_Harm_FM.dBspectrogram));
    axis([0 sg_Harm_FM.temporalPositions(end) 0 max_f_Hz]);
    title('Harmonic - Coherent FM');
    axis('xy');colorbar; grid
    
    subplot(324);
    imagesc([0 sg_Jitt_FM.temporalPositions(end)],[0 fs/2],max(-90,sg_Jitt_FM.dBspectrogram));
    axis([0 sg_Jitt_FM.temporalPositions(end) 0 max_f_Hz]);
    title(['Jittered - Coherent FM']);
    axis('xy');colorbar; grid

    subplot(325);
    imagesc([0 sg_Harm_iFM.temporalPositions(end)],[0 fs/2],max(-90,sg_Harm_iFM.dBspectrogram));
    axis([0 sg_Harm_iFM.temporalPositions(end) 0 max_f_Hz]);
    title('Harmonic - Incoherent FM');
    axis('xy');colorbar; grid
    
    subplot(326);
    imagesc([0 sg_Jitt_iFM.temporalPositions(end)],[0 fs/2],max(-90,sg_Jitt_iFM.dBspectrogram));
    axis([0 sg_Jitt_iFM.temporalPositions(end) 0 max_f_Hz]);
    title(['Jittered - Incoherent FM']);
    axis('xy');colorbar; grid
end

