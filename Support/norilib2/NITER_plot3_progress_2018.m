function  NITER_plot3_progress_2018(ALL,KKK,J,msgN)
data=ALL{J}.data;
NN=0;

%figure(10);clf;
subplot(2,2,1);
cnt=0;
for kkk=1:KKK
    if ~ isempty(data{kkk})
        Rm=data{kkk}.Rm;
       
        
        TRUNC_TRESH=data{kkk}.TRUNC_TRESH;
        REPEAT=data{kkk}.REPEAT;
        myREP=data{kkk}.myREP;
        TOT=data{kkk}.TOT;
        CLICKS=length(data{kkk}.SM)-1;
        
        
        if isfield (data{kkk}, 'is_do_not_change')
            is_do_not_change=data{kkk}.is_do_not_change;
        else
            is_do_not_change=false;
        end
        
            if is_do_not_change
                plot(data{kkk}.SM,cnt*ones(size(data{kkk}.SM)),'rs');hold on;
            else
                plot(data{kkk}.SM,cnt*ones(size(data{kkk}.SM)),'bs');hold on;
            
            end
      
        %ylim([0 50]);
        for k=1:length(data{kkk}.SM)
            if is_do_not_change
                plot([data{kkk}.SM(k),data{kkk}.SM(k)],[cnt,cnt+data{kkk}.myREP],'r-');
            else
                plot([data{kkk}.SM(k),data{kkk}.SM(k)],[cnt,cnt+data{kkk}.myREP],'b-');
            end
            %plot([data{KKK}.RM(k),data{kkk}.RM(k)],[cnt,cnt+data{kkk}.myREP],'m-');
        end
        
      
        
        Rr=data{kkk}.Rr-data{kkk}.Sideal2(1);
        TOT=data{kkk}.TOT;
        REPEAT=data{kkk}.REPEAT;
        for ll=1:length(Rr)
            kter=floor(Rr(ll)/TOT);
            xpos=Rr(ll)-kter*TOT;
            if (xpos>=0) &&(xpos<TOT) && ( Rr(ll)<TOT*(myREP+0.2))
                mclr=(mod([21341*kkk+123,21223*kkk+112,2119*kkk+121] ,200))/256 +30/256;
                plot(xpos,cnt+kter,'.','Color',mclr,'MarkerSize',6);hold on;
            end
        end
        
        for J=1:size(Rm,1)
            mclr=(mod([21341*kkk+123,21223*kkk+112,2119*kkk+121] ,200))/256 +30/256;
            plot(Rm(J,:),cnt*ones(size(Rm(J,:))),'.','Color',mclr,'MarkerSize',8);hold on;
            plot(Rm(J,:),cnt*ones(size(Rm(J,:))),'xk');hold on;
            cnt=cnt+1;
        end
    end
    
    
end
title(msgN);
set(gca,'FontSize',14);
xlabel('Time (msec)')
ylabel('Iteration');
set(gca,'Ytick',data{kkk}.myREP*( (1:(KKK+1))-1 ));
set(gca,'YtickLabel',0:KKK);

if 1==2
    subplot(2,2,2);
    SM=data{1}.SM;
    for kkk=1:KKK
        if ~ isempty(data{kkk})
            RM=data{kkk}.RM;
        end
    end
    %RM=max(RM,TRUNC_TRESH); %%NOTE HERE
    md=max(min(diff(RM)),TRUNC_TRESH); %%NOTE HERE
    plot(diff(SM)/md,'sb-','LineWidth',3);hold on;
    plot(diff(RM)/md,'xr-.','LineWidth',2);hold all;
    legend('initial','current');
    set(gca,'FontSize',15);
    for kkk=1:KKK
        if ~ isempty(data{kkk})
            RM=data{kkk}.RM;
            md=max(min(diff(RM)),TRUNC_TRESH); %%NOTE HERE
            pt=kkk/REPEAT;
            ln=1;
            if kkk<=2
                ln=2;
            end
            plot(diff(RM)/md,'x-.','LineWidth',ln,'Color',[pt,0,1-pt]);hold all;
        end
    end
    plot(diff(RM)/md,'xr-.','LineWidth',2);hold all;drawnow
    drawnow;
    title(msgN);
end
%igure

subplot(2,2,3);
if CLICKS==3
    LITER_draw_clicks_clean_2018(ALL,KKK,TOT,TRUNC_TRESH)
    %     %plot(ws(:,1),ws(:,2),'.k');hold on;%drawnow;
    %     NITER_draw_random_field(NN,TOT,TRUNC_TRESH);hold on;
    %     wss=nan(KKK,2);
    %     wss0=nan(KKK,2);
    %     w0=nan(1,3);
    %     for kkk=1:KKK,
    %         if ~ isempty(data{kkk})
    %
    %             RM=data{kkk}.RM;
    %             rmm=diff(RM);
    %             smm=diff(data{1}.SM);
    %             smm2=diff(data{kkk}.SM);
    %             w=[0,0]*rmm(1)/TOT +[1,1]*rmm(2)/TOT +[0,1]*rmm(3)/TOT;
    %             w0=[0,0]*smm(1)/TOT +[1,1]*smm(2)/TOT +[0,1]*smm(3)/TOT;
    %             w02=[0,0]*smm2(1)/TOT +[1,1]*smm2(2)/TOT +[0,1]*smm2(3)/TOT;
    %             wss(kkk,1:2)=w;
    %             wss0(kkk,1:2)=w02;
    %         end
    %     end
    %     plot([w0(1,1);wss(:,1)],[w0(1,2);wss(:,2)],'or-');hold on;%drawnow;
    %     plot([w0(1,1);wss(:,1)],[w0(1,2);wss(:,2)],'b+');hold on;%drawnow;
    %
    %     plot(w0(1,1),w0(1,2),'ob-','LineWidth',2);hold on;%drawnow;
    %     %plot(wss0(:,1),wss0(:,2),'b+','LineWidth',1,'MarkerFaceColor','b','MarkerSize',6);hold on;%drawnow;
    %     plot(wss(end,1),wss(end,2),'sr-','LineWidth',2);hold on;%drawnow;
    %
    title(msgN);set(gca,'FontSize',14);
    %set(gca,'Visible','off');
    
