function baseShifter = doNothingShifter(dataStructure)
%   baseShifter = doNothingShifter(dataStructure)

%   Dummy shifter for sinusoidal models and cross synthesis
%   Designed and coded by Hideki Kawahara
%   26/Mar./2012

fftl = (size(dataStructure.spectrogramSTRAIGHT,1)-1)*2;
baseShifter = zeros(fftl,1);
return;