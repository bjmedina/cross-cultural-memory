function output=MASING_get_matching_data(todo)

fprintf('\n****************************************************************************************\n*** getting matching data for Experiment %s\n****************************************************************************************\n',todo.EXP_NAME);


if isempty(todo.filter_unique_participants) || isnan(todo.filter_unique_participants)
    todo.filter_unique_participants=0;
end


intervals0=todo.intervals0;
OCTAVES=todo.OCTAVES;
RESsize=todo.RESsize;
GENDER=todo.GENDER;
interval_options=todo.interval_options;


if ischar(todo.data_or_data_dir)
    data_dir=todo.data_or_data_dir;
    cd (data_dir)
    
    adir=dir(todo.fseed_pattern);
    assert(~isempty(adir));
    NS=length(adir);
    IS_DIR=true;
    
else
    NS=length(todo.data_or_data_dir.data);
    IS_DIR=false;
    todo.fseed_pattern=strrep(todo.fseed_pattern,'*','.*');

end

output=[];
output.data=cell(2,1);
cnt=0;cnt2=0;cnt1=0;cnt3=0;
output.fseeds=cell(2,1);


fseeds=cell(2,1);
for I=1:NS
    if IS_DIR
        fname=adir(I).name;
        if todo.VERBOSITY>1
            fprintf('loading I=%d of %d:  %s...\n',I,NS,fname);
        end
        mdata=load(fname);
        
    else
        
        
        mdata=todo.data_or_data_dir.data{I};
        fname=mdata.fname;
        if todo.VERBOSITY>1
            fprintf('loading I=%d of %d:  %s...\n',I,NS,fname);
        end
        if isempty(regexp(fname,todo.fseed_pattern, 'once'))
            if todo.VERBOSITY>1
                fprintf('\tskipping file: %s becuase does not match in filename: %s\n',fname,todo.fseed_pattern)
               
            end
             cnt1=cnt1+1;
                continue
            
        end
        
        
        
    end
    fseed=mdata.PARAMS.fname;
    fseed=fseed(1:(strfind(mdata.PARAMS.fname,'RND')-2));
    if isfield(mdata,'code_uniq_demog')
        fseed=mdata.code_uniq_demog;
    end
    
    
    
    
    mdata.PARAMS.fseed=fseed;
    %mdata
    if (length(mdata.PARAMS.intervals)~=length(intervals0))
        
        
        if todo.VERBOSITY>2
            fprintf('interval length do not match...\n')
            mdata
            mdata.PARAMS
        end
        cnt2=cnt2+1;
        continue
    end
    
    intervals0p=intervals0;
    intervals0p(isnan(intervals0p))=mdata.PARAMS.intervals(isnan(intervals0p));
    if (sum(mdata.PARAMS.intervals==intervals0p)~=length(intervals0))
        if todo.VERBOSITY>2
            fprintf('intervals params do not match...\n')
            mdata
            mdata.PARAMS
        end
        cnt2=cnt2+1;
        continue
    end
    
    if (length(mdata.PARAMS.octaves)~=length(OCTAVES))
        if todo.VERBOSITY>2
            fprintf('octaves length do not match...\n')
            mdata
            mdata.PARAMS
        end
        cnt2=cnt2+1;
        continue
    end
    if (size(mdata.RES,1)>RESsize(1))||(size(mdata.RES,2)~=RESsize(2))||(size(mdata.RES,3)~=RESsize(3))
        if todo.VERBOSITY>2
            fprintf('RES size do not match...\n')
            mdata
            mdata.PARAMS
        end
        cnt2=cnt2+1;
        continue
    end
    if ~isnan(GENDER) && (GENDER~=mdata.PARAMS.IS_MALE)
        if todo.VERBOSITY>2
            fprintf('Gender do not match...\n')
            mdata
            mdata.PARAMS
        end
        cnt2=cnt2+1;
        continue
    end
    if todo.VERBOSITY>2
        size(mdata.RES)
    end
    
    is_found=false;
    old_place=[];
    for ll=1:length(output.fseeds)
        if strcmp(output.fseeds{ll},fseed)
            is_found=true;
            old_time=datenum(output.data{ll}.PARAMS.time_start);
            new_time=datenum(mdata.PARAMS.time_start);
            old_place=ll;
            break
        end
    end
    
    
    if todo.filter_unique_participants<0 && is_found
        if new_time<old_time
            fprintf('Replacing data with participant %s\t of time: %s \t. A later data point (time: %s) is not relevant any more\n',fseed,mdata.PARAMS.time_start,output.data{old_place}.PARAMS.time_start)
            output.data{old_place}=mdata;
            output.fseeds{old_place}=fseed;
            cnt3=cnt3+1;
        else
            fprintf('Skipping data for participant %s\t of time: %s \t.  Found a earlier data point (time: %s)\n',fseed,mdata.PARAMS.time_start,output.data{old_place}.PARAMS.time_start)
            cnt3=cnt3+1;
        end
    elseif todo.filter_unique_participants>0 && is_found
        if new_time>old_time
            fprintf('Replacing data with participant %s\t of time: %s \t. An earlier data point (time: %s) is not relevant any more\n',fseed,mdata.PARAMS.time_start,output.data{old_place}.PARAMS.time_start)
            output.data{old_place}=mdata;
            output.fseeds{old_place}=fseed;
            cnt3=cnt3+1;
        else
            fprintf('Skipping data for participant %s\t of time: %s \t Found later data point (time: %s)\n',fseed,mdata.PARAMS.time_start,output.data{old_place}.PARAMS.time_start)
            cnt3=cnt3+1;
        end
        
    else
        cnt=cnt+1;
        output.data{cnt}=mdata;
        output.fseeds{cnt}=fseed;
        
    end
     
    
    if cnt==1
        fprintf('************** TARGET ************\n');
        mdata
        mdata.PARAMS
        fprintf('************** TARGET ************\n');
    end
    
    
end

if length(output.fseeds)<=2
    nparts=0;
else
    nparts=length(unique(output.fseeds));
end


fprintf('originally %d lines/files \t found %d files, before unique found %d, with %d unique participants matched paramas.\n\t Skipped %d becuase of filename, %d because of params mismatch and %d becuase of chronology order (all skipped=%d)\n',...
    NS,cnt, cnt+cnt3,nparts,cnt1,cnt2,cnt3,cnt1+cnt2+cnt3);

assert(cnt>0);
output.todo=todo;
fprintf('\n****************************************************************************************\n*** done matching data for Experiment %s\n****************************************************************************************\n',todo.EXP_NAME);


