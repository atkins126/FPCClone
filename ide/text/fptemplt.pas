{
    $Id$
    This file is part of the Free Pascal Integrated Development Environment
    Copyright (c) 1998 by Berczi Gabor

    Template support routines for the IDE

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit FPTemplt;

interface

uses FPViews;

function  GetTemplateCount: integer;
function  GetTemplateName(Index: integer): string;
function  StartTemplate(Index: integer; Editor: PSourceEditor): boolean;

procedure InitTemplates;
procedure DoneTemplates;

implementation

uses
  Dos,Objects,
{$ifdef EDITORS}
  Editors,
{$else}
  WEditor,
{$endif}
  FPVars,FPUtils;

type
    PTemplate = ^TTemplate;
    TTemplate = record
      Name : PString;
      Path : PString;
    end;

    PTemplateCollection = ^TTemplateCollection;
    TTemplateCollection = object(TSortedCollection)
      function  At(Index: Integer): PTemplate;
      procedure FreeItem(Item: Pointer); virtual;
      function  Compare(Key1, Key2: Pointer): Sw_Integer; virtual;
    end;

const Templates : PTemplateCollection = nil;

function NewTemplate(const Name, Path: string): PTemplate;
var P: PTemplate;
begin
  New(P);
  FillChar(P^,SizeOf(P^),0);
  P^.Name:=NewStr(Name);
  P^.Path:=NewStr(Path);
  NewTemplate:=P;
end;

procedure DisposeTemplate(P: PTemplate);
begin
  if assigned(P) then
   begin
     if assigned(P^.Name) then
       DisposeStr(P^.Name);
     if assigned(P^.Path) then
       DisposeStr(P^.Path);
     Dispose(P);
   end;
end;

function TTemplateCollection.At(Index: Integer): PTemplate;
begin
  At:=inherited At(Index);
end;

procedure TTemplateCollection.FreeItem(Item: Pointer);
begin
  if assigned(Item) then
    DisposeTemplate(Item);
end;

function TTemplateCollection.Compare(Key1, Key2: Pointer): Sw_Integer;
var R: Sw_integer;
    K1: PTemplate absolute Key1;
    K2: PTemplate absolute Key2;
begin
  if K1^.Name^<K2^.Name^ then R:=-1 else
  if K1^.Name^>K2^.Name^ then R:= 1 else
  R:=0;
  Compare:=R;
end;

function GetTemplateCount: integer;
var Count: integer;
begin
  if Templates=nil then Count:=0 else Count:=Templates^.Count;
  GetTemplateCount:=Count;
end;

function GetTemplateName(Index: integer): string;
begin
  GetTemplateName:=Templates^.At(Index)^.Name^;
end;

function StartTemplate(Index: integer; Editor: PSourceEditor): boolean;
var
    T: PTemplate;
    OK: boolean;
begin
  T:=Templates^.At(Index);
  OK:=StartEditor(Editor,T^.Path^);
  StartTemplate:=OK;
end;


{*****************************************************************************
                                 InitTemplates
*****************************************************************************}

procedure InitTemplates;

  procedure ScanDir(Dir: PathStr);
  var SR: SearchRec;
      S: string;
      PT : PTemplate;
      i : sw_integer; 
  begin
    if copy(Dir,length(Dir),1)<>DirSep then Dir:=Dir+DirSep;
    FindFirst(Dir+'*.pt',AnyFile,SR);
    while (DosError=0) do
    begin
      S:=NameOf(SR.Name);
      S:=LowerCaseStr(S);
      S[1]:=Upcase(S[1]);
      PT:=NewTemplate(S,FExpand(Dir+SR.Name));
      if not Templates^.Search(PT,i) then
        Templates^.Insert(PT)
      else
        DisposeTemplate(PT);
      FindNext(SR);
    end;
  {$ifdef FPC}
    FindClose(SR);
  {$endif def FPC}
  end;

begin
  New(Templates, Init(10,10));
  ScanDir('.');
  ScanDir(IDEDir);
end;


procedure DoneTemplates;
begin
  if assigned(Templates) then
    begin
      Dispose(Templates, Done);
      Templates:=nil;
    end;
end;

END.
{
  $Log$
  Revision 1.8  1999-06-25 00:33:40  pierre
   * avoid lost memory on duplicate Template Items

  Revision 1.7  1999/03/08 14:58:11  peter
    + prompt with dialogs for tools

  Revision 1.6  1999/03/01 15:42:03  peter
    + Added dummy entries for functions not yet implemented
    * MenuBar didn't update itself automatically on command-set changes
    * Fixed Debugging/Profiling options dialog
    * TCodeEditor converts spaces to tabs at save only if efUseTabChars is
 set
    * efBackSpaceUnindents works correctly
    + 'Messages' window implemented
    + Added '$CAP MSG()' and '$CAP EDIT' to available tool-macros
    + Added TP message-filter support (for ex. you can call GREP thru
      GREP2MSG and view the result in the messages window - just like in TP)
    * A 'var' was missing from the param-list of THelpFacility.TopicSearch,
      so topic search didn't work...
    * In FPHELP.PAS there were still context-variables defined as word instead
      of THelpCtx
    * StdStatusKeys() was missing from the statusdef for help windows
    + Topic-title for index-table can be specified when adding a HTML-files

  Revision 1.5  1999/02/18 13:44:35  peter
    * search fixed
    + backward search
    * help fixes
    * browser updates

  Revision 1.4  1999/02/16 17:13:56  pierre
   + findclose added for FPC

  Revision 1.3  1999/01/21 11:54:24  peter
    + tools menu
    + speedsearch in symbolbrowser
    * working run command

  Revision 1.2  1998/12/28 15:47:52  peter
    + Added user screen support, display & window
    + Implemented Editor,Mouse Options dialog
    + Added location of .INI and .CFG file
    + Option (INI) file managment implemented (see bottom of Options Menu)
    + Switches updated
    + Run program

  Revision 1.2  1998/12/22 10:39:51  peter
    + options are now written/read
    + find and replace routines

}
