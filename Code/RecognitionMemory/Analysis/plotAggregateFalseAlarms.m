function plotAggregateFalseAlarms(baseDir, placeCodes, condition, minISI0dprime)
% plotAggregateFalseAlarms  Aggregate false?alarm rates vs subset across filtered participants
%
%   plotAggregateFalseAlarms(baseDir, placeCodes, condition, minISI0dprime)
%
%   Inputs:
%     baseDir         ? folder containing your .mat files
%     placeCodes      ? cell array of place codes, e.g. {'BOS','CAM'} or {'ALL'}
%     condition       ? string to match in filename, e.g. 'Textures'
%     minISI0dprime   ? numeric threshold for d' at ISI=0 (filtering applied)
%
%   Saves to:
%     <baseDir>/figures/<placeTag>/<condition>/falseAlarms/
%       aggFalseAlarms_<placeTag>_<condition>.png

    % ?? 1) Get only the files passing place/condition/ISI0?d' filter ??
    files = getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime);
    if isempty(files)
        warning('No participants passed your filters?nothing to plot.');
        return
    end

    epsilon       = 0.0001;     % for correctRate capping
    nFiles        = numel(files);
    fa_wr_vec     = nan(nFiles,1);
    fa_nr_vec     = nan(nFiles,1);
    overallFA_vec = nan(nFiles,1);

    % ?? 2) Loop over each file, compute its 3 FA rates ??
    for i = 1:nFiles
        S = load(files{i}, 'repeatPosition','isResponseCorrect','stimulusPresented');
        N = numel(S.stimulusPresented(:));
        SP = string(S.stimulusPresented(:));

        % build first?presentation masks
        willRepeatFirst  = false(N,1);
        neverRepeatFirst = false(N,1);
        for id = unique(SP).'
            maskAll = SP==id;
            firstI  = find(maskAll,1,'first');
            if nnz(maskAll)>1
                willRepeatFirst(firstI) = true;
            else
                neverRepeatFirst(firstI) = true;
            end
        end

        % sanity?check
        firstTrials = isnan(S.repeatPosition);
        assert(all((willRepeatFirst|neverRepeatFirst)==firstTrials), ...
            'Mask mismatch for %s', files{i});

        % fa for will-repeat
        rawFA_wr    = sum(~S.isResponseCorrect(willRepeatFirst))  / sum(willRepeatFirst);
        fa_wr       = correctRate(rawFA_wr, epsilon);

        % fa for never-repeat
        rawFA_nr    = sum(~S.isResponseCorrect(neverRepeatFirst)) / sum(neverRepeatFirst);
        fa_nr       = correctRate(rawFA_nr, epsilon);

        % overall FA = weighted average
        Nw          = sum(willRepeatFirst);
        Nn          = sum(neverRepeatFirst);
        rawFA_all   = (fa_wr*Nw + fa_nr*Nn) / (Nw + Nn);
        fa_all      = correctRate(rawFA_all, epsilon);

        % store
        fa_wr_vec(i)     = fa_wr;
        fa_nr_vec(i)     = fa_nr;
        overallFA_vec(i) = fa_all;
    end

    % ?? 3) Compute mean & SEM across subjects ??
    mu   = [ mean(fa_wr_vec), mean(fa_nr_vec), mean(overallFA_vec) ];
    sem  = [ std(fa_wr_vec)./sqrt(nFiles), ...
             std(fa_nr_vec)./sqrt(nFiles), ...
             std(overallFA_vec)./sqrt(nFiles) ];

    % ?? 4) Plot with error bars ??
    x = 1:3;
    figure;
    bar(x, mu, 'FaceAlpha',0.8);
    hold on;
    errorbar(x, mu, sem, 'k','LineStyle','none','LineWidth',1.5);
    hold off;

    xticks(x);
    xticklabels({'FA will repeat','FA never repeat','Overall FA'});
    ylabel('False?Alarm Rate');
    ylim([0, 1]);
    title(sprintf('Aggregate FA Rates ? %s (N=%.2f)', condition, nFiles));
    grid on;
    % build place tag
    if any(strcmpi(placeCodes,'ALL'))
        placeTag = 'ALL';
    else
        placeTag = strjoin(placeCodes,'_');
    end
    

    % build and ensure directory:
    outputFolder = fullfile(baseDir, 'figures', condition);
    if ~exist(outputFolder,'dir')
        mkdir(outputFolder);
    end

    outname = sprintf('%s-%s-catchtrial-sens-%.2f.png', 'aggFalseAlarms', placeTag, minISI0dprime);
    saveas(gcf, fullfile(outputFolder, outname));
    fprintf('Saved aggregate plot to %s\n', fullfile(outputFolder, outname));
end
