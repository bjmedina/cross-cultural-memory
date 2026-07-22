function run_deck_repro()
% Run the GENUINE v1 deck pipeline (runIntergroupCorrelationPipeline) as-is on
% the cluster data, to regenerate the bolivia_results.pdf between-group bars and
% confirm the equal-N (nEqual=100) participant-subsample error-bar mechanism.
root = '/orcd/data/jhm/001/om2/bjmedina/cross-cultural-memory/Code/RecognitionMemory';
addpath(genpath(fullfile(root, 'Analysis-Scripts')));
addpath(genpath(fullfile(root, 'Analysis')));

baseDir = '/orcd/data/jhm/001/om2/bjmedina/cross-cultural-memory/Data/RecognitionMemory/Results';
OUTDIR  = fullfile(root, 'Analysis-Scripts-v2', 'bolivia_recreation_outputs', 'matlab_original');
if ~exist(OUTDIR, 'dir'), mkdir(OUTDIR); end

% Group order matches the pipeline's bar labels:
%   A = US/Prolific, B = Tsimane, C = San Borja
%   ac=(US,SanBorja)=SB-US  ab=(US,Tsimane)=Tsi-US  bc=(Tsimane,SanBorja)=Tsi-SB
A = {'PRO','BOS','CAM'};                      % US / Prolific
B = {'NVM','MAJ','MAN','NUM','NUV','CVR'};    % Tsimane
C = {'SBO','SNB','SBJ'};                      % San Borja

conds  = {'Globalized-Music', 'Industrial-Nature'};
trials = {'hit', 'fa'};

for ci = 1:numel(conds)
    for ti = 1:numel(trials)
        fprintf('\n\n########## %s | %s ##########\n', conds{ci}, trials{ti});
        try
            runIntergroupCorrelationPipeline(baseDir, trials{ti}, conds{ci}, A, B, C);
            % capture whatever figure the pipeline just drew/saved
            f = gcf;
            saveas(f, fullfile(OUTDIR, sprintf('deck_%s_%s.png', conds{ci}, trials{ti})));
            fprintf('Saved copy to %s\n', fullfile(OUTDIR, sprintf('deck_%s_%s.png', conds{ci}, trials{ti})));
        catch ME
            fprintf(2, 'ERROR on %s|%s: %s\n', conds{ci}, trials{ti}, ME.message);
            disp(getReport(ME));
        end
        close all;
    end
end
fprintf('\nDONE run_deck_repro\n');
end
