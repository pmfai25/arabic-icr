function RecState = ProcessNewPoint(RecParams,RecState,Sequence,IsMouseUp,UI )
%PROCESSNEWPOINT Summary of this function goes here
%   Detailed explanation goes here
global gUI;
gUI = UI;

Alg = RecParams.Alg;
CurrPoint = length(Sequence);
RecState.Sequence=Sequence;

if(IsMouseUp==true)
    if (RecState.LCCPI == 0)
        if (~isempty(RecState.CandidateCP))
            [IsMerged,MergedPoint] = TryToMerge(Alg,Sequence,1,RecState.CandidateCP,CurrPoint);
            if (IsMerged)
                %[7] - CP(merged - old CP and the remainder)
                RecState = AddCriticalPoint(RecState,Sequence,MergedPoint);
            else
                %[5]- CP ->CP (of MU) => Ini, Fin || Iso
                Option1 = CreateOptionDouble(Alg,Sequence,1,RecState.CandidateCP.Point,'Ini',RecState.CandidateCP.Point,CurrPoint,'Fin');
                Option2 = CreateOptionSingle(Alg,Sequence,1,CurrPoint,'Iso');
                BO = BetterOption(Option1, Option2);
                if (BO==1)
                    %Add 2 Critical Points 'Ini','Fin'
                    RecState = AddCriticalPoint(RecState,Sequence,Option1.FirstPoint);
                    RecState = AddCriticalPoint(RecState,Sequence,Option1.SecondPoint);
                else
                    %Add 1 Critical Point 'Iso'
                    RecState = AddCriticalPoint(RecState,Sequence,Option2.FirstPoint);
                end
            end
        else
            %[6]- CP(MU) => Iso
            RecState = RecognizeAndAddCriticalPoint(Alg,Sequence,RecState,1,CurrPoint,'Iso');
        end
    else %not the first letter
        if (~isempty(RecState.CandidateCP))
            %[1] - Critical CP -> CP -> CP (of MU)
            LCCPP = RecState.CriticalCPs(RecState.LCCPI).Point;
            Option1 = CreateOptionDouble(Alg,Sequence,LCCPP,RecState.CandidateCP.Point,'Mid',RecState.CandidateCP.Point,CurrPoint,'Fin');
            Option2 = CreateOptionSingle(Alg,Sequence,LCCPP,CurrPoint,'Fin');
            BO = BetterOption(Option1, Option2);
            if (BO==1)
                %Add 2 Critical Points 'Mid','Fin'
                RecState = AddCriticalPoint(RecState,Sequence,Option1.FirstPoint);
                RecState = AddCriticalPoint(RecState,Sequence,Option1.SecondPoint);
                
            else
                RecState = AddCriticalPoint(RecState,Sequence,Option2.FirstPoint);
            end
        else
            if (RecState.LCCPI==1)
                BLCCP.Point = 1;
            else
                BLCCP = RecState.CriticalCPs(RecState.LCCPI-1);
            end
            LCCP = RecState.CriticalCPs(RecState.LCCPI);
            [IsMerged,MergedPoint] = TryToMerge(Alg,Sequence,BLCCP.Point,LCCP,CurrPoint);
            
            if (IsMerged)
                %[4]Critical CP -> New Critical CP(merged with remainder)
                %Remove the previous critical CP
                MarkOnSequence('CandidatePoint',Sequence,LCCP.Point);
                RecState.LCCPI = RecState.LCCPI-1;
                RecState.CriticalCPs = RecState.CriticalCPs(1:RecState.LCCPI);
                RecState = AddCriticalPoint(RecState,Sequence,MergedPoint);
            else
                %[2] - Critical CP -> CP(MU)
                RecState = RecognizeAndAddCriticalPoint(Alg,Sequence,RecState,LCCP.Point,CurrPoint,'Fin');
            end
        end
    end
