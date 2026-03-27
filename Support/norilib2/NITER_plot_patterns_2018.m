function NITER_plot_patterns_2018(ALL,KKK,msgN,NN)

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
    LITER_draw_clicks_clean_2018(ALL,KKK,TOT,TRUNC_TRESH)
    
    title(msgN);
    
elseif CLICKS==2
    
    sv=[];
    for l=1:NN
        
        vec=NITER_randomize_1threshold_point(CLICKS,TOT,TRUNC_TRESH);
        
        rvec=vec/sum(vec);
        rat=TOT*rvec(1);
        sv=[sv;rat];
    end
    
    plot(sv,sv*0+0,'mo');hold on;
    [ysv,xsv] = hist(sv,0:(TOT/24):TOT);
    errorbar(xsv,ysv/max(ysv)*0.9+0,sqrt(ysv)/max(ysv),'r--')
    
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