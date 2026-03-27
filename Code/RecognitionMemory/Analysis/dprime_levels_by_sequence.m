function dprimes = dprime_levels_by_sequence(PLACE_CODES, PASSING_DPRIME)
    
    %experiment_strings = {"NaturalSoundsFirstFixed", "NaturalSoundsSecondFixed", "NaturalSoundsRandom", "Music"};
    experiment_strings = {"NaturalSoundsRandom", "MusicFirstFixed", "MusicSecondFixed", "MusicRandom"};

    
    if nargin == 0
        PLACE_CODES = {"MAR"};
    elseif nargin == 1
        PASSING_DPRIME = 2.0;
    end
    
    file_suffix = strjoin("~/Tsimane2023/Data/RecognitionMemory/Results/*%s*v2*block*", "");
    
    all_placefiles = [];
    for code_i=1:length(PLACE_CODES)
        % get filenames for village
%         village_files = sprintf("*%s*", string(PLACE_CODES(code_i)));
%         all_filenames = dir([file_suffix village_files]);
%         disp(all_filenames);
        place_filenames = sprintf(file_suffix, string(PLACE_CODES(code_i)));
    
        place_response_files = dir(place_filenames);
        all_placefiles = [all_placefiles; place_response_files];
    end
        
    participantData   = load(all_placefiles(1).name);
    repeatPosition    = participantData.repeatPosition;
    uniquePositions = unique(repeatPosition(~isnan(repeatPosition)));       
    numPositions = length(uniquePositions);
    isis = uniquePositions -1;
    
    %dprimes = zeros(numPositions,1);
    dprimes_avg = 0;
    
    
    figure;

    disp(all_placefiles);
    
    coin_flip = 1;

    
    for block_number=1:4
        
        if block_number == 1 || block_number == 2
            dprimes = zeros(numPositions,1);
            subplot(2,1,coin_flip);
            goodParticipants = 0;
        end

        for i=1:length(all_placefiles)
            participantData   = load(all_placefiles(i).name);

            splitFName= split(all_placefiles(i).name, "_");
            fileID    = splitFName{1};

            if goodParticipantCheck(fileID, PLACE_CODES, PASSING_DPRIME) && contains(all_placefiles(i).name, sprintf("block-%d", block_number))
                containsRepeat    = participantData.containsRepeat;
                isResponseCorrect = participantData.isResponseCorrect;
                repeatPosition    = participantData.repeatPosition;
                %sequence_number   = participantData.coin_flip;
                
                %if sequence_number == coin_flip

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
        
        if block_number == 1 || block_number == 4
            dprimes = dprimes / goodParticipants;
            dprimes_avg = dprimes_avg / goodParticipants;

            dprime_plot = bar(isis, dprimes);
            dprime_plot.FaceAlpha = 0.5;
            xlabel('Interstimulus Interval (ISI)');
            ylabel("d'");
            title(sprintf("d' VS isi. Avg. d' = %f. Blocks passed: %d", dprimes_avg, goodParticipants));
            %grid on;
            xlim([min(isis) - 2, max(isis) + 2]);
            ylim([-1, 5]);

            hold off;
            coin_flip = coin_flip + 1;
        end

    end



