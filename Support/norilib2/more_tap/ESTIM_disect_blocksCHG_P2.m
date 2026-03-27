function [SS,RS]=ESTIM_disect_blocksCHG_P2(Sraw,Rraw,myMIN,percent,TRIM)

sraw=diff(Sraw);
sraw=[sraw(1),sraw];
SS=cell(1,1);
RS=cell(1,1);
cnt=0;

pos=[0,max(Sraw)];

lasts=sraw(1);
for k=2:length(sraw)
    if abs(sraw(k)-lasts)>percent*lasts/100;
        pos=[pos,Sraw(k)];
        %lasts=sraw(k);
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
       
       
       S=S(TRIM(1):(end-TRIM(2)));
       R=R(TRIM(1):(end-TRIM(2)));
       
       
      
       SS{cnt,1}=S;
       RS{cnt,1}=R;
       
       
       fprintf('found block %d with %d S onsets and %d R onsets\n',cnt,length(S),length(R));
    end 
end
