function audio=SYNTH_trim_end(audio)
if size(audio,2)>size(audio,1)
    audio=audio';
end
K=find(sum(audio,2)>0,1,'last');
if K<size(audio,1)
    K=K+1;
end
audio=audio(1:K,:);
