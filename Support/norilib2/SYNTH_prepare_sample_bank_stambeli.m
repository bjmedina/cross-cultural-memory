function P=SYNTH_prepare_sample_bank_stambeli(P,root_sample_dir,IS_PLAY_SOUNDS,fs0)
%%% global parameters:
% root_sample_dir='~/researchM/Justin/2017IEMP/Jembe-samples';
root_sample_dir='~/researchM/Justin/2017IEMP/Stambeli-samples';
IS_PLAY_SOUNDS=false;
 fs0=44100; % make sure everything is in the same sampling rate



% set up patterns and notes
if strcmp(root_sample_dir,'~/researchM/Justin/2017IEMP/Jembe-samples')
    fprintf('Found synthesizer Jembe[29-JAN-2017]\n');
    JEMBE2_PATTERN_51='*Tone*.wav';
    JEMBE2_PATTERN_52='*Slap*.wav';
    JEMBE2_PATTERN_53='*Bass*.wav';
    JEMBE2_notes=[51,52,53];
    JEMBE2_patterns={JEMBE2_PATTERN_51,JEMBE2_PATTERN_52,JEMBE2_PATTERN_53};
    
    
    DUNDUN1_PATTERN_61='*open*.wav';
    DUNDUN1_PATTERN_62='*closed*.wav';
    DUNDUN1_notes=[61,62];
    DUNDUN1_patterns={DUNDUN1_PATTERN_61,DUNDUN1_PATTERN_62};
    
    
    JEMBE1_PATTERN_71='*Tone*.wav';
    JEMBE1_PATTERN_72='*Slap*.wav';
    JEMBE1_PATTERN_73='*Bass*.wav';
    JEMBE1_notes=[71,72,73];
    JEMBE1_patterns={JEMBE1_PATTERN_71,JEMBE1_PATTERN_72,JEMBE1_PATTERN_73};
    
    INSTRUMENTS=cell(1,3);
    
    INSTRUMENTS{1}.name='Jembe-2';
    INSTRUMENTS{1}.notes=JEMBE2_notes;
    INSTRUMENTS{1}.patterns=JEMBE2_patterns;
    
    INSTRUMENTS{2}.name='Dundun';
    INSTRUMENTS{2}.notes=DUNDUN1_notes;
    INSTRUMENTS{2}.patterns=DUNDUN1_patterns;
    
    INSTRUMENTS{3}.name='Jembe-1';
    INSTRUMENTS{3}.notes=JEMBE1_notes;
    INSTRUMENTS{3}.patterns=JEMBE1_patterns;
    MAX_NUM=12;
end


if strcmp(root_sample_dir,'~/researchM/Justin/2017IEMP/Stambeli-samples')
    fprintf('Found Stambeli Samples[11-MAR-2017]\n');
    SHQASHIQ_PATTERN_51='*downbeat*.wav';
    SHQASHIQ_PATTERN_52='*upbeat*.wav';
    SHQASHIQ_notes=[51,52];
    SHQASHIQ_patterns={SHQASHIQ_PATTERN_51,SHQASHIQ_PATTERN_52};
    
    GUNBRI_patterns={'1*G down.wav','2*G down skin.wav','3*G up.wav', '4*G octaves down.wav','5*G octaves up.wav' ,...
    '6*Ab.wav' ,'7*Gumbri Ab skin.wav'  ,'8*Ab hammer.wav' ,...
    '9*C.wav'         ,'10*C skin.wav', '11*C pulloff from D.wav', '12*C left pluck.wav' , ...
    '13*D.wav' , '14*D skin.wav'  , '15*D hammer.wav' , ...
    '16*E.wav'   ,    '17*E skin.wav', ...
    '18*high G.wav'};
    
    GUMBRI_notes=[167,267,367,467,567,    168, 268,368,   172, 272,372,472,   174,274,374,   176,276,  179];
    
    
    
   
    INSTRUMENTS=cell(1,2);
    
    INSTRUMENTS{1}.name='Shqashiq';
    INSTRUMENTS{1}.notes=SHQASHIQ_notes;
    INSTRUMENTS{1}.patterns=SHQASHIQ_patterns;
    
    INSTRUMENTS{2}.name='Gumbri';
    INSTRUMENTS{2}.notes=GUMBRI_notes;
    INSTRUMENTS{2}.patterns=GUNBRI_patterns;
    MAX_NUM=18;
end

