function analyze_pitch_experiment_yinonly(result_dir)

is_gui_mode = usejava('desktop') && usejava('awt');
%%% more parameters
ISPLOT=false; %don't plot output (change that to see graph within matlab)
ISPLOT=is_gui_mode;

%%% initializations
addpath([pwd,'/voicebox']);
addpath([pwd,'/yin']);


dir_files=dir(sprintf('%s/*.wav',result_dir));NF=length(dir_files); % number of stimuli
fprintf('reading directory:%s (%d files)\n',result_dir,NF);


rng('shuffle');UUID=round(rand(1)*8999+1000); %%% get unique identifyer for the result filename
rfname=sprintf('ANALYZE-RESULTS.%d.csv',UUID); %get result file name


% print result file header
F=fopen(rfname,'w'); 
fprintf(F,'file_number,file_name,note_fq,note_midi,start_time,stop_time,praatlike_start_time,praat_like_stop_time,more_detected_notes(if-exists)\n');

%%% run over files in directory in random order
for I=1:NF
    fname=sprintf('%s/%s',result_dir,dir_files(I).name); %get audio filename
    [myaudio,fs]=audioread(fname); %read audio
    [fq,midi,start_stop]=detect_pitch_nori_yinonly(myaudio,fs,ISPLOT);
    praat_start_stop=detect_praat_startstop(myaudio,fs,midi,start_stop,ISPLOT);
    
    %%% print results
    fprintf(F,'%d,%s',I,fname);
    fprintf('file_number:%d, filename:%s \t',I,fname);
    
    for J=1:length(fq)
        fprintf(F,',%4.1f,%3.2f,%5.3f,%5.3f,%5.3f,%5.3f\t',fq(J),midi(J),start_stop(J,1),start_stop(J,2),praat_start_stop(J,1),praat_start_stop(J,2));
        fprintf('frequency:%4.1f midi:%3.2f start_time:%5.3f stop_time:%5.3f praatlike_start_time:%5.3f praatlike_stop_time:%5.3f \t',fq(J),midi(J),start_stop(J,1),start_stop(J,2),praat_start_stop(J,1),praat_start_stop(J,2));
    end
    fprintf(F,'\n');
    fprintf('\n');
   if ISPLOT
       drawnow
   end
end

fprintf('saving to file: %s\n',rfname);
fclose(F);
  
if ~is_gui_mode
    exit(0)
end