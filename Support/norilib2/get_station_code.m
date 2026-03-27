function [my_station]=get_station_code(fname)
%  COMPUTER_COLOR := {BLACK, BLUE, CYAN, GREEN, ORANGE, PURPLE, RED, YELLOW}
% 
%     example: tf-mcdermott-bolivia-BLACK-07-03-18-earL.mat
% 
% 2) computer + soundcard + USB cable + adapter jack + headphone pair
%     COMPUTER_COLOR := {BLACK, BLUE, CYAN, GREEN, ORANGE, PURPLE, RED, YELLOW}-Soundcard

prompt = {'Please choose station: [Black/CHARTREUSE/CYAN/GREEN/GREY/MAHOGANY/ORANGE][-Soundcard]'};
mtitle = 'Station code';
lines = 1;
adir=dir(fname);
mdate=date();
if isempty(adir)
    
    def = {sprintf('XXXX')};
else
    dat=load(fname);
    
    if strcmp(mdate,dat.mdate) % once a day
        def = {dat.STATION};
    else
        def = {sprintf('XXXX PLEASE CHOOSE STATION XXX')};
    end
    
end

answer = inputdlg(prompt,mtitle,lines,def);
if ~isempty(answer)
    my_station = answer{1};
    
else
    fprintf('no input of a station! try again...\n');
    assert(1==0);
end

possible_colors={'BLACK', 'BLUE', 'CYAN', 'GREEN', 'ORANGE', 'PURPLE', 'RED', 'YELLOW', 'GREY', 'MAHOGANY', 'CHARTREUSE'};
possible_types={'','-Soundcard'};
is_found=false;
for cc=1:length(possible_colors)
    for tt=1:length(possible_types)
        val=sprintf('%s%s',possible_colors{cc},possible_types{tt});
        if strcmp(my_station,val)
            is_found=true;
            break
        end
    end
    if strcmp(my_station,val)
        is_found=true;
        break
    end
end
cnt=0;
if ~is_found
    
    fprintf("ERROR: Did not find station name... Here are all possible stations:\n");
    for cc=1:length(possible_colors)
        for tt=1:length(possible_types)
            val=sprintf('%s%s',possible_colors{cc},possible_types{tt});
            cnt=cnt+1;
            fprintf('Station %2d: %s\n',cnt,val);
        end
    end
    assert(1==0);
else
    STATION=my_station;
    save(fname,'STATION','mdate');
end