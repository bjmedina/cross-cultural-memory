function [SUBJn,gender]=get_subject_name_last_force(fname,IS_FORCE_NEW)
rng('shuffle'); %in every experiment where random conditions are introduced in matlab this should be ON!

prompt = {'Subject name:'};
mtitle = 'Subject name';
lines = 1;

if isempty(adir)|| IS_FORCE_NEW
    UUID=randi(10000-1000-1)+1000; %randomize UUID for the output file
    def = {sprintf('XXXX9999%d',UUID)};
else
    dat=load(fname);
    def = {dat.SUBJn};
end
answer = inputdlg(prompt,mtitle,lines,def);
if ~isempty(answer)
    subName = answer{1};
    
else
    fprintf('no subject!\n');
    assert(1==0);
end
SUBJn=subName;

if (isempty(adir)) || (~strcmp(SUBJn,dat.SUBJn))
    gender=input('Please, type participants''s gender: (1) Female (2) Male: ');
else
    gender=dat.gender;
    GENDERS={'female','male'};
    fprintf('Note: participant: %s have a saved gender: %s\n',SUBJn,GENDERS{gender});
end
save(fname,'SUBJn','gender');