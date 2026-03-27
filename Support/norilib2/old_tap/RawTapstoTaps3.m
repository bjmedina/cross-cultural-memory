function [R,S,W,L,s,r,e]=RawTapstoTaps3(Sraw,Rraw,MAXPROXIMITY,LATENshift)
 Rraw=Rraw-LATENshift;
 for kkk=1:length(Sraw),
     if min(abs(Rraw-Sraw(kkk)))<MAXPROXIMITY
         jj=kkk+1;
         break
     end
 end
 
jj=2;
 N=length(jj:length(Sraw));
 S=nan(N,1);
 R=nan(N,1);
 W=nan(N,1);
 L=nan(N,1);
 s=nan(N,1);
 r=nan(N,1);
 e=nan(N,1);
 
 pos=1;
 lastR=0;
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
         Rraw(posR)=nan;
        
     else
        W(pos)=1;
        S(pos)=Sraw(J);
        R(pos)=nan;
        s(pos)=Sraw(J)-Sraw(J-1);
         if (pos>1)
             r(pos)=nan;
         elseif posR>1
             r(1)=nan;
         else
             r(1)=nan;
         end
         e(pos)=nan;
         L(pos)=0;
     end
     pos=pos+1;        
         
     end
 end
  
