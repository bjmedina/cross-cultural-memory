function [stats, items_hit, items_fa, T_hit, T_fa] = intergroupReliabilityScatterText( ...
    baseDir, placeCodesA, placeCodesB, condition, minISI0dprime, outPrefix)
% intergroupReliabilityScatterText
%   Build intergroup scatter plots (A vs B) with item names as text labels
%   for both trial types: hits (nonzero-ISI repeats) and false alarms (firsts).
%
% Inputs:
%   baseDir        : folder with .mat files
%   placeCodesA    : cellstr for Group A (e.g., {'BOS','CAM'} or {'ALL'})
%   placeCodesB    : cellstr for Group B (e.g., {'TSI'} or {'ALL'})
%   condition      : filename match string (e.g., 'Industrial-Nature')
%   minISI0dprime  : numeric filter on participants
%   outPrefix      : optional filename prefix for figure/CSVs (string)
%
% Outputs:
%   stats      : struct with fields hit/fa, each with r, nItems, slope, intercept
%   items_hit  : string vector of aligned items used for hits
%   items_fa   : string vector of aligned items used for FAs
%   T_hit      : table with columns {'item','A','B'} for hits
%   T_fa       : table with columns {'item','A','B'} for FAs
%
% Assumes each .mat has variables (top-level or under `data`):
%   stimulusPresented (string or char array), repeatPosition (numeric, NaN for firsts),
%   isResponseCorrect (logical or 0/1).
%
% Notes:
%   - Item-wise rates are participant means per item, then averaged across participants.
%   - For hits: mean(correct) over nonzero-ISI repeats.
%   - For FAs : mean(1 - correct) over first presentations.

    if nargin < 6 || isempty(outPrefix), outPrefix = 'intergroup-scatter'; end

    % --- Collect participant files per group ---
    filesA = getRecognitionMemFiles(baseDir, placeCodesA, condition, minISI0dprime);
    filesB = getRecognitionMemFiles(baseDir, placeCodesB, condition, minISI0dprime);
    if isempty(filesA) || isempty(filesB)
        error('No files for one or both groups. A=%d, B=%d', numel(filesA), numel(filesB));
    end

    % --- Build per-participant item matrices for both trial types ---
    [items_hit,  Ra_hit,  Rb_hit ] = buildAlignedMatrices(filesA, filesB, 'hit');
    [items_fa,   Ra_fa,   Rb_fa  ] = buildAlignedMatrices(filesA, filesB, 'fa');

    % --- Average across participants (omit NaNs) ---
    [A_hit, B_hit] = meanAcrossParticipants(Ra_hit, Rb_hit);
    [A_fa,  B_fa ] = meanAcrossParticipants(Ra_fa,  Rb_fa );

    % --- Assemble tables for saving/debug ---
    T_hit = table(items_hit(:), A_hit(:), B_hit(:), 'VariableNames', {'item','A','B'});
    T_fa  = table(items_fa(:),  A_fa(:),  B_fa(:),  'VariableNames', {'item','A','B'});

    % --- Compute simple stats for titles/legends ---
    stats = struct();
    stats.hit = fitAndCorr(A_hit, B_hit);
    stats.fa  = fitAndCorr(A_fa,  B_fa );

    % --- Prepare output paths/tags ---
    if any(strcmpi(placeCodesA,'ALL')), placeTagA='ALL';
    else, placeTagA = strjoin(placeCodesA,'_'); end
    if any(strcmpi(placeCodesB,'ALL')), placeTagB='ALL';
    else, placeTagB = strjoin(placeCodesB,'_'); end

    outDir = fullfile(baseDir,'figures',condition);
    if ~exist(outDir,'dir'), mkdir(outDir); end

    % --- Save CSVs of plotted values ---
    writetable(T_hit, fullfile(outDir, sprintf('%s-HITS_%s_vs_%s-%s.csv', outPrefix, placeTagA, placeTagB, safetag(condition))));
    writetable(T_fa,  fullfile(outDir, sprintf('%s-FAS_%s_vs_%s-%s.csv',  outPrefix, placeTagA, placeTagB, safetag(condition))));

    % --- Make figure with two panels (Hits | FAs) ---    % --- Make figure with two panels (Hits | FAs) ---
    f = figure('Color','w','Position',[100 100 1200 520]);
    
    labels_hit = stripFilenames(items_hit);
    labels_fa  = stripFilenames(items_fa);

    % Panel 1
    subplot(1,2,1);

    % Panel 1: Hits
    subplot(1,2,1);
    textScatterLabeled(A_hit, B_hit, labels_hit);
    title(sprintf('HITS  %s vs %s  (r=%.3f, n=%d)\n%s', ...
        placeTagA, placeTagB, stats.hit.r, stats.hit.nItems, condition), ...
        'Interpreter','none');
    addRefAndFit(A_hit, B_hit, stats.hit.slope, stats.hit.intercept);
    xlabel(sprintf('%s mean hit rate', placeTagA)); 
    ylabel(sprintf('%s mean hit rate', placeTagB));
    axis equal; xlim([0 1]); ylim([0 1]); grid on;

    % Panel 2: FAs
    subplot(1,2,2);
    textScatterLabeled(A_fa, B_fa, labels_fa);
    title(sprintf('FALSE ALARMS  %s vs %s  (r=%.3f, n=%d)\n%s', ...
        placeTagA, placeTagB, stats.fa.r, stats.fa.nItems, condition), ...
        'Interpreter','none');
    addRefAndFit(A_fa, B_fa, stats.fa.slope, stats.fa.intercept);
    xlabel(sprintf('%s mean FA rate', placeTagA)); 
    ylabel(sprintf('%s mean FA rate', placeTagB));
    axis equal; xlim([0 1]); ylim([0 1]); grid on;

