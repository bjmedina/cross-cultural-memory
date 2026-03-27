function [fq,midi,start_stop,more]=detect_pitch_nori_yinonly3(recaudio,fs,ISPLOT,vocal_range_midi)

more=[];

% old setup
%
% CUT_PRE=100/1000;  %time ignored at the begning of each segment.
% CUT_POST=100/1000; %time ignored at the end of each segment.
% MINon=200/1000; % minimal time in sec that segment should have.
% MINoff=10/1000; % minimal time in sec between segments.
% TH=0.8; % minimal VAD threshold to consider a segment.
% minf0=60; %minimal freqeuncy for pitch detection.
% maxf0=900; %maximal frequency for pitch detection.

%CUT_PRE=50/1000;  %time ignored at the begning of each segment.
%CUT_POST=50/1000; %time ignored at the end of each segment.
CUT_PRE=100/1000;  %time ignored at the begning of each segment.
CUT_POST=100/1000; %time ignored at the end of each segment.
MINon=50/1000; % minimal time in sec that segment should have.


% MINoff=5/1000; % minimal time in sec between segments.
TH=0.7; % minimal VAD threshold to consider a segment.
minf0=min(midi2freq(vocal_range_midi)); %minimal freqeuncy for pitch detection.
maxf0=max(midi2freq(vocal_range_midi)); %maximal frequency for pitch detection.
%ISPLOT=true; %plot figure for debug

PP.MSEC_SILENCE=25;
PP.MSEC_END_SILENCE=(CUT_PRE+CUT_POST)*1000*1.3;
PP.DB_THRESHOLD=-22; %db threshold
PP.PEAK_PROMINANCE=0.002; %in abs units 0.1 old value
PP.PEAK_TIME_DIF=70; %in ms
THRESHOLD_SEMITONE_TO_CORRECT=6;
THRESHOLD_PERECENT_OF_SEGMENT_GOOD=1/3;

x=recaudio;
if size(x,2)==2
    x=sum(x,2);
end
if size(x,1)==1
    x=x';
end


tt=(1:length(x))/fs;

%[~,tx,pv,~]=fxYIN(x,fs,0.01,'');


PYIN=[];
PYIN.sr=fs;
PYIN.minf0=minf0;
PYIN.maxf0=maxf0;
r=yin(x,PYIN);
FF0t=resample(440*(2.^r.f0),32,1)';

w=ones(round(10/1000*(fs/32)),1);w=w/sum(w);pv_yin=conv(1-r.ap0,w,'same');
pv_yin=resample(pv_yin,32,1)';
v=pv_yin;

if length(v)>length(tt)
    v=v(1:length(tt));
end

if length(v)<length(tt)
    v=[v;nan(length(tt)-length(v),1)];
end


%FF0t = interp1(tx,fx,tt)';
%PVt = interp1(tx,pv,tt)';
%v=PVt;
%rpos=calc_segments(pv_yin,tt,false,TH,MINon,MINoff); %changed that based
%on tresults online
%rpos=calc_segments2(recaudio.*(pv_yin>TH),tt,fs,ISPLOT); %this seems to be more robust

% MSEC_SILENCE=15;
% MSEC_END_SILENCE=120;
% DB_THRESHOLD=-22; %this is the threshold relative to max amp

ISPLOT2=false;
rpos=calc_segments3(recaudio.*(v>TH),tt,fs,ISPLOT2,PP); %this seems to be more robust
%rpos=calc_segments2(recaudio,tt,fs,ISPLOT); %this seems to be more robust


if length(FF0t)>length(v)
    FF0t=FF0t(1:length(v));
else
    temp=zeros(size(v));
    temp(1:length(FF0t))=FF0t;
    FF0t=temp;
end

cpre=round(CUT_PRE*fs);
cpost=round(CUT_POST*fs);
rposC=rpos;

if ~isempty(rpos)
    rposC(:,1)=rpos(:,1)+cpre;
    rposC(:,2)=rpos(:,2)-cpost;
