function [mel_with_noise] = addmaskingnoise( interval, input_sound, starting_f0, sr, centroid);
%mel1 = steps
%mel2 = full melody vector
max_mel = max([0, interval]);


 harm_nums = [1:100];
 jitt_amt = 0;
 jitt = 0;
dist = 1;

dur_s = .4;
% Calibrate Noise
[noise_standard, jitter_matrix_standard] = make_mel_v7(max_mel, starting_f0, harm_nums, jitt_amt,jitt, dur_s, sr,  dist, centroid);

F0 = starting_f0*2^(max_mel/12) ;
[midpoint] = find_loudest_harm(F0, centroid);
low_harmonic = midpoint-1;
high_harmonic = midpoint+1;
set_midpoint_noise = 3;
dB_noise = 80;
No_noise = 1;
Type_noise = 'Low';

[music_with_noise, filtered_noise_scaled_standard] = filter_music_v1(noise_standard, sr, F0, low_harmonic, high_harmonic, set_midpoint_noise, dB_noise, No_noise, Type_noise);
noise_full_standard = repmat(hann(filtered_noise_scaled_standard', 5, sr), 1, 4);
noise_full_standard = noise_full_standard(1:length(input_sound));
mel_with_noise = (input_sound+noise_full_standard');
