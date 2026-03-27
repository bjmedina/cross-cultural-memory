%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Nori Jacoby's audio library
% Please don't use it without Nori's permision...
% For more information please contact: nori.viola@gmail.com
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [S1,S2]=LongAnalyzeCleanSoundsDivideStereoVIEW2(myaudio,FS,TRESH,SLEEP,SLEEPMIN,CHUNK,ISPLOT)

PLOT_SHIFT=-2;
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
    tt=(1:size(y(1:DELUTE:end,:),1))/FS + pos/FS;
    
    if (ISPLOT)
        %figure(202);clf;subplot(2,1,1);
        hold off;
        plot(tt, ones(size(y(1:DELUTE:end,1)))*TRESH(1),'g-');hold on;
        plot(tt,-ones(size(y(1:DELUTE:end,1)))*TRESH(1),'g-');hold on;
        plot(tt,y(1:DELUTE:end,1),'Color','b');hold on;
        
        %subplot(2,1,2);
        plot(tt, ones(size(y(1:DELUTE:end,2)))*TRESH(2) +PLOT_SHIFT,'g-');hold on;
        plot(tt,-ones(size(y(1:DELUTE:end,2)))*TRESH(2) +PLOT_SHIFT,'g-');hold on;
        plot(tt,y(1:DELUTE:end,2)+PLOT_SHIFT,'r');hold on;
        set(gca,'Ytick',[-2,0]);
        set(gca,'YtickLabel',{'Response','Stimulus'})
        set(gca,'FontSize',14);
    end
    
     % THIS HAS BEEN RECENTLY CHANGED
         %     DEC/12/2015
    if myend==TOT
        FINISHED=true;
    end
    %     if length(y(:,1))<myCHUNK  % THIS HAS BEEN RECENTLY CHANGED
    %     DEC/12/2015
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
                    plot(tt(II),PLOT_SHIFT+y(II,2),'ok','MarkerFaceColor','y');
                    
                end
            end
            last2=place;
        end
        
        if (abs(y(II,1))>TRESH(1))&&(place-last1>mySLEEP(1))
            placet=place*1000/FS;
            if (place-last1>mySLEEPMIN(1))
                Onsets1=[Onsets1,placet]; %#ok<AGROW>
                if (ISPLOT)
                    plot(tt(II),y(II,1),'ok','MarkerFaceColor','y');
                    
                end
            end
            
            
            
            
            last1=place;
            % THIS HAS BEEN RECENTLY CHANGED:DEC/12/2015 (moved outside of the if of stimulus)
            %S1{idx}=Onsets1;  %#ok<AGROW>  
            %S2{idx}=Onsets2;  %#ok<AGROW>
        
        end % 
        
         % THIS HAS BEEN RECENTLY CHANGED:DEC/12/2015 (moved outside of the if of stimulus)
        S1{idx}=Onsets1;  %#ok<AGROW>  
        S2{idx}=Onsets2;  %#ok<AGROW>
        
        
        
    end
    
    
    pos=pos+length(y);
    if (ISPLOT)
        
        title(sprintf('sec=%g\tmin= %g',pos/FS,pos/FS/60));
        pause
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


end





