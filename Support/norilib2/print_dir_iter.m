%%%% this script reads a direcotry of choice and create a summary text file
%%%% of the data (text_data_file.txt)

selpath = uigetdir(); % get direcotry for analysis from the UI
fseed='SUMMARY*.mat';
tfname='text_data_file.txt';
FID=fopen(tfname,'w');

adir=dir(fseed);
data=cell(length(adir),1);
for I=1:length(adir)
    fname=adir(I).name;
    fprintf('loading: %s\n',fname);
    data{I}=load(fname);
end

for I=1:length(data)
    
    mdata=data{I}.ALL{1};
    fname=adir(I).name;
    
    fprintf(FID,'Filename: %s\n',fname); %FID
    for l=1:length(mdata.data)
        if isempty(mdata.data{l})
            fprintf(FID,'Iteration %d of %d <failed> \t\t',l,length(mdata.data));
            continue
        end
        miter=mdata.data{l};
    
        fprintf(FID,'Iteration %d of %d stimulus: \t\t',l,length(mdata.data));
        for kk=1:size(mdata.data{l}.Sm,2)
            fprintf(FID,'%5.5g\t', mdata.data{l}.Sm(1,kk));
        end
        fprintf(FID,'\n');
        
        for jj=1:size(mdata.data{l}.Rm,1)
            fprintf(FID,'Response iteration %3d: \t',jj);
            for kk=1:size(mdata.data{l}.Rm,2)
                 fprintf(FID,'%5.5g\t\t', mdata.data{l}.Rm(jj,kk));
            end
            fprintf(FID,'\n');
        end
        
        fprintf(FID,'Averaged interpolated response: \t\t');
        for kk=1:length(mdata.data{l}.RM)
            fprintf(FID,'%5.5g\t', mdata.data{l}.RM(kk));
        end
        fprintf(FID,'\n\n');
    end
end

fclose(FID);
fprintf('Done! Wrote to file: %s in directory: %s\n',tfname,selpath);
