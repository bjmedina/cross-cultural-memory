function [px f] = fftplot(wav,sr,varargin)

fontsize = 12;
fontweight = 'Demi';

% row vector
if size(wav,1) ~= 1;
    wav = wav';
end

% size of fft
nfft = sr;
if optInputs(varargin, 'nfft')
    nfft = varargin{optInputs(varargin, 'nfft')+1};
end

% misc parameters
binfactor = nfft / sr; % bin = freq * binfactor + 1, freq = (bin - 1) / binfactor
nyq = ceil((nfft+1)/2); % maximum positive frequency, nyquist if nfft is even
bins = 1:nyq;
f = (bins-1)/binfactor;

% divide the input into nonoverlapping bins
if length(wav) > nfft 
    ncols = floor( length(wav)/nfft );
    wav_mat = reshape( wav(1:nfft*ncols), nfft, ncols );
else
    wav_mat = wav(:);
end

% spectrum level collapsed across positive and negative frequencies
px_twoside = mean( abs(fft(wav_mat,nfft)/nfft).^2, 2); % power per Hz per sample
px = [px_twoside(1); 2*px_twoside(2:nyq)];

% compensate for padding
if length(wav) < nfft
    px = px * nfft/length(wav);
end

if optInputs(varargin, 'noplot')
    return;
end

% Plot
semilogx(f(:),10*log10(px), 'r','LineWidth',1);

% X Ticks
set(gca,'XTick',logspace(1,4,4),'FontWeight',fontweight,'FontSize',fontsize);
xlim([20 20000]);
ylim(max(10*log10(px)) + [-70 10]);