function outs = ooo_similarity_from_triplets()
% ooo_similarity_from_triplets
%   Build a pairwise similarity matrix S from Odd-One-Out triplet data,
%   using the rule: in triplet (i, j, k), if j is chosen as odd, then (i,k)
%   are counted as the "similar" pair.
%
%   Normalization options:
%     'prob'  : S(i,j) = s(i,j) / t(i,j)
%     'beta'  : S(i,j) = (s(i,j)+alpha) / (t(i,j)+2*alpha)   % Laplace/Beta(?,?)
%     'pmi'   : PMI-style score based on expected chance of being the similar pair
%     'zscore': Binomial z-score for s(i,j) given t(i,j) and global baseline p0
%
%   Outputs:
%     outs.S        : (n_items x n_items) similarity
%     outs.D        : dissimilarity (1 - S) clipped to [0,1] for 'prob'/'beta'
%     outs.T        : co-occurrence counts for pairs
%     outs.s        : ?similar? counts for pairs
%     outs.p_odd    : per-stim probability of being chosen as odd (group mean)
%     outs.meta     : settings and bookkeeping
%
%   Bryan Medina ? Oct 29, 2025

%% ====================== USER SETTINGS ======================
data_dir   = '/Users/bjm/Documents/School/MIT/labs/mcdermott/Tsimane2025/Data/OOO_2025/GlobalizedMusic/';  % where *.rsp live
n_items    = 80;                                              % mem_stim_0..79
norm_mode  = 'prob';                                          % 'prob' | 'beta' | 'pmi' | 'zscore'
alpha      = 1;                                               % Laplace/Beta smoothing strength
min_pair_n = 3;                                               % require at least this many co-occurrences
verbose    = true;

%% ====================== LOAD ALL TRIPLETS ===================
% This builds a tall table with columns: cond1, cond2, cond3, resp, subj
[subjTrials, subjIDs] = load_all_rsp(data_dir);
if isempty(subjTrials)
    error('No .rsp trials found in %s', data_dir);
end
if verbose
    fprintf('Loaded %d trials from %d participants\n', height(subjTrials), numel(subjIDs));
end

%% ====================== COUNT s AND t =======================
% s(i,j): #times (i,j) appeared together AND the odd choice was the third
% t(i,j): #times (i,j) appeared together in any order
[s, t, chosenCount, appearCount] = count_pairwise_similarity(subjTrials, n_items);

% enforce symmetry and zero diagonal
s = symmetrize_zero_diag(s);
t = symmetrize_zero_diag(t);

%% ====================== NORMALIZE TO S ======================
switch lower(norm_mode)
    case 'prob'
        S = zeros(n_items);
        mask = t >= min_pair_n;
        S(mask) = s(mask) ./ t(mask);

    case 'beta'
        S = zeros(n_items);
        mask = t >= min_pair_n;
        S(mask) = (s(mask) + alpha) ./ (t(mask) + 2*alpha);

    case 'pmi'
        % crude PMI-style: compare observed P(similar|co-occur) to chance
        % Chance baseline p0 ? average similar rate across all observed pairs
        mask = t >= min_pair_n;
        p_obs = zeros(n_items); p_obs(mask) = s(mask) ./ t(mask);
        p0 = sum(s(mask)) / sum(t(mask) + eps);
        S = zeros(n_items);
        S(mask) = log( (p_obs(mask) + eps) ./ (p0 + eps) );   % can be negative/positive
        % rescale to [0,1] for visualization (optional)
        S = rescale_to_unit(S, mask);

    case 'zscore'
        % binomial z-score for each pair, centered relative to global baseline p0
        mask = t >= min_pair_n;
        p0 = sum(s(mask)) / sum(t(mask) + eps);
        mu = p0 .* t;                          % expected successes
        sd = sqrt(p0 .* (1-p0) .* t + eps);    % binomial SD
        Z = zeros(n_items);
        Z(mask) = (double(s(mask)) - mu(mask)) ./ max(sd(mask), 1e-9);
        % convert z to [0,1] by sigmoid for S-like output
        S = 1 ./ (1 + exp(-Z));
    otherwise
        error('Unknown norm_mode: %s', norm_mode);
end

% clean up S
S = symmetrize_zero_diag(S);

% Dissimilarity (for prob/beta, clip to [0,1])
if ismember(lower(norm_mode), {'prob','beta'})
    D = 1 - S;
    D = max(0, min(1, D));
else
    % for PMI/Z we provide an affine-rescaled D for convenience
    D = 1 - S;
    D = rescale_to_unit(D, t >= min_pair_n);
    D = symmetrize_zero_diag(D);
end

%% ====================== PER-STIM ODD PROB ===================
% Aggregate over participants:
% odd_count(i)   = total times stim i chosen as odd
% appear_count(i)= total times stim i appears in any triplet
odd_count   = sum(chosenCount, 2);      % n_items x 1
appear_count = sum(appearCount, 2);     % n_items x 1

% Avoid divide-by-zero for unseen items
p_odd = odd_count ./ max(appear_count, 1);
p_odd(appear_count == 0) = NaN;         % optional: NaN for never-shown items

%% ====================== OUTPUTS & PLOTS =====================
outs.S = S;
outs.D = D;
outs.T = t;
outs.s = s;
outs.p_odd = p_odd;
outs.meta = struct('data_dir', data_dir, 'n_items', n_items, ...
                   'norm_mode', norm_mode, 'alpha', alpha, ...
                   'min_pair_n', min_pair_n, ...
                   'n_participants', numel(subjIDs), ...
                   'n_trials', height(subjTrials));

