%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Singing experiment code Jacoby and McDermott, in prep...         %%%%
%%% For questions ask: nori.viola@gmail.com %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all;close all;clc % "To begin at the beginning" (Under Milk Wood/Dylan Thomas)

% these are folders included in Nori's code based, they are replaced by a
% single call to the norilib folder.
% addpath('~/ResearchMIT/toolboxes/Sound_Texture_Synthesis_Toolbox/');
% addpath('~/ResearchMIT/toolboxes/SYNTH');
% addpath('~/ResearchMIT/toolboxes/create_tap_stim');
% addpath('~/ResearchMIT/toolboxes/PITCH')
% addpath('~/ResearchMIT/toolboxes/PITCH/yin')
% addpath('~/ResearchMIT/toolboxes/oUTIL/');
% addpath('~/ResearchMIT/toolboxes/nUTIL/');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% set working dirs and sond card setup - YOU WILL NEED TO CHANGE THIS AREA OF THE CODE!
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%  CHANGE AREA START ---->  CHANGE HERE!
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% main experiment code and data path (you should set this!)
ROOT_DIRECOTRY= '/Users/jacoby/Dropbox (Holden)/mcdexp-jacoby/Singing-7feb2018/'; %direcotry of scripts (root)
LIB_DIRECOTRY='/Users/jacoby/Dropbox (Holden)/mcdexp-jacoby/Singing-7feb2018/norilib/'; %direcotry of scripts (usually would be root/norilib)

addpath(ROOT_DIRECOTRY);
addpath(LIB_DIRECOTRY);
% sound card setup (need to be changed if run withhout sound card)
DEV='Scarlett 2i2 USB';
DEVin=DEV;
DEVout=DEV;
% If you want to try the experiment without a sound card (simply with your
% mac), this can work with a PC too but need to find the internalize sound
% card name from the output of: nori_scan_soundcards();
DEVin='Built-in Microph';
DEVout='Built-in Output';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%  END OF CHANGE AREA....
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf('Print Sound Cards:\n');
fprintf('------------------------------------------------------------\n');
nori_scan_soundcards(); % this prints all audio devices. In case you want to use a different sound card you can use the output of this function to locate all sound cards
fprintf('------------------------------------------------------------\n');


fprintf('Now in a new direcotry: %s\n',pwd());

rng('shuffle'); %this should be in any matlab script since otherwise Matlab may not realy randomize things!!!
%%% also usefull to make sure sound card is connected
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Global default parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
FREQ_MIN=60; % defines a lower and higher limit on presented sounds
FREQ_MAX=11500;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Sound synthesis parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% synth params
P=[];
P.atk=50;
P.dec=50;
P.v=[1,0,0,0,0];%P.v=[16,0,8,0,4,0,2,0,1]; % pure tone
%P.v=[16,8,4,2,1];%P.v=[16,0,8,0,4,0,2,0,1];
SYNTH=@SYNTH_make_note_aditive_db;
%P.isi=400;P.vel=120;P.dur=350;
P.isi=8000;P.vel=100;P.dur=7900;
%%%P.isi=800;P.vel=100;P.dur=790;
%P.headphone_code=headphone_code;
P.SYNTH=SYNTH;
Ps=P;
fs=44100;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Gender dependent paramters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% get subject name, type of experiment and gender
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%SUBJn=get_subject_name(); %get subejct name
%[SUBJn,gender]=get_subject_name_last(LAST_FNAME);
SUBJn='xxxx';
gender=2;
switch gender
    case 1 %female
        TONE_LOWEST=55; % singing range
        TONE_HIGHEST=72;% singing range
        %TONE_LOWEST=53;  % used in the past
        %TONE_HIGHEST=70; % used in the past
        TONE_MID=(TONE_HIGHEST+TONE_LOWEST)/2; % middle of the singing range (most comfortable)
        TONE_HIGH_MARGIN=9; % defines the highest possible tone (importnat for pitch extraction)
        IS_MALE=false; %females are not males.
        
    case 2 %male
        TONE_LOWEST=43;% singing range
        TONE_HIGHEST=60;% singing range
        % TONE_LOWEST=41; % used in the past
        %TONE_HIGHEST=58; % used in the past
        TONE_HIGH_MARGIN=9; % defines the highest possible tone (importnat for pitch extraction)
        TONE_MID=(TONE_HIGHEST+TONE_LOWEST)/2;% middle of the singing range (most comfortable)
        IS_MALE=true; % record gender for analysis
