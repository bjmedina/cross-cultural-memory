function result = scale(stimulus,gain)
%scale(stimulus,gain)
%Scales a stimulus by a factor gain in dB
%Any gain of -150 or less mutes the signal

if nargin < 2
   help scale
   return
end

if gain <= -150
   result = stimulus .* 0;
else
   result = stimulus .* 10^(gain/20);
end
