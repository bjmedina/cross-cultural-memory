function [final_signal] = scale_add_noise_f0(signal, noise, fs, F0,low_harmonic, high_harmonic,scale); 
[power_noise, output_noise] = calc_power_noise(noise, fs, F0); 

[power_signal, output_signal] = calc_power_noise(signal, fs, F0);  

%Take signal, normalize to the power of an individual component and scale
%by the noise, then scale using the SNR - 'Scale'
signal_prime = signal*(power_noise/power_signal)*10^(scale/20);

%sanity check
[power_signal1] = calc_power_noise(signal_prime, fs, F0);  %20*log10(power_signal1) should be 'scale' greater than 20*log10(power_noise)


final_signal = [noise+signal_prime]'; 