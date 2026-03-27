function [filtered_signal, filter1, F] = trapezoidFilter_v3(input_wav_signal, fs, F0, low, gradient, high, plot_figs)
% This function is intended to take an input wav signal that has been
% flattened using STRAIGHT and then filtered using a sigmoid filter (the function Filter_F0_Speech_dB). 
% This function then filters the speech again using a rectangular filter from 4.5*f0 to 8.5*F0, then
% calculates the mean power of the signal (divided by 4, to get average
% power of a signle harmonic). 

% Function returns the filtered signal, the filter, the power of the
% signal, the dB of the signal, and a frequency vector F that can be used
% for plotting. 
%%Malinda McPherson, 2017
y = input_wav_signal;
nft=2^(ceil(log2(length(y)))); 
%Take the Fourier transform of the signal to convert to frequency domain. 
Y = fft(y, nft);
NFFT = length(Y); 

%Sets midpoint to 4th harmonic, scales to signal. 

% Make positive Frequency vector - in Hz space, not bin space
F1 = [1:NFFT/2]*(fs/NFFT);
 % Make positive and negative frequency vector
F = [-flipdim(F1, 2), 0, F1(1:end-1)]; 
%%

%low = 300; 
%gradient = 200; 
%high =  800;  

%Make the positive filter --> Zeros until F0*4.5, ones from F0*4.5:F0*8.5, zeros from F0*8.5:end 
%y1 = [zeros([1,round(F0*(set_midpoint+.5)*(NFFT/fs))]),ones([1,round((F0*(set_midpoint+8.5))*(NFFT/fs))-round((F0*(set_midpoint+.5))*(NFFT/fs))+1]),...
 %   zeros([1,(NFFT/2)-round((F0*(set_midpoint+8.5))*(NFFT/fs)+1)])];

low = round(low*NFFT/fs); %Set low filter cutoff
high = round(high*NFFT/fs);  % Set high filter cutoff 
gradientLow = round(F0*gradient*NFFT/fs);
gradientHigh = round(F0*gradient*NFFT/fs);
dB = 30;
%y1 = [zeros([1,low]), logspace(1/gradientLow, 1, length([1/gradientLow:1/gradientLow:1]))./10 , ones([1,high-low-length([1/gradientLow:1/gradientLow:1])]), fliplr(logspace(1/gradientHigh, 1, length([1/gradientHigh:1/gradientHigh:1]))./10), zeros([1,length(F1)-high-length([1/gradientHigh:1/gradientHigh:1])])]*dB-dB;
y1 = [ones([1,high]), fliplr([1/gradientHigh:1/gradientHigh:1]), zeros([1,length(F1)-high-length(fliplr([1/gradientHigh:1/gradientHigh:1]))])]*dB-dB;
%plot(y1)
y1 = 10.^(y1/20); %Put in dB 

 
%Make full filter
filter1 = [flipdim(y1, 2), 1, y1(1:end-1)];

%Apply filter (multiply in frequency domain)
if size(fftshift(Y),2)>1
    Y = Y';
end
new_signal = fftshift(Y).*filter1';

% ifft to return to temporal domain 
filtered_signalA = (ifft(ifftshift(new_signal)));
filtered_signal = filtered_signalA(1:length(y));

if plot_figs == 1; 
figure
[D,F] = gammatonegram(filtered_signal,fs);

plot([1:64], 10*log(mean(D')), 'b')
figure
pwelch(filtered_signal, [], [], [], fs)
else 
end
%power_signal = (mean(filtered_signal.^2))/(high_harmonic-(low_harmonic-1)); %Divide signal by number of harmonics it contains
%Sanity Check 
%%
%power_signal_db = 10*log10(power_signal);


