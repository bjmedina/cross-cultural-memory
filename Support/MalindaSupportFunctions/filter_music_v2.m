
function [music_with_noise, filtered_noise_scaled] = filter_music_v2(original, fs, F0, low_harmonic, high_harmonic, set_midpoint_noise, dB_noise, No_noise, Type_noise);
if rem(length(original), 2) == 1
    original = original(1:end-1); 
end



% Calculate power of music 
[filtered_flat_music, filter1, power_signal, power_signal_db] = bandpass_filter_calculate_power(original, fs, F0, low_harmonic, high_harmonic);

%Make and filter noise, calculate power
[power_noise, pinknoise_signal, output_auditory_filter] = pinknoise_filter_calc_power(original, fs,F0, set_midpoint_noise, dB_noise, No_noise, Type_noise);


scaled_filtered_noise = output_auditory_filter.*sqrt((power_signal/power_noise))*10^-(24/20);

%Calculate the power in dB - sanity check
power_scaled_filtered_noise = mean(scaled_filtered_noise.^2);
%This dB should be 10 dB less than the power_signal_dB output
power_scaled_filtered_noise_dB = 10*log10(mean(scaled_filtered_noise.^2));

%Scale the entire pinknoise signal - this pink noise can then be added to
%an unflattened (but filtered) music signal from STRAIGHT. 
filtered_noise_scaled = (pinknoise_signal.*sqrt(power_signal/power_noise)*10^-(24/20))';

music_with_noise = filtered_noise_scaled+original';