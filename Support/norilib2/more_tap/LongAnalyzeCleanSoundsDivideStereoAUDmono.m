function [S1,S2]=LongAnalyzeCleanSoundsDivideStereoAUDmono(myaudio,FS,TRESH,SLEEP,SLEEPMIN,CHUNK,ISPLOT)

if (length(size(myaudio))~=2)
    sprintf('This is not a stereo file!');
    assert(size(myaudio,2)==2);
end

TOT=max(size(myaudio));
LNG=min(TOT,FS*50);
y=myaudio(1:LNG,1:2);

y(:,1)=y(:,1)/max(abs(y(:,1)));
y(:,2)=y(:,2)/max(abs(y(:,2)));


DELUTE=1;
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
    %pause
    display(sprintf('sec=%g\tmin= %g',pos/FS,pos/FS/60))
    
    myend=min(pos+myCHUNK,TOT);
    
    y=myaudio(pos:myend,1:2);
    
    y(:,1)=y(:,1)/max(abs(y(:,1)));
    y(:,2)=y(:,2)/max(abs(y(:,2)));
    
    
    if (ISPLOT)||(randi(12)==3);
        figure(1);clf;subplot(2,1,1);
        plot([y(1:DELUTE:end,1), ones(size(y(1:DELUTE:end,1)))*TRESH(1)]);hold on;
        plot([y(1:DELUTE:end,1),-ones(size(y(1:DELUTE:end,1)))*TRESH(1)]);hold on;
        subplot(2,1,2);
        plot([y(1:DELUTE:end,2), ones(size(y(1:DELUTE:end,2)))*TRESH(2)]);hold on;
        plot([y(1:DELUTE:end,2),-ones(size(y(1:DELUTE:end,2)))*TRESH(2)]);hold on;
        
    end
    
    if myend==TOT
        FINISHED=true;
    end
    %     if length(y(:,1))<myCHUNK
    %         FINISHED=true;
    %     end
    %
    for II=1:length(y(:,1)),
        place=pos+II;
        
        if (abs(y(II,2))>TRESH(2))&&(place-last2>mySLEEP(2))
            placet=place*1000/FS;
            if (place-last2>mySLEEPMIN(2))
                Onsets2=[Onsets2,placet]; %#ok<AGROW>
                if (ISPLOT)
                    subplot(2,1,2);plot(II/DELUTE,y(II,2),'oc');
                    
                end
            end
            last2=place;
        end
        
        if (abs(y(II,1))>TRESH(1))&&(place-last1>mySLEEP(1))
            placet=place*1000/FS;
            if (place-last1>mySLEEPMIN(1))
                Onsets1=[Onsets1,placet]; %#ok<AGROW>
                if (ISPLOT)
                    subplot(2,1,1);plot(II/DELUTE,y(II,1),'oc');
                    
                end
            end
            
            
            
            
            last1=place;
        end
        
        S1{idx}=Onsets1;  %#ok<AGROW>
        S2{idx}=Onsets2;  %#ok<AGROW>
        
        
        
    end
    
    
    pos=pos+length(y);
    if (ISPLOT)||(randi(12)==3);
        subplot(2,1,1);
        title(sprintf('sec=%g\tmin= %g',pos/FS,pos/FS/60));
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


% if (ISPLOT||(randi(12)==3))&&(~isempty(S2))&&(~isempty(S1))&&(length(S1)>=2)&&(length(S2)>=2)
%     figure(1);clf;
%     plot(S1,[S1(2)-S1(1),diff(S1)],'bo-');hold on;
%     plot(S2,[S2(2)-S2(1),diff(S2)],'rx-');hold on;
% end

end





