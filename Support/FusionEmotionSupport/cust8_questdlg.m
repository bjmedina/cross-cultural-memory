function ButtonName=cust8_questdlg(Question,Title,Btn1,Btn2,Btn3,Btn4,Btn5,Btn6,Btn7,Btn8,Default)

%customized version of questdlg to include 7 buttons rather than 3

%QUESTDLG Question dialog box.
%  ButtonName=QUESTDLG(Question) creates a modal dialog box that
%  automatically wraps the cell array or string (vector or matrix)
%  Question to fit an appropriately sized window.  The name of the
%  button that is pressed is returned in ButtonName.  The Title of
%  the figure may be specified by adding a second string argument.
%  Question will be interpreted as a normal string.
%
%  QUESTDLG uses UIWAIT to suspend execution until the user responds.
%
%  The default set of buttons names for QUESTDLG are 'Yes','No' and
%  'Cancel'.  The default answer for the above calling syntax is 'Yes'.
%  This can be changed by adding a third argument which specifies the
%  default Button.  i.e. ButtonName=questdlg(Question,Title,'No').
%
%  Up to 3 custom button names may be specified by entering
%  the button string name(s) as additional arguments to the function
%  call.  If custom ButtonName's are entered, the default ButtonName
%  must be specified by adding an extra argument DEFAULT, i.e.
%
%    ButtonName=questdlg(Question,Title,Btn1,Btn2,DEFAULT);
%
%  where DEFAULT=Btn1.  This makes Btn1 the default answer. If the
%  DEFAULT string does not match any of the button string names, a
%  warning message is displayed.
%
%  To use TeX interpretation for the Question string, a data
%  structure must be used for the last argument, i.e.
%
%    ButtonName=questdlg(Question,Title,Btn1,Btn2,OPTIONS);
%
%  The OPTIONS structure must include the fields Default and Interpreter.
%  Interpreter may be 'none' or 'tex' and Default is the default button
%  name to be used.
%
%  If the dialog is closed without a valid selection, the return value
%  is empty.
%
%  Example:
%
%  ButtonName=questdlg('What is your wish?', ...
%                      'Genie Question', ...
%                      'Food','Clothing','Money','Money');
%
%
%  switch ButtonName,
%    case 'Food',
%     disp('Food is delivered');
%    case 'Clothing',
%     disp('The Emperor''s  new clothes have arrived.')
%     case 'Money',
%      disp('A ton of money falls out the sky.');
%  end % switch
%
%  See also TEXTWRAP, INPUTDLG.

%  Copyright 1984-2005 The MathWorks, Inc.
%  $Revision: 5.55.4.8 $

if nargin<9,error('Too few arguments for CUST7_QUESTDLG');end

Interpreter='none';
if ~iscell(Question),Question=cellstr(Question);end

%%%%%%%%%%%%%%%%%%%%%
%%% General Info. %%%
%%%%%%%%%%%%%%%%%%%%%
Black      =[0       0        0      ]/255;
LightGray  =[192     192      192    ]/255;
LightGray2 =[160     160      164    ]/255;
MediumGray =[128     128      128    ]/255;
White      =[255     255      255    ]/255;

%%%%%%%%%%%%%%%%%%%%
%%% Nargin Check %%%
%%%%%%%%%%%%%%%%%%%%

if nargout>1,error('Wrong number of output arguments for CUST_QUESTDLG');end
if nargin>10, error('Too many input arguments');NumButtons=8;end

NumButtons=8;
Default=Btn4;

if isstruct(Default),
    Interpreter=Default.Interpreter;
    Default=Default.Default;
end


%%%%%%%%%%%%%%%%%%%%%%%
%%% Create QuestFig %%%
%%%%%%%%%%%%%%%%%%%%%%%
FigPos    = get(0,'DefaultFigurePosition');
FigPos(3) = 267;
FigPos(4) =  70;
FigPos    = getnicedialoglocation(FigPos, get(0,'DefaultFigureUnits'));

