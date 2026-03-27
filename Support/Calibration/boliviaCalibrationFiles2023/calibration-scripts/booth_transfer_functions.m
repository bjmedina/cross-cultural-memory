function tf = booth_transfer_functions(booth_ear_string)

% function booth_transfer_functions(booth_ear_string)
%
% reads in a transfer function corresponding to a particular booth and ear
%
% Sam Norman-Haignere - Updated calibration scripts for booth C to use
% higher levels
%
% Sam Norman-Haignere - Updated 8/4/2015 to return booths C and D to original
% levels
%
% Sam Norman-Haignere - Updated 8/27/2015 increased level of Booth C
%
% Sam Norman-Haignere - Updated 9/7/2015 returned Booth C to normal level
% and increased levels of Booth A and B
%
% Ray Gonzalez raysgon@yahoo.com - Updated 6/6/2017 recalibrated all booths
%
% July 04, 2018 -- Ray Gonzalez raygon@mit.edu; Calibrated computers
% for 2018 Bolivia trip; updated set_level.m and
% booth_transfer_functions.m accordingly.

calibration_directory = strrep(which(mfilename), [mfilename '.m'], '');

switch booth_ear_string
    case 'BLACKLeft'
        tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-BLACK-6-24-24-earL.mat'));
    case 'BLACKRight'
        tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-BLACK-6-24-24-earR.mat'));
    case 'BLACK-SoundcardLeft'
        tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-BLACK-Soundcard-6-25-2024-earL.mat'));
    case 'BLACK-SoundcardRight'
        tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-BLACK-Soundcard-6-25-2024-earR.mat'));
    case 'BLUELeft'
        tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-BLUE-6-25-2024-earL.mat'));
    case 'BLUERight'
        tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-BLUE-6-25-2024-earR.mat'));
 %   case 'BLUE-SoundcardLeft'
  %      tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-BLUE-Soundcard-07-03-18-earL.mat'));
  %  case 'BLUE-SoundcardRight'
  %      tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-BLUE-Soundcard-07-03-18-earR.mat'));
    case 'CYANLeft'
        tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-CYAN-6-24-24-earL.mat'));
    case 'CYANRight'
        tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-CYAN-6-24-24-earR.mat'));
    case 'GREYLeft'
        tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-GREY-6-25-2024-earL.mat'));
    case 'GREYRight'
        tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-GREY-6-25-2024-earR.mat'));
   % case 'GREENLeft'
   %     tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-GREEN-07-02-18-earL.mat'));
   % case 'GREENRight'
  %      tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-GREEN-07-02-18-earR.mat'));
   % case 'GREEN-SoundcardLeft'
   %     tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-GREEN-Soundcard-07-02-18-earL.mat'));
   % case 'GREEN-SoundcardRight'
   %     tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-GREEN-Soundcard-07-02-18-earR.mat'));
    case 'ORANGELeft'
        tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-ORANGE-6-24-24-earL.mat'));
    case 'ORANGERight'
        tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-ORANGE-6-24-24-earR.mat'));
    case 'ORANGE-SoundcardLeft'
        tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-ORANGE-Soundcard-6-25-24-earL.mat'));
    case 'ORANGE-SoundcardRight'
        tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-ORANGE-Soundcard-6-25-24-earR.mat'));
    case 'PURPLELeft'
        tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-PURPLE-6-25-2024-earL.mat'));
    case 'PURPLERight'
        tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-PURPLE-6-25-2024-earR.mat'));
    case 'PURPLE-SoundcardLeft'
        tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-PURPLE-Soundcard-6-25-2024-earL.mat'));
    case 'PURPLE-SoundcardRight'
        tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-PURPLE-Soundcard-6-25-2024-earR.mat'));
    case 'REDLeft'
        tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-RED-6-25-2024-earL.mat'));
    case 'REDRight'
        tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-RED-6-25-2024-earR.mat'));
 %   case 'RED-SoundcardLeft'
 %       tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-RED-Soundcard-06-25-19-earL.mat'));
 %   case 'RED-SoundcardRight'
 %       tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-RED-Soundcard-06-20-19-earR.mat'));
    %case 'YELLOWLeft'
   %     tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-YELLOW-07-03-18-earL.mat'));
   % case 'YELLOWRight'
   %     tf = load(fullfile(calibration_directory, 'tf-mcdermott-bolivia-YELLOW-07-03-18-earR.mat'));
end
