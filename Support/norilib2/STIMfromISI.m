function [times,myaudio]=STIMfromISI(FS,vecISI,clicksound)
    times=cumsum(vecISI);
    times=[1,times+1];
    myaudio=soundme(FS,times,clicksound);
    %wavwrite(audiout,FS,fname);
end