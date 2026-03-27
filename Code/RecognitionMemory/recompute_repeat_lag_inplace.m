function results = recompute_repeat_lag_inplace(dirPath, varargin)
% Recompute repeatPosition = trials-since-previous-occurrence (NaN for non-repeats).
% Args: dirPath, 'Pattern','*.mat', 'Backup',true, 'BackupDir','backup', 'Verbose',true

p = inputParser;
p.addRequired('dirPath', @(s)ischar(s)||isstring(s));
p.addParameter('Pattern','*.mat', @(s)ischar(s)||isstring(s));
p.addParameter('Backup',true, @(b)islogical(b)||isnumeric(b));
p.addParameter('BackupDir','backup', @(s)ischar(s)||isstring(s));
p.addParameter('Verbose',true, @(b)islogical(b)||isnumeric(b));
p.parse(dirPath, varargin{:});
args = p.Results;

files = dir(fullfile(char(args.dirPath), char(args.Pattern)));
if args.Backup
    bdir = fullfile(char(args.dirPath), char(args.BackupDir));
    if ~exist(bdir,'dir'), mkdir(bdir); end
end

results = struct('file',{},'changed',{},'msg',{});
for k = 1:numel(files)
    f = fullfile(files(k).folder, files(k).name);
    rec.file = f; rec.changed = false; rec.msg = '';
    try
        S = load(f);
        if ~isfield(S,'data') || ~isfield(S.data,'stimulusPresented') || ~isfield(S.data,'containsRepeat')
            rec.msg = 'missing fields'; results(end+1)=rec; continue
        end
        stim = string(S.data.stimulusPresented(:));
        rep  = logical(S.data.containsRepeat(:));
        n    = numel(stim);
        rp   = nan(n,1);
        lastSeen = containers.Map('KeyType','char','ValueType','double');
        for i = 1:n
            si = char(stim(i));
            if rep(i)
                if isKey(lastSeen, si)
                    rp(i) = i - lastSeen(si);
                else
                    % if JSON incorrectly marks a first occurrence as repeat, set to 0
                    rp(i) = 0;
                end
            end
            if ~isKey(lastSeen, si), lastSeen(si) = i; else, lastSeen(si) = i; end
        end
        if args.Backup, copyfile(f, fullfile(files(k).folder, args.BackupDir, files(k).name)); end
        S.data.repeatPosition = rp;
        save(f, '-struct', 'S', '-v7');
        rec.changed = true; rec.msg = 'repeatPosition recomputed';
        results(end+1)=rec;
        if args.Verbose, fprintf('[ok] %s\n', files(k).name); end
    catch ME
        rec.msg = ME.message; results(end+1)=rec;
        if args.Verbose, fprintf('[err] %s -> %s\n', files(k).name, ME.message); end
    end
end
end