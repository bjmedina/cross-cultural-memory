%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Nori Jacoby's audio library
% Please don't use it without Nori's permision...
% For more information please contact: nori.viola@gmail.com
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [R,S,W,L,s,r,e]=RawTapstoTaps4(Sraw,Rraw,MAXPROXIMITY)
 
 
jj=1;
 N=length(Sraw);
 S=nan(N,1);
 R=nan(N,1);
 W=nan(N,1);
 L=nan(N,1);
 s=nan(N,1);
 r=nan(N,1);
 e=nan(N,1);
 
 pos=1;
 lastR=0;
 for J=1:length(Sraw)
     [valR,posR]=min(abs(Rraw-Sraw(J)));
     if (abs(valR)<MAXPROXIMITY)
         W(pos)=0;
         S(pos)=Sraw(J);
         R(pos)=Rraw(posR);
         
         if J>1
            s(pos)=Sraw(J)-Sraw(J-1);
         end
         if (pos>1)
             r(pos)=R(pos)-R(pos-1);
         end
         
         e(pos)=R(pos)-S(pos);
         L(pos)=0;
         Rraw(posR)=nan;
     else
        W(pos)=1;
        S(pos)=Sraw(J);
        R(pos)=nan;
        if J>1
            s(pos)=Sraw(J)-Sraw(J-1);
        end
         if (pos>1)
             r(pos)=nan;
             r(1)=nan;
         end
         e(pos)=nan;
         L(pos)=0;
     end
     pos=pos+1;        
         
     end
 end
  
