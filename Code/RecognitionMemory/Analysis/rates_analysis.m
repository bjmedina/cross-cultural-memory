function [fa_rates, hit_rates] = rates_analysis(block, PLACE_CODES)
    PASSING_DPRIME = 3.5;
    experiment_strings = {"NaturalSoundsFirstFixed", "NaturalSoundsSecondFixed", "NaturalSoundsRandom", "Music"};


    if nargin == 1
        PLACE_CODES = {"MAR"};
    end

    file_suffix = strjoin("~/Tsimane2023/Data/RecognitionMemory/Results/*%s*block-%d*", "");

    all_placefiles = [];
    for code_i=1:length(PLACE_CODES)
        % get filenames for village
    %         village_files = sprintf("*%s*", string(PLACE_CODES(code_i)));
    %         all_filenames = dir([file_suffix village_files]);
    %         disp(all_filenames);
        place_filenames = sprintf(file_suffix, string(PLACE_CODES(code_i)), block);        
    end

    place_response_files = dir(place_filenames);
    disp(place_response_files)

    %dprimes = cell(4,1);

    participantData   = load(place_response_files(1).name);
    repeatPosition    = participantData.repeatPosition;
    uniquePositions = unique(repeatPosition(~isnan(repeatPosition)));       
    numPositions = length(uniquePositions);
    isis = uniquePositions - 1;


    hit_rates = zeros(numPositions,1);
    hit_rates_avg = 0;
    fa_avg = 0;

    goodParticipants = 0;

    for i=1:length(place_response_files)
        participantData   = load(place_response_files(i).name);
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
        dprimeByPosition = zHitByPosition - zFalseAlarmByPosition;
        if dprimeByPosition(1) > PASSING_DPRIME
            hit_rates_avg = hit_rates_avg + overallHitRate;
            fa_avg = fa_avg + overallFalseAlarmRate;

            goodParticipants = goodParticipants + 1;
            hit_rates = hit_rates + hitRateByPosition;

            hold on;
            plot(isis, hitRateByPosition);
        end

    end

    hit_rates = hit_rates /goodParticipants;
    hit_rates_avg = hit_rates_avg / goodParticipants;

    fa_avg = fa_avg / goodParticipants;

    hitrate_plot = bar(isis, hit_rates);
    hitrate_plot.FaceAlpha = 0.5;
    xlabel('Hit Rate');
    ylabel("d'");
    title1 = sprintf("%s: Hit Rate' VS ISI. Avg. hit rate' = %f. Blocks passed: %d", string(experiment_strings(block)), hit_rates_avg, goodParticipants);
    title();
    %grid on;
    xlim([min(isis) - 2, max(isis) + 2]);
    hold off;
    
    hold on;

    fa_rates = ones(goodParticipants, 1);
    hit_rates = ones(goodParticipants, 1);

    goodParticipants = 1;

    figure;
    title2 = sprintf("%s: Average hit rate and FA rate", string(experiment_strings(block)));
    %title();


    for i=1:length(place_response_files)
        participantData   = load(place_response_files(i).name);
        containsRepeat    = participantData.containsRepeat;
        isResponseCorrect = participantData.isResponseCorrect;

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
        dprimeByPosition = zHitByPosition - zFalseAlarmByPosition;
        if dprimeByPosition(1) > PASSING_DPRIME
            fa_rates(goodParticipants)  = fa_rates(goodParticipants) * overallFalseAlarmRate;
            hit_rates(goodParticipants) = hit_rates(goodParticipants) * overallHitRate;
            goodParticipants = goodParticipants + 1;
        end

    end
    
    errorbar(mean(hit_rates), std(hit_rates)./sqrt(length(hit_rates)), '.k')
    hold on;
    errorbar(mean(fa_rates), std(fa_rates)./sqrt(length(fa_rates)), '.g')
    legend({'hit rates','fa rates'})
    ylim([0, 1]);

    hold off;
