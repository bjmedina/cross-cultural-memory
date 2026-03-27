function files = getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime)
% getRecognitionMemFiles  List subject files by place & condition, filtered by ISI0 d'
%
%   files = getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime)
%
%   Inputs:
%     baseDir         ? folder containing your ?.mat? files
%     placeCodes      ? cell array of place codes, e.g. {'BOS','CAM'}, or {'ALL'}
%     condition       ? string to match in filename, e.g. 'Textures'
%     minISI0dprime   ? numeric threshold for d' at ISI=0
%
%   Output:
%     files           ? cell array of full file paths matching all filters

    epsilon   = 0.01;  % cap for rates in correctRate()
    listing   = dir(fullfile(baseDir, '*.mat'));
    files     = {};
    allPlaces = any(strcmpi(placeCodes, 'ALL'));

    for k = 1:numel(listing)
        fn = listing(k).name;

        % 1) filter by place
        if allPlaces
            placeMatch = true;
        else
            placeMatch = any( contains(fn, placeCodes, 'IgnoreCase', false) );
        end

        % 2) filter by condition
        condMatch = contains(fn, condition, 'IgnoreCase', true);
        multiISIMatch = ~contains(fn, "_Multi-p",'IgnoreCase', false);

        if ~(placeMatch && condMatch && multiISIMatch)
            continue
        end

        % 3) load only what we need
        S = load(fullfile(baseDir,fn), ...
                 'repeatPosition','isResponseCorrect','stimulusPresented');

        % --- build willRepeatFirst mask from stimulusPresented ---
        nTrials = numel(S.stimulusPresented);
        SP = string(S.stimulusPresented);
        
        willRepeatFirst  = false(nTrials,1);
        neverRepeatFirst = false(nTrials,1);
        for id = unique(SP).'
            maskAll    = SP==id;
            firstI     = find(maskAll,1,'first');
            if nnz(maskAll)>1
                willRepeatFirst(firstI) = true;
            else
                neverRepeatFirst(firstI) = true;
            end
        end

        % --- compute FA rate for will-repeat ---
        rawFA_wr   = sum(~S.isResponseCorrect(willRepeatFirst)) / sum(willRepeatFirst);
        faRate_wr  = correctRate(rawFA_wr, epsilon);

        % --- compute hit rates by repeat-position ---
        repeatTrials = ~ (willRepeatFirst | neverRepeatFirst);
        rawHitAll    = sum(S.isResponseCorrect(repeatTrials)) / sum(repeatTrials);
        overallHit   = correctRate(rawHitAll, epsilon);

        uniqPos  = unique(S.repeatPosition(repeatTrials));
        hitByPos = zeros(numel(uniqPos),1);
        for i = 1:numel(uniqPos)
            idx = S.repeatPosition==uniqPos(i);
            hitByPos(i) = correctRate( sum(S.isResponseCorrect(idx))/sum(idx), epsilon );
        end

        % --- compute d' curve using will-repeat FA ---
        zH    = norminv(hitByPos);
        zFA   = norminv(faRate_wr);
        dprimeByPos = zH - zFA;

        % --- find ISI=0 (pos==1) and test threshold ---
        idx0 = find(uniqPos==1,1);
        if isempty(idx0)
            continue
        end
        if dprimeByPos(idx0) < minISI0dprime
            continue
        end

        % if we get here, this file passes all filters
        files{end+1,1} = fullfile(baseDir,fn); %#ok<AGROW>
    end
end