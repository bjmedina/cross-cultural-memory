function out=SYNTH_simple2midi(notes,isi,vel,dur,chn,fname)
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
%M=SYNTH_simple2matrix({60,[62,69],[64]},[600 600 600],[127 100 60],{100,[100,100],[50]},1);
%M=SYNTH_simple2matrix([60,61,62],[600 600 600],[100 100 100],[200 300 200],1);

M=SYNTH_simple2Notes(notes,isi,vel,dur,chn);
midi=matrix2midi(M);
writemidi(midi,fname);