function MASING_plot_stats(DATASETs,what_to_to,RES)
Ntodo=length(what_to_to.exps); %number of condition to show
DO_SUBPLOT=what_to_to.DO_SUBPLOT;
fprintf('Plot results: mean interval and std of interval...\n');
MLGS=RES.MLGS;
for JJJ=1:Ntodo % run over all condition
    
    J0=what_to_to.exps(JJJ);
    MCLR=what_to_to.clrs{JJJ};
    MLN=what_to_to.line{JJJ};
    MGRP=what_to_to.grps{JJJ};
    OCTAVES= DATASETs{J0}.output.todo.OCTAVES;
    interval_options=DATASETs{J0}.output.todo.interval_options;
    NDATA=DATASETs{J0}.NDATA;
    NI=NDATA.NI; % number of potential intervals
    NO=NDATA.NO; % number of  octaves
    NR=NDATA.NR; % maximal number of repetitions
    NS=NDATA.NS; % number of subjects or trials
    
    
    oct_titles=RES.summary{JJJ}.oct_titles;
    fprintf('\tNow in %d OF %d (%s)... NS=%d \n',JJJ,length(what_to_to.exps),DATASETs{J0}.EXP_NAME,DATASETs{J0}.NDATA.NS);
    for O=1:NO
        %%%%% plot mean response interval
        %%%%% (response note 2 - response note
        figure(1);
        if DO_SUBPLOT
            subplot(2,round(NO/2),O); %%%% do in multiple notes?
        end
        
        
        LW=2.5; % line width parameters
        h=errorbar(notnan_mean(RES.summary{JJJ}.all_s{O},1),notnan_mean(RES.summary{JJJ}.all_r{O},1),notnan_ste(RES.summary{JJJ}.all_r{O},1),['o' MLN],'LineWidth',LW,'Color',MCLR);hold on;
        set(gca,'FontSize',14);
        title(oct_titles{O});
        if JJJ==Ntodo % plot legend only for last participant
            if O==NO
                legend(MLGS,'AutoUpdate','off','FontSize',14,'Location','NorthWest');
            end
            
            plot(notnan_mean(notnan_mean(RES.summary{JJJ}.all_s{O},1),1),notnan_mean(notnan_mean(RES.summary{JJJ}.all_s{O},1),1),'g--','LineWidth',2);hold on; % stimulus = response line
            xlabel('Stimulus interval (semitones)');
            ylabel('Reproduced interval (semitones)');
            set(gca,'Xtick',interval_options);
            set(gca,'Ytick',interval_options);
            xlim([min(interval_options)-0.25,max(interval_options)+0.25])
            ylim([min(interval_options)-1.5,max(interval_options)+1.5])
            
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%% plot direction accuracy summary graph
    figure(2);
    errorbar(OCTAVES,notnan_mean(RES.summary{JJJ}.direction_accuracy,1),notnan_ste(RES.summary{JJJ}.direction_accuracy,1),'o-','color',MCLR,'LineWidth',3);title('Direction accuracy');hold on;
    
    set(gca,'Xtick',OCTAVES);
    set(gca,'XtickLabel',oct_titles);
    set(gca,'XTickLabelRotation',90)
    set(gca,'FontSize',14)
    title('direction accuracy')
    if JJJ==Ntodo
        legend(MLGS,'AutoUpdate','off','FontSize',14,'Location','NorthWest');
        plot(OCTAVES,OCTAVES*0+0.5,'g--','LineWidth',1);hold on;
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%% plot mean abs error accuracy summary graph
    figure(3);
    errorbar(OCTAVES,notnan_mean(RES.summary{JJJ}.meanabs_accuracy,1),notnan_ste(RES.summary{JJJ}.meanabs_accuracy,1),'o-','color',MCLR,'LineWidth',3);title('Direction accuracy');hold on;
    set(gca,'Xtick',OCTAVES);
    set(gca,'XtickLabel',oct_titles);
    set(gca,'XTickLabelRotation',90)
    set(gca,'FontSize',14)
    title('mean abs error accuracy')
    if JJJ==Ntodo
        legend(MLGS,'AutoUpdate','off','FontSize',14,'Location','NorthWest');
        
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
end


fprintf('Plot results: psychometric curve...\n');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%% plot and compute psychometric curves
%%%%% Note analysis here is done accumualting data
%%%%%  from all participants (and not by first averaging a paticipant
%%%%%  data)

figure(4);
mupdleg={};cmupdleg=0; % containers for direction data
for JJJ=1:Ntodo % run over all condition
    
    J0=what_to_to.exps(JJJ);
    MCLR=what_to_to.clrs{JJJ};
    MLN=what_to_to.line{JJJ};
    MGRP=what_to_to.grps{JJJ};
    OCTAVES= DATASETs{J0}.output.todo.OCTAVES;
    interval_options=DATASETs{J0}.output.todo.interval_options;
    NI=NDATA.NI; % number of potential intervals
    NO=NDATA.NO; % number of  octaves
    NR=NDATA.NR; % maximal number of repetitions
    NS=NDATA.NS; % number of subjects or trials
    
    fprintf('\tNow in %d OF %d (%s)... NS=%d \n',JJJ,length(what_to_to.exps),DATASETs{J0}.EXP_NAME,DATASETs{J0}.NDATA.NS);
    
    for O=1:NO
        if isfield(what_to_to,'lcrls')
            LCLR=what_to_to.lcrls;
            MCLR=LCLR{(JJJ-1)*3+1};
        end
        
        subplot(2,round(NO/2),O);
        LW=1;
        errorbar(interval_options,100*RES.summary{JJJ}.pup(O,:),100*RES.summary{JJJ}.pup_e(O,:),['-'],'LineWidth',LW,'Color',MCLR,'MarkerFaceColor',MCLR);hold on;
        if O==NO
            cmupdleg=cmupdleg+1;mupdleg{cmupdleg,1}=sprintf('Up %s',MLGS{JJJ});
        end
        
        if isfield(what_to_to,'lcrls')
            LCLR=what_to_to.lcrls;
            MCLR=LCLR{(JJJ-1)*3+2};
        end
        
        
        LW=JJJ+0.5;
        errorbar(interval_options,100*RES.summary{JJJ}.pdn(O,:),100*RES.summary{JJJ}.pdn_e(O,:),['--'],'LineWidth',LW,'Color',MCLR,'MarkerFaceColor',MCLR);hold on;
        if O==NO
            cmupdleg=cmupdleg+1;mupdleg{cmupdleg,1}=sprintf('Down %s',MLGS{JJJ});
        end
        
        if isfield(what_to_to,'isplot_unis') && (what_to_to.isplot_unis)
            LW=1;
            if isfield(what_to_to,'lcrls')
                LCLR=what_to_to.lcrls;
                MCLR=LCLR{(JJJ-1)*3+3};
            end
            
            errorbar(interval_options,100*RES.summary{JJJ}.pun(O,:),100*RES.summary{JJJ}.pun_e(O,:),[':'],'LineWidth',LW,'Color',MCLR,'MarkerFaceColor',MCLR);hold on;
            if O==NO
                cmupdleg=cmupdleg+1;mupdleg{cmupdleg,1}=sprintf('Unison %s',MLGS{JJJ});
            end
        end
        title(oct_titles{O});
        set(gca,'FontSize',14);
        ylim([0 100]);
        ylabel('Response direction (%)');
        xlabel('Stimulus interval (semitones)');
        set(gca,'Xtick',interval_options);
        xlim([min(interval_options)-0.25,max(interval_options)+0.25])
    end
    
end
figure(4);legend(mupdleg);