function [filtered_signal, filter1, F] = Sigmoid_Filter(signal, fs, F0,set_midpoint, dB, No, Type)
% This is a multi-purpose sigmoid filter, primarily designed to remove
% the fundamental and first few resolved harmonics from speech signals. 

% Input signal is 'signal' - If stereo, the signal is made mono before
% being filtered. 

% Midpoint is an integer multiplier of the F0 - where the inflection point
% of the filter should be set. 

% dB - how much attenuation from bottom to top of filter

% No, Number of octaves over which HALF the attenuation occurs - 

%ex. input of 1 No and 80dB will lead to 40 dB of attenuation between peak
%and midpoint over one octave

% Type - 'Low' or 'High'

% Malinda J. McPherson, September, 2016

if nargin <5
    set_k = .001;
end

if nargin<4
    set_midpoint = 2;
end


y = signal;

if size(y, 2)==2; %If stereo, make mono 
lv = ~sum(y == 0, 2);                          % Rows Without Zeros (Logical Vector)
y = sum(y, 2);                              % Sum Across Columns
y(lv) = y(lv)/2;   
else
end
    
%Take the Fourier transform of the signal to convert to frequency domain. 
nft=2^(ceil(log2(length(y)))); 

%Take the Fourier transform of the signal to convert to frequency domain. 
Y = fft(y,nft);
NFFT = length(Y); 

midpoint = log2(F0*set_midpoint);

% Make positive Frequency vector
F1 = log2([1:NFFT/2]*fs/NFFT); % In Hz spacecd /
 % Make positive and negative frequency vector
F = [-flipdim(F1, 2), 0, F1(1:end-1)]; 

%Make the positive filter 

%% Set slope of signal 
if strcmp(Type,'Low')==1
k = -log(10^(dB/40)-1)/No;  % Set in dB/No (number of octaves)
elseif strcmp(Type,'High')==1
k = log(10^(dB/40)-1)/No;  % Set in dB/No (number of octaves)
else
error('Not correct filter type input - must be High or Low')
end


%No is number of octaves over which you want the attenuation

sig = ((1./(1 +exp(-k*(F1 - midpoint))))-1)*dB; %Logistic Function
y1 = 10.^(sig/20); %Put in dB 
%Make full filter
filter1 = [flipdim(y1, 2), 0, y1(1:end-1)];% was end-1

%Apply filter (multiply in frequency domain)
new_signal = fftshift(Y).*filter1';

% ifft to return to temporal domain 
filtered_signalA = (ifft(ifftshift(new_signal)));

filtered_signal = filtered_signalA(1:length(y));
