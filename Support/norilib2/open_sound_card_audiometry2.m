function pout=open_sound_card_audiometry2(NOTTHISDEV)
bit_depth = 16;
nchannels = 2;

verbosity=-1;
Screen('Preference','SuppressAllWarnings', 1);


if verbosity>=1
    fprintf('Initializing sound card...\n');
end
InitializePsychSound();
devs=PsychPortAudio('GetDevices');
isfound=false;
for I=1:length(devs)
    if verbosity>=1
        fprintf('scan devices found %s as # %d (searching for %s)\n',devs(I).DeviceName,I,NOTTHISDEV);
    end
    if strcmp(strrep(devs(I).DeviceName,' ',''),strrep(NOTTHISDEV,' ','')) && (devs(I).NrOutputChannels>0)
        mydev=devs(I).DeviceIndex;
        fs=devs(I).DefaultSampleRate;
        if verbosity>=1
            fprintf('found device %s as device index %d\n',devs(I).DeviceName,mydev);
        end
        isfound=true;
        
        break;
    end
end
if isfound
    fprintf('\n\n ********<><><>><<>><<><><><>\n TO RUN AUDIOMETRY DISCONNECT THIS DEVICE: %s \n********<><><>><<>><<><><><>\n\n\n\n',NOTTHISDEV);
    assert(1==0);
end

fs=44100;
pout = PsychPortAudio('Open',[], [], 0, fs, nchannels);
