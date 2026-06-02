function results = powerSimulationPairedBootstrap(varargin)
% powerSimulationPairedBootstrap
%   Monte Carlo evaluation of the paired-bootstrap test in
%   pairedBootstrapCompareCorrelations under known-truth conditions.
%
%   Generates synthetic three-group recognition memory data with a
%   specified true intergroup itemwise correlation structure, runs the
%   paired-bootstrap test on each replicate, and reports empirical
%   type-I error / power and CI coverage for the three pair comparisons.
%
%   Name/Value options:
%     'nReps'        (200)            Monte Carlo replicates
%     'nA','nB','nC' ([25 25 25])     participants per group
%     'nItems'       (60)             shared items
%     'rho'          ([0.4 0.4 0.4])  true (AB, AC, BC) intergroup correlations
%                                     at the level of item-level true rates
%     'rel'          ([0.7 0.7 0.7])  target within-group reliabilities
%                                     (controls per-participant noise floor)
%     'baseRate'     (0.7)            mean hit rate across items
%     'itemSpread'   (0.15)           std of item-level true rates (on prob scale)
%     'alpha'        (0.05)
%     'nBoot'        (1000)
%     'UseSpearman'  (true)
%     'BootstrapDim' (1)
%     'minResp'      (2)
%     'Verbose'      (false)          quiet pairedBootstrap calls
%     'Seed'         ([])             optional rng seed for reproducibility
%
%   Output struct:
%     .reject_null    [3x1]  empirical rejection rate using recentered-null p
%     .reject_straddle[3x1]  empirical rejection rate using straddle-zero p
%     .coverage       [3x1]  fraction of replicates whose 95% CI for the
%                            diff covered the true diff
%     .mean_obs_r     [3x1]  mean observed correlations (AB, AC, BC)
%     .mean_obs_diff  [3x1]  mean observed differences (AB-AC, AB-BC, AC-BC)
%     .true_diff      [3x1]  true differences implied by 'rho'
%     .opts           struct of resolved options
%     .raw            cell array of per-replicate pvals structs (if requested)
%
%   Typical use:
%     % Type-I error at Bryan's site sizes (US n=30, SB n=20, Tsimane n=20)
%     out = powerSimulationPairedBootstrap('nA',30,'nB',20,'nC',20, ...
%             'nItems',50,'rho',[0.4 0.4 0.4],'nReps',500);
%
%     % Power to detect a 0.2 difference in one pair
%     out = powerSimulationPairedBootstrap('nA',30,'nB',20,'nC',20, ...
%             'nItems',50,'rho',[0.6 0.4 0.4],'nReps',500);
%
%   Bryan Medina -- May 2026

    % ---------- options ----------
    p = inputParser;
    addParameter(p,'nReps',200,@isscalar);
    addParameter(p,'nA',25,@isscalar);
    addParameter(p,'nB',25,@isscalar);
    addParameter(p,'nC',25,@isscalar);
    addParameter(p,'nItems',60,@isscalar);
    addParameter(p,'rho',[0.4 0.4 0.4],@(x) numel(x)==3);
    addParameter(p,'rel',[0.7 0.7 0.7],@(x) numel(x)==3);
    addParameter(p,'baseRate',0.7,@isscalar);
    addParameter(p,'itemSpread',0.15,@isscalar);
    addParameter(p,'alpha',0.05,@isscalar);
    addParameter(p,'nBoot',1000,@isscalar);
    addParameter(p,'UseSpearman',true,@islogical);
    addParameter(p,'BootstrapDim',1,@isscalar);
    addParameter(p,'minResp',2,@isscalar);
    addParameter(p,'Verbose',false,@islogical);
    addParameter(p,'StoreRaw',false,@islogical);
    addParameter(p,'Seed',[]);
    parse(p,varargin{:});
    opt = p.Results;

    if ~isempty(opt.Seed), rng(opt.Seed); else, rng('shuffle'); end

    % Validate correlation matrix is PSD
    R = [1 opt.rho(1) opt.rho(2); opt.rho(1) 1 opt.rho(3); opt.rho(2) opt.rho(3) 1];
    [~, pflag] = chol(R);
    if pflag ~= 0
        error('rho = [%.2f %.2f %.2f] does not yield a PSD covariance.', opt.rho);
    end

    true_diff = [opt.rho(1)-opt.rho(2); opt.rho(1)-opt.rho(3); opt.rho(2)-opt.rho(3)];

    % participant-level noise std to hit target reliability
    % Spearman-Brown form: rel = nA*sig_t^2 / (nA*sig_t^2 + sig_e^2)
    % We treat sig_t = itemSpread on the prob scale and back out sig_e
    % per group. This is approximate but in the right ballpark.
    sigT = opt.itemSpread;
    nGroup = [opt.nA opt.nB opt.nC];
    sigE = zeros(1,3);
    for g = 1:3
        if opt.rel(g) >= 1 || opt.rel(g) <= 0
            sigE(g) = 0;
        else
            sigE(g) = sigT * sqrt(nGroup(g) * (1 - opt.rel(g)) / opt.rel(g));
        end
    end

    % ---------- pre-allocate ----------
    p_null     = nan(opt.nReps, 3);   % AB_vs_AC, AB_vs_BC, AC_vs_BC
    p_straddle = nan(opt.nReps, 3);
    obs_r      = nan(opt.nReps, 3);   % r(AB), r(AC), r(BC)
    obs_diff   = nan(opt.nReps, 3);
    ci_cover   = false(opt.nReps, 3);

    if opt.StoreRaw, raw = cell(opt.nReps,1); else, raw = {}; end

    % ---------- replicate loop ----------
    t0 = tic;
    for rep = 1:opt.nReps
        % Draw item-level latent rates jointly across the three groups.
        Z = mvnrnd([0 0 0], R, opt.nItems);      % [nItems x 3], unit variance
        % Map to probabilities in (0,1) with mean baseRate, std ~itemSpread.
        ItemRates = opt.baseRate + sigT * Z;
        ItemRates = min(max(ItemRates, 0.02), 0.98);

        % Per-group participant matrices.
        outs = cell(1,3);
        for g = 1:3
            n   = nGroup(g);
            % participant offsets per item (additive noise on prob scale)
            E = sigE(g) * randn(n, opt.nItems);
            P = ItemRates(:,g)' + E;            % [n x nItems]
            P = min(max(P, 0.01), 0.99);
            % Single Bernoulli per (participant, item).
            X = double(rand(n, opt.nItems) < P);

            % within-group split-half reliability (Spearman-Brown corrected)
            sb = withinGroupSB(X, 20);

            % Build the minimal struct expected by pairedBootstrapCompareCorrelations.
            o = struct();
            o.itemwise_hits = X;
            o.itemwise_fas  = nan(size(X));     % not used in this sim
            o.items         = string(arrayfun(@(k) sprintf('item%03d',k), 1:opt.nItems, 'UniformOutput', false))';
            o.sb_hit        = sb;
            o.sb_fa         = NaN;
            o.nSubjects     = n;
            outs{g} = o;
        end

        pvals = pairedBootstrapCompareCorrelations(outs{1}, outs{2}, outs{3}, 'hit', ...
            'nBoot', opt.nBoot, 'UseSpearman', opt.UseSpearman, ...
            'BootstrapDim', opt.BootstrapDim, 'minResp', opt.minResp, ...
            'Verbose', opt.Verbose);

        p_null(rep,:)     = [pvals.AB_vs_AC,          pvals.AB_vs_BC,          pvals.AC_vs_BC];
        p_straddle(rep,:) = [pvals.straddle.AB_vs_AC, pvals.straddle.AB_vs_BC, pvals.straddle.AC_vs_BC];
        obs_r(rep,:)      = [pvals.observed.r_AB,     pvals.observed.r_AC,     pvals.observed.r_BC];
        obs_diff(rep,:)   = [pvals.observed_diffs.AB_minus_AC, ...
                             pvals.observed_diffs.AB_minus_BC, ...
                             pvals.observed_diffs.AC_minus_BC];

        ci_cover(rep,1) = pvals.ci.AB_minus_AC(1) <= true_diff(1) && true_diff(1) <= pvals.ci.AB_minus_AC(2);
        ci_cover(rep,2) = pvals.ci.AB_minus_BC(1) <= true_diff(2) && true_diff(2) <= pvals.ci.AB_minus_BC(2);
        ci_cover(rep,3) = pvals.ci.AC_minus_BC(1) <= true_diff(3) && true_diff(3) <= pvals.ci.AC_minus_BC(2);

        if opt.StoreRaw, raw{rep} = pvals; end

        if mod(rep,25)==0
            fprintf('  rep %d/%d  elapsed=%.1fs\n', rep, opt.nReps, toc(t0));
        end
    end

    % ---------- summarize ----------
    results = struct();
    results.opts            = opt;
    results.true_diff       = true_diff;
    results.reject_null     = mean(p_null     <= opt.alpha, 1)';
    results.reject_straddle = mean(p_straddle <= opt.alpha, 1)';
    results.coverage        = mean(ci_cover, 1)';
    results.mean_obs_r      = mean(obs_r, 1, 'omitnan')';
    results.mean_obs_diff   = mean(obs_diff, 1, 'omitnan')';
    results.p_null          = p_null;
    results.p_straddle      = p_straddle;
    results.obs_r           = obs_r;
    results.obs_diff        = obs_diff;
    results.raw             = raw;

    % ---------- console summary ----------
    pairLabels = {'AB vs AC','AB vs BC','AC vs BC'};
    fprintf('\n=== powerSimulationPairedBootstrap (%d reps) ===\n', opt.nReps);
    fprintf('N per group: A=%d B=%d C=%d   nItems=%d   alpha=%.2f   nBoot=%d\n', ...
        opt.nA, opt.nB, opt.nC, opt.nItems, opt.alpha, opt.nBoot);
    fprintf('True rho: AB=%.2f AC=%.2f BC=%.2f   target rel: A=%.2f B=%.2f C=%.2f\n', ...
        opt.rho, opt.rel);
    fprintf('%-12s %12s %12s %14s %12s %12s\n', ...
        'Pair', 'true_diff', 'mean_diff', 'reject_null', 'reject_strad', 'CI_cover');
    for k = 1:3
        fprintf('%-12s %12.3f %12.3f %14.3f %12.3f %12.3f\n', ...
            pairLabels{k}, true_diff(k), results.mean_obs_diff(k), ...
            results.reject_null(k), results.reject_straddle(k), results.coverage(k));
    end
end

% --- minimal within-group Spearman-Brown reliability via participant split ---
function sb = withinGroupSB(X, nRep)
    [n, ~] = size(X);
    if n < 4, sb = NaN; return; end
    rr = nan(nRep,1);
    for k = 1:nRep
        idx = randperm(n);
        h1 = mean(X(idx(1:floor(n/2)), :), 1, 'omitnan');
        h2 = mean(X(idx(floor(n/2)+1:end), :), 1, 'omitnan');
        m = ~isnan(h1) & ~isnan(h2);
        if sum(m) < 3, continue; end
        rr(k) = corr(h1(m)', h2(m)', 'Type', 'Spearman', 'Rows', 'pairwise');
    end
    r_half = mean(rr, 'omitnan');
    sb = (2 * r_half) / (1 + r_half);
end
