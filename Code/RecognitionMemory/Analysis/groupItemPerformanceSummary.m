function [itemStats, dprimeStats, summary] = groupItemPerformanceSummary( ...
    baseDir, placeCodes, condition, minISI0dprime, trialType, varargin)
% groupItemPerformanceSummary
%   Summarize per-item performance within a single group, now including
%   itemwise d' (computed from per-item hit & FA rates).
%
% Outputs:
%   itemStats    : table for hit/FA (depending on trialType input)
%   dprimeStats  : table of itemwise d'
%   summary      : struct with top/bottom items for mean, FA, and d'
%
% Bryan Medina ? Oct 2025 (extended Nov 2025)

    % ---- optional args ----
    p = inputParser;
    addParameter(p, 'TopK', 10, @(x)isnumeric(x)&&isscalar(x));
    addParameter(p, 'ShowPlot', true, @islogical);
    parse(p, varargin{:});
    topK = p.Results.TopK;
    showPlot = p.Results.ShowPlot;

    % ---- load files ----
    files = getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime);
    if isempty(files)
        warning('No valid files found for group.');
        itemStats = table(); dprimeStats = table(); summary = struct(); return;
    end

    % ---- union of all items ----
    items = unionOfItems(files, 'hit');   % ensures all items appear
    nItems = numel(items);

    % ---- compute per-item hit and FA matrices ----
    R_hit = participantItemRates(files, items, 'hit');
    R_fa  = participantItemRates(files, items, 'fa');
    
    % ==========================
    % Debug: two random splits for chosen trialType
    % ==========================
    figure('Color','w','Name','Two Random Splits: Debug','Position',[300 300 600 600]);

    nP = size(R_hit,1);
    half = floor(nP/2);

    idx = randperm(nP);
    g1 = idx(1:half);
    g2 = idx(half+1:2*half);

    switch lower(trialType)
        case 'hit'
            % split-hit data
            v1 = mean(R_hit(g1,:), 1, 'omitnan');
            v2 = mean(R_hit(g2,:), 1, 'omitnan');
            xlab = 'Hit Rate (Split A)';
            ylab = 'Hit Rate (Split B)';

        case 'fa'
            % split-false alarm data
            v1 = mean(R_fa(g1,:), 1, 'omitnan');
            v2 = mean(R_fa(g2,:), 1, 'omitnan');
            xlab = 'False Alarm Rate (Split A)';
            ylab = 'False Alarm Rate (Split B)';

        case 'dprime'
            % compute dprime in each split
            eps = 1e-2;

            hit1 = mean(R_hit(g1,:), 1, 'omitnan');
            fa1  = mean(R_fa(g1,:), 1, 'omitnan');
            hit1 = min(max(hit1, eps), 1-eps);
            fa1  = min(max(fa1,  eps), 1-eps);
            v1 = norminv(hit1) - norminv(fa1);

            hit2 = mean(R_hit(g2,:), 1, 'omitnan');
            fa2  = mean(R_fa(g2,:), 1, 'omitnan');
            hit2 = min(max(hit2, eps), 1-eps);
            fa2  = min(max(fa2,  eps), 1-eps);
            v2 = norminv(hit2) - norminv(fa2);

            xlab = 'd'' (Split A)';
            ylab = 'd'' (Split B)';
    end

    % Scatter plot
    scatter(v1, v2, 35, 'filled'); hold on;
    plot([min(v1) max(v1)], [min(v1) max(v1)], 'k--'); % diagonal
    axis square;

    xlabel(xlab);
    ylabel(ylab);

    r_dbg = corr(v1(:), v2(:), 'rows','complete');
    title(sprintf('Split?Split %s Reliability (single draw): r = %.2f', ...
          char(upper(trialType)), r_dbg));

    grid on;    

    % ---- per-item means ----
    hitMean = mean(R_hit, 1, 'omitnan');
    hitSEM  = std(R_hit, 0, 1, 'omitnan') ./ sqrt(sum(~isnan(R_hit),1));
    hitN    = sum(~isnan(R_hit),1);

    faMean  = mean(R_fa, 1, 'omitnan');
    faSEM   = std(R_fa, 0, 1, 'omitnan') ./ sqrt(sum(~isnan(R_fa),1));
    faN     = sum(~isnan(R_fa),1);

    % ---- itemwise d' computation ----
    eps = 1e-2;
    hitClip = min(max(hitMean, eps), 1-eps);
    faClip  = min(max(faMean,  eps), 1-eps);

    dprimeVals = norminv(hitClip) - norminv(faClip);

    % ---- short names ----
    shortNames = cellfun(@(x) string(extractAfter(x, findLastFileSep(x))), ...
                         cellstr(items), 'UniformOutput', true);

    % ---- create both tables ----
    itemStats = table(shortNames(:), hitMean(:), hitSEM(:), hitN(:), ...
                      faMean(:),  faSEM(:),  faN(:), ...
                      'VariableNames', ...
                      {'Item','HitMean','HitSEM','HitN','FAMean','FASEM','FAN'});

    dprimeStats = table(shortNames(:), dprimeVals(:), ...
                        'VariableNames', {'Item','Dprime'});

    % ---- sort by trialType for main output ----
    switch lower(trialType)
        case 'hit'
            [~, idx] = sort(itemStats.HitMean, 'descend');
        case 'fa'
            [~, idx] = sort(itemStats.FAMean, 'ascend'); % lower FA is better
        case 'dprime'
            [~, idx] = sort(dprimeStats.Dprime, 'ascend');
        otherwise
            error('trialType must be ''hit'' or ''fa''.');
    end
    itemStats = itemStats(idx,:);

    % ---- summary ----
    summary = struct();
    summary.group     = strjoin(placeCodes, '-');
    summary.condition = condition;

    % Determine the metric of interest and sorted tables
    switch lower(trialType)
        case 'hit'
            metric = itemStats.HitMean;
            sortedTable = itemStats; % already sorted by HitMean earlier
            summary.metric_name = 'HitMean';

        case 'fa'
            metric = itemStats.FAMean;
            sortedTable = itemStats; % already sorted by FAMean earlier
            summary.metric_name = 'FAMean';

        case 'dprime'
            metric = dprimeStats.Dprime;
            sortedTable = dprimeStats; % already sorted by Dprime earlier
            summary.metric_name = 'Dprime';
    end

    % Top and bottom K for the chosen metric
    summary.top    = sortedTable(1:min(topK, nItems), :);
    summary.bottom = sortedTable(max(1, nItems - topK + 1):nItems, :);

    % For convenience, also record all three sorted lists
    summary.top_hit    = itemStats(1:min(topK,nItems),:);
    summary.bot_hit    = itemStats(max(1,nItems-topK+1):nItems,:);

    summary.top_dprime = dprimeStats(1:min(topK,nItems),:);
    summary.bot_dprime = dprimeStats(max(1,nItems-topK+1):nItems,:);

    % ---- reliabilities ----
    summary.dp_reliability = dprimeVectorReliability(R_hit, R_fa);
    summary.hit_reliability = rateVectorReliability(R_hit);
    summary.fa_reliability  = rateVectorReliability(R_fa);

    summary.overall_hit_mean = mean(hitMean,'omitnan');
    summary.overall_fa_mean  = mean(faMean,'omitnan');
    summary.overall_dprime   = mean(dprimeVals,'omitnan');

    % ---- visualization (optional) ----
    if showPlot
        figure('Color','w','Name','Itemwise Summary','Position',[300 200 900 700]);

        % =======================
        % 1. Histogram (depends on trialType)
        % =======================
        subplot(3,1,1);

        switch lower(trialType)
            case 'hit'
                vals = itemStats.HitMean;
                label = "Itemwise Hit Rate";
                mainTop = summary.top_hit;
                mainBot = summary.bot_hit;
            case 'fa'
                vals = itemStats.FAMean;
                label = "Itemwise False-Alarm Rate";
                mainTop = summary.top_hit;   % 'top' means "better" ? lowest FA
                mainBot = summary.bot_hit;
            case 'dprime'
                vals = dprimeVals;
                label = "Itemwise d'";
                mainTop = summary.top_dprime;
                mainBot = summary.bot_dprime;
        end

        histogram(vals, 'BinWidth',0.05, 'FaceColor',[0.3 0.6 0.8]);
        xlabel(label);
        ylabel('Count');
        title(sprintf('%s: %s (%s)', summary.group, condition, label), 'Interpreter','none');
        grid on;

        % Optional reliability annotation
        if strcmpi(trialType,'hit')
            rel = summary.hit_reliability;
        elseif strcmpi(trialType,'fa')
            rel = summary.fa_reliability;
        else
            rel = summary.dp_reliability;
        end

        rel_text = sprintf('Split-half reliability: r = %.2f (CI [%.2f, %.2f])', ...
            rel.mean_r, rel.ci(1), rel.ci(2));
        text(0.02, 0.92, rel_text, 'Units','normalized', 'FontSize',9);

        % =======================
        % 2. Top K by trialType
        % =======================
        cleanTop = strrep(mainTop.Item, '_', ' ');
        subplot(3,1,2);

        switch lower(trialType)
            case 'hit'
                bar(mainTop.HitMean, 'FaceColor',[0.2 0.7 0.3]);
                ylabel("Hit Rate");
            case 'fa'
                bar(mainTop.FAMean, 'FaceColor',[0.2 0.7 0.3]);
                ylabel("False-Alarm Rate");
            case 'dprime'
                bar(mainTop.Dprime, 'FaceColor',[0.2 0.7 0.3]);
                ylabel("d'");
        end

        set(gca,'XTick',1:numel(cleanTop), ...
                'XTickLabel',cleanTop, ...
                'XTickLabelRotation',45, ...
                'TickLabelInterpreter','none');

        title(sprintf('Top %d Items by %s', topK, label));
        grid on;

        % =======================
        % 3. Bottom K by trialType
        % =======================
        cleanBot = strrep(mainBot.Item, '_', ' ');
        subplot(3,1,3);

        switch lower(trialType)
            case 'hit'
                bar(mainBot.HitMean, 'FaceColor',[0.8 0.3 0.3]);
                ylabel("Hit Rate");
            case 'fa'
                bar(mainBot.FAMean, 'FaceColor',[0.8 0.3 0.3]);
                ylabel("False-Alarm Rate");
            case 'dprime'
                bar(mainBot.Dprime, 'FaceColor',[0.8 0.3 0.3]);
                ylabel("d'");
        end

        set(gca,'XTick',1:numel(cleanBot), ...
                'XTickLabel',cleanBot, ...
                'XTickLabelRotation',45, ...
                'TickLabelInterpreter','none');

        title(sprintf('Bottom %d Items by %s', topK, label));
        grid on;

        % spacing improvement
        set(gcf, 'PaperPositionMode', 'auto');
        drawnow;
    end
