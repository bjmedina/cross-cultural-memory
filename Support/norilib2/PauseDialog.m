function PauseDialog(MTIME)
tic();

if ispc()
    KEYPAUSE=32;
    KEYENTER=13;    
else
    KEYPAUSE=44;
    KEYENTER=19;
end

FlushEvents()

commandwindow
MCHOICE='continue';
fprintf('Press space for pause, ENTER for continue (will continue in %g secs...)\n',MTIME);
while toc()<MTIME
    [keyIsDown, secs, keyCode, deltaSecs] = KbCheck();
    if keyIsDown
        mchar=find(keyCode);
        
        if (sum(mchar==KEYPAUSE)==length(mchar))
            MCHOICE='pause';
            break
        elseif (sum(mchar==KEYENTER)==length(mchar))
            
            MCHOICE='continue';
            break
        end
        
    end
end
if strcmp(MCHOICE,'pause')
    commandwindow
    fprintf('Pause: press ENTER to continue\n');
    pause
else
    fprintf('CONTINUE!\n');
end

end