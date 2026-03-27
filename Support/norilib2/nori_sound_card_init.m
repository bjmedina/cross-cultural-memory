%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Nori Jacoby's audio library
% Please don't use it without Nori's permision...
% For more information please contact: nori.viola@gmail.com
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function context=nori_sound_card_init(DEV)
context=[];
verbosity=5;
Screen('Preference','SuppressAllWarnings', 1);


if (nargin<1)||(isempty(DEV))
    DEV='Scarlett 2i2 USB'; %find the device.
    DEV_input='Scarlett 2i2 USB';
end

if iscell(DEV) && (length(DEV)==2)
    DEV_input=DEV{2};
    DEV=DEV{1};
end
    
if (length(DEV)==1) && isnan(DEV)
    DEV='Built-in Output'; %find audio output (normal)
    DEV_input='Built-in Microph';
end

%BEG=0.5; % limit output file length


repetitions=1; %repeat once audio file


if verbosity>=1
    fprintf('Initializing sound card...\n');
end
InitializePsychSound();


devs=PsychPortAudio('GetDevices');
isfound=false;
if verbosity>=1
    fprintf('Search for output sound card...\n');
end
for I=1:length(devs)
    if verbosity>=1
        fprintf('scan devices found %s as # %d (searching for %s)\n',devs(I).DeviceName,I,DEV);
    end
    if strcmp(devs(I).DeviceName,DEV)
        mydev=devs(I).DeviceIndex;
        context.fs=devs(I).DefaultSampleRate;
        if verbosity>=1
            fprintf('found device %s as device index %d\n',devs(I).DeviceName,mydev);
        end
        isfound=true;
        break;
    end
end
if ~isfound
    fprintf('did not find the proper device %s ',DEV);
    assert(1==0);
end

if verbosity>=1
    fprintf('Search for input sound card...\n');
end
isfound=false;
for I=1:length(devs)
    if verbosity>=1
        fprintf('scan devices found %s as # %d (searching for %s)\n',devs(I).DeviceName,I,DEV_input);
    end
    if strcmp(devs(I).DeviceName,DEV_input)
        mydev_input=devs(I).DeviceIndex;
        context.fs=devs(I).DefaultSampleRate;
        if verbosity>=1
            fprintf('found device %s as device index %d\n',devs(I).DeviceName,mydev_input);
        end
        isfound=true;
        break;
    end
end
if ~isfound
    fprintf('did not find the proper device %s ',DEV_input);
    assert(1==0);
end


if verbosity>=1
    fprintf('prepare audio...\n');
end


nrchannels=2;


% open two channels for input and output
pout = PsychPortAudio('Open',mydev, [], 0, context.fs, nrchannels);
%pin= PsychPortAudio('Open',mydev, 2, 0, fs, nrchannels);
% Preallocate an internal audio recording  buffer with a capacity of 10 seconds:
%PsychPortAudio('GetAudioData', pin, 10);
pin= PsychPortAudio('Open',mydev_input, 2, 0, context.fs, nrchannels);

context.pout=pout;
context.pin=pin;
context.devs=devs;
context.verbosity=-1;
context.mydev=mydev;
context.mydev_input=mydev_input;
context.nrchannels=nrchannels;
context.BEG=0.1;

%context.fs=fs;



