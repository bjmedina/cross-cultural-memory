function [SS,RS]=ESTIM_disect_blocksCHG_P(Sraw,Rraw,myMIN,percent)

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
       s=diff(S);s=[s(1),s];
       
       dlast=median(s(end-5:end));
       for kk=0:4
           if s(end-kk)==dlast
               break
           end
       end
       S=S(1:(end-kk));
       R=R(1:(end-kk));
       
       
       %if (s(end)-s(end-1))/median(s)>0.1
         
       %end
       
       SS{cnt,1}=S;
       RS{cnt,1}=R;
       
       
       fprintf('found block %d with %d S onsets and %d R onsets\n',cnt,length(S),length(R));
    end 
end
