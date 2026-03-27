%% Restart MATLAB before each singing session
%% Make sure VolumeLock is ON
%% command shift enter runs a single block of code 
%% ALL RUN: Add support files to path
addpath(genpath('~/Tsimane2025/'))
%% Auditory Memory Experiment (3 SINGLE ISI EXPERIMENTS)
% NHS, INDUSTRIAL/NATURE, GLOBALIZED MUSIC
% ONLY RUN THIS ON PEOPLE WHO 
CODE_DIR = '~/Tsimane2025/Code/RecognitionMemory/';
addpath(CODE_DIR)

% run demography too (only bryan bc you gotta know spanish)
wrapperRecognitionMemoryNoTextures_ISI16


%% Auditory Memory Experiment (GLOBALIZED MUSIC + multi-isi experiment)
CODE_DIR = '~/Tsimane2025/Code/RecognitionMemory/';
addpath(CODE_DIR)

wrapperRecognitionMemoryGMOnly