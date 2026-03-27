%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Script for iterated learing
%
% If you use the script please cite:
% "Integer ratio priors on musical rhythm revealed cross-culturally by
% iterated reproduction" Nori Jacoby & Josh McDermott 2017
%
% For more information please contact: nori.viola@gmail.com
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear all;close all;clc; % "To begin at the beginning" (Under Milk Wood/Dylan Thomas)

%%% code not used in the main version that allows for the selection of
%%% tempo:
% tans=input('   TEMPO?   2000? 1000?: ');
% assert((tans==2000)||(tans==1000))
% TOT=tans;

TOT=2000; % setup the overall pattern duration to 2000 ms

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% set working dirs and sound card setup - YOU WILL NEED TO CHANGE THIS AREA OF THE CODE!
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%  CHANGE AREA START ---->  CHANGE HERE!
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Setup directories CHANGE THESE LINES ON EVERY NEW COMPUTER!!!
if ispc()  % IF YOU HAVE A PC CHANGE HERE!!
    PROGRAM_DIRECTORY='C:\Users\kelly\Dropbox\WORLD-FEB2018-ITER-EXPERIMENT\'; %you may want to change this this is where the main script is found - a sub directory of this need to be norilib
    DATA_DIRECTORY='C:\Users\kelly\Dropbox\WORLD-FEB2018-ITER-EXPERIMENT\data'; %you may want to change this this is where the data is found 
    SOUND_CARD='Focusrite USB ASIO'; % cell column is a list of optional, cell row is stereo with different names % for pc-2
    %%%% OTHER OPTIONS THAT WORKED ON OTHER COMPUTERS (DEPEND ON OPERTATING
    %%%% SYSTEM)
    %SOUND_CARD={'Focusrite USB (Focusrite USB Audio)';'Focusrite USB (Focusrite USB Au'}; % cell column is a list of optional, cell row is stereo with different names
    %SOUND_CARD='Focusrite USB (Focusrite USB Au'
    %SOUND_CARD='Focusrite USB (2- Focusrite USB Audio)'; %name of sound card
    %SOUND_CARD='Focusrite USB (Focusrite USB Au'; %name of sound card
    %SOUND_CARD='Focusrite USB (2- Focusrite USB';
     %DATA_DIRECTORY=sprintf('C:\Users\kelly\Dropbox\WORLD-FEB2018-ITER-EXPERIMENT\3intervals-%d',TOT);
    %%old version
    InitializePsychSound
else % MAC OR UNIX? CHANGE HERE!!!
    PROGRAM_DIRECTORY='~/ResearchMIT/CBMM/CMMMproj/WORLD-FEB2018-ITER-EXPERIMENT/'; %you may want to change this this is where the main script is found - a sub directory of this need to be norilib
    DATA_DIRECTORY='~/ResearchMIT/CBMM/CMMMproj/WORLD-FEB2018-ITER-EXPERIMENT/data';
    SOUND_CARD='Scarlett 2i2 USB '; %name of sound card
    
    %old version
     %DATA_DIRECTORY=sprintf('~/ResearchMIT/CBMM/CMMMproj/WORLD-FEB2018-ITER-EXPERIMENT/3intervals-%d',TOT);       %you may want to change this: data directory
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%  END OF CHANGE AREA....
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Initialize file directories:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
addpath(DATA_DIRECTORY)
addpath(genpath(PROGRAM_DIRECTORY))

rng('shuffle'); %in every experiment where random conditions are introduced in matlab this should be ON!
KbName('UnifyKeyNames');

% create result directory
fprintf('your current directory is: %s\n',pwd());
cd (DATA_DIRECTORY);
DATE_STRING=date();
EXPname=sprintf('EXPiter-%s',DATE_STRING);
mkdir(EXPname);cd (EXPname);

fprintf('Now in a new direcotry: %s\n',pwd());

%%% for debugging purposes: print all the audio devices. In case of an
%%% error you can use this output to locate sound cards names so that they
%%% can be used for the field: SOUND_CARD
fprintf('\nPrinting all audio devices:\n-------------------------------\n\n');
devs=PsychPortAudio('GetDevices');
for I=1:length(devs)
    fprintf('Show devices found ''%s'' as # %d \n',devs(I).DeviceName,I);
end
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Expeirment's parameters

SUBJn=get_subject_name(); %get subejct name
SUBJn=strrep(SUBJn,' ','');
fprintf('\n\n********************************************************************************\n');
fprintf('Iterative tapping - Jacoby and McDermott 2017\n');
Print_stat_participants(SUBJn);
fprintf('********************************************************************************\n');