elseif CLICKS==2
    %simulated_NN=200;
    
    sv=[];
    for l=1:NN
        
        vec=NITER_randomize_1threshold_point(CLICKS,TOT,TRUNC_TRESH);
        %         if rand(1,1)<1/10
        %             vec=[TOT/3,TOT*2/3]+randn(1,2)*50;
        %         end
        %         if rand(1,1)<1/10
        %             vec=[TOT/2,TOT/2]+randn(1,2)*50;
        %         end
        %          if rand(1,1)<1/10
        %             vec=[2*TOT/3,TOT/3]+randn(1,2)*50;
        %         end
        %         if rand(1,1)<1/10
        %             vec=[3*TOT/4,TOT/4]+randn(1,2)*50;
        %         end
        rvec=vec/sum(vec);
        rat=TOT*rvec(1);
        sv=[sv;rat];
    end
    
    plot(sv,sv*0+0,'mo');hold on;
    %[ysv,xsv] = ksdensity(sv);
    [ysv,xsv] = hist(sv,0:(TOT/24):TOT);
    errorbar(xsv,ysv/max(ysv)*0.9+0,sqrt(ysv)/max(ysv),'r--')
    %[ysv,xsv] = hist(sv,0:(TOT/12):TOT);
    %plot(xsv,ysv/max(ysv)*1+0,'r-')
    max(ysv)
    
    rv=[];
    for k=1:length(data)
        if isempty(data{k})
            continue
        end
        plot([0,TOT],[k k],'g--')
        errorbar([TRUNC_TRESH,TOT-TRUNC_TRESH],[k k],[0.1,0.1],'g-','LineWidth',2)
        for ii=1:4
            for jj=1:4
                if (ii==jj)&(ii~=1)
                    continue
                end
                %if (ii~=1)&&(jj~=1)
                %    continue
                %end
                if ii+jj>5
                    continue
                end
                v=[ii,jj];
                v=v/sum(v)*TOT;
                
                if min(v)>TRUNC_TRESH
                    rat=v(1);
                    msg=sprintf('%d:%d',ii,jj);
                    %plot(rat,k+0.6,'sk','MarkerSize',20);hold on;
                    plot(rat,k,'+k','MarkerSize',6);hold on;
                    text(rat,k+0.3,msg,'Color','k','HorizontalAlignment','center','VerticalAlignment','middle');
                    
                end
            end
        end
        
        
        rats=[];
        for l=1:size(data{k}.Rm,1)
            vec=data{k}.Rm(l,:);
            if sum(isnan(vec))>0
                continue;
            end
            
            dvec=diff(vec);
            rvec=dvec/sum(dvec);
            rat=TOT*rvec(1);
            rats=[rats,rat];
            
            plot(rat,k,'xb');hold on;
            
        end
        if ~isempty(rats)
            [ysv,xsv] = ksdensity(rats);
            %[yrv,xrv] = hist(rats,(0:50:TOT));
            plot(xsv,0.3*ysv/max(ysv)+0+k,'b-')
        end
        dvecM=diff(data{k}.RM);
        rvecM=dvecM/sum(dvecM);
        ratM=TOT*rvecM(1);
        plot(ratM,k,'ob');hold on;
        
        
        sratM=nan;
        svecM=diff(data{k}.SM);
        svecM=svecM/sum(svecM);
        sratM=TOT*svecM(1);
        
        plot(sratM,k-0.5,'db','MarkerSize',10,'MarkerFaceColor','b');hold on;
        
        if ~isnan(sratM)
            rv=[rv;sratM,k-0.5];
        end
        
        
        if ~isnan(ratM)
            if abs(sratM-ratM)<(TRUNC_TRESH)
                rv=[rv;ratM,k];
            end
            
        end
        
        
    end
    if ~isempty(rv)
        plot(rv(:,1),rv(:,2),'ob-','LineWidth',1);
        plot(rv(:,1),rv(:,2),'ob','LineWidth',1,'MarkerFaceColor','c','MarkerSize',8);
        plot(rv(1,1),rv(1,2),'oc-','LineWidth',2);
        plot(rv(end,1),rv(end,2),'or-','LineWidth',2);
        pos=(mod(rv(:,2),1)==0.5);
        plot(rv(pos,1),rv(pos,2),'db','MarkerSize',10,'MarkerFaceColor','b');hold on;
        
    end
    ylabel('Iteration #');
    xlabel('ISI/IRI(ms)');
    
    
    
end
set(gca,'FontSize',14);
subplot(2,2,4);
temp=[];
for kkk=1:KKK
    if isempty(data{kkk})
        continue;
    end
    vec=data{kkk}.e;
    vec=vec(~isnan(vec));
    temp=[temp;mean(vec),std(vec)];
end
plot(temp(:,2),'ko-','LineWidth',3);hold on;
plot(temp(:,1),'s--','LineWidth',2,'Color',[0.2 0.2 0.2]);hold on;
try
    legend('Std of Asynchrony','Mean Asynchrony','Location','best');
catch
    %try to avoid annoying warning
end
title(msgN);set(gca,'FontSize',14);
ylabel('msec');
xlabel('iterations');
set(gca,'Xtick',1:5);
drawnow;

%%%%%%%%%%%%%%%%%%%%%%