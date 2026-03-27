function audiout=generatebeep(FS,attack,hold,release,freq)


N=floor(FS*(attack+hold+release)/1000);
y=0.95*sin(2*pi*(1:N)*freq/FS);
fadin=floor(FS*attack/1000);
y(1:fadin)=y(1:fadin).*((1:fadin)/fadin);
fadout=floor(FS*release/1000);
y((N-fadout+1):N)=y((N-fadout+1):N).*((fadout:-1:1)/fadout);

audiout=y;

end



