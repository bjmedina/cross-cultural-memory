function detect_pitch_in_file_yinonly(fname)
addpath([pwd,'/voicebox']);
addpath([pwd,'/yin']);
[myaudio,fs]=audioread(fname);

is_gui_mode = usejava('desktop') && usejava('awt');
%%% more parameters
%ISPLOT=false; %don't plot output (change that to see graph within matlab)
ISPLOT=is_gui_mode;
if is_gui_mode
    figure(1);clf
end
[fq,midi,start_stop]=detect_pitch_nori_yinonly(myaudio,fs,ISPLOT);

tfname=sprintf('%s.txt',fname);
FID=fopen(tfname,'w');

for I=1:length(fq)
    fprintf(FID,'note %2d\t\tfq= %4.1f\tmidi=%3.2f\tstart=%3.3f\tstop=%3.3f\n',I,fq(I),midi(I),start_stop(I,1),start_stop(I,2));
end
fclose(FID);

for I=1:length(fq)
    fprintf('note %2d\t\tfq= %4.1f\tmidi=%3.2f\tstart=%3.3f\tstop=%3.3f\n',I,fq(I),midi(I),start_stop(I,1),start_stop(I,2));
end
if ~is_gui_mode
    exit(0)
end
