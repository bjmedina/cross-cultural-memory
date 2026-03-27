function [ s, jitter_matrix ] = make_mel_v8(mel, f0, harm_nums, jitt_amt,jitt, dur_s, sr, dist, centroid, Jitter_Input_Vector)

% Creates melody with specified jitter, centroid.
% applies the function note_envelope_jitter_vary to each note in an input
% melody
% When jitt = 1, JitterString will be used for every note. 
% Saves an output signal and a vector of jitters for each note 

% Malinda McPherson, November 2015

mel_ratio = 2.^((mel)/12); %Convert melody (in semitones) to Hz. 

if nargin<10
    
    JitterString = make_jittered_harmonics2(f0*min(mel_ratio), harm_nums,jitt_amt);

else
   
    JitterString = Jitter_Input_Vector; 
end

%If dur_s is a single duration to apply to each note, make it a vector the
%same length as mel. 
if length(dur_s)< length(mel); 
    dur_s = repmat(dur_s, 1, length(mel));  
end

% Jitter string for fixed jitter

s=[];
jitter_matrix = zeros(length(harm_nums), length(mel));
for j=1:length(mel_ratio);
    f = f0*mel_ratio(j);
    [x, jitter_m] = generate_singlenote_vary_envelope_jitter_randphase(f, harm_nums, jitt_amt, jitt, dur_s(j), sr, dist, JitterString, centroid);
    s = [s x];
    jitter_matrix(:,j) = jitter_m;
end


end

