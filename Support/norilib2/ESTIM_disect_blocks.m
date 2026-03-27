function [SS,RS]=ESTIM_disect_blocks(Sraw,Rraw,myBREAK,myMIN)

sraw=diff(Sraw);
sraw=[sraw(1),sraw];
SS=cell(1,1);
RS=cell(1,1);
cnt=0;

pos=sort(unique([0,Sraw(sraw>myBREAK),max(Sraw)]));

for I=2:length(pos)
    mybeg=pos(I-1);
    myend=pos(I);
    S=Sraw( (Sraw<=myend) & (Sraw>mybeg));
    R=Rraw( (Rraw<=myend) & (Rraw>mybeg));
    
   
    if ((length(S)>=myMIN) && (length(R)>=myMIN))
       cnt=cnt+1;
       s=diff(S);s=[s(1),s];
       SS{cnt,1}=S(s<myBREAK);
       RS{cnt,1}=R;
       
       fprintf('found block %d with %d S onsets and %d R onsets\n',cnt,length(S),length(R));
    end 
end
