function responseInFreqDomain = zeroPhaseResponse(specSlice)
%   responseInFreqDomain = zeroPhaseResponse(specSlice)

%   zero phase resoponse 
%   codec by Hideki Kawahara
%   27/Mar./2012 

responseInFreqDomain = sqrt([specSlice;specSlice(end-1:-1:2)]);
return;