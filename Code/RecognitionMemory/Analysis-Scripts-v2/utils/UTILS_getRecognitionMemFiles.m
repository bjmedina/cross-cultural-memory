% function files = UTILS_getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime, isMultiISI)
% % getRecognitionMemFiles  List subject files by place & condition, filtered by ISI0 d'
% %
% %   files = getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime, isMultiISI)
% %
% %   Inputs:
% %     baseDir         - folder containing your .mat files
% %     placeCodes      - cell array of place codes, e.g. {'BOS','CAM'}, or {'ALL'}
% %     condition       - string to match in filename, e.g. 'Textures' or 'Industrial-Nature'
% %     minISI0dprime   - numeric threshold for d' at ISI=0
% %     isMultiISI      - logical flag (true = multi-ISI, false = single-ISI)
% %
% %   Output:
% %     files           - cell array of full file paths matching all filters
% %
% %   Bryan Medina ? Oct 2025
% 
%     epsilon   = 1e-5;  % cap for rates in correctRate()
%     listing   = dir(fullfile(baseDir, '*.mat'));
%     files     = {};
%     allPlaces = any(strcmpi(placeCodes, 'ALL'));
% 
%     for k = 1:numel(listing)
%         fn = listing(k).name;
% 
%         % --- (1) Place filter ---
%         if allPlaces
%             placeMatch = true;
%         else
%             placeMatch = any(contains(fn, placeCodes, 'IgnoreCase', false));
%         end
% 
%         % --- (2) Condition filter ---
%         condMatch = contains(fn, condition, 'IgnoreCase', true);
% 
%         % --- (3) ISI-type filter ---
%         hasMultiTag = contains(fn, '_Multi-p', 'IgnoreCase', true);
%         if isMultiISI
%             isiMatch = hasMultiTag;
%         else
%             isiMatch = ~hasMultiTag;
%         end
%         
%         isOld = contains(fn, '-original.', 'IgnoreCase', true);
% 
%         if ~(placeMatch && condMatch && isiMatch && ~isOld)
%             continue
%         end
% 
%         % --- (4) Load minimal variables for performance check ---
%         S = load(fullfile(baseDir,fn), ...
%                  'repeatPosition','isResponseCorrect','stimulusPresented');
% 
%         % --- Build willRepeatFirst mask ---
%         nTrials = numel(S.stimulusPresented);
%         SP = string(S.stimulusPresented);
%         willRepeatFirst  = false(nTrials,1);
%         neverRepeatFirst = false(nTrials,1);
%         for id = unique(SP).'
%             maskAll    = SP == id;
%             firstI     = find(maskAll,1,'first');
%             if nnz(maskAll) > 1
%                 willRepeatFirst(firstI) = true;
%             else
%                 neverRepeatFirst(firstI) = true;
%             end
%         end
% 
%         % --- Compute FA and hit rates ---
%         rawFA_wr   = sum(~S.isResponseCorrect(willRepeatFirst)) / sum(willRepeatFirst);
%         faRate_wr  = correctRate_clip(rawFA_wr, epsilon);
% 
%         repeatTrials = ~(willRepeatFirst | neverRepeatFirst);
%         rawHitAll    = sum(S.isResponseCorrect(repeatTrials)) / sum(repeatTrials);
%         overallHit   = correctRate_clip(rawHitAll, epsilon); %#ok<NASGU>
% 
%         uniqPos  = unique(S.repeatPosition(repeatTrials));
%         hitByPos = zeros(numel(uniqPos),1);
%         for i = 1:numel(uniqPos)
%             idx = S.repeatPosition == uniqPos(i);
%             hitByPos(i) = correctRate_clip(sum(S.isResponseCorrect(idx))/sum(idx), epsilon);
%         end
% 
%         % --- Compute d' curve ---
%         zH = norminv(hitByPos);
%         zFA = norminv(faRate_wr);
%         dprimeByPos = zH - zFA;
% 
%         % --- Threshold by ISI=0 performance ---
%         idx0 = find(uniqPos == 1, 1);
%         if isempty(idx0)
%             continue
%         end
%         if dprimeByPos(idx0) < minISI0dprime
%             continue
%         end
% 
%         % --- Passed all filters ---
%         files{end+1,1} = fullfile(baseDir, fn); 
%     end
% end


