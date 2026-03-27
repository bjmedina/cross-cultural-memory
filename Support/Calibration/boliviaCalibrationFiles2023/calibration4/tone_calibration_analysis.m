function tone_calibration_analysis(device, ears, input_speclevel)
% noise_calibration_analysis(device, ears, input_speclevel)
%
% Companion script to noise_calibration_sound, used to calibrate
% headphones. Measures the sound level of a noise stimulus recorded
% with the Svantek sound meter, and compared the measured level of 
% at each frequency (in dB SPL) with the input level used to create the 
% stimulus in matlab (in unreference dB SPL units, e.g. 10*log10(power))
%
% device is a string, identifying the pair of headphones being calibrated.
% The recorded WAV file should be named: [device '-earL.WAV'] (for the left headphone),
% and placed in the 'noise-recordings' subdirectory
%
% ears is a cell string specifying the headphone (e.g. {'L'} or {'R'})
%
% input_speclevel should be the same as that used for the noise_calibration_sound
%
% Last edited by SNH on 12/13/14

% directory figures are saved to
figuredir = [pwd '/figures/'];
if ~exist(figuredir,'dir')
    mkdir(figuredir);
end

% the passband and attenuation should match that used in
% tone_calibration_sound
sr = 48000;
spec_atten = 3; 
passband = [20,sr/2];

% duration of the tone stimulus
dur = 8;

% frequencies to test
n_freqs = 200;
freqs = round(logspace(log10(passband(1)),log10(passband(2)), n_freqs));
freqs = unique(freqs);
n_freqs = length(freqs);

%%
figure; clf;
for j = 1:length(ears)

    %%
    wav = audioread([pwd '/tone-recordings/' device '-ear' ears{j} '.WAV']);
    
    % raw wave file
    [px_raw, f_raw] = fftplot2(wav((1:dur*sr))*10^(142.4/20),sr,'nfft',sr,'noplot');
   
    % compared with matlab spectrum
    f = freqs';
    px = nan(size(f));
    for i = 1:n_freqs
        x = abs(log2(f_raw/freqs(i)))<0.001;
        px(i) = 10*log10(sum(px_raw(x))) - (input_speclevel(j) + spec_atten*log2(freqs(1)./freqs(i)))';
    end
    %
    %     f = f_raw(xi)';
    %     px = 10*log10(px_raw(xi)); %);
    %
    
    %         figure;
    %         semilogx(f_raw, 10*log10(px_raw)); hold on;
    %         semilogx(f,px,'-ro')
    %         xlim(passband)
        
    % plot
    f = f(:);
    px = px(:);
    save(['tf-' device '-ear' ears{j} '.mat'],'f','px');
    
    cols = {'b','r'};
    semilogx(f,px,cols{j});
    
    if j == 1;
        hold on;
    end
    
end

legend(ears,'Location','NorthWest');
ylim([60 140]);
xlim([min(f) max(f)]);
ylabel('Level (dB SPL)');
xlabel('Frequency');
title(['Transfer Function for ' device]);
saveas(gcf,[figuredir 'tf-' device '-ear' sprintf('%s',ears{:}) '.pdf'],'pdf');
hold off;