if verbose
    % coverage summary
    tmp = tril(t > 0, -1);
    covered_pairs = sum(tmp(:));

    fprintf('Observed %d/%d unique pairs (%.1f%% coverage)\n', ...
        covered_pairs, n_items*(n_items-1)/2, ...
        100*covered_pairs / (n_items*(n_items-1)/2));
    % quick visuals
    figure('Name','Pairwise similarity (S)'); imagesc(S); axis image; colorbar;
    title(sprintf('Similarity S (%s)', norm_mode)); xlabel('Stim ID'); ylabel('Stim ID');

    figure('Name','Pairwise dissimilarity (D)'); imagesc(D); axis image; colorbar;
    title('Dissimilarity D = 1 - S'); xlabel('Stim ID'); ylabel('Stim ID');

    figure('Name','Odd-choice probability per stimulus');
    bar(p_odd, 'FaceColor', [0.2 0.5 0.9]); ylim([0 1]); grid on;
    xlabel('Stimulus ID'); ylabel('P(chosen odd)'); title('Per-stimulus odd-choice rate');
end

end

%% ====================== HELPER FUNCTIONS ======================

function [s, t, chosenCount, appearCount] = count_pairwise_similarity(T, n_items)
% Count pairwise co-occurrences (t) and "similar" flags (s) from OOO trials.
% Also compute per-subject chosen/appear counts for per-stim odd probability.

s = zeros(n_items);   % similar counts
t = zeros(n_items);   % co-occurrence counts
subs = unique(T.subj);
chosenCount = zeros(n_items, numel(subs));
appearCount = zeros(n_items, numel(subs));

for si = 1:numel(subs)
    Ti = T(T.subj == subs(si), :);
    for r = 1:height(Ti)
        a = Ti.cond1(r); b = Ti.cond2(r); c = Ti.cond3(r);
        resp = Ti.resp(r);
        % co-occurrences
        t(a,b) = t(a,b)+1; t(b,a) = t(b,a)+1;
        t(a,c) = t(a,c)+1; t(c,a) = t(c,a)+1;
        t(b,c) = t(b,c)+1; t(c,b) = t(c,b)+1;
        % similar pair = the two NOT chosen as odd
        switch resp
            case 1  % first (a) is odd -> (b,c) similar
                s(b,c) = s(b,c)+1; s(c,b) = s(c,b)+1;
                odd_id = a;
            case 2  % second (b) odd -> (a,c) similar
                s(a,c) = s(a,c)+1; s(c,a) = s(c,a)+1;
                odd_id = b;
            case 3  % third (c) odd -> (a,b) similar
                s(a,b) = s(a,b)+1; s(b,a) = s(b,a)+1;
                odd_id = c;
            otherwise
                odd_id = [];
        end
        % per-stim choice/appearance for odd probability
        appearCount([a b c], si) = appearCount([a b c], si) + 1;
        if ~isempty(odd_id)
            chosenCount(odd_id, si) = chosenCount(odd_id, si) + 1;
        end
    end
end
end

function M = symmetrize_zero_diag(M)
% Symmetrize and zero the diagonal
M = (M + M.')/2;
M(1:size(M,1)+1:end) = 0;
end

function X = rescale_to_unit(X, mask)
% Rescale values in mask to [0,1], leave others at 0
vals = X(mask);
if isempty(vals)
    return;
end
mn = min(vals); mx = max(vals);
if mx > mn
    vals = (vals - mn) / (mx - mn);
else
    vals = 0.5 * ones(size(vals));
end
X(mask) = vals;
end

function X = replace_zeros_with_nan(X)
% Convert zeros in X to NaN to avoid bias in means when counts=0
X(X == 0) = NaN;
end

function [subjTrials, subjIDs] = load_all_rsp(data_dir)
% Load all .rsp files into a table: cond1,cond2,cond3,resp,subj
files = dir(fullfile(data_dir, '*.rsp'));
subjTrials = table(); subjIDs = strings(0,1);
for f = 1:numel(files)
    fp = fullfile(files(f).folder, files(f).name);
    [T, subj] = parse_rsp(fp);
    if ~isempty(T)
        T.subj = repmat(subj, height(T), 1);
        subjTrials = [subjTrials; T]; 
        subjIDs = unique([subjIDs; subj]); 
    end
end
end

function [T, subj] = parse_rsp(fname)
% Parse a .rsp file into table with cond1,cond2,cond3,resp
subj = string(extractBefore(string(fname), '_GMOddOneOut'));
fid = fopen(fname,'rt'); if fid==-1, T=[]; return; end
lines = {}; while true, L=fgetl(fid); if ~ischar(L), break; end, lines{end+1}=L; end, fclose(fid);
h = find(contains(lines,'Cond1'),1,'first'); if isempty(h), T=[]; return; end
nums = cellfun(@(x) str2double(regexp(x,'[-+]?\d+\.?\d*','match')), lines(h+1:end), 'UniformOutput', false);
rows = cellfun(@(v) numel(v)>=8, nums); nums = nums(rows);
cond1=zeros(numel(nums),1); cond2=cond1; cond3=cond1; resp=cond1;
for k=1:numel(nums)
    v = nums{k}(end-7:end);
    cond1(k)=v(2); cond2(k)=v(3); cond3(k)=v(4); resp(k)=v(5);
end
mask = ismember(resp, [1 2 3]);
T = table(cond1(mask), cond2(mask), cond3(mask), resp(mask), ...
          'VariableNames', {'cond1','cond2','cond3','resp'});
end
