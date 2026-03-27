function [myseq,myaudio]=STIMcreateBruno(FS,Nbeats,T1,T2,rangeJump,BEG,clicksound)
%rangeJump=[8 12];   
%Nbeats=100;
%BEG= 3;
randseq=randi(rangeJump,Nbeats,1); % randomize much more than needed
myseq=zeros(Nbeats,1);
tos=rand(1,1)>0.5;
T0=T1*tos + T2*(1-tos);
myseq(1:BEG)=T0;
T0=T1*tos + T2*(1-tos);
pos=BEG+1;
for I=1:length(randseq),
    jump=randseq(I);
    if (T0==T1) 
        T0=T2;
    else
        T0=T1;
    end
    topos=min(pos+jump,Nbeats);
    myseq(pos:topos)=T0;
    pos=pos+jump;
    
    if pos>Nbeats
        break;
    end
    
end

    myplaces=cumsum(myseq);myplaces=1+myplaces-myplaces(1);
    myaudio=soundme(FS,myplaces,clicksound);
    plot(myseq,'o-');
    
    %wavwrite(audiout,FS,fname);
end


