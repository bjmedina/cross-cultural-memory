function computer_id = getComputerID()
% getComputerID  Prompt user to select one of six known computer stations
%
% Output:
%   computer_id - integer from 1 to 6 identifying the selected computer
%
% The following mappings are used:
%   1 = grey
%   2 = mahogany
%   3 = cyan
%   4 = red
%   5 = orange
%   6 = black

    idFile = fullfile(fileparts(mfilename('fullpath')), 'computer_id.mat');
    computer_names = {'grey', 'mahogany', 'cyan', 'red', 'orange', 'black'};
    num_computers = numel(computer_names);

    % Check for saved ID
    if isfile(idFile)
        S = load(idFile);
        if isfield(S, 'computer_id') && ismember(S.computer_id, 1:num_computers)
            saved_id = S.computer_id;
            fprintf('? Using saved computer ID: %d (%s)\n', saved_id, computer_names{saved_id});
            override = lower(strtrim(input('Would you like to change it? (y/n): ', 's')));
            if strcmp(override, 'n')
                computer_id = saved_id;
                return;
            end
        end
    end

    % Prompt until valid and confirmed
    while true
        fprintf('\nWhich computer is this?\nMake sure to keep this consistent.\n');
        for i = 1:num_computers
            fprintf('\t%d. %s\n', i, computer_names{i});
        end

        comp_choice = input('Select computer ID (1?6): ');
        if isempty(comp_choice) || ~isnumeric(comp_choice) || ~ismember(comp_choice, 1:num_computers)
            fprintf('Invalid selection. Try again.\n\n');
            continue;
        end

        confirm = lower(strtrim(input(sprintf('You selected computer %d (%s). Confirm? (y/n): ', ...
            comp_choice, computer_names{comp_choice}), 's')));
        if strcmp(confirm, 'y')
            computer_id = comp_choice;
            save(idFile, 'computer_id');
            fprintf('? Saved computer ID: %d (%s)\n', computer_id, computer_names{computer_id});
            break;
        else
            fprintf('Selection canceled. Let?s try again.\n\n');
        end
    end
end