QuestFig=dialog(                                    ...
    'Visible'         ,'off'                      , ...
    'Name'            ,Title                      , ...
    'Pointer'         ,'arrow'                    , ...
    'Position'        ,FigPos                     , ...
    'KeyPressFcn'     ,@doFigureKeyPress          , ...
    'IntegerHandle'   ,'off'                      , ...
    'WindowStyle'     ,'normal'                   , ...
    'HandleVisibility','callback'                 , ...
    'CloseRequestFcn' ,@doDelete                  , ...
    'Tag'             ,Title                        ...
    );

%%%%%%%%%%%%%%%%%%%%%
%%% Set Positions %%%
%%%%%%%%%%%%%%%%%%%%%
DefOffset  =10;

IconWidth  =54;
IconHeight =54;
IconXOffset=DefOffset;
IconYOffset=FigPos(4)-DefOffset-IconHeight;
IconCMap=[Black;get(QuestFig,'Color')];

DefBtnWidth =56;
BtnHeight   =22;

BtnYOffset=DefOffset;

BtnWidth=DefBtnWidth;

ExtControl=uicontrol(QuestFig   , ...
    'Style'    ,'pushbutton', ...
    'String'   ,' '          ...
    );

btnMargin=1.4;
set(ExtControl,'String',Btn1);
BtnExtent=get(ExtControl,'Extent');
BtnWidth=max(BtnWidth,BtnExtent(3)+8);

set(ExtControl,'String',Btn2);
BtnExtent=get(ExtControl,'Extent');
BtnWidth=max(BtnWidth,BtnExtent(3)+8);

set(ExtControl,'String',Btn3);
BtnExtent=get(ExtControl,'Extent');
BtnWidth=max(BtnWidth,BtnExtent(3)*btnMargin);

set(ExtControl,'String',Btn4);
BtnExtent=get(ExtControl,'Extent');
BtnWidth=max(BtnWidth,BtnExtent(3)*btnMargin);

set(ExtControl,'String',Btn5);
BtnExtent=get(ExtControl,'Extent');
BtnWidth=max(BtnWidth,BtnExtent(3)*btnMargin);

set(ExtControl,'String',Btn6);
BtnExtent=get(ExtControl,'Extent');
BtnWidth=max(BtnWidth,BtnExtent(3)*btnMargin);

set(ExtControl,'String',Btn7);
BtnExtent=get(ExtControl,'Extent');
BtnWidth=max(BtnWidth,BtnExtent(3)*btnMargin);

set(ExtControl,'String',Btn8);
BtnExtent=get(ExtControl,'Extent');
BtnWidth=max(BtnWidth,BtnExtent(3)*btnMargin);
BtnHeight = max(BtnHeight,BtnExtent(4)*btnMargin);

delete(ExtControl);

MsgTxtXOffset=IconXOffset+IconWidth;

FigPos(3)=max(FigPos(3),MsgTxtXOffset+NumButtons*(BtnWidth+2*DefOffset));
set(QuestFig,'Position',FigPos);

BtnXOffset=zeros(NumButtons,1);

BtnXOffset=[MsgTxtXOffset 0 0 0 0 0 0 (FigPos(3)-DefOffset-BtnWidth)];
BtnXOffset(4)=(BtnXOffset(1)+BtnXOffset(8))/2;
BtnXOffset(2)=(BtnXOffset(1)+(BtnXOffset(8)-BtnXOffset(1))/6);
BtnXOffset(3)=(BtnXOffset(1)+(BtnXOffset(8)-BtnXOffset(1))/6*2);
BtnXOffset(5)=(BtnXOffset(1)+(BtnXOffset(8)-BtnXOffset(1))/6*4);
BtnXOffset(6)=(BtnXOffset(1)+(BtnXOffset(8)-BtnXOffset(1))/6*5);

MsgTxtYOffset=DefOffset+BtnYOffset+BtnHeight;
MsgTxtWidth=FigPos(3)-DefOffset-MsgTxtXOffset-IconWidth;
MsgTxtHeight=FigPos(4)-DefOffset-MsgTxtYOffset;
MsgTxtForeClr=Black;
MsgTxtBackClr=get(QuestFig,'Color');

