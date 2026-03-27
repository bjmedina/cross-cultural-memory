function [stats, items_hit, items_fa, T_hit, T_fa] = intergroupReliabilityScatterText_JSONByCondition( ...
    baseDir, placeCodesA, placeCodesB, condition, minISI0dprime, outPrefix, labelField)
% intergroupReliabilityScatterText_JSONByCondition
%   Intergroup scatter (A vs B) with TEXT labels from
%   ~/static2025/Stimuli/RecognitionMemory/<expFolder>/filenames.json.
%   <expFolder> inferred from 'condition'. Uses subplot (pre-R2019b safe).
%
% Inputs:
%   baseDir        : root folder with participant .mat files
%   placeCodesA    : cellstr, group A (e.g., {'BOS','CAM'} or {'ALL'})
%   placeCodesB    : cellstr, group B (e.g., {'TSI'} or {'ALL'})
%   condition      : 'NHS' | 'Industrial-Nature' | 'Textures' | 'Global-Music'
%   minISI0dprime  : numeric participant filter
%   outPrefix      : output filename prefix (string)
%   labelField     : JSON field to display as label (default 'type')
%
% Outputs:
%   stats   : struct with fields .hit and .fa (r, slope, intercept, nItems)
%   items_* : string vectors of aligned items (hits/FAs)
%   T_*     : tables {item, A, B, label} used to draw each panel

    if nargin < 6 || isempty(outPrefix), outPrefix = 'igr-scatter'; end
    if nargin < 7 || isempty(labelField), labelField = 'type'; end

    % ---------- Resolve experiment folder & JSON ----------
%     expFolder = mapConditionToFolder(condition);
%     % If you prefer ~ expansion, use expanduser and '~' instead of absolute pieces.
%     jsonPath  = fullfile('Users','bjm','Documents','School','MIT','labs','mcdermott', ...
%                          'static2025','Stimuli','RecognitionMemory',expFolder,'filenames.json');
                     
                     
    expFolder = mapConditionToFolder(condition);                  % maps to e.g., 'nhs-region-n_80'
    jsonPath  = expanduser(fullfile('Users','bjm', 'Documents', 'School', 'MIT', 'labs', 'mcdermott', 'static2025','Stimuli','RecognitionMemory',expFolder,'filenames.json'));

    if ~isfile(jsonPath)
        error('filenames.json not found: %s', jsonPath);
    end

    % ---------- Find participant files ----------
    filesA = getRecognitionMemFiles(baseDir, placeCodesA, condition, minISI0dprime);
    filesB = getRecognitionMemFiles(baseDir, placeCodesB, condition, minISI0dprime);
    if isempty(filesA) || isempty(filesB)
        error('No files for one or both groups. A=%d, B=%d', numel(filesA), numel(filesB));
    end
    
    % --- Build filename -> labelField lookup from JSON ---
    lookup = makeJsonLookup(jsonPath, labelField);               % containers.Map('filename'->label)

    % --- Shared items and per-participant matrices for both trial types ---
    [items_hit,  Ra_hit,  Rb_hit ] = buildAlignedMatrices(filesA, filesB, 'hit');
    [items_fa,   Ra_fa,   Rb_fa  ] = buildAlignedMatrices(filesA, filesB, 'fa');

    % --- Participant means (omit NaNs) ---
    [A_hit, B_hit] = meanAcrossParticipants(Ra_hit, Rb_hit);
    [A_fa,  B_fa ] = meanAcrossParticipants(Ra_fa,  Rb_fa );

    % --- Labels from JSON (fallback to the bare filename) ---
    labels_hit = itemsToJsonLabels(items_hit, lookup);
    labels_fa  = itemsToJsonLabels(items_fa,  lookup);

    % --- Tables for reproducibility/debug ---
    T_hit = table(items_hit(:), A_hit(:), B_hit(:), labels_hit(:), 'VariableNames', {'item','A','B','label'});
    T_fa  = table(items_fa(:),  A_fa(:),  B_fa(:),  labels_fa(:),  'VariableNames', {'item','A','B','label'});

    % --- Basic stats for titles ---
    stats = struct();
    stats.hit = fitAndCorr(A_hit, B_hit);
    stats.fa  = fitAndCorr(A_fa,  B_fa );

    % --- Output paths ---
    if any(strcmpi(placeCodesA,'ALL')), placeTagA='ALL'; else, placeTagA = strjoin(placeCodesA,'_'); end
    if any(strcmpi(placeCodesB,'ALL')), placeTagB='ALL'; else, placeTagB = strjoin(placeCodesB,'_'); end
    outDir = fullfile(baseDir,'figures',condition);
    if ~exist(outDir,'dir'), mkdir(outDir); end
    writetable(T_hit, fullfile(outDir, sprintf('%s-HITS_%s_vs_%s-%s.csv', outPrefix, placeTagA, placeTagB, safetag(condition))));
    writetable(T_fa,  fullfile(outDir, sprintf('%s-FAS_%s_vs_%s-%s.csv',  outPrefix, placeTagA, placeTagB, safetag(condition))));

    % --- Figure (two subplots: Hits | FAs) ---
    f = figure('Color','w','Position',[100 100 1200 520]);

    % Panel 1: Hits
    subplot(1,2,1);
    textScatterLabeled(A_hit, B_hit, labels_hit);
    title(sprintf('HITS  %s vs %s  (r=%.3f, n=%d)\n%s', placeTagA, placeTagB, stats.hit.r, stats.hit.nItems, condition), ...
          'Interpreter','none');
    addRefAndFit(A_hit, B_hit, stats.hit.slope, stats.hit.intercept);
    xlabel(sprintf('%s mean hit rate', placeTagA)); ylabel(sprintf('%s mean hit rate', placeTagB));
    axis equal; xlim([0 1]); ylim([0 1]); grid on;

    % Panel 2: FAs
    subplot(1,2,2);
    textScatterLabeled(A_fa, B_fa, labels_fa);
    title(sprintf('FALSE ALARMS  %s vs %s  (r=%.3f, n=%d)\n%s', placeTagA, placeTagB, stats.fa.r, stats.fa.nItems, condition), ...
          'Interpreter','none');
    addRefAndFit(A_fa, B_fa, stats.fa.slope, stats.fa.intercept);
    xlabel(sprintf('%s mean FA rate', placeTagA)); ylabel(sprintf('%s mean FA rate', placeTagB));
    axis equal; xlim([0 1]); ylim([0 1]); grid on;

    % Save figure
    figName = sprintf('%s-text_%s_vs_%s-%s.png', outPrefix, placeTagA, placeTagB, safetag(condition));
    saveas(f, fullfile(outDir, figName));
    fprintf('Saved figure to %s\n', fullfile(outDir, figName));
