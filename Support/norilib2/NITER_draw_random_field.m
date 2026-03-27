function NITER_draw_random_field(NN,TOT,TRUNC_TRESH)
% figure(7);clf
% TOT=2000;
% TOT=2000;
% TRUNC_TRESH=TOT*150/1000;
% NN=300

CLICKS=3; %this works only this way
TRIP={[0,0],[1,1],[0,1]}; %tip points

if isempty(NN)
    NN=300;
end
ws=nan(NN,2);
for ttt=1:NN,
    ISIseed0=NITER_randomize_1threshold_point(CLICKS,TOT,TRUNC_TRESH);
    
    
    assert(sum(ISIseed0>0)==CLICKS);
    assert(abs(sum(ISIseed0)-TOT)<1); ISIseed0=TOT*ISIseed0/sum(ISIseed0);
    
    w=TRIP{1}*ISIseed0(1)/TOT +TRIP{2}*ISIseed0(2)/TOT +TRIP{3}*ISIseed0(3)/TOT;
    ws(ttt,1:2)=w;
end

plot(ws(:,1),ws(:,2),'.k');hold on;

CL='r';FS=20;STG='sr';
for ii=1:3
    for jj=1:3
        for kk=1:3
            if (ii==jj) && (jj==kk) && (ii~=1)
                continue
            end
            v=[ii jj kk];str=sprintf('%d%d%d',ii,jj,kk);
            v=TOT*v/sum(v);
            if min(v)>=TRUNC_TRESH
                w=TRIP{1}*v(1)/TOT +TRIP{2}*v(2)/TOT +TRIP{3}*v(3)/TOT;
                plot(w(1,1),w(1,2),STG,'MarkerSize',FS);hold on;
               
                h=text(w(1,1),w(1,2),str,'Color',CL,'HorizontalAlignment','center','VerticalAlignment','middle');
                 plot(w(1,1),w(1,2),['r','.'])
                
            end
        end
    end
end
plot([0 0],[0 1],'g--');
plot([0 1],[1 1],'g--');
plot([1 0],[1 0],'g--');

f=TRUNC_TRESH/TOT;
plot([f ,f],[2*f ,1-f],'c--');
plot([f ,1-f*2],[1-f, 1-f],'c--');
plot([1-2*f, f],[1-f, 2*f],'c--');

f=TRUNC_TRESH/TOT*0.95;
plot([f ,f],[2*f ,1-f],'m--');
plot([f ,1-f*2],[1-f, 1-f],'m--');
plot([1-2*f, f],[1-f, 2*f],'m--');


axis([0 1 0 1]);

%plot(ws(end,1),ws(end,2),'ob-','LineWidth',2);hold on;drawnow;