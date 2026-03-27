function ResetRandStream2(random_seed)
% Resets the random stream with a given seed.
%
% -- Example --
% ResetRandStream2(1); 
% rand
% ResetRandStream2(2); 
% rand
% ResetRandStream2(1);
% rand

% reinitializing random seed
random_stream = RandStream('mt19937ar','Seed', random_seed);
try 
    RandStream.setDefaultStream(random_stream); %#ok<SETRS>
catch
    RandStream.setGlobalStream(random_stream);
end