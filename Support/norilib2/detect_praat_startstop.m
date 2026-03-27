function praat_start_stop=detect_praat_startstop(recaudio,fs,midi,start_stop,ISPLOT)
DB_THRESHOLD=-25; %this is the threshold relative to max amp
MSEC_SILENCE=40;

if ISPLOT
    figure(1);%subplot(2,1,1);
    %figure(3);clf
    %plot(tt,recaudio);hold all;
    hold all;
end

tt=1000*(1:length(recaudio))/fs;
%figure(1);clf;
praat_start_stop=nan(size(start_stop));
for k=1:length(midi)
    mybeg=round(start_stop(k,1)*fs);
    myend=round(start_stop(k,2)*fs);
    
    [max_amp,idx]=max(abs(recaudio(mybeg:myend)));
    idx=idx+mybeg;
    max_amp_db=20*log10(max_amp);
    amp_thrsh_db=max_amp_db+DB_THRESHOLD;
    amp_thrsh=10.^(amp_thrsh_db/20);
    
    last=idx;
    for I=idx:-1:1,
        if abs(recaudio(I))>amp_thrsh
            last=I;
        end
        if (1000*abs(I-last)/fs)>MSEC_SILENCE
            break
        end
    end
    new_start=last;
    
    
    
    last=idx;
    for I=idx:length(recaudio),
        if abs(recaudio(I))>amp_thrsh
            last=I;
        end
        if (1000*abs(I-last)/fs)>MSEC_SILENCE
            break
        end
    end
    new_end=last;
    praat_start_stop(k,1:2)=[new_start,new_end]/fs;
    if ISPLOT
        plot([mybeg,myend]/fs,[0, 0],'-xr','LineWidth',2);
        plot([idx/fs,idx/fs],[-max_amp*sign(recaudio(idx)),max_amp*sign(recaudio(idx))],'ro-');
        plot([new_start/fs,new_start/fs],[-max_amp*(recaudio(idx)),max_amp*(recaudio(idx))],'md--');
        plot([new_end/fs,new_end/fs],[-max_amp*(recaudio(idx)),max_amp*(recaudio(idx))],'md--');
        
    end
    
end
