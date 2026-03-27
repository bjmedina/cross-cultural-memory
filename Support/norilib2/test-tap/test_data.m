cd ~/ResearchMIT/CBMM/CMMMproj/WORLD-KIMI-ITER-EXPERIMENT/kimi-EXPiter-26-Jan-2017/
cd ~/ResearchMIT/CBMM/CMMMproj/WORLD-KIMI-ITER-EXPERIMENT/EXPiter-09-Feb-2017/



WORKING_DIRECTORY='/Users/jacoby/Dropbox/Research MIT/CBMM/CMMMproj/WORLD-KIMI-ITER-EXPERIMENT';       %you may want to change this: root directory
LIB_DIRECTORY='/Users/jacoby/Dropbox/Research MIT/CBMM/CMMMproj/WORLD-KIMI-ITER-EXPERIMENT/nori_lib/'; %you may want to change this: nori library
SOUND_CARD='Scarlett 2i2 USB'; %name of sound card
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

addpath(WORKING_DIRECTORY)
addpath(LIB_DIRECTORY)
close all force

a=dir('EXP*ISI2000.iterations5,REPa10.REPb10*mat');

for I=1:length(a)
    fname=a(I).name;
    res=load(fname);
    
    figure(I+100);
    for K=1:5
        clf
        subplot(1,2,1); plot(res.ALL2{1}.data{K}.recD(:,1)); title(fname)
        subplot(1,2,2); plot(res.ALL2{1}.data{K}.recD(:,2));title(K);
        %drawnow;
        %nori_doplay2(res.ALL2{1}.data{K}.recD,res.fs0);
        SLEEP=[18,60];    %extraction parameters
        SLEEPMIN=[26,80]; %min sleep time
        CHUNK=7603;       %extraction normalization length (ms)
        ISPLOT=true; %plot extraction
        TRESH=[0.15,0.15]; %extraction thresholds
        BEG=0.5; %safety output silence
        figure(1);clf
        recD=res.ALL2{1}.data{K}.recD;
        fs=44100; %fs of extraction
        fs0=12000;%down sampled sampling rate

        %[Sr,Rr]=LongAnalyzeCleanSoundsDivideStereoVIEWpause(recD,fs0,TRESH,SLEEP,SLEEPMIN,CHUNK,ISPLOT); %extract onsets
        %[Sr,Rr]=LongAnalyzeCleanSoundsDivideStereoVIEW(recD,fs0,TRESH,SLEEP,SLEEPMIN,CHUNK,ISPLOT); %extract onsets
        %pause
         figure(11);set (gcf,'units','normalized','outerposition',[0 0 1 1]);NITER_plot_patterns(  res.ALL,K,'',0);
            %figure(10);clf;
            figure(10);clf;set (gcf,'units','normalized','outerposition',[0 0 1 1]);NITER_plot3_progress( res.ALL{1}.data,K,'',0);
            %pause
    end
    
end