else    %Mouse not up
    if (rem(CurrPoint,RecParams.K)==0)
        
        [proportionalSiplifiedContour,absoluteSiplifiedContour] = SimplifyContour(Sequence(1:CurrPoint,:));
        resampledSequence = ResampleContour(proportionalSiplifiedContour,size(absoluteSiplifiedContour,1)*5);
        resSeqLastPoint = size(resampledSequence,1);
        
        Slope = CalculateSlope(resampledSequence,resSeqLastPoint-RecParams.PointEnvLength,resSeqLastPoint);
        SlopeRes = CheckSlope(Slope,RecParams);
        
        %scatter(resampledSequence(:,1),resampledSequence(:,2));
        
        %Handle horizontal Segments
        if(IsFirstPointInHS(resampledSequence,SlopeRes,RecState,RecParams))
            RecState = StartNewHS(CurrPoint,RecState);
            MarkOnSequence('StartHorizontalIntervalPoint',Sequence,CurrPoint);
            return;
        elseif (SlopeRes)
            RecState.LastSeenHorizontalPoint = CurrPoint;
            return;
        elseif (IsClosingHS(SlopeRes,RecState,RecParams))
            MarkOnSequence('EndHorizontalIntervalPoint',Sequence,RecState.LastSeenHorizontalPoint);
            [HS,RecState] = EndHS(RecState);
            midPoint=CalcuateHSMidPoint(HS);
        else
            return;
        end
        
        
        [LCCPP,LetterPosition] = CalculateLCCP(RecState);        %The execution will reach this point, only if IsClosingHS is true
        NewCheckPoint = CreateCheckPoint(Alg,Sequence,LCCPP,midPoint,LetterPosition);
        
        if (isempty(RecState.CandidateCP))
            RecState.CandidateCP = NewCheckPoint;
            MarkOnSequence('CandidatePoint',Sequence,midPoint);
        else
            SCP = BetterCP (RecState.CandidateCP,NewCheckPoint); %SCP - Selected CheckPoint
            
            %update the Candidate point in RecState
            if (SCP.Point==RecState.CandidateCP.Point) %Candidate point was selected.
                LCCPP = RecState.CandidateCP.Point;
                RecState.CandidateCP =  CreateCheckPoint (Alg,Sequence,LCCPP,midPoint,'Mid');
                MarkOnSequence('CandidatePoint',Sequence,midPoint);
            else
                RecState.CandidateCP = [];
            end
            % Add a new Critical Point
            RecState = AddCriticalPoint(RecState,Sequence,SCP);
            
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%    HELPER FUNCTIONS   %%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%HS means Horiontal Sections.
function Res = IsFirstPointInHS(ProcessedSequence,Slope,RecState,RecParams)
processedCurrPont = size(ProcessedSequence,1);
[~,absoluteSiplifiedContour] = SimplifyContour(ProcessedSequence(1:processedCurrPont,:));  % this one is to avoid gettinf critical point on letters that start with a straight line like K and 3
Res = RecState.HSStart == -1 && Slope && ProcessedSequence(processedCurrPont,1)<ProcessedSequence(processedCurrPont-1,1) && ~(size(absoluteSiplifiedContour,1)==2);
%Check that the horizontal segment is close to the baseline of the word,
%which is calulated by extrapolating the previous check points.
%We need to handle the valeys of the F_Fin, Y_Fin and N_Fin using linear regression to calculate the baseline using previous Critical points.
%if the Horizontal segments is far away from the regression line, avoid it.
if (Res==true)
    Res = Res && IsOnBaseline(RecState,RecParams);
end


%Check That the slope of the CurrPoint in the simplified version of the
%sequence is small (horizontal). This should fix the problem that very
%small horizontal segments are taken into acount. (Bad condition because we would like to know about smal HS like in KLM*H)
% if (Res==true)
%     resampled = ResampleContour(proportionalSiplifiedContour,size(absoluteSiplifiedContour,1)*5);
%     plot(resampled(:,1),resampled(:,2))
%     lastPoint = size(resampled,1);
%     slope = CalculateSlope(resampled,max(lastPoint-1,1),lastPoint);
%     SlopeRes = CheckSlope(slope,CheckSlope);
%     Res = Res && SlopeRes;
% end

%Check that there is enough information between the (last critical checkpoint) and the (the last candidate)
%to the current HS start. Theoritacally this condition should
%always be true, however viberation in the digitizer can cause too much
%small HS that should be a single HS.
OrigSequence = RecState.Sequence;
OrigCurrPoint = size(OrigSequence,1);

if (RecState.LCCPI~=0)
    LCCPP = RecState.CriticalCPs(RecState.LCCPI).Point;
    [~,abs] = SimplifyContour(OrigSequence(LCCPP:OrigCurrPoint,:));
    Res = Res && (size(abs,1)>2);
end

if (~isempty(RecState.CandidateCP))
    LCCPP = RecState.CandidateCP.Point;
    [~,abs] = SimplifyContour(OrigSequence(LCCPP:OrigCurrPoint,:));
    Res = Res && (size(abs,1)>2);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Res = IsClosingHS(SlopeRes,RecState,RecParams)

% if (RecState.HSStart~=-1 && Slope==0)
%     slope = CalculateSlope(Sequence,lastPoint-2,lastPoint-1);
%     SlopeRes = CheckSlope(slope);
%     Res = SlopeRes && (size(abs,1)==2);
% else
%    Res = false;
% end

