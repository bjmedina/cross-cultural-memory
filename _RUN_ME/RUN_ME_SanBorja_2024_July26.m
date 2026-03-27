%% Restart MATLAB before each singing session, and make sure sound card is plugged in before you start
%% Make sure VolumeLock is ON
%% command shift enter runs a single block of code 

%% ALL RUN: Add support files to path
addpath(genpath('~/Tsimane2024/'))

%% Auditory Memory Experiment 
CODE_DIR = '~/Tsimane2024/Code/RecognitionMemory/';
addpath(CODE_DIR)

wrapperRecognitionMemory_v3

%% Visual Memory Experiment (COLOR)
addpath(genpath('~/Tsimane2024/'))
CODE_DIR = '~/Tsimane2024/Code/VisualRecognitionMemory/';
addpath(CODE_DIR)
wrapperRecognitionMemoryVisualBW_v2

%% Demography
CODE_DIR = '~/Tsimane2024/Code0/Demography';
addpath(CODE_DIR)
Run_Demography_SanBorja_v1
%Code for Polaroid: D  