end
msg='';
NSEG=size(rposC,1);
yc=[];fc=[];myseg=cell(NSEG,1);myfq=nan(NSEG,1);
for k=1:NSEG
    yc=[yc;zeros(1000,1);x(rposC(k,1):rposC(k,2))];
    fc=[fc;zeros(1000,1);FF0t((rposC(k,1):rposC(k,2)))];
    myseg{k}=FF0t((rposC(k,1):rposC(k,2)));
    myfq(k)=midi2freq(median(fq2midi(myseg{k})));
    if sum((abs(fq2midi(myseg{k})-fq2midi(median(myseg{k})))>THRESHOLD_SEMITONE_TO_CORRECT))/length(myseg{k})>THRESHOLD_PERECENT_OF_SEGMENT_GOOD
        myfq(k)=nan;
    end
    if (rposC(k,2)/fs-rposC(k,1)/fs)<MINon
        myfq(k)=nan;
    end
    
    if ~isnan(myfq(k))
            msg=sprintf('%s min %2.1f max %2.1f median %2.1f\n',msg,midi2freq(min(fq2midi(myseg{k}))),midi2freq(max(fq2midi(myseg{k}))),midi2freq(median(fq2midi(myseg{k}))));
     end
end
myfq2=nan(NSEG,3);
for k=1:NSEG
    myseg{k}=FF0t((rposC(k,1):rposC(k,2)));
    myfq2(k,:)=[midi2freq(median(fq2midi(myseg{k}))),midi2freq(soft_max(fq2midi(myseg{k}),0.05)), midi2freq(soft_max(fq2midi(myseg{k}),0.95))];
    if sum((abs(fq2midi(myseg{k})-fq2midi(median(myseg{k})))>THRESHOLD_SEMITONE_TO_CORRECT))/length(myseg{k})>THRESHOLD_PERECENT_OF_SEGMENT_GOOD
        myfq2(k,:)=[nan,nan,nan];
    end
    if (rposC(k,2)/fs-rposC(k,1)/fs)<MINon
        myfq2(k,:)=[nan,nan,nan];
    end
end


myaudio=x;

rposC=min(rposC,length(tt));
rpos=min(rpos,length(tt));
if ISPLOT
    clf;
    ax(1)=subplot(2,1,1);
    plot(tt,[x,v]);
    title('VAD/audio (VAD: YIN)');
    ax(2)=subplot(2,1,2);
    
    for k=1:size(rposC,1)
        
        plot(tt(rposC(k,1:2)),[1 1], 'r-','LineWidth',2);
        plot(tt(rposC(k,1)),1, 'b.');
        plot(tt(rposC(k,2)),1, 'r.');
        
    end
    
    plot(tt,fq2midi(FF0t).*(v>TH));hold all;
    plot(tt,fq2midi(FF0t));hold all;
    
    
    plot(tt,v);hold all
    for k=1:size(rpos,1)
        plot(tt(rposC(k,1:2)),[fq2midi(myfq(k)) , fq2midi(myfq(k))], 'm--','LineWidth',2);
        plot(tt(rpos(k,1:2)),[1 1], 'y-','LineWidth',3);
        plot(tt(rpos(k,1)),1 , 'bs','LineWidth',1);
        plot(tt(rpos(k,2)),1 , 'rx','LineWidth',1);
    end
    title('pitch (YIN pitch tracker)');
    title(msg);
    linkaxes(ax,'x');
    
    %plot(tt,v);hold all
    for k=1:size(rposC,1)
        plot(tt(rposC(k,1:2)),[1 1], 'r-','LineWidth',2);
        plot(tt(rposC(k,1)),1, 'b.');
        plot(tt(rposC(k,2)),1, 'r.');
        
    end
end

fq=myfq;
fq2=myfq2;
start_stop=tt(rpos);
midi=fq2midi(fq);

if isempty(start_stop)
    duration=0;
else
    %sorting according to begining
    duration=start_stop(:,1);
    [~,idx]=sort(duration);
    fq=fq(idx);
    fq2=fq2(idx,:);
    start_stop=start_stop(idx,1:2);
    midi=midi(idx);
    
    pos=~isnan(fq);
    fq=fq(pos);
    fq2=fq2(pos,:);
    
    midi=midi(pos);
    start_stop=start_stop(pos,:);
    more.fq2=fq2;
    
    %more.FF0t=FF0t;
    %move.v=v;
end
% for I=1:length(fq)
%     fprintf('note %2d\t\tfq= %4.1f\tmidi=%3.2f\tstart=%3.3f\tstop=%3.3f\n',I,fq(I),midi(I),start_stop(I,1),start_stop(I,2))
% end
