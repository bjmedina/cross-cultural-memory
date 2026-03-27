function plotAggregateHitRate(baseDir, placeCodes, condition, minISI0dprime)
% plotAggregateHitRate  Aggregate hit rate vs ISI across filtered participants
%
%   plotAggregateHitRate(baseDir, placeCodes, condition, minISI0dprime)
%
%   Inputs:
%     baseDir         ? folder containing your .mat files
%     placeCodes      ? cell array of place codes, e.g. {'BOS','CAM'} or {'ALL'}
%     condition       ? string to match in filename, e.g. 'Textures'
%     minISI0dprime   ? numeric threshold for d' at ISI=0
%
%   Saves to:
%     <baseDir>/figures/<placeTag>/<condition>/
%       aggHitRate_catchtrial-sens-<minISI0dprime>.png

    % 1) find & filter files by place/condition/ISI0-d'
    files = getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime);
    if isempty(files)
        warning('No participants passed your filters?nothing to plot.');
        return
    end

    epsilon       = 0.0001;   % for correctRate capping
    subjPos       = {};     % per-subject unique repeatPositions
    subjHitRates  = {};     % per-subject hit-rate vectors
    allPos        = [];

    % 2) compute per-subject hit-rate curves
    for i = 1:numel(files)
        S = load(files{i}, 'repeatPosition','isResponseCorrect');

        % which trials are repeats (non-NaN repeatPosition)
        rt = ~isnan(S.repeatPosition);
        upr = unique(S.repeatPosition(rt));
        if isempty(upr)
            continue
        end

        % compute hit rate at each repeat-position
        hitByPos = zeros(numel(upr),1);
        for j = 1:numel(upr)
            idx = S.repeatPosition == upr(j);
            hr  = sum(S.isResponseCorrect(idx)) / sum(idx);
            hitByPos(j) = correctRate(hr, epsilon);
        end

        subjPos{end+1}      = upr;       %#ok<AGROW>
        subjHitRates{end+1} = hitByPos;  %#ok<AGROW>
        allPos              = union(allPos, upr);
    end

    if isempty(allPos)
        warning('No valid repeatPositions found.');
        return
    end

    % 3) align into matrix [nSub × nPos]
    nSub = numel(subjHitRates);
    nPos = numel(allPos);
    M    = nan(nSub, nPos);

    for i = 1:nSub
        for j = 1:numel(subjPos{i})
            col = find(allPos == subjPos{i}(j), 1);
            M(i,col) = subjHitRates{i}(j);
        end
    end

    % 4) compute mean & SEM
    muHit  = nanmean(M,1);
    semHit = nanstd(M,0,1) ./ sqrt(sum(~isnan(M),1));

    % convert repeatPosition ? ISI
    ISI = allPos - 1;

    % 5) plot
    figure;
    errorbar(ISI, muHit, semHit, 'o-','LineWidth',2);
    xlabel('Interstimulus Interval (ms)');
    ylabel('Mean Hit Rate');
    title(sprintf('Aggregate Hit Rate vs ISI ? %s (N=%.2f)', condition, nSub));
    grid on;
    ylim([0 1]);  % always start at 0, cap at 1
    if numel(ISI) > 1
        xlim([min(ISI)-1, max(ISI)+1]);
    end

    % 6) save under baseDir/figures/<condition>/
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

    outname = sprintf('%s-%s-catchtrial-sens-%.2f.png', 'aggHitRate', placeTag, minISI0dprime);
    saveas(gcf, fullfile(outputFolder, outname));
    fprintf('Saved aggregate plot to %s\n', fullfile(outputFolder, outname));
end
