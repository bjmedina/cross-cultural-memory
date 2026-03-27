function [ s, jitter_matrix ] = make_mel_harmsplit_v2(mel, f0, harm_nums, jitt_amt,jitt, dur_s, sr, dist, centroid, SplitHalf, dB_atten,Jitter_Input_Vector)

% Creates melody with specified jitter, centroid.
% applies the function note_envelope_jitter_vary to each note in an input
% melody
% When jitt = 1, JitterString will be used for every note. 
% Saves an output signal and a vector of jitters for each note 

% Malinda McPherson, November 2015


mel_ratio = 2.^((mel)/12); %Convert melody (in semitones) to Hz. 

% Jitter string for fixed jitter
if isempty(Jitter_Input_Vector)  ==1
    JitterString = make_jittered_harmonics2(f0*min(mel_ratio), harm_nums,jitt_amt);
else
    JitterString = Jitter_Input_Vector; 
end

if isempty(SplitHalf) == 1 
    SplitHalf = repmat(harm_nums, length(mel),1)';
end

if isempty(dB_atten) == 1 
    dB_atten = 0; 
end

s=[];
jitter_matrix = zeros(length(harm_nums), length(mel));
if size(SplitHalf,1)>size(SplitHalf,2)
    SplitHalf = SplitHalf';
end

for j=1:length(mel_ratio)
    SplitHalfA =  SplitHalf(j,:);
    SplitHalfA(SplitHalfA==0) = [];
    f = f0*mel_ratio(j);
    if  dist ==1 ||dist ==0
        input_harms = harm_nums; 
    elseif dist ==2 
        input_harms = SplitHalfA;
    end

    [x, jitter_m] = note_vary_env_jitt_HarmSplit_v3(f,input_harms, jitt_amt,jitt, dur_s, sr, dist,JitterString, centroid, SplitHalfA, dB_atten);
    s = [s x];
    %jitter_matrix(1:length(SplitHalfA),j) = jitter_m;
end


end

