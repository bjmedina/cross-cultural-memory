%% Present DPs Individually

sr = 48000;
dur = 2;
spl = 70;
ear = 1;
x = {'L','R'};
tf = load(['charlie-sens278-ear' x{ear} '-complex.mat']);

lowfreq = 1200;
% lowfreq = 2400;

lowharm = 3;
% lowharm = 4;
% lowharm = 5;
% lowharm = 6;
% lowharm = 8;
% lowharm = 10;
% lowharm = 12;
% lowharm = 15;

bw = 2;
phaserel = 'sine';

f0 = lowfreq/lowharm;
pb = lowfreq*[1 bw];

stim = synth_harm_note_mono(f0, f0*[lowharm, lowharm*bw], phaserel, dur, sr, spl, tf, 75);
% stim = gnoise_SNH(lowfreq, lowfreq*bw, 0, 75, dur, sr, 'spl', spl, 'tf', tf);

% plot spectrum
% fftplot(stim, sr, 0);

% play sound to appropriate ear
stim_stereo = zeros(2,dur*sr);
stim_stereo(ear,:) = stim;

if any(abs(stim_stereo(:))>1)
    error('Clipping');
end

% open audio device
deviceid = 2;
playbackmode = 1;
latencyclass = 1; % controls how agressive PTB is in ensuring timing precicions
nchannels = 2;
PsychPortAudio('Close');
pahandle = PsychPortAudio('Open',deviceid,playbackmode,latencyclass,sr,nchannels);
PsychPortAudio('FillBuffer',pahandle,stim_stereo);
PsychPortAudio('Start', pahandle);

%% 2-Second Sequence

sr = 48000;
spl = 70;
dur = 2;
ear = 2;
filt_atten = 75;
x = {'L','R'};
tf = load(['charlie-sens278-ear' x{ear} '-complex.mat']);

lowfreqs = [1200 2400];
lowharms = [3 4 5 6 8 10 12 15];
semijitter = -5:5;
bw = 2;
phaserel = 'sine';

fid = fopen(fileplus(['sens278_mainstims_spl' num2str(spl) '_dur' num2str(dur) '_ear' num2str(ear) '_' phaserel '.txt']),'w');

nstims = length(lowfreqs)*length(lowharms)*length(semijitter);
total_smps = sr*dur*nstims;
stim = zeros(total_smps, 1);
index = 0;
for i = 1:length(lowfreqs)
    for j = 1:length(lowharms)
        for k = 1:length(semijitter)
            index = index + 1;
            meanf0 = lowfreqs(i)/lowharms(j);
            f0 = round(2^(semijitter(k)/12)*meanf0);
            stim( (1:dur*sr) + (index-1)*dur*sr )  = synth_harm_note_mono(f0, f0*[lowharms(j),lowharms(j)*bw], phaserel, dur, sr, spl, tf, filt_atten);
            fprintf(fid,'%8d%8d%8d%8d%8d\n', 1+(index-1)*dur*sr, f0, lowfreqs(i), lowharms(j), semijitter(k));
        end
    end
end
fclose(fid);

% 6 minutes and 10 second recording should do the trick

%% Play Sequence

stim_stereo = zeros(2,size(stim,1));
stim_stereo(ear,:) = stim;

if any(abs(stim_stereo(:))>1)
    error('Clipping');
end

% open audio device
deviceid = 2;
playbackmode = 1;
latencyclass = 1; % controls how agressive PTB is in ensuring timing precicions
nchannels = 2;
PsychPortAudio('Close');
pahandle = PsychPortAudio('Open',deviceid,playbackmode,latencyclass,sr,nchannels);
PsychPortAudio('FillBuffer',pahandle,stim_stereo);
PsychPortAudio('Start', pahandle);

%% Analysis

% parameters
spl = 70;
dur = 2;
phaserel = 'sine';
ears = [1 2];
bw = 2;
semis = -5:5;
filt_atten = 75;
min_dp_level = 0; % ignore 'dps' below this threshold
dpthresh = 5;

alldps = [];
alldps_low = [];
alldps_high = [];

watchmovie = true;

