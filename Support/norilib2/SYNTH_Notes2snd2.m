%%% stereo version asumes that P in Ps have P.pan and P.vol (P.pan is
%%% panning from 0 to 1 where 0.5 is center) P.vol is in dB.
function out=SYNTH_Notes2snd2(Notes,SYNTHESIZER,Ps,fs)

% fname='test3b.mid'
%  midi = readmidi(fname); % read midi file
% [Notes,endtime] = midiInfo(midi,0,[]); % parse midi
% 
% SYNTH=@SYNTH_make_note_fm;
% clear P;
% P.v=[nan nan 1. 8. 6. 1. 0. 0.125 49.541283 0.015625 86.238533 0. 64.220169 1.875 0. 0.375 51.376144 0. 148.62384];
% P.v=[nan nan 1. 10. 10. 0. 0. 1. 25.688072 0.734375 20.183487 0.6875 117.43119 0. 36.697235 0. 0. 5.25 25.688072 4.5 14.678898 0.375 108.256866 0. 51.376144];
% Ps=P;

%   1     2    3  4   5  6  7       8
% [track chan nn vel t1 t2 msgNum1 msgNum2]

CHNS=unique(Notes(:,2));
NC=length(CHNS);


% creat enought blank audio 
MAXTIME=max(max(Notes(:,5:6))); %extra  secodns for sample durations (important for samplers)
out=zeros(round(MAXTIME*fs)+3,2);

if numel(Ps)<=1 %for single timber- just use it
    P=Ps;
    Ps=cell(NC,1);
    for k=1:NC
        Ps{k}=P;
    end
else
    if (length(Ps)<NC)
        fprintf('NC=%d poly=%d\n',NC,length(Ps));
    end
    assert(length(Ps)>=NC); % for multitmber make sure the number of instruments can support this midi file
end

for C=1:NC
    posC=(Notes(:,2)==CHNS(C));
    myNotes=Notes(posC,:);
    P=Ps{C};
    pan=P.pan;
    assert(pan>=0);assert(pan<=1);
    vol_db=P.vol;
    vamp=10.^(vol_db/10);
    
    for k=1:size(myNotes,1)
       midi=myNotes(k,3);
       vel=myNotes(k,4);
       duration=1000*(myNotes(k,6)-myNotes(k,5));
       start=myNotes(k,5);
       audio=vamp*SYNTHESIZER(midi,vel,duration,fs,P);
       beg=round(fs*start)+1;
       audio_1=audio*(pan);
       audio_2=audio*(1-pan);
       if (-1+beg+length(audio))<size(out,1)
        out(beg:(-1+beg+length(audio)),:)=out(beg:(-1+beg+length(audio)),:)+[audio_1',audio_2'];
       else
           out2=zeros(beg+length(audio)+3,2);
           out2(1:size(out,1),:)=out;
           out2(beg:(-1+beg+length(audio)),:)=out2(beg:(-1+beg+length(audio)),:)+[audio_1',audio_2'];
           out=out2;
       end
    end
end

%nori_doplay2(0.5*out,fs);