CBString='uiresume(gcbf)';
DefaultValid = false;
DefaultWasPressed = false;
BtnHandle = [];
DefaultButton = 0;

% Check to see if the Default string passed does match one of the
% strings on the buttons in the dialog. If not, throw a warning.
for i = 1:NumButtons
    switch i
        case 1
            ButtonString=Btn1;
            ButtonTag='Btn1';
            if strcmp(ButtonString, Default)
                DefaultValid = true;
                DefaultButton = 1;
            end

        case 2
            ButtonString=Btn2;
            ButtonTag='Btn2';
            if strcmp(ButtonString, Default)
                DefaultValid = true;
                DefaultButton = 2;
            end
        case 3
            ButtonString=Btn3;
            ButtonTag='Btn3';
            if strcmp(ButtonString, Default)
                DefaultValid = true;
                DefaultButton = 3;
            end
        case 4
            ButtonString=Btn4;
            ButtonTag='Btn4';
            if strcmp(ButtonString, Default)
                DefaultValid = true;
                DefaultButton = 4;
            end
        case 5
            ButtonString=Btn5;
            ButtonTag='Btn5';
            if strcmp(ButtonString, Default)
                DefaultValid = true;
                DefaultButton = 5;
            end
        case 6
            ButtonString=Btn6;
            ButtonTag='Btn6';
            if strcmp(ButtonString, Default)
                DefaultValid = true;
                DefaultButton = 6;
            end
        case 7
            ButtonString=Btn7;
            ButtonTag='Btn7';
            if strcmp(ButtonString, Default)
                DefaultValid = true;
                DefaultButton = 7;
            end
            
             case 8
            ButtonString=Btn8;
            ButtonTag='Btn8';
            if strcmp(ButtonString, Default)
                DefaultValid = true;
                DefaultButton = 8;
            end
    end

    BtnHandle(end+1)=uicontrol(QuestFig            , ...
        'Style'              ,'pushbutton', ...
        'Position'           ,[ BtnXOffset(1) BtnYOffset BtnWidth BtnHeight ]           , ...
        'KeyPressFcn'        ,@doControlKeyPress , ...
        'CallBack'           ,CBString    , ...
        'String'             ,ButtonString, ...
        'HorizontalAlignment','center'    , ...
        'Tag'                ,ButtonTag     ...
        );
end

if ~DefaultValid
    warnstate = warning('backtrace','off');
    warning('MATLAB:QUESTDLG:stringMismatch','Default string does not match any button string name.');
    warning(warnstate);
end

MsgHandle=uicontrol(QuestFig            , ...
    'Style'              ,'text'         , ...
    'Position'           ,[MsgTxtXOffset MsgTxtYOffset 0.95*MsgTxtWidth MsgTxtHeight ]              , ...
    'String'             ,{' '}          , ...
    'Tag'                ,'Question'     , ...
    'HorizontalAlignment','left'         , ...
    'FontWeight'         ,'bold'         , ...
    'BackgroundColor'    ,MsgTxtBackClr  , ...
    'ForegroundColor'    ,MsgTxtForeClr    ...
    );

[WrapString,NewMsgTxtPos]=textwrap(MsgHandle,Question,75);

NumLines=size(WrapString,1);

% The +2 is to add some slop for the border of the control.
MsgTxtWidth=max(MsgTxtWidth,NewMsgTxtPos(3)+2);
MsgTxtHeight=NewMsgTxtPos(4)+2;

MsgTxtXOffset=IconXOffset+IconWidth+DefOffset;
FigPos(3)=max(NumButtons*(BtnWidth+DefOffset)+DefOffset, ...
    MsgTxtXOffset+MsgTxtWidth+DefOffset);


% Center Vertically around icon
if IconHeight>MsgTxtHeight,
    IconYOffset=BtnYOffset+BtnHeight+DefOffset;
    MsgTxtYOffset=IconYOffset+(IconHeight-MsgTxtHeight)/2;
    FigPos(4)=IconYOffset+IconHeight+DefOffset;
    % center around text
