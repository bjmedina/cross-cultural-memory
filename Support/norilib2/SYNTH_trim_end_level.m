function audio=SYNTH_trim_end_level(audio,leveldb_relative_to_max)
if size(audio,2)>size(audio,1)
    audio=audio';
end

max_audio=max(audio(:));
amp=(10.^((-abs(leveldb_relative_to_max))./20))*max_audio;

K=find(sum(audio,2)>amp,1,'last');
if K<size(audio,1)
    K=K+1;
end
audio=audio(1:K,:);
