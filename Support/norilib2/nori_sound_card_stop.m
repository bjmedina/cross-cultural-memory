%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Nori Jacoby's audio library
% Please don't use it without Nori's permision...
% For more information please contact: nori.viola@gmail.com
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function nori_sound_card_stop(context)
if isfield(context,'pout') && (~isnan(context.pout))
    PsychPortAudio('Close', context.pout);
end
if isfield(context,'pin') && (~isnan(context.pin))
    PsychPortAudio('Close', context.pin);
end


