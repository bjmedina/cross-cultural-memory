function results = flatten_mat_data_field(dirPath, varargin)
% FLATTEN_MAT_DATA_FIELD  Promote fields from 'data' struct to top-level vars in many .mat files.
% Usage:
%   results = flatten_mat_data_field('/path/to/mats', ...
%       'Pattern','*.mat', 'Backup',true, 'BackupDir','backup', ...
%       'IncludeOtherVars',true, 'Verbose',true)
%
% Inputs (name/value):
%   dirPath           : folder of .mat files
%   'Pattern'         : file pattern (default '*.mat')
%   'Backup'          : make a copy before overwrite (default true)
%   'BackupDir'       : subfolder for backups (default 'backup')
%   'IncludeOtherVars': keep non-'data' variables that were in the file (default true)
%   'Verbose'         : print progress (default true)
%
% Output:
%   results : struct array with fields: file, changed, msg

% --------------------------- args ---------------------------
p = inputParser;
p.addRequired('dirPath', @(s)ischar(s) || isstring(s));
p.addParameter('Pattern','*.mat', @(s)ischar(s) || isstring(s));
p.addParameter('Backup',true, @(b)islogical(b) || isnumeric(b));
p.addParameter('BackupDir','backup', @(s)ischar(s) || isstring(s));
p.addParameter('IncludeOtherVars',true, @(b)islogical(b) || isnumeric(b));
p.addParameter('Verbose',true, @(b)islogical(b) || isnumeric(b));
p.parse(dirPath, varargin{:});
args = p.Results;

dirPath = char(dirPath);
pattern = char(args.Pattern);
backupFlag = logical(args.Backup);
backupDir = char(args.BackupDir);
keepOthers = logical(args.IncludeOtherVars);
verbose = logical(args.Verbose);

if ~isfolder(dirPath), error('Folder not found: %s', dirPath); end
files = dir(fullfile(dirPath, pattern));

if backupFlag
    bdir = fullfile(dirPath, backupDir);
    if ~exist(bdir,'dir'), mkdir(bdir); end
end

results = struct('file',{},'changed',{},'msg',{});

% ------------------------ main loop -------------------------
for k = 1:numel(files)
    fpath = fullfile(files(k).folder, files(k).name);
    rec.file = fpath; rec.changed = false; rec.msg = '';

    try
        info = whos('-file', fpath);
        hasData = any(strcmp({info.name}, 'data'));

        if ~hasData
            rec.msg = 'no ''data'' var; skipped';
            results(end+1) = rec; %#ok<AGROW>
            if verbose, fprintf('[skip] %s (no data)\n', files(k).name); end
            continue
        end

        S = load(fpath, '-mat');               % load everything
        if ~isstruct(S.data)
            rec.msg = '''data'' exists but is not a struct; skipped';
            results(end+1) = rec; %#ok<AGROW>
            if verbose, fprintf('[skip] %s (data not struct)\n', files(k).name); end
            continue
        end

        % Build output struct M by promoting fields of S.data
        M = S.data;                             % promoted fields become top-level vars

        if keepOthers
            otherNames = setdiff(fieldnames(S), {'data'});
            for i = 1:numel(otherNames)
                nm = otherNames{i};
                if ~isfield(M, nm)              % avoid collision; data fields take precedence
                    M.(nm) = S.(nm);
                end
            end
        end

        % Optional: ensure column vectors for 1-D numeric/logical arrays
        fns = fieldnames(M);
        for i = 1:numel(fns)
            v = M.(fns{i});
            if (isnumeric(v) || islogical(v)) && isvector(v)
                M.(fns{i}) = v(:);              % make column
            end
        end

        % Backup then overwrite
        if backupFlag
            copyfile(fpath, fullfile(files(k).folder, backupDir, files(k).name));
        end

        % Save: each field of M becomes a top-level variable in the MAT
        save(fpath, '-struct', 'M', '-v7');     % use -v7 unless you need -v7.3

        rec.changed = true;
        rec.msg = sprintf('flattened %d fields', numel(fieldnames(S.data)));
        results(end+1) = rec; %#ok<AGROW>
        if verbose, fprintf('[ok]   %s -> flattened\n', files(k).name); end

    catch ME
        rec.msg = sprintf('ERROR: %s', ME.message);
        results(end+1) = rec; %#ok<AGROW>
        if verbose, fprintf('[err]  %s -> %s\n', files(k).name, ME.message); end
    end
end
end