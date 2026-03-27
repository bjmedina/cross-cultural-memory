function runDemoExperiments(STATION)
% runDemoExperiments  Run a series of ?demoExperiment_v1? calls with
%                     interactive prompts and optional skipping.
%
%   runDemoExperiments(STATION) will walk through five preset demo
%   sequences.  At each one you?ll be asked to press ENTER to run it,
%   or type 's' + ENTER to skip that demo.
%
%   Input:
%     STATION   ? The station ID passed through to demoExperiment_v1.
%
%   Example:
%     runDemoExperiments(1)

    demos = { ...
        struct('seq',[0,1,1],                      'desc','first (back to back only)'), ...
        struct('seq',[2,2,3,4,4],                  'desc','longer (back to back only)'), ...
        struct('seq',[5,6,7,5,8,9,9],              'desc','longer ? one back-to-back & one non-b2b'), ...
        struct('seq',[10,11,12,10,12,13,14,15,13,16,14], 'desc','even longer (no back to back)'), ...
        struct('seq',[17,18,18,19,20,21,22,23,19,20,24,25,26,27,21,24], 'desc','last (longest ? mimics actual)') ...
    };

    for i = 1:numel(demos)
        D = demos{i};
        prompt = sprintf('\nPress ENTER to run the %s demo, or type ''s'' to skip: ', D.desc);
        ansStr = input(prompt,'s');
        if strcmpi(ansStr,'s')
            fprintf('? Skipping: %s\n', D.desc);
        else
            fprintf('\n? Running: %s\n\n', D.desc);
            demoExperiment_v1(D.seq, 1, STATION);
        end
    end

    fprintf('\nNOTE: If performance was poor and you wish to abort the main experiment, you can Ctrl-C now.\n\n');
end
