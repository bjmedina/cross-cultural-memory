function plotTripleIntergroupGridPerSound(ac, ab, bc, condition, trial_type, baseDir, varargin)
% plotTripleIntergroupGridPerSound
%   Create a grid of small bar plots showing intergroup correlations
%   per sound. Each subplot = one sound, with 3 bars:
%       1. Boston?San Borja
%       2. Boston?Tsimane
%       3. Tsimane?San Borja
%
%   Inputs:
%     ac, ab, bc : outputs from intergroupCorrelationPerSound()
%     condition  : experiment condition name
%     trial_type : 'hit' or 'fa'
%     baseDir    : directory for saving figure
%
%   Optional Name/Value pairs:
%     'MaxSounds' : number of sounds to plot (default = 16)
%     'SortByMean': true/false (default = true)
%     'ShowCI'    : true/false (default = false)
%
%   Bryan Medina ? Bolivia 2025

    % -----------------------------
    % Parameters
    % -----------------------------
    p = inputParser;
    addParameter(p,'MaxSounds',16,@isscalar);
    addParameter(p,'SortByMean',true,@islogical);
    addParameter(p,'ShowCI',false,@islogical);
    parse(p,varargin{:});
    nShow = p.Results.MaxSounds;
    sortByMean = p.Results.SortByMean;
    showCI = p.Results.ShowCI;

    % -----------------------------
    % Prepare data
    % -----------------------------
    pairs = {'BOS?SAN','BOS?TSI','TSI?SAN'};
    nItems = min([ac.nItems, ab.nItems, bc.nItems]);
    nShow = min(nShow, nItems);

    rMat = [ac.r_raw(1:nShow); ab.r_raw(1:nShow); bc.r_raw(1:nShow)]';  % [nShow × 3]
    meanVals = mean(rMat,2,'omitnan');

    % Sort sounds by mean correlation
    if sortByMean
        [~, order] = sort(meanVals,'descend');
    else
        order = 1:nShow;
    end
    rMat = rMat(order,:);
    itemLabels = string(ac.items(order));

    % -----------------------------
    % Grid layout
    % -----------------------------
    nCols = ceil(sqrt(nShow));
    nRows = ceil(nShow / nCols);

    figure('Color','w','Position',[100 100 1300 800]);

    for i = 1:nShow
        subplot(nRows,nCols,i);
        vals = rMat(i,:);
        bar(vals, 'FaceAlpha', 0.85);
        colormap([0.7 0.8 1.0; 0.4 0.55 0.9; 0.2 0.35 0.7]);
        ylim([0 1]);
        title(sprintf('%s', itemLabels(i)), 'Interpreter','none','FontSize',9);
        set(gca,'XTick',1:3,'XTickLabel',pairs,'XTickLabelRotation',25);
        grid on; box off;

        % Optional CI bars
        if showCI && isfield(ac,'ci')
            ciMat = [ac.ci(:,order(i)), ab.ci(:,order(i)), bc.ci(:,order(i))];
            hold on;
            for j = 1:3
                errLow = vals(j) - ciMat(1,j);
                errHigh = ciMat(2,j) - vals(j);
                errorbar(j, vals(j), errLow, errHigh, 'k', 'LineStyle','none', 'LineWidth',1);
            end
            hold off;
        end
    end

    % Global title
    sgtitle(sprintf('Per-sound Intergroup %s Correlations ? %s', upper(trial_type), condition), ...
        'FontWeight','bold','FontSize',14);

    % -----------------------------
    % Save figure
    % -----------------------------
    outDir = UTILS_buildOutputDir(baseDir, condition);
    fname = sprintf('grid_intergroup_perSound_%s_%s.png', trial_type, condition);
    saveas(gcf, fullfile(outDir, fname));
    fprintf('Saved per-sound grid of intergroup correlations to %s\n', fullfile(outDir, fname));
end