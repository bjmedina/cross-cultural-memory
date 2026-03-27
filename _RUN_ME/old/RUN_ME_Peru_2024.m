%% Restart MATLAB before each singing session, and make sure sound card is plugged in before you start
%% Make sure VolumeLock is ON
%% command shift enter runs a single block of code 

%% ALL RUN: Add support files to path
addpath(genpath('~/Tsimane2024/Code/'))

%% Audiometry
system('osascript -e "set Volume 3.5"');
CODE_DIR= '~/Tsimane2024/Code/Audiometry/'; %direcotry of scripts (root)
cd (CODE_DIR)
Audiometry_2024_v1

% Code For Polaroid: A

%% Demography --> NOT TESTED, NEED TO RE-CODE 
CODE_DIR = '~/Tsimane2024/Code/Demography/';
addpath(CODE_DIR)
Run_Demography_Tsimane_2024_v1
% Code For Polaroid: D

%% High Pitch Preference 
CODE_DIR = '~/Tsimane2024/Code/HighPitch/';
addpath(CODE_DIR)
Wrapper_HighPitchPref_2024_v1
% Code For Polaroid: H
%% Environmental Sounds Only 
CODE_DIR = '~/Tsimane2024/Code/HighPitch/';
addpath(CODE_DIR)
Wrapper_EnvironmentalSounds_2024_v1
% Code For Polaroid: E
%% What Made this Sound
Wrapper_WhatMadeThisSound_2024_v1
% Code For Polaroid: W
%% Detection in noise 
%% OPEN ADDITIONAL INSTANCE OF MATLAB AND RUN THE FOLLOWING CODE IN THE
% SECOND INSTANCE (COPY/PASTE):
addpath(genpath('~/Tsimane2024/'))
CALIBRATION_DIR='~/Tsimane2024/Support/Calibration/boliviaCalibrationFiles2024/calibScripts_July2024/calibration-scripts/'; % Jul 5
CODE_DIR = '~/Tsimane2024/Code/DetectionInNoise';
addpath(CALIBRATION_DIR);
addpath(CODE_DIR);
[pahandle]=StartNoise_v4
%%WAIT TO SEE PSYCHTOOLBOX OUTPUT - NOISE HAS STARTED%%
%% THEN, RUN THE CODE BELOW IN THIS INSTANCE OF MATLAB
CODE_DIR = '~/Tsimane2024/Code/SoundSegregation';
addpath(CODE_DIR);
Detection_HarmInharm_HearingTest_2024_v1
% Code For Polaroid: N
%% STOP NOISE IN SECOND INSANCE OF MATLAB
PsychPortAudio('stop', pahandle);
PsychPortAudio('Close', pahandle);

%% General Consonance Preference Experiment 
CODE_DIR = '~/Tsimane2024/Code/Preference/';
addpath(CODE_DIR)
PreferenceExperiments_2024_v1
% Code For Polaroid: P
%% Tapping 
RUNME_jacoby_mcdermott2018_dec2018Malinda
% Code For Polaroid: %
%% Singing Short Test - Need to still write analysis script 
SING_v1_Peru_2024
% Code For Polaroid: S

%% NOT TO USE - SINGING FOR Malinda in Bolivia 
%% Open additional instance of MATLAB, open the following code and start the
% noise

addpath(genpath('~/Tsimane2024/'))
open Noise_Wrapper_v1

%%
addpath(genpath('~/Tsimane2024/Code/MSing/'))
HarmInharm_Singing_2024_v6




