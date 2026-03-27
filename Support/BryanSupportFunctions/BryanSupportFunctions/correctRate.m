% correctRate(rate, epsilon)
%
% Corrects a rate value that is within epsilon of 0 or 1.
% This is useful when calculating d', for instance, because
% you never want the rates that go into the 'norminv' function
% to be 0 or 1 (leads to inf or -inf d' values).
%
% Input(s)
% ========
% rate (double): rate value to correct
% epsilon (double): tolerance for correction.
%
% Output(s)
% =========
% correctedRate (double): rate value after correction (if any).
%
% July 27, 2023 -- Bryan Medina (bjmedina@mit.edu)
function correctedRate = correctRate(rate, epsilon)
    correctedRate = rate;
    if rate >= 1-epsilon
        correctedRate = 1-epsilon;
    elseif rate <= epsilon
        correctedRate = epsilon;
    end 