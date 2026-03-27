function RES=MASING_compute_stats(DATASETs,what_to_to)

Ntodo=length(what_to_to.exps); %number of condition to show

fprintf('Computing stats...\n');
RES=[]; % container for saving data
RES.summary=cell(Ntodo,1); % container for results
MLGS=cell(size(what_to_to.exps)); % container for legend
MAX_INTERVAL_for_accuracy=what_to_to.MAX_INTERVAL_for_accuracy;
for JJJ=1:Ntodo % run over all condition
    % get dat for current condition
    J0=what_to_to.exps(JJJ);
    MCLR=what_to_to.clrs{JJJ};
    MLN=what_to_to.line{JJJ};
    MGRP=what_to_to.grps{JJJ};
    
    NDATA=DATASETs{J0}.NDATA;
    data=NDATA.data;%=DATASETs{J0}.output.data;
    interval_options=DATASETs{J0}.output.todo.interval_options;
    OCTAVES= DATASETs{J0}.output.todo.OCTAVES;
    
    fprintf('\tNow in %d OF %d (%s)... NS=%d \n',JJJ,length(what_to_to.exps),DATASETs{J0}.EXP_NAME,DATASETs{J0}.NDATA.NS);
    
    MLGS{JJJ}=sprintf('%s (N=%d)',MGRP,DATASETs{J0}.NDATA.NS); % get legend with number of files
    
    NI=NDATA.NI; % number of potential intervals
    NO=NDATA.NO; % number of  octaves
    NR=NDATA.NR; % maximal number of repetitions
    NS=NDATA.NS; % number of subjects or trials
    rs=NDATA.rs;     % response interval (semitones)
    ss=NDATA.ss;     % stimulus interval (semitones)
    sb=NDATA.sb;     % base tone (midi notes)
    s1=NDATA.s1;     % stimulus note 1 (the fixed tone) in midi notes
    s2=NDATA.s2;     % stimulus note 2 in midi notes
    s10=NDATA.s10;   % stimulus note 1 transposed to vocal range ("target note 1") % in midi notes
    s20=NDATA.s20;   % stimulus note 2 transposed to vocal range ("target note 2") % in midi notes
    r1=NDATA.r1;     % response tone 1
    r2=NDATA.r2;     % response tone 2
    s1_last=NDATA.s1_last;   % last trial's stimulus tone 1 (midi notes)
    s2_last=NDATA.s2_last;   % last trial's stimulus tone 2 (midi notes)
    s10_last=NDATA.s10_last; % last trial's stimulus tone 1 (midi notes) transposed to the vocal range
    s20_last=NDATA.s20_last; % last trial's stimulus tone 2 (midi notes) transposed to the vocal range
    s1_next=NDATA.s1_next;   % next trial's stimulus tone 1 (midi notes)
    s2_next=NDATA.s2_next;   % next trial's stimulus tone 1 (midi notes)
    s10_next=NDATA.s10_next; % next trial's stimulus tone 1 (midi notes) transposed to the vocal range
    s20_next=NDATA.s20_next; % next trial's stimulus tone 1 (midi notes) transposed to the vocal range
    
    
    %%
    direction_accuracy=nan(NS,NO); %measure direction accuracy (of intervals)
    meanabs_accuracy=nan(NS,NO); %measuere mean absolute error accuracy (of intervals)
    
    all_s=cell(NO); % containers for values all data together (response- eperated by octaves)
    all_r=cell(NO); % containers for values all data together (stimulus-seperated by octaves)
    
    all_ss=cell(NO,length(interval_options));% all stimuli container
    all_rr=cell(NO,length(interval_options));% all responses container
    
    oct_titles=cell(NO); %container for octave titles
    
    for O=1:NO
        all_s{O}=nan(NS,length(interval_options));
        
        for II=1:NS
            intervals=data{II}.PARAMS.intervals;
            
            sss=[]; % container for allsubject stims interals
            rrr=[]; % container fot allsubject repsonse intervals
            
            for III=1:length(interval_options)
                iplaces=find(interval_options(III)==intervals); %find locations of intervals
                assert(~isempty(iplaces)); % should not be empty
                tss=ss(II,:,O,iplaces);tss=tss(:)'; %vectorize all relevant data
                trr=rs(II,:,O,iplaces);trr=trr(:)'; %vectorize all relevant data
                
                all_ss{O,III}=[all_ss{O,III};tss']; % update all simuli container
                all_rr{O,III}=[all_rr{O,III};trr']; % update all responses container
                
                all_s{O}(II,III)=mean(tss(~isnan(tss+trr))); % update all simuli container
                all_r{O}(II,III)=mean(trr(~isnan(tss+trr))); % update all responses container
                
                sss=[sss,tss]; % flatten all data and aggregate
                rrr=[rrr,trr]; % flatten all data and aggregate
            end
            
            % remove locations with no or error in responses
            pos=~isnan(rrr+sss);
            rrr=rrr(pos);
            sss=sss(pos);
            
            %%% direction accuracy:
            ddd=((rrr>0.5)&(sss>0.5)) + ((rrr<-0.5)&(sss<-0.5)) + ((abs(rrr)<0.5)&(abs(sss)<0.5));
            eee=mean(abs(ddd));
            direction_accuracy(II,O)=eee;
            
            %%% mean abs accuracy:
            ddd=rrr-sss;
            ddd=min(ddd,MAX_INTERVAL_for_accuracy);ddd=max(ddd,-MAX_INTERVAL_for_accuracy); %truncate outliers
            
            eee=mean(abs(ddd));
            meanabs_accuracy(II,O)=eee;
            
        end
        stemp=s2(:,:,O,:);stemp=stemp(:);stemp=stemp(~isnan(stemp));
        oct_titles{O}=sprintf('Register %1d ~%d-%d Hz',O,round(midi2freq(min(stemp))/10)*10,round(midi2freq(max(stemp))/10)*10);
    end
    %%% containers for psychometric curve
    pup=nan(NO,length(interval_options)); % up
    pdn=nan(NO,length(interval_options)); % down
    pun=nan(NO,length(interval_options)); % unison
    %%% containers for psychometric ste
    pup_e=nan(NO,length(interval_options)); % up
    pdn_e=nan(NO,length(interval_options)); % down
    pun_e=nan(NO,length(interval_options)); % unison
    
    for O=1:NO
        intervals=data{II}.PARAMS.intervals;
        for III=1:length(interval_options)
            
            % rearange data from this octave for all participants
            tss=ss(:,:,O,:);
            iplaces=(tss==interval_options(III));
            tss=tss(iplaces)';
            
            trr=rs(:,:,O,:);trr=trr(iplaces)';
            ts2=s2(:,:,O,:);ts2=ts2(iplaces)';
            
            pos=~isnan(tss+trr);
            tss=tss(pos);
            trr=trr(pos);
            
            % up
            mpup=sum(trr>0.5)/length(trr);
            mpup_e=sqrt(abs(mpup*(1-mpup)/length(trr)));
            
            % down
            mpdn=sum(trr<-0.5)/length(trr);
            mpdn_e=sqrt(abs(mpdn*(1-mpdn)/length(trr)));
            
            % aprox unison
            mpun=1-mpup-mpdn;
            mpun_e=sqrt(abs(mpun*(1-mpun)/length(trr)));
            
            % set data (octave interval)
            pup(O,III)=mpup;
            pdn(O,III)=mpdn;
            pun(O,III)=mpun;
            
            pup_e(O,III)=mpup_e;
            pdn_e(O,III)=mpdn_e;
            pun_e(O,III)=mpun_e;
            
            
        end
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%% store results within container
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    RES.Ntodo=Ntodo;
    RES.MLGS=MLGS;
    
    
    
    RES.summary{JJJ}.direction_accuracy=direction_accuracy;
    RES.summary{JJJ}.meanabs_accuracy=meanabs_accuracy;
    RES.summary{JJJ}.all_s=all_s;
    RES.summary{JJJ}.all_r=all_r;
    RES.summary{JJJ}.all_ss=all_ss;
    RES.summary{JJJ}.all_rr=all_rr;
    RES.summary{JJJ}.oct_titles= oct_titles;
    
    RES.summary{JJJ}.pup=pup;
    RES.summary{JJJ}.pdn=pdn;
    RES.summary{JJJ}.pun=pun;
    
    RES.summary{JJJ}.pup_e=pup_e;
    RES.summary{JJJ}.pdn_e=pdn_e;
    RES.summary{JJJ}.pun_e=pun_e;
end