function [files, outs] = UTILS_getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime, isMultiISI)
% UTILS_getRecognitionMemFiles
% Return (1) a cell array of valid participant files, and
%         (2) a struct containing p1/p2 splits & d? curves.
%
% Required for compatibility with plotAggregateDprime_twoCurves().
%
% Bryan Medina ? Nov 2025

    epsilon   = 1e-5;
    listing   = dir(fullfile(baseDir, '*.mat'));
    filesAll  = {};
    dprimeAll = {};
    allPlaces = any(strcmpi(placeCodes, 'ALL'));

    for k = 1:numel(listing)
        fn = listing(k).name;

        % --- place filter ---
        if allPlaces
            placeMatch = true;
        else
            placeMatch = any(contains(fn, placeCodes, 'IgnoreCase', false));
        end

        % --- condition filter ---
        condMatch = contains(fn, condition, 'IgnoreCase', true);

        % --- ISI-type filter ---
        hasMultiTag = contains(fn, '_Multi-p', 'IgnoreCase', true);
        if isMultiISI
            isiMatch = hasMultiTag;
        else
            isiMatch = ~hasMultiTag;
        end

        % exclude legacy
        isOld = contains(fn, '-original.', 'IgnoreCase', true);
        if ~(placeMatch && condMatch && isiMatch && ~isOld)
            continue
        end

        % --- load minimal ---
        S = load(fullfile(baseDir,fn), 'repeatPosition','isResponseCorrect','stimulusPresented');

        % --- repeat-mode masks ---
        nTrials = numel(S.stimulusPresented);
        SP = string(S.stimulusPresented);
        willRepeatFirst  = false(nTrials,1);
        neverRepeatFirst = false(nTrials,1);
        for id = unique(SP).'
            maskAll = (SP == id);
            firstI  = find(maskAll,1,'first');
            if nnz(maskAll) > 1
                willRepeatFirst(firstI) = true;
            else
                neverRepeatFirst(firstI) = true;
            end
        end

        rawFA_wr  = sum(~S.isResponseCorrect(willRepeatFirst)) / sum(willRepeatFirst);
        faRate_wr = correctRate_clip(rawFA_wr, epsilon);

        repeatTrials = ~(willRepeatFirst | neverRepeatFirst);
        uniqPos      = unique(S.repeatPosition(repeatTrials));

        hitByPos = zeros(numel(uniqPos),1);
        for i = 1:numel(uniqPos)
            idx = (S.repeatPosition == uniqPos(i));
            hitByPos(i) = correctRate_clip(sum(S.isResponseCorrect(idx))/sum(idx), epsilon);
        end

        zH = norminv(hitByPos);
        zFA = norminv(faRate_wr);
        dprimeByPos = zH - zFA;

        % --- threshold on ISI=0 ---
        idx0 = find(uniqPos == 1,1);
        if isempty(idx0), continue; end
        if dprimeByPos(idx0) < minISI0dprime, continue; end

        % --- keep file ---
        filesAll{end+1,1}  = fullfile(baseDir, fn);
        dprimeAll{end+1,1} = dprimeByPos(:)';   % row vector
    end

    % --- build p1/p2 splits ---
    isP1 = endsWith(filesAll, 'p1.mat', 'IgnoreCase', true);
    isP2 = endsWith(filesAll, 'p2.mat', 'IgnoreCase', true);

    filesP1 = filesAll(isP1);
    filesP2 = filesAll(isP2);

    % --- pad d? curves ---
    if isempty(dprimeAll)
        dprimeP1 = [];
        dprimeP2 = [];
    else
        maxLen = max(cellfun(@numel, dprimeAll));
        dMat = NaN(numel(dprimeAll), maxLen);
        for i = 1:numel(dprimeAll)
            v = dprimeAll{i};
            dMat(i,1:numel(v)) = v;
        end
        dprimeP1 = dMat(isP1,:);
        dprimeP2 = dMat(isP2,:);
    end

    % --- primary return value (legacy) ---
    files = filesAll;

    % --- struct for plotting ---
    outs.filesAll  = filesAll;
    outs.filesP1   = filesP1;
    outs.filesP2   = filesP2;
    outs.dprimeP1  = dprimeP1;
    outs.dprimeP2  = dprimeP2;
end

function r = correctRate_clip(p, eps)
    r = max(min(p,1-eps),eps);
end
