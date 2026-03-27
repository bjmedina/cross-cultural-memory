function noise_calibration_analysis(device, ears, input_speclevel)
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
% noise_calibration_sound
sr = 48000;
spec_atten = 6; 
passband = [20,sr/2];

figure; clf;
for j = 1:length(ears)

    wav = wavread([pwd '/noise-recordings/' device '-ear' ears{j} '.WAV']);
    
    % measure spectrum
    dwnsmp_factor = 32;
    [px_raw f_raw] = fftplot((1/sqrt(dwnsmp_factor))*wav*10^(142.4/20),sr,0,'nfft',sr/dwnsmp_factor,'noplot');
  
    % compared with matlab spectrum
    x = f_raw > passband(1) & f_raw < passband(2);
    f = f_raw(x);
    px = 10*log10(px_raw(x)) - (input_speclevel(j) + spec_atten*log2(passband(1)./f'));
    
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