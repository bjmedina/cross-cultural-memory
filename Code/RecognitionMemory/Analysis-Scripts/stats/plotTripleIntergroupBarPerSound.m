function plotTripleIntergroupBarPerSound(ac, ab, bc, condition, trial_type, baseDir, varargin)
% plotTripleIntergroupBarPerSound
%   Plot per-sound intergroup correlations for three group pairs (works in MATLAB 2018).
%
%   Each sound (stimulus) has 3 bars:
%       1. Boston?San Borja
%       2. Boston?Tsimane
%       3. Tsimane?San Borja
%
%   Inputs:
%     ac, ab, bc : outputs from intergroupCorrelationPerSound()
%     condition  : string label (e.g., 'Globalized-Music')
%     trial_type : 'hit' or 'fa'
%     baseDir    : directory for saving figure
%
%   Optional Name/Value pairs:
%     'ShowCI'    : true/false (default = false)
%     'MaxSounds' : number of sounds to show (default = Inf)
%     'SortByMean': true/false (default = true)
%
%   Bryan Medina ? Bolivia 2025

    % -----------------------------
    % Parameters
    % -----------------------------
    p = inputParser;
    addParameter(p,'ShowCI',false,@islogical);
    addParameter(p,'MaxSounds',Inf,@isscalar);
    addParameter(p,'SortByMean',true,@islogical);
    parse(p,varargin{:});
    showCI    = p.Results.ShowCI;
    maxSounds = p.Results.MaxSounds;
    sortByMean = p.Results.SortByMean;

    % -----------------------------
    % Prepare data
    % -----------------------------
    pairs = {'Boston?San Borja','Boston?Tsimane','Tsimane?San Borja'};
    nItems = min([ac.nItems, ab.nItems, bc.nItems]);
    nShow  = min(nItems, maxSounds);

    rawVals = [ac.r_raw(1:nShow); ab.r_raw(1:nShow); bc.r_raw(1:nShow)]';  % [nSounds × 3]

    if isfield(ac,'sem')
        semVals = [ac.sem(1:nShow); ab.sem(1:nShow); bc.sem(1:nShow)]';
    else
        semVals = nan(size(rawVals));
    end

    if showCI && isfield(ac,'ci')
        ciLow  = [ac.ci(1,1:nShow); ab.ci(1,1:nShow); bc.ci(1,1:nShow)]';
        ciHigh = [ac.ci(2,1:nShow); ab.ci(2,1:nShow); bc.ci(2,1:nShow)]';
    else
        ciLow = nan(size(rawVals));
        ciHigh = nan(size(rawVals));
    end

    % Sort by average correlation if desired
    meanAcrossPairs = mean(rawVals,2,'omitnan');
    if sortByMean
        [~, order] = sort(meanAcrossPairs,'descend');
        rawVals = rawVals(order,:);
        semVals = semVals(order,:);
        ciLow   = ciLow(order,:);
        ciHigh  = ciHigh(order,:);
    else
        order = 1:nShow;
    end

    % -----------------------------
    % Plot grouped bars
    % -----------------------------
    figure('Color','w','Position',[100 100 1100 450]); hold on;
    b = bar(rawVals,'grouped','FaceAlpha',0.85);
    b(1).FaceColor = [0.7 0.8 1.0];
    b(2).FaceColor = [0.4 0.55 0.9];
    b(3).FaceColor = [0.2 0.35 0.7];

    % --- compute X coordinates manually (for MATLAB 2018) ---
    ngroups = size(rawVals,1);
    nbars   = size(rawVals,2);
    groupwidth = min(0.8, nbars/(nbars + 1.5));

    for j = 1:nbars
        % center of each bar within its group
        x = (1:ngroups) - groupwidth/2 + (2*j-1) * groupwidth / (2*nbars);

        % Error bars
        if showCI
            errLow = rawVals(:,j) - ciLow(:,j);
            errHigh = ciHigh(:,j) - rawVals(:,j);
            errorbar(x, rawVals(:,j), errLow, errHigh, ...
                     'k','LineStyle','none','LineWidth',1.1);
        else
            errorbar(x, rawVals(:,j), semVals(:,j), ...
                     'k','LineStyle','none','LineWidth',1.1);
        end
    end

    % -----------------------------
    % Axis & labels
    % -----------------------------
    xlabel('Sounds (sorted by mean correlation)');
    ylabel('Intergroup correlation (r)');
    title(sprintf('Per-sound Intergroup %s Correlations ? %s', upper(trial_type), condition));
    legend(pairs,'Location','northoutside','Orientation','horizontal');
    ylim([0 1]);
    xlim([0.5 nShow+0.5]);
    xticks(1:nShow);

    if isfield(ac,'items')
        xticklabels(string(ac.items(order)));
        xtickangle(45);
    else
        xticklabels(string(1:nShow));
    end

    grid on; box off;
    hold off;

    % -----------------------------
    % Save figure
    % -----------------------------
    outDir = UTILS_buildOutputDir(baseDir, condition);
    fname = sprintf('triple_intergroup_perSound_%s_%s.png', trial_type, condition);
    saveas(gcf, fullfile(outDir, fname));
    fprintf('Saved per-sound triple intergroup plot to %s\n', fullfile(outDir, fname));

    % -----------------------------
    % Summary in console
    % -----------------------------
    meanCorrs = mean(rawVals,'omitnan');
    fprintf('\n=== Mean correlations across sounds (%s) ===\n', trial_type);
    fprintf('Boston?San Borja: %.3f | Boston?Tsimane: %.3f | Tsimane?San Borja: %.3f\n', ...
        meanCorrs(1), meanCorrs(2), meanCorrs(3));
end