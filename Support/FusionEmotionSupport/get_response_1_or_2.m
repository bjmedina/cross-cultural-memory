

function [response, repeated, instruction] = get_response_1_or_2(k, total_trials, response_prompt_string, pahandle, OutWav, sr)

%response_prompt_string = '(1 or 2; r to repeat; i after number if instructions repeated)';
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
    elseif ~(strcmp(response,'1') || strcmp(response,'2') || ...
            strcmp(response,'1i') || strcmp(response,'2i'))
        response = input(['Invalid response - must enter 1, 2, 1i, or 2i:   '],'s');
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
