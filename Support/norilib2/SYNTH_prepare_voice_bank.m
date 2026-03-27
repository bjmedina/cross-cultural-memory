function Ps=SYNTH_prepare_voice_bank(root_sample_dir,root_seed,IS_PLAY_SOUNDS,fs0,FADE_OUT)

%clear all;close all;clc

Ps=[];
%%%  parameters:
%root_sample_dir='~/reSearchColumbia/BOLIVIA2018/SING/GenerateInstrumentFiles_Nori/InstrumentFilesProcessed';
%root_seed='f*.wav'; %root_seed='m*.wav';
%fs0=44100; % make sure everything is in the same sampling rate
%IS_PLAY_SOUNDS=false;

cd (root_sample_dir);
adir=dir(root_seed);

inst_names=cell(2,1);
for I=1:length(adir)
    fname=adir(I).name;
    vec=strrep(fname,'.wav','');
    vec=strsplit(vec,'_');
    gender=vec{1};
    assert(strcmp(gender,'f')||strcmp(gender,'m'));
    singer_num=vec{2};
    vowel_num=vec{3};
    midi_note=(str2double(vec{4}))/10;
    assert(midi_note>30);
    assert(midi_note<110);
    
    inst_name=sprintf('%s_%s_%s',vec{1},vec{2},vec{3});
    
    inst_names{I}=inst_name;
    
end
inst_names=unique(inst_names);
NI=length(inst_names);


INSTRUMENTS=cell(1,NI);

MAX_NUM=-1;
for I=1:length(adir)
    fname=adir(I).name;
    vec=strrep(fname,'.wav','');
    vec=strsplit(vec,'_');
    gender=vec{1};
    assert(strcmp(gender,'f')||strcmp(gender,'m'));
    singer_num=vec{2};
    vowel_num=vec{3};
    midi_note=(str2double(vec{4}))/10;
    assert(midi_note>30);
    assert(midi_note<110);
    
    inst_name=sprintf('%s_%s_%s',vec{1},vec{2},vec{3});
    is_found=false;
    for ll=1:length(inst_names)
        if strcmp(inst_names{ll,1},inst_name)
            ll_idx=ll;
            is_found=true;
            break
        end
    end
    assert(is_found);
    
    INSTRUMENTS{1,ll_idx}.name=inst_names{ll_idx};
    if isfield(INSTRUMENTS{1,ll_idx},'notes')
        INSTRUMENTS{1,ll_idx}.notes(1,end+1)=midi_note;
        INSTRUMENTS{1,ll_idx}.patterns{1,end+1}=fname;
    else
        INSTRUMENTS{ll_idx}.notes=midi_note;
        INSTRUMENTS{ll_idx}.patterns=cell(1,1);
        INSTRUMENTS{ll_idx}.patterns{1,1}=fname;
    end
    
    MAX_NUM=max(MAX_NUM,length(INSTRUMENTS{ll_idx}.notes));
end

%%


fprintf('Making sound bank for root-dir: %s\n and seed %s\n',root_sample_dir,root_seed)
cd (root_sample_dir);
for I=1:length(INSTRUMENTS)
    INSTRUMENTS{I}.pattern_files=cell(size(INSTRUMENTS{I}.notes));
    INSTRUMENTS{I}.patterns_codes=cell(size(INSTRUMENTS{I}.patterns));
    for J=1:length(INSTRUMENTS{I}.notes)
        fname_pat=sprintf('%s',INSTRUMENTS{I}.patterns{J});


        pattern_code=INSTRUMENTS{I}.patterns{J};
        pattern_code=strrep(pattern_code,'*','');
        pattern_code=strrep(pattern_code,'.wav','');
        
        INSTRUMENTS{I}.patterns_codes{J}=pattern_code;

        fname_pat;
        a=dir(fname_pat);
        assert(length(a)>0);
        INSTRUMENTS{I}.pattern_files{J}.files=cell(size(a));
        INSTRUMENTS{I}.pattern_files{J}.wavs=cell(size(a));
        %fprintf('Instrument name= %s\t note %3.1f  pattern %s [%s]\n',INSTRUMENTS{I}.name, INSTRUMENTS{I}.notes(J),INSTRUMENTS{I}.patterns{J},INSTRUMENTS{I}.patterns_codes{J});
        for K=1:length(INSTRUMENTS{I}.pattern_files{J}.files)
            fname_wav=sprintf('%s/%s',root_sample_dir,a(K).name);
           

            INSTRUMENTS{I}.pattern_files{J}.files{K}=fname_wav;
            INSTRUMENTS{I}.pattern_files{J}.codes{K}=pattern_code;
            [y,fs]=audioread(fname_wav);
            y=fade_out(y,fs,FADE_OUT);
            INSTRUMENTS{I}.pattern_files{J}.wavs{K}=y;

            %fprintf('\tLoading file: %s duration %g (ms) fs= %d\n',fname_wav,1000*length(y)/fs,fs)
            assert(fs==fs0);
        end
    end
