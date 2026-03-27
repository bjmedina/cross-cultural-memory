function [SS,RS]=ESTIM_disect_blocksCHG(Sraw,Rraw,myMIN)

sraw=diff(Sraw);
sraw=[sraw(1),sraw];
SS=cell(1,1);
RS=cell(1,1);
cnt=0;

pos=[0,max(Sraw)];

lasts=sraw(1);
for k=2:length(sraw)
    if abs(sraw(k)-lasts)>10
        pos=[pos,Sraw(k)];
        lasts=sraw(k);
    end
    
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
       
       fprintf('found block %d with %d S onsets and %d R onsets\n',cnt,length(S),length(R));
    end 
end
