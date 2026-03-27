function [rBoot, summary, itemsShared, globalMinN] = intergroupCorrelationBootstrap( ...
    baseDir, placeCodesA, placeCodesB, condition, minISI0dprime, nBoot, trialType, varargin)
% intergroupCorrelationBootstrap
%   Cross-group itemwise correlation using global equal-N resampling.
%
% For groups A and B:
%   - Each group has responses to N sounds (may differ per subject)
%   - Compute globalMinN = min_i min(n_A,i, n_B,i)
%   - For each bootstrap:
%       1. Sample globalMinN participants (with replacement) per group.
%       2. For each sound:
%            a. Use only sampled participants who have data.
%            b. If < globalMinN usable responses, resample existing
%               responses for that sound (within group) to reach globalMinN.
%       3. Compute mean response per sound per group.
%       4. Compute Spearman correlation across sounds.
%
% Inputs:
%   baseDir, placeCodesA/B, condition, minISI0dprime, nBoot, trialType
%
% Optional name/value:
%   'RngSeed'   : integer for reproducibility (default = [])
%
% Outputs:
%   rBoot       : nBoot x 1 vector of Spearman correlations
%   summary     : struct with r_mean, r_median, r_ci
%   itemsShared : shared stimulus IDs
%   globalMinN  : minimum number of responses per sound across groups

    % ---------- optional args ----------
    p = inputParser;
    addParameter(p, 'RngSeed', [], @(x)isempty(x) || isnumeric(x));
    addParameter(p, 'GlobalMinN', [], @(x)isempty(x) || isnumeric(x) && isscalar(x));
    parse(p, varargin{:});
    if ~isempty(p.Results.RngSeed)
        rng(p.Results.RngSeed);
    end

    % ---------- get files ----------
    filesA = getRecognitionMemFiles(baseDir, placeCodesA, condition, minISI0dprime);
    filesB = getRecognitionMemFiles(baseDir, placeCodesB, condition, minISI0dprime);
    if isempty(filesA) || isempty(filesB)
        warning('No files for one or both groups.');
        rBoot = nan(nBoot,1); summary = struct(); itemsShared = string([]); globalMinN = NaN; return;
    end

    % ---------- shared items ----------
    itemsA = unionOfItems(filesA, trialType);
    itemsB = unionOfItems(filesB, trialType);
    [itemsShared, ~, ~] = intersect(itemsA, itemsB, 'stable');
    nItems = numel(itemsShared);
    if nItems < 3
        warning('Too few shared items.');
        rBoot = nan(nBoot,1); summary = struct(); globalMinN = NaN; return;
    end

    % ---------- participant × item response matrices ----------
    Ra = participantItemRates(filesA, itemsShared, trialType);
    Rb = participantItemRates(filesB, itemsShared, trialType);
    nA = size(Ra,1); nB = size(Rb,1);

    
    if isempty(p.Results.GlobalMinN)
        nAvailA = sum(~isnan(Ra), 1);
        nAvailB = sum(~isnan(Rb), 1);

        globalMinN = min([nAvailA nAvailB]);
    else
        globalMinN = p.Results.GlobalMinN;
    end

    
    minParticipants = min([nA, nB]);
    % ---------- bootstrap ----------
    rBoot = nan(nBoot,1);
    for b = 1:nBoot
        
        % Step 1: sample participants (with replacement)
        sampA = randi(nA, [minParticipants, 1]);
        sampB = randi(nB, [minParticipants, 1]);

        meanA = nan(1, nItems);
        meanB = nan(1, nItems);

        % Step 2: compute per-item means
        for j = 1:nItems
            valsA = Ra(sampA, j); valsA = valsA(~isnan(valsA));
            valsB = Rb(sampB, j); valsB = valsB(~isnan(valsB));

            %If fewer than globalMinN, resample existing responses to fill in
            if numel(valsA) < minParticipants && ~isempty(valsA)
                to_add = valsA(randi(numel(valsA), [minParticipants-size(valsA,1),1]));
                valsA = cat(1, valsA, to_add);
                %valsA = valsA(randi(numel(valsA), [nA, 1]));
            end

            if numel(valsB) < minParticipants && ~isempty(valsB)
                to_add = valsB(randi(numel(valsB), [minParticipants-size(valsB,1),1]));
                valsB = cat(1, valsB, to_add);
                %valsB = valsB(randi(numel(valsB), [nB, 1]));
            end

            if isempty(valsA) || isempty(valsB)
                continue;
            end

            meanA(j) = mean(valsA, 'omitnan');
            meanB(j) = mean(valsB, 'omitnan');
        end

        % Step 3: correlate across items
        valid = ~isnan(meanA) & ~isnan(meanB);
        if nnz(valid) >= 3
            rBoot(b) = corr(meanA(valid).', meanB(valid).', 'type','Spearman', 'rows','pairwise');
            if rBoot(b) >= 0.9
                display(rBoot(b));
            end
        end
    end
    
    %
    
    % ---------- true mean ----------
    % Step 1: 
    true_meanA = nan(1, nItems);
    true_meanB = nan(1, nItems);

    % Step 2: compute per-item means
    for j = 1:nItems
        valsA = Ra(:, j); valsA = valsA(~isnan(valsA));
        valsB = Rb(:, j); valsB = valsB(~isnan(valsB));
        
        if isempty(valsA) || isempty(valsB)
            continue;
        end

        true_meanA(j) = mean(valsA, 'omitnan');
        true_meanB(j) = mean(valsB, 'omitnan');
    end

    % Step 3: correlate across items
    true_mean = corr(true_meanA(valid).', true_meanB(valid).', 'type','Spearman', 'rows','pairwise');

    % ---------- summarize ----------
    summary = struct();
    % need to fix this, because the MEAN should be the true mean and 
    summary.r_mean   = mean(true_mean, 'omitnan');
    summary.r_median = median(rBoot, 'omitnan');
    summary.r_ci     = quantile(rBoot(~isnan(rBoot)), [0.025 0.975]);

    % ---------- diagnostic plot ----------
    figure('Color','w');
    histogram(rBoot, 'BinWidth',0.02);
    xlabel('Inter-group correlation (Spearman)');
    ylabel('Count');
    title(sprintf('Intergroup correlation ? %s (%s, nBoot=%d)', ...
        condition, trialType, nBoot), 'Interpreter','none');
    grid on;
    xline(summary.r_mean, 'r-', 'LineWidth',1.5, ...
        'Label', sprintf('mean = %.3f', summary.r_mean), ...
        'LabelOrientation','horizontal','LabelVerticalAlignment','bottom');
end