fprintf('root-dir: %s\n',root_sample_dir)
cd (root_sample_dir);
for I=1:length(INSTRUMENTS)
    INSTRUMENTS{I}.pattern_files=cell(size(INSTRUMENTS{I}.notes));
    INSTRUMENTS{I}.patterns_codes=cell(size(INSTRUMENTS{I}.patterns));
    for J=1:length(INSTRUMENTS{I}.notes)
        fname_pat=sprintf('%s/%s',INSTRUMENTS{I}.name,INSTRUMENTS{I}.patterns{J});
        
        
            pattern_code=INSTRUMENTS{I}.patterns{J};
            pattern_code=strrep(pattern_code,'*','');
            pattern_code=strrep(pattern_code,'.wav','');
            pattern_code=strrep(pattern_code,' ','');
            pattern_code=strrep(pattern_code,'_','');
            INSTRUMENTS{I}.patterns_codes{J}=pattern_code;
            
            
        a=dir(fname_pat);
        assert(length(a)>0);
        INSTRUMENTS{I}.pattern_files{J}.files=cell(size(a));
        INSTRUMENTS{I}.pattern_files{J}.wavs=cell(size(a));
        fprintf('Instrument name= %s\t note %3d  pattern %s [%s]\n',INSTRUMENTS{I}.name, INSTRUMENTS{I}.notes(J),INSTRUMENTS{I}.patterns{J},INSTRUMENTS{I}.patterns_codes{J});
        for K=1:length(INSTRUMENTS{I}.pattern_files{J}.files)
            fname_wav=sprintf('%s/%s/%s',root_sample_dir,INSTRUMENTS{I}.name,a(K).name);
            code=a(K).name;
            code=strrep(code,'.wav','');
            code=strrep(code,' ','-');
            code=strrep(code,'_','-');
            code=strrep(code,'---','-');
            code=strrep(code,'--','-');
            
            
            INSTRUMENTS{I}.pattern_files{J}.files{K}=fname_wav;
            INSTRUMENTS{I}.pattern_files{J}.codes{K}=code;
            [y,fs]=audioread(fname_wav);
            INSTRUMENTS{I}.pattern_files{J}.wavs{K}=y;
            
            fprintf('\tLoading file: %s duration %g (ms) fs= %d\n',fname_wav,1000*length(y)/fs,fs)
            assert(fs==fs0);
        end
    end
end



if IS_PLAY_SOUNDS
    figure(1);clf;
end
fprintf('\nValidating files...\n');
% print instrument content:

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
            cnt=cnt+1;
            if IS_PLAY_SOUNDS
                fprintf('\t \t \t \t %s\t [%s]\n',INSTRUMENTS{I}.pattern_files{J}.files{K},INSTRUMENTS{I}.pattern_files{J}.codes{K});
            end
            assert(~isempty(dir(INSTRUMENTS{I}.pattern_files{J}.files{K})));
            
            if IS_PLAY_SOUNDS
                %subplot_tight(length(INSTRUMENTS),MAX_NUM,(I-1)*MAX_NUM + (J-1)*length(INSTRUMENTS{I}.pattern_files{J}.files)+K)
                subplot_tight(length(INSTRUMENTS),MAX_NUM,(I-1)*MAX_NUM + cnt)
                %subplot(length(INSTRUMENTS),MAX_NUM,(I-1)*MAX_NUM + (J-1)*length(INSTRUMENTS{I}.pattern_files{J}.files)+K);
                
                plot(1000*(1:length(INSTRUMENTS{I}.pattern_files{J}.wavs{K}))/fs0,INSTRUMENTS{I}.pattern_files{J}.wavs{K},'Color',mclr);
                
                msg=sprintf('%s [%3d]\n%s\n%s',INSTRUMENTS{I}.name, INSTRUMENTS{I}.notes(J),INSTRUMENTS{I}.patterns_codes{J},INSTRUMENTS{I}.pattern_files{J}.codes{K});
                %msg=sprintf('%s',INSTRUMENTS{I}.pattern_files{J}.codes{K});
               
                h=title(msg);
                set(h,'FontSize',6);
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
fprintf('Files OK!\n');
P.INSTRUMENTS=INSTRUMENTS;

fprintf('Making midi map list (map each midi note to a sample)...\n');
MAPPER=cell(1270,1);
for I=1:length(INSTRUMENTS)
    for J=1:length(INSTRUMENTS{I}.notes)
        note=INSTRUMENTS{I}.notes(J);
        assert(isempty(MAPPER{note}));
        %MAPPER{note}.samples=cell(length(INSTRUMENTS{I}.pattern_files{J}.files));
        MAPPER{note}.files=cell(length(INSTRUMENTS{I}.pattern_files{J}.files));
        
        for K=1:length(INSTRUMENTS{I}.pattern_files{J}.files)
            MAPPER{note}.files{K}=INSTRUMENTS{I}.pattern_files{J}.files{K};
            MAPPER{note}.codes{K}=INSTRUMENTS{I}.pattern_files{J}.codes{K};
            MAPPER{note}.wavs{K} =INSTRUMENTS{I}.pattern_files{J}.wavs{K};
        end
    end
end

P.MAPPER=MAPPER;
P.fs0=fs0;


