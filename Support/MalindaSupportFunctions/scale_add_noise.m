function [final_signal,filtered_noise_scaled] = scale_add_noise(signal, noise, fs, F0,low_harmonic, high_harmonic); 
[power_noise] = calc_power_noise(noise, fs, F0);  
[filtered_signal, filter1, power_signal, power_signal_db, F] = calculate_power_harmonics(signal, fs, F0, low_harmonic, high_harmonic);

scaled_filtered_noise = noise.*sqrt((power_signal/power_noise))*10^-(10/20);

%Calculate the power in dB - sanity check
power_scaled_filtered_noise = mean(scaled_filtered_noise.^2);
%This dB should be 10 dB less than the power_signal_dB output
power_scaled_filtered_noise_dB = 10*log10(mean(scaled_filtered_noise.^2));

%Scale the entire pinknoise signal - this pink noise can then be added to
%an unflattened (but filtered) sound signal from STRAIGHT. 
filtered_noise_scaled = (noise.*sqrt(power_signal/power_noise)*10^-(10/20))';

final_signal = signal+filtered_noise_scaled; 