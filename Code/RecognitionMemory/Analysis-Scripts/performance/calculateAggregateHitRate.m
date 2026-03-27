function outs = calculateAggregateHitRate(baseDir, placeCodes, condition, minISI0dprime, isMultiISI, varargin)
% calculateAggregateHitRate
%   Aggregate hit rate vs ISI across filtered participants (optionally plots & saves).
%
%   outs = calculateAggregateHitRate(baseDir, placeCodes, condition, minISI0dprime, isMultiISI, ...)
%
%   Inputs:
%     baseDir         - folder containing your .mat files
%     placeCodes      - cell array of place codes, e.g. {'BOS','CAM'} or {'ALL'}
%     condition       - string to match in filename, e.g. 'Textures'
%     minISI0dprime   - numeric threshold for d' at ISI=0
%     isMultiISI      - logical flag (true = multi-ISI, false = single-ISI)
%
%   Optional Name/Value pairs:
%     'ShowPlot'      - whether to generate & save the figure (default = true)
%
%   Output struct fields:
%     outs.ISI             - vector of ISI values (trials-between)
%     outs.mean_hit_rate   - mean hit rate across participants
%     outs.sem_hit_rate    - SEM across participants
%     outs.subject_hit_mat - [nSub x nPos] matrix of per-subject hit rates
%     outs.subject_positions - cell array of per-subject repeatPositions
%     outs.files            - full paths of included .mat files
%     outs.nSubjects        - number of participants included
%
%   Bryan Medina ? Oct 28 2025

    % -----------------------------
    % parameters & options
    % -----------------------------
    epsilon = 1e-5; % small epsilon for clipping
    p = inputParser;
    addParameter(p, 'ShowPlot', true, @islogical);
    parse(p, varargin{:});
    ShowPlot = p.Results.ShowPlot;

    % -----------------------------
    % 1) find & filter files
    % -----------------------------
    files = UTILS_getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime, isMultiISI);
    if isempty(files)
        warning('No participants passed filters ? nothing to compute.');
        outs = struct(); return;
    end

    subjPos = {};
    subjHitRates = {};
    allPos = [];

    % -----------------------------
    % 2) compute per-subject hit-rate curves
    % -----------------------------
    for i = 1:numel(files)
        S = load(files{i}, 'repeatPosition','isResponseCorrect');
        if ~isfield(S,'repeatPosition') || isempty(S.repeatPosition)
            continue
        end

        rt = ~isnan(S.repeatPosition);
        upr = unique(S.repeatPosition(rt));
        if isempty(upr)
            continue
        end

        hitByPos = zeros(numel(upr),1);
        for j = 1:numel(upr)
            idx = S.repeatPosition == upr(j);
            hr_raw = sum(S.isResponseCorrect(idx)) / sum(idx);
            hitByPos(j) = correctRate_clip(hr_raw, epsilon);
        end

        subjPos{end+1} = upr; %#ok<AGROW>
        subjHitRates{end+1} = hitByPos; %#ok<AGROW>
        allPos = union(allPos, upr);
    end

    if isempty(allPos)
        warning('No valid repeat positions found.');
        outs = struct(); return;
    end

    % -----------------------------
    % 3) align into [nSub × nPos] matrix
    % -----------------------------
    nSub = numel(subjHitRates);
    nPos = numel(allPos);
    M = nan(nSub, nPos);

    for i = 1:nSub
        for j = 1:numel(subjPos{i})
            col = find(allPos == subjPos{i}(j), 1);
            M(i,col) = subjHitRates{i}(j);
        end
    end

    % -----------------------------
    % 4) compute mean & SEM
    % -----------------------------
    muHit  = nanmean(M,1);
    semHit = nanstd(M,0,1) ./ sqrt(sum(~isnan(M),1));
    ISI    = allPos - 1;

    % -----------------------------
    % 5) optional plotting
    % -----------------------------
    if ShowPlot
        figure('Color','w');
        errorbar(ISI, muHit, semHit, 'o-','LineWidth',2);
        xlabel('Interstimulus Interval (trials-between)');
        ylabel('Mean Hit Rate');
        title(sprintf('Aggregate Hit Rate vs ISI ? %s (N=%d)', condition, nSub));
        grid on;
        ylim([0 1]);
        if numel(ISI) > 1, xlim([min(ISI)-1, max(ISI)+1]); end

        if any(strcmpi(placeCodes,'ALL')), placeTag = 'ALL';
        else, placeTag = strjoin(placeCodes,'_'); end

        figDir = fullfile(baseDir, 'figures', condition);
        if ~exist(figDir,'dir'), mkdir(figDir); end

        fname = sprintf('aggHitRate_%s_%s_%s.png', ...
            condition, placeTag, ternary(isMultiISI,'multiISI','singleISI'));
        saveas(gcf, fullfile(figDir, fname));
        fprintf('Saved aggregate plot to %s\n', fullfile(figDir, fname));
    end

    % -----------------------------
    % 6) package outputs for downstream analyses
    % -----------------------------
    outs = struct();
    outs.ISI               = ISI;
    outs.mean_hit_rate     = muHit;
    outs.sem_hit_rate      = semHit;
    outs.subject_hit_mat   = M;
    outs.subject_positions = subjPos;
    outs.files             = files;
    outs.nSubjects         = nSub;
end

% -----------------------------
% utilities
% -----------------------------
function p = correctRate_clip(p_raw, eps_val)
    if isnan(p_raw)
        p = NaN;
    else
        p = min(max(p_raw, eps_val), 1 - eps_val);
    end
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end