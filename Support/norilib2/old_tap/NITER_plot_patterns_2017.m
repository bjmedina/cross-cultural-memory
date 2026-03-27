function NITER_plot_patterns_2017(ALL,KKK,msgN,NN)
%%NN=300;
%%figure(11);clf
for J=1:length(ALL)
    for kkk=1:KKK
        if isempty(ALL{J})
            continue
        end
        if ~ isempty(ALL{J}.data{kkk})
            
            TRUNC_TRESH=ALL{J}.data{kkk}.TRUNC_TRESH;
            REPEAT=ALL{J}.data{kkk}.REPEAT;
            TOT=ALL{J}.data{kkk}.TOT;
            CLICKS=length(ALL{J}.data{kkk}.SM)-1;
            
        end
    end
end

if CLICKS==3
        LITER_draw_clicks_clean_2017(ALL,KKK,TOT,TRUNC_TRESH)

%     
    title(msgN);
%     NITER_draw_random_field(NN,TOT,TRUNC_TRESH);hold on;
%     for J=1:length(ALL)
%         %plot(ws(:,1),ws(:,2),'.k');hold on;%drawnow;
%         data=ALL{J}.data;
%         wss=nan(KKK,2);
%         wss0=nan(KKK,2);
%         w0=nan(1,3);
%         for kkk=1:KKK,
%             wsss=[];
%             if ~ isempty(data{kkk})
%                 
%                 RM=data{kkk}.RM;
%                 rmm=diff(RM);
%                 smm=diff(data{1}.SM);
%                 smm2=diff(data{kkk}.SM);
%                 smm2=smm2/sum(smm2)*TOT;
%                 w=[0,0]*rmm(1)/TOT +[1,1]*rmm(2)/TOT +[0,1]*rmm(3)/TOT;
%                 w0=[0,0]*smm(1)/TOT +[1,1]*smm(2)/TOT +[0,1]*smm(3)/TOT;
%                 w02=[0,0]*smm2(1)/TOT +[1,1]*smm2(2)/TOT +[0,1]*smm2(3)/TOT;
%                 wss(kkk,1:2)=w;
%                 wss0(kkk,1:2)=w02;
%                 
%                 
%                 for l=1:size(data{kkk}.Rm,1)
%                     vec=data{kkk}.Rm(l,:);
%                     
%                     if sum(isnan(vec))>0
%                         continue;
%                     end
%                     if (min(diff(vec)))<=(TRUNC_TRESH+eps)
%                         continue;
%                     end
%                     vec=diff(vec(1:(CLICKS+1)));
%                     vec=TOT*vec/sum(vec);
%                     wv=[0,0]*vec(1)/TOT +[1,1]*vec(2)/TOT +[0,1]*vec(3)/TOT;
%                     
%                     wsss=[wsss;wv];
%                     
%                     
%                 end
%                 if ~isempty(wsss)
%                     plot(wsss(:,1),wsss(:,2),'.','MarkerSize',10);hold all;%drawnow;
%                 end
%                
%                 
%                 
%             end
%         end
%   
%         plot([w0(1,1);wss(:,1)],[w0(1,2);wss(:,2)],'x-','LineWidth',3);hold all;%drawnow;
%         plot([w0(1,1);wss(:,1)],[w0(1,2);wss(:,2)],'+b');hold all;%drawnow;
%         
%          %plot(wss0(:,1),wss0(:,2),'+b','LineWidth',1,'MarkerFaceColor','b','MarkerSize',6);hold on;%drawnow;
%         plot(w0(1,1),w0(1,2),'ok-','LineWidth',2,'MarkerFaceColor','b','MarkerSize',10);hold on;%drawnow;
%         %plot(wss0(:,1),wss0(:,2),'+b','LineWidth',1,'MarkerFaceColor','b','MarkerSize',6);hold on;%drawnow;
%         plot(wss(end,1),wss(end,2),'sk-','MarkerFaceColor','r','LineWidth',2,'MarkerSize',10);hold on;%drawnow;
%         
%         title(msgN);
%    end
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
    fprintf('min/max number point in histogram cell is %d/%d of total %d points\n',min(ysv),max(ysv),sum(ysv));
    
    for J=1:length(ALL)
        if isempty(ALL{J})
            continue
        end
        data=ALL{J}.data;
        rv=[];
        h=[];
        for k=1:length(data)
            if isempty(data{k})
                continue
            end
            plot([0,TOT],[k k],'g--')
            errorbar([TRUNC_TRESH,TOT-TRUNC_TRESH],[k k],[0.1,0.1],'g-','LineWidth',2)
            for ii=1:4
                for jj=1:4
                    if (ii==jj)&&(ii~=1)
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
                hold all;h1=plot(xsv,0.3*ysv/max(ysv)+0+k,'-');
                if ~isempty(h)
                    set(h1,'Color',h.Color);
                    
                end
                h=h1;
            end
            dvecM=diff(data{k}.RM);
            rvecM=dvecM/sum(dvecM);
            ratM=TOT*rvecM(1);
            
             sratM=nan;
             svecM=diff(data{k}.SM);
             svecM=svecM/sum(svecM);
             sratM=TOT*svecM(1);
             
            plot(sratM,k-0.5,'db','MarkerSize',12,'MarkerFaceColor','b');hold on;
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
            hold all;h2=plot(rv(:,1),rv(:,2),'o-','LineWidth',2);
            if ~isempty(h)
                set(h2,'Color',h.Color);
            end
            plot(rv(:,1),rv(:,2),'ob','LineWidth',1,'MarkerFaceColor','c','MarkerSize',8);
            plot(rv(1,1),rv(1,2),'oc-','LineWidth',2);
            plot(rv(end,1),rv(end,2),'or-','LineWidth',2);
             pos=(mod(rv(:,2),1)==0.5);
            plot(rv(pos,1),rv(pos,2),'db','MarkerSize',10,'MarkerFaceColor','b');hold on;
            ylabel('iteration #');
            xlabel('ISI/IRI(ms)');
        end
    end
    
end