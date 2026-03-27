function [myseq,myaudio]=STIMcreateEOS(FS,Nbeats,T0,T1,T2,rangeJump,BEG,clicksound)
% T0=500;T1=520;T2=480;
% rangeJump=[8 12];   
% Nbeats=107;
% BEG= 0;

randseq=randi(rangeJump,Nbeats,1); % randomize much more than needed
myseq=ones(Nbeats,1)*T0;
myseq(1:(BEG))=T0;

pos=BEG;
for I=1:length(randseq),
    jump=randseq(I);
    
    if (mod(I,2)==0) 
        nT=T2;
    else
        nT=T1;
    end
    
    topos=min(pos+jump,Nbeats);
    myseq((pos+1):topos)=T0;
    if (topos<Nbeats-1)
        myseq(topos)=nT;
        myseq(topos+1)=T0-(nT-T0);
    end
    
    pos=pos+jump+1;
    
    if pos>Nbeats
        break;
    end
    
end

     myplaces=cumsum(myseq);myplaces=2+myplaces-myplaces(1);
     myaudio=soundme(FS,myplaces,clicksound);
     plot(myseq,'o-');
     %wavwrite(audiout,FS,fname);
end


