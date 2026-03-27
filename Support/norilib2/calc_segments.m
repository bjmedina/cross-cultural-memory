function rpos=calc_segments(v,tt,ISPLOT,TH,MINon,MINoff)
% v
% tt
if isempty(ISPLOT)
    ISPLOT=true;
end
if isempty(MINon)
    MINon=300/1000; % minimal time in sec
end
if isempty(MINoff)
    MINoff=10/1000;
end
if isempty(TH)
    TH=0.99;
end

vT=(v>=TH);

pos=[];cnt=0;
lasttime=-999;now_on=false;what_last=-1;
for I=1:length(vT);
    if (vT(I)==1) && (~now_on)
        now_on=true;
        
        if ((tt(I)-lasttime)>MINoff)
            if what_last~=1
                cnt=cnt+1;
            end
            pos(cnt,1)=I;
            pos(cnt,2)=1;
            
            what_last=1;
            
            lasttime=tt(I);
        else
            lasttime=tt(I);
        end
    end
    
    if (vT(I)==0) && (now_on)
        now_on=false;
        
        if ((tt(I)-lasttime)>MINon)
            if what_last~=0
                cnt=cnt+1;
            end
            pos(cnt,1)=I;
            pos(cnt,2)=0;
            
            what_last=0;
            lasttime=tt(I);
        else
            lasttime=tt(I);
        end
    end
    
end
if pos(1,2)==1
    k=1;
else
    k=2;
end

l=floor(size(pos,1)/2)*2;
rpos=[pos(pos(k:l,2)==1,1),pos(pos(k:l,2)==0,1)];

if ISPLOT
    if (~isempty(pos))&&(size(pos,1)>2)
        % figure(1);clf;
        %size(pos)
        %pos
        plot(tt,v);hold all
        for k=1:size(rpos,1)
            plot(tt(rpos(k,1:2)),[1 1], 'y-','LineWidth',2);
        end
        plot(tt(pos(pos(:,2)==1,1)),1,'sb');
        plot(tt(pos(pos(:,2)==0,1)),1,'rx');
    end
end
