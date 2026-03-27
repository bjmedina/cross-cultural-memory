function out = plotAggregateDprimeMulti(baseDir, groupPlaceCodes, condition, minISI0dprime, varargin)
% plotAggregateDprimeMulti  Plot aggregate d' vs ISI for multiple groups on one figure.
%
%   out = plotAggregateDprimeMulti(baseDir, groupPlaceCodes, condition, minISI0dprime, ...
%                                  'GroupLabels', labelsCell, ...
%                                  'Save', true/false, ...
%                                  'OutDir', outDir)
%
%   Inputs:
%     baseDir           folder containing your .mat files
%     groupPlaceCodes   cell array of groups, each group is a cell array of place codes
%                       e.g., { {'BOS'}, {'SB','BENI'}, {'TSI'} }
%     condition         string to match in filename, e.g. 'Textures'
%     minISI0dprime     numeric threshold for d' at ISI=0 (participant filter)
%
%   Name-Value options:
%     'GroupLabels'     cellstr of legend labels, one per group (default: joined place codes)
%     'Save'            logical, whether to save PNG (default: true)
%     'OutDir'          output directory (default: fullfile(baseDir,'figures',condition))
%
%   Output (struct):
%     out.groups(k).label   label used for the kth group
%     out.groups(k).ISI     row vector of ISIs used for that group
%     out.groups(k).mu      mean d' per ISI (aligned to global ISI union)
%     out.groups(k).sem     SEM per ISI (aligned)
%     out.groups(k).nSub    number of participants contributing to that group
%     out.ISI               global union of ISIs across groups (x-axis)
%
%   Dependencies expected in path:
%     - getRecognitionMemFiles.m (your existing helper)
%   Notes:
%     - This file defines a private correctRate() used internally if one is not on path.
%
%   Example:
%     groups = { {'BOS'}, {'SB','BENI'}, {'TSI'} };
%     labels = {'Boston','San Borja+Beni','Tsimane'''};
%     out = plotAggregateDprimeMulti('/data/recog', groups, 'Textures', 0.5, ...
%                                    'GroupLabels', labels, 'Save', true);

    % -------------------- Parse args --------------------
    p = inputParser;
    p.addParameter('GroupLabels', defaultLabels(groupPlaceCodes), @(c) iscellstr(c) && numel(c)==numel(groupPlaceCodes));
    p.addParameter('Save', true, @(x) islogical(x) && isscalar(x));
    p.addParameter('OutDir', fullfile(baseDir,'figures',condition), @(s) ischar(s) || isstring(s));
    p.parse(varargin{:});
    labels   = p.Results.GroupLabels;
    doSave   = p.Results.Save;
    outDir   = char(p.Results.OutDir);

    % Ensure output dir exists when saving
    if doSave && ~exist(outDir,'dir'), mkdir(outDir); end

    % -------------------- Compute per-group aggregates --------------------
    groupAgg = cell(1, numel(groupPlaceCodes));
    allISI   = [];

    % Loop over groups, compute their aggregate curves
    for g = 1:numel(groupPlaceCodes)
        % Compute subject curves and aggregate stats for this group
        groupAgg{g} = computeAggregateForGroup(baseDir, groupPlaceCodes{g}, condition, minISI0dprime);
        % Union of ISIs across groups for alignment
        allISI = union(allISI, groupAgg{g}.ISI);
    end

    if isempty(allISI)
        warning('No valid ISIs found across any groups. Nothing to plot.');
        out = struct('groups', [], 'ISI', []);
        return;
    end

    % -------------------- Align groups to global ISI union --------------------
    G = numel(groupAgg);
    K = numel(allISI);
    alignedMu  = nan(G, K);  % means aligned to allISI
    alignedSem = nan(G, K);  % sems aligned to allISI
    nSubs      = nan(G, 1);  % participant counts

    for g = 1:G
        nSubs(g) = groupAgg{g}.nSub;
        if isempty(groupAgg{g}.ISI), continue; end
        [~, idxInAll] = ismember(groupAgg{g}.ISI, allISI);  %#ok<ISMT>
        alignedMu(g, idxInAll)  = groupAgg{g}.mu;
        alignedSem(g, idxInAll) = groupAgg{g}.sem;
    end

    % -------------------- Plot --------------------
    figure('Color','w'); hold on; grid on;
    hLines = gobjects(G,1);   % <--- ADD THIS

    for g = 1:G
        % Plot mean line (store handle; set legend label here)
        hLines(g) = plot(allISI, alignedMu(g, :), '-o', 'LineWidth', 2, 'MarkerSize', 6);
        set(hLines(g), 'DisplayName', sprintf('%s (N=%d)', labels{g}, nSubs(g)));

        % Plot error bars (same color as line; hide from legend)
        valid = ~isnan(alignedMu(g,:)) & ~isnan(alignedSem(g,:));
        if any(valid)
            thisColor = get(hLines(g), 'Color');
            errorbar(allISI(valid), alignedMu(g,valid), alignedSem(g,valid), ...
                     'LineStyle', 'none', 'LineWidth', 1.2, 'Color', thisColor, ...
                     'HandleVisibility','off');   % <--- KEY: exclude from legend
        end
    end

    xlabel('Interstimulus Interval (ms)');
    ylabel('Mean d^{\prime}');
    ttl = sprintf('Aggregate d'' vs ISI ? %s', condition);
    title(ttl);

    % Legend with N per group
    legStrings = arrayfun(@(i) sprintf('%s (N=%d)', labels{i}, nSubs(i)), 1:G, 'UniformOutput', false);
    legend(hLines, 'Location','best');

    if numel(allISI)>1
        xlim([min(allISI)-1, max(allISI)+1]);  % add small padding
    end

    % -------------------- Save (optional) --------------------
    if doSave
        placeTag = strjoin(cellfun(@(pc) strjoin(pc,'+'), groupPlaceCodes, 'UniformOutput', false), '__');
        outname  = sprintf('aggDprimeMulti-%s-sens-%.2f.png', placeTag, minISI0dprime);
        saveas(gcf, fullfile(outDir, outname));
        fprintf('Saved multi-group plot to %s\n', fullfile(outDir, outname));
    end

    % -------------------- Return results --------------------
    out = struct();
    out.ISI = allISI;
    out.groups = struct('label', [], 'ISI', [], 'mu', [], 'sem', [], 'nSub', []);
    for g = 1:G
        out.groups(g).label = labels{g};
        out.groups(g).ISI   = groupAgg{g}.ISI;
        out.groups(g).mu    = groupAgg{g}.mu;
        out.groups(g).sem   = groupAgg{g}.sem;
        out.groups(g).nSub  = groupAgg{g}.nSub;
    end