end
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% print menue and data for Boliva 2017
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

msg=cell(5,1);

fprintf('Play ranges (Bolivia 2017)\n-------------------------------------------------------------------------------\n');


fprintf('\n');

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Get input from participant and start experiments...
%%% this contains a long list of parameter setups
%%% for the different inputs
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


        
    
        fprintf('3 \t High tones  \n-----------------------------------------------------\n')
        fprintf('\tExperimenter:Explain again to participants that there might be high tones\n');
        fprintf('\nPress ENTER to continue...\n\n');
        
        pause
        COND='test-3-high-tones';
        if IS_MALE
            octaves=[-1,0,1,2,3,4,5,6];
        else
            octaves=[-2,-1,0,1,2,3,4,5];
        end
        intervals=[0]; %-2..2 tsimane pilot 17jul17 % 18 jul change to -3:3
        BASE_TONE_RANGE=[TONE_MID-2.5,TONE_MID+2.5];
        REPEATtimes=4;
        MIN_TRIALS_WITH_2_NOTES=2;
        
        IS_RANDOMIZE_ORDER_OCTAVES=false;
        IS_RANDOMIZE_ORDER_INTERVALS=false;
        MAX_DIFF_ACCEPTABLE=999;
        IS_PAUSE_BLOCK=true;
        IS_PAUSE_TRIALS=true;
        REPEATtimes=1;





%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% initialize basic variables
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

NTONES=2; % number of tones
NI=length(intervals); % number of intervals
NK=length(octaves); % number of registers (octaves)
NR=REPEATtimes; % maximal number of sequential repetition of each melody


UUID=randi(10000-1000)+1000; % used to save experiments

ISPLOT=true;
RECDUR_FACTOR=1.5; % this determined the length of the recording relative to the length of the audio file.
TDUR=NTONES*P.isi*RECDUR_FACTOR/1000; % this is for display purpose (estimated stimulus duration)

%%

%%% Document parameters in the PARAMETER structure.
PARAMS.NTONES=NTONES;
PARAMS.IS_MALE=IS_MALE;
PARAMS.fs=fs;
PARAMS.RECDUR_FACTOR=RECDUR_FACTOR;
PARAMS.TONE_LOWEST=TONE_LOWEST;
PARAMS.TONE_HIGHEST=TONE_HIGHEST;
PARAMS.synthP=P;
PARAMS.time_start=datetime('now');
PARAMS.TONE_MID=TONE_MID;
PARAMS.intervals=intervals;
PARAMS.octaves=octaves;
PARAMS.BASE_TONE_RANGE=BASE_TONE_RANGE;
PARAMS.COND=COND;
PARAMS.IS_RANDOMIZE_ORDER_OCTAVES=IS_RANDOMIZE_ORDER_OCTAVES;
PARAMS.IS_RANDOMIZE_ORDER_INTERVALS=IS_RANDOMIZE_ORDER_INTERVALS;
PARAMS.NI=NI;
PARAMS.NK=NK;

%%%%%%%%% Get amplitude for all octaves %%%%%%%%%%%%%%%
%%% This function was hand tuned
%%% You will need to change this for different type of sounds
%%% For example
vels=vels_for_octave_db(octaves,IS_MALE);
PARAMS.vels=vels;



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Doing the experiment
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
commandwindow
tic

RES= cell(NR,NK,NI); %% JJ/NR (repetitions), KK/NK (octaves), II/NI (intervals)
ARES=cell(NR,NK,NI); %% audio container JJ/NR (repetitions), KK/NK (octaves), II/NI (intervals)

% randomize of not the order of registers
if IS_RANDOMIZE_ORDER_OCTAVES
    perm_octave=randperm(NK);
else
    perm_octave=1:NK;
end
cnt=0; %counter of attempts

%%
figure(3);clf;figure(2);clf; % for display of monitoring information

