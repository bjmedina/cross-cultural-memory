fdir='~/reSearchColumbia/EXPERIMENTS17bolivia/experiments/WORLD-JUL2017-ITER-EXPERIMENT/sofar';
%fdir='~/reSearchColumbia/EXPERIMENTS17bolivia/experiments/WORLD-JUL2017-ITER-EXPERIMENT/tapping-28july17-backup-both';
fdir='~/reSearchColumbia/EXPERIMENTS17bolivia/experiments/WORLD-JUL2017-ITER-EXPERIMENT/EXPiter-29-Jul-2017';





cd (fdir)
adir=dir ('SUMMARY*test*mat');
dnc=[];
cntm=0;
for I=1:length(adir)
    fname=adir(I).name;
   mdata=load(fname);
   dnc=[dnc,mdata.ALL{1}.cnt_do_not_change];
   fprintf('fname %s dnc= %d\n',fname,mdata.ALL{1}.cnt_do_not_change);
   
   if isempty(mdata.ALL{1}.data{5})
       continue
   end
   
   if isempty(mdata.ALL{1}.data{4})
       continue
   end
       
   if sum(~isnan(sum(mdata.ALL{1}.data{5}.Rm,2)))>2 ||sum(~isnan(sum(mdata.ALL{1}.data{4}.Rm,2)))>2
    cntm=cntm+1;
   end
end

length(adir)
sum(dnc<3)
cntm

