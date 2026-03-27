function audio=SYNTH_make_note_sampler(midi,vel,duration,fs,P)

if isempty(P.MAPPER{midi})
    fprintf('NORI: error this midi note (%d) do not have samples!\n',midi);
    assert(1==0);
end

Noptions=length(P.MAPPER{midi}.wavs);
my_option=randi(Noptions,1,1);
audio=P.MAPPER{midi}.wavs{my_option}';

if isfield(P,'fade_out')
  
    audio=fade_out(audio,fs,P.fade_out);
end
if ~isnan(vel)
   
    assert(vel<=0);
    audio=(audio/max(audio))*(10.^(vel/10));
end
    


% msg=sprintf('choose %d [%s] %s ',my_option,P.MAPPER{midi}.codes{my_option},P.MAPPER{midi}.files{my_option})
% 
% fprintf('%s',msg);
% figure(1);clf;
% plot(P.MAPPER{midi}.wavs{my_option});
% title(msg);
% drawnow
