function [outs, R_all] = split_half_reliability_group( ...
    baseDir, placeCodes, condition, minISI0dprime, trialType, varargin)
% split_half_reliability_group
%   Robust split-half reliability within ONE group (e.g., Tsimane).
%   Handles item alignment between halves, minimum coverage, and degenerate halves.
%
% Inputs:
%   baseDir, placeCodes, condition, minISI0dprime, trialType ('hit'|'fa')
%
% Name/Value:
%   'NSplits'           : number of random splits (default 5000)
%   'MinSubsPerItem'    : require >= this many subjects per item per half (default 3)
%   'MinItemsOverlap'   : require >= this many overlapping items to correlate (default 15)
%   'RngSeed'           : integer or [] (default [])
%   'Verbose'           : true/false diagnostics (default true)
%
% Outputs (struct):
%   outs.rho_splits     : NSplitsx1 Spearman correlations (raw, half-vs-half)
%   outs.rho_sb         : NSplitsx1 Spearman?Brown corrected reliabilities
%   outs.summary        : mean/median/CI for rho_sb
%   outs.meta           : diagnostics: nSubs, nItems, cov stats per split
%
% Bryan Medina ? Oct 2025

    % ---------- params ----------
    p = inputParser;
    addParameter(p, 'NSplits', 5000, @(x)isnumeric(x) && isscalar(x) && x>=10);
    addParameter(p, 'MinSubsPerItem', 3, @(x)isnumeric(x) && isscalar(x) && x>=1);
    addParameter(p, 'MinItemsOverlap', 15, @(x)isnumeric(x) && isscalar(x) && x>=3);
    addParameter(p, 'RngSeed', [], @(x)isempty(x) || isnumeric(x));
    addParameter(p, 'Verbose', true, @(x)islogical(x) || isnumeric(x));
    parse(p, varargin{:});
    NSplits         = p.Results.NSplits;
    MinSubsPerItem  = p.Results.MinSubsPerItem;
    MinItemsOverlap = p.Results.MinItemsOverlap;
    if ~isempty(p.Results.RngSeed), rng(p.Results.RngSeed); end
    Verbose = logical(p.Results.Verbose);

    % ---------- files & items (group-only) ----------
    files = getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime);
    if isempty(files)
        error('No files found for %s. Check filters.', strjoin(placeCodes, ','));
    end
    groupItems = unionOfItems(files, trialType);                 % use ALL items present in this group
    [R_all, usedItems_all] = participantItemRates(files, groupItems, trialType);  %#ok<ASGLU>
    % Ensure participants with zero usable data are dropped
    keepSub = ~all(isnan(R_all), 2);
    R_all   = R_all(keepSub, :);
    files   = files(keepSub);
    nSubs   = size(R_all,1);
    nItems  = size(R_all,2);
    if nSubs < 6
        warning('Very few subjects after filtering (n=%d). Split-half may be unstable.', nSubs);
    end

    if Verbose
        itmVar = var(R_all,0,1,'omitnan');
        fprintf('[%s] nSubs=%d, nItems=%d, mean item var=%.4f, zero-var items=%d\n', ...
            strjoin(placeCodes,','), nSubs, nItems, nanmean(itmVar), sum(itmVar==0 | isnan(itmVar)));
    end

    % ---------- prealloc ----------
    rho  = nan(NSplits,1);
    rhoS = nan(NSplits,1);
    meta = struct('nItemsOverlap', nan(NSplits,1), ...
                  'nSubA', nan(NSplits,1), 'nSubB', nan(NSplits,1), ...
                  'varA', nan(NSplits,1), 'varB', nan(NSplits,1));

    % ---------- main loop ----------
    for s = 1:NSplits
        % random balanced split of participants
        idx = randperm(nSubs);
        A = idx(1:floor(nSubs/2));
        B = idx(floor(nSubs/2)+1:end);

        % compute per-item means in each half after enforcing MinSubsPerItem coverage
        [mA, okA] = mean_with_min_coverage(R_all(A,:), MinSubsPerItem);
        [mB, okB] = mean_with_min_coverage(R_all(B,:), MinSubsPerItem);

        % alignment: only items with means in BOTH halves
        ok = okA & okB & ~isnan(mA) & ~isnan(mB);
        if nnz(ok) < MinItemsOverlap
            rho(s)  = NaN;
            rhoS(s) = NaN;
            continue
        end

        xa = mA(ok)'; xb = mB(ok)';

        % reject degenerate halves (flat means after masking)
        if all(xa==xa(1)) || all(xb==xb(1))
            rho(s)  = NaN;
            rhoS(s) = NaN;
            continue
        end

        r = corr(xa, xb, 'type','Spearman');  % raw half-vs-half
        rho(s)  = r;
        rhoS(s) = (2*r)/(1+r);                % Spearman?Brown correction

        % meta
        meta.nItemsOverlap(s) = nnz(ok);
        meta.nSubA(s) = numel(A);
        meta.nSubB(s) = numel(B);
        meta.varA(s)  = var(xa, 1);  % population variance for diagnostics
        meta.varB(s)  = var(xb, 1);
    end

    % ---------- summarize ----------
    outs = struct();
    outs.rho_splits = rho;
    outs.rho_sb     = rhoS;
    outs.summary    = summarize_vector(rhoS);
    outs.meta       = meta;
    outs.settings   = struct('NSplits',NSplits, 'MinSubsPerItem',MinSubsPerItem, ...
                             'MinItemsOverlap',MinItemsOverlap, 'trialType',trialType, ...
                             'condition',condition, 'placeCodes',{placeCodes});

    if Verbose
        nValid = sum(~isnan(rhoS));
        fprintf('Splits usable: %d/%d (%.1f%%). Mean SB=%.3f, median=%.3f, 95%% CI=[%.3f, %.3f]\n', ...
            nValid, NSplits, 100*nValid/NSplits, ...
            outs.summary.mean, outs.summary.median, outs.summary.ci(1), outs.summary.ci(2));
    end

    % ---------- quick viz ----------
    figure('Color','w'); histogram(rhoS, 'BinWidth',0.025);
    xlabel(sprintf('Split-half reliability (SB), %s ? %s', strjoin(placeCodes,','), trialType), 'Interpreter','none');
    ylabel('Count'); title(sprintf('%s ? %s', condition, trialType), 'Interpreter','none'); grid on;
    xline(outs.summary.mean, 'r-', 'LineWidth',1.5, 'Label',sprintf('mean=%.3f',outs.summary.mean), ...
        'LabelOrientation','horizontal','LabelVerticalAlignment','bottom');
