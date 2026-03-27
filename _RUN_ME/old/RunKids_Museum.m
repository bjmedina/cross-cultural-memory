%% Restart MATLAB before each session
%% Make sure VolumeLock is ON

%% Singing
addpath(genpath('~/Tsimane2019/Code/MSing/'))
%HarmInharm_Singing_2019_Kids_v3
PureTone4Octaves_Singing_2020_Kids_v3






%%%%
%% Boston Demography
addpath(genpath('~/Tsimane2019/Code/Demography/'))
Run_Demography_Boston_v1
%% Audiometry
system('osascript -e "set Volume 3.5"');
CODE_DIR= '~/Tsimane2019/Code/Audiometry/'; %direcotry of scripts (root)
cd (CODE_DIR)
Audiometry_v5
%% Detection In Noise
%% FUSION STUDY
%% Make sure noise is off, headphones stay plugged into main computer 
CODE_DIR = '~/Tsimane2019/Code/Fusion';
addpath(genpath(CODE_DIR))
Fusion_Expmts_2019_v3






