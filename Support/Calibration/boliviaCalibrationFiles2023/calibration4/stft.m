function stft(input_file, device, ear)

input_file = 'mvocs-pitch-80dB';
device = 'scanlaptop-aphex2-channel2-BNCExtension-bevil-stax1-141212';
ear = 'L';

figuredir = [pwd '/stft/'];
if ~exist(figuredir,'dir')
    mkdir(figuredir);
end

sr = 48000;
dwnsmp_factor = 32;

% the passband and attenuation should match that used in
% noise_calibration_sound

hop_smp = 0.01*sr; 
win_smp = 0.03*sr;

tf = load(['tf-' device '-ear' ear '.mat']);

%% inputs
[y_input,wav_sr] = wavread([pwd '/other-recordings/' input_file '-input-ear' ear '.wav']);
y_input = resample(y_input,sr,wav_sr);

[y_measured,wav_sr] = wavread([pwd '/other-recordings/' input_file '-measured-ear' ear '.wav']);
y_measured = resample(y_measured,sr,wav_sr);
% 
% 
% %%
% [B,A] = butter(4,200/(sr/2),'high');
% y_input_hp = filtfilt(B,A,y_input);
% y_measured_hp = filtfilt(B,A,y_measured);
% y_input_downsmp = resample(y_input_hp,2400,sr);
% y_measured_downsmp = resample(y_measured_hp,2400,sr);
% 
% nshifts = length(y_measured_downsmp) - length(y_input_downsmp) + 1;
% crcorr = nan(1,nshifts);
% for i = 1:nshifts
%   crcorr(i) = fastcorr(y_input_downsmp, y_measured_downsmp((1:length(y_input_downsmp)) + (i-1)));
% end
% 
% %%
% [~,xi] = max(crcorr);
% subplot(2,1,1);
% plot(y_input_downsmp);
% subplot(2,1,2);
% plot(y_measured_downsmp((1:length(y_input_downsmp)) + (xi-1)));
% 



%%
nwin = floor((length(y_input)-win_smp) / hop_smp) + 1;
px_expected = nan(721,nwin);
for i = 1:nwin
  [px_expected(:,i), f] = fftplot2(y_input((1:win_smp) + (i-1)*hop_smp),sr,'tf',tf,'noplot');
end

nwin = floor((length(y_measured)-win_smp) / hop_smp) + 1;
px_measured = nan(721,nwin);
for i = 1:nwin
  [px_measured(:,i), f] = fftplot2(y_measured((1:win_smp) + (i-1)*hop_smp)*10^(142.4/20),sr,sr/dwnsmp_factor,'noplot');
end

px_expected_envelope = 10*log10(abs(sum(px_expected(f>200,:))));
px_measured_envelope = 10*log10(abs(sum(px_measured(f>200,:))));

px_expected = 10*log10(abs(px_expected));
px_measured = 10*log10(abs(px_measured));

xi = find(px_expected_envelope > 65,1);
px_expected = px_expected(:,xi:end);
xi = find(px_measured_envelope > 65,1);
px_measured = px_measured(:,(1:size(px_expected,2))+xi-1);



%%

imagesc(px_measured,[0 90]);

% 
% px_expected(px_expected==-inf) = min(px_expected(px_expected~=-inf));
% 
% crscorr = nan(length(f),3795);
% for i = 1:length(f)
%   crscorr(i,:) = xcorr(px_expected(i,:), px_measured(i,:));
% end
% 

%%


nwin_groups = ceil(nwin/100);
for i = 1:nwin_groups
  if i < nwin_groups
    xi = (1:nwin) + (i-1)*nwin_groups;
  end
  imagesc(10*log10(flipud(abs(px(:,)))),[0 90]);
end


nwin = 

%%



%%
[px_raw f_raw] = fftplot((1/sqrt(dwnsmp_factor))*wav*10^(142.4/20),sr,0,'nfft',sr/dwnsmp_factor,'noplot');


figure; clf;

%%
x = f_raw > passband(1) & f_raw < passband(2);
f = f_raw(x);
px = 10*log10(px_raw(x)) - (input_speclevel(j) + spec_atten*log2(passband(1)./f'));

f = f(:);
px = px(:);
save(['tf-' device '-ear' ears{j} '.mat'],'f','px');

cols = {'b','r'};
semilogx(f,px,cols{j});

%%

if j == 1;
  hold on;
end


legend(ears,'Location','NorthWest');
ylim([60 140]);
xlim([min(f) max(f)]);
ylabel('Level (dB SPL)');
xlabel('Frequency');
title(['Transfer Function for ' device]);
saveas(gcf,[figuredir 'tf-' device '-ear' sprintf('%s',ears{:}) '.pdf'],'pdf');
hold off;

% [wav,wav_sr] = wavread([pwd '/other-recordings/mvocs-pitch-80dB-input-earL.wav']);
% wavwrite(wav(:,1),wav_sr,16,[pwd '/other-recordings/mvocs-pitch-80dB-input-earL.wav']);

