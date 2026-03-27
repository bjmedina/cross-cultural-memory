function [group_id, group_name] = promptGroup()
% promptGroup  Prompt user to select or add a group using an integer ID
%
% Outputs:
%   group_id    - numeric group ID
%   group_name  - string group name from mapping
%
% Bryan Medina (bjmedina@mit.edu) -- July 17th, 2025

    mapFile = fullfile(fileparts(mfilename('fullpath')), 'group_mapping.mat');

    % Load or initialize group mapping
    if isfile(mapFile)
        S = load(mapFile);
        group_ids = S.group_ids;
        group_names = S.group_names;
    else
        group_ids = [1, 2, 3];
        group_names = {'Tsimané', 'SanBorja', 'Boston'};
    end

    while true
        % Display menu
        fprintf('\nAvailable cultural groups:\n');
        for i = 1:numel(group_ids)
            fprintf('  %d. %s\n', group_ids(i), group_names{i});
        end
        fprintf('  0. Add a new cultural group\n');

        % Prompt for group
        group_choice = input('Select a group ID: ');
        if isempty(group_choice) || ~isnumeric(group_choice) || group_choice < 0
            fprintf('Invalid selection. Please try again.\n');
            continue
        end

        if group_choice == 0
            group_id = max([group_ids, 0]) + 1;
            group_name = strtrim(input('Enter name for new group: ', 's'));
            if isempty(group_name)
                fprintf('Group name cannot be empty.\n');
                continue
            end
            group_ids(end+1)   = group_id;
            group_names{end+1} = group_name;
            save(mapFile, 'group_ids', 'group_names');
            fprintf('Added group %d: %s\n', group_id, group_name);
        else
            idx = find(group_ids == group_choice, 1);
            if isempty(idx)
                fprintf('Group ID not found. Please try again.\n');
                continue
            end
            group_id = group_ids(idx);
            group_name = group_names{idx};
        end

        % Confirm selection
        confirm = lower(strtrim(input(sprintf('You selected group %d (%s). Confirm? (y/n): ', group_id, group_name), 's')));
        if strcmp(confirm, 'y')
            break
        else
            fprintf('Selection canceled. Let?s try again.\n\n');
        end
    end
end