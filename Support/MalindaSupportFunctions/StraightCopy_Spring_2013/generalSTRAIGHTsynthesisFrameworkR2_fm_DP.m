function synthOutStructure = generalSTRAIGHTsynthesisFrameworkR2_fm_DP(...
    feedingHandle,responseHandle,deterministicHandle,randomHandle,shifterHandle,dataSubstrate,optionalParameters)
%   synthOutStructure = generalSTRAIGHTsynthesisFrameworkR2_fm(...
%    feedingHandle,responseHandle,deterministicHandle,randomHandle,shifterHandle,dataSubstrate)

%   generalized synthesis routine for TANDEM-STRAIGHT manipulation
%   Designed and coded by Hideki Kawahara
%   21/Feb./2012
%   25/Feb./2012 first release
%   04/Mar./2012 more generalization
%   25/Mar./2012 further generalization
%
%   Aug 22 2014 - modified by Josh McDermott to return frequency contours
%   for FM stimuli
%   22/Aug/2014 -- modified to separately synthesize periodic and aperiodic
%   components

%startTime = tic;
synthOutStructure = [];
if isempty(feedingHandle)
    disp('input argument is empty!');
    return;
end;
if nargin == 7
    if isfield(optionalParameters,'deterministicHandleOption')
        deterministicHandleOption = optionalParameters.deterministicHandleOption;
    end;
    if isfield(optionalParameters,'randomHandleOption')
        randomHandleOption = optionalParameters.randomHandleOption;
    end;
    if isfield(optionalParameters,'feedingHandleOption')
        feedingHandleOption = optionalParameters.feedingHandleOption;
    end;
end;
%------------------------------------
fs = dataSubstrate.samplingFrequency;
if exist('feedingHandleOption','var')
    currentDataStructure = feedingHandle('initialize',dataSubstrate,[],feedingHandleOption);
else
    currentDataStructure = feedingHandle('initialize',dataSubstrate);
end;
eventLocations = currentDataStructure.eventLocations;
fftl = currentDataStructure.fftLength;
if exist('deterministicHandleOption','var')
    currentDataStructure = deterministicHandle('initialize',currentDataStructure,deterministicHandleOption);
else
    currentDataStructure = deterministicHandle('initialize',currentDataStructure);
end;
if exist('randomHandleOption','var')
    currentDataStructure = randomHandle('initialize',currentDataStructure,randomHandleOption);
else
    currentDataStructure = randomHandle('initialize',currentDataStructure);
end;
outBuffer = zeros(round(fs*eventLocations(end)),1);
%blankBuffer = zeros(fftl,1);
baseShifter = shifterHandle(dataSubstrate);
baseIndex = (1:fftl)'-fftl/2;
maxIndex = size(outBuffer,1);
for ii = 1:length(eventLocations)
    dataSubstrate.currentLocation = eventLocations(ii);
    currentDataStructure = feedingHandle('fetch',dataSubstrate,currentDataStructure);
    %sourceOption = currentDataStructure.sourceOption;
    currentIndex = floor(eventLocations(ii)*fs+1);
    fractionalIndex = eventLocations(ii)*fs+1-currentIndex;
    copyIndex = max(1,min(maxIndex,baseIndex+currentIndex));
    %f0 = currentDataStructure.f0;
    if currentDataStructure.vuv > 0.3
        randomCoeff = currentDataStructure.randomComponent;
        periodCoeff = sqrt(1-randomCoeff.^2);
        responseInFrequencyD = responseHandle(currentDataStructure.spectrum.*periodCoeff.^2);
        responseInFrequencyR = responseHandle(currentDataStructure.spectrum.*randomCoeff.^2);
        response = real(ifft(responseInFrequencyD.*deterministicHandle('fetch',currentDataStructure).*exp(-1i*baseShifter*fractionalIndex)));
        responseAP = real(ifft(responseInFrequencyR.*randomHandle('fetch',currentDataStructure)));
        %outBuffer(copyIndex) = outBuffer(copyIndex)+response+responseAP;
        outBuffer(copyIndex) = outBuffer(copyIndex)+response;
    else
        responseInFrequencyD = minimumPhaseResponse(currentDataStructure.spectrum);
        response = real(ifft(responseInFrequencyD.*randomHandle('fetch',currentDataStructure)));
        %outBuffer(copyIndex) = outBuffer(copyIndex)+response;
    end;
end;
synthOutStructure.synthesisOut = outBuffer;
synthOutStructure.flag = currentDataStructure.flag;
if deterministicHandleOption.returnFreqContours == 1
    synthOutStructure.freqContours = currentDataStructure.freqContours;
end
%synthOutStructure.elapsedTime = toc(startTime);
return;