Res = ~SlopeRes && RecState.HSStart~=-1;
% OrigSequence = RecState.Sequence;
% Res = false;
% if (~SlopeRes && RecState.HSStart~=-1)
%     [~,abs] = SimplifyContour(OrigSequence(RecState.HSStart:RecState.LastSeenHorizontalPoint,:));
%     segmentSlope = CalculateSlope(abs,1,size(abs,1));
%     segmentSlopeRes = CheckSlope(segmentSlope,RecParams);
%     Res = segmentSlopeRes; %&& (size(abs,1)==2);
%     if (Res==false)
%         RecState.HSStart=-1;
%     end
% end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function RecState = StartNewHS(CurrPoint,RecState)
RecState.HSStart = CurrPoint;
RecState.LastSeenHorizontalPoint = CurrPoint;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [HS,RecState] = EndHS(RecState)
HS = [RecState.HSStart,RecState.LastSeenHorizontalPoint];
RecState.HSStart = -1;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function Res = IsOnBaseline(RecState,RecParams)
Sequence = RecState.Sequence;
CurrPoint = size(RecState.Sequence,1);

Res = true;
if (RecState.LCCPI<2)
    return;
else
    CCParr =[];
    for i=1:RecState.LCCPI
        CCPI = RecState.CriticalCPs(i).Point;
        CCParr = [CCParr;Sequence(CCPI,:)];
    end
    if (~isempty(RecState.CandidateCP) && RecState.LCCPI>1)
        CCParr = [CCParr;Sequence(RecState.CandidateCP.Point,:)];
    end
    p = polyfit(CCParr(:,1),CCParr(:,2),1);
    yfit = polyval(p,Sequence(CurrPoint,1));
    %%%% Activate to see the baseline %%%%%%%
    %     figure
    %     scatter(Sequence(:,1),Sequence(:,2))
    %     t = (Sequence(1,1):-0.001:Sequence(CurrPoint,1));
    %     y = p(1)*t+p(2);
    %     hold on;
    %     plot(t,y)
    %     hold off;
    %     abs(yfit-Sequence(CurrPoint,2))
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    if (abs(yfit-Sequence(CurrPoint,2))>RecParams.MaxDistFromBaseline)
        Res = false;
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function MidPoint = CalcuateHSMidPoint(HS)
MidPoint = floor((HS(1)+HS(2))/2);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [LCCPP,LetterPosition]  = CalculateLCCP(RecState)
if ( RecState.LCCPI == 0)
    LCCPP = 1;
    LetterPosition = 'Ini';
else
    LCCPP = RecState.CriticalCPs(RecState.LCCPI).Point;
    LetterPosition = 'Mid';
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [IsMerged,MergedPoint] = TryToMerge(Alg,Sequence,LastCriticalPoint,Candidate,LastPoint)
global LettersDataStructure;

MergedPoint.Point = LastPoint;
SubSeq =Sequence(LastCriticalPoint:LastPoint,:);
if (LastCriticalPoint==1)
    RecognitionResults = RecognizeSequence(SubSeq , Alg, 'Iso', LettersDataStructure);
else
    RecognitionResults = RecognizeSequence(SubSeq , Alg, 'Fin', LettersDataStructure);
end
MergedPoint.Candidates = RecognitionResults;
BCP = BetterCP (Candidate,MergedPoint);
if (BCP.Point==MergedPoint.Point)
    IsMerged = true;
else
    IsMerged = false;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Option = CreateOptionDouble(Alg,Sequence,Start1,End1,Position1,Start2,End2,Position2)
Option.OptionType = 'Double';
FirstPoint = CreateCheckPoint (Alg,Sequence,Start1,End1,Position1);
Option.FirstPoint =  FirstPoint;
SecondPoint = CreateCheckPoint (Alg,Sequence,Start2,End2,Position2);
Option.SecondPoint =  SecondPoint;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Option = CreateOptionSingle(Alg,Sequence,Start,End,Position)
Option.OptionType = 'Single';
FirstPoint = CreateCheckPoint (Alg,Sequence,Start,End,Position);
Option.FirstPoint =  FirstPoint;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function BO = BetterOption(Option1, Option2)
switch Option1.OptionType
    case 'Single',
        Option1AvgDist = CalculateAvgCandidatesDistane (Option1.FirstPoint);
    case 'Double',
        Option1AvgDist = (CalculateAvgCandidatesDistane (Option1.FirstPoint)+CalculateAvgCandidatesDistane (Option1.SecondPoint))/2;
end

switch Option2.OptionType
    case 'Single',
        Option2AvgDist = CalculateAvgCandidatesDistane (Option2.FirstPoint);
    case 'Double',
        Option2AvgDist = (CalculateAvgCandidatesDistane (Option2.FirstPoint)+CalculateAvgCandidatesDistane (Option2.SecondPoint))/2;
end

if (Option1AvgDist<Option2AvgDist)
    BO=1;
