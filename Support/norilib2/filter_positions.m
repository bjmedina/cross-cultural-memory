function [R,S,W,L,s,r,e]=filter_positions(R,S,W,L,s,r,e,minISI,maxISI,MAXBEATS)
pos=(s>=minISI)&(s<=maxISI);
R=R(pos);
S=S(pos);
W=W(pos);
L=L(pos);
s=s(pos);
r=r(pos);
e=e(pos);
if ~isempty(MAXBEATS)
    if length(s)>MAXBEATS
        pos=1:MAXBEATS;
        R=R(pos);
        S=S(pos);
        W=W(pos);
        L=L(pos);
        s=s(pos);
        r=r(pos);
        e=e(pos);
    end
end