for j = 1:2
    
    % read recorded waveform
    [stim sr] = wavread(['sens278_mainstims_spl' num2str(spl) '_dur' num2str(dur) '_ear' num2str(ears(j)) '_' phaserel '.WAV']);
    
    % read corresponding text file
    fid = fopen(['sens278_mainstims_spl' num2str(spl) '_dur' num2str(dur) '_ear' num2str(ears(j)) '_' phaserel '.txt'],'r');
    x = textscan(fid,'%8f%8f%8f%8f%8f');
    [onsets f0s lowfreqs lowharms semijitters] = x{:};
    fclose(fid);
        
    % hand chosen starting index
    if ears(j) == 2  && strcmp(phaserel,'sine')
        start_index = 187100;
    elseif ears(j) == 1 && strcmp(phaserel,'sine')
        start_index = 207400;
    end
    
    % filter based on semitones that will be used in the experiment
    inds = find(ismember(semijitters, semis));
    
    for i = 1:length(inds)
        
        % parameters for this stimulus
        xi = inds(i);
        f0 = f0s(xi);
        ons = onsets(xi);
        lharm = lowharms(xi);
        lfreq = lowfreqs(xi);
        pb = f0*[lharm, lharm*bw];
        
        % select waveform
        wav = stim((1:sr) + ons + start_index - 1);
        
        % predicted primaries
        harms = (1:floor(20000/f0))';
        predicted_primaries = zeros(size(harms));
        
        % low-frequency falloff
        x = f0*harms < pb(1);
        predicted_primaries(x) = filt_atten * log2(f0*harms(x)/pb(1));
        
        % high-frequency falloff
        x = f0*harms > pb(2);
        predicted_primaries(x) = filt_atten * log2(pb(2)./(f0*harms(x)));
        
        % spl normalization
        predicted_primaries = spl + predicted_primaries - 10*log10(sum(10.^(predicted_primaries/10)));
        
        % measured levels
        [px f] = fftplot(10^(142.4/20)*wav, sr, 0, 'noplot');
        x = ismember(f, f0*harms);
        measured_levels = 10*log10(px(x));
        
        % select dps
        x = measured_levels > (predicted_primaries+dpthresh) & measured_levels > min_dp_level;
        stim_dps = [f0*harms(x), measured_levels(x)];
        
        if lfreq == 1200;
            alldps_low = [alldps_low; stim_dps];
        elseif lfreq == 2400
            alldps_high = [alldps_high; stim_dps];
        end
        
        alldps = [alldps; stim_dps];
        
        if watchmovie
            if lfreq == 1200;
                x = [1 3];
            elseif lfreq == 2400;
                x = [2 3];
            end
            for k = x
                subplot(1,3,k);
                hold off;
                semilogx(f0*harms, measured_levels,'bo');
                hold on;
                semilogx(f0*harms, predicted_primaries,'ro');
                
                if k == 1
                    semilogx(alldps_low(:,1), alldps_low(:,2),'ko','LineWidth',2);
                    title('Low-Freq DPs');
                elseif k == 2
                    semilogx(alldps_high(:,1), alldps_high(:,2),'ko','LineWidth',2);
                    title('High-Freq DPs');
                elseif k == 3;
                    semilogx(alldps(:,1), alldps(:,2),'ko','LineWidth',2);
                    title('All DPs');
                end
                
                xlim([50 20000]);
                ylim([0 100]);
                ylabel('Level (dB SPL)');
                xlabel('Frequency (Hz)');
                drawnow;
            end
        end
    end
end

%% DP Boundary

winsize = 0.1;
smoothkern = 10;

for j = 1:3
    
    f = logspace(log10(350),log10(20000),100*log2(20000/350))';
    dp_boundary = zeros(size(f));
    
    if j == 1;
        dps = alldps_low;
    elseif j == 2;
        dps = alldps_high;
    elseif j == 3;
        dps = alldps;
    else
        error('Index too high');
    end
    
    for i = 1:length(f)
        
        % window size
        win = winsize*f(i);
        
        % max DPs over window
        x = dps(:,1) < f(i)+win/2 & dps(:,1) > f(i)-win/2;
        if sum(x) ~= 0
            dp_boundary(i) = max(dps(x,2));
        end
    end
    
    f = f(:);
    px = 10*log10(conv_gauss(10.^(max(dp_boundary,min_dp_level)/10), smoothkern));
    
    if j == 1;
        save(['sens278-dps-low-' num2str(spl) '.mat'],'f','px');
        tstring = 'Low DPs';
    elseif j == 2;
        save(['sens278-dps-high-'  num2str(spl) '.mat'],'f','px');
        tstring = 'High DPs';
    elseif j == 3;
        save(['sens278-dps-' num2str(spl) '.mat'],'f','px');
        tstring = 'All DPs';
    else
        error('Index too high');
    end
    
    subplot(1,3,j);
    semilogx(dps(:,1), dps(:,2),'ko','LineWidth',2);
    hold on;
    semilogx(f,px,'r','LineWidth',2);
    xlim([50 20000]);
    ylim([0 100]);
    xlabel('Frequency (Hz)');
    ylabel('Level (dB)');
    title(tstring);
    
