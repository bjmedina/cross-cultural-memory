function SUBJn=get_subject_name()
prompt = {'Subject name:'};
mtitle = 'Subject name';
lines = 1;
def = {'XXXX9999'};
answer = inputdlg(prompt,mtitle,lines,def);
if ~isempty(answer)
    subName = answer{1};
    
else
    fprintf('no subject!\n');
    assert(1==0);
end
SUBJn=subName;