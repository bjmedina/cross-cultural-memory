function P=SYNTH_prepare_sample_bank(P,root_sample_dir,IS_PLAY_SOUNDS,fs0)
%%% global parameters:
% root_sample_dir='~/researchM/Justin/2017IEMP/Jembe-samples';
%root_sample_dir='~/researchM/Justin/2017IEMP/Stambeli-samples';
%IS_PLAY_SOUNDS=false;
% fs0=44100; % make sure everything is in the same sampling rate



% set up patterns and notes
if contains(root_sample_dir,'Jembe')
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


if contains(root_sample_dir,'Stambeli-samples')
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
    %                    G                     Ab              C               D                E       Gh
    %                                                                          D                E       Gh
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

if contains(root_sample_dir,'Candombe')
    fprintf('Found Candombe  Samples[15-MAR-2017]\n');

    CLAVE_patterns = {'repique_madera*wav'};
    CLAVE_notes=[177];

    CHICO_patterns={'chico_S*wav','chico_H*wav','chico_m*wav','chico_R*wav'};
    CHICO_notes=[271,   260      , 277  ,272];

    PIANO_patterns={'piano_m*wav','piano_SO*wav','piano_SP*wav','piano_SC*wav','piano_HS*wav','piano_HO*wav','piano_HC*wav'};
    PIANO_notes=[377,371,369,367,365,360,362];

    REPIQUE_patterns={'repique_S*wav','repique_H*wav','repique_SP*wav','repique_R*wav'};
    REPIQUE_notes=[471,460,469,472];


    INSTRUMENTS=cell(1,4);

    INSTRUMENTS{1}.name='clave';
    INSTRUMENTS{1}.notes=CLAVE_notes;
    INSTRUMENTS{1}.patterns=CLAVE_patterns;

    INSTRUMENTS{2}.name='chico';
    INSTRUMENTS{2}.notes=CHICO_notes;
    INSTRUMENTS{2}.patterns=CHICO_patterns;


    INSTRUMENTS{3}.name='piano';
    INSTRUMENTS{3}.notes=PIANO_notes;
    INSTRUMENTS{3}.patterns=PIANO_patterns;

    INSTRUMENTS{4}.name='repique';
    INSTRUMENTS{4}.notes=REPIQUE_notes;
    INSTRUMENTS{4}.patterns=REPIQUE_patterns;

    MAX_NUM=28;
end

if contains(root_sample_dir,'Jazz')
    fprintf('Found synthesizer Jazz[1-JULY-2017]\n');
    SNARE_PATTERN_21='snare*.wav';

    SNARE_notes=[21];
    SNARE_patterns={SNARE_PATTERN_21};


    HIHAT_PATTERN_31='Hi*.wav';
    HIHAT_notes=[31];
    HIHAT_patterns={HIHAT_PATTERN_31};


    RIDE_PATTERN_41='sflat*ride*wav';
    RIDE_notes=[41];
    RIDE_patterns={RIDE_PATTERN_41};

    BASS_PATTERN_110='Ex_01*- 1.wav';
    BASS_PATTERN_120='Ex_01*- 2.wav';
    BASS_PATTERN_131='Ex_01*- 3-1.wav';
    BASS_PATTERN_132='Ex_01*- 3-2.wav';
    BASS_PATTERN_140='Ex_01*- 4.wav';
    BASS_PATTERN_151='Ex_01*- 5-1.wav';
    BASS_PATTERN_152='Ex_01*- 5-2.wav';
    BASS_PATTERN_160='Ex_01*- 6.wav';
    BASS_PATTERN_170='Ex_01*- 7.wav';
    BASS_PATTERN_180='Ex_01*- 8.wav';

    %     BASS_PATTERN_210='Ex_02*- 1.wav';
    %     BASS_PATTERN_220='Ex_02*- 2.wav';
    %     BASS_PATTERN_230='Ex_02*- 3.wav';
    %     BASS_PATTERN_241='Ex_02*- 4-1.wav';
    %     BASS_PATTERN_242='Ex_02*- 4-2.wav';
    %     BASS_PATTERN_250='Ex_02*- 5.wav';
    %     BASS_PATTERN_260='Ex_02*- 6.wav';
    %     BASS_PATTERN_271='Ex_02*- 7-1.wav';
    %     BASS_PATTERN_272='Ex_02*- 7-2.wav';
    %     BASS_PATTERN_280='Ex_02*- 8.wav';

%     BASS_notes=[110,120,131,132,140,151,152,160,170,180,   210,220,230,241,242,250,260,271,272,280];
%     BASS_patterns={BASS_PATTERN_110,BASS_PATTERN_120,BASS_PATTERN_131,BASS_PATTERN_132,BASS_PATTERN_140,BASS_PATTERN_151,BASS_PATTERN_152,BASS_PATTERN_160,BASS_PATTERN_170,BASS_PATTERN_180,...
%         BASS_PATTERN_210,BASS_PATTERN_220,BASS_PATTERN_230,BASS_PATTERN_241,BASS_PATTERN_242,BASS_PATTERN_250,BASS_PATTERN_260,BASS_PATTERN_271,BASS_PATTERN_272,BASS_PATTERN_280};
%
    BASS_PATTERN_310='ex_2_b_01.wav';
    BASS_PATTERN_320='ex_2_b_02.wav';
    BASS_PATTERN_330='ex_2_b_03.wav';
    BASS_PATTERN_340='ex_2_b_04.wav';
    BASS_PATTERN_351='ex_2_b_5-1.wav';
    BASS_PATTERN_352='ex_2_b_5-2.wav';
    BASS_PATTERN_360='ex_2_b_6.wav';
    BASS_PATTERN_371='ex_2_b_7-1.wav';
    BASS_PATTERN_372='ex_2_b_7-2.wav';
    BASS_PATTERN_380='ex_2_b_8.wav';


    BASS_notes=[110,120,131,132,140,151,152,160,170,180,        310,320,330,340,351,352,360,371,372,380];
    BASS_patterns={BASS_PATTERN_110,BASS_PATTERN_120,BASS_PATTERN_131,BASS_PATTERN_132,BASS_PATTERN_140,BASS_PATTERN_151,BASS_PATTERN_152,BASS_PATTERN_160,BASS_PATTERN_170,BASS_PATTERN_180,...
        BASS_PATTERN_310,BASS_PATTERN_320,BASS_PATTERN_330,BASS_PATTERN_340,BASS_PATTERN_351,BASS_PATTERN_352,BASS_PATTERN_360,BASS_PATTERN_371,BASS_PATTERN_372,BASS_PATTERN_380};


    INSTRUMENTS=cell(1,4);

    INSTRUMENTS{1}.name='Snare';
    INSTRUMENTS{1}.notes=SNARE_notes;
    INSTRUMENTS{1}.patterns=SNARE_patterns;

    INSTRUMENTS{2}.name='Hihat';
    INSTRUMENTS{2}.notes=HIHAT_notes;
    INSTRUMENTS{2}.patterns=HIHAT_patterns;

    INSTRUMENTS{3}.name='Ride';
    INSTRUMENTS{3}.notes=RIDE_notes;
    INSTRUMENTS{3}.patterns=RIDE_patterns;


    INSTRUMENTS{4}.name='Bass';
    INSTRUMENTS{4}.notes=BASS_notes;
    INSTRUMENTS{4}.patterns=BASS_patterns;
    MAX_NUM=20;
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

        fname_pat;
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
            if size(y,2)==2
                y=sum(y,2);
                %assert(1==0)
            end
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


