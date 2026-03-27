function outputArgument = deterministicExcitationZero(commandString,currentDataStructure,deterministicHandleOption)
%   outBuffer = noiseBurstInFrequency(buffer,fs,f0,stretch)

%   deterministic excitation signal generator prototype
%   Designed and coded by Hideki Kawahara
%   24/Feb./2012
%   04/Mar./2012

switch commandString
    case 'initialize'
        currentDataStructure.buffer = zeros(currentDataStructure.fftLength,1);
        fs = currentDataStructure.samplingFrequency;
        originalF0 = currentDataStructure.originalF0;
        if nargin > 2
            if isfield(deterministicHandleOption,'sourceType')
                currentDataStructure.sourceType = deterministicHandleOption.sourceType;
            else
                currentDataStructure.sourceType = 'cos';
            end;
            if isfield(deterministicHandleOption,'biasFactor')  % dpwe
                biasFactor = deterministicHandleOption.biasFactor;
            end;
        else
            currentDataStructure.sourceType = 'cos';
        end;
        temporalPositions = currentDataStructure.temporalPositions;
        timeBase = (0:1/fs:temporalPositions(end))';
        f0Interpolated = interp1(temporalPositions,originalF0,timeBase,'linear','extrap');
        integratedPhase = cumsum(f0Interpolated(:)*2*pi/fs);
        maxComponents = floor(fs/min(originalF0(originalF0>32)));
        excitationBuffer = timeBase*0;
        switch currentDataStructure.sourceType
            case 'cos'
                for ii = 1:maxComponents
                    excitationBuffer = excitationBuffer+cos(integratedPhase*ii).*(f0Interpolated*ii<fs/2);
                end;
            case 'sin'
                for ii = 1:maxComponents
                    excitationBuffer = excitationBuffer+sin(integratedPhase*ii).*(f0Interpolated*ii<fs/2);
                end;
            case 'cosPlusBias'
                for ii = 1:maxComponents
                    thisBiasFactor = biasFactor(1);
                    if length(biasFactor) > 1
                        if ii > length(biasFactor)
                            thisBiasFactor = 0;
                        else
                            thisBiasFactor = biasFactor(ii);
                        end
                    end
                    biasPhase = cumsum((f0Interpolated(:)*thisBiasFactor)*2*pi/fs); % dpwe
                    excitationBuffer = excitationBuffer+cos(integratedPhase*ii+biasPhase).* ...
                        (f0Interpolated*(ii+thisBiasFactor)<fs/2); % dpwe
                end;                
        end;
        currentDataStructure.excitationBuffer = excitationBuffer./sqrt(fs./f0Interpolated)*2; % why 2? not sqrt(2)
        outputArgument = currentDataStructure;
    case 'fetch'
        fftl = currentDataStructure.fftLength;
        currentTime = currentDataStructure.eventLocations(currentDataStructure.eventCount);
        if isfield(currentDataStructure,'frameRateInSecond')
            halfLength = round(currentDataStructure.samplingFrequency*currentDataStructure.frameRateInSecond);
        else
            halfLength = round(currentDataStructure.samplingFrequency/currentDataStructure.f0);
        end;
        w = hanning(halfLength*2+1).*currentDataStructure.excitationBuffer(...
            max(1,(-halfLength:halfLength)+round(currentTime*currentDataStructure.samplingFrequency)));
        outputArgument = currentDataStructure.buffer;
        outputArgument(fftl/2+1+(-halfLength:halfLength)) = w;
        outputArgument = 0*fft(outputArgument);
end;
return;