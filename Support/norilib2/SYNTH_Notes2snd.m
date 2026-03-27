function out=SYNTH_Notes2snd(Notes,SYNTHESIZER,Ps,fs)

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
MAXTIME=max(max(Notes(:,5:6)))+2.1; %extra  secodns for sample durations (important for samplers)
out=zeros(1,round(MAXTIME*fs)+3);

if numel(Ps)<=1 %for single timber- just use it
    P=Ps;
    Ps=cell(NC,1);
    for k=1:NC,
        Ps{k}=P;
    end
else
    if (length(Ps)<NC)
        fprintf('NC=%d poly=%d\n',NC,length(Ps));
    end
    assert(length(Ps)>=NC); % for multitmber make sure the number of instruments can support this midi file
end

for C=1:NC,
    posC=(Notes(:,2)==CHNS(C));
    myNotes=Notes(posC,:);
    P=Ps{C};
    for k=1:size(myNotes,1),
       midi=myNotes(k,3);
       vel=myNotes(k,4);
       duration=1000*(myNotes(k,6)-myNotes(k,5));
       start=myNotes(k,5);
       a = isfield(P, 'SplitHalf');
       if a ==0
           b = isfield(P, 'harm_nums');
          if b ==0
              P.SplitHalfa = [];
          else
               
           P.SplitHalfa = P.harm_nums;
          end
       elseif a ==1
            P.SplitHalfa = P.SplitHalf(:,k);
        end
     
        audio=SYNTHESIZER(midi,vel,duration,fs,P);
       beg=round(fs*start)+1;
       out(beg:(-1+beg+length(audio)))=out(beg:(-1+beg+length(audio)))+audio;
    end
end

%nori_doplay2(0.5*out,fs);
