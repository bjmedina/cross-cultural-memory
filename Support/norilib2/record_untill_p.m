function [y,fs]=record_untill_p()
fs=44100;
fs1=22050;
r = audiorecorder(fs, 16, 1);
record(r);

mkey=1;
fprintf('RECORDING: Press "p" to stop recording... \n');
while (mkey~=999)
    [ ~, ~, keyCode ] = KbCheck;
    
    mkey= find(keyCode,1);
    %fprintf('%d\n',mkey);
    if isempty(mkey)
        mkey=1;
    end
    if mkey==19
        break
    end
end
fprintf('\n');
mySpeech = getaudiodata(r, 'int16');
mySpeech=double(mySpeech);
stop(r);

y=resample(mySpeech,fs1,fs);
fs=fs1;
figure(1);clf;
plot(1:length(mySpeech),mySpeech);
fprintf('Finished recording....\n');