%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Choose training or test. Run traing at least once

msg=sprintf('   (1) Train NOTE: tempo=%d  (3) Test NOTE: tempo=%d: ',TOT,TOT);
sans=input(msg);

% parameters that are different in train and test:
switch sans
    case 1 % train
        REPEAT=1; %number of feedback blocks
        REP=10;  %number of repetitions of the cycle
        GRANDITERs=5; %number of blocks run without break
        EXPres='EXPall.feb2018.nori-new.train'; %result file initials
        IS_PAUSE=false; %break between blocks (change it if you want more control on the session, though even in false you can stop by pressing the space bar)
        IS_TEST=false;
    case 3 %test new (with pause)
        REPEAT=5; %number of feedback blocks
        REP=10;  %number of iterations
        GRANDITERs=10; %number of blocks run without break
        EXPres='EXPall.feb2018.nori-new.test'; %result file initials
        IS_PAUSE=true; %break between blocks
        IS_TEST=true;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Global parameters
% parameters that are common to all cases
CLICKS=3;     %number of clicks (3 = 3 interval rhythms)
IS_NEW=false; % do not apply onset filtering (use this always!)
BEG=1;        %safety output silence
NUM_PTR=1;    % number of patterns (1 = one pattern at a time)
CHUNK=12203;  %extraction normalization length (ms)
TRUNC_TRESH=TOT*150/1000; %inner tirangle borders (in sec)
MAXPROXIMITY=TRUNC_TRESH/2; %defines the larggest possible error (in sec)
MIN_IRI=0.95*TRUNC_TRESH; %minum IRI that is ok for accepting trials, ISI of iteration will never be less than TRUNC_TRESH
%%PERCENT_NO_CHANGE=1/4; % number of trials that need to be good inorder to
%%change to this iterati (used in some versions 2016-2017)
PERCENT_NO_CHANGE=1/3; % number of trials that need to be good inorder to change to this iteration CHANGED BACK!!
MAX_do_not_chang=3; % maximum number of no change iterations within a block
PAUSE_BETWEEN_ITERATIONS=1.2;
PAUSE_BETWEEN_BLOCKS=3;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Onset extraction parameters
TRESH=[0.15,0.145]; %extraction thresholds ---> You might want to change here if you have a sound card different from Focusrite, this depend on the signal SNRs
SLEEP=[18,60];    %extraction parameters (time between onsets a)
SLEEPMIN=[26,80]; %min sleep time (time between onsets b )
simulated_NN=0; % number of simulation points (display only) This should be 0
fs=44100; %sampling rate of extraction
fs0=12000;%down sampled sampling rate (save data with less resolution to save disk space)
clicksound=calc_click(1,fs); % 1 for click 2 for beep.Change here if you want to change tembre
ISPLOT=true; %plot extraction !! (for debuging)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Actuall experiment

ALL=cell(NUM_PTR,1);  %container for data (but not for raw audio)
ALL2=cell(NUM_PTR,1); %container for recordings (raw audio)

