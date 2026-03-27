function LITER_draw_clicks_clean_2018(ALL,KKK,TOT,TRUNC_TRESH)
ymax=sqrt(3)/2;
TRIP={[0,0],[1,0],[1/2,ymax]}; %tip points
PT=[TRIP{1}(1),TRIP{1}(2);TRIP{2}(1),TRIP{2}(2);TRIP{3}(1),TRIP{3}(2)];

f=TRUNC_TRESH/TOT;
PS=[[f,f,1-2*f;f,1-2*f,f;1-2*f,f,f]];
m1=min(PS*PT);m2=max(PS*PT);
avec=([m1(1)-0.01,m2(1)+0.01,m1(2)-0.01,m2(2)]);

NITER_draw_random_field_tri_clr_clean_2017(TOT,TRUNC_TRESH,PT)



%%NN=300;
%%figure(11);clf
for J=1:length(ALL)
    for kkk=1:KKK
        if isempty(ALL{J})
            continue
        end
        if ~isempty(ALL{J}.data{kkk})
            
            fname=ALL{J}.data{kkk}.fname;
            TRUNC_TRESH=ALL{J}.data{kkk}.TRUNC_TRESH;
            REPEAT=ALL{J}.data{kkk}.REPEAT;
            TOT=ALL{J}.data{kkk}.TOT;
            CLICKS=length(ALL{J}.data{kkk}.SM)-1;
            
        end
    end
end


%NITER_draw_random_field(0,TOT,TRUNC_TRESH);hold on;
for J=1:length(ALL)
    %plot(ws(:,1),ws(:,2),'.k');hold on;%drawnow;
    data=ALL{J}.data;
    wss=nan(KKK,2);
    w0=nan(1,3);
    for kkk=1:KKK
        wsss=[];
        wsss2=[];
        if ~ isempty(data{kkk})
            
            
            Rm2=data{kkk}.Rm;
            for j=1:(CLICKS+1)
                vec=Rm2(:,j);
                vec=vec(~isnan(vec));
                Rm2(isnan(Rm2(:,j)),j)=mean(vec);
            end
%             
            RM=data{kkk}.RM;
            rmm=diff(RM);
            smm=diff(data{1}.SM);
            w=(rmm/TOT)*PT;
            w0=(smm/TOT)*PT;
            wss(kkk,1:2)=w;
            

            
            for l=1:size(data{kkk}.Rm,1)
                vec=data{kkk}.Rm(l,:);
               vec=diff(vec);
                vec=TOT*vec/sum(vec);
                wv=(vec/TOT)*PT;
                wsss=[wsss;wv];
                
                vec2=Rm2(l,:);
                vec2=diff(vec2);
                vec2=TOT*vec2/sum(vec2);
                wv2=(vec2/TOT)*PT;
                wsss2=[wsss2;wv2];
                
               
                
            end
            mclr=(mod([21341*kkk+123,21223*kkk+112,2119*kkk+121] ,200))/256 +30/256;
            
            if ~isempty(wsss2)
                plot(wsss2(:,1),wsss2(:,2),'o','MarkerSize',5,'Color',mclr);%drawnow;
            end
             if ~isempty(wsss)
                plot(wsss(:,1),wsss(:,2),'o','MarkerSize',5,'Color',mclr,'MarkerFaceColor',mclr);hold all;%drawnow;
            end
            
            
            
        end
    end
    
    plot([w0(1,1);wss(:,1)],[w0(1,2);wss(:,2)],'rx-','LineWidth',3);hold all;%drawnow;
    plot([w0(1,1);wss(:,1)],[w0(1,2);wss(:,2)],'kx','LineWidth',3);hold all;%drawnow;
    plot(w0(1,1),w0(1,2),'ok-','LineWidth',2,'MarkerFaceColor','k','MarkerSize',10);hold on;%drawnow;
    
    plot(wss(end,1),wss(end,2),'sk-','MarkerFaceColor','r','LineWidth',2,'MarkerSize',10);hold on;%drawnow;
    
end
axis(avec)
