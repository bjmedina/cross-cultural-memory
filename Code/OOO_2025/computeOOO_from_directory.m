function df = loadOOOFile(filepath)
% loadOOOFile
%   Reads a .rsp Odd-One-Out file which is NOT a true table.
%   We parse each line manually using textscan and sscanf.

    fid = fopen(filepath, 'r');
    if fid == -1
        error('Could not open file: %s', filepath);
    end

    % Read header line (contains file description)
    header = fgetl(fid);

    % Preallocate lists
    TrialN = [];
    Cond1 = [];
    Cond2 = [];
    Cond3 = [];
    Resp  = [];
    RT    = [];
    Rep   = [];
    Instr = [];

    % Read each remaining line
    while true
        line = fgetl(fid);
        if ~ischar(line)
            break;
        end

        % Skip empty lines
        if isempty(line) || all(isspace(line))
            continue;
        end

        % Skip first token (timestamp)
        % Extract everything AFTER the timestamp
        tokens = regexp(line, '\s+', 'split');

        % timestamp is the first 2 tokens (date + time)
        if numel(tokens) < 10
            continue; % skip malformed lines
        end

        % Example row:
        % Time TrialN Cond1 Cond2 Cond3 Resp RT Rep Instr
        %
        % tokens = {date, time, TrialN, Cond1, Cond2, Cond3, Resp, RT, Rep, Instr}
        %
        % So we extract tokens{3} through tokens{10}

        TrialN(end+1,1) = str2double(tokens{3});
        Cond1(end+1,1)  = str2double(tokens{4});
        Cond2(end+1,1)  = str2double(tokens{5});
        Cond3(end+1,1)  = str2double(tokens{6});
        Resp(end+1,1)   = str2double(tokens{7});
        RT(end+1,1)     = str2double(tokens{8});
        Rep(end+1,1)    = str2double(tokens{9});
        Instr(end+1,1)  = str2double(tokens{10});
    end

    fclose(fid);

    % Build struct (instead of table)
    df.TrialN = TrialN;
    df.Cond1  = Cond1;
    df.Cond2  = Cond2;
    df.Cond3  = Cond3;
    df.Resp   = Resp;
    df.RT     = RT;
    df.Rep    = Rep;
    df.Instr  = Instr;
end

function stats = computeOddOneOutStats(df)
    all_ids = unique([df.Cond1; df.Cond2; df.Cond3]);

    ooo_count   = zeros(size(all_ids));
    appearances = zeros(size(all_ids));

    all_conds = [df.Cond1; df.Cond2; df.Cond3];
    for i = 1:numel(all_ids)
        appearances(i) = sum(all_conds == all_ids(i));
    end

    nTrials = numel(df.Resp);
    for t = 1:nTrials
        resp = df.Resp(t);

        switch resp
            case 1
                chosen = df.Cond1(t);
            case 2
                chosen = df.Cond2(t);
            case 3
                chosen = df.Cond3(t);
            otherwise
                continue;
        end

        idx = find(all_ids == chosen, 1);
        ooo_count(idx) = ooo_count(idx) + 1;
    end

    stats.sound_ids   = all_ids;
    stats.appearances = appearances;
    stats.ooo_count   = ooo_count;
    stats.ooo_rate    = ooo_count ./ appearances;
end