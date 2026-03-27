function [S1,S2]=LongAnalyzeCleanSoundsDivideStereoAUDP(myaudio,FS,TRESH,SLEEP,SLEEPMIN,CHUNK,ISPLOT,P)

if (length(size(myaudio))~=2)
    sprintf('This is not a stereo file!');
    assert(size(myaudio,2)==2);
end

if isfield(P,'msg');
    my_msg=P.msg;
else
    my_msg='';
end
if isfield(P,'ispause')
    ispause=P.ispause;
else
    ispause=false;
end

TOT=max(size(myaudio));
LNG=min(TOT,FS*50);
y=myaudio(1:LNG,1:2);

y(:,1)=y(:,1)/max(abs(y(:,1)));
y(:,2)=y(:,2)/max(abs(y(:,2)));


MINBEATS=2;

idx=1;
S1={};
S2={};

Onsets1=[];
Onsets2=[];

mySLEEP=floor(FS*SLEEP/1000)+1;
mySLEEPMIN=floor(FS*SLEEPMIN/1000)+1;

myCHUNK=floor(FS*CHUNK/1000)+1;

FINISHED=false;
pos=1;
assert(myCHUNK>2*max(mySLEEP));
last1=-99999;
last2=-99999;

while (~FINISHED)
    if ispause
        pause
    end
    display(sprintf('%s: sec=%g\tmin= %g',my_msg,pos/FS,pos/FS/60))
    
    myend=min(pos+myCHUNK,TOT);
    
    y=myaudio(pos:myend,1:2);
    y(:,1)=y(:,1)/max(abs(y(:,1)));
    y(:,2)=y(:,2)/max(abs(y(:,2)));
    
    
    
    if (ISPLOT)||(randi(12)==3);
        figure(1);clf;subplot (2,1,1);
        plot((1:size(y,1))'*FS/1000, y(:,1),'m');hold on;
        plot((1:size(y,1))'*FS/1000, ones(size(y(:,1)))*TRESH(1),'g');hold on;
        plot((1:size(y,1))'*FS/1000,-ones(size(y(:,1)))*TRESH(1),'g');hold on;
        subplot(2,1,2);
        plot((1:size(y,1))'*FS/1000, y(:,2),'m');hold on;
        plot((1:size(y,1))'*FS/1000, ones(size(y(:,2)))*TRESH(2),'g');hold on;
        plot((1:size(y,1))'*FS/1000,-ones(size(y(:,2)))*TRESH(2),'g');hold on;
        
    end
    
    if length(y(:,1))<myCHUNK
        FINISHED=true;
    end
    
    for II=1:length(y(:,1)),
        place=pos+II;
        
        if (abs(y(II,2))>TRESH(2))&&(place-last2>mySLEEP(2))
            placet=place*1000/FS;
            if (place-last2>mySLEEPMIN(2))
                Onsets2=[Onsets2,placet]; %#ok<AGROW>
                if (ISPLOT)
                    subplot(2,1,2);plot(II*FS/1000,y(II,2),'or','MarkerFaceColor','b','MarkerSize',10);
                    
                end
            end
            last2=place;
        end
        
        if (abs(y(II,1))>TRESH(1))&&(place-last1>mySLEEP(1))
            placet=place*1000/FS;
            if (place-last1>mySLEEPMIN(1))
                Onsets1=[Onsets1,placet]; %#ok<AGROW>
                if (ISPLOT)
                    subplot(2,1,1);plot(II*FS/1000,y(II,1),'or','MarkerFaceColor','b','MarkerSize',10);
                    
                end
            end
            
            
            
            S1{idx}=Onsets1;  %#ok<AGROW>
            S2{idx}=Onsets2;  %#ok<AGROW>
            
            
            
            last1=place;
        end
        
        
        
    end
    
    
    pos=pos+length(y);
    if (ISPLOT)||(randi(12)==3);
        subplot(2,1,1);
        title(sprintf('%s: sec=%g\tmin= %g',my_msg,pos/FS,pos/FS/60));
        drawnow;
        
        %pause(1)
    end
    
    
end

S1=S1{1};
S2=S2{1};
if ~isempty(S1)&&(length(S1)>1)
    dS1=diff(S1);
    dS1=[dS1(1),dS1];
    S1=S1(dS1>SLEEPMIN(1));
end

if ~isempty(S2)&&(length(S2)>1)
    dS2=diff(S2);
    dS2=[dS2(1),dS2];
    S2=S2(dS2>SLEEPMIN(2));
end


if (ISPLOT||(randi(12)==3))&&(~isempty(S2))&&(~isempty(S1))&&(length(S1)>=2)&&(length(S2)>=2)
    figure(1);clf;
    plot(S1,[S1(2)-S1(1),diff(S1)],'bo-');hold on;
    plot(S2,[S2(2)-S2(1),diff(S2)],'rx-');hold on;
end

end





