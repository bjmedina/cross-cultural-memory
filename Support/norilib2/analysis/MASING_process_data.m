function NDATA=MASING_process_data(data)

fprintf('processing files to numeric data structure...\n');
NDATA.NS=length(data);
NS=NDATA.NS;
NDATA.rs=[];
NDATA.ss=[];
NDATA.sb=[];
NDATA.s1=[];
NDATA.s2=[];
NDATA.s10=[];
NDATA.s20=[];
NDATA.r1=[];
NDATA.r2=[];
NDATA.s1_last=[];
NDATA.s2_last=[];
NDATA.s10_last=[];
NDATA.s20_last=[];
NDATA.s1_next=[];
NDATA.s2_next=[];
NDATA.s10_next=[];
NDATA.s20_next=[];
NDATA.cnt=0;
NDATA.NI=[];
NDATA.NO=[];
NDATA.NR=[];
NDATA.intervals=cell(NS,1);
NDATA.octaves=cell(NS,1);
NDATA.IS_MALE=nan(NS,1);
NDATA.BASE_TONE_RANGE_low=[];
NDATA.BASE_TONE_RANGE_high=[];

NDATA.data=data;
% NDATA.data=data.data;
% 
% NDATA.interval_options=data.todo.interval_options;
% NDATA.OCTAVES=data.todo.OCTAVES;
% data=data.data;

