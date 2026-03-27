function [myseq,myaudio]=STIMcreateISO(FS,NUMCLICK,T1,clicksound)
    myseq=T1*ones(NUMCLICK,1);
    times=cumsum(myseq);
    myaudio=soundme(FS,times,clicksound);
    %wavwrite(audiout,FS,fname);
end