function writeheader(fid,header,formatstring,varargin)

% function writeheader(fid,header,formatstring,varargin)
% 
% Writes a head for a column file.
% 
% -- Example: 3-Column header  --
% 
% % header names
% header = {'Name','Age','Height'}; 
% 
% % formatting string, e.g. help fprintf, the type
% % information is ignored and just the spacing is used
% formatstring = '%12s%12d%12.2f\n'; 
% 
% % file id
% fid = fopen('example-3column-header.txt','w'); % file id
% 
% % adding the 'command' argument causes the header to also be displayed in
% % the command window
% writeheader(fid, header, formatstring, 'command');
% 
% % write some data to file and command window
% fprintf(     formatstring, 'John', 24, 55.2);
% fprintf(fid, formatstring, 'John', 24, 55.2);
% 
% % close file
% fclose(fid);
% 
% Commented by Sam Norman-Haignere on 2015-06-24
    
x = regexprep(formatstring,'[df]','s');
y = regexprep(x,'\.\d','');
fprintf(fid, y, header{:});
if optInputs(varargin,'command')
    fprintf(y, header{:});
end

%
% z = regexp(y,'\%[\-\w\.]*','match');
% 
% keyboard;
% 
% for j = 1:length(z)
%     fprintf(fid, z{j}, header{j});
%     if optInputs(varargin,'command')
%         fprintf(z{j}, header{j});
%     end
% end

% fprintf(fid,'\n');
% if optInputs(varargin,'command')
%     fprintf('\n');
% end


