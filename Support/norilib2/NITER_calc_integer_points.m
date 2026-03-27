function [rps,NAMES,scores,colors]=NITER_calc_integer_points(TOT,TRUNC_TRESH)
NAMES={};
rps=[];
scores=[];
colors=[];
cnt=0;
for ii=1:3
    for jj=1:3
        for kk=1:3
            if (ii==jj) && (jj==kk) && (ii~=1)
                continue
            end
            v0=[ii jj kk];
            v=v0;
            v=TOT*v/sum(v);
            if min(v)>=TRUNC_TRESH
                str=sprintf('%d%d%d',ii,jj,kk);
                cnt=cnt+1;
                rps=[rps;v/sum(v)];
                NAMES{cnt}=str;
                IMA = speye(length(v0));
                sig = -det(IMA(:,v0));
                cmplx=100*sum(v0)+ sum(v0)/min(v0)*10 + max(v0)+0.1*sig;
                scores=[scores,cmplx];
                colors=[colors;0.99-sort(v0)/3 + 0.1*(sig+1)/2];
            end
        end
    end
end
[~,idx]=sort(scores);
sNAMES=cell(size(NAMES));
for l=1:length(NAMES)
    sNAMES{l}=NAMES{idx(l)};
end
NAMES=sNAMES;
rps=rps(idx,:);
colors=colors(idx,:);
colors=(colors-min(colors(:)))/(max(colors(:))-min(colors(:)));