for II=1:NS
    
    if isempty(data{II})
        continue
    end
    
    if isfield(data{II}.PARAMS,'IS_MALE')
        IS_MALE=data{II}.PARAMS.IS_MALE;
    else
        IS_MALE=[];
    end
    octaves=data{II}.PARAMS.octaves;
    intervals=data{II}.PARAMS.intervals;
    BASE_TONE_RANGE=data{II}.PARAMS.BASE_TONE_RANGE;
    
    NDATA.intervals{II}=intervals;
    NDATA.octaves{II}=octaves;
    NDATA.IS_MALE(II)=IS_MALE;
    
    if isempty(NDATA.NI)
        NDATA.NI=length(intervals);
        NDATA.NO=length(octaves);
        NDATA.NR=size(data{II}.RES,1);
        NI=NDATA.NI;
        NO=NDATA.NO;
        NR=NDATA.NR;
    else
        assert(NDATA.NI==length(intervals))
        assert(NDATA.NO==length(octaves))
        assert(NDATA.NR==size(data{II}.RES,1))
    end
    
    
    RES=data{II}.RES;
    if isempty (NDATA.rs)
        NDATA.rs=nan(NS,NR,NO,NI);
        NDATA.ss=nan(NS,NR,NO,NI);
        NDATA.sb=nan(NS,NR,NO,NI);
        NDATA.s1=nan(NS,NR,NO,NI);
        NDATA.s2=nan(NS,NR,NO,NI);
        NDATA.s10=nan(NS,NR,NO,NI);
        NDATA.s20=nan(NS,NR,NO,NI);
        NDATA.r1=nan(NS,NR,NO,NI);
        NDATA.r2=nan(NS,NR,NO,NI);
        NDATA.s1_last=nan(NS,NR,NO,NI);
        NDATA.s2_last=nan(NS,NR,NO,NI);
        NDATA.s10_last=nan(NS,NR,NO,NI);
        NDATA.s20_last=nan(NS,NR,NO,NI);
        NDATA.s1_next=nan(NS,NR,NO,NI);
        NDATA.s2_next=nan(NS,NR,NO,NI);
        NDATA.s10_next=nan(NS,NR,NO,NI);
        NDATA.s20_next=nan(NS,NR,NO,NI);
        NDATA.BASE_TONE_RANGE_low=nan(NS,NR,NO,NI);
        NDATA.BASE_TONE_RANGE_high=nan(NS,NR,NO,NI);


    end
    
    for K=1:NDATA.NR
        
        for O=1:NDATA.NO
           
            
            for I=1:NDATA.NI
                mdata=data{II}.RES{K,O,I};
                if isempty(mdata)
                    continue
                end
                if ~mdata.is_good
                    continue
                end
                NDATA.cnt=NDATA.cnt+1;
                TONES0=mdata.TONES0;
                TONES=mdata.TONES;
                RESP=RES{K,O,I}.resp_midi;
                BASE_TONE=RES{K,O,I}.BASE_TONE;
                if isfield(RES{K,O,I},'my_time')
                    my_time=datenum(RES{K,O,I}.my_time);
                else
                    my_time=nan;
                end
                
                sinterval=diff(TONES);
                rinterval=diff(RESP);
                
                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%% get previous  and next trial in chronological order.
                %%%%%%%%%%%%%%%%%%%%%%%%%
                current_octave_order=find((RES{K,O,I}.perm_octave==O));
                
                if current_octave_order>1
                    O_previous=RES{K,O,I}.perm_octave(current_octave_order-1);
                else
                    O_previous=nan;
                end
                
                
                my_time_last=nan;
                TONES_last=nan(size(TONES));
                TONES0_last=nan(size(TONES0));
                if ~isnan(O_previous)
                    for kkk=1:size(RES{K,O_previous,I},1)
                        if isempty(RES{kkk,O_previous,I})
                            continue
                        end
                        TONES_last=RES{kkk,O_previous,I}.TONES;
                        TONES0_last=RES{kkk,O_previous,I}.TONES0;
                        assert(sum(isnan(TONES_last))==0);
                        assert(sum(isnan(TONES0_last))==0);
                        if isfield(RES{kkk,O_previous,I},'my_time')
                            my_time_last=datenum(RES{kkk,O_previous,I}.my_time);
                        end
                    end
                    
                end
                
                if current_octave_order<length(RES{K,O,I}.perm_octave)
                    O_next=RES{K,O,I}.perm_octave(current_octave_order+1);
                else
                    O_next=nan;
                end
                
                my_time_next=nan;
                TONES_next=nan(size(TONES));
                TONES0_next=nan(size(TONES0));
                if ~isnan(O_next)
                    for kkk=1:size(RES{K,O_next,I},1)
                        if isempty(RES{kkk,O_next,I})
                            continue
                        end
                        TONES_next=RES{kkk,O_next,I}.TONES;
                        TONES0_next=RES{kkk,O_next,I}.TONES0;
                        assert(sum(isnan(TONES_next))==0);
                        assert(sum(isnan(TONES0_next))==0);
                        if isfield(RES{kkk,O_next,I},'my_time')
                            my_time_next=datenum(RES{kkk,O_next,I}.my_time);
                        end
                    end
                    
                end
                if ~isnan(my_time_next)
                    assert(my_time<my_time_next)
                end
                
                if ~isnan(my_time_last)
                    assert(my_time>my_time_last)
                end
                
               
                
                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%% finish chronological order
                %%%%%%%%%%%%%%%%%%%%%%%%%
                
                NDATA.rs(II,K,O,I)=rinterval;
                NDATA.ss(II,K,O,I)=sinterval;
                NDATA.sb(II,K,O,I)=BASE_TONE;
                NDATA.s1(II,K,O,I)=TONES(1);
                NDATA.s2(II,K,O,I)=TONES(2);
                NDATA.s10(II,K,O,I)=TONES0(1);
                NDATA.s20(II,K,O,I)=TONES0(2);
                NDATA.r1(II,K,O,I)=RESP(1);
                NDATA.r2(II,K,O,I)=RESP(2);
                NDATA.s1_last(II,K,O,I)=TONES_last(1);
                NDATA.s2_last(II,K,O,I)=TONES_last(2);
                NDATA.s10_last(II,K,O,I)=TONES0_last(1);
                NDATA.s20_last(II,K,O,I)=TONES0_last(2);
                
                NDATA.s1_next(II,K,O,I)=TONES_next(1);
                NDATA.s2_next(II,K,O,I)=TONES_next(2);
                NDATA.s10_next(II,K,O,I)=TONES0_next(1);
                NDATA.s20_next(II,K,O,I)=TONES0_next(2);
                % rs(II,K,O,I)=TONES0(1;
                %ss(II,K,O,I)=RESP-TONES0(1);
                
                NDATA.BASE_TONE_RANGE_low(II,K,O,I)=min(BASE_TONE_RANGE);
                NDATA.BASE_TONE_RANGE_high(II,K,O,I)=max(BASE_TONE_RANGE);
                
            end
        end
    end
end


fprintf('DONE! processed %d trials.\n',NDATA.cnt);
