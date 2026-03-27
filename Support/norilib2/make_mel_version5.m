function [ s, jitter_matrix ] = make_mel_version5(mel, f0, harm_nums, jitt_amt,jitt, dur_s, sr, dist, centroid, JitterString)

% Creates melody with specified jitter, centroid.
% applies the function note_envelope_jitter_vary to each note in an input
% melody
% When jitt = 1, JitterString will be used for every note. 
% Saves an output signal and a vector of jitters for each note 

% Malinda McPherson, November 2015


mel_ratio = 2.^((mel)/12); %Convert melody (in semitones) to Hz. 

% Jitter string for fixed jitter
%JitterString = make_jittered_harmonics2(f0, harm_nums,jitt_amt);

s=[];
jitter_matrix = zeros(length(harm_nums), length(mel));
for j=1:length(mel_ratio);
    f = f0*mel_ratio(j);
    [x, jitter_m] = generate_singlenote_vary_envelope_jitter(f, harm_nums, jitt_amt, jitt, dur_s(j), sr, dist, JitterString, centroid);
    s = [s x];
    jitter_matrix(:,j) = jitter_m;
end


end