end

% ============================= Helpers =============================

function expFolder = mapConditionToFolder(condition)
% Map condition -> experiment folder in RecognitionMemory/.
    switch string(condition)
        case "NHS"
            expFolder = 'nhs-region-n_80';
        case "Industrial-Nature"
            expFolder = 'mem_exp_ind-nature_2025-07-21-25';
        case "Textures"
            expFolder = 'mem_exp_atexts_2025';
        case "Global-Music"
            expFolder = 'global-music-2025-n_80';
        otherwise
            error('Unknown condition: %s', string(condition));
    end
end

function pathOut = expanduser(pathIn)
% Expand '~' prefix to $HOME (for fileread/jsondecode on POSIX).
    pathIn = string(pathIn);
    if startsWith(pathIn, "~")
        home = getenv('HOME');
        pathOut = fullfile(home, extractAfter(pathIn, 1));
    else
        pathOut = char(pathIn);
    end
end

function lookup = makeJsonLookup(jsonPath, labelField)
% Build containers.Map(filename -> labelField) from filenames.json.
% Requires JSON with fields 'filename' and labelField.
    S = jsondecode(fileread(jsonPath));               % struct array
    if ~isfield(S, 'filename') || ~isfield(S, labelField)
        error('JSON must contain fields "filename" and "%s".', labelField);
    end
    K = arrayfun(@(x) string(x.filename), S, 'UniformOutput', true);
    V = arrayfun(@(x) string(x.(labelField)), S, 'UniformOutput', true);
    [Kuniq, ia] = unique(K, 'stable');                % keep first if duplicates
    Vuniq = V(ia);
    lookup = containers.Map(cellstr(Kuniq), cellstr(Vuniq));
end

% ---- Replace your itemsToJsonLabels with this (forces string output) ----
function labels = itemsToJsonLabels(items, lookup)
    % Map full paths -> filename -> label via JSON; fallback to filename.
    items  = string(items);                 % normalize input
    labels = strings(size(items));          % prealloc string array
    for i = 1:numel(items)
        fn = onlyFilename(items(i));        % 'mem_stim_XX.wav' as string
        if isKey(lookup, char(fn))
            labels(i) = string(lookup(char(fn)));
        else
            labels(i) = fn;                 % fallback to filename
        end
    end
end

% ---- Replace your onlyFilename with this ----
function s = onlyFilename(p)
    % Return 'name.ext' as a STRING regardless of input type/path.
    p = string(p);                          % normalize input to string scalar
    [~, name, ext] = fileparts(char(p));    % fileparts returns char
    if isempty(ext)
        s = string(name);
    else
        s = string(name) + string(ext);     % string concatenation (safe)
    end
end

function [itemsAB, Ra, Rb] = buildAlignedMatrices(filesA, filesB, trialType)
% Shared items + per-participant matrices aligned to them.
    itemsA = unionOfItems(filesA, trialType);
    itemsB = unionOfItems(filesB, trialType);
    [itemsAB, ~, ~] = intersect(itemsA, itemsB, 'stable'); % preserve A order
    if isempty(itemsAB)
        warning('No shared items for trialType=%s.', trialType);
        Ra = nan(0,0); Rb = nan(0,0); return;
    end
    Ra = participantItemRates(filesA, itemsAB, trialType);
    Rb = participantItemRates(filesB, itemsAB, trialType);
