function [rt, rkey, flipped] = responseloop(start_time,max_rt,response_codes,varargin)

% [rt, rkey, flipped] = responseloop(start_time,max_rt,responsecodes,varargin)
% 
% Uses KbCheck to look for particular button responses. Looks for responses
% for a given duration of time, determined by the "start_time" and "max_rt"
% input variables. When a response is detected the function immediately
% returns. Otherwise the function returns after the alloted duration.
% 
% -- Required Inputs --
% 
% start_time: system time which all other times are relative to
% 
% max_rt: maximum response time, the duration for which the function
% searches for button responses, after this duration is exceeded the
% function returns.
% 
% response_codes: response code keys to look for (see: help KbCheck, and
% example below)
% 
% -- Outputs --
% 
% rt: time when a button was registered, relative to start_time
% 
% rkey: the key code of the button pressed
% 
% flipped: whether or not a screen was flipped (see below)
% 
% -- Optional arguments --
% 
% deviceNumber: index of the device from which to detect to responses,
% default is -3, which checks all devices (see: help KbCheck). The device
% number is specified in the format: ..., 'deviceNumber', DEVICENUMBER, ...
% 
% flipscreen: allows a screen to be flipped after a specified time,
% format is: ..., 'flipscreen', MAINWINDOW, FLIPTIME, ...
% 
% -- Example: Check if the 1 or 2 key was pressed for 10 seconds --
% 
% response_codes = KbName({'1!', '2@'});
% max_duration = 10;
% fprintf('Type 1 or 2...');
% [rt, rkey] = responseloop(GetSecs,max_duration,response_codes)
% 
% Last modified by Sam Norman-Haignere on 2015-06-24

checkflip = false;
flipped = false;
if optInputs(varargin, 'flipscreen')
    checkflip = true;
    mainwindow = varargin{optInputs(varargin, 'flipscreen')+1};
    fliptime = varargin{optInputs(varargin, 'flipscreen')+2};
end

deviceNumber = -3;
if optInputs(varargin, 'deviceNumber')
    deviceNumber = varargin{optInputs(varargin, 'deviceNumber')+1};
end
    
loopdelay = 0.0005;
testcode = 0;
rt = nan;
rkey = nan;
% FlushEvents('keyDown');
while (GetSecs < start_time+max_rt)
    WaitSecs(loopdelay);
    [zz, secs, keyCode] = KbCheck(deviceNumber); %#ok<ASGLU>
    if sum(keyCode(response_codes)) == testcode
        if testcode == 0;
            testcode = 1;
        else
            rt = secs-start_time;
            rkey = response_codes(logical(keyCode(response_codes)));
            break;
        end
    end
    if checkflip && ~flipped && (GetSecs>fliptime)
        Screen('Flip',mainwindow);
        flipped = true;
    end
end