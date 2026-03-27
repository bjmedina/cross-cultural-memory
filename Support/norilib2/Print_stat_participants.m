function msg=Print_stat_participants(SUBJn)
    dtrain=dir (sprintf('SUMMARY*train*%s*',SUBJn));
    dtest=dir (sprintf('SUMMARY*test*%s*',SUBJn));
    dtrain2=dir (sprintf('SUMMARY*train*',SUBJn));
    dtest2=dir (sprintf('SUMMARY*test*',SUBJn));
    msg=sprintf('For participant %s, there are: %3d train files and %3d test files.\t [Today thus far we have: %3d train files and %3d test files]\n',SUBJn,length(dtrain),length(dtest),length(dtrain2),length(dtest2) );
    fprintf('%s',msg);