end

% ======================= HELPERS =======================

function [R, usedItems] = participantItemRates(files, itemsShared, trialType)
% Build participant × item matrix; preserves itemsShared order.
    nSub = numel(files); nItems = numel(itemsShared);
    R = nan(nSub, nItems);
    itemsShared = string(itemsShared(:));
    for i = 1:nSub
        [SP, rp, ic] = loadSP_RP_IC(files{i});
        SP = string(SP(:)); rp = rp(:); ic = logical(ic(:));
        switch lower(trialType)
            case 'hit'
                mask = ~isnan(rp) & rp > 1;
                vals = double(ic(mask)); ids = SP(mask);
            case 'fa'
                mask = isnan(rp);
                vals = 1 - double(ic(mask)); ids = SP(mask);
            otherwise
                error('Unknown trialType: %s', trialType);
        end
        if isempty(ids), continue; end
        [G, uids] = findgroups(ids);
        v = splitapply(@mean, vals, G);
        [tf, loc] = ismember(itemsShared, uids);
        R(i, tf) = v(loc(tf));
    end
    usedItems = itemsShared;
end

function [m, ok] = mean_with_min_coverage(Rhalf, minSubs)
% Column-wise mean requiring >= minSubs non-NaN observations.
    nPerItem = sum(~isnan(Rhalf), 1);
    ok = nPerItem >= minSubs;
    m  = nan(1, size(Rhalf,2));
    m(ok) = mean(Rhalf(:, ok), 'omitnan');
end

function s = summarize_vector(x)
% Mean/median/95% CI for a numeric vector with NaNs dropped.
    x = x(~isnan(x));
    if isempty(x)
        s = struct('mean',NaN,'median',NaN,'ci',[NaN NaN],'n',0);
        return
    end
    s.mean   = mean(x);
    s.median = median(x);
    s.ci     = quantile(x, [0.025 0.975]);
    s.n      = numel(x);
end

% ======================= DEMO CALL =======================
function demo_run_for_group()
% Demo: run for Tsimane on your current script vars (edit as needed).
    baseDir = fullfile(getenv('HOME'), 'Documents', 'School', 'MIT', 'labs', 'mcdermott', 'Tsimane2025', 'Data', ...
                       'RecognitionMemory', 'Results');
    placeCodes = {'MAN','MAJ','NVM','NUM','NUV','CVR'};  % Tsimane
    condition  = 'Globalized-Music';                     % or 'Industrial-Nature' / 'NHS'
    minISI0dprime = 2.0;

    % Hits
    outs_hit = split_half_reliability_group(baseDir, placeCodes, condition, minISI0dprime, 'hit', ...
        'NSplits', 5000, 'MinSubsPerItem', 3, 'MinItemsOverlap', 15, 'Verbose', true);
    disp(outs_hit.summary)

    % False alarms
    outs_fa = split_half_reliability_group(baseDir, placeCodes, condition, minISI0dprime, 'fa', ...
        'NSplits', 5000, 'MinSubsPerItem', 3, 'MinItemsOverlap', 15, 'Verbose', true);
    disp(outs_fa.summary)
end