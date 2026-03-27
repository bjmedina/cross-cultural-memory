function outs = intergroupCorrelationPerSound(outsA, outsB, trialType, varargin)
% intergroupCorrelationPerSound
%   Compute correlation PER SOUND between two groups (A,B),
%   comparing their participant-level responses for each sound.
%
%   Outputs:
%     outs.r_raw : [1×nItems] correlation per sound
%     outs.ci    : [2×nItems] bootstrap CIs (optional)
%     outs.sem   : [1×nItems] bootstrap SEM (optional)
%
%   Bryan Medina ? Bolivia 2025

    % -----------------------------
    % Parameters
    % -----------------------------
    p = inputParser;
    addParameter(p,'UseSpearman',true,@islogical);
    addParameter(p,'nBoot',0,@isscalar);
    parse(p,varargin{:});
    useSpearman = p.Results.UseSpearman;
    nBoot = p.Results.nBoot;

    method = ternary(useSpearman,'Spearman','Pearson');
    trialType = lower(trialType);
    assert(ismember(trialType,{'hit','fa'}),'trialType must be ''hit'' or ''fa''.');

    % -----------------------------
    % Extract matrices
    % -----------------------------
    switch trialType
        case 'hit'
            XA = double(outsA.itemwise_hits);
            XB = double(outsB.itemwise_hits);
        case 'fa'
            XA = double(outsA.itemwise_fas);
            XB = double(outsB.itemwise_fas);
    end

    % Align items
    [sharedItems, ia, ib] = intersect(string(outsA.items), string(outsB.items), 'stable');
    XA = XA(:, ia);
    XB = XB(:, ib);
    nItems = numel(sharedItems);

    % -----------------------------
    % Compute per-sound correlations
    % -----------------------------
    r_raw = nan(1, nItems);
    sem = nan(1, nItems);
    ci = nan(2, nItems);

    fprintf('Computing per-sound intergroup correlations (%s)...\n', method);
    for i = 1:nItems
        a = XA(:,i);
        b = XB(:,i);

        % Remove NaNs separately for each group ? they have different participant counts
        a = a(~isnan(a));
        b = b(~isnan(b));

        % Can't correlate across participants between groups directly,
        % so we correlate ranks across the empirical distributions
        if isempty(a) || isempty(b)
            continue;
        end

        % Resample to equalize group size (draw with replacement)
        m = min(numel(a), numel(b));
        a_samp = randsample(a, m, true);
        b_samp = randsample(b, m, true);

        r_raw(i) = corr(a_samp, b_samp, 'Type', method, 'Rows','pairwise');

        % Bootstrap for CI
        if nBoot > 0
            boot_r = nan(nBoot,1);
            for bIter = 1:nBoot
                idxA = randi(m,[m,1]);
                idxB = randi(m,[m,1]);
                boot_r(bIter) = corr(a_samp(idxA), b_samp(idxB), 'Type', method, 'Rows','pairwise');
            end
            sem(i) = std(boot_r,'omitnan');
            ci(:,i) = prctile(boot_r,[2.5 97.5]);
        end
    end

    % -----------------------------
    % Package outputs
    % -----------------------------
    outs = struct();
    outs.trialType = trialType;
    outs.method    = method;
    outs.items     = sharedItems;
    outs.nItems    = nItems;
    outs.r_raw     = r_raw;
    outs.sem       = sem;
    outs.ci        = ci;
end