function plotStimulusTypeHitRates(baseDir, placeCodes, condition, minISI0dprime)
% plotStimulusTypeHitRates  Aggregate hit rate at nonzero ISI by stimulus type
%
%   plotStimulusTypeHitRates(baseDir, placeCodes, condition, minISI0dprime)
%
%   Inputs:
%     baseDir         ? folder with your .mat files
%     placeCodes      ? cell array of place codes, e.g. {'BOS','CAM'} or {'ALL'}
%     condition       ? string to match in filename, e.g. 'Industrial-Nature'
%     minISI0dprime   ? threshold for d' at ISI=0 (filters participants)
%
%   Saves to:
%     <baseDir>/figures/<placeTag>/<condition>/stimulusTypeHitRate/
%       aggStimulusTypeHitRate_<placeTag>_<condition>.png

    % 1) get filtered files
    files = getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime);
    if isempty(files)
        warning('No participants passed your filters?nothing to plot.');
        return
    end

    epsilon = 0.0001;
    allTypes = string([]);

    % First pass: collect the union of all stimulus types
    for i = 1:numel(files)
        S = load(files{i}, 'repeatPosition','stimuli_type');
        rp      = S.repeatPosition; %repeat position -> index of repeat in seq
        stype   = string(S.stimuli_type(:));
        valid   = ~isnan(rp) & (rp>0);                % nonzero-ISI trials only
        types_i = unique(stype(valid));
        allTypes = union(allTypes, types_i);
    end

    if isempty(allTypes)
        warning('No stimulus types found across participants.');
        return
    end

    % 2) build an Nsubjects by Ntypes matrix of hit?rates
    nSub   = numel(files);
    nTypes = numel(allTypes);
    M      = nan(nSub, nTypes);

    for i = 1:nSub
        S     = load(files{i}, 'repeatPosition','isResponseCorrect','stimuli_type');
        rp    = S.repeatPosition;
        corr  = S.isResponseCorrect;
        stype = string(S.stimuli_type(:));

        valid = ~isnan(rp) & (rp>0);

        for t = 1:nTypes
            thisType = allTypes(t);
            maskType = valid & (stype==thisType);
            ntrials  = sum(maskType);
            if ntrials>0
                hr_raw = sum(corr(maskType)) / ntrials;
                M(i,t) = correctRate(hr_raw, epsilon);
            end
        end
    end

    % 3) aggregate mean & SEM
    mu   = nanmean(M,1);
    sem  = nanstd(M,0,1) ./ sqrt(sum(~isnan(M),1));
    ISI  = 1;  % irrelevant here - just categories

    % 4) plot
    figure;
    x = 1:nTypes;
    bar(x, mu, 'FaceAlpha',0.8); hold on;
    errorbar(x, mu, sem, 'k','LineStyle','none','LineWidth',1.5);
    hold off;
    xticks(x);
    xticklabels(allTypes);
    xlabel('Stimulus Type');
    ylabel('Hit Rate (nonzero ISI)');
    title(sprintf('Hit Rate by Stimulus Type ? %s (N=%.2f)', condition, nSub));
    ylim([0,1]);
    grid on;

    % 5) save into <baseDir>/figures/<condition>/stimulusTypeHitRate/

    if any(strcmpi(placeCodes,'ALL')), placeTag='ALL';
    else placeTag = strjoin(placeCodes,'_'); end

    outDir = fullfile(baseDir,'figures',condition);
    if ~exist(outDir,'dir'), mkdir(outDir); end

    fname = sprintf('%s-%s-catchtrial-sens-%.2f.png','aggStimulusTypeHitRate', placeTag, minISI0dprime);
    saveas(gcf, fullfile(outDir, fname));
    fprintf('Saved plot to %s\n', fullfile(outDir,fname));
end
