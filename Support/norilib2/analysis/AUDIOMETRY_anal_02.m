fres='~/reSearchColumbia/EXPERIMENTS17bolivia/data/sing-jul19/CALIB-19jul17-20-Jul-2017';
cd (fres)

adir=dir('CA*');
X=60:1:11000;   
figure(2);%clf;
vec=[];
for I=1:length(adir)
    fdata=load(adir(I).name);
    fdata.RES.LEVELS
    freqs=fdata.RES.freqs;
    [~,idx]=sort(freqs);
    levels=fdata.RES.LEVELS(idx);
    freqs=fdata.RES.freqs(idx);
    %plot(fdata.RES.freqs,fdata.RES.LEVELS,'o-');hold all
    semilogx(freqs,levels,'o-','LineWidth',3);;hold all
    V=interp1(fdata.RES.freqs,mean(fdata.RES.LEVELS,1),X);
    vec=[vec;V];
end

plot(X,mean(vec),'k','LineWidth',4)
