function audio=SYNTH_make_note_inharmonic2(midi,vel,duration,fs,P)
STATION= P.STATION;

    harm_nums=P.harm_nums;
    centroid=P.centroid;
    jitt=P.jitt;
    dist=P.dist;
    jitt_amt = P.jitt_amt;
    JitterString=P.JitterString;
    if isfield(P,'SplitHalf')
        SplitHalf=P.SplitHalf;
    else
        SplitHalf=[harm_nums;harm_nums];
    end
    
    if size(SplitHalf,2)==2
       
        if midi>1000
            midi=midi-1000;
            SplitHalf=SplitHalf(:,2);
        else
          SplitHalf=SplitHalf(:,1);  
        end
    end
    
    
    
    %%%% DENUG HACK!!!!
    
%     if isfield(P,'SplitHalf')
%         SplitHalf=P.SplitHalf;
%     else
%         SplitHalf=[];
%     end
%     
%     if size(SplitHalf,2)==2
%        
%         if midi>1000
%             harm_nums=4;
%             midi=midi-1000;
%         else
%           harm_nums=10;  
%         end
%     end
    %%%% DENUG HACK!!!!
    
    
    %%%
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



    %for I=1:length(v)
        myfq=fq;
        %Ttone  = make_mel_harmsplit_v1(myfq, fs,length(tt)/fs,harm_nums,centroid, jitt, dist, JitterString);
        tone  = make_mel_harmsplit_v3(0, myfq, harm_nums, jitt_amt, jitt, length(tt)/fs,fs,dist,  centroid,SplitHalf,-Inf, JitterString);
        
        %note_vary_env_jitt_HarmSplit_v1(f0, harm_nums, jitt_amt,jitt, dur_s, sr, dist,JitterString, centroid, SplitHalf, dB_atten)

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


audio=(audio/max(audio)).*env10;
audio_l=set_level(audio, fs, vel, [STATION 'Left']);
audio_r=set_level(audio, fs, vel, [STATION 'Right']);
audio=nan(length(audio_l),2);
audio(:,1)=audio_l;
audio(:,2)=audio_r;