end

% ============================= Helpers =============================

function fnames = stripFilenames(items)
    fnames = strings(size(items));
    for k = 1:numel(items)
        [~, name, ext] = fileparts(items(k));
        fnames(k) = name + ext;   % keep 'mem_stim_41.wav'
    end
end

function [itemsAB, Ra, Rb] = buildAlignedMatrices(filesA, filesB, trialType)
% Return item intersection and per-participant matrices aligned to it.
    itemsA = unionOfItems(filesA, trialType);
    itemsB = unionOfItems(filesB, trialType);
    [itemsAB, ~, ~] = intersect(itemsA, itemsB, 'stable'); % preserve A's order
    if isempty(itemsAB)
        warning('No shared items for trialType=%s.', trialType);
        itemsAB = string([]);
        Ra = nan(0,0); Rb = nan(0,0);
        return;
    end
    Ra = participantItemRates(filesA, itemsAB, trialType);
    Rb = participantItemRates(filesB, itemsAB, trialType);
end

function [Amean, Bmean] = meanAcrossParticipants(Ra, Rb)
% Average over participants for each item, omitting NaNs.
    if isempty(Ra), Amean = []; else, Amean = mean(Ra, 1, 'omitnan'); end
    if isempty(Rb), Bmean = []; else, Bmean = mean(Rb, 1, 'omitnan'); end
    % Ensure column vectors for downstream use
    Amean = Amean(:); Bmean = Bmean(:);
end

function s = fitAndCorr(x, y)
% Compute Pearson r and OLS line y = m*x + b on valid pairs.
    valid = ~(isnan(x) | isnan(y));
    xv = x(valid); yv = y(valid);
    s = struct('r', NaN, 'nItems', numel(xv), 'slope', NaN, 'intercept', NaN);
    if numel(xv) >= 3
        s.r = corr(xv, yv, 'type', 'Pearson', 'rows', 'pairwise');
        P = polyfit(xv, yv, 1);
        s.slope = P(1); s.intercept = P(2);
    end
end

