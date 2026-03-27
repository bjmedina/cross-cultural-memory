
if (isfield(PARAMS,'IS_ASK_PREFER_FEEDBACK')) && IS_ASK_PREFER_FEEDBACK
     msgt=sprintf('\n\nDid you like it more when the person was talking in headphones or when there was not talking ?: \n[Type 4 with person talking (feedback) 5 no talking (no-feedbak)] \n');
     PARAMS.do_you_prefer_feedback=msgt;
     
     msg=nan;
        while isnan(msg)
            msg=input (msgt,'s');
            msg=str2double(msg);
            if isempty(msg)
                msg=nan;
            end
            if ~((msg==4)||(msg==5))
                msg=nan;
            end
        end
        if msg==4
            PARTICIPANT_PREFER_FEEDBACK=true;
        else
            PARTICIPANT_PREFER_FEEDBACK=false;
        end
        PARAMS.PARTICIPANT_PREFER_FEEDBACK=PARTICIPANT_PREFER_FEEDBACK;
        
              save(fnameC,'RES','PARAMS');
    fprintf ('trying to save comment file %s...\n',fnameC);
    fprintf('\n\n');
end

PARTICIPANT_INPUT_FOR_CHROMA=nan;
if (isfield(PARAMS,'MALE_IS_CHROMA')) && ((~isempty(MALE_IS_CHROMA)))
    
    MALE_IS_FIRST=[];
    if MALE_IS_CHROMA && IS_CHROMA_FEEDBACK_FIRST
        MALE_IS_FIRST=true;
    end
    
    if MALE_IS_CHROMA && (~IS_CHROMA_FEEDBACK_FIRST)
        MALE_IS_FIRST=false;
    end
    
    if (~MALE_IS_CHROMA) && IS_CHROMA_FEEDBACK_FIRST
        MALE_IS_FIRST=false;
    end
    
    if (~MALE_IS_CHROMA) && (~IS_CHROMA_FEEDBACK_FIRST)
        MALE_IS_FIRST=true;
    end
    
    assert(~isempty(MALE_IS_FIRST));
    
    if IS_CHROMA_FEEDBACK_FIRST
        if MALE_IS_FIRST
            msgt=sprintf('\nWhat was eassier the first [IRIS] session 20,200 (male [SON]) or the second session 30, 300[PARA] (female [PEN]): \n[Type 1 if participant think first session (male [SON]) was eassier] \n\t\t<<3 if this the first time you run the feedback (question irrelevant)>>\n');
            PARAMS.feedback_comments=msgt;
            
        else
            msgt=sprintf('\nWhat was eassier the first [IRIS] session 20,200 (female [PEN]) or the second session 30, 300[PARA] (man [SON]): \n[Type 1 if participant think first (female [PEN]) session was eassier] \n\t\t<<3 if this the first time you run the feedback (question irrelevant)>>\n');
            PARAMS.feedback_comments=msgt;
        end
        
        msg=nan;
        while isnan(msg)
            msg=input (msgt,'s');
            msg=str2double(msg);
            if isempty(msg)
                msg=nan;
            end
            if ~((msg==1)||(msg==2)||(msg==3))
                msg=nan;
            end
        end
        
        if msg==1
            PARTICIPANT_THINK_CHROMA_EASIER=true;
        else
            PARTICIPANT_THINK_CHROMA_EASIER=false;
        end
        
        PARTICIPANT_INPUT_FOR_CHROMA=msg;
        if msg==3
            PARTICIPANT_THINK_CHROMA_EASIER=nan;
        end
        
    else
        if MALE_IS_FIRST
            msgt=sprintf('\nWhat was eassier the first [IRIS] session 30,300 (male [SON]) or the second session 20, 200 [PARA] (female [PEN]): \n[Type 1 if participant think first (male [SON]) session was eassier] \n\t\t<<3 if this the first time you run the feedback (question irrelevant)>>\n');
            PARAMS.feedback_comments=msgt;
            
        else
            msgt=sprintf('\nWhat was eassier the first [IRIS] session 30,300 (female [PEN]) or the second session 20, 200 [PARA] (man [SON]): \n[Type 1 if participant think first session (female [PEN]) was eassier] \n\t\t<<3 if this the first time you run the feedback (question irrelevant)>>\n');
            PARAMS.feedback_comments=msgt;
            
        end
        msg=nan;
        while isnan(msg)
            msg=input (msgt,'s');
            msg=str2double(msg);
            if isempty(msg)
                msg=nan;
            end
             if ~((msg==1)||(msg==2)||(msg==3))
                msg=nan;
            end
        end
        if msg==2
            PARTICIPANT_THINK_CHROMA_EASIER=true;
        else
            PARTICIPANT_THINK_CHROMA_EASIER=false;
        end
        if msg==3
            PARTICIPANT_THINK_CHROMA_EASIER=nan;
        end
        PARTICIPANT_INPUT_FOR_CHROMA=msg;
    end
    
    
    
    SPARAMS.MALE_IS_CHROMA=MALE_IS_CHROMA;
    SPARAMS.IS_CHROMA_FEEDBACK_FIRST=IS_CHROMA_FEEDBACK_FIRST;
    SPARAMS.PARTICIPANT_INPUT_FOR_CHROMA=PARTICIPANT_INPUT_FOR_CHROMA;
    SPARAMS.PARTICIPANT_THINK_CHROMA_EASIER=PARTICIPANT_THINK_CHROMA_EASIER;
    SPARAMS.MALE_IS_CHROMA=MALE_IS_CHROMA;
    SPARAMS.ORD_MASSAGE=ORD_MASSAGE;
    SPARAMS.FEEDBACK_DIRECTORY=FEEDBACK_DIRECTORY;
    SPARAMS.feedback_comments=PARAMS.feedback_comments;
    fprintf('FOR DEBUG');
    SPARAMS
    
    PARAMS.SPARAMS=SPARAMS;
  
     fprintf ('trying to save comment file with participant''s responses %s...\n',fnameC);
    save(fnameC,'RES','PARAMS');
    
    
end
if (isfield(PARAMS,'IS_ASK_NUM_TONES') && PARAMS.IS_ASK_NUM_TONES)
    msgt=sprintf('\n >>>>>>>>>>>>>  What number of tones did the subject prefer (type 2,3,4 or 5)?\n');
    SPARAMS.ask_num_question=msgt;
    
    msg=nan;
        while isnan(msg)
            msg=input (msgt,'s');
            msg=str2double(msg);
            if isempty(msg)
                msg=nan;
            end
            if ~((msg==2)||(msg==3)||(msg==4)||(msg==5))
                msg=nan;
            end
        end
        SPARAMS.ask_num_answer=msg;
        PARAMS.SPARAMS=SPARAMS;
end
    

fprintf('\n\n');
msg=input ('Please type any comments for this session (ENTER for no comments):\n','s');
fnameC;
PARAMS.general_comments=msg;
if ~isempty(msg)
    save(fnameC,'RES','PARAMS');
    fprintf ('trying to save comment file %s...\n',fnameC);
    
end

