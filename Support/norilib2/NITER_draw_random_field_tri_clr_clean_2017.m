function NITER_draw_random_field_tri_clr_clean_2017(TOT,TRUNC_TRESH,PT)

% figure(7);clf
% TOT=2000;
% TOT=2000;
% TRUNC_TRESH=TOT*150/1000;
% NN=300

CLICKS=3; %this works only this way
ymax=sqrt(3)/2;
TRIP={[0,0],[1,0],[1/2,ymax]}; %tip points
[rps,NAMES,~,~]=NITER_calc_integer_points(TOT,TRUNC_TRESH);

Irps=rps*PT;

 for l=1:size(Irps,1)
     %for l=1:2
     plot(Irps(l,1),Irps(l,2),'dk','MarkerSize',14,'MarkerFaceColor','w');hold on;
     h=text(Irps(l,1),Irps(l,2)+0.02,NAMES{l},'FontSize',13);
     set(h,'HorizontalAlignment','center','Color','k')
 end

for J=1:length(TRIP)
    J1=J;
    J2=mod(J+1-1,length(TRIP))+1;
    plot([TRIP{J1}(1),TRIP{J2}(1)],[TRIP{J1}(2),TRIP{J2}(2)],'g--');
end
f=TRUNC_TRESH/TOT;
PS={[f,f,1-2*f],[f,1-2*f,f],[1-2*f,f,f]};
for J=1:length(TRIP)
    J1=J;
    J2=mod(J+1-1,length(TRIP))+1;
    plot([TRIP{J1}(1),TRIP{J2}(1)],[TRIP{J1}(2),TRIP{J2}(2)],'g--');
    v1=0;
    for l=1:length(TRIP)
        v1=v1+PS{J1}(l)*TRIP{l};
    end
    v2=0;
    for l=1:length(TRIP)
        v2=v2+PS{J2}(l)*TRIP{l};
    end
    plot([v1(1),v2(1)],[v1(2),v2(2)],'c--');
end


%
%plot([f ,f],[2*f ,1-f],'c--');
%plot([f ,1-f*2],[1-f, 1-f],'c--');
%plot([1-2*f, f],[1-f, 2*f],'c--');


axis([0 1 0 ymax]);

%plot(ws(end,1),ws(end,2),'ob-','LineWidth',2);hold on;drawnow;