%% Restart MATLAB before each singing session
%% Make sure VolumeLock is ON
%% command shift enter runs a single block of code 
%% ALL RUN: Add support files to path
addpath(genpath('~/Tsimane2024/'))
%% Auditory Memory Experiment 
CODE_DIR = '~/Tsimane2024/Code/RecognitionMemory/';
addpath(CODE_DIR)

wrapperRecognitionMemory_v3

%% Visual Memory Experiment (COLOR)
addpatscah(genpath('~/Tsimane2024/'))
CODE_DIR = '~/Tsimane2024/Code/VisualRecognitionMemory/';
addpath(CODE_DIR)
wrapperRecognitionMemoryVisualBW_v2

%% San borja Demography
Run_Demography_Tsimane_2024_vJu1