%%% run multiple blocks
for GRANDITER=1:GRANDITERs
   
    tic % measure time
    UUID=randi(100000-10000-1)+10000; %randomize UUID for the output file
    fname=sprintf('%s.%s.ISI%d.iterations%d.REP%d.RND%d.mat',EXPres,SUBJn,TOT,REPEAT,REP,UUID); %save everything
    fname2=sprintf('SUMMARY.%s.%s.ISI%d.iterations%d.REP%d.RND%d.mat',EXPres,SUBJn,TOT,REPEAT,REP,UUID); % this is a shorter summary file with no audio
    fnameE=sprintf('WARNING.%s.%s.ISI%d.iterations%d.REP%d.RND%d.mat',EXPres,SUBJn,TOT,REPEAT,REP,UUID); % this is a warning file if we encounter large inaccuracies in the recorded (loop back) stimulus
    fnamep=sprintf('PIC.%s.%s.ISI%d.iterations%d.REP%d.RND%d.png',EXPres,SUBJn,TOT,REPEAT,REP,UUID); %save everything
    
    % error files should be sent to Nori for debugging purposes
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Initializing seeds (all pattern that are run in parallel
    for JJ=1:NUM_PTR
        ISIseed0=NITER_randomize_1threshold_point(CLICKS,TOT,TRUNC_TRESH); %randomize points
        ALL{JJ}.ISIseed0=ISIseed0; %initializing seed
        ALL{JJ}.ISIseed=ALL{JJ}.ISIseed0; %select seed
        
        ALL{JJ}.data=cell(REPEAT,1); % container for data within this pattern
        ALL2{JJ}.data=cell(REPEAT,1); % container for recording data within this pattern
        ALL{JJ}.cnt_do_not_change=0; %how many error iterations causes switching pattern without saving
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% run multiple iterations
    KKK=0;
    for KKK=1:REPEAT
        my_perm=randperm(NUM_PTR);
        for JJ=1:NUM_PTR   %%% in case patterns are running in parallel...
            J=my_perm(JJ);
            
            ALL{J}.is_do_not_change=false;%initially change!
            myREP=REP; %select number of cycles within a block
            
            ALL{J}.ISI=nan(1,CLICKS*myREP); %ISIs for all block
            for k=1:myREP
                ALL{J}.ISI((1:CLICKS)+(k-1)*CLICKS)=ALL{J}.ISIseed;
            end
            AMP=ones(size(ALL{J}.ISI)); % amplitudes for synthesis
            
            [~,myaudio]=STIMfromISIamp(fs,ALL{J}.ISI,AMP,clicksound); %sound synthesis
            
            verbosity_recording=-1; % eventually: for test runs
            %verbosity_recording=2.5; % for debuging in the begining...
            %verbosity_recording=5; % will follow recorind in real time
            %(debuggin purposes)
            rec=nori_do_play_record_macpc4(0.9*myaudio/max(myaudio(:)),fs,SOUND_CARD,verbosity_recording,BEG);%%record audio mac
            %rec=nori_do_play_record(0.9*myaudio/max(myaudio),fs,SOUND_CARD,verbosity_recording,BEG);%%older
            %versions
            %%
            
            % clean some of the noise if the recording level is too low,
            % also remove DC component with very strong taps
            
            d = designfilt('bandpassiir','FilterOrder',10, 'HalfPowerFrequency1',10,'HalfPowerFrequency2',180, 'SampleRate',fs0);
            recD=resample(rec,fs0,fs); %downsample
            
            % remove filtering artifacts from the begining and ending of the recording
            recDf=recD;recDf(:,2)= filtfilt(d,recD(:,2));fadein=linspace(0, 1, 1+round(350/1000*fs0)).^2;
            fadeout=fadein(end:(-1):1);
            recDf(1:length(fadein),2)=recDf(1:length(fadein),2).*[fadein'];
            recDf((end-length(fadein)+1):end,2)=recDf((end-length(fadein)+1):end,2).*[fadeout'];
            
            %%% analyze tapping data
            figure(10);clf;subplot(2,2,2);
            [Sr,Rr]=LongAnalyzeCleanSoundsDivideStereoVIEWALL(recDf,fs0,TRESH,SLEEP,SLEEPMIN,CHUNK,ISPLOT); %extract onsets
            
            
            %%
            
            % check that the extracted onsetes mataches the "ideal" template,
            % allow not more than 10 ms difference. This is a sanity check used
            % mainly to make sure data collection is ok.
            MAXproxS=min(ALL{J}.ISI)/2; %used to be:  MAXproxS=min(ISI)/2; %this is just for ideal stimulus
            Sideal=Sr(1)+cumsum([0,ALL{J}.ISI]);
            [Sideal2,~,~,~,~,sideal2,eideal2]=RawTapstoTaps4(Sideal,Sr,MAXproxS);
            
            
            %%% Check alignment of the stimulus and loopback stimulus, save warning file
            %%% Print meanigful error if there seems to be a problem.
            if max(abs(eideal2))>10
                fprintf('Saving WARNING file to: %s\n',fnameE)
                save(fnameE)
                fprintf('WARNING, big deviation from loopback accuracy (%3.3f msec)\n Saving warning to file: %s\n I will try to go on...\n',max(abs(eideal2)),fnameE)
            end
            if ((max(abs(eideal2))>15)||(sum(isnan(eideal2))>=(length(Sideal)/2)))
                fprintf('Saving WARNING file to: %s\n',fnameE)
                save(fnameE)
                fprintf('\nERROR because of a deviation from loopback accuracy (maximal error: %3.3f msec, number of errors %d)\n This is probably because the loop cable is not connected properley. Please check connections!!\n PC computers might have this error sometimes due to timing issues, if this is the case send the warning file to Nori\n',max(abs(eideal2)),length(Sideal))
            end
            assert( (max(abs(eideal2))<15) && ((sum(isnan(eideal2))<(length(Sideal)/2))) ); % even though we allow a bit of an error (due to rare issue on Rainer's computer) we don't allow more inaccuacies larger than 15 msec
            % note that an error here means probably that the computer is
            % not connected correctly
            
            
            % aligments of extracted onsets
            % find mean asynchrony, shift data by mean async and apply
            % alignment criteria (same for all trials) shift back...
            [~,~,~,~,~,~,e]=RawTapstoTaps4(Sideal2-Sideal2(1),Rr-Sideal2(1),MAXPROXIMITY); % apply a conservative critertion
            mean_async=mean(e(~isnan(e))); % compute mean asynchorny
            [R,S,W,L,s,r,e]=RawTapstoTaps4(Sideal2-Sideal2(1),Rr-Sideal2(1)-mean_async,MAXPROXIMITY); % recompute onsets cnaceling out mean async.
            R=R+mean_async; %removing mean async shift
            e=e+mean_async; %removing mean async shift
            
            
            % reorder onsets as a matrix
            Sm=nan(myREP,CLICKS+1);
            Cm=nan(myREP,CLICKS+1);
            Rm=nan(myREP,CLICKS+1);
            for k=1:myREP
                for j=1:(CLICKS+1)
                    Sm(k,j)=S(j+(k-1)*CLICKS)-S(1+(k-1)*CLICKS);
                    Cm(k,j)=k;
                    Rm(k,j)=R(j+(k-1)*CLICKS)-S(1+(k-1)*CLICKS);
                end
            end
            
            % do NOT apply this correction, it was found to be less good
            % for participants that have hard time tapping.
            % It does not do much anyhow for good participants
            RmOLD=Rm;
            if IS_NEW
                npos=isnan(sum(Rm,2));
                Rm(npos,:)=nan;
            end
            
             %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Average across repetition and make sure data is OK
            % average across repetition to find average pattern
            RM=nan(1,CLICKS+1);
            for j=1:(CLICKS+1)
                vec=Rm(:,j);
                vec=vec(~isnan(vec));
                
                
                % if there are two many missing point - do not change!
                if length(vec)<myREP*PERCENT_NO_CHANGE
                    vec=Sm(:,j);
                    ALL{J}.is_do_not_change=true;%###
                end
                RM(j)=mean(vec);
            end
            SM=cumsum([0,ALL{J}.ISIseed]);
            
              %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
              %Filter bad iterations...
              
            % if there is a two short interval (out of the triangle) - do not change!
            if min(diff(RM))<MIN_IRI   %if min(diff(RM))<0.8*TRUNC_TRESH
                ALL{J}.is_do_not_change=true;%###
            end
            
            % Display change or do not change ? 
            if ALL{J}.is_do_not_change % do not change seed
                fprintf('ISIseed is not changed');
                ALL{J}.cnt_do_not_change=ALL{J}.cnt_do_not_change+1;
                msgN=sprintf('failed (!)...trying again...[%d|%d %d|%d]',KKK,REPEAT,GRANDITER,GRANDITERs);
            else % udate seed
                ALL{J}.ISIseed=diff(RM);
                ALL{J}.ISIseed=max( ALL{J}.ISIseed,TRUNC_TRESH); %%NOTE HERE! (Project to the inside of the triangle)
                ALL{J}.ISIseed=TOT* ALL{J}.ISIseed/sum( ALL{J}.ISIseed); %%NEW FROM VERSIONS OF OCT2015 keep total ISI fixed
                
                msgN=sprintf('trial ok! [%d|%d %d|%d]',KKK,REPEAT,GRANDITER,GRANDITERs);
            end
            %%
            % store data:
            ALL{J}.data{KKK}.S=S;
            ALL{J}.data{KKK}.Sr=Sr;
            ALL{J}.data{KKK}.Rr=Rr;
            ALL{J}.data{KKK}.Sideal2=Sideal2;
            ALL{J}.data{KKK}.R=R;
            ALL{J}.data{KKK}.s=s;
            ALL{J}.data{KKK}.r=r;
            ALL{J}.data{KKK}.e=e;
            ALL{J}.data{KKK}.W=W;
            ALL{J}.data{KKK}.Sm=Sm;
            ALL{J}.data{KKK}.Rm=Rm;
            ALL{J}.data{KKK}.RmOLD=RmOLD;
            ALL{J}.data{KKK}.Cm=Cm;
            ALL{J}.data{KKK}.RM=RM;
            ALL{J}.data{KKK}.SM=SM;
            ALL{J}.data{KKK}.time_finish=datestr(now);
            
            ALL2{J}.data{KKK}.recD=recD;
            ALL2{J}.data{KKK}.recDf=recDf;
            ALL{J}.data{KKK}.myREP=myREP;
            ALL{J}.data{KKK}.REP=REP;
            ALL{J}.data{KKK}.REPEAT=REPEAT;
            ALL{J}.data{KKK}.TRUNC_TRESH=TRUNC_TRESH;
            ALL{J}.data{KKK}.fname=fname;
            ALL{J}.data{KKK}.TOT=TOT;
            ALL{J}.data{KKK}.TRUNC_TRESH=TRUNC_TRESH;
            ALL{J}.data{KKK}.ISIseed0= ALL{J}.ISIseed0;
            ALL{J}.data{KKK}.is_do_not_change=ALL{J}.is_do_not_change;
            
            % store parameters:
            PARAM=[];
            PARAM.TRUNC_TRESH=TRUNC_TRESH;
            PARAM.MAXPROXIMITY=MAXPROXIMITY;
            PARAM.REPEAT=REPEAT;
            PARAM.MIN_IRI=MIN_IRI;
            PARAM.CLICKS=CLICKS;
            PARAM.PERCENT_NO_CHANGE=PERCENT_NO_CHANGE;
            PARAM.REP=REP;
            PARAM.NUM_PTR=NUM_PTR;
            PARAM.GRANDITERs=GRANDITERs;
            PARAM.IS_NEW=IS_NEW;
            PARAM.BEG=BEG;
            PARAM.CHUNK=CHUNK;
            PARAM.IS_PAUSE=IS_PAUSE;
            PARAM.SLEEP=SLEEP;
            PARAM.SLEEPMIN=SLEEPMIN;
            PARAM.TRESH=TRESH;
            PARAM.ISPC=ispc();
            PARAM.fs=fs;
            PARAM.fs0=fs0;
            PARAM.SUBJn=SUBJn;
            PARAM.TIME_FINISH=datestr(now);
            PARAM.DATA_DIRECTORY=DATA_DIRECTORY;
            PARAM.PROGRAM_DIRECTORY=PROGRAM_DIRECTORY;
            PARAM.SOUND_CARD=SOUND_CARD;
            PARAM.IS_TEST=IS_TEST;
            PARAM.EXPname=EXPname;
            PARAM.PAUSE_BETWEEN_BLOCKS=PAUSE_BETWEEN_BLOCKS;
            PARAM.PAUSE_BETWEEN_ITERATIONS = PAUSE_BETWEEN_ITERATIONS;
            PARAM.MAX_do_not_chang=MAX_do_not_chang;
            PARAM2=PARAM;
            PARAM2.clicksound=clicksound;
            PARAM2.devs=devs;
            
            
            ALL{J}.PARAM=PARAM;
            ALL2{J}.PARAM=PARAM2;
            
            %%
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Visualization:  monitor data acquisition
            %monitor data acquisition
            %figure(11);clf;set
            %(gcf,'units','normalized','outerposition',[0 0 1
            %1]);NITER_plot_patterns_2018(  ALL,KKK,msgN,0); Visualize
            %triangle only (not needed)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Do visualization of triangle and data
            figure(10);set (gcf,'units','normalized','outerposition',[0 0 1 1]);NITER_plot3_progress_2018(ALL,KKK,J,msgN);
            drawnow;
            
            
        end
        pause (PAUSE_BETWEEN_ITERATIONS);
        % skip this block, there is no point to collect more data, too
        % many mistakes...
        %make the skip only if running one pattern otherwise this is
        %problematic becuase we need to take care of other patterns.
        if (NUM_PTR==1) && (ALL{J}.cnt_do_not_change>=MAX_do_not_chang)
            fprintf('skipping because too many mistakes, goint to next block...\n');
            break
        end
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% saving data:
    tREPEAT=KKK;
    fprintf('saving to directory: %s\n',pwd())
    save(fname);
    save(fname2,'ALL');
    print(10, '-dpng', fnamep); % save png file
    fprintf('Time to run one block (%d of %d):\n',GRANDITER,GRANDITERs)
    toc
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Display information about the subject (may be useful when restarting)
    fprintf(' current pwd %s\n',pwd())
    fprintf('\n\n********************************************************************************\n');
    fprintf('Now in block %d of %d\n',GRANDITER,GRANDITERs);
    Print_stat_participants(SUBJn);
    fprintf('********************************************************************************\n');
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% Pause between blocks
    if IS_PAUSE
        commandwindow
        fprintf('Press ENTER to continue\n');
        pause
    else
        fprintf('\n\n--> You have now %g seconds to pause...\n',PAUSE_BETWEEN_BLOCKS);
        PauseDialog(PAUSE_BETWEEN_BLOCKS)
        
    end
    figure(10);
end
%%
fprintf('DONE!!\n'); %finally...
commandwindow
