function ksgram(d,fs)

sg = stftSpectrogramStructure(d,fs,80,1,'nuttallwin12');


imagesc([0 sg.temporalPositions(end)],[0 fs/2],max(-80,sg.dBspectrogram));
axis('xy');colorbar; grid

axis([0 1.2 0 2000]);
