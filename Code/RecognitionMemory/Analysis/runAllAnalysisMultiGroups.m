function outs = runAllAnalysisMultiGroups(groupPlaceCodes, groupLabels, minISI0dprime, varargin)
% runAllAnalysisMultiGroups  Run aggregate multi-group d' plots across conditions.
%
%   outs = runAllAnalysisMultiGroups(groupPlaceCodes, groupLabels, minISI0dprime, ...
%                                    'BaseDir', baseDir, ...
%                                    'Conditions', conditionsCell, ...
%                                    'Save', true/false, ...
%                                    'OutDir', outDir)
%
%   Inputs:
%     groupPlaceCodes : 1xG cell, each cell is a cellstr of place codes for a group
%                       e.g., { {'PRO'}, {'MAN','MAJ','NVM','NUM','NUV','CVR'} }
%     groupLabels     : 1xG cellstr label per group (use [] to auto-build)
%     minISI0dprime   : numeric threshold for subject inclusion based on ISI=0 d'
%
%   Name-Value options:
%     'BaseDir'    : root folder containing .mat files
%                    default: ~/Documents/School/MIT/labs/mcdermott/Tsimane2025/Data/RecognitionMemory/Results
%     'Conditions' : cellstr of conditions to process
%                    default: {'NHS','Industrial-Nature','Textures','Globalized-Music'}
%     'Save'       : logical, save figures (default: true)
%     'OutDir'     : override output directory (default: <BaseDir>/figures/<condition>)
%
%   Output:
%     outs         : struct with one field per condition; each contains the
%                    struct returned by plotAggregateDprimeMulti for that condition.
%
%   Example:
%     placeCodesA = {'PRO'};
%     placeCodesB = {'MAN','MAJ','NVM','NUM','NUV','CVR'};
%     groups      = {placeCodesA, placeCodesB};
%     labels      = {'Prolific','Tsimane'};
%     outs = runAllAnalysisMultiGroups(groups, labels, 2.0, ...
%                                      'Conditions', {'Industrial-Nature','Textures'});
%
%   Bryan Medina ? 08-27-25

    % -------- Defaults & parsing --------
    defaultBaseDir = fullfile(getenv('HOME'), 'Documents','School','MIT','labs','mcdermott', ...
                              'Tsimane2025','Data','RecognitionMemory','Results');
    defaultConds   = {'NHS','Industrial-Nature','Textures','Globalized-Music'};
    p = inputParser;
    p.addParameter('BaseDir', defaultBaseDir, @(s) ischar(s) || isstring(s));
    p.addParameter('Conditions', defaultConds, @(c) iscellstr(c) && ~isempty(c));
    p.addParameter('Save', true, @(x) islogical(x) && isscalar(x));
    p.addParameter('OutDir', '', @(s) ischar(s) || isstring(s));
    p.parse(varargin{:});
    baseDir   = char(p.Results.BaseDir);
    conditions = p.Results.Conditions;
    doSave     = p.Results.Save;
    overrideOutDir = char(p.Results.OutDir);

    % Auto-build labels if empty
    if isempty(groupLabels)
        groupLabels = defaultLabels(groupPlaceCodes); % small helper below
    end

    % Basic validation
    assert(iscell(groupPlaceCodes) && ~isempty(groupPlaceCodes), 'groupPlaceCodes must be a non-empty cell.');
    assert(iscellstr(groupLabels) && numel(groupLabels)==numel(groupPlaceCodes), ...
           'groupLabels must be a cellstr with one label per group.');

    % -------- Run per condition --------
    outs = struct();
    for c = 1:numel(conditions)
        cond = conditions{c};
        fprintf('\n=== Processing condition: %s ===\n', cond);

        % Choose per-condition outdir (use override if provided)
        if isempty(overrideOutDir)
            outDir = fullfile(baseDir, 'figures', cond);
        else
            outDir = overrideOutDir;
        end

        % Call your multi-group aggregator/plotter
        outs.(sanitizeField(cond)) = plotAggregateDprimeMulti( ...
            baseDir, ...
            groupPlaceCodes, ...
            cond, ...
            minISI0dprime, ...
            'GroupLabels', groupLabels, ...
            'Save', doSave, ...
            'OutDir', outDir);
        
%         
%         % Stimulus-type hit rates (multi-group) ? always run
%         outs.(sanitizeField(cond)).stimTypes = plotStimulusTypeHitRatesMulti( ...
%             baseDir, ...
%             groupPlaceCodes, ...
%             cond, ...
%             minISI0dprime, ...
%             'GroupLabels', groupLabels, ...
%             'Save', doSave, ...
%             'OutDir', outDir);
    end

    % -------- Final message --------
    fprintf('\nAll multi-group d'' analyses complete.\n');
    if doSave
        fprintf('Open figures folder with:\n!open %s\n', fullfile(baseDir,'figures'));
    end
end

% ---- Helper: default legend labels from place-code groups ----
function labels = defaultLabels(groupPlaceCodes)
    labels = cell(1, numel(groupPlaceCodes));
    for i = 1:numel(groupPlaceCodes)
        pc = groupPlaceCodes{i};
        if any(strcmpi(pc,'ALL'))
            labels{i} = 'ALL';
        else
            labels{i} = strjoin(pc, '+');
        end
    end
end

% ---- Helper: sanitize strings to valid struct field names ----
function f = sanitizeField(s)
    % Replace non-alphanumeric with underscores; ensure starts with letter
    f = regexprep(char(s), '[^A-Za-z0-9]', '_');
    if isempty(f) || ~isletter(f(1)), f = ['c_' f]; end
end