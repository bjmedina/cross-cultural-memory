function [filtered_sound_with_noise, filtered_sound, filtered_noise_scaled] = filter_stimuli_v1(original, fs, F0, low_harmonic, high_harmonic, set_midpoint_sound, dB_sound, No_sound, Type_sound, set_midpoint_noise, dB_noise, No_noise, Type_noise);
if rem(length(original), 2) == 1
    original = original(1:end-1); 
end


% Filter sound 

[filtered_sound] = Sigmoid_Filter(original, fs, F0,set_midpoint_sound, dB_sound, No_sound, Type_sound);

% Calculate power of sound 
[filtered_flat_sound, filter1, power_signal] = bandpass_filter_calculate_power(original, fs, F0, low_harmonic, high_harmonic);

%Make and filter noise, calculate power
[power_noise, pinknoise_signal, output_auditory_filter] = pinknoise_filter_calc_power(original, fs,F0, set_midpoint_noise, dB_noise, No_noise, Type_noise);

%Scale the entire pinknoise signal - this pink noise can then be added to
%an unflattened (but filtered) sound signal from STRAIGHT. 
filtered_noise_scaled = (pinknoise_signal.*sqrt(power_signal/power_noise)*10^-(4/20))';

filtered_sound_with_noise = filtered_noise_scaled+filtered_sound;
