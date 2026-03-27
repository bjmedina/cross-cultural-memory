function plotTripleIntergroupGridPerSound_sortedByAsymmetry(ac, ab, bc, condition, trial_type, baseDir, varargin)
% plotTripleIntergroupGridPerSound_sortedByAsymmetry
%   Grid of per-sound bar plots sorted by cross-group asymmetry:
%       score = |(BOS?SAN - BOS?TSI)| + |(TSI?SAN - BOS?TSI)|
%
%   Each subplot = one sound with 3 bars:
%       1. BOS?SAN
%       2. BOS?TSI
%       3. TSI?SAN
%
%   Bryan Medina ? Bolivia 2025

    % -----------------------------
    % Parameters
    % -----------------------------
    p = inputParser;
    addParameter(p,'MaxSounds',16,@isscalar);
    addParameter(p,'ShowCI',false,@islogical);
    parse(p,varargin{:});
    nShow = p.Results.MaxSounds;
    showCI = p.Results.ShowCI;

    % -----------------------------
    % Prepare data
    % -----------------------------
    pairs = {'BOS?SAN','BOS?TSI','TSI?SAN'};
    nItems = min([ac.nItems, ab.nItems, bc.nItems]);
    nShow = min(nShow, nItems);

    % Extract correlations per sound
    r_ac = ac.r_raw(:);
    r_ab = ab.r_raw(:);
    r_bc = bc.r_raw(:);

    % Compute asymmetry score
    asymScore = abs(r_ac - r_ab) + abs(r_bc - r_ab);

    % Sort by descending asymmetry
    [~, order] = sort(asymScore, 'descend');

    % Keep top nShow
    order = order(1:nShow);
    rMat = [r_ac(order), r_ab(order), r_bc(order)];
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
        bar(vals,'FaceAlpha',0.85);
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
                errorbar(j, vals(j), errLow, errHigh, 'k', 'LineStyle','none','LineWidth',1);
            end
            hold off;
        end
    end

    % Global title
    sgtitle(sprintf('Per-sound Intergroup %s Correlations (sorted by asymmetry) ? %s', ...
        upper(trial_type), condition), 'FontWeight','bold','FontSize',14);

    % -----------------------------
    % Save figure
    % -----------------------------
    outDir = UTILS_buildOutputDir(baseDir, condition);
    fname = sprintf('grid_intergroup_perSound_sortedByAsymmetry_%s_%s.png', trial_type, condition);
    saveas(gcf, fullfile(outDir, fname));
    fprintf('Saved asymmetry-sorted per-sound grid plot to %s\n', fullfile(outDir, fname));

    % -----------------------------
    % Console summary
    % -----------------------------
    fprintf('\n=== Top %d asymmetric sounds (%s) ===\n', nShow, trial_type);
    T = table(itemLabels(:), r_ac(order), r_ab(order), r_bc(order), asymScore(order), ...
        'VariableNames', {'Item','r_BOS_SAN','r_BOS_TSI','r_TSI_SAN','AsymScore'});
    disp(T(1:min(10,end),:));
end