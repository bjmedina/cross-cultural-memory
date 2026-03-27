function [stats, items_hit, items_fa, T_hit, T_fa, perType] = intergroupReliabilityScatterText_JSONByCondition_v2( ...
    baseDir, placeCodesA, placeCodesB, condition, minISI0dprime, outPrefix, labelField)
% intergroupReliabilityScatterText_JSONByCondition
%   Intergroup scatter (A vs B) with TEXT labels from
%   ~/static2025/Stimuli/RecognitionMemory/<expFolder>/filenames.json.
%   <expFolder> inferred from 'condition'. Uses subplot (pre-R2019b safe).
%   Also produces a per-type analysis: separate panels/CSVs per unique label.
%
% Inputs:
%   baseDir        : root folder with participant .mat files
%   placeCodesA    : cellstr, group A (e.g., {'BOS','CAM'} or {'ALL'})
%   placeCodesB    : cellstr, group B (e.g., {'TSI'} or {'ALL'})
%   condition      : 'NHS' | 'Industrial-Nature' | 'Textures' | 'Global-Music'
%   minISI0dprime  : numeric participant filter
%   outPrefix      : output filename prefix (string)
%   labelField     : JSON field to display/group (default 'type')
%
% Outputs:
%   stats     : struct with fields .hit and .fa (r, slope, intercept, nItems)
%   items_*   : string vectors of aligned items (hits/FAs)
%   T_*       : tables {item, A, B, label} used to draw overall panels
%   perType   : struct with one field per label level containing:
%               .level, .T_hit, .T_fa, .stats_hit, .stats_fa
%
% Notes:
%   - If a JSON lookup is missing, labels fall back to the bare filename.
%   - Per-type figure: 2 x K subplots (K = #unique labels). Top row: hits; bottom: FAs.

    if nargin < 6 || isempty(outPrefix), outPrefix = 'igr-scatter'; end
    if nargin < 7 || isempty(labelField), labelField = 'type'; end

    % ---------- Resolve experiment folder & JSON ----------
%     expFolder = mapConditionToFolder(condition);
%     % If you prefer ~ expansion, use expanduser and '~' instead of absolute pieces.
%     jsonPath  = fullfile('Users','bjm','Documents','School','MIT','labs','mcdermott', ...
%                          'static2025','Stimuli','RecognitionMemory',expFolder,'filenames.json');
                     
                     
    expFolder = mapConditionToFolder(condition);                  % maps to e.g., 'nhs-region-n_80'
    jsonPath  = expanduser(fullfile('/Users','bjm', 'Documents', 'School', 'MIT', 'labs', 'mcdermott', 'static2025','Stimuli','RecognitionMemory',expFolder,'filenames.json'));

    if ~isfile(jsonPath)
        error('filenames.json not found: %s', jsonPath);
    end

    % ---------- Find participant files ----------
    filesA = getRecognitionMemFiles(baseDir, placeCodesA, condition, minISI0dprime);
    filesB = getRecognitionMemFiles(baseDir, placeCodesB, condition, minISI0dprime);
    if isempty(filesA) || isempty(filesB)
        error('No files for one or both groups. A=%d, B=%d', numel(filesA), numel(filesB));
    end

    % ---------- Build filename -> labelField lookup ----------
    lookup = makeJsonLookup(jsonPath, labelField);  % Map('filename'->label)

    % ---------- Matrices & means for hits and FAs ----------
    [items_hit,  Ra_hit,  Rb_hit ] = buildAlignedMatrices(filesA, filesB, 'hit');
    [items_fa,   Ra_fa,   Rb_fa  ] = buildAlignedMatrices(filesA, filesB, 'fa');
    [A_hit, B_hit] = meanAcrossParticipants(Ra_hit, Rb_hit);
    [A_fa,  B_fa ] = meanAcrossParticipants(Ra_fa,  Rb_fa );

    % ---------- Labels from JSON (fallback = filename) ----------
    labels_hit = itemsToJsonLabels(items_hit, lookup);
    labels_fa  = itemsToJsonLabels(items_fa,  lookup);

    % ---------- Overall CSVs & stats (all items) ----------
    T_hit = table(items_hit(:), A_hit(:), B_hit(:), labels_hit(:), ...
                  'VariableNames', {'item','A','B','label'});
    T_fa  = table(items_fa(:),  A_fa(:),  B_fa(:),  labels_fa(:),  ...
                  'VariableNames', {'item','A','B','label'});

    stats = struct();
    stats.hit = fitAndCorr(A_hit, B_hit);
    stats.fa  = fitAndCorr(A_fa,  B_fa );

    % ---------- Output paths ----------
    if any(strcmpi(placeCodesA,'ALL')), placeTagA='ALL'; else, placeTagA = strjoin(placeCodesA,'_'); end
    if any(strcmpi(placeCodesB,'ALL')), placeTagB='ALL'; else, placeTagB = strjoin(placeCodesB,'_'); end
    outDir = fullfile(baseDir,'figures',condition);
    if ~exist(outDir,'dir'), mkdir(outDir); end

    writetable(T_hit, fullfile(outDir, sprintf('%s-HITS_%s_vs_%s-%s.csv', outPrefix, placeTagA, placeTagB, safetag(condition))));
    writetable(T_fa,  fullfile(outDir, sprintf('%s-FAS_%s_vs_%s-%s.csv',  outPrefix, placeTagA, placeTagB, safetag(condition))));

    % ---------- Overall figure (2 subplots) ----------
    f = figure('Color','w','Position',[100 100 1200 520]);

    % Hits
    subplot(1,2,1);
    textScatterLabeled(A_hit, B_hit, labels_hit);
    title(sprintf('HITS  %s vs %s  (r=%.3f, n=%d)\n%s', ...
          placeTagA, placeTagB, stats.hit.r, stats.hit.nItems, condition), 'Interpreter','none');
    addRefAndFit(A_hit, B_hit, stats.hit.slope, stats.hit.intercept);
    xlabel(sprintf('%s mean hit rate', placeTagA)); ylabel(sprintf('%s mean hit rate', placeTagB));
    axis equal; xlim([0 1]); ylim([0 1]); grid on;

    % FAs
    subplot(1,2,2);
    textScatterLabeled(A_fa, B_fa, labels_fa);
    title(sprintf('FALSE ALARMS  %s vs %s  (r=%.3f, n=%d)\n%s', ...
          placeTagA, placeTagB, stats.fa.r, stats.fa.nItems, condition), 'Interpreter','none');
    addRefAndFit(A_fa, B_fa, stats.fa.slope, stats.fa.intercept);
    xlabel(sprintf('%s mean FA rate', placeTagA)); ylabel(sprintf('%s mean FA rate', placeTagB));
    axis equal; xlim([0 1]); ylim([0 1]); grid on;

    saveas(f, fullfile(outDir, sprintf('%s-text_%s_vs_%s-%s.png', outPrefix, placeTagA, placeTagB, safetag(condition))));

    % =====================================================================
    %                           PER-TYPE ANALYSIS
    % =====================================================================

    % Unique label levels present across both panels
    lvls = unique([labels_hit(:); labels_fa(:)]);
    lvls = lvls(~ismissing(lvls) & strlength(lvls) > 0);
    perType = struct();

    % Figure with 2 x K grid (K = number of types)
    K = numel(lvls);
    if K > 0
        fig2 = figure('Color','w','Position',[50 50 max(900, 420*K) 740]); % wider with more types
        for k = 1:K
            lvl = lvls(k);

            % --- Subset hits to this type ---
            idxH = labels_hit == lvl & ~isnan(A_hit) & ~isnan(B_hit);
            Ah = A_hit(idxH); Bh = B_hit(idxH); Ih = items_hit(idxH); Lh = labels_hit(idxH);

            % --- Subset FAs to this type ---
            idxF = labels_fa == lvl & ~isnan(A_fa) & ~isnan(B_fa);
            Af = A_fa(idxF); Bf = B_fa(idxF); If = items_fa(idxF); Lf = labels_fa(idxF);

            % --- Stats & tables per type ---
            statsH = fitAndCorr(Ah, Bh);
            statsF = fitAndCorr(Af, Bf);
            Th = table(Ih(:), Ah(:), Bh(:), Lh(:), 'VariableNames', {'item','A','B','label'});
            Tf = table(If(:), Af(:), Bf(:), Lf(:), 'VariableNames', {'item','A','B','label'});

            perType.(safetag(char(lvl))) = struct( ...
                'level', string(lvl), ...
                'T_hit', Th, 'T_fa', Tf, ...
                'stats_hit', statsH, 'stats_fa', statsF);

            % Save per-type CSVs
            writetable(Th, fullfile(outDir, sprintf('%s-HITS_%s_vs_%s-%s-%s.csv', ...
                        outPrefix, placeTagA, placeTagB, safetag(condition), safetag(lvl))));
            writetable(Tf, fullfile(outDir, sprintf('%s-FAS_%s_vs_%s-%s-%s.csv', ...
                        outPrefix, placeTagA, placeTagB, safetag(condition), safetag(lvl))));

            % --- Plot hits (row 1, col k) ---
            subplot(2, K, k);
            if ~isempty(Ah)
                textScatterLabeled(Ah, Bh, onlyFilename(Ih));
                title(sprintf('HITS | %s  (r=%.3f, n=%d)', lvl, statsH.r, statsH.nItems), 'Interpreter','none');
                addRefAndFit(Ah, Bh, statsH.slope, statsH.intercept);
            else
                title(sprintf('HITS | %s  (no items)', lvl), 'Interpreter','none');
            end
            xlabel(sprintf('%s', placeTagA)); ylabel(sprintf('%s', placeTagB));
            axis equal; xlim([0 1]); ylim([0 1]); grid on;

            % --- Plot FAs (row 2, col k) ---
            subplot(2, K, K + k);
            if ~isempty(Af)
                textScatterLabeled(Af, Bf, onlyFilename(If));
                title(sprintf('FA | %s  (r=%.3f, n=%d)', lvl, statsF.r, statsF.nItems), 'Interpreter','none');
                addRefAndFit(Af, Bf, statsF.slope, statsF.intercept);
            else
                title(sprintf('FA | %s  (no items)', lvl), 'Interpreter','none');
            end
            xlabel(sprintf('%s', placeTagA)); ylabel(sprintf('%s', placeTagB));
            axis equal; xlim([0 1]); ylim([0 1]); grid on;
        end

        % Save per-type figure
        saveas(fig2, fullfile(outDir, sprintf('%s-text_byType_%s_vs_%s-%s.png', ...
            outPrefix, placeTagA, placeTagB, safetag(condition))));
    end

    fprintf('Saved outputs in %s\n', outDir);
end

% ============================= Helpers =============================

function expFolder = mapConditionToFolder(condition)
    switch string(condition)
        case "NHS"
            expFolder = 'nhs-region-n_80';
        case "Industrial-Nature"
            % Use your current folder name. If you renamed later, update here.
            expFolder = 'mem_exp_ind-nature_2025-07-21-25';
        case "Textures"
            expFolder = 'mem_exp_atexts_2025';
        case "Global-Music"
            expFolder = 'global-music-2025-n_80';
        otherwise
            error('Unknown condition: %s', string(condition));
    end
end

function lookup = makeJsonLookup(jsonPath, labelField)
    S = jsondecode(fileread(jsonPath));        % struct array
    if ~isfield(S, 'filename') || ~isfield(S, labelField)
        error('JSON must contain fields "filename" and "%s".', labelField);
    end
    K = arrayfun(@(x) string(x.filename), S, 'UniformOutput', true);
    V = arrayfun(@(x) string(x.(labelField)), S, 'UniformOutput', true);
    [Kuniq, ia] = unique(K, 'stable');
    Vuniq = V(ia);
    lookup = containers.Map(cellstr(Kuniq), cellstr(Vuniq));
end

function labels = itemsToJsonLabels(items, lookup)
    items  = string(items);
    labels = strings(size(items));
    for i = 1:numel(items)
        fn = onlyFilename(items(i));
        if isKey(lookup, char(fn))
            labels(i) = string(lookup(char(fn)));
        else
            labels(i) = fn;
        end
    end
end

function s = onlyFilename(p)
    p = string(p);
    [~, name, ext] = fileparts(char(p));
    if isempty(ext), s = string(name); else, s = string(name) + string(ext); end
end

function [itemsAB, Ra, Rb] = buildAlignedMatrices(filesA, filesB, trialType)
    itemsA = unionOfItems(filesA, trialType);
    itemsB = unionOfItems(filesB, trialType);
    [itemsAB, ~, ~] = intersect(itemsA, itemsB, 'stable');
    if isempty(itemsAB)
        warning('No shared items for trialType=%s.', trialType);
        Ra = nan(0,0); Rb = nan(0,0); return;
    end
    Ra = participantItemRates(filesA, itemsAB, trialType);
    Rb = participantItemRates(filesB, itemsAB, trialType);
end

function [Amean, Bmean] = meanAcrossParticipants(Ra, Rb)
    if isempty(Ra), Amean = []; else, Amean = mean(Ra, 1, 'omitnan'); end
    if isempty(Rb), Bmean = []; else, Bmean = mean(Rb, 1, 'omitnan'); end
    Amean = Amean(:); Bmean = Bmean(:);
end

function s = fitAndCorr(x, y)
    valid = ~(isnan(x) | isnan(y));
    xv = x(valid); yv = y(valid);
    s = struct('r', NaN, 'nItems', numel(xv), 'slope', NaN, 'intercept', NaN);
    if numel(xv) >= 3
        s.r = corr(xv, yv, 'type', 'Pearson', 'rows', 'pairwise');
        P = polyfit(xv, yv, 1);
        s.slope = P(1); s.intercept = P(2);
    end
end

function textScatterLabeled(x, y, labels)
    x = max(0, min(1, x)); 
    y = max(0, min(1, y));
    labels = string(labels);
    hold on;
    [~, idx] = sortrows([x y]); x = x(idx); y = y(idx); labels = labels(idx);
    epsJit = 1e-3;
    for i = 2:numel(x)
        if abs(x(i)-x(i-1)) < 2*epsJit && abs(y(i)-y(i-1)) < 2*epsJit
            x(i) = x(i) + epsJit * i; 
            y(i) = y(i) + epsJit * i;
        end
    end
    for i = 1:numel(x)
        text(x(i), y(i), char(labels(i)), ...
            'Interpreter','none', ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', ...
            'FontSize', 9);
    end
    plot([0 1],[0 1],'k:','LineWidth',1); 
    box on;
end

function addRefAndFit(x, y, m, b)
    if ~isnan(m) && ~isnan(b)
        xx = linspace(0,1,100); yy = m*xx + b;
        plot(xx, yy, '-', 'LineWidth', 1.5);
    end
end

function items = unionOfItems(files, trialType)
    items = string([]);
    for i = 1:numel(files)
        [SP, rp] = loadSP_RP(files{i});
        SP = string(SP(:)); rp = rp(:);
        switch lower(trialType)
            case 'hit', mask = ~isnan(rp) & rp > 1;
            case 'fa',  mask = isnan(rp);
            otherwise, error('trialType must be ''hit'' or ''fa''.');
        end
        if any(mask), items = union(items, unique(SP(mask))); end
    end
end

function R = participantItemRates(files, itemsAB, trialType)
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
                    val = splitapply(@mean, double(ic(mask)), G);
                    uids = unique(ids);
                    [~, ia, ib] = intersect(itemsAB, uids, 'stable');
                    R(i, ia) = val(ib);
                end
            case 'fa'
                mask = isnan(rp);
                if any(mask)
                    [G, ids] = findgroups(SP(mask));
                    val = splitapply(@mean, 1 - double(ic(mask)), G);
                    uids = unique(ids);
                    [~, ia, ib] = intersect(itemsAB, uids, 'stable');
                    R(i, ia) = val(ib);
                end
        end
    end
end

function [SP, rp] = loadSP_RP(file)
    Sraw = load(file,'-mat');
    if isfield(Sraw,'data'), D = Sraw.data; else, D = Sraw; end
    SP = D.stimulusPresented; rp = D.repeatPosition;
end

function [SP, rp, ic] = loadSP_RP_IC(file)
    Sraw = load(file,'-mat');
    if isfield(Sraw,'data'), D = Sraw.data; else, D = Sraw; end
    SP = D.stimulusPresented; rp = D.repeatPosition; ic = D.isResponseCorrect;
end

function tag = safetag(str)
    tag = regexprep(str, '[^A-Za-z0-9_\-]+', '_');
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