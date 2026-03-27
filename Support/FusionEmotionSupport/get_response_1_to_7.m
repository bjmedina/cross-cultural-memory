

function [response, repeated, instruction] = get_response_1_to_7(k, total_trials, response_prompt_string, pahandle, OutWav, sr)

%response_prompt_string = '(1= dislike a lot; 2= dislike a little; 3= like a little; 4= like a lot)';
response = input(['Trial #' num2str(k) ' of ' num2str(total_trials) ': ' response_prompt_string '   '],'s');

done = 0;
repeated = 0;

while ~done
    %allow to repeat as many times as needed
    if strcmp(response,'r')
        PsychPortAudio('FillBuffer', pahandle, OutWav);
        t1 = PsychPortAudio('Start', pahandle, 1, 0, 1);
        WaitSecs(size(OutWav,2)/sr);
        response = input(['Now enter response: ' response_prompt_string '   '],'s');
        repeated = repeated + 1;
    elseif ~(strcmp(response,'1') || strcmp(response,'2') || strcmp(response,'3') || strcmp(response,'4') || ...
            (strcmp(response,'5') || strcmp(response,'6') || strcmp(response,'7') || ...
            strcmp(response,'1i') || strcmp(response,'2i') || strcmp(response,'3i') || strcmp(response,'4i')) || ...
            strcmp(response,'5i') || strcmp(response,'6i') || strcmp(response,'7i')) 
        response = input(['Invalid response - must enter 1, 2, 3, 4, 5,6,or 7 or 1i, 2i, 3i, 4i, 5i, 6i, or 7i:   '],'s');
    else
        done = 1;
    end
end
if length(response)==2
    if response(2)=='i';
        instruction=1;
        response = str2num(response(1));
    else
        instruction=0;
    end
else
    instruction=0;
    response = str2num(response);
end
