%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Nori Jacoby's audio library
% Please don't use it without Nori's permision...
% For more information please contact: nori.viola@gmail.com
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [times,myaudio]=STIMfromISIamp(FS,vecISI,amp,clicksound)
ENDSILENCE=.1;

clicksound=clicksound/sqrt(mean(clicksound.^2));
times=cumsum(vecISI);
times=[1,times+1];
amp=[amp(1),amp];
assert(length(amp)==length(times));

N=floor(FS*(max(times)/1000))+1;
mywhere=zeros(N,1);

for I=1:length(times)
    mywhere(floor(FS*(times(I))/1000))=amp(I);
end
myaudio=conv(mywhere,clicksound);
N0=ENDSILENCE*FS;myzeros=zeros(N0,1);
myaudio=[myaudio;myzeros];
end