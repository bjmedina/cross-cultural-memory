function dprimes = dprime_levels_analysis(block, PLACE_CODES, PASSING_DPRIME)
    
    experiment_strings = {"NaturalSoundsFirstFixed", "NaturalSoundsSecondFixed", "NaturalSoundsRandom", "Music"};
    %experiment_strings = {"NaturalSoundsRandom", "MusicFirstFixed", "MusicSecondFixed", "MusicRandom"};

    
    if nargin == 1
        PLACE_CODES = {"MAR"};
    elseif nargin == 2
        PASSING_DPRIME = 2.0;
    end
    
    file_suffix = strjoin("~/Tsimane2023/Data/RecognitionMemory/Results/*%s*v1*block-%d*", "");
    
    all_placefiles = [];
    for code_i=1:length(PLACE_CODES)
        % get filenames for village
%         village_files = sprintf("*%s*", string(PLACE_CODES(code_i)));
%         all_filenames = dir([file_suffix village_files]);
%         disp(all_filenames);
        place_filenames = sprintf(file_suffix, string(PLACE_CODES(code_i)), block);
    
        place_response_files = dir(place_filenames);
        all_placefiles = [all_placefiles; place_response_files];
    end
        
    participantData   = load(all_placefiles(1).name);
    repeatPosition    = participantData.repeatPosition;
    uniquePositions = unique(repeatPosition(~isnan(repeatPosition)));       
    numPositions = length(uniquePositions);
    isis = uniquePositions -1;
    
    dprimes = zeros(numPositions,1);
    dprimes_avg = 0;
    
    goodParticipants = 0;
    
    figure;

    disp(all_placefiles);
    
    for i=1:length(all_placefiles)
        participantData   = load(all_placefiles(i).name);
        
        splitFName= split(all_placefiles(i).name, "_");
        fileID    = splitFName{1};
        
        if goodParticipantCheck(fileID, PLACE_CODES, PASSING_DPRIME)
            containsRepeat    = participantData.containsRepeat;
            isResponseCorrect = participantData.isResponseCorrect;
            repeatPosition    = participantData.repeatPosition;

            overallHitRate = sum(isResponseCorrect & containsRepeat) / sum(containsRepeat);
            overallFalseAlarmRate = sum(~isResponseCorrect & ~containsRepeat) / sum(~containsRepeat);

            % Small ass number
            epsilon = 0.01;

            % correcting the different rates (cant be arbitrarily close to 
            % 0 or 1)
            overallHitRate = correctRate(overallHitRate, epsilon);
            overallFalseAlarmRate = correctRate(overallFalseAlarmRate, epsilon);

            % figure out the set of ISIs used in the experiment
            uniquePositions = unique(repeatPosition(~isnan(repeatPosition)));
            numPositions = length(uniquePositions);
            hitRateByPosition = zeros(numPositions, 1);

            for j = 1:numPositions
                position = uniquePositions(j);
                hitRateByPosition(j) = sum(isResponseCorrect(repeatPosition == position)) / sum(repeatPosition == position);
                %falseAlarmRateByPosition(i) = sum(~isResponseCorrect(repeatPosition ~= position)) / overallFalseAlarmRate;

                % We don't want nans or infs in d' (which happens if the hit rate is 1 or 0).
                % So let's cap the hit rate to be 0.99 if too high and 0 if too low.
                hitRateByPosition(j) = correctRate(hitRateByPosition(j), epsilon);
            end

            % Calculate z-scores for the overall experiment
            zHitOverall = norminv(overallHitRate);
            zFalseAlarmOverall = norminv(overallFalseAlarmRate);

            % Calculate z-scores for each unique position of the repeat
            zHitByPosition = norminv(hitRateByPosition);
            %zFalseAlarmByPosition = norminv(falseAlarmRateByPosition);
            zFalseAlarmByPosition = norminv(zeros(numPositions,1) + overallFalseAlarmRate);

            % Compute d' for the overall experiment and each unique position of the repeat
            dprimeOverall = zHitOverall - zFalseAlarmOverall;


            dprimeByPosition = zHitByPosition - zFalseAlarmByPosition;
            %if dprimeByPosition(1) > PASSING_DPRIME
            dprimes_avg = dprimes_avg + dprimeOverall;

            goodParticipants = goodParticipants + 1;
            dprimes = dprimes + dprimeByPosition;

            hold on;
            plot(isis, dprimeByPosition);
            %end
        end
        
    end
    
    dprimes = dprimes /goodParticipants;
    dprimes_avg = dprimes_avg / goodParticipants;
 
    dprime_plot = bar(isis, dprimes);
    dprime_plot.FaceAlpha = 0.5;
    xlabel('Interstimulus Interval (ISI)');
    ylabel("d'");
    title(sprintf("%s: d' VS isi. Avg. d' = %f. Blocks passed: %d", string(experiment_strings(block)), dprimes_avg, goodParticipants));
    %grid on;
    xlim([min(isis) - 2, max(isis) + 2]);
    ylim([-1, 5]);

    hold off;



