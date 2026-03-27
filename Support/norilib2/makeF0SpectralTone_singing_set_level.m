function [mel] = makeF0SpectralTone_singing_set_level(nNMat, F0, dur, up_down, sr, isi, STATION)
%New version - if N >4, the second note starts at N+2, not N+1
% _singing version adds an inter-note interval of 300ms
x = F0;
t = 0:1/sr:dur;

n = nNMat(1);
N = nNMat(2);
if n<4
    n1 = n;
else
    n1 = n+1;
end



x1 = x/(N+n-1);
x2 = x/(N+n1);


if N ==2
    a = sin(2*pi*x1*n*t)+sin(2*pi*x1*(n+1)*t);
    
    b = sin(2*pi*x2*(n1+1)*t)+sin(2*pi*x2*(n1+2)*t);
elseif N ==3
    
    
    a = sin(2*pi*x1*(n)*t)+sin(2*pi*x1*(n+1)*t)+sin(2*pi*x1*(n+2)*t);
    b = sin(2*pi*x2*(n1+1)*t)+sin(2*pi*x2*(n1+2)*t)+sin(2*pi*x2*(n1+3)*t);
elseif N ==4
    
    
    a = sin(2*pi*x1*(n)*t)+sin(2*pi*x1*(n+1)*t)+sin(2*pi*x1*(n+2)*t)+sin(2*pi*x1*(n+3)*t);
    b = sin(2*pi*x2*(n1+1)*t)+sin(2*pi*x2*(n1+2)*t)+sin(2*pi*x2*(n1+3)*t)+sin(2*pi*x2*(n1+4)*t);
    
    
    
end

c = hann(a, 20, sr);
d = hann(b, 10, sr);
if size(c,2)>size(c,1)
    c=c';
    d=d';
end


c_l=set_level(c, fs, vel, [STATION 'Left']);
c_r=set_level(c, fs, vel, [STATION 'Right']);
c=nan(length(c_l),2);
c(:,1)=c_l;
c(:,2)=c_r;


d_l=set_level(d, fs, vel, [STATION 'Left']);
d_r=set_level(d, fs, vel, [STATION 'Right']);
d=nan(length(d_l),2);
d(:,1)=d_l;
d(:,2)=d_r;



if up_down ==-1
    mel = [c; zeros([(isi-(dur*1000))/1000*sr,1]), d];
elseif up_down ==1
    mel = [d; zeros([(isi-(dur*1000))/1000*sr,1]), c];
end

end
