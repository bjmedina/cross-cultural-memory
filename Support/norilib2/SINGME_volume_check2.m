%function SINGME_volume_check2(Ps,SYNTH,fs,DEVout)

RANGE=[43,130];
%while 1==1
%     TONES=rand(1,30)*(max(RANGE)-min(RANGE))+min(RANGE);
    TONES=[55+ (0:6)*12];
    
%     vel=[100,90,80,70,60,50,40];
%     vel=[100]+ ([0:1:6]/-6)*40;
%     
%     %vel=[vel,vel(end:-1:1)];
%     %TONES=[TONES,TONES(end:-1:1)]
%     TONES=[TONES,TONES];
%     vel=[vel,vel];
    vel=SINGME_midi2vel(TONES)
    isi=1500;
    dur=1400;
    [stim_audio,~]=SYNTH_simple2sound(TONES,isi,vel,dur,1,Ps,SYNTH,fs);
    stim_audio=SYNTH_trim_end(stim_audio);
    
   
    
    nori_do_play_soundcard(stim_audio,fs,DEVout);
%     sans=input('coninue? yes(0) no (1):');
% 
%     if sans~=0
%         break
%     end
% end