end

%% Combine with measured DPs

for j = 1:3

    if j == 1;
        sysdps = load(['sens278-dps-low-' num2str(spl) '.mat']);
    elseif j == 2;
        sysdps = load(['sens278-dps-high-'  num2str(spl) '.mat']);
    elseif j == 3;
        sysdps = load(['sens278-dps-' num2str(spl) '.mat']);
    else
        error('Index too high');
    end
    
    cochdps = load('cochlear-dps.mat');
    
    f = logspace(log10(80),log10(10000),100*log2(10000/80));
    coch_dps_resamp = myinterp1(log2(cochdps.f), cochdps.px, log2(f), 'cubic');
    sys_dps_resamp = myinterp1(log2(sysdps.f), sysdps.px, log2(f), 'cubic');
    
    px = max(coch_dps_resamp, sys_dps_resamp);
    
    figure(1);
    subplot(1,3,j);
    semilogx(cochdps.f,cochdps.px,'b','LineWidth',4);
    hold on;
    semilogx(sysdps.f,sysdps.px,'k','LineWidth',4);
    semilogx(f,px,'r','LineWidth',1);
    
    xlim([50 20000]);
    ylim([0 100]);
    title(['Cochlear and System DPs at ' num2str(spl) ' dB SPL']);
    xlabel('Frequency (Hz)');
    ylabel('Level (dB)');
    legend('Cochlear', 'Sensimetrics', 'Max')
    
    if j == 1;
        save(['sens278-cochlear-dps-low-' num2str(spl) 'dB.mat'],'f','px');
    elseif j == 2;
        save(['sens278-cochlear-dps-high-' num2str(spl) 'dB.mat'],'f','px');
    elseif j == 3;
        save(['sens278-cochlear-dps-' num2str(spl) 'dB.mat'],'f','px');
    else
        error('Index too high');
    end
    
    px = max(coch_dps_resamp, sys_dps_resamp-5);
    
    figure(2);
    subplot(1,3,j);
    semilogx(cochdps.f,cochdps.px,'b','LineWidth',4);
    hold on;
    semilogx(sysdps.f,sysdps.px-5,'k','LineWidth',4);
    semilogx(f,px,'r','LineWidth',1);
    
    xlim([50 20000]);
    ylim([0 100]);
    title(['Cochlear and System DPs at ' num2str(spl-5) ' dB SPL']);
    xlabel('Frequency (Hz)');
    ylabel('Level (dB)');
    legend('Cochlear', 'Sensimetrics', 'Max')
    
    if j == 1;
        save(['sens278-cochlear-dps-low-' num2str(spl-5) 'dB.mat'],'f','px');
    elseif j == 2;
        save(['sens278-cochlear-dps-high-' num2str(spl-5) 'dB.mat'],'f','px');
    elseif j == 3;
        save(['sens278-cochlear-dps-' num2str(spl-5) 'dB.mat'],'f','px');
    else
        error('Index too high');
    end

end

%% Listen to Stims

sr = 48000;

dp = load(['sens278-cochlear-dps-' num2str(spl) 'dB.mat']);
dp.px = dp.px + 15;
tfL = load('charlie-linus-earL-complex.mat');
tfR = load('charlie-linus-earR-complex.mat');
noiseL = gnoise_SNH(100, 10000, 0, 75, 1, sr, 'specfilt', dp, 'tf', tfL, 'ten');
noiseR = gnoise_SNH(100, 10000, 0, 75, 1, sr, 'specfilt', dp, 'tf', tfR, 'ten');
noise = ramp([noiseL', noiseR'],0.025,sr);

fftplot(noiseL,sr,0);

% open audio device
deviceid = 2;
playbackmode = 1;
latencyclass = 1; % controls how agressive PTB is in ensuring timing precicions
nchannels = 2;
PsychPortAudio('Close');
pahandle = PsychPortAudio('Open',deviceid,playbackmode,latencyclass,sr,nchannels);
PsychPortAudio('FillBuffer',pahandle,noise');
PsychPortAudio('Start', pahandle);


