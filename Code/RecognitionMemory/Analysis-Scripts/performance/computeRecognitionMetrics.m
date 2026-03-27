function metrics = computeRecognitionMetrics(files)
% computeRecognitionMetrics
%   Compute detailed hit/FA/d? metrics for a set of recognition-memory files.
%
%   metrics = computeRecognitionMetrics(files)
%
%   Inputs:
%     files  : cell array of .mat file paths
%
%   Output struct fields (each NxK, N=participants, K=ISI positions):
%     .ISI_list             -- list of ISIs (0,1,2,4,...)
%     .hit_by_ISI           -- hit rate per ISI
%     .FA_willRepeatFirst   -- FA on willRepeatFirst trials
%     .FA_neverRepeat       -- FA on neverRepeatFirst trials
%     .FA_allNonRepeat      -- FA pooled across all non-repeat trials
%     .overall_hit          -- overall hit rate
%     .overall_FA           -- overall FA rate
%     .dprime               -- d? per ISI
%     .nTrials_per_ISI      -- number of trials contributing to each ISI
%
%   Bryan Medina ? Nov 2025

    epsilon = 1e-5;   % clip for norminv

    N = numel(files);
    if N == 0
        error('No files passed to computeRecognitionMetrics().');
    end

    % First pass: determine all ISIs that appear
    allISI = [];
    for i = 1:N
        S = load(files{i}, 'repeatPosition');
        pos = S.repeatPosition(~isnan(S.repeatPosition));  % only valid repeat trials
        allISI = [allISI; unique(pos(:))];
    end
    allISI = unique(allISI);      % repeat positions
    ISI_list = allISI - 1;        % convert to actual ISI
    K = numel(ISI_list);

    % Initialize matrices
    hit_by_ISI         = NaN(N,K);
    FA_willRepeatFirst = NaN(N,1);
    FA_neverRepeat     = NaN(N,1);
    FA_allNonRepeat    = NaN(N,1);
    overall_hit        = NaN(N,1);
    overall_FA         = NaN(N,1);
    dprime             = NaN(N,K);
    nTrials_per_ISI    = zeros(N,K);

    % Loop over participants
    for i = 1:N
        S = load(files{i}, 'repeatPosition','isResponseCorrect','stimulusPresented');

        SP = string(S.stimulusPresented);
        nTrials = numel(S.isResponseCorrect);

        % --- repeat-mode classification ---
        willRepeatFirst  = false(nTrials,1);
        neverRepeatFirst = false(nTrials,1);

        for id = unique(SP).'
            mask = (SP == id);
            firstI = find(mask,1,'first');
            if nnz(mask) > 1
                willRepeatFirst(firstI) = true;
            else
                neverRepeatFirst(firstI) = true;
            end
        end

        repeatTrials = ~(willRepeatFirst | neverRepeatFirst);

        % ---------- False alarm rates ----------
        FA_willRepeatFirst(i) = mean(~S.isResponseCorrect(willRepeatFirst));
        FA_neverRepeat(i)     = mean(~S.isResponseCorrect(neverRepeatFirst));
        FA_allNonRepeat(i)    = mean(~S.isResponseCorrect(willRepeatFirst | neverRepeatFirst));
        overall_FA(i)         = FA_allNonRepeat(i);

        % ---------- Hit rates ----------
        overall_hit(i) = mean(S.isResponseCorrect(repeatTrials));

        for k = 1:K
            pos = allISI(k);              % repeatPosition value
            maskISI = (S.repeatPosition == pos);
            nTrials_per_ISI(i,k) = sum(maskISI);
            if nTrials_per_ISI(i,k) > 0
                hit_by_ISI(i,k) = mean(S.isResponseCorrect(maskISI));
            end
        end

        % ---------- d? ----------
        % use FA from willRepeatFirst (standard McDermott lab policy)
        fa = max(min(FA_willRepeatFirst(i),1-epsilon),epsilon);
        zFA = norminv(fa);

        for k = 1:K
            if isnan(hit_by_ISI(i,k)), continue; end
            h = max(min(hit_by_ISI(i,k),1-epsilon),epsilon);
            zH = norminv(h);
            dprime(i,k) = zH - zFA;
        end
    end

    % ---------- Package outputs ----------
    metrics.ISI_list             = ISI_list;
    metrics.hit_by_ISI           = hit_by_ISI;
    metrics.FA_willRepeatFirst   = FA_willRepeatFirst;
    metrics.FA_neverRepeat       = FA_neverRepeat;
    metrics.FA_allNonRepeat      = FA_allNonRepeat;
    metrics.overall_hit          = overall_hit;
    metrics.overall_FA           = overall_FA;
    metrics.dprime               = dprime;
    metrics.nTrials_per_ISI      = nTrials_per_ISI;
end