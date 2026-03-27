function EXPERn=get_experimenter_name()
rng('shuffle'); %in every experiment where random conditions are introduced in matlab this should be ON!

prompt = {'Experimenter name is required for this condition:'};
mtitle = 'Experimenter name';
lines = 1;
UUID=randi(10000-1000-1)+1000; %randomize UUID for the output file
%def = {sprintf('XXXX9999%d',UUID)};
def = {'Malinda'};

answer = inputdlg(prompt,mtitle,lines,def);
if ~isempty(answer)
    subName = answer{1};
    
else
    fprintf('no expeirmnted specified, can not continue!\n');
    assert(1==0);
end
EXPERn=subName;