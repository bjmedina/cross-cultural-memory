function outputArgument = deterministicExcitation_harm_variants(commandString,currentDataStructure,deterministicHandleOption)
%   outBuffer = noiseBurstInFrequency(buffer,fs,f0,stretch)

%   deterministic excitation signal generator prototype
%   Designed and coded by Hideki Kawahara
%   24/Feb./2012
%   04/Mar./2012
%
%   extended by Josh McDermott
%   25/July/2013
%
%   updated 14/Aug/2014 by Josh McDermott

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
        maxComponents = floor(fs/2/min(originalF0(originalF0>32))); %jhm

        f0Interpolated_low = interp1(temporalPositions,originalF0/2,timeBase,'linear','extrap');
        integratedPhase_low = cumsum(f0Interpolated_low(:)*2*pi/fs);
        maxComponents_low = floor(fs/2/min(originalF0((originalF0/2)>32)/2)); %jhm
        
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
            case 'cosOddOnly'
                for ii = 1:2:maxComponents
                    excitationBuffer = excitationBuffer+cos(integratedPhase*ii).*(f0Interpolated*ii<fs/2);
                end;
            case 'cosOddLow'
                for ii = 1:2:maxComponents_low
                    excitationBuffer = excitationBuffer+cos(integratedPhase_low*ii).*(f0Interpolated_low*ii<fs/2);
                end;
            case 'cosEvenOnly'
                for ii = 2:2:maxComponents
                    excitationBuffer = excitationBuffer+cos(integratedPhase*ii).*(f0Interpolated*ii<fs/2);
                end;
            case 'cosThirdOnly'
                for ii = 3:3:maxComponents
                    excitationBuffer = excitationBuffer+cos(integratedPhase*ii).*(f0Interpolated*ii<fs/2);
                end;
            case 'cosMissingThird'
                harms = [1:maxComponents];
                harms = setdiff(harms,[3:3:maxComponents]);
                for ii = harms
                    excitationBuffer = excitationBuffer+cos(integratedPhase*ii).*(f0Interpolated*ii<fs/2);
                end;
        end;
        if strcmp(currentDataStructure.sourceType, 'CosOddLow')
            currentDataStructure.excitationBuffer = excitationBuffer./sqrt(fs./f0Interpolated_low)*2; % why 2? not sqrt(2)            
        else
            currentDataStructure.excitationBuffer = excitationBuffer./sqrt(fs./f0Interpolated)*2; % why 2? not sqrt(2)
        end
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
            min(length(currentDataStructure.excitationBuffer),...
                max(1,(-halfLength:halfLength)+round(currentTime*currentDataStructure.samplingFrequency))));
        outputArgument = currentDataStructure.buffer;
        outputArgument(fftl/2+1+(-halfLength:halfLength)) = w;
        outputArgument = fft(outputArgument);
end;
return;