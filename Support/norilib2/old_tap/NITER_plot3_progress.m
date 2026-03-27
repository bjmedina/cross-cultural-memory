%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Nori Jacoby's audio library
% Please don't use it without Nori's permision...
% For more information please contact: nori.viola@gmail.com
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function  NITER_plot3_progress(data,KKK,msgN,NN)

subplot(2,2,1);
cnt=0;
for kkk=1:KKK,
    if ~ isempty(data{kkk})
        Rm=data{kkk}.Rm;
                
        TRUNC_TRESH=data{kkk}.TRUNC_TRESH;
        REPEAT=data{kkk}.REPEAT;
        TOT=data{kkk}.TOT;
        CLICKS=length(data{kkk}.SM)-1;
        
        
        plot(data{kkk}.SM,cnt*ones(size(data{kkk}.SM)),'bs');hold on;
        %ylim([0 50]);
        for k=1:length(data{kkk}.SM)
            plot([data{kkk}.SM(k),data{kkk}.SM(k)],[cnt,cnt+data{kkk}.myREP],'b-');
            %plot([data{KKK}.RM(k),data{kkk}.RM(k)],[cnt,cnt+data{kkk}.myREP],'m-');
        end
        
        for J=1:size(Rm,1)
            plot(Rm(J,:),cnt*ones(size(Rm(J,:))),'xr');hold on;
            cnt=cnt+1;
        end
        
    end
    
end
title(msgN);
set(gca,'FontSize',14);
title('Iterated learning for rhythm by Jacoby and McDermott')


subplot(2,2,3);
if CLICKS==3
    
    NITER_draw_random_field(NN,TOT,TRUNC_TRESH);hold on;
    wss=nan(KKK,2);
    wss0=nan(KKK,2);
    w0=nan(1,3);
    for kkk=1:KKK,
        if ~ isempty(data{kkk})
            
            RM=data{kkk}.RM;
            rmm=diff(RM);
            smm=diff(data{1}.SM);
            smm2=diff(data{kkk}.SM);
            w=[0,0]*rmm(1)/TOT +[1,1]*rmm(2)/TOT +[0,1]*rmm(3)/TOT;
            w0=[0,0]*smm(1)/TOT +[1,1]*smm(2)/TOT +[0,1]*smm(3)/TOT;
            w02=[0,0]*smm2(1)/TOT +[1,1]*smm2(2)/TOT +[0,1]*smm2(3)/TOT;
            wss(kkk,1:2)=w;
            wss0(kkk,1:2)=w02;
        end
    end
    plot([w0(1,1);wss(:,1)],[w0(1,2);wss(:,2)],'or-');hold on;%drawnow;
    plot([w0(1,1);wss(:,1)],[w0(1,2);wss(:,2)],'b+');hold on;%drawnow;
    
    plot(w0(1,1),w0(1,2),'ob-','LineWidth',2);hold on;%drawnow;
    %plot(wss0(:,1),wss0(:,2),'b+','LineWidth',1,'MarkerFaceColor','b','MarkerSize',6);hold on;%drawnow;
    plot(wss(end,1),wss(end,2),'sr-','LineWidth',2);hold on;%drawnow;
    
    title(msgN);
    set(gca,'FontSize',14);
    
end

subplot(2,2,4);
temp=[];
for kkk=1:KKK,
    if isempty(data{kkk})
        continue;
    end
    vec=data{kkk}.e;
    vec=vec(~isnan(vec));
    temp=[temp;mean(vec),std(vec)];
end

plot(temp(:,2),'mo-','LineWidth',3);hold on;
plot(temp(:,1),'cs-','LineWidth',2);hold on;
legend('std','mean');
title(msgN);
set(gca,'FontSize',14);
drawnow;

%%%%%%%%%%%%%%%%%%%%%%