function outputArgument = deterministicExcitation_w_fm(commandString,currentDataStructure,deterministicHandleOption)

%   deterministic excitation signal generator prototype
%   Designed and coded by Hideki Kawahara
%   24/Feb./2012
%   04/Mar./2012
%
%   extended by Josh McDermott
%   14/August/2014

switch commandString
    case 'initialize'
        currentDataStructure.buffer = zeros(currentDataStructure.fftLength,1);
        fs = currentDataStructure.samplingFrequency;
        originalF0 = currentDataStructure.originalF0;
        flag_utterance = 0;
        if nargin > 2
            if isfield(deterministicHandleOption,'sourceType')
                currentDataStructure.sourceType = deterministicHandleOption.sourceType;
            else
                currentDataStructure.sourceType = 'cos';
            end;
            if isfield(deterministicHandleOption,'biasFactor')  % dpwe
                biasFactor = deterministicHandleOption.biasFactor;
            else
                biasFactor = 0;
            end;
            if isfield(deterministicHandleOption,'FM_parameters')  % jhm
                FM_parameters = deterministicHandleOption.FM_parameters;
            end;
            if isfield(deterministicHandleOption,'returnFreqContours')
                currentDataStructure.returnFreqContours = deterministicHandleOption.returnFreqContours;
            else
                currentDataStructure.returnFreqContours = 0;
            end;
            if isfield(deterministicHandleOption,'criticalSpacing')
                criticalSpacing = deterministicHandleOption.criticalSpacing;
            end
        else
            currentDataStructure.sourceType = 'cos';
        end;
        temporalPositions = currentDataStructure.temporalPositions;
        timeBase = (0:1/fs:temporalPositions(end))';
        f0Interpolated = interp1(temporalPositions,originalF0,timeBase,'linear','extrap');
        mean_f0 = mean(f0Interpolated);
        if isfield(deterministicHandleOption,'vuv')
            vuvInterpolated = interp1(temporalPositions,deterministicHandleOption.vuv,timeBase,'linear','extrap');
        end
        maxComponents = floor(fs/2/min(originalF0(originalF0>32))); %jhm
        excitationBuffer = timeBase*0;
        switch currentDataStructure.sourceType
            case 'cos'
                integratedPhase = cumsum(f0Interpolated(:)*2*pi/fs);
                for ii = 1:maxComponents
                    excitationBuffer = excitationBuffer+cos(integratedPhase*ii).*(f0Interpolated*ii<fs/2);
                end;
            case 'sin'
                integratedPhase = cumsum(f0Interpolated(:)*2*pi/fs);
                for ii = 1:maxComponents
                    excitationBuffer = excitationBuffer+sin(integratedPhase*ii).*(f0Interpolated*ii<fs/2);
                end;
            case 'cosPlusBias'
                integratedPhase = cumsum(f0Interpolated(:)*2*pi/fs);
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
            case 'cosPlusBiasPlusCohFM'
                dur_ms = length(f0Interpolated)/fs*1000;
                fm_shared = pnoise(dur_ms,FM_parameters(2),FM_parameters(3),-30,0,fs)';
                fm_shared = fm_shared/rms(fm_shared)*mean_f0*FM_parameters(1); %amplitude is proportion of mean f0
                f0_contour = f0Interpolated + fm_shared;
                integratedPhase = cumsum(f0_contour(:)*2*pi/fs);
                for ii = 1:maxComponents
                    thisBiasFactor = biasFactor(1);
                    if length(biasFactor) > 1
                        if ii > length(biasFactor)
                            thisBiasFactor = 0;
                        else
                            thisBiasFactor = biasFactor(ii);
                        end
                    end
                    biasPhase = cumsum((f0_contour(:)*thisBiasFactor)*2*pi/fs);
                    excitationBuffer = excitationBuffer+cos(integratedPhase*ii+biasPhase).* ...
                        (f0_contour*(ii+thisBiasFactor)<fs/2);
                end;
                freq_contours = 0;
            case 'cosPlusBiasPlusCohFMFixedHz' %constant amplitude in Hz
                dur_ms = length(f0Interpolated)/fs*1000;
                fm_shared = pnoise(dur_ms,FM_parameters(2),FM_parameters(3),-30,0,fs)';
                fm_shared = fm_shared/rms(fm_shared)*mean_f0*FM_parameters(1); %amplitude is proportion of mean f0
                for ii = 1:maxComponents
                    thisBiasFactor = biasFactor(1);
                    if length(biasFactor) > 1
                        if ii > length(biasFactor)
                            thisBiasFactor = 0;
                        else
                            thisBiasFactor = biasFactor(ii);
                        end
                    end
                    freq_contour = f0Interpolated*(ii+thisBiasFactor) + fm_shared; %now folding bias and harmonic number into freq contour for simplicity
                    intPhase_indiv = cumsum(freq_contour(:)*2*pi/fs);
                    excitationBuffer = excitationBuffer+cos(intPhase_indiv).*(freq_contour<fs/2);
                end;
                freq_contours(:,ii) = freq_contour;
            case 'cosPlusBiasPlusIncFM'
                dur_ms = length(f0Interpolated)/fs*1000;
                for ii = 1:maxComponents
                    thisBiasFactor = biasFactor(1);
                    if length(biasFactor) > 1
                        if ii > length(biasFactor)
                            thisBiasFactor = 0;
                        else
                            thisBiasFactor = biasFactor(ii);
                        end
                    end
                    if ii==1
                        fm_indiv = pnoise(dur_ms,FM_parameters(2),FM_parameters(3),-30,0,fs)';
                        fm_indiv = fm_indiv/rms(fm_indiv)*mean_f0*FM_parameters(1);
                        freq_contour = f0Interpolated*(ii+thisBiasFactor) + fm_indiv; %now folding bias and harmonic number into freq contour for simplicity                        
                    else
                        min_freq_diff = -1; loop_n = 0;
                        while min_freq_diff < criticalSpacing
                            loop_n = loop_n+1;
                            if rem(loop_n,10000)==0
                                fprintf('Harmonic %d; starting %dth try...\n',ii,loop_n);
                            end
                            fm_indiv = pnoise(dur_ms,FM_parameters(2),FM_parameters(3),-30,0,fs)';
                            fm_indiv = fm_indiv/rms(fm_indiv)*mean_f0*FM_parameters(1);
                            freq_contour = f0Interpolated*(ii+thisBiasFactor) + fm_indiv; %now folding bias and harmonic number into freq contour for simplicity
                            freq_diff = freq_contour - previous_freq_contour;
                            min_freq_diff = min(freq_diff(vuvInterpolated==1));
                            if loop_n > 100000
                                flag_utterance = 1;
                                break
                            end
                        end
                        if loop_n>1
                            fprintf('Harmonic %d; %d loops needed.\n',ii,loop_n);
                        end
                    end
                    intPhase_indiv = cumsum(freq_contour(:)*2*pi/fs);
                    excitationBuffer = excitationBuffer+cos(intPhase_indiv).*(freq_contour<fs/2);
                    previous_freq_contour = freq_contour;
                    freq_contours(:,ii) = freq_contour;
                end;                
            case 'cosPlusBiasPlusIncFMScaled'
                dur_ms = length(f0Interpolated)/fs*1000;
                for ii = 1:maxComponents
                    thisBiasFactor = biasFactor(1);
                    if length(biasFactor) > 1
                        if ii > length(biasFactor)
                            thisBiasFactor = 0;
                        else
                            thisBiasFactor = biasFactor(ii);
                        end
                    end
                    fm_indiv = pnoise(dur_ms,FM_parameters(2),FM_parameters(3),-30,0,fs)';
                    fm_indiv = fm_indiv/rms(fm_indiv)*mean_f0*FM_parameters(1);
                    freq_contour = f0Interpolated*(ii+thisBiasFactor) + fm_indiv*ii; %now folding bias and harmonic number into freq contour for simplicity
                    intPhase_indiv = cumsum(freq_contour(:)*2*pi/fs);
                    excitationBuffer = excitationBuffer+cos(intPhase_indiv).*(freq_contour<fs/2);
                    freq_contours(:,ii) = freq_contour;
                end;                
        end;
        currentDataStructure.excitationBuffer = excitationBuffer./sqrt(fs./f0Interpolated)*2; % why 2? not sqrt(2)
        currentDataStructure.flag = flag_utterance;
        if currentDataStructure.returnFreqContours == 1
            currentDataStructure.freqContours = freq_contours;
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