end

% ======================== Helper: default legend labels ========================
function labels = defaultLabels(groupPlaceCodes)
% defaultLabels  Build default legend labels by joining place codes per group.
    labels = cell(1, numel(groupPlaceCodes));
    for i = 1:numel(groupPlaceCodes)
        pc = groupPlaceCodes{i};
        if any(strcmpi(pc,'ALL'))
            labels{i} = 'ALL';
        else
            labels{i} = strjoin(pc, '+');
        end
    end
end

% ======================== Helper: compute group aggregate ======================
function agg = computeAggregateForGroup(baseDir, placeCodes, condition, minISI0dprime)
% computeAggregateForGroup  Compute mean/SEM d' vs ISI for one group.
%
%   Returns struct with fields:
%     .ISI    row vector of ISIs present in this group
%     .mu     mean d' per ISI (row)
%     .sem    SEM per ISI (row)
%     .nSub   number of subjects contributing

    % Get filtered files (user-provided helper on path)
    files = getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime);
    if isempty(files)
        agg = struct('ISI', [], 'mu', [], 'sem', [], 'nSub', 0);
        return;
    end

    % Compute per-subject d' curves
    [subjPos, subjDp, allPos] = computeSubjectCurves(files);

    if isempty(allPos)
        agg = struct('ISI', [], 'mu', [], 'sem', [], 'nSub', 0);
        return;
    end

    % Build subject × position matrix
    nSub = numel(subjDp);
    nPos = numel(allPos);
    M    = nan(nSub, nPos);
    for i = 1:nSub
        up = subjPos{i};
        for j = 1:numel(up)
            col = find(allPos==up(j), 1);
            M(i,col) = subjDp{i}(j);
        end
    end

    % Aggregate stats
    mu  = nanmean(M, 1);
    sem = nanstd(M, 0, 1) ./ sqrt(sum(~isnan(M), 1));

    % Convert repeatPosition -> ISI (ms), assuming repeatPosition = ISI+1
    ISI = allPos - 1;

    agg = struct('ISI', ISI(:).', 'mu', mu(:).', 'sem', sem(:).', 'nSub', nSub);
end

% ======================== Helper: per-subject curves ===========================
function [subjPos, subjDprimes, allPos] = computeSubjectCurves(files)
% computeSubjectCurves  Load each file, compute that subject's d' vs position.
%
%   d' is z(H) - z(FA), where:
%     - H computed per repeatPosition among repeat trials
%     - FA from "willRepeatFirst" catch trials (first presentation of items that repeat)
%
%   Returns:
%     subjPos{i}      unique repeatPositions for subject i
%     subjDprimes{i}  d' for those positions
%     allPos          union of all positions across subjects

    epsilon     = 1e-5;     % cap to avoid inf z-scores
    subjPos     = {};
    subjDprimes = {};
    allPos      = [];

    for i = 1:numel(files)
        S = load(files{i}, 'repeatPosition','isResponseCorrect','stimulusPresented');
        N = numel(S.stimulusPresented);
        SP = string(S.stimulusPresented);

        % Build "willRepeatFirst": first presentation of any item that later repeats
        willRepeatFirst = false(N,1);
        uids = unique(SP);
        for k = 1:numel(uids)
            m = (SP == uids(k));
            if nnz(m) > 1
                fi = find(m, 1, 'first');
                willRepeatFirst(fi) = true;
            end
        end

        % Repeat trials mask and positions present
        repeatTrials = ~isnan(S.repeatPosition);
        upr = unique(S.repeatPosition(repeatTrials));
        if isempty(upr), continue; end

        % Hit rate per position
        hitByPos = zeros(numel(upr),1);
        for j = 1:numel(upr)
            idx = (S.repeatPosition == upr(j));
            hr  = sum(S.isResponseCorrect(idx)) / sum(idx);
            hitByPos(j) = correctRate(hr, epsilon); % cap away from 0/1
        end

        % False alarm rate from catch trials
        rawFA = sum(~S.isResponseCorrect(willRepeatFirst)) / max(1, sum(willRepeatFirst));
        fa    = correctRate(rawFA, epsilon);

        % d' = z(H) - z(FA)
        zH = norminv(hitByPos);
        zF = norminv(fa);
        dp = zH - zF;

        % Store
        subjPos{end+1}     = upr; %#ok<AGROW>
        subjDprimes{end+1} = dp;  %#ok<AGROW>
        allPos             = union(allPos, upr);
    end
end

% ======================== Helper: correctRate (safeguard) ======================
function x = correctRate(p, epsVal)
% correctRate  Clamp a proportion into (eps, 1-eps) to avoid inf z-scores.
    if nargin < 2, epsVal = 1e-5; end
    x = min(max(p, epsVal), 1 - epsVal);
end