else
    BO=2;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function CheckPoint = CreateCheckPoint (Alg,Sequence,StartPoint,EndPoint,Position)
global LettersDataStructure;
SubSeq = Sequence(StartPoint:EndPoint,:);
RecognitionResults = RecognizeSequence(SubSeq , Alg, Position, LettersDataStructure);
CheckPoint.Point = EndPoint;
CheckPoint.Candidates = RecognitionResults;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function RecState = RecognizeAndAddCriticalPoint(Alg,Sequence,RecState,StartPoint,EndPoint,LetterPos)
WarpedPoint= CreateCheckPoint (Alg,Sequence,StartPoint,EndPoint,LetterPos);
RecState = AddCriticalPoint(RecState,Sequence,WarpedPoint);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function RecState = AddCriticalPoint(RecState,Sequence,WrappedPoint)
RecState.CriticalCPs = [RecState.CriticalCPs;WrappedPoint];
RecState.LCCPI = RecState.LCCPI + 1;
MarkOnSequence('CriticalCP',Sequence,WrappedPoint.Point);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function BCP = BetterCP (CP1,CP2)
AvgCP1 = CalculateAvgCandidatesDistane(CP1);
AvgCP2 = CalculateAvgCandidatesDistane(CP2);
if (AvgCP1<AvgCP2)
    BCP = CP1;
else
    BCP = CP2;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Avg = CalculateAvgCandidatesDistane (CandidateCP)
NumCandidates = size(CandidateCP.Candidates,1);
arr = [];
for k=1:NumCandidates
    arr = [arr;CandidateCP.Candidates{k,2}];
end
Avg = min (arr);
%Avg = mean (arr);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function res = CheckSlope(Slope,RecParams)
res = SPQuerySVM('C:\OCRData\Segmentation\SVM\SVMStruct',Slope) && Slope<RecParams.MaxSlopeRate;


%%%%%%%%%%%%%%%%%%     UNUSED FUNCTIONS      %%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [CheckPoint,SumDist,CDist,minDist] = CreateCheckPointAndDistanceInfo (Alg,Sequence,StartPoint,EndPoint,Position)
global LettersDataStructure;
SubSeq = Sequence(StartPoint:EndPoint,:);
[RecognitionResults,SumDist] = RecognizeSequence(SubSeq , Alg, Position, LettersDataStructure);
CheckPoint.Point = EndPoint;
CheckPoint.Candidates = RecognitionResults;
distances = [RecognitionResults{:,2}];
CDist = sum (distances);
minDist = min (distances);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function CheckPoint = CreateEmptyCheckPoint (Alg,Sequence,StartPoint,EndPoint,Position)
SubSeq = Sequence(StartPoint:EndPoint,:);
CheckPoint.Point = EndPoint;
CheckPoint.Candidates = [];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Res = IsCheckPoint(Sequence,CurrPoint,SimplifiedSequence,Slope)
%A candidate point is a Checkpoint only if all the below are valid:
%1. The current Sub sequence contains enough information
%2. Directional - > going "forward" in x axes
%3. The point environmnt is horizontal
%%%MaxSlope=RecParams.MaxSlope;
Res = (length(SimplifiedSequence)>2 && CheckSlope(Slope)&& Sequence(CurrPoint,1)<Sequence(CurrPoint-1,1));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [SeqLen] = CalculateSequenceLength (Sequence,CurrPoint,RecState)
LCCPI=RecState.LCCPI;
if(LCCPI==0)
    SeqLen = SequenceLength(Sequence);
else
    LastCCP = RecState.CriticalCPs(LCCPI);
    sub_s= Sequence(LastCCP.Point:CurrPoint,:);
    SeqLen = SequenceLength(sub_s);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%    PRINTING/TEST FUNCTIONS   %%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function MarkOnSequence(Type,Sequence,Point)
global gUI;
if (gUI==true)
    switch Type
        case 'CandidatePoint',
            plot(findobj('Tag','AXES'),Sequence(Point-1:Point,1),Sequence(Point-1:Point,2),'c.-','Tag','SHAPE','LineWidth',10);
            return;
        case 'CriticalCP'
            plot(findobj('Tag','AXES'),Sequence(Point-1:Point,1),Sequence(Point-1:Point,2),'r.-','Tag','SHAPE','LineWidth',10);
            return;
        case 'StartHorizontalIntervalPoint'
            plot(findobj('Tag','AXES'),Sequence(Point-1:Point,1),Sequence(Point-1:Point,2),'g.-','Tag','SHAPE','LineWidth',10);
            return;
        case 'EndHorizontalIntervalPoint'
            plot(findobj('Tag','AXES'),Sequence(Point-1:Point,1),Sequence(Point-1:Point,2),'k.-','Tag','SHAPE','LineWidth',10);
            return;
        otherwise
            return;
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%