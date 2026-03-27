function M=SYNTH_simple2Notes(notes,isi,vel,dur,chn)
% This function takes a formatted input and create MIDI matrix from simple
% input
% notes can be a cell of chords (vecors) as {60,[62,69],[64]}
% isi is the isis between notes, and is suppose to be vector of size of
% notes
% vel are the velocities and it can be either of the same cell format of
% notes, a vecotr of length(notes) which means each chord have the same vel
% (and not individually whthin the chord), or a single number setting
% allnotes to this single values;
% dur have the same format as notes
% chn is only one number or a vecotr seeting channels (defaul channel 1).
% examples:
%M=SYNTH_simple2matrix({60,[62,69],[64]},[600 600 600],{100,[500,100],[50]},[200 300 200],1);
%M=SYNTH_simple2matrix([60,61,62],[600 600 600],[100 100 100],[200 300 200],1);
%
%note!!! isi is in Vorberg format

if length(isi)==1
    isi=ones(size(notes))*isi;
end
% everything is in msec
%size(notes)
%size(isi)
assert(size(notes,2)==size(isi,2));

if ~iscell(notes)
    temp=cell(size(notes));
    for k=1:length(notes)
        temp{k}=[notes(k)];
    end
    notes=temp;
end

if isempty(vel);
    vel=127;
end

if numel(vel)==1;
    temp=cell(size(notes));
    for k=1:length(notes)
        temp{k}=ones(size(notes{k}))*vel;
    end
    vel=temp;
end

if ~iscell(vel)
    temp=cell(size(notes));
    for k=1:length(notes)
        temp{k}=ones(size(notes{k}))*vel(k);
    end
    vel=temp;
end
assert(length(vel)==length(notes));


if isempty(dur);
    dur=50;
end

if numel(dur)==1;
    temp=cell(size(notes));
    for k=1:length(notes)
        temp{k}=ones(size(notes{k}))*dur;
    end
    dur=temp;
end

if ~iscell(dur)
    temp=cell(size(notes));
    for k=1:length(notes)
        temp{k}=ones(size(notes{k}))*dur(k);
    end
    dur=temp;
end
assert(length(dur)==length(notes));


if isempty(chn)
    chn=ones(size(isi));
end

if numel(chn)==1;
    chn=ones(size(isi))*chn;
else
    assert(numel(chn)==numel(isi))
end

%   1     2    3  4   5  6
% [track chan nn vel t1 t2 ]
starts=[0,cumsum(isi(1:(end-1)))]/1000;
starts=starts-starts(1);
M=nan(length(notes),6); % this is probably not enought so it will grow.
      
cnt=0;
for I=1:length(notes);
    chord=notes{I};
    for k=1:length(chord)
        cnt=cnt+1;
        M(cnt,1)=1;
        M(cnt,2)=chn(I);
        M(cnt,3)=chord(k);
        M(cnt,4)=vel{I}(k);
        M(cnt,5)=starts(I);
        M(cnt,6)=starts(I)+dur{I}(k)/1000;
    end
end

end