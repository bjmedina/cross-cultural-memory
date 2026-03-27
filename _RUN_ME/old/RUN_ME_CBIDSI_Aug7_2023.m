%% Restart MATLAB before each singing session
%% Make sure VolumeLock is ON
%% command shift enter runs a single block of code 
%% ALL RUN: Add support files to path
addpath(genpath('~/Tsimane2023/'))

%% High Pitch Preference 
CODE_DIR = '~/Tsimane2023/Code/HighPitch/';
addpath(CODE_DIR)
Wrapper_HighPitccchPref_2023_SanBorja_v1

%% EDUARDO 
%% Demography 
CODE_DIR = '~/Tsimane2023/Code/Demography/';
addpath(CODE_DIR)
Run_Demography_Tsimane_2023_v5
%% Audiometry
system('osascript -e "set Volume 3.5"');
CODE_DIR= '~/Tsimane2023/Code/Audiometry/'; %direcotry of scripts (root)
cd (CODE_DIR)
Audiometry_2023_v5



%% What Made this Sound
Wrapper_WhatMadeThisSound_v2












%% NOT TO USE TODAY Singing 
%% Open additional instance of MATLAB, open the following code and start the
% noise
addpath(genpath('~/Tsimane2023/'))
open Noise_Wrapper_v1

%%
addpath(genpath('~/Tsimane2023/Code/MSing/'))
HarmInharm_Singing_2023_v6
%% Detection in noise 
%% OPEN ADDITIONAL INSTANCE OF MATLAB AND RUN THE FOLLOWING CODE IN THE
% SECOND INSTANCE (COPY/PASTE):
addpath(genpath('~/Tsimane2023/'))
CALIBRATION_DIR='~/Tsimane2023/Support/Calibration/boliviaCalibrationFiles2023/calibScripts_July2023/calibration-scripts/'; % Jul 5
CODE_DIR = '~/Tsimane2023/Code/DetectionInNoise';
addpath(CALIBRATION_DIR);
addpath(CODE_DIR);
[pahandle]=StartNoise_v3 
%%WAIT TO SEE PSYCHTOOLBOX OUTPUT - NOISE HAS STARTED%%
%% THEN, RUN THE CODE BELOW IN THIS INSTANCE OF MATLAB
CODE_DIR = '~/Tsimane2023/Code/SoundSegregation';
addpath(CODE_DIR);
Detection_HarmInharm_HearingTest_2023_v2

%% STOP NOISE IN SECOND INSANCE OF MATLAB
PsychPortAudio('stop', pahandle);
PsychPortAudio('Close', pahandle);




%% Melody Contour Experiment
% same instructions as memory experiment, but repetitions are always back
% to back 
CODE_DIR = '~/Tsimane2023/';
addpath(genpath(CODE_DIR))
WrapperPitchSequence_2023_v4
