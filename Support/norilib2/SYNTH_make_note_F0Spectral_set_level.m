function audio=SYNTH_make_note_F0Spectral_set_level(midi,vel,duration,fs,P)

amp=10.^(vel/20);
fq=(2^((midi-69)/12))*440;

atk=floor(P.atk*fs/1000);
dec=floor(P.dec*fs/1000);
dur=round(duration*fs/1000);

if (atk+dec)>(dur)
    atk=floor(dur/2);
    dec=dur-atk;
    sus=0;
else
    sus=dur-atk-dec;
end

env10=[linspace(0,amp,atk),linspace(amp,amp,sus),linspace(amp,0,dec)];

tt=(1:length(env10))/fs;

audio=zeros(size(tt));

myfq=fq;

tone  = makeF0SpectralTone_singing_set_level(P.nNMat, myfq,length(tt)/fs,P.interval, fs, P.isi,P.STATION); %generate two tones!!!
audio=tone;


