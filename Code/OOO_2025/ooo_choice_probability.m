function outs = ooo_choice_probability(data_dir, n_items, verbose)
% ooo_choice_probability
%   Computes, for Odd-One-Out triplet data:
%       - P(chosen odd | appeared)
%       - total number of times each item was chosen odd
%       - total number of appearances
%
%   INPUTS:
%       data_dir : directory containing *.rsp files
%       n_items  : number of stimuli (e.g., 80)
%       verbose  : true/false for printing + plots
%
%   OUTPUT struct outs:
%       outs.odd_count     : n_items x 1 (# times item chosen odd)
%       outs.appear_count  : n_items x 1 (# times item appears)
%       outs.p_odd         : n_items x 1 (probability chosen odd)
%       outs.subjIDs       : participant IDs
%       outs.meta          : metadata

if nargin < 3, verbose = true; end

%% ===================== LOAD RSP FILES ======================
[subjTrials, subjIDs] = load_all_rsp(data_dir);
if isempty(subjTrials)
    error('No .rsp files found in %s', data_dir);
end

if verbose
    fprintf('Loaded %d trials from %d participants\n', ...
        height(subjTrials), numel(subjIDs));
end

%% ===================== COUNT APPEARANCES + ODD ======================
odd_count    = zeros(n_items, 1);
appear_count = zeros(n_items, 1);

for r = 1:height(subjTrials)
    a = subjTrials.cond1(r);
    b = subjTrials.cond2(r);
    c = subjTrials.cond3(r);

    resp = subjTrials.resp(r);

    % increment appearance count for all 3
    appear_count([a b c]) = appear_count([a b c]) + 1;

    % increment odd choice
    switch resp
        case 1
            odd_count(a) = odd_count(a) + 1;
        case 2
            odd_count(b) = odd_count(b) + 1;
        case 3
            odd_count(c) = odd_count(c) + 1;
    end
end

%% ===================== COMPUTE PROBABILITIES ======================
p_odd = odd_count ./ max(appear_count, 1);
p_odd(appear_count == 0) = NaN;   % optional: NaN for never-seen items

%% ===================== PACKAGE OUTPUT ======================
outs.odd_count    = odd_count;
outs.appear_count = appear_count;
outs.p_odd        = p_odd;
outs.subjIDs      = subjIDs;

outs.meta = struct( ...
    'data_dir', data_dir, ...
    'n_items', n_items, ...
    'n_participants', numel(subjIDs), ...
    'n_trials', height(subjTrials));

%% ===================== OPTIONAL DIAGNOSTIC PLOTS ======================
if verbose
    figure('Name','Odd-choice probability per stimulus');
    bar(p_odd, 'FaceColor', [0.2 0.5 0.9]);
    ylim([0 1]);
    grid on;
    xlabel('Stimulus ID'); ylabel('P(chosen odd)');
    title('Distinctiveness: frequency of being judged the odd item');

    figure('Name','Stimulus appearance counts');
    bar(appear_count);
    xlabel('Stimulus ID'); ylabel('# appearances');
    title('How many times each stimulus appeared across all triplets');
end

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