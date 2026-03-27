function [sh, sw, si_jitt1, si_jitt2, si_sh, sh_shu] = StraightCopy2_expmt_conds_v2_mjm01(x,fs,jitter_amts1,jitter_amts2,shift_factor,harm_shift_up_factor, plot_sg, contour, previous)
%function [sh, sw, si_jitt, si_sh, sh_shu] = StraightCopy2_expmt_conds(x,fs,jitter_amts,shift_factor,harm_shift_up_factor, plot_sg)
%   This function generates different versions of a speech utterance, to be
%   used in segregation experiments
%    x is a speech waveform at sample rate fs.
%    Use STRAIGHT to decompose into voiced and unvoiced parts, and
%    produce three new reconstructions, with a sinusoidal model of
%    the voiced portion:
%    sh is a harmonic reconstruction, intended to be very close
%      to the original.
%    sh_shu is a harmonic reconstruction whose f0 is shifted
%      up relative to that of the original
%    si_jitt and si_sh are inharmonic versions.  Each harmonic is displaced by
%      shift_factor*f0 in the shifted case, and by jitter_amts in the jittered case.
%    sw is a simulated whisper with noise replacing the voiced
%      component, and the combined result gently high-pass filtered
%      to be 3 dB down at 1600 Hz, 10 dB down at 1000 Hz, and 40 dB
%      down at 100 Hz.
%    For McDermott, Ellis & Kawahara, Interspeech 2012.
% 2012-03-30 Dan Ellis dpwe@ee.columbia.edu
% modified 2012-08-31 by Josh McDermott to do multiple variants at once
% modified 2012-10-11 by Josh McDermott to add a second jittered variant

% Modified 2016-03-28 by Malinda McPherson to add parameters for imposing
% a melody onto the speech. 

if nargin < 3
    bias = 0.1;
end

%%  After testScriptForR2.m
%   Test script for new framework
%   by Hideki Kawahara
%   26/Mar./2012

%[x,fs] = wavread('../baseTamdemSTRAIGHTV009ag3/openTheCrate.wav');

%%
r = exF0candidatesTSTRAIGHTGB(x,fs);
rc = r;
rc = autoF0Tracking(r,x);
rc.vuv = refineVoicingDecision(x,rc);
sourceStructure = aperiodicityRatioSigmoid(x,rc,1,2,0);
filterStructure = exSpectrumTSTRAIGHTGB(x,fs,sourceStructure);
%%
% Contour 

if contour == 1%Don't change contour
     input_contour = sourceStructure.f0; 
elseif contour ==2; %Flat contour;
  input_contour =repmat(mean(sourceStructure.f0), size(sourceStructure.f0));
elseif contour ==3 %Impose Melody
    n = 5; %number of notes
    contour1 = make_newmel_sour3_forspeech(n, -1, 1);
    temp1 = round(length(sourceStructure.f0)/n);
    temp2 = repmat(contour1, [temp1, 1]); 
    temp3 = reshape(temp2, temp1*n, 1);
    remainder1 = length(sourceStructure.f0) - length(temp3);
    temp3(end:end+remainder1) = temp3(end);
    input_contour = temp3;
elseif contour == 4;
    ind = length(sourceStructure.f0);
    input_contour = previous(1:ind);
end
    
%%

testSubstrate.samplingFrequency = sourceStructure.samplingFrequency;
testSubstrate.sigmoidParameter = sourceStructure.sigmoidParameter;
testSubstrate.vuv = sourceStructure.vuv;
testSubstrate.f0 = input_contour; %Change this to the F0contour
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

% Noise part only
syn_Noise = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@noiseBurstInFrequencyWhisper,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% Inharmonic - jittered
option.deterministicHandleOption.biasFactor = jitter_amts1;
syn_Inharm_jitt1 = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitationR2,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

option.deterministicHandleOption.biasFactor = jitter_amts2;
syn_Inharm_jitt2 = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitationR2,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% % Inharmonic - stretched
% if length(stretch_factor)==1
%     harm_nums = 1:15;
%     stretch_factors = harm_nums.*(harm_nums-1)*stretch_factor;
%     option.deterministicHandleOption.biasFactor = stretch_factors;
% else
%     option.deterministicHandleOption.biasFactor = stretch_factor;
% end
% syn_Inharm_stretch = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
%     @minimumPhaseResponse,@deterministicExcitationR2,@noiseBurstInFrequencyR2, ...
%     @doNothingShifter,testSubstrate,option);

% Inharmonic - shifted
if length(shift_factor)==1
    harm_nums = 1:15;
    shift_factors = ones(size(harm_nums))*shift_factor;
    option.deterministicHandleOption.biasFactor = shift_factors;
else
    option.deterministicHandleOption.biasFactor = shift_factor;
end
syn_Inharm_shift = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitationR2,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

% Harmonic - pitch shifted up
if length(harm_shift_up_factor)==1
    harm_nums = 1:60;
    shift_factors = harm_nums*harm_shift_up_factor;
    option.deterministicHandleOption.biasFactor = shift_factors;
else
    harm_nums = 1:60;
    shift_factors = harm_nums*harm_shift_up_factor(1);
    option.deterministicHandleOption.biasFactor = shift_factors;
end
syn_Harm_shift_up = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@deterministicExcitationR2,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

%% Harmonic - pitch shifted down
% if length(harm_shift_down_factor)==1
%     harm_nums = 1:60;
%     shift_factors = harm_nums*harm_shift_down_factor;
%     option.deterministicHandleOption.biasFactor = shift_factors;
% else
%     harm_nums = 1:60;
%     shift_factors = harm_nums*harm_shift_down_factor(1);
%     option.deterministicHandleOption.biasFactor = shift_factors;
% end
% syn_Harm_shift_down = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
%     @minimumPhaseResponse,@deterministicExcitationR2,@noiseBurstInFrequencyR2, ...
%     @doNothingShifter,testSubstrate,option);

% Simulated whisper
syn_Whisper = generalSTRAIGHTsynthesisFrameworkR2(@interpFetcherFixRate, ...
    @minimumPhaseResponse,@noiseBurstInFrequencyWhisper,@noiseBurstInFrequencyR2, ...
    @doNothingShifter,testSubstrate,option);

%%

if plot_sg
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
end

sh = syn_Harm.synthesisOut;
si_jitt1 = syn_Inharm_jitt1.synthesisOut;
si_jitt2 = syn_Inharm_jitt2.synthesisOut;
%si_str = syn_Inharm_stretch.synthesisOut;
si_sh = syn_Inharm_shift.synthesisOut;
sh_shu = syn_Harm_shift_up.synthesisOut;
%sh_shd = syn_Harm_shift_down.synthesisOut;
%su = syn_Noise.synthesisOut;

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
