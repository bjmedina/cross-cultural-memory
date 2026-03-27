function file_with_plus = fileplus(file)

% function file_with_plus = fileplus(file)
% 
% If file alrealdy exists, this function returns a file with a plus
% appended to the end of the file, e.g. file+.extension. If file+.extension
% also exists, it returns file++.extension, and so on. Useful for not
% overwriting files.
% 
% Last modified by Sam Norman-Haignere on 2015-06-24

while 1
    if exist(file,'file');
        s = regexp(file,'[.]','split');
        if length(s)==1
            file = [file '+']; %#ok<AGROW>
        else
            file = [cat(2,s{1:end-1}) '+.' s{end}];
        end        
    else
        file_with_plus = file;
        break;
    end
end


