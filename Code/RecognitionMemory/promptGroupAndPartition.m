function [group_id, group_name, partition_id] = promptGroupAndPartition()
% promptGroupAndPartitionInts  Prompt user to select group/partition using integers
%
% Outputs:
%   group_id     - numeric group ID (e.g., 1)
%   group_name   - string from mapping (e.g., 'Tsimane')
%   partition_id - string representing partition (e.g., '1', 'odd_low')

    mapFile = fullfile(fileparts(mfilename('fullpath')), 'group_mapping.mat');

    % Load or initialize group mapping
    if isfile(mapFile)
        S = load(mapFile);
        group_ids = S.group_ids;
        group_names = S.group_names;
    else
        group_ids = [1, 2, 3];
        group_names = {'Tsimane', 'SanBorja', 'Boston/U.S.'};
    end

    % Display options
    fprintf('\nWhich cultural group are you working with?\n¿Con qué grupo cultural estás trabajando?:\n');
    fprintf('\t0. Add a new cultural group\n');

    for i = 1:numel(group_ids)
        fprintf('\t%d. %s\n', group_ids(i), group_names{i});
    end

    % Prompt for group
    group_choice = input('\nSelect a group ID: ');
    if isnan(group_choice) || group_choice < 0
        error('Invalid selection.');
    end

    if group_choice == 0
        group_id = max([group_ids, 0]) + 1;
        group_name = strtrim(input('Enter name for new group: ', 's'));
        group_ids(end+1) = group_id;
        group_names{end+1} = group_name;
        save(mapFile, 'group_ids', 'group_names');
        fprintf('? Added group %d: %s\n', group_id, group_name);
    else
        idx = find(group_ids == group_choice, 1);
        if isempty(idx)
            error('Group ID not found.');
        end
        group_id = group_ids(idx);
        group_name = group_names{idx};
    end

    % Prompt for partition
    partition_id_str = input('Enter partition ID ("1", "2", "3", "4")\nKeep this consistent until otherwise noted: ', 's');
    partition_id = str2double(partition_id_str);
    if isempty(partition_id)
        error('Partition ID cannot be empty.');
    end
    
    fprintf('? Selected group %d (%s), partition %d\n', group_id, group_name, partition_id);
end