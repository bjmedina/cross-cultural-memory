%%% return the element that is p positioned within the vector vec (1.0 is
%%% max) 0.0 is min
function v=soft_max(vec,p)
if isempty(vec)
    v=nan;
else
    svec=sort(vec);
    pos=floor(p*length(vec));
    pos=max(pos,1);
    pos=min(pos,length(svec));
    v=svec(pos);
end
    