end

function [Amean, Bmean] = meanAcrossParticipants(Ra, Rb)
% Average across participants, per item (omit NaNs).
    if isempty(Ra), Amean = []; else, Amean = mean(Ra, 1, 'omitnan'); end
    if isempty(Rb), Bmean = []; else, Bmean = mean(Rb, 1, 'omitnan'); end
    Amean = Amean(:); Bmean = Bmean(:);
end

function s = fitAndCorr(x, y)
% Pearson r and OLS fit y = m*x + b on valid pairs.
    valid = ~(isnan(x) | isnan(y));
    xv = x(valid); yv = y(valid);
    s = struct('r', NaN, 'nItems', numel(xv), 'slope', NaN, 'intercept', NaN);
    if numel(xv) >= 3
        s.r = corr(xv, yv, 'type', 'Pearson', 'rows', 'pairwise');
        P = polyfit(xv, yv, 1);
        s.slope = P(1); s.intercept = P(2);
    end
end

% ---- (Optional) make text plotting extra-robust on older MATLAB ----
function textScatterLabeled(x, y, labels)
    % Place text labels at (x,y); clamp to [0,1]; light de-overlap; draw y=x.
    x = max(0, min(1, x)); 
    y = max(0, min(1, y));
    labels = string(labels);                % ensure string for indexing, cast to char when drawing
    hold on;
    [~, idx] = sortrows([x y]);
    x = x(idx); y = y(idx); labels = labels(idx);
    epsJit = 1e-3;
    for i = 2:numel(x)
        if abs(x(i)-x(i-1)) < 2*epsJit && abs(y(i)-y(i-1)) < 2*epsJit
            x(i) = x(i) + epsJit * i; 
            y(i) = y(i) + epsJit * i;
        end
    end
    for i = 1:numel(x)
        text(x(i), y(i), char(labels(i)), ...  % cast to char for max compatibility
            'Interpreter','none', ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', ...
            'FontSize', 9);
    end
    plot([0 1],[0 1],'k:','LineWidth',1); 
    box on;
end

function addRefAndFit(x, y, m, b)
% Draw OLS fit line if available.
    if ~isnan(m) && ~isnan(b)
        xx = linspace(0,1,100); yy = m*xx + b;
        plot(xx, yy, '-', 'LineWidth', 1.5);
    end
end

function items = unionOfItems(files, trialType)
% Union of items that qualify for trialType across participant files.
    items = string([]);
    for i = 1:numel(files)
        [SP, rp] = loadSP_RP(files{i});
        SP = string(SP(:)); rp = rp(:);
        switch lower(trialType)
            case 'hit', mask = ~isnan(rp) & rp > 1;   % nonzero-ISI repeats
            case 'fa',  mask = isnan(rp);             % first presentations
            otherwise, error('trialType must be ''hit'' or ''fa''.');
        end
        if any(mask), items = union(items, unique(SP(mask))); end
    end
end

function R = participantItemRates(files, itemsAB, trialType)
% Per-participant x item matrix of rates for the requested trialType.
    nSub   = numel(files);
    nItems = numel(itemsAB);
    R = nan(nSub, nItems);
    for i = 1:nSub
        [SP, rp, ic] = loadSP_RP_IC(files{i});
        SP = string(SP(:)); rp = rp(:); ic = logical(ic(:));
        switch lower(trialType)
            case 'hit'
                mask = ~isnan(rp) & rp > 1;
                if any(mask)
                    [G, ids] = findgroups(SP(mask));
                    val = splitapply(@mean, double(ic(mask)), G);      % hit rate
                    uids = unique(ids);
                    [~, ia, ib] = intersect(itemsAB, uids, 'stable');
                    R(i, ia) = val(ib);
                end
            case 'fa'
                mask = isnan(rp);
                if any(mask)
                    [G, ids] = findgroups(SP(mask));
                    val = splitapply(@mean, 1 - double(ic(mask)), G);  % FA rate
                    uids = unique(ids);
                    [~, ia, ib] = intersect(itemsAB, uids, 'stable');
                    R(i, ia) = val(ib);
                end
        end
    end
end

function [SP, rp] = loadSP_RP(file)
% Load SP and rp (top-level or under 'data').
    Sraw = load(file,'-mat');
    if isfield(Sraw,'data'), D = Sraw.data; else, D = Sraw; end
    SP = D.stimulusPresented; rp = D.repeatPosition;
end

function [SP, rp, ic] = loadSP_RP_IC(file)
% Load SP, rp, ic (top-level or under 'data').
    Sraw = load(file,'-mat');
    if isfield(Sraw,'data'), D = Sraw.data; else, D = Sraw; end
    SP = D.stimulusPresented; rp = D.repeatPosition; ic = D.isResponseCorrect;
end

function tag = safetag(str)
% Safe-ish tag for filenames.
    tag = regexprep(str, '[^A-Za-z0-9_\-]+', '_');
end