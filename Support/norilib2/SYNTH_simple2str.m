function str=SYNTH_simple2str(notes)
%notes={60,[61,63,65],[62,69],[64]}
NAMES={'C','Db','D','Eb','E','F','F#','G','Ab','A','Bb','B'};
str='';
lastreg=nan;
for I=1:length(notes)
    chord=notes{I};
    for J=1:length(chord)
        note=chord(J);
        reg=floor((note-24)/12)+1;
        nm=NAMES{mod(note-60,12)+1};
        if reg==lastreg;
            str=sprintf('%s%s',str,nm);
        else
            str=sprintf('%s%s%d',str,nm,reg);
            lastreg=reg;
        end
        
        
        if J<length(chord)
            str=sprintf('%s-',str);
        end
    end
    if I<length(notes)
        str=sprintf('%s,',str);
    end
end
