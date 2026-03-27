function [R,S,W,L,s,r,e]=RawTapstoTaps2(Sraw,Rraw,MAXPROXIMITY,LATENshift)
Rraw=Rraw-LATENshift;
 for kkk=1:length(Sraw),
     if min(abs(Rraw-Sraw(kkk)))<MAXPROXIMITY
         jj=kkk+1;
         break
     end
 end
 
 N=length(jj:length(Sraw));
 S=zeros(N,1);
 R=zeros(N,1);
 W=zeros(N,1);
 L=zeros(N,1);
 s=zeros(N,1);
 r=zeros(N,1);
 e=zeros(N,1);
 
 pos=1;
 for J=jj:length(Sraw)
     [valR,posR]=min(abs(Rraw-Sraw(J)));
     if (abs(valR)<MAXPROXIMITY)
         W(pos)=0;
         S(pos)=Sraw(J);
         R(pos)=Rraw(posR);
         s(pos)=Sraw(J)-Sraw(J-1);
         if (pos>1)
             r(pos)=R(pos)-R(pos-1);
         elseif posR>1
             r(1)=Rraw(posR)-Rraw(posR-1);
         else
             r(1)=s(1);
         end
         e(pos)=R(pos)-S(pos);
         L(pos)=0;
        
     else
        W(pos)=1;
        S(pos)=Sraw(J);
        R(pos)=Sraw(J);
        s(pos)=Sraw(J)-Sraw(J-1);
         if (pos>1)
             r(pos)=R(pos)-R(pos-1);
         elseif posR>1
             r(1)=Rraw(posR)-Rraw(posR-1);
         else
             r(1)=s(1);
         end
         e(pos)=R(pos)-S(pos);
         L(pos)=0;
     end
     pos=pos+1;        
         
     end
 end
  
