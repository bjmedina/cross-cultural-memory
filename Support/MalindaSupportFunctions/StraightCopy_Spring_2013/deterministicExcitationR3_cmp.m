function outputArgument = deterministicExcitationR3(commandString,currentDataStructure,deterministicHandleOption)
%   outBuffer = noiseBurstInFrequency(buffer,fs,f0,stretch)

%   deterministic excitation signal generator prototype
%   Designed and coded by Hideki Kawahara
%   24/Feb./2012
%   04/Mar./2012
%
%   extended by Josh McDermott to implement compressed harmonics
%   -sets max_harmonics based on specified component frequencies, not
%   harmonic frequencies
%   7/Aug./2013

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
                freq_ratios = biasFactor + [1:length(biasFactor)];
                maxComponents = max(find((min(originalF0(originalF0>32))*freq_ratios) < fs/2)); %jhm
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
            case 'cosLogSpaced' %biasFactor is the ratio between successive components
                thisBiasFactor = biasFactor(1);
                downShift = 4; %set frequency of first "harmonic" to be 1/4 * F0 of original
                minF0 = min(originalF0(originalF0>32))/downShift; 
                maxComponents = floor(log2(fs/2/minF0)/log2(thisBiasFactor));
                for ii = 1:maxComponents
                    excitationBuffer = excitationBuffer+cos(integratedPhase/downShift*thisBiasFactor^ii).* ...
                        (f0Interpolated/downShift*thisBiasFactor^ii<fs/2); % dpwe
                end;
            case 'cosOddOnly'
                for ii = 1:2:maxComponents
                    excitationBuffer = excitationBuffer+cos(integratedPhase*ii).*(f0Interpolated*ii<fs/2);
                end;
            case 'cosLowF0' %lower F0 by some factor
                downShift = biasFactor;
                minF0 = min(originalF0(originalF0>32))/downShift; 
                maxComponents = floor(fs/2/minF0);
                for ii = 1:maxComponents
                    excitationBuffer = excitationBuffer+cos(integratedPhase/downShift*ii).*(f0Interpolated/downShift*ii<fs/2);
                end;
            case 'cosUnres' %lower F0 by specified amount; include only upper harmonics
                downShift = biasFactor(2);
                lowest_harmonic = biasFactor(1);
                minF0 = min(originalF0(originalF0>32))/downShift; 
                maxComponents = floor(fs/2/minF0);
                for ii = lowest_harmonic:maxComponents
                    excitationBuffer = excitationBuffer+cos(integratedPhase/downShift*ii).*(f0Interpolated/downShift*ii<fs/2);
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
            min(length(currentDataStructure.excitationBuffer),...
                max(1,(-halfLength:halfLength)+round(currentTime*currentDataStructure.samplingFrequency))));
        outputArgument = currentDataStructure.buffer;
        outputArgument(fftl/2+1+(-halfLength:halfLength)) = w;
        outputArgument = fft(outputArgument);
end;
return;