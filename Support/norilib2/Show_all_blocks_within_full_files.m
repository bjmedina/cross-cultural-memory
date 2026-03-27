
TEST_DIR='/Users/jacoby/Dropbox (Holden)/Rhythm EXperiment/data of MATLAB';

adir=dir('EXPall*');

for III=1:length(adir)
    fname=adir(III).name;
    data=load(fname);
    figure(10);clf;subplot(2,2,2);
    [Sr,Rr]=LongAnalyzeCleanSoundsDivideStereoVIEWALL(data.recDf,data.fs0,data.TRESH,data.SLEEP,data.SLEEPMIN,data.CHUNK,data.ISPLOT); %extract onsets
    figure(10);set (gcf,'units','normalized','outerposition',[0 0 1 1]);NITER_plot3_progress_2017(data.ALL,data.KKK,data.J,data.msgN);%NITER_plot3_progress_2018(data.ALL,data.KKK,data.J,data.msgN);
    subplot(2,2,3);title(fname)
    
    drawnow;
    pause
    
end