end

% ---------- helper ----------
function part = findLastFileSep(pathStr)
    idxSlash = find(pathStr=='/' | pathStr=='\', 1, 'last');
    part = iff(isempty(idxSlash), 0, idxSlash);
end

function out = iff(cond,a,b)
    if cond, out=a; else, out=b; end
end

function rel = rateVectorReliability(R, nSplits)
% rateVectorReliability
%   Split-half reliability for an itemwise rate vector (hits OR false alarms).
%
% Inputs:
%   R        : participants x items matrix of hit or FA rates
%   nSplits  : number of random splits (default 1000)
%
% Outputs (struct rel):
%   .raw_r   : array of split-half correlations
%   .mean_r  : mean correlation
%   .ci      : 95% confidence interval
%   .sb      : Spearman?Brown corrected reliability

    if nargin < 2
        nSplits = 1000;
    end

    R   = double(R);
    nP  = size(R,1);
    half = floor(nP/2);

    raw_r = nan(nSplits,1);

    for s = 1:nSplits
        idx = randperm(nP);
        g1 = idx(1:half);
        g2 = idx(half+1:2*half);

        % itemwise mean rates for each half
        v1 = mean(R(g1,:), 1, 'omitnan');
        v2 = mean(R(g2,:), 1, 'omitnan');

        % correlation across items
        r = corr(v1(:), v2(:), 'rows', 'complete');
        raw_r(s) = r;
    end

    rel.raw_r  = raw_r;
    rel.mean_r = mean(raw_r, 'omitnan');

    % use quantile or prctile depending on your MATLAB
    rel.ci = quantile(raw_r, [0.025 0.975]);

    rel.sb = (2 * rel.mean_r) / (1 + rel.mean_r);
end