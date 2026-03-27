function SINGME_volume_check1db(Ps,SYNTH,fs,DEVout)

RANGE=[43,130];
while 1==1
    TONES=rand(1,30)*(max(RANGE)-min(RANGE))+min(RANGE);
    vel=100;
    vel=SINGME_midi2vel2(TONES);
    isi=200;
    dur=390;
    [stim_audio,~]=SYNTH_simple2sound(TONES,isi,vel,dur,1,Ps,SYNTH,fs);
    stim_audio=SYNTH_trim_end(stim_audio);
    nori_do_play_soundcard(stim_audio,fs,DEVout);
    sans=input('coninue? yes(0) no (1):');

    if sans~=0
        break
    end
end
