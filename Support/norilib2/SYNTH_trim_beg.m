function audio=SYNTH_trim_beg(audio)
K=find(audio>0,1,'first');
if K>2
    K=K-1;
end
audio=audio(K:end);
