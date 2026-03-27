clear all;close all;clc

%%%%% CHANGE HERE TO YOUR PATH IN YOUR LOCAL COMPUTER %%%%%%
addpath('/Users/administrator/Dropbox (MIT)/SYNCtoBOOTHS/mcdexp-jacoby/Singing-7feb2018/MalindaAnalysis'); % addpath analysis code (may need to change this to accomodate local directory structure)
addpath('/Users/administrator/Dropbox (MIT)/SYNCtoBOOTHS/mcdexp-jacoby/Singing-7feb2018/MalindaAnalysis/norilib/'); % addpath to support functions (may need to change this to accomodate local directory structure)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% This example show how to read data for two condition, organize them and
% plot common analyis
% in this example  we assume we want to compare the results of two
% conditions "4-inharmonic" and "5-inharmonic".

DATASETs=cell(2,1); % container for data for all experiments

%%
%%%%% set the parameters for the experiments
%%% condition 1:
todo=[]; % container to searc pattern and data from one condition
todo.fseed_pattern='Summary*test-3.5*'; %search pattern for the file 
todo.intervals0=[-5 -4 -3 -2 -1 0 1 2 3 4 5 ]; % in this case we will match all experiments with the same size (number of condition) as [0 1 2 3 4 0 -1 -2 -3 -4 0]*nan if this specified will do exact match
todo.OCTAVES=[0 1 ]; % will only compare size since man and women may have different OCTAVE content, OCTAVE are relative to the singing range.
todo.RESsize=[4 2 11]; % #repetitions X #octaves X #intervals
todo.GENDER=nan; % nan for both, True for male (IS_MALE=true, sorry I haven't made this reversed, I usually do..., but started to test it on myself, hence the true/false direction)
todo.interval_options=todo.intervals0; % what possibly can be the intervals (if the intervals are selected at random)
todo.filter_unique_participants=-1; % GET_EARLY=-1 % get the ealiest time stamp % GET_LATE=1 get the latest time stamp % GET_ALL=nan/0/empty do not filter uniq participnats.
todo.VERBOSITY=1;
todo.data_or_data_dir='/Users/administrator/Dropbox (MIT)/SYNCtoBOOTHS/mcdexp-jacoby/Singing-7feb2018/data/CompiledExpEnv/';
todo.IS_EXPERIMENTER=false;% always be false
todo.EXP_NAME='Harmonic';
%%%% Read the data and organize it
output=MASING_get_matching_data(todo);
NDATA=MASING_process_data(output.data);
%%%% Store in container
DATASETs{1}.NDATA=NDATA;
DATASETs{1}.EXP_NAME=todo.EXP_NAME;
DATASETs{1}.output=output;


%% condition 2:
todo=[];% container to searc pattern and data from the second condition
todo.fseed_pattern='Summary*test-5*'; %search pattern for the file 
todo.intervals0=[-5 -4 -3 -2 -1 0 1 2 3 4 5]; % in this case we will match all experiments with the same size (number of condition) as [0 1 2 3 4 0 -1 -2 -3 -4 0]*nan if this specified will do exact match
todo.OCTAVES=[0 1]; % will only compare size since man and women may have different OCTAVE content, OCTAVE are relative to the singing range.
todo.RESsize=[4 2 11]; % #repetitions X #octaves X #intervals
todo.GENDER=nan; %  nan for both
todo.interval_options=todo.intervals0; % what possibly can be the intervals (if the intervals are selected at random)
todo.filter_unique_participants=-1; % GET_EARLY=-1 % get the ealiest time stamp % GET_LATE=1 get the latest time stamp % GET_ALL=nan/0/empty do not filter uniq participnats.
todo.VERBOSITY=1;
todo.data_or_data_dir='/Users/administrator/Dropbox (MIT)/SYNCtoBOOTHS/mcdexp-jacoby/Singing-7feb2018/data/CompiledExpEnv/';
todo.IS_EXPERIMENTER=false; % always be false
todo.EXP_NAME='Inharmonic - Block';
%%%% Read the data and organize it
output=MASING_get_matching_data(todo);
NDATA=MASING_process_data(output.data);
%%%% Store in container
DATASETs{2}.NDATA=NDATA;
DATASETs{2}.EXP_NAME=todo.EXP_NAME;
DATASETs{2}.output=output;

clear NDATA
clear output

fprintf('---------------------------------------------------------\nDONE reading experiments! I was reading %d experiments:\n',length(DATASETs))
for I=1:length(DATASETs)
    fprintf('Experiment %2d \t %s (%d files)\n',I,DATASETs{I}.EXP_NAME,DATASETs{I}.NDATA.NS);
end
fprintf('---------------------------------------------------------\n')

%%
close all

%%% decide what conditions to show, what colors and what would be the
%%% labels
what_to_to.exps=[1,2]; % what condition to run (so for example to reverse order of presentation you can do; what_to_to.exps=[2,1]
what_to_to.clrs={'b','r'}; % line colors of the conditions
what_to_to.line={'-','-'}; % line shape of the conditions
what_to_to.grps={DATASETs{1}.EXP_NAME,DATASETs{2}.EXP_NAME}; % conditions labels
what_to_to.lcrls={'r','m', [0.6 0.2 0.2],'b','c', 'g'}; %more colors for direction plot
what_to_to.isplot_unis=false; % plot unisons frequncy (true or false) for reduced clatter--> false

what_to_to.DO_SUBPLOT=true; %plot all octaves on one graph, or plot multiple subplots
what_to_to.MAX_INTERVAL_for_accuracy=6; % for computation of mean abs accruacy trim responses with too large intervals (in semitones, shoud be larger than abs of largest intrval)

RES=MASING_compute_stats(DATASETs,what_to_to);
  
MASING_plot_stats(DATASETs,what_to_to,RES)
%% 

clear all;close all;clc

%%%%% CHANGE HERE TO YOUR PATH IN YOUR LOCAL COMPUTER %%%%%%
addpath('/Users/administrator/Dropbox (MIT)/SYNCtoBOOTHS/mcdexp-jacoby/Singing-7feb2018/MalindaAnalysis'); % addpath analysis code (may need to change this to accomodate local directory structure)
addpath('/Users/administrator/Dropbox (MIT)/SYNCtoBOOTHS/mcdexp-jacoby/Singing-7feb2018/MalindaAnalysis/norilib/'); % addpath to support functions (may need to change this to accomodate local directory structure)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% This example show how to read data for two condition, organize them and
% plot common analyis
% in this example  we assume we want to compare the results of two
% conditions "4-inharmonic" and "5-inharmonic".

DATASETs=cell(2,1); % container for data for all experiments

%%
%%%%% set the parameters for the experiments
%%% condition 1:
todo=[]; % container to searc pattern and data from one condition
todo.fseed_pattern='Summary*test-8*'; %search pattern for the file 
todo.intervals0=[-5 -4 -3 -2 -1 0 1 2 3 4 5 ]; % in this case we will match all experiments with the same size (number of condition) as [0 1 2 3 4 0 -1 -2 -3 -4 0]*nan if this specified will do exact match
todo.OCTAVES=[0 ]; % will only compare size since man and women may have different OCTAVE content, OCTAVE are relative to the singing range.
todo.RESsize=[4 1 11]; % #repetitions X #octaves X #intervals
todo.GENDER=nan; % nan for both, True for male (IS_MALE=true, sorry I haven't made this reversed, I usually do..., but started to test it on myself, hence the true/false direction)
todo.interval_options=todo.intervals0; % what possibly can be the intervals (if the intervals are selected at random)
todo.filter_unique_participants=-1; % GET_EARLY=-1 % get the ealiest time stamp % GET_LATE=1 get the latest time stamp % GET_ALL=nan/0/empty do not filter uniq participnats.
todo.VERBOSITY=1;
todo.data_or_data_dir='/Users/administrator/Dropbox (MIT)/SYNCtoBOOTHS/mcdexp-jacoby/Singing-7feb2018/data/Compiled_Wider/Good_AccuracyLess1ST/';
todo.IS_EXPERIMENTER=false;% always be false
todo.EXP_NAME='Shepard - Harmonic';
%%%% Read the data and organize it
output=MASING_get_matching_data(todo);
NDATA=MASING_process_data(output.data);
%%%% Store in container
DATASETs{1}.NDATA=NDATA;
DATASETs{1}.EXP_NAME=todo.EXP_NAME;
DATASETs{1}.output=output;


%% condition 2:
todo=[];% container to searc pattern and data from the second condition
todo.fseed_pattern='Summary*test-10*'; %search pattern for the file 
todo.intervals0=[-5 -4 -3 -2 -1 0 1 2 3 4 5]; % in this case we will match all experiments with the same size (number of condition) as [0 1 2 3 4 0 -1 -2 -3 -4 0]*nan if this specified will do exact match
todo.OCTAVES=[0 ]; % will only compare size since man and women may have different OCTAVE content, OCTAVE are relative to the singing range.
todo.RESsize=[4 1 11]; % #repetitions X #octaves X #intervals
todo.GENDER=nan; %  nan for both
todo.interval_options=todo.intervals0; % what possibly can be the intervals (if the intervals are selected at random)
todo.filter_unique_participants=-1; % GET_EARLY=-1 % get the ealiest time stamp % GET_LATE=1 get the latest time stamp % GET_ALL=nan/0/empty do not filter uniq participnats.
todo.VERBOSITY=1;
todo.data_or_data_dir='/Users/administrator/Dropbox (MIT)/SYNCtoBOOTHS/mcdexp-jacoby/Singing-7feb2018/data/Compiled_Wider/Good_AccuracyLess1ST/';
todo.IS_EXPERIMENTER=false; % always be false
todo.EXP_NAME='Shepard - Inharmonic - Block';
%%%% Read the data and organize it
output=MASING_get_matching_data(todo);
NDATA=MASING_process_data(output.data);
%%%% Store in container
DATASETs{2}.NDATA=NDATA;
DATASETs{2}.EXP_NAME=todo.EXP_NAME;
DATASETs{2}.output=output;

clear NDATA
clear output

fprintf('---------------------------------------------------------\nDONE reading experiments! I was reading %d experiments:\n',length(DATASETs))
for I=1:length(DATASETs)
    fprintf('Experiment %2d \t %s (%d files)\n',I,DATASETs{I}.EXP_NAME,DATASETs{I}.NDATA.NS);
end
fprintf('---------------------------------------------------------\n')

%%
close all

%%% decide what conditions to show, what colors and what would be the
%%% labels
what_to_to.exps=[1,2]; % what condition to run (so for example to reverse order of presentation you can do; what_to_to.exps=[2,1]
what_to_to.clrs={'b','r'}; % line colors of the conditions
what_to_to.line={'-','-'}; % line shape of the conditions
what_to_to.grps={DATASETs{1}.EXP_NAME,DATASETs{2}.EXP_NAME}; % conditions labels
what_to_to.lcrls={'r','m', [0.6 0.2 0.2],'b','c', 'g'}; %more colors for direction plot
what_to_to.isplot_unis=false; % plot unisons frequncy (true or false) for reduced clatter--> false

what_to_to.DO_SUBPLOT=true; %plot all octaves on one graph, or plot multiple subplots
what_to_to.MAX_INTERVAL_for_accuracy=6; % for computation of mean abs accruacy trim responses with too large intervals (in semitones, shoud be larger than abs of largest intrval)

RES=MASING_compute_stats(DATASETs,what_to_to);
  
MASING_plot_stats(DATASETs,what_to_to,RES)

