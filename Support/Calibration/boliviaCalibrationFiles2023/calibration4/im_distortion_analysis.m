function im_distortion_analysis(device, ears, watchmovie)
% im_distortion_analysis(device, ears, watchmovie)
% 
% Companion script to im_distortion_sound, used to measure
% the distortion characteristics of headphones.
%
% Device is a string specifying the headphone.
% The transfer function of the headphone needs to have
% already been measured with the noise_calibration scripts.
%
% Ear is a string ('L' or 'R') specifying whether the left or
% right headphone is being used.
%
% watchmovie is a flag that when set to true will cause
% a series of figures to be plotted, illustrating the 
% distortion measurements
%
% Last edited by Sam Norman-Haignere on 12/13/14

% parameters used for distortion-product measurements
min_dp_level = 0; 
dpthresh = 5;

% directory figures are saved to
figuredir = [pwd '/distortion-figures/' device '/'];
if ~exist(figuredir,'dir')
    mkdir(figuredir);
end

alldps = cell(1,length(ears));
for i = 1:length(ears)
    
    % reads in parameters used to present sounds
    p = im_distortion_sound(device, ears{i}, 'nosound');
    
    % read in recorded waveform
    [stim, sr] = wavread([pwd '/distortion-recordings/' device '-ear' ears{i} '.WAV']);
    
    % detect the onset of the first sound
    [B,A] = butter(6,60/(p.sr/2),'high');
    stim_filt = filtfilt(B,A,stim);
    trigger = find(stim_filt > 4e-4 & (1:length(stim_filt))' > 1*sr, 1) + 0.05*sr;
    
    nstims = length(p.f0_order);
    onsets = round(trigger + (0:nstims-1)*p.dur*p.sr);
    % loop through each sound
    for j = 1:nstims
        
        f0 = p.f0_order(j);
        ons = onsets(j);
        lharm = p.lowharms_order(j);
        prel = p.phaserel_order{j};
        spl = p.spl_order(j);
        pb = f0*[lharm, lharm*p.bw];
                
        % expected levels for each harmonic
        [~,f_primaries,predicted_primaries_tmp] = synth_harm_note_mono( f0, pb, prel, p.dur, p.sr, spl, [], p.filt_atten, 'nonote' );
        if isinf(p.filt_atten);
            fharms = f0*(1:floor(20000/f0))';
            predicted_primaries = -300*ones(size(fharms));
            predicted_primaries(ismember(fharms, f_primaries(:))) = predicted_primaries_tmp;
        else
            fharms = f_primaries(:);
            predicted_primaries = predicted_primaries(:);
        end
        
        % select waveform
        wav = stim((1:sr) + ons);
        
        % measure spectrum and plot
        figure(1); clf(1);
        [px f] = fftplot(10^(142.4/20)*wav, sr);
        
        ylim([0 100]);
        xlim([50 20000]);
        ylabel('Level (dB SPL)');
        xlabel('Frequency');
        
        tstring = sprintf(['IM Distortion ' device ' ear' ears{i} '\n%d - %d Hz, Harms %d - %d, %d SPL, Phase: %s'], pb(1), pb(2), lharm, lharm*p.bw, spl, prel);
        title(tstring);
        
        fname = sprintf(['im_distortion_' device '-ear' ears{i} '_freq%d-%d_harms%d-%d_spl%d_%s'], pb(1), pb(2), lharm, lharm*p.bw, spl, prel);
        saveas(gcf,[figuredir fname '.pdf'],'pdf');

        % calculate dps
        x = ismember(f, fharms);
        measured_levels = 10*log10(px(x));
        
        % select dps
        x = measured_levels > (predicted_primaries+dpthresh) & measured_levels > min_dp_level;
        dps = [fharms(x), measured_levels(x)];
        
        alldps{i} = [alldps{i}; dps];
        
        if watchmovie
            
            figure(2);
            
            % measured and predicted primaries
            subplot(1,length(ears),i);
            hold off;
            semilogx(fharms, measured_levels,'bo');
            hold on;
            semilogx(fharms, predicted_primaries,'ro');
            
            % dps
            if ~isempty(alldps{i})
                semilogx(alldps{i}(:,1), alldps{i}(:,2),'ko','LineWidth',2);
            end
            
            xlim([50 20000]);
            ylim([0 100]);
            ylabel('Level (dB SPL)');
            xlabel('Frequency (Hz)');
            title(['IM Distortion ' device ' ear' ears{i}]);
        end
    end
end

%% DP Boundary

frange = [100 20000];
winsize = 0.2;
smoothkern = 10;

for i = 1:length(ears)
    
    f = logspace(log10(frange(1)),log10(frange(2)),100*log2(frange(2)/frange(1)))';
    dp_boundary = zeros(size(f));
    dps = alldps{i};
    
    for j = 1:length(f)
        
        % window size
        win = f(j) * [1/sqrt(1+winsize), sqrt(1+winsize)];
        
        % max DPs over window
        x = dps(:,1) > win(1) & dps(:,1) < win(2);
        if any(x)
            dp_boundary(j) = max(dps(x,2));
        end
    end
    
    f = f(:);
    px = 10*log10(conv_gauss(10.^(max(dp_boundary,min_dp_level)/10), smoothkern));
    
    save(['im_distortion_' device '-ear' ears{i} '_dpboundary.mat'],'f','px');
    figure(3);
    subplot(1,length(ears),i);
    semilogx(dps(:,1), dps(:,2),'ko','LineWidth',2);
    hold on;
    semilogx(f,px,'r','LineWidth',2);
    xlim([50 20000]);
    ylim([0 100]);
    xlabel('Frequency (Hz)');
    ylabel('Level (dB)');
    title(['IM DP Boundary, ' device ', ear' ears{i}]);
    hold off;
    
end

saveas(gcf,[figuredir 'im_dp_boundary_' device '-ear' sprintf('%s',ears{:}) '.pdf'],'pdf');


