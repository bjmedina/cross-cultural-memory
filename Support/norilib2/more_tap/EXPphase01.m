NUMCLICK=107;

ISO=500;
devs=[2,6,10,14,18];
rangeJump=[8 12];   
BEG=3;

REPET=2;
NTRIALS=length(devs);
NCONDS=REPET*NTRIALS;

FS=44100;

%cd 'C:\Users\Nori\Documents\My Dropbox\Research\new_experiments'
cd 'C:\Users\NJ\Dropbox\Research\new_experiments'
clicksound=calc_click(1); % 1 for click 2 for beep.

EXPID=floor(rand(1,1)*10000);
EXPname='EXPphase01';

TOT=NCONDS;
myTOTperm=randperm(TOT);
idx=0;
for J=1:REPET,
        for K=1:NTRIALS,
            idx=idx+1;
            mydev=devs(K);
            T0=ISO;
            T1=ISO + ISO*mydev/100;
            T2=ISO - ISO*mydev/100;
            Nbeats=NUMCLICK;
            rangeJump=[8 12];   
            BEG= 0;

            fname=sprintf('%s_%d_1_%02d_TRIAL=%d_REPEAT=%d_T0=%d_T1=%d_T2=%d_dev=%d.wav',EXPname,EXPID,myTOTperm(idx),K,J,T0,T1,T2,mydev)
            %%%myseq=STIMcreateIID(fname,FS,NUMCLICK,myT1,myT2,myp,clicksound);
            %%%myseq=STIMcreateIID(fname,FS,NUMCLICK,myT1,myT2,myT0,BEG,myp,clicksound);
            %%%myseq=STIMcreateDRIFTbound(fname,FS,NUMCLICK,T0,myDT,B1,B2,BEG,clicksound);
         
            
            myseq=STIMcreatePhase(fname,FS,Nbeats,T0,T1,T2,rangeJump,BEG,clicksound);
            
            
        end
end
%%
%Create ISO sequqnece
fname=sprintf('%s_%d_00_ISO.wav',EXPname,EXPID);
myseq=STIMcreatePhase(fname,FS,Nbeats,500,500,500,rangeJump,BEG,clicksound);
