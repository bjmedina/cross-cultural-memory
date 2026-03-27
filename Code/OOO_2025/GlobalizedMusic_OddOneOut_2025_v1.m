function GlobalizedMusic_OddOneOut_2025_v1(subject, STATION, n_trials)
% GlobalizedMusic_OddOneOut_2025_v1(subject, STATION, n_trials)
%
%   Odd-One-Out task with globalized music.
%   Each trial presents 3 distinct sounds randomly selected from 80 total.
%   Participant identifies which sound is most distinct (1, 2, or 3).
%
%   The participant may replay the 3-sound sequence before responding.
%
%   Inputs:
%       subject     - string, participant ID
%       STATION     - numeric code for loudness calibration
%       n_trials    - number of trials to run (e.g. 40)
%
%   Bryan Medina - Oct 28, 2025
%   Adapted from GlobalizedMusic_OddOneOut_2025_v1

% ---------------- SETUP ----------------
rng('shuffle');
Screen('Preference', 'SkipSyncTests', 1);
oldEnableFlag = Screen('Preference', 'SuppressAllWarnings');
InitializePsychSound;
warning('off','all');

expmt_suffix = ['_GMOddOneOut_v1_' date];
data_dir = '~/Tsimane2025/Data/OOO_2025/IndustrialNature/';
stim_dir = '~/static2025/Stimuli/OOO_2025/global-music-2025-n_80/';
desired_level = 75;
sr = 44100; nchannels = 2;

pahandle = PsychPortAudio('Open', [], [], 0, sr, nchannels);

n_stims = 80; % total available stimuli
stim_indices = 1:n_stims;

% ---------------- FILE CHECKING ----------------
par_fname = fullfile(data_dir, [subject expmt_suffix '.par']);
rsp_fname = fullfile(data_dir, [subject expmt_suffix '.rsp']);
now_fname = fullfile(data_dir, [subject expmt_suffix '.now']);

fid = fopen(par_fname,'r+t');
if fid ~= -1
    fclose(fid);
    start_trial = load(now_fname) + 1;
    load(par_fname, 'trial_params', '-mat');
else
    % generate random triplets
    triplets = nan(n_trials, 3);
    for i = 1:n_trials
        triplets(i,:) = randperm(n_stims, 3);
    end
    trial_params = triplets;
    save(par_fname, 'trial_params', '-mat');
    
    fid = fopen(rsp_fname,'wt');
    fprintf(fid, ['Results for %s, Globalized Music Odd-One-Out Experiment\n'], subject);
    fprintf(fid, 'Time\tTrialN\tCond1\tCond2\tCond3\tResp\tRT\tRep\tInstr\n');
    fclose(fid);
    
    TrialN = 0; save(now_fname,'TrialN','-ASCII');
    start_trial = 1;
end

total_trials = size(trial_params,1);
fprintf('\nOdd-One-Out Globalized Music Experiment starting.\n');
fprintf('You will hear 3 sounds. Choose which one is most distinct (1, 2, or 3).\n');
input('Press ENTER to begin.\n');

WaitSecs(0.7);

% ---------------- MAIN LOOP ----------------
for k = start_trial:total_trials
    stim_ids = trial_params(k,:);
    fprintf('\nTrial %d / %d\n', k, total_trials);
    
    % ---------- Load, play, and collect response ----------
    OutWav = cell(1,3);
    for j = 1:3
        filename = sprintf('%smem_stim_%d.wav', stim_dir, stim_ids(j)-1);
        [stim_s, sr] = audioread(filename);
        OutWav{j} = set_level_wrapper(stim_s, sr, desired_level, STATION);
    end

    n_repeats = 0;
    resp = [];

    while isempty(resp)
        % --- Play all 3 sounds ---
        n_repeats = n_repeats + 1;
        for j = 1:3
            PsychPortAudio('FillBuffer', pahandle, OutWav{j}');
            PsychPortAudio('Start', pahandle, 1, 0, 1);
            WaitSecs(size(OutWav{j},1)/sr + 0.25); % 250 ms ISI
        end
        WaitSecs(0.5);

        % --- Get response or replay command ---
        resp_str = input('Which sound was most distinct? (1,2,3 or r=repeat): ','s');
        if any(strcmpi(resp_str, {'1','2','3'}))
            resp = str2double(resp_str);
        elseif strcmpi(resp_str, 'r')
            fprintf('Replaying triplet...\n');
            continue;
        else
            fprintf('Invalid input. Please enter 1, 2, 3, or r.\n');
        end
    end

    RT = toc;  % only if you start tic() before this section
    
    % Optional post-trial instruction (like notes or "hard/easy" tag)
    instr = 0;
    
    % Save response
    fid = fopen(rsp_fname,'at');
    fprintf(fid,'%22s %2d ', datestr(clock,0), k);
    fprintf(fid,'%6d %6d %6d ', stim_ids(1), stim_ids(2), stim_ids(3));
    fprintf(fid,'%6d %2.5f %6d %6d\n', resp, RT, n_repeats, instr);
    fclose(fid);
    
    TrialN = k; save(now_fname,'TrialN','-ASCII');
    WaitSecs(0.7);
end

disp('Experiment complete! Thank you.');

PsychPortAudio('Close', pahandle);
Screen('Preference','SuppressAllWarnings', oldEnableFlag);

end