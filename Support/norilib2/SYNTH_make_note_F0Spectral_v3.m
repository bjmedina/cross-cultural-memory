function audio=SYNTH_make_note_F0Spectral_v3(midi,vel,duration,fs,P)


    

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


if isfield(P,'LFO')
    lfo_width=P.LFO.width;
    lfo_fq=1/(P.LFO.time/1000);
    for I=1:length(v)
        %mylfo=sin(2*pi*tt*lfo_fq);
        %mymidi=(midi+lfo_width.*sin(2*pi*tt*lfo_fq));
        %myfq=I*fq;
        
        audio=audio+ sin(2*pi*( (tt.*fq*I) + (I*lfo_width/lfo_fq)*sin(2*pi*tt*lfo_fq)))*v(I);
    end
    
else
    %for I=1:length(v)
        myfq=fq;

        %[mel] = makeF0SpectralTone(nNMat, F0, dur, up_down, sr)
        tone  = makeF0SpectralTone_singing_v3(P.nNMat, myfq,length(tt)/fs,P.interval, fs, P.isi);
        
%         if length(tone)>length(tt)
%             tone=tone(1:length(tt));
%         end
%         if length(tone)<length(tt)
%             tone0=zeros(length(tt));
%             tone0(1:length(tone))=tone;
%             tone=tone0;
%         end
        audio=tone;
        %audio=audio+sin(2*pi*tt*myfq)*v(I);
    %end
end

audio=audio;

