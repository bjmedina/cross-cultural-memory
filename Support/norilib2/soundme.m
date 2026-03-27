% times in msec a list of all the times that a click should appear
% FS is the frequency sampling rate
% clicksound is the click sound sample
%
%[clicksound,FS]=wavread('click01.wav');
%FS=44100;
%times=100:250:5000
% ENDSILENCE is constant and say the number of seconds of quite in the end

function audiout=soundme(FS,times,clicksound,ENDSILENCE)
if (nargin<=3)||(isempty(ENDSILENCE))
    ENDSILENCE=5;
end
N=floor(FS*(max(times)/1000))+1;
mywhere=zeros(N,1);
mywhere(floor(FS*(times)/1000))=1;
audiout=conv(mywhere,clicksound);
N0=ENDSILENCE*FS;myzeros=zeros(N0,1);audiout=[audiout;myzeros];

end



