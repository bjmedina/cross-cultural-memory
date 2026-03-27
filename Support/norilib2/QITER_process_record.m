function [myfq,tt,fc,rposC]=PITER_process_record(recaudio,fs,ISPLOT,PP)
if isfield(PP,'TH')
    TH=PP.TH;
else
    TH=0.6;
end
if isfield(PP,'CUT_PRE')
    CUT_PRE=PP.CUT_PRE;
else
    CUT_PRE=60/1000;
end
if isfield(PP,'CUT_POST')
    CUT_POST=PP.CUT_POST;
else
    CUT_POST=60/1000;
end
if isfield(PP,'MINon')
    MINon=PP.MINon;
else
    MINon=160/1000;
end
if isfield(PP,'MINoff')
    MINoff=PP.MINoff;
else
    MINoff=160/1000;
end
%fs=16000;
%RECDUR=5000/1000;
x=recaudio;

tt=(1:length(x))/fs;
%nori_doplay2(x,fs);
%FF0t=STRAIGHT_F0(x,tt,fs,ISPLOT);
%v=vadsohn(x,fs,'b');

if ISPLOT
    m='G';
else
    m='';
end
figure(2);
[fx,tx,pv,~]=fxpefac(x,fs,0.001,m);
FF0t = interp1(tx,fx,tt)';
PVt = interp1(tx,pv,tt)';
v=PVt; 
rpos=calc_segments(v,tt,false,TH,MINon,MINoff);

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
    myfq(k)=mean(myseg{k});
end

myaudio=x;

if ISPLOT
    figure(1);clf;
    ax(1)=subplot(2,1,1);
    plot(1000*tt,[x,v]);hold on;
    title('VAD/audio (VAD: PEFAC)');
    ax(2)=subplot(2,1,2);
    plot(1000*tt,FF0t.*(v>TH));hold all;
    plot(1000*tt,FF0t);hold all;
    
    
    plot(tt,v);hold all
    for k=1:size(rpos,1)
        ax(1)=subplot(2,1,1);
        mrng=[rpos(k,1):rpos(k,2)];
        plot(1000*tt(mrng),[x(mrng),v(mrng)]);hold all
        plot(1000*tt(rpos(k,1:2)),[0 0], 'y-','LineWidth',3);
        plot(1000*tt(rpos(k,1)),0 , 'bs','LineWidth',1);
        plot(1000*tt(rpos(k,2)),0 , 'rx','LineWidth',1);
        
        %plot(tt(mrng),v(mrng));hold all
        %plot(tt,[x,v]);
        ax(2)=subplot(2,1,2);
        plot(1000*tt(rpos(k,1:2)),[1 1], 'y-','LineWidth',3);
        plot(1000*tt(rpos(k,1)),1 , 'bs','LineWidth',1);
        plot(1000*tt(rpos(k,2)),1 , 'rx','LineWidth',1);
    end
    
%     ax(1)=subplot(2,1,1);
%     plot(tt,[x,v]);
%     title('VAD/audio (VAD: PEFAC)');
    
    title('pitch (PEFAC pitch tracker)');
    linkaxes(ax,'x');
    
    plot(1000*tt,v);hold all
    for k=1:size(rposC,1)
        plot(1000*tt(rposC(k,1:2)),[1 1], 'r-','LineWidth',2);
        plot(1000*tt(rposC(k,1)),1, 'b.');
        plot(1000*tt(rposC(k,2)),1, 'r.');
    end
end

