function devs=nori_scan_soundcards
fprintf('\nPrinting all audio devices:\n-------------------------------\n');
devs=PsychPortAudio('GetDevices');
for I=1:length(devs)
    fprintf('scan devices found ''%s'' as # %d \n',devs(I).DeviceName,I);
end
% % DEV='Scarlett 2i2 USB';
% % DEVin=DEV;
% % DEVout=DEV;
% DEV='Scarlett 2i2 USB';
% DEVin=DEV;
% DEVout=DEV;
%DEVin='Built-in Microph';
%DEVout='Built-in Output';