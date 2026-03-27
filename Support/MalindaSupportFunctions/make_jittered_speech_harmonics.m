function jitters = make_jittered_speech_harmonics(f0, harm_nums,jitt_amt,intended_midi, actual_midi)
% Function to make jittered harmonics
% Interatively generates harmonics subject to the constraint that they do
% not fall within 30 Hz of each other (to avoid beating.
% Version 2 outputs jitter values, verion 1 outputs frequencies
% Inputs
%f0
%harm_nums - Number of harmonics
%jitt_amt - Jitter amount
freq = zeros(1,length(harm_nums));
for i=2:length(harm_nums);
    jitt_amt_str(1) = 0;
    
    x = rand(1);
    if x>.5;
        sign_jitt = 1;
    elseif x<=.5;
        sign_jitt = -1;
    end
    % Need at add sign loop because can't use randn (must use rand to have a
    % uniform distribution instead of a Gaussian distribution).
    
    if (f0*harm_nums(i)-.5*f0)<(freq(i-1)+30); %Test whether previous harmonic is within range
        jitt_amt1 = (f0*harm_nums(i)-(freq(i-1)+30))/f0; %If so, set Jitter to a lower amount
    else
        jitt_amt1 = jitt_amt; %Otherwise keep the jitter the same
    end
    
    jitt_amt_str = jitt_amt1*rand(1,1);
    
    freq(i) = jitt_amt_str*sign_jitt;
end
jitters = freq;


