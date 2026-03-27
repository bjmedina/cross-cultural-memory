function stim_audio=make_repeated_stim(y,fs,reps,PAUSE_BETWEEN_REPETITIONS)

FADEINOUT=50; % in msec

y=sum(y,2);
NUP=round(fs*FADEINOUT/1000);
env=[linspace(0, 1, NUP),linspace(1, 1, length(y)-NUP*2),linspace(1, 0, NUP)]';
y=y.*env;
N_PAUSE=round(1+fs*PAUSE_BETWEEN_REPETITIONS/1000);
o_all=y;
for K=2:reps
    o_all=[o_all;zeros(N_PAUSE,size(y,2));y];
end
stim_audio=o_all;