function [notes,isi,durations]=SYNTH_str2simpleR(str,isi0)

if isempty(isi0)
    isi0=500;
end
sp=strsplit(str,',');
notes=cell(1,length(sp));
isi=ones(1,length(sp))*isi0;
durations=ones(1,length(sp))*isi0;
my_isi=isi0;
my_dir=0;
mytim_idx=0;

NAMES='CDEFGAB';
ACC='b#';
shft=[-1,1];
REG='123456789';
TIM='*\dtqQS';

nums =[24,26,28,29,31,33,35];
myreg=nan;
for I=1:length(sp)
    spl=strsplit(sp{I},'-');
    
    
    vec=nan(1,length(spl));
    for J=1:length(spl)
        mynote=nan;myacc=0;
        str=spl{J};
        for k=1:length(str)
            
            
            if ~isempty(strfind(NAMES,str(k)))
                mynote=nums(strfind(NAMES,str(k)));
            end
            if ~isempty(strfind(REG,str(k)))
                myreg=(strfind(REG,str(k))-1)*12;
            end
            if ~isempty(strfind(ACC,str(k)))
                myacc=shft(strfind(ACC,str(k)));
            end
            if ~isempty(strfind(TIM,str(k)))
                mytim_idx=strfind(TIM,str(k));
                if mytim_idx==1
                    my_dir=1;
                end
                if mytim_idx==2
                    my_dir=-1;
                end
            end
        end
        
        mymidi=mynote+myreg+myacc;
        assert(~isnan(mymidi));
        vec(J)=mymidi;
        
        
        if mytim_idx>=3
            if my_dir==1
                my_isi=my_isi/(mytim_idx-1);
                my_dir=0;
            end
            if my_dir==-1
                my_isi=my_isi*(mytim_idx-1);
                my_dir=0;
            end
        end
        
        
    end
    notes{I}=vec;
    
    isi(I)=my_isi;
    durations(I)=my_isi;
    
    
end

