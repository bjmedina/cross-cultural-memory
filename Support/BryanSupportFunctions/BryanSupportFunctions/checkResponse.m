% checkResponse()
%
% Prompts for response and makes sure response it is only 0 or 1.
%
% Output(s)
% ========
% response (int): response of the participant
%
% August 1, 2023 -- Bryan Medina (bjmedina@mit.edu)

function response = checkResponse()     

    % flag for valid response
    validResponse = false;

    while ~validResponse
        userInput = input('(Enter 0 for "No/ñoxi" or 1 for "Yes/moye"): ', 's'); 
        
        % if you just press enter
        if isempty(userInput)
            fprintf('No response detected. Please try again.\n');
            
        % if you received a good response
        elseif ismember(userInput, {'0', '1'})
            validResponse = true;
            
        % if you received an invalid response (something that isn't enter,
        % 0 or 1.
        else
            fprintf('Invalid response. Please enter 0/No/ñoxi or 1/Yes/Moye.\n');
        end
        
    end

    response = str2double(userInput); 