end



if IS_PLAY_SOUNDS
    figure(1);clf;
end
fprintf('\nValidating files...\n');
% print instrument content:
cnt_all=0;
for I=1:length(INSTRUMENTS)
    if IS_PLAY_SOUNDS
        fprintf('Instrument name= %s\n',INSTRUMENTS{I}.name);
    end
    cnt=0;
    for J=1:length(INSTRUMENTS{I}.notes)

        if IS_PLAY_SOUNDS
            fprintf('Instrument name= %s\t note %3d  pattern %s \n',INSTRUMENTS{I}.name, INSTRUMENTS{I}.notes(J),INSTRUMENTS{I}.patterns{J});
        end
        assert(sum(size(INSTRUMENTS{I}.notes)==size(INSTRUMENTS{I}.patterns))==2);
        mclr=mod([J*234+I*21+12,J*2134+I*221+11,J*241+I*221+1],255)/255;
        for K=1:length(INSTRUMENTS{I}.pattern_files{J}.files)
            cnt=cnt+1;cnt_all=cnt_all+1;
            if IS_PLAY_SOUNDS
                fprintf('\t \t \t \t %s\t [%s]\n',INSTRUMENTS{I}.pattern_files{J}.files{K},INSTRUMENTS{I}.pattern_files{J}.codes{K});
            end
            assert(~isempty(dir(INSTRUMENTS{I}.pattern_files{J}.files{K})));

            if IS_PLAY_SOUNDS
                %subplot_tight(length(INSTRUMENTS),MAX_NUM,(I-1)*MAX_NUM + (J-1)*length(INSTRUMENTS{I}.pattern_files{J}.files)+K)
                %[length(INSTRUMENTS),MAX_NUM,(I-1)*MAX_NUM + cnt]
                %subplot_tight(length(INSTRUMENTS),MAX_NUM,(I-1)*MAX_NUM + cnt)
                %subplot(length(INSTRUMENTS),MAX_NUM,(I-1)*MAX_NUM + (J-1)*length(INSTRUMENTS{I}.pattern_files{J}.files)+K);
                subplot(length(INSTRUMENTS),MAX_NUM,(I-1)*MAX_NUM + cnt);

                plot(1000*(1:length(INSTRUMENTS{I}.pattern_files{J}.wavs{K}))/fs0,INSTRUMENTS{I}.pattern_files{J}.wavs{K},'Color',mclr);

                msg=sprintf('%s [%3d]\n%s\n%s',INSTRUMENTS{I}.name, INSTRUMENTS{I}.notes(J),INSTRUMENTS{I}.patterns_codes{J},INSTRUMENTS{I}.pattern_files{J}.codes{K});
                %msg=sprintf('%s',INSTRUMENTS{I}.pattern_files{J}.codes{K});

                h=title(msg);
                set(h,'FontSize',8);
                ylim([-1 1])
            end
            if IS_PLAY_SOUNDS
                drawnow;
                nori_doplay2(INSTRUMENTS{I}.pattern_files{J}.wavs{K},fs)
                %nori_doplay2id(INSTRUMENTS{I}.pattern_files{J}.wavs{K},fs,2)
            end

        end

    end
end
fprintf('%d Files OK!\n',cnt_all);
%P.INSTRUMENTS=INSTRUMENTS;
Ps=cell(1,NI);

fprintf('Making midi map list (map each midi note to a sample) for %d instruments...\n',NI);

for I=1:length(INSTRUMENTS)
    MAPPER10=cell(1270,1);
    for J=1:length(INSTRUMENTS{I}.notes)
        note10=round(INSTRUMENTS{I}.notes(J)*10);
        assert(isempty(MAPPER10{note10}));
        %MAPPER{note}.samples=cell(length(INSTRUMENTS{I}.pattern_files{J}.files));
        MAPPER10{note10}.files=cell(length(INSTRUMENTS{I}.pattern_files{J}.files));

        for K=1:length(INSTRUMENTS{I}.pattern_files{J}.files)
            MAPPER10{note10}.files{K}=INSTRUMENTS{I}.pattern_files{J}.files{K};
            MAPPER10{note10}.codes{K}=INSTRUMENTS{I}.pattern_files{J}.codes{K};
            MAPPER10{note10}.wavs{K} =INSTRUMENTS{I}.pattern_files{J}.wavs{K};
        end
    end
    Ps{I}.MAPPER=MAPPER10;
    Ps{I}.fs0=fs0;
    Ps{I}.FADE_OUT=FADE_OUT;
    Ps{I}.INSTRUMENT=INSTRUMENTS{I};
end




