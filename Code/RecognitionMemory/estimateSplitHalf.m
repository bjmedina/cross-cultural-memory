function [mean_r, std_r] = estimateSplitHalf(data, nSplits)
    n = size(data,1);
    rs = nan(nSplits,1);
    for s = 1:nSplits
        idx = randperm(n);
        half1 = data(idx(1:floor(n/2)), :);
        half2 = data(idx(floor(n/2)+1:end), :);

        m1 = nanmean(half1, 1);
        m2 = nanmean(half2, 1);

        valid = ~(isnan(m1) | isnan(m2));
        if sum(valid) < 2
            rs(s) = NaN;
        else
            rs(s) = corr(m1(valid)', m2(valid)', 'rows', 'complete');
        end
    end
    mean_r = mean(rs, 'omitnan');
    std_r  = std(rs, 'omitnan');
    
    % -----------------------------
    % Optional diagnostic: visualize distribution of split-half r's
    % -----------------------------
    figure('Color','w');
    histogram(rs, 15, 'FaceColor',[0.2 0.4 0.8], 'EdgeColor','none', 'FaceAlpha',0.7);
    xlabel('Split-half correlation (r)');
    ylabel('Count');
    title(sprintf('Distribution of split-half reliabilities (nSplits = %d)', nSplits));
    grid on; box off;

    % annotate mean ± std
    xline(mean_r, 'k-', 'LineWidth',1.5);
    xline(mean_r + std_r, '--k', 'LineWidth',1);
    xline(mean_r - std_r, '--k', 'LineWidth',1);
    text(mean_r, max(ylim)*0.9, sprintf('mean = %.3f ± %.3f', mean_r, std_r), ...
         'HorizontalAlignment','center', 'FontSize',10, 'FontWeight','bold');
end