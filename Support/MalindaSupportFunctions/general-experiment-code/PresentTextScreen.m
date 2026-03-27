function onset_time = PresentTextScreen(t, mainwindow, blankscreen, start_time)

% function onset_time = PresentTextScreen(t, mainwindow, blankscreen, start_time)
% 
% Presents text at the center of the screen.
% 
% Last modified by Sam Norman-Haignere on 2015-06-24

Screen('CopyWindow', blankscreen, mainwindow);
Screen('TextSize', mainwindow, 26);
DrawFormattedText(mainwindow, t, 'center', 'center',[],[],[],[],1.5);

if nargin == 4
    onset_time = Screen('Flip',mainwindow, start_time);
else
    onset_time = Screen('Flip',mainwindow);
end