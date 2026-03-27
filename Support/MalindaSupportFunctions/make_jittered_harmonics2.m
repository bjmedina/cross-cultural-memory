function jitters = make_jittered_harmonics2(f0, harm_nums, jitt_amt)
% Function to make string of jitter values to jitter harmonics
% Interatively generates harmonics subject to the constraint that they do
% not fall within 30 Hz of each other (to avoid beating.)
% Returns jitter values

% Inputs:
% f0
% harm_nums - Number of harmonics, vector
% jitt_amt - Jitter amount, between 0 (harmonic) and 1. Ex. .5 jitter= 50%

% Malinda McPherson, November 2015

freq = zeros(1,length(harm_nums));
for i=2:length(harm_nums);
    jitt_amt_str(1) = 0;
    
    x = rand(1);
    if x>.5;
        sign_jitt = 1;
    elseif x<=.5;
        sign_jitt = -1;
    end
    
    % Need at add sign loop to randomly assign +/- to jitter values 
    
    if (f0*harm_nums(i)-.5*f0)<(freq(i-1)+30); %Test whether previous harmonic is within range
        jitt_amt1 = (f0*harm_nums(i)-(freq(i-1)+30))/f0; %If so, set Jitter to a lower amount
    else
        jitt_amt1 = jitt_amt; %Otherwise keep the jitter the same
    end
    
    jitt_amt_str = jitt_amt1*rand(1,1);
    
    freq(i) = jitt_amt_str*sign_jitt;
end
jitters = freq;


