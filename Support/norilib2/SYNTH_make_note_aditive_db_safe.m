function audio=SYNTH_make_note_aditive_db_safe(midi,vel,duration,fs,P)
v=P.v;
 %P.v=120-log2(1:10)*12; % complex tone
vdb=10.^(v/20);
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

%env=[linspace(0,vel,atk),linspace(vel,vel,sus),linspace(vel,-10,dec)];
%env10=10.^((env-127)/64);

tt=(1:length(env10))/fs;

audio=zeros(size(tt));

for I=1:length(v)
    myfq=fq*I;
    if myfq<(fs/2)
        audio=audio+sin(2*pi*tt*myfq)*vdb(I);
    end
end

audio=(audio/max(audio)).*env10;

