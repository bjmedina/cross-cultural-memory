% CLICKorBEEP is 1 for click and 2 for beep
function clicksound=calc_click(CLICKorBEEP,FS)
doCLICK=1;
doBEEP=2;

if isempty(FS)
    FS=44100;
end

    if CLICKorBEEP==doCLICK
        %[clicksound,fs]=wavread('click01.wav');
        [clicksound,fs]=audioread('click01.wav');
        clicksound=resample(clicksound,FS,fs);
    elseif CLICKorBEEP==doBEEP
        fq=1000;
        clicksound=generatebeep(FS,10,45,10,fq);    
    
    elseif (CLICKorBEEP>=30) && (CLICKorBEEP<=120) %one sound with midi note
        midi=CLICKorBEEP;
        vel=100;
        duration=65;
       
        P=[];P.atk=10;P.dec=10;
        clicksound=SYNTH_make_note_pure(midi,vel,duration,FS,P);
        
        
    elseif (CLICKorBEEP>=1030) && (CLICKorBEEP<=1120) %two sound with midi notes
        midi=CLICKorBEEP-1000;
        vel=100;
        duration=65;
        P=[];P.atk=10;P.dec=10;
        
        clicksound1=SYNTH_make_note_pure(midi,vel,duration,FS,P);
        clicksound2=SYNTH_make_note_pure(midi-4,vel,duration,FS,P);
        clicksound3=SYNTH_make_note_pure(midi-8,vel,duration,FS,P);
        clicksound=0.5*clicksound1+clicksound2+clicksound3;
        

    else
        fprintf('wrong click type!\n');
        assert(1==0);
    end
    
    myrms=rms(clicksound);
    clicksound=0.8*(clicksound/myrms);
end