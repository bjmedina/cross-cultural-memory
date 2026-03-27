function [mean_r, std_r, rs] = estimateSplitHalfFlexible(data, nSplits, splitDim)
% estimateSplitHalfFlexible
%   Compute split-half reliability across participants or stimuli.
%
%   [mean_r, std_r, rs] = estimateSplitHalfFlexible(data, nSplits, splitDim)
%
%   splitDim = 1 ? split across participants (default)
%   splitDim = 2 ? split across stimuli
%
%   Bryan Medina ? Bolivia 2025

    if nargin < 3, splitDim = 1; end
    nSplits = max(1, nSplits);
    [nSub, nItems] = size(data);
    rs = nan(nSplits, 1);

    for s = 1:nSplits
        switch splitDim
            case 1  % split across participants
                idx = randperm(nSub);
                half1 = data(idx(1:floor(nSub/2)), :);
                half2 = data(idx(floor(nSub/2)+1:end), :);
                m1 = nanmean(half1, 1);
                m2 = nanmean(half2, 1);

            case 2  % split across stimuli
                idx = randperm(nItems);
                half1 = data(:, idx(1:floor(nItems/2)));
                half2 = data(:, idx(floor(nItems/2)+1:end));
                m1 = nanmean(half1, 2);
                m2 = nanmean(half2, 2);

            otherwise
                error('splitDim must be 1 (participants) or 2 (stimuli).');
        end

        % ensure column vectors
        m1 = m1(:); 
        m2 = m2(:);

        % only keep valid entries
        valid = ~(isnan(m1) | isnan(m2));
        if sum(valid) < 3
            rs(s) = NaN;
            continue
        end

        try
            r_temp = corr(m1(valid), m2(valid), 'Rows', 'pairwise');
            if ~isempty(r_temp) && ~isnan(r_temp)
                rs(s) = r_temp;
            end
        catch
            rs(s) = NaN;
        end
    end

    % summarize
    mean_r = mean(rs, 'omitnan');
    std_r  = std(rs, 'omitnan');

    % diagnostic histogram
    if nSplits > 10
        figure('Color','w');
        histogram(rs, 20, 'FaceColor',[0.2 0.4 0.8], 'EdgeColor','none', 'FaceAlpha',0.75);
        xlabel('Split-half correlation (r)');
        ylabel('Count');
        title(sprintf('Distribution of split-half r (splitDim=%d, nSplits=%d)', splitDim, nSplits));
        grid on; box off;
        xline(mean_r, 'k-', 'LineWidth',1.5);
        xline(mean_r+std_r, '--k', 'LineWidth',1);
        xline(mean_r-std_r, '--k', 'LineWidth',1);
    end
end

% function [mean_r, std_r, rs] = estimateSplitHalfFlexible(data, nSplits, splitDim)
% % estimateSplitHalfFlexible
% %   Compute split-half reliability either across participants (rows)
% %   or across stimuli (columns).
% %
% %   [mean_r, std_r, rs] = estimateSplitHalfFlexible(data, nSplits, splitDim)
% %
% %   Inputs:
% %     data     - matrix [nSub × nItems], with NaNs for missing entries
% %     nSplits  - number of random splits (e.g. 1000)
% %     splitDim - dimension to split along:
% %                  1 = split across participants (default)
% %                  2 = split across stimuli
% %
% %   Outputs:
% %     mean_r   - mean split-half correlation
% %     std_r    - standard deviation of r across splits
% %     rs       - vector of all split-half correlations
% %
% %   Bryan Medina ? Bolivia 2025
% 
%     if nargin < 3, splitDim = 1; end  % default: split across participants
%     nSplits = max(1, nSplits);
% 
%     % Determine dimension sizes
%     [nSub, nItems] = size(data);
%     rs = nan(nSplits, 1);
% 
%     for s = 1:nSplits
%         switch splitDim
%             case 1  % split across participants
%                 idx = randperm(nSub);
%                 half1 = data(idx(1:floor(nSub/2)), :);
%                 half2 = data(idx(floor(nSub/2)+1:end), :);
% 
%                 m1 = nanmean(half1, 1);  % mean across participants
%                 m2 = nanmean(half2, 1);
% 
%             case 2  % split across stimuli
%                 idx = randperm(nItems);
%                 half1 = data(:, idx(1:floor(nItems/2)));
%                 half2 = data(:, idx(floor(nItems/2)+1:end));
% 
%                 m1 = nanmean(half1, 2);  % mean across stimuli
%                 m2 = nanmean(half2, 2);
% 
%             otherwise
%                 error('splitDim must be 1 (participants) or 2 (stimuli).');
%         end
% 
%         % compute correlation between halves
%         valid = ~(isnan(m1) | isnan(m2));
%         if sum(valid) < 2
%             rs(s) = NaN;
%         else
%             rs(s) = corr(m1(valid), m2(valid), 'Rows', 'complete');
%         end
%     end
% 
%     % summarize
%     mean_r = mean(rs, 'omitnan');
%     std_r  = std(rs, 'omitnan');
% 
%     % -----------------------------
%     % visualization
%     % -----------------------------
%     figure('Color','w');
%     histogram(rs, 20, 'FaceColor',[0.2 0.4 0.8], 'EdgeColor','none', 'FaceAlpha',0.75);
%     xlabel('Split-half correlation (r)');
%     ylabel('Count');
%     if splitDim==1
%         title(sprintf('Participant split-half reliabilities (nSplits=%d)', nSplits));
%     else
%         title(sprintf('Stimulus split-half reliabilities (nSplits=%d)', nSplits));
%     end
%     grid on; box off;
% 
%     % annotate mean ± std
%     xline(mean_r, 'k-', 'LineWidth',1.5);
%     xline(mean_r + std_r, '--k', 'LineWidth',1);
%     xline(mean_r - std_r, '--k', 'LineWidth',1);
%     ylimCurr = ylim;
%     text(mean_r, ylimCurr(2)*0.9, sprintf('mean = %.3f ± %.3f', mean_r, std_r), ...
%          'HorizontalAlignment','center', 'FontSize',10, 'FontWeight','bold');
% end