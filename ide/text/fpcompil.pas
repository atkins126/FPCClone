{
    $Id$
    This file is part of the Free Pascal Integrated Development Environment
    Copyright (c) 1998 by Berczi Gabor

    Compiler call routines for the IDE

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit FPCompile;

interface

uses FPViews;

type
    TCompileMode = (cBuild,cMake,cCompile,cRun);

    PCompileStatusDialog = ^TCompileStatusDialog;
    TCompileStatusDialog = object(TCenterDialog)
      ST    : PAdvancedStaticText;
      KeyST : PColorStaticText;
      constructor Init;
      procedure   Update;
    private
      MsgLB: PMessageListBox;
    end;

procedure DoCompile(Mode: TCompileMode);

implementation

uses
  Video,CRt,
  Objects,Drivers,Views,App,
  CompHook,
  FPConst,FPVars,FPUtils,FPIntf,FPSwitches;

const SD: PCompileStatusDialog = nil;

constructor TCompileStatusDialog.Init;
var R: TRect;
begin
  R.Assign(0,0,50,11+7);
  inherited Init(R, 'Compiling');
  GetExtent(R); R.B.Y:=11;
  R.Grow(-3,-2);
  New(ST, Init(R, ''));
  Insert(ST);
  GetExtent(R); R.B.Y:=11;
  R.Grow(-1,-1); R.A.Y:=R.B.Y-1;
  New(KeyST, Init(R, '', Blue*16+White+longint($80+Blue*16+White)*256));
  Insert(KeyST);
  GetExtent(R); R.Grow(-1,-1); R.A.Y:=10;
  New(MsgLB, Init(R, nil, nil));
  MsgLB^.NewList(New(PUnsortedStringCollection, Init(100,100)));
  Insert(MsgLB);
end;


procedure TCompileStatusDialog.Update;
var StatusS,KeyS: string;
const CtrlBS = 'Press Ctrl+Break to cancel';
      SuccessS = 'Compile successful: ~Press Enter~';
      FailS = 'Compile failed';
begin
  case CompilationPhase of
    cpCompiling :
      begin
        StatusS:='Compiling '+Status.CurrentSource;
        KeyS:=CtrlBS;
      end;
    cpLinking   :
      begin
        StatusS:='Linking...';
        KeyS:=CtrlBS;
      end;
    cpDone      :
      begin
        StatusS:='Done.';
        if Status.ErrorCount=0 then KeyS:=SuccessS else KeyS:=FailS;
      end;
  end;
  ST^.SetText(
    'Main file: '+MainFile+#13+
    StatusS+#13#13+
    'Target: '+LExpand(KillTilde(TargetSwitches^.ItemName(TargetSwitches^.GetCurrSel)),12)+'    '+
    'Line number: '+IntToStrL(Status.CurrentLine,7)+#13+
    'Free memory: '+IntToStrL(MemAvail div 1024,6)+'K'+ '    '+
    'Total lines: '+IntToStrL(Status.CompiledLines,7)+#13+
    'Total errors: '+IntToStrL(Status.ErrorCount,5)
  );
  KeyST^.SetText(^C+KeyS);
end;


{****************************************************************************
                               Compiler Hooks
****************************************************************************}

function CompilerStatus: boolean; {$ifndef FPC}far;{$endif}
begin
  SD^.Update;
  CompilerStatus:=false;
end;


procedure CompilerStop; {$ifndef FPC}far;{$endif}
begin
end;


function CompilerComment(Level:Longint; const s:string):boolean; {$ifndef FPC}far;{$endif}
begin
  CompilerComment:=false;
  if (status.verbosity and Level)=Level then
   begin
     ProgramInfoWindow^.AddMessage(Level,S,SmartPath(status.currentmodule),status.currentline);
     SD^.MsgLB^.AddItem(New(PCompilerMessage, Init(Level, S, SmartPath(status.currentmodule),status.currentline)));
   end;
end;


{****************************************************************************
                                 DoCompile
****************************************************************************}

procedure DoCompile(Mode: TCompileMode);

  function IsExitEvent(E: TEvent): boolean;
  begin
    IsExitEvent:=(E.What=evKeyDown) and
                 ((E.KeyCode=kbEnter) or (E.KeyCode=kbEsc));
  end;


var
  P: PSourceWindow;
  FileName: string;
  E: TEvent;
{  WasVisible: boolean;}
begin
{ Get FileName }
  P:=Message(Desktop,evBroadcast,cmSearchWindow,nil);
  if (PrimaryFile='') and (P=nil) then
    begin
      ErrorBox('Oooops, nothing to compile.',nil);
      Exit;
    end;
  if PrimaryFile<>'' then
    FileName:=PrimaryFile
  else
    begin
      if P^.Editor^.Modified and (not P^.Editor^.Save) then
       begin
         ErrorBox('Can''t compile unsaved file.',nil);
         Exit;
       end;
      FileName:=P^.Editor^.FileName;
    end;
  MainFile:=SmartPath(FileName);
{ Reset }
  CtrlBreakHit:=false;
{ Show Program Info }
{  WasVisible:=ProgramInfoWindow^.GetState(sfVisible);
  ProgramInfoWindow^.LogLB^.Clear;
  if WasVisible=false then
    ProgramInfoWindow^.Show;
  ProgramInfoWindow^.MakeFirst;}

  CompilationPhase:=cpCompiling;
  New(SD, Init);
  SD^.SetState(sfModal,true);
  Application^.Insert(SD);
  SD^.Update;

  do_status:=CompilerStatus;
  do_stop:=CompilerStop;
  do_comment:=CompilerComment;

  Compile(FileName);

  CompilationPhase:=cpDone;
  SD^.Update;

  if ((status.errorcount=0) or (ShowStatusOnError)) and (Mode<>cRun) then
   repeat
     SD^.GetEvent(E);
     if IsExitEvent(E)=false then
      SD^.HandleEvent(E);
   until IsExitEvent(E);

  Application^.Delete(SD);
  SD^.SetState(sfModal,false);
  Dispose(SD, Done);

{  if (WasVisible=false) and (status.errorcount=0) then
   ProgramInfoWindow^.Hide;}
end;

end.
{
  $Log$
  Revision 1.2  1998-12-28 15:47:42  peter
    + Added user screen support, display & window
    + Implemented Editor,Mouse Options dialog
    + Added location of .INI and .CFG file
    + Option (INI) file managment implemented (see bottom of Options Menu)
    + Switches updated
    + Run program

  Revision 1.3  1998/12/22 10:39:40  peter
    + options are now written/read
    + find and replace routines

}