function textScatterLabeled(x, y, labels)
% Plot item names at (x,y) instead of points; jitter tiny overlaps; clamp to [0,1].
    x = max(0, min(1, x));
    y = max(0, min(1, y));
    hold on;
    % Lightweight collision handling: nudge nearly-identical coords slightly
    [~, idx] = sortrows([x y]);
    x = x(idx); y = y(idx); labels = labels(idx);
    epsJit = 1e-3;
    for i = 2:numel(x)
        if abs(x(i)-x(i-1)) < 2*epsJit && abs(y(i)-y(i-1)) < 2*epsJit
            x(i) = x(i) + epsJit * i;
            y(i) = y(i) + epsJit * i;
        end
    end
    for i = 1:numel(x)
        text(x(i), y(i), labels(i), 'Interpreter','none', ...
            'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
            'FontSize', 9);
    end
    box on;
end

function addRefAndFit(x, y, m, b)
% Draw y=x reference and the OLS fit if available.
    plot([0 1],[0 1],'k:','LineWidth',1); % y=x
    if ~isnan(m) && ~isnan(b)
        xx = linspace(0,1,100);
        yy = m*xx + b;
        plot(xx, yy, '-', 'LineWidth', 1.5);
    end
end

function items = unionOfItems(files, trialType)
% Union of items that qualify for the requested trialType across files.
    items = string([]);
    for i = 1:numel(files)
        [SP, rp] = loadSP_RP(files{i});
        SP = string(SP(:)); rp = rp(:);
        switch lower(trialType)
            case 'hit' % nonzero-ISI repeats
                mask = ~isnan(rp) & rp > 1;
            case 'fa'  % first presentations
                mask = isnan(rp);
            otherwise
                error('trialType must be ''hit'' or ''fa''.');
        end
        if any(mask)
            items = union(items, unique(SP(mask)));
        end
    end
end

function R = participantItemRates(files, itemsAB, trialType)
% Per-participant x item matrix of rates for the requested trialType.
% Hits: mean(correct) over nonzero-ISI repeats for that item.
% FAs : mean(1 - correct) over first presentations for that item.
    nSub   = numel(files);
    nItems = numel(itemsAB);
    R = nan(nSub, nItems);
    for i = 1:nSub
        [SP, rp, ic] = loadSP_RP_IC(files{i});
        SP = string(SP(:)); rp = rp(:); ic = logical(ic(:));
        switch lower(trialType)
            case 'hit'
                mask = ~isnan(rp) & rp > 1;
                if any(mask)
                    [G, ids] = findgroups(SP(mask));
                    val = splitapply(@mean, double(ic(mask)), G);      % hit rate
                    uids = unique(ids);
                    [~, ia, ib] = intersect(itemsAB, uids, 'stable');
                    R(i, ia) = val(ib);
                end
            case 'fa'
                mask = isnan(rp);
                if any(mask)
                    [G, ids] = findgroups(SP(mask));
                    val = splitapply(@mean, 1 - double(ic(mask)), G);  % FA rate
                    uids = unique(ids);
                    [~, ia, ib] = intersect(itemsAB, uids, 'stable');
                    R(i, ia) = val(ib);
                end
        end
    end
end

function [SP, rp] = loadSP_RP(file)
% Load SP and rp from .mat that may store fields at top level or under 'data'.
    Sraw = load(file,'-mat');
    if isfield(Sraw,'data'), D = Sraw.data; else, D = Sraw; end
    SP = D.stimulusPresented; rp = D.repeatPosition;
end

function [SP, rp, ic] = loadSP_RP_IC(file)
% Load SP, rp, ic with same robustness as above.
    Sraw = load(file,'-mat');
    if isfield(Sraw,'data'), D = Sraw.data; else, D = Sraw; end
    SP = D.stimulusPresented; rp = D.repeatPosition; ic = D.isResponseCorrect;
end

function tag = safetag(str)
% Replace spaces/slashes etc. for filenames.
    tag = regexprep(str, '[^A-Za-z0-9_\-]+', '_');
end