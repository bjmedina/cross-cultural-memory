function notes=SYNTH_str2simple(str)

sp=strsplit(str,',');
notes=cell(1,length(sp));

NAMES='CDEFGAB';
ACC='b#';
shft=[-1,1];
REG='123456789';
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
        end
        mymidi=mynote+myreg+myacc;
        assert(~isnan(mymidi));
        vec(J)=mymidi;
    end
    notes{I}=vec;
    
    
end

