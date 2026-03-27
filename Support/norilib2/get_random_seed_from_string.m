function num=get_random_seed_from_string(SUBJn,nmod)

DATE_STRING=date();
p1=295075153;
p2=1277;
p3=15187;

c=1+sum(DATE_STRING)+1+7+length(SUBJn)*p2;
for l=1:length(SUBJn)
    c=c*p2+(SUBJn(l))*p3+3 ;
    c=mod(c,p1);
end
c=c+length(SUBJn)*p2+sum(SUBJn);
c=mod(c,p1)+1;
num=c;
if ~isempty(nmod)
    num=mod(num,nmod)+1;
end