for KK=1:NK
    K=perm_octave(KK); % select a register from register list
    octave=octaves(K); % octave shift
    msg2=sprintf('now in octave %d of %d [octave(%d) =%d]', KK,NK,K,octave);
    fprintf('%s\n',msg2);
    
    % randomize presentation of intervals within a block
    if IS_RANDOMIZE_ORDER_INTERVALS
        perm_intervals=randperm(NI);
    else
        perm_intervals=1:NI;
    end
    
    
    %%%%%%%%% Rove tones by rejection sampling %%%%%%%%%%%%%%%
    %%% Rove base tone (the first tone)! Do this by randmoizing tones and
    %%% make sure (rejection sampling) that they are in the right range
    %%% by rejection sampling
    for iii=1:1000
        if iscell(BASE_TONE_RANGE) % allows for different base tone range for different registers
            BASE_TONE=min(BASE_TONE_RANGE{1,K})+rand(1,1)*(max(BASE_TONE_RANGE{1,K})-min(BASE_TONE_RANGE{1,K}));
        else %rove base tone
            BASE_TONE=min(BASE_TONE_RANGE)+rand(1,1)*(max(BASE_TONE_RANGE)-min(BASE_TONE_RANGE));
        end
        if (midi2freq(max(BASE_TONE)+octave*12+max(intervals))<=FREQ_MAX) && (midi2freq(min(BASE_TONE)+min(intervals)+octave*12)>=FREQ_MIN)
            break
        end
        
    end
    if iii>1
        fprintf('rejection sampling %d\n',iii); %print the number of required iterations (for debug purposes)
    end
    assert(iii<100); %this  not suppose to happen since the chance of getting a tone in the right range should be not so small.
    
    % pass over all intervals
    for II=1:NI
        trials_with_2_tones=0; % count trials with 2 tones as a response
        attempts_continue=false; % set to false, this will be true when we need to continue since we got enought good trials
        % pass over all repetitions
        for JJ=1:NR
            cnt=cnt+1;
            J=JJ;
            
            if trials_with_2_tones>=MIN_TRIALS_WITH_2_NOTES
                %pasue
                fprintf('quiting this repetitions because we have %d of %d trials with 2 notes\n',trials_with_2_tones,MIN_TRIALS_WITH_2_NOTES)
                break
            end
            if attempts_continue
                break
            end
            msg1=sprintf('now in grand-repetition %d of %d trials_with_2_tones=%d MIN_TRIALS_WITH_2_NOTES=%d', JJ,NR,trials_with_2_tones,MIN_TRIALS_WITH_2_NOTES);
            
            
            % find the interval
            I=perm_intervals(II);
            interval=intervals(I);
            msg3=sprintf('now in interval %d of %d [interval(%d) =%2.2f]', II,NI,I,interval);
            fprintf('%s\n',msg3);
            
            %%%%%%%%%Create the two tones! %%%%%%%%%%%%%%%
            %%% second tone = first tone + interval
            %%%%
            TONES0=[BASE_TONE ,BASE_TONE + interval];
            
            TONES=TONES0+ octave*12;
            %%% we decided not to do this check... we are taking care of
            %%% registers in other ways (OK if this is slightly off)
            %%% we will need to fix it !!! %%%%%
            %assert(max(TONES0)<=TONE_HIGHEST);
            %assert(min(TONES0)>TONE_LOWEST);
            %%% we will need to fix it !!! %%%%%
            
            
            vel=vels(K);  % Get level in dbs
            
            %%%%%%%%%Create sound from prescription %%%%%%%%%%%%%%%
            %%% This is where a change in synthesis method should be done!
            %%%%
            [stim_audio,~]=SYNTH_simple2sound(TONES,Ps.isi,vel,Ps.dur,1,Ps,SYNTH,fs);
            
            %%% remove silence in the end
            stim_audio=SYNTH_trim_end(stim_audio');
            
            
            %%%%%%%%%play sound! %%%%%%%%%%%%%%%
            %%%% from sound card
            nori_do_play_soundcard_fbeg(stim_audio,fs,DEVout); %
            
            
            
            
        end % ofJJ/ NR
    end % of II/ NI
    
    
    if IS_PAUSE_BLOCK
        commandwindow
        fprintf('[Block finished] Press ENTER to continue...\n');
        pause
    else
        pause(2);
    end
end % of KK/NK


