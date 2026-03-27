function [rBoot, summary, itemsAB] = intergroupReliabilityBootstrap( ...
    baseDir, placeCodesA, placeCodesB, condition, minISI0dprime, nBoot, trialType)
% intergroupReliabilityBootstrap
%   Intergroup correlation via participant bootstrap with replacement.
%   On each bootstrap:
%     - sample n=min(nA,nB) participants (with replacement) from each group
%     - compute item-wise rate for that sample in each group
%     - correlate the two item vectors across the shared items
%
% Inputs:
%   baseDir        : folder containing .mat files
%   placeCodesA    : cellstr for Group A (e.g., {'BOS','CAM'} or {'ALL'})
%   placeCodesB    : cellstr for Group B (e.g., {'TSI'} or {'ALL'})
%   condition      : string to match in filename (e.g., 'Industrial-Nature')
%   minISI0dprime  : numeric threshold (filters participants)
%   nBoot          : number of bootstrap replicates
%   trialType      : 'hit' for nonzero-ISI repeats, 'fa' for first-presentations (FAs)
%
% Outputs:
%   rBoot   : nBootx1 vector of Spearman r across items
%   summary : struct with fields {'r_mean','r_median','r_ci'}
%   itemsAB : aligned item list used for correlation (string vector)
%
% Notes:
%   - Uses exact string matching of stimulusPresented (no normalization).
%   - Requires variables under top level or data: repeatPosition, isResponseCorrect, stimulusPresented.

    % --- gather files by group (respect condition) ---
    filesA = getRecognitionMemFiles(baseDir, placeCodesA, condition, minISI0dprime);
    filesB = getRecognitionMemFiles(baseDir, placeCodesB, condition, minISI0dprime);
    if isempty(filesA) || isempty(filesB)
        warning('No files for one or both groups. A=%d, B=%d', numel(filesA), numel(filesB));
        rBoot = nan(nBoot,1); summary = struct(); itemsAB = string([]); return;
    end

    % --- union items seen in either group (based on requested trialType) ---
    itemsA = unionOfItems(filesA, trialType);
    itemsB = unionOfItems(filesB, trialType);
    [itemsAB, ia, ib] = intersect(itemsA, itemsB, 'stable');     % intersect, keep A's order
    if isempty(itemsAB)
        warning('No shared items between groups for trialType=%s.', trialType);
        rBoot = nan(nBoot,1); summary = struct(); return;
    end

    % --- precompute per-participant item-wise rates for each group ---
    Ra = participantItemRates(filesA, itemsAB, trialType);  % size: nA x nItems
    Rb = participantItemRates(filesB, itemsAB, trialType);  % size: nB x nItems

    nA = size(Ra,1); nB = size(Rb,1);
    n  = min(nA, nB);                         % equal sample size per bootstrap
    nItems = numel(itemsAB);

    % --- bootstrap sampling of participants with replacement ---
    rBoot = nan(nBoot,1);
    for b = 1:nBoot
%         idxA = randi(nA, n, 1);
%         idxB = randi(nB, n, 1);
        idxA = randsample(nA, n, false);  % without replacement
        idxB = randsample(nB, n, false); 
        meanA = mean(Ra(idxA, :), 1, 'omitnan');   % 1 x nItems
        meanB = mean(Rb(idxB, :), 1, 'omitnan');   % 1 x nItems

        valid = ~isnan(meanA) & ~isnan(meanB);
        if nnz(valid) >= 3
            rBoot(b) = corr(meanA(valid).', meanB(valid).', 'type','Spearman', 'rows','pairwise');
        else
            rBoot(b) = NaN;
        end
    end

    % --- summarize ---
    summary = struct();
    summary.r_mean   = mean(rBoot, 'omitnan');
    summary.r_median = median(rBoot, 'omitnan');
    if nnz(~isnan(rBoot)) > 0
        summary.r_ci = quantile(rBoot(~isnan(rBoot)), [0.025 0.975]);
    else
        summary.r_ci = [NaN NaN];
    end

    % --- simple plot ---
    figure('Color','w'); histogram(rBoot, 'BinWidth',0.02);
    xlabel(sprintf('Intergroup r (%s)', trialType)); ylabel('Count');
    title(sprintf('Intergroup Correlation ? %s (nBoot=%d, nA=%d, nB=%d, n=%d)', ...
        condition, nBoot, nA, nB, n));
    grid on;
    
    % --- add vertical line for mean ---
    hold on;
    xline(summary.r_mean, 'r-', 'LineWidth', 2, ...
        'Label', sprintf('Mean = %.3f', summary.r_mean), ...
        'LabelOrientation', 'horizontal', ...
        'LabelVerticalAlignment', 'bottom');
    hold off;
    
    % placeCodesA, placeCodesB
    
    if any(strcmpi(placeCodesA,'ALL')), placeTagA='ALL';
    else placeTagA = strjoin(placeCodesA,'_'); end
    
    if any(strcmpi(placeCodesB,'ALL')), placeTagB='ALL';
    else placeTagB = strjoin(placeCodesB,'_'); end

    outDir = fullfile(baseDir,'figures',condition);
    if ~exist(outDir,'dir'), mkdir(outDir); end

    fname = sprintf('%s-%s-%s_%s-catchtrial-sens-%.2f.png','intergroup-correlation', trialType, placeTagA, placeTagB, ...
        minISI0dprime);
    saveas(gcf, fullfile(outDir, fname));
    fprintf('Saved plot to %s\n', fullfile(outDir,fname));
end

% ===================== helpers =====================

function items = unionOfItems(files, trialType)
% Union of items that qualify for the requested trialType across a set of files.
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
% Build per-participant x item matrix of rates for the requested trialType.
% - For hits: mean(correctness) over nonzero-ISI repeat trials for that item.
% - For FAs : mean(1 - correctness) over first presentations for that item.
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
                    val = splitapply(@mean, double(ic(mask)), G);  % hit rate = mean(correct)
                    [~, ia, ib] = intersect(itemsAB, unique(ids), 'stable');
                    R(i, ia) = val(ib);
                end
            case 'fa'
                mask = isnan(rp);
                if any(mask)
                    [G, ids] = findgroups(SP(mask));
                    val = splitapply(@mean, 1 - double(ic(mask)), G);  % FA rate = mean(1-correct)
                    [~, ia, ib] = intersect(itemsAB, unique(ids), 'stable');
                    R(i, ia) = val(ib);
                end
        end
    end
end

function [SP, rp] = loadSP_RP(file)
% Robustly load vectors from a .mat (fields may be top-level or under 'data').
    Sraw = load(file,'-mat');
    if isfield(Sraw,'data'), D = Sraw.data; else, D = Sraw; end
    SP = D.stimulusPresented; rp = D.repeatPosition;
end

function [SP, rp, ic] = loadSP_RP_IC(file)
    Sraw = load(file,'-mat');
    if isfield(Sraw,'data'), D = Sraw.data; else, D = Sraw; end
    SP = D.stimulusPresented; rp = D.repeatPosition; ic = D.isResponseCorrect;
end