else,
    MsgTxtYOffset=BtnYOffset+BtnHeight+DefOffset;
    IconYOffset=MsgTxtYOffset+(MsgTxtHeight-IconHeight)/2;
    FigPos(4)=MsgTxtYOffset+MsgTxtHeight+DefOffset;
end


    BtnXOffset(4)=(FigPos(3)-BtnWidth)/2;
    BtnXOffset=[BtnXOffset(4)-3*DefOffset-3*BtnWidth
        BtnXOffset(4)-2*DefOffset-2*BtnWidth
        BtnXOffset(4)-DefOffset-BtnWidth
        BtnXOffset(4)
        BtnXOffset(4)+BtnWidth+DefOffset
        BtnXOffset(4)+2*BtnWidth+2*DefOffset
        BtnXOffset(4)+3*BtnWidth+3*DefOffset
        ];


set(QuestFig ,'Position',getnicedialoglocation(FigPos, get(QuestFig,'Units')));

BtnPos=get(BtnHandle,{'Position'});
BtnPos=cat(1,BtnPos{:});
BtnPos(:,1)=BtnXOffset;
BtnPos=num2cell(BtnPos,2);
set(BtnHandle,{'Position'},BtnPos);

if DefaultValid
    setdefaultbutton(QuestFig, BtnHandle(DefaultButton));
end

delete(MsgHandle);

AxesHandle=axes('Parent',QuestFig,'Position',[0 0 1 1],'Visible','off');

MsgHandle=text( ...
    'Parent'              ,AxesHandle                      , ...
    'Units'               ,'pixels'                        , ...
    'Color'               ,get(BtnHandle(1),'ForegroundColor')   , ...
    'HorizontalAlignment' ,'left'                          , ...
    'FontName'            ,get(BtnHandle(1),'FontName')    , ...
    'FontSize'            ,get(BtnHandle(1),'FontSize')    , ...
    'VerticalAlignment'   ,'bottom'                        , ...
    'Position'            ,[MsgTxtXOffset MsgTxtYOffset 0] , ...
    'String'              ,WrapString                      , ...
    'Interpreter'         ,Interpreter                     , ...
    'Tag'                 ,'Question'                        ...
    );

IconAxes=axes(                                      ...
    'Parent'      ,QuestFig              , ...
    'Units'       ,'Pixels'              , ...
    'Position'    ,[IconXOffset IconYOffset IconWidth IconHeight], ...
    'NextPlot'    ,'replace'             , ...
    'Tag'         ,'IconAxes'              ...
    );

set(QuestFig ,'NextPlot','add');

load dialogicons.mat questIconData questIconMap;
IconData=questIconData;
questIconMap(256,:)=get(QuestFig,'color');
IconCMap=questIconMap;

Img=image('CData',IconData,'Parent',IconAxes);
set(QuestFig, 'Colormap', IconCMap);
set(IconAxes, ...
    'Visible','off'           , ...
    'YDir'   ,'reverse'       , ...
    'XLim'   ,get(Img,'XData'), ...
    'YLim'   ,get(Img,'YData')  ...
    );

% make sure we are on screen
movegui(QuestFig)


set(QuestFig ,'WindowStyle','modal','Visible','on');
drawnow;
if DefaultButton ~= 0
    uicontrol(BtnHandle(DefaultButton));
end

uiwait(QuestFig);

if ishandle(QuestFig)
    if DefaultWasPressed
        ButtonName=Default;
    else
        ButtonName=get(get(QuestFig,'CurrentObject'),'String');
    end
    doDelete;
else
    ButtonName='';
end

    function doFigureKeyPress(obj, evd)
        switch(evd.Key)
            case {'return','space'}
                if DefaultValid
                    DefaultWasPressed = true;
                    uiresume(gcbf);
                end
            case 'escape'
                doDelete
        end
    end

    function doControlKeyPress(obj, evd)
        switch(evd.Key)
            case {'return'}
                if DefaultValid
                    DefaultWasPressed = true;
                    uiresume(gcbf);
                end
            case 'escape'
                doDelete
        end

    end

    function doDelete(varargin)
        delete(QuestFig);
    end
end
