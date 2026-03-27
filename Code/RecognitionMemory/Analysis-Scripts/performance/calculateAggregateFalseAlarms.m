function outs = calculateAggregateFalseAlarms(baseDir, placeCodes, condition, minISI0dprime, isMultiISI, varargin)
% calculateAggregateFalseAlarms
%   Aggregate false alarm rates (will-repeat, never-repeat, overall)
%   across participants filtered by ISI0 d' and condition.
%
%   outs = calculateAggregateFalseAlarms(baseDir, placeCodes, condition, minISI0dprime, isMultiISI, ...)
%
%   Inputs:
%     baseDir         - folder containing your .mat files
%     placeCodes      - cell array of place codes, e.g. {'BOS','CAM'} or {'ALL'}
%     condition       - string to match in filename, e.g. 'Textures'
%     minISI0dprime   - numeric threshold for d' at ISI=0 (filtering)
%     isMultiISI      - logical flag (true = multi-ISI, false = single-ISI)
%
%   Optional Name/Value pairs:
%     'ShowPlot'      - whether to generate & save the figure (default = true)
%
%   Output struct fields:
%     outs.fa_wr          - vector of FA rates for "will-repeat" trials
%     outs.fa_nr          - vector of FA rates for "never-repeat" trials
%     outs.fa_overall     - overall FA rates (weighted)
%     outs.mean           - [1x3] mean of FA_WR, FA_NR, Overall
%     outs.sem            - [1x3] SEM of FA_WR, FA_NR, Overall
%     outs.files          - included .mat files
%     outs.nSubjects      - number of participants
%
%   Bryan Medina ? Bolivia 2025

    % -----------------------------
    % parameters & options
    % -----------------------------
    epsilon = 1e-5;
    p = inputParser;
    addParameter(p, 'ShowPlot', true, @islogical);
    parse(p, varargin{:});
    ShowPlot = p.Results.ShowPlot;

    % -----------------------------
    % 1) Filter participant files
    % -----------------------------
    files = UTILS_getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime, isMultiISI);
    if isempty(files)
        warning('No participants passed filters ? nothing to compute.');
        outs = struct(); return;
    end

    nFiles        = numel(files);
    fa_wr_vec     = nan(nFiles,1);
    fa_nr_vec     = nan(nFiles,1);
    fa_overall_vec = nan(nFiles,1);

    % -----------------------------
    % 2) Compute FA rates per participant
    % -----------------------------
    for i = 1:nFiles
        S = load(files{i}, 'repeatPosition','isResponseCorrect','stimulusPresented');
        if ~isfield(S, 'stimulusPresented') || isempty(S.stimulusPresented)
            continue
        end

        N  = numel(S.stimulusPresented(:));
        SP = string(S.stimulusPresented(:));

        % --- Identify first presentations ---
        willRepeatFirst  = false(N,1);
        neverRepeatFirst = false(N,1);
        for id = unique(SP).'
            maskAll = SP == id;
            firstI  = find(maskAll, 1, 'first');
            if nnz(maskAll) > 1
                willRepeatFirst(firstI) = true;
            else
                neverRepeatFirst(firstI) = true;
            end
        end

        % --- Sanity check: first trials = non-repeat trials ---
        firstTrials = isnan(S.repeatPosition);
        assert(all((willRepeatFirst | neverRepeatFirst) == firstTrials), ...
            'Mask mismatch in %s', files{i});

        % --- Compute FA for each subset ---
        rawFA_wr  = sum(~S.isResponseCorrect(willRepeatFirst))  / sum(willRepeatFirst);
        fa_wr     = correctRate_clip(rawFA_wr, epsilon);

        rawFA_nr  = sum(~S.isResponseCorrect(neverRepeatFirst)) / sum(neverRepeatFirst);
        fa_nr     = correctRate_clip(rawFA_nr, epsilon);

        % Weighted overall FA
        Nw = sum(willRepeatFirst);
        Nn = sum(neverRepeatFirst);
        rawFA_all = (fa_wr * Nw + fa_nr * Nn) / (Nw + Nn);
        fa_all    = correctRate_clip(rawFA_all, epsilon);

        % Store
        fa_wr_vec(i)      = fa_wr;
        fa_nr_vec(i)      = fa_nr;
        fa_overall_vec(i) = fa_all;
    end

    % -----------------------------
    % 3) Compute group mean & SEM
    % -----------------------------
    mu  = [ mean(fa_wr_vec, 'omitnan'), ...
            mean(fa_nr_vec, 'omitnan'), ...
            mean(fa_overall_vec, 'omitnan') ];

    sem = [ std(fa_wr_vec,  'omitnan') ./ sqrt(nFiles), ...
            std(fa_nr_vec,  'omitnan') ./ sqrt(nFiles), ...
            std(fa_overall_vec, 'omitnan') ./ sqrt(nFiles) ];

    % -----------------------------
    % 4) Plot
    % -----------------------------
    if ShowPlot
        figure('Color', 'w');
        x = 1:3;
        bar(x, mu, 'FaceAlpha', 0.85);
        hold on;
        errorbar(x, mu, sem, 'k', 'LineStyle', 'none', 'LineWidth', 1.5);
        hold off;
        xticks(x);
        xticklabels({'FA will-repeat', 'FA never-repeat', 'Overall FA'});
        ylabel('False Alarm Rate');
        ylim([0 1]);
        title(sprintf('Aggregate FA Rates ? %s (N=%d)', condition, nFiles));
        grid on;

        if any(strcmpi(placeCodes,'ALL')), placeTag = 'ALL';
        else, placeTag = strjoin(placeCodes,'_'); end

        figDir = fullfile(baseDir, 'figures', condition);
        if ~exist(figDir,'dir'), mkdir(figDir); end

        fname = sprintf('aggFalseAlarms_%s_%s_%s.png', ...
            condition, placeTag, ternary(isMultiISI,'multiISI','singleISI'));
        saveas(gcf, fullfile(figDir, fname));
        fprintf('Saved aggregate plot to %s\n', fullfile(figDir, fname));
    end

    % -----------------------------
    % 5) Package outputs for downstream use
    % -----------------------------
    outs = struct();
    outs.fa_wr          = fa_wr_vec;
    outs.fa_nr          = fa_nr_vec;
    outs.fa_overall     = fa_overall_vec;
    outs.mean           = mu;
    outs.sem            = sem;
    outs.files          = files;
    outs.nSubjects      = nFiles;
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