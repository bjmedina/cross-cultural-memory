function notesT=SYNTH_simple_transpose(notes,T)
notesT=notes;
for I=1:length(notes)
    notesT{I}=notes{I}+T;
end