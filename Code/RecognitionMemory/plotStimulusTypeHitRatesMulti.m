function out = plotStimulusTypeHitRatesMulti(baseDir, groupPlaceCodes, condition, minISI0dprime, varargin)
% plotStimulusTypeHitRatesMulti  Aggregate nonzero-ISI hit rates by stimulus type for multiple groups.
%
%   out = plotStimulusTypeHitRatesMulti(baseDir, groupPlaceCodes, condition, minISI0dprime, ...
%                                       'GroupLabels', labelsCell, ...
%                                       'Save', true/false, ...
%                                       'OutDir', outDir)
%
%   Inputs:
%     baseDir           folder with your .mat files
%     groupPlaceCodes   1xG cell; each cell is a cellstr of place codes (e.g., {{'PRO'}, {'MAN','MAJ',...}})
%     condition         string to match in filename, e.g. 'Industrial-Nature'
%     minISI0dprime     threshold for d' at ISI=0 (filters participants)
%
%   Name-Value options:
%     'GroupLabels'     1xG cellstr legend labels (default: joined place codes)
%     'Save'            logical, save PNG (default: true)
%     'OutDir'          override output directory (default: <baseDir>/figures/<condition>)
%
%   Output:
%     out.types         1xT string array of all stimulus types (x-axis categories)
%     out.groups(g).mu  1xT mean hit rate per type (NaN where group lacks that type)
%     out.groups(g).sem 1xT SEM per type (aligned to out.types)
%     out.groups(g).nSub  scalar N participants used for that group
%
%   Bryan Medina ? 08-27-25

    % ---- Parse options ----
    p = inputParser;
    p.addParameter('GroupLabels', defaultLabels(groupPlaceCodes), @(c) iscellstr(c) && numel(c)==numel(groupPlaceCodes));
    p.addParameter('Save', true, @(x) islogical(x) && isscalar(x));
    p.addParameter('OutDir', fullfile(baseDir,'figures',condition), @(s) ischar(s) || isstring(s));
    p.parse(varargin{:});
    labels = p.Results.GroupLabels;
    doSave = p.Results.Save;
    outDir = char(p.Results.OutDir);
    if doSave && ~exist(outDir,'dir'), mkdir(outDir); end

    % ---- Collect per-group stats & union of types ----
    G = numel(groupPlaceCodes);
    groupStats = cell(1,G);
    allTypes   = string([]);
    for g = 1:G
        groupStats{g} = computeTypeStatsForGroup(baseDir, groupPlaceCodes{g}, condition, minISI0dprime);
        allTypes = union(allTypes, groupStats{g}.types);
    end
    if isempty(allTypes)
        warning('No stimulus types found across any groups.'); 
        out = struct('types', [], 'groups', []); 
        return;
    end

    % ---- Align each group to the global type union ----
    T = numel(allTypes);
    MU  = nan(G,T);
    SEM = nan(G,T);
    N   = zeros(G,1);
    for g = 1:G
        N(g) = groupStats{g}.nSub;
        if isempty(groupStats{g}.types), continue; end
        [tf, idx] = ismember(groupStats{g}.types, allTypes);
        MU(g, idx(tf))  = groupStats{g}.mu(tf);
        SEM(g, idx(tf)) = groupStats{g}.sem(tf);
    end

    % ---- Plot grouped bars with error bars ----
    figure('Color','w'); hold on; grid on;
    % bar() expects rows as categories; columns as series -> transpose MU/SEM
    bh = bar(MU.', 'grouped', 'FaceAlpha', 0.9);
    % Error bars: use XEndPoints when available
    try
        for g = 1:G
            xe = bh(g).XEndPoints;
            valid = ~isnan(MU(g,:)) & ~isnan(SEM(g,:));
            errorbar(xe(valid), MU(g,valid), SEM(g,valid), 'k', ...
                     'LineStyle','none', 'LineWidth', 1.2, 'HandleVisibility','off');
        end
    catch
        % Fallback: approximate centers if XEndPoints not supported
        ng = numel(bh);                % number of actually plotted bar series
        T  = size(MU, 2);              % number of categories
        xbase = 1:T;
        % Use bar width if available, otherwise 0.8
        try, w = bh(1).BarWidth; catch, w = 0.8; end
        offsets = linspace(-w/2, w/2, ng);

        for gg = 1:ng                   % loop over actual series, not G
            xg = xbase + offsets(gg);
            valid = ~isnan(MU(gg,:)) & ~isnan(SEM(gg,:));
            errorbar(xg(valid), MU(gg,valid), SEM(gg,valid), 'k', ...
                     'LineStyle','none', 'LineWidth', 1.2, 'HandleVisibility','off');
        end
    end
    xticks(1:T);
    xticklabels(allTypes);
    ylim([0,1]); 
    xlabel('Stimulus Type'); 
    ylabel('Hit Rate (nonzero ISI)');
    ttl = sprintf('Hit Rate by Stimulus Type ? %s', condition);
    title(ttl);

    % Legend with N
    %legStrings = arrayfun(@(i) sprintf('%s (N=%d)', labels{i}, N(i)), 1:G, 'UniformOutput', false);
    plotGroupCount = numel(bh);  % number of bar series actually drawn
    legStrings = arrayfun(@(i) sprintf('%s (N=%d)', labels{i}, N(i)), ...
                          1:plotGroupCount, 'UniformOutput', false);
    legend(legStrings, 'Location','best');

    % ---- Save ----
    if doSave
        placeTag = strjoin(cellfun(@(pc) strjoin(pc,'+'), groupPlaceCodes, 'UniformOutput', false), '__');
        fname = sprintf('aggStimulusTypeHitRateMulti-%s-sens-%.2f.png', placeTag, minISI0dprime);
        saveas(gcf, fullfile(outDir, fname));
        fprintf('Saved multi-group stimulus-type plot to %s\n', fullfile(outDir, fname));
    end

    % ---- Return ----
    out = struct();
    out.types = allTypes(:).';
    out.groups = struct('mu', [], 'sem', [], 'nSub', []);
    for g = 1:G
        out.groups(g).mu   = MU(g, :);
        out.groups(g).sem  = SEM(g, :);
        out.groups(g).nSub = N(g);
    end
end

% =================== Helper: compute per-group type stats ===================
function S = computeTypeStatsForGroup(baseDir, placeCodes, condition, minISI0dprime)
% computeTypeStatsForGroup  Compute mean/SEM nonzero-ISI hit rate per stimulus type for one group.

    files = getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime);
    if isempty(files)
        S = struct('types', string([]), 'mu', [], 'sem', [], 'nSub', 0);
        return;
    end

    epsilon = 1e-4;
    % First pass: union of types among valid (nonzero-ISI) repeat trials
    allTypes = string([]);
    for i = 1:numel(files)
        T = load(files{i}, 'repeatPosition','stimuli_type');
        rp    = T.repeatPosition;
        stype = string(T.stimuli_type(:));
        valid = ~isnan(rp) & (rp>0);
        allTypes = union(allTypes, unique(stype(valid)));
    end
    if isempty(allTypes)
        S = struct('types', string([]), 'mu', [], 'sem', [], 'nSub', 0);
        return;
    end

    % Subject-by-type hit-rate matrix
    nSub = numel(files);
    nTyp = numel(allTypes);
    M    = nan(nSub, nTyp);
    for i = 1:nSub
        T = load(files{i}, 'repeatPosition','isResponseCorrect','stimuli_type');
        rp    = T.repeatPosition;
        corr  = T.isResponseCorrect;
        stype = string(T.stimuli_type(:));
        valid = ~isnan(rp) & (rp>0);
        for t = 1:nTyp
            mask = valid & (stype==allTypes(t));
            ntr  = sum(mask);
            if ntr>0
                hr = sum(corr(mask)) / ntr;
                M(i,t) = correctRate(hr, epsilon);
            end
        end
    end

    mu  = nanmean(M,1);
    sem = nanstd(M,0,1) ./ sqrt(sum(~isnan(M),1));
    S = struct('types', allTypes(:).', 'mu', mu(:).', 'sem', sem(:).', 'nSub', nSub);
end

% =================== Helper: default legend labels ===================
function labels = defaultLabels(groupPlaceCodes)
% defaultLabels  Build default legend labels from place codes for each group.
    labels = cell(1, numel(groupPlaceCodes));
    for i = 1:numel(groupPlaceCodes)
        pc = groupPlaceCodes{i};
        if any(strcmpi(pc,'ALL')), labels{i} = 'ALL';
        else, labels{i} = strjoin(pc, '+');
        end
    end
end

% =================== Helper: correctRate cap ===================
function x = correctRate(p, epsVal)
% correctRate  Clamp proportion into (eps, 1-eps).
    if nargin<2, epsVal = 1e-4; end
    x = min(max(p, epsVal), 1 - epsVal);
end