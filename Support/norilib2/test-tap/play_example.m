
FS=44100; %defines the frequency sample

%decide if you want to do click or beep. 
doCLICK=1;doBEEP=2;
clicksound=calc_click(doCLICK,FS); % if you want to change the beep structure change calc_click

% attack=10;hold=30;release=10;freq=1000;
% clicksound=generatebeep(FS,attack,hold,release,freq);
% click sound contains a short wav that represents the percussive sound


%plug here the stimulus you want to create.
vecISI=[500,500,600,500,3000]; %important must be a raw vector!!

fname='example3.wav';
times=STIMfromISI(FS,vecISI,clicksound);

