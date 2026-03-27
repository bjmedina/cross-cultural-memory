function fixResponses(filename, trials_to_fix)
    load(filename);
    
    for trial=1:length(trials_to_fix)
        curr_response = participantResponses(trials_to_fix(trial));
        participantResponses(trials_to_fix(trial)) = mod(participantResponses(trials_to_fix(trial)) + 1, 2);
        
        fprintf("Past response %d -- new response %d\n\n", curr_response, participantResponses(trials_to_fix(trial)));
    end
    
    isResponseCorrect = (participantResponses == containsRepeat);
    
    fprintf("SAVING %s", filename);
    
    save(filename);
end

