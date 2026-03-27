function audio=SYNTH_make_note_inharmonic(midi,vel,duration,fs,P)
STATION= P.STATION;

    

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
        tone  = make_tone(myfq, fs,length(tt)/fs,P.harm_nums,P.centroid, P.jitt, P.dist, P.JitterString);
        
        if length(tone)>length(tt)
            tone=tone(1:length(tt));
        end
        if length(tone)<length(tt)
            tone0=zeros(length(tt));
            tone0(1:length(tone))=tone;
            tone=tone0;
        end
        audio=tone;
        %audio=audio+sin(2*pi*tt*myfq)*v(I);
    %end
end

audio=(audio/max(audio)).*env10;
audio_l=set_level(audio, fs, vel, [STATION 'Left']);
audio_r=set_level(audio, fs, vel, [STATION 'Right']);
audio=nan(length(audio_l),2);
audio(:,1)=audio_l;
audio(:,2)=audio_r;

