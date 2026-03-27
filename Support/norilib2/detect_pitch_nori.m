function [fq,midi,start_stop]=detect_pitch_nori(recaudio,fs,ISPLOT)

addpath(genpath('~/ResearchMIT/CBMM/CMMMproj/PITCH/'))
addpath(' ~/ResearchMIT/CBMM/CMMMproj/PITCH/voicebox/')
addpath('~/ResearchMIT/toolboxes/Sound_Texture_Synthesis_Toolbox/');
addpath('~/ResearchMIT/toolboxes/SYNTH/');
addpath('~/ResearchMIT/toolboxes/create_tap_stim/');
addpath ('~/ResearchMIT/CBMM/CMMMproj/VSQR')


CUT_PRE=100/1000;  %time ignored at the begning of each segment.
CUT_POST=100/1000; %time ignored at the end of each segment.
MINon=200/1000; % minimal time in sec that segment should have.
MINoff=60/1000; % minimal time in sec between segments.
TH=0.6; % minimal VAD threshold to consider a segment.
minf0=60; %minimal freqeuncy for pitch detection.
maxf0=900; %maximal frequency for pitch detection.
%ISPLOT=true; %plot figure for debug

x=recaudio;
if size(x,1)==1
    x=x';
end
    

tt=(1:length(x))/fs;

[fx,tx,pv,~]=fxpefac(x,fs,0.01,'');


PYIN=[];
PYIN.sr=fs;
PYIN.minf0=minf0;
PYIN.maxf0=maxf0;
r=yin(x,PYIN);
FF0t=resample(440*(2.^r.f0),32,1)';
w=ones(round(5/1000*fs),1);w=w/sum(w);conv(1-r.ap0,w);



%FF0t = interp1(tx,fx,tt)';
PVt = interp1(tx,pv,tt)';
v=PVt; 
rpos=calc_segments(v,tt,false,TH,MINon,MINoff);

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
rposC(:,1)=rpos(:,1)+cpre;
rposC(:,2)=rpos(:,2)-cpost;


NSEG=size(rposC,1);
yc=[];fc=[];myseg=cell(NSEG,1);myfq=nan(NSEG,1);
for k=1:NSEG
    yc=[yc;zeros(1000,1);x(rposC(k,1):rposC(k,2))];
    fc=[fc;zeros(1000,1);FF0t((rposC(k,1):rposC(k,2)))];
    myseg{k}=FF0t((rposC(k,1):rposC(k,2)));
    myfq(k)=median(myseg{k});
end

myaudio=x;

if ISPLOT
    clf;
    ax(1)=subplot(2,1,1);
    plot(tt,[x,v]);
    title('VAD/audio (VAD: PEFAC)');
    ax(2)=subplot(2,1,2);
    
    plot(tt,FF0t.*(v>TH));hold all;
    plot(tt,FF0t);hold all;
    
    
    plot(tt,v);hold all
    for k=1:size(rpos,1)
        plot(tt(rpos(k,1:2)),[1 1], 'y-','LineWidth',3);
        plot(tt(rpos(k,1)),1 , 'bs','LineWidth',1);
        plot(tt(rpos(k,2)),1 , 'rx','LineWidth',1);
    end
    title('pitch (PEFAC pitch tracker)');
    linkaxes(ax,'x');
    
    plot(tt,v);hold all
    for k=1:size(rposC,1)
        plot(tt(rposC(k,1:2)),[1 1], 'r-','LineWidth',2);
        plot(tt(rposC(k,1)),1, 'b.');
        plot(tt(rposC(k,2)),1, 'r.');
    end
end

fq=myfq;
start_stop=tt(rpos);
midi=fq2midi(fq);

%sorting according to duration
duration=start_stop(:,2)-start_stop(:,1);
[~,idx]=sort(duration,'descend');
fq=fq(idx);
start_stop=start_stop(idx,1:2);
midi=midi(idx);


% for I=1:length(fq)
%     fprintf('note %2d\t\tfq= %4.1f\tmidi=%3.2f\tstart=%3.3f\tstop=%3.3f\n',I,fq(I),midi(I),start_stop(I,1),start_stop(I,2))
% end
