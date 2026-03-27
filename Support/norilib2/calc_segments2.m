function rpos=calc_segments2(recaudio,tt,fs,ISPLOT)
if isempty(ISPLOT)
    ISPLOT=true;
end

MSEC_SILENCE=15;
MSEC_END_SILENCE=120;
DB_THRESHOLD=-22; %this is the threshold relative to max amp

a1=(recaudio.^2);

jmp=round(10/1000*fs);
for I=1:jmp:length(tt)
    pos=I:min(I+jmp,length(tt));
    vec=a1(pos);
    a2(pos)=max(vec);
end

[pk,loc]=findpeaks(a2,'MinPeakDistance',70/1000*fs,'MinPeakProminence',0.01);

loc=[1,loc];
pk=[0,pk];


plc_start=[];


for l=2:length(loc),
    
    
    max_amp=a2(loc(l));
    idx=loc(l);
    max_amp_db=20*log10(max_amp);
    amp_thrsh_db=max_amp_db+DB_THRESHOLD;
    amp_thrsh=10.^(amp_thrsh_db/20);
    
    
    last=idx;
    is_found=false;
    for I=idx:-1:loc(l-1),
        if abs(a2(I))>amp_thrsh
            last=I;
        end
        if (1000*abs(I-last)/fs)>MSEC_SILENCE
            is_found=true;
            break
        end
    end
    if (last==idx)
        new_start=I;
    else
        new_start=last;
    end
    %new_start=I;
    if is_found
        plc_start=[plc_start;new_start];
    end
    
end

plc_end=[];
for l=1:length(plc_start),
    amp_thrsh=a2(plc_start(l));
    amp_thrsh=0.003;
    idx=plc_start(l);
    last=idx;
    for I=idx:length(recaudio),
        if abs(a2(I))>amp_thrsh
            last=I;
        end
        if ((1000*abs(I-last)/fs)>MSEC_SILENCE) && ( 1000*(I-plc_start(l))/fs > MSEC_END_SILENCE)
            break
        end
    end
    new_end=I;
    plc_end=[plc_end;new_end];
end

%filter overlaps
pos=ones(size(plc_start));
for I=1:length(pos)
    for J=1:length(pos)
        if I==J
            continue
        end
        if (plc_start(I)>plc_start(J)) && (plc_start(I)<plc_end(J))
           pos(I)=0; 
        end
    end
end

rpos=[plc_start(pos==1),plc_end(pos==1)];
if ISPLOT
    %figure(1);clf;
    plot(tt,a2);hold on;
    plot(tt(loc),a2(loc),'db');
    plot(tt(plc_end),a2(plc_end),'sm');hold on;
    plot(tt(plc_start),a2(plc_start),'rx');hold on;

    % figure(1);clf;
    %size(pos)
    %pos
    plot(tt,a2);hold all
    for k=1:size(rpos,1)
        plot(tt(rpos(k,1:2)),[0 0], 'y-','LineWidth',2);
    end
    
    if ~isempty(rpos)
        plot(tt(rpos(:,1)),0,'sb');
        plot(tt(rpos(:,2)),0,'rx');
    end
end
