function outDir = UTILS_buildOutputDir(baseDir, condition)
% UTILS_buildOutputDir
%   Create and return the standard output directory for figures or results.
%
%   outDir = UTILS_buildOutputDir(baseDir, condition)
%
%   Inputs:
%     baseDir   - base directory (e.g., '~/Tsimane2025/Data/RecognitionMemory')
%     condition - string identifying the experimental condition
%
%   Output:
%     outDir    - full path to the output directory
%
%   Example:
%     outDir = UTILS_buildOutputDir('~/Tsimane2025/Data/RecognitionMemory', 'Industrial-Nature')
%
%   This will create (if needed):
%       ~/Tsimane2025/Data/RecognitionMemory/figures/Industrial-Nature/
%
%   Bryan Medina ? Bolivia 2025

    % ensure baseDir exists
    if ~exist(baseDir, 'dir')
        error('Base directory does not exist: %s', baseDir);
    end

    % build path
    outDir = fullfile(baseDir, 'figures', condition);

    % create if missing
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
end