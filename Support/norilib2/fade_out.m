function yn=fade_out(y,fs,SILENCE_TIME)
    yn=y;
    
    
    silen=round(fs*SILENCE_TIME+1); %fade in and fade out samples...
    esilen=exp(-(1:silen)*4/silen)'; %exponential decay
    if silen<size(y,1)
        %yn(1:silen,:)=y(1:silen,:).*repmat(esilen(end:(-1):1),1,size(y,2));   %beg
        yn(end:(-1):(end-silen+1),:)=y(end:(-1):(end-silen+1),:).*repmat(esilen(end:(-1):1),1,size(y,2)); %end
    end
   