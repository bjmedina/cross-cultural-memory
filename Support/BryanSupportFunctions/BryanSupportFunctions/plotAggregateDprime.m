function plotAggregateDprime(baseDir, placeCodes, condition, minISI0dprime)
% plotAggregateDprime  Aggregate d' vs ISI across filtered participants
%
%   plotAggregateDprime(baseDir, placeCodes, condition, minISI0dprime, saveDir)
%
%   Inputs:
%     baseDir         ? folder containing your .mat files
%     placeCodes      ? cell array of place codes, e.g. {'BOS','CAM'} or {'ALL'}
%     condition       ? string to match in filename, e.g. 'Textures'
%     minISI0dprime   ? numeric threshold for d' at ISI=0
%     saveDir         ? folder to write the aggregate PNG into


    % 1) get only the files that pass place/condition/ISI0?d? filter
    files = getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime);
    if isempty(files)
        warning('No participants passed your filters?nothing to plot.');
        return
    end

    epsilon     = 0.00001;     % for correctRate capping
    subjPos     = {};          % per?subject unique repeatPositions
    subjDprimes = {};          % per?subject d? vectors
    allPos      = [];

    % 2) loop over each file, compute its d? curve
    for i = 1:numel(files)
        S = load(files{i}, ...
                 'repeatPosition','isResponseCorrect','stimulusPresented');
        N = numel(S.stimulusPresented);
        SP = string(S.stimulusPresented);

        % build willRepeatFirst mask
        willRepeatFirst = false(N,1);
        for id = unique(SP).'
            m = SP==id;
            fi = find(m,1,'first');
            if nnz(m)>1, willRepeatFirst(fi)=true; end
        end

        % hit rates by repeatPosition
        % repeatTrials = ~ (willRepeatFirst | isnan(S.repeatPosition)==0 & false(N,1)); 
        % simpler: repeatTrials = ~isnan(S.repeatPosition);
        repeatTrials = ~isnan(S.repeatPosition);
        upr = unique(S.repeatPosition(repeatTrials));
        if isempty(upr), continue; end    % no repeats present

        hitByPos = zeros(numel(upr),1);
        for j = 1:numel(upr)
            idx = S.repeatPosition==upr(j);
            hr  = sum(S.isResponseCorrect(idx)) / sum(idx);
            hitByPos(j) = correctRate(hr, epsilon);
        end

        % false alarm rate for will?repeat
        rawFA = sum(~S.isResponseCorrect(willRepeatFirst)) / sum(willRepeatFirst);
        fa    = correctRate(rawFA, epsilon);

        % compute d?
        zH = norminv(hitByPos);
        zF = norminv(fa);
        dp = zH - zF;

        % store
        subjPos{end+1}     = upr;
        subjDprimes{end+1} = dp;
        allPos             = union(allPos, upr);
    end

    if isempty(allPos)
        warning('No valid repeatPositions found across any participants.');
        return
    end

    % 3) Build matrix of [subjects × positions]
    nSub = numel(subjDprimes);
    nPos = numel(allPos);
    M    = nan(nSub, nPos);

    for i = 1:nSub
        for j = 1:numel(subjPos{i})
            col = find(allPos==subjPos{i}(j),1);
            M(i,col) = subjDprimes{i}(j);
        end
    end

    % 4) compute aggregate mean & SEM
    mu  = nanmean(M,1);
    sem = nanstd( M,0,1 ) ./ sqrt( sum(~isnan(M),1) );

    % convert repeatPosition ? ISI
    ISI = allPos - 1;

    % 5) plot & save
    figure;
    errorbar(ISI, mu, sem, 'o-','LineWidth',2);
    xlabel('Interstimulus Interval (ms)');
    ylabel('Mean d^{\prime}');
    title(sprintf('Aggregate d'' vs ISI ? %s (N=%.2f)', condition, nSub));
    grid on;
    
    % 6) save under baseDir/figures/<placeTag>/<condition>/
    if any(strcmpi(placeCodes,'ALL'))
        placeTag = 'ALL';
    else
        placeTag = strjoin(placeCodes,'_');
    end

    % only set x?limits if there's more than one ISI
    if numel(ISI)>1
        xlim([min(ISI)-1, max(ISI)+1]);
    end

    % build place tag
    if any(strcmpi(placeCodes,'ALL'))
        placeTag = 'ALL';
    else
        placeTag = strjoin(placeCodes, '_');
    end
    
    % build and ensure directory:
    outputFolder = fullfile(baseDir, 'figures', condition);
    if ~exist(outputFolder,'dir')
        mkdir(outputFolder);
    end

    outname = sprintf('%s-%s-catchtrial-sens-%.2f.png', 'aggDprime', placeTag, minISI0dprime);
    saveas(gcf, fullfile(outputFolder, outname));

    fprintf('Saved aggregate plot to %s\n', fullfile(outputFolder, outname));

end
