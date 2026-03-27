function outs = analyzeOOO_OddChoiceProbabilities()
% analyzeOOO_OddChoiceProbabilities
%   Compute, for each stimulus, the probability of being chosen as "odd one out".
%
%   P(i) = (# times i was chosen as odd) / (# times i appeared in any triplet)
%
%   Works directly on .rsp logs from OOO experiments.
%
%   Bryan Medina ? Oct 29, 2025

% ========================= Settings =========================
data_dir  = '/Volumes/blossom/DATABACKUP/2025-10-29/OOO_2025/GlobalizedMusic/'; % folder with *.rsp
n_items   = 80;  % number of unique stimuli
min_trials_for_validity = 3; % optional filter
rng('default');

% ========================= Load data =========================
[subjTrials, subjIDs] = load_all_rsp(data_dir);
fprintf('Loaded %d trials from %d participants.\n', height(subjTrials), numel(subjIDs));

% ========================= Initialize counts =================
chosen_count = zeros(n_items, numel(subjIDs));   % times chosen as odd
appear_count = zeros(n_items, numel(subjIDs));   % times appeared in any triplet

% ========================= Count per participant ==============
for p = 1:numel(subjIDs)
    Ti = subjTrials(subjTrials.subj == subjIDs(p), :);
    for r = 1:height(Ti)
        a = Ti.cond1(r); b = Ti.cond2(r); c = Ti.cond3(r);
        resp = Ti.resp(r);
        appear_count([a b c],p) = appear_count([a b c],p) + 1;
        chosen_idx = [a b c];
        chosen_count(chosen_idx(resp),p) = chosen_count(chosen_idx(resp),p) + 1;
    end
end

% ========================= Compute probabilities ==============
P = chosen_count ./ max(appear_count,1);
P(appear_count < min_trials_for_validity) = NaN; % mask sparse stimuli

meanP = nanmean(P,2);
semP  = nanstd(P,0,2) ./ sqrt(sum(~isnan(P),2));

% ========================= Visualization =====================
figure('Name','Probability of being chosen as odd');
bar(meanP, 'FaceColor',[0.2 0.4 0.8]); hold on;
errorbar(1:n_items, meanP, semP, 'k.', 'LineWidth',1);
xlabel('Stimulus ID');
ylabel('P(chosen as odd)');
title('Per-stimulus probability of being chosen (group average)');
ylim([0 1]);
grid on;

% Histogram across stimuli
figure('Name','Distribution of odd-choice probabilities');
histogram(meanP, 15, 'FaceColor',[0.3 0.3 0.7]);
xlabel('P(chosen as odd)'); ylabel('Count of stimuli');
title('Distribution across all stimuli');
xlim([0 1]);

% ========================= Output struct =====================
outs.prob_by_stim = meanP;
outs.sem_by_stim  = semP;
outs.raw_P        = P;
outs.appear_count = appear_count;
outs.chosen_count = chosen_count;
outs.subjIDs      = subjIDs;

fprintf('\nMean P(chosen)=%.3f ± %.3f (SD across stimuli)\n', nanmean(meanP), nanstd(meanP));

end

% ========================= Helper (same as before) =========================
function [subjTrials, subjIDs] = load_all_rsp(data_dir)
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
    subj = string(extractBefore(string(fname), '_GMOddOneOut'));
    fid = fopen(fname,'rt'); if fid==-1, T=[]; return; end
    lines = {}; while true, L=fgetl(fid); if ~ischar(L), break; end, lines{end+1}=L; end, fclose(fid);
    h = find(contains(lines,'Cond1'),1,'first'); if isempty(h), T=[]; return; end
    nums = cellfun(@(x) str2double(regexp(x,'[-+]?\d+\.?\d*','match')), lines(h+1:end), 'UniformOutput',false);
    rows = cellfun(@(v) numel(v)>=8, nums); nums = nums(rows);
    cond1=zeros(numel(nums),1); cond2=cond1; cond3=cond1; resp=cond1;
    for k=1:numel(nums)
        v = nums{k}(end-7:end);
        cond1(k)=v(2); cond2(k)=v(3); cond3(k)=v(4); resp(k)=v(5);
    end
    mask = ismember(resp,[1 2 3]);
    T = table(cond1(mask),cond2(mask),cond3(mask),resp(mask), ...
              'VariableNames',{'cond1','cond2','cond3','resp'});
end