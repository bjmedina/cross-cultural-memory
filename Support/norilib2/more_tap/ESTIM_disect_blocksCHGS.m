function [SS,RS]=ESTIM_disect_blocksCHGS(Sraw,Rraw,myMIN,myPERCENT)

sraw=diff(Sraw);
sraw=[sraw(1),sraw];
SS=cell(1,1);
RS=cell(1,1);
cnt=0;

pos=[0,max(Sraw)];

lasts=sraw(1);
for k=2:length(sraw)
    if abs(sraw(k)-lasts)>lasts*myPERCENT/100
        pos=[pos,Sraw(k)];
        % maybe was here?  lasts=sraw(k); potential bug!!!
    end
    lasts=sraw(k);
end

pos=sort(pos);
for I=2:length(pos)
    mybeg=pos(I-1);
    myend=pos(I);
    S=Sraw( (Sraw<myend) & (Sraw>=mybeg));
    R=Rraw( (Rraw<myend) & (Rraw>=mybeg));
    
   
    if ((length(S)>=myMIN) && (length(R)>=myMIN))
       cnt=cnt+1;
       s=diff(S);s=[s(1),s];
       SS{cnt,1}=S;
       RS{cnt,1}=R;
       
       fprintf('found block %d with %d S onsets (mean %d) and %d R onsets (mean(%d)\n',cnt,length(S),round(mean(diff(S))),length(R),round(mean(diff(R))));
    end 
end
