# McDermott Lab Bolivia 2018 Calibration
========================================
The calibrated `set_level.m` and `booth_transfer_functions.m` (i.e., probably what you want) for _all_ computers are located in:
./boliviaCalibrationFiles2018/calibScripts_July2018/calibration-scripts/
Things should work if you include a copy of this directory on a computer of interest.

## Overview
Calibration for a pair of headphones results in 4 output files:
+ Transfer function for left ear
+ Transfer function for right ear
+ Plot of transfer function for left ear
+ Plot of transfer function for right ear

A summary of all the transfer function plots can be found in:
./boliviaCalibrationFiles2018/extra/transferFunctionSummary.pdf

The complete set of plots is located in:
./boliviaCalibrationFiles2018/extra/figures/

The complete set of transfer functions is located in:
./boliviaCalibrationFiles2018/extra/transferFunctions/

## Naming convention
Transfer functions and plots are named using the following template:
tf-mcdermott-bolivia-{COMPUTER_COLOR}-{MM-DD-YY}-ear{EAR_ID}

Note: All computers, except YELLOW, have a set of transfer functions, and therefore slightly different naming conventions, for:
1) computer + headphone pair
    COMPUTER_COLOR := {BLACK, BLUE, CYAN, GREEN, ORANGE, PURPLE, RED, YELLOW}

    example: tf-mcdermott-bolivia-BLACK-07-03-18-earL.mat

2) computer + soundcard + USB cable + adapter jack + headphone pair
    COMPUTER_COLOR := {BLACK, BLUE, CYAN, GREEN, ORANGE, PURPLE, RED, YELLOW}-Soundcard

    example: tf-mcdermott-bolivia-BLACK-Soundcard-07-02-18-earL.mat

## Setup procedure
To use a specific transfer function:
+ update `calibration-scripts/booth_transfer_functions.m` to use the desired transfer function.
+ update `calibration-scripts/set_level.m` if necessary.

