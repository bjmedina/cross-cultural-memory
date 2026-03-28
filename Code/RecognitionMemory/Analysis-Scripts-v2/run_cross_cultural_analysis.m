% run_cross_cultural_analysis.m
%
% Top-level driver: runs the full cross-cultural recognition memory analysis
% for Globalized-Music and Industrial-Nature, broken out by collection site.
%
% Sites:
%   US        - Prolific (PRO), Boston (BOS), Cambridge (CAM)
%   San Borja - SBO, SNB, SBJ
%   Tsimane   - Nuevo Mundo (NVM), Majal (MAJ), Manguito (MAN),
%               Diversos (NUM, NUV, CVR)
%
% For each condition the pipeline:
%   1. Computes within-site split-half reliability (Spearman, stimulus split)
%   2. Bootstraps cross-site itemwise correlations (raw + attenuation-corrected)
%   3. Runs paired-bootstrap significance tests comparing the three site pairs
%   4. Saves bar-chart figures to Data/RecognitionMemory/Results/figures/<condition>/
%
% Usage (from MATLAB, any working directory):
%   run('<path_to_this_file>/run_cross_cultural_analysis.m')
%
% Bryan Medina -- 2026

% -------------------------------------------------------------------------
% 1. Paths
% -------------------------------------------------------------------------
scriptDir = fileparts(mfilename('fullpath'));
addpath(fullfile(scriptDir, 'utils'));
addpath(fullfile(scriptDir, 'stats'));

% Data directory: relative to this script's location
baseDir = fullfile(scriptDir, '..', '..', '..', 'Data', 'RecognitionMemory', 'Results');
% Resolve any '..' in the path (works in MATLAB 2018b without Java)
origDir = pwd; cd(baseDir); baseDir = pwd; cd(origDir);

if ~exist(baseDir, 'dir')
    error('Data directory not found: %s\nCheck the path relative to this script.', baseDir);
end
fprintf('Data directory: %s\n', baseDir);

% -------------------------------------------------------------------------
% 2. Site definitions
% -------------------------------------------------------------------------
US       = {'PRO', 'BOS', 'CAM'};
SanBorja = {'SBO', 'SNB', 'SBJ'};
Tsimane  = {'NVM', 'MAJ', 'MAN', 'NUM', 'NUV', 'CVR'};

% -------------------------------------------------------------------------
% 3. Conditions to analyse
% -------------------------------------------------------------------------
conditions = {'Globalized-Music', 'Industrial-Nature'};

% -------------------------------------------------------------------------
% 4. Run
% -------------------------------------------------------------------------
results = struct();

for ci = 1:numel(conditions)
    cond    = conditions{ci};
    condKey = strrep(cond, '-', '_');   % valid struct field name

    fprintf('\n\n========================================\n');
    fprintf('Condition: %s\n', cond);
    fprintf('========================================\n');

    for tt = {'hit', 'fa'}
        trial_type = tt{1};
        fprintf('\n--- Trial type: %s ---\n', trial_type);

        results.(condKey).(trial_type) = runIntergroupCorrelationPipeline( ...
            baseDir, trial_type, cond, US, SanBorja, Tsimane);
    end
end

fprintf('\n\nAll done. Figures saved under %s/figures/\n', baseDir);
