function stim_audio_level=set_level_wrapper(stim_audio,fs,DESIRED_SPL,STATION)
if size(stim_audio,2)==1
    stim_audio=[stim_audio,stim_audio];
end
stim_audio_level(:,1)=set_level(stim_audio(:,1),fs,DESIRED_SPL,[STATION,'Left']);
stim_audio_level(:,2)=set_level(stim_audio(:,2),fs,DESIRED_SPL,[STATION,'Right']);
