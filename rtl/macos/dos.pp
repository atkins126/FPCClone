{
    $Id$
    This file is part of the Free Pascal run time library.
    Copyright (c) 2004 by Olle Raab and
    members of the Free Pascal development team

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
Unit Dos;
Interface

Uses
  macostp;
  

Const
  {Max PathName Length for files}
  FileNameLen=255;

Type
    SearchRec = packed record
        Attr: Byte;       {attribute of found file}
        Time: LongInt;    {last modify date of found file}
        Size: LongInt;    {file size of found file}
        Reserved: Word;   {future use}
        Name: string[FileNameLen]; {name of foundfile}
        SearchSpec: string[FileNameLen]; {search pattern}
        NamePos: Word;    {end of path,start of name position}

        {MacOS specific params, private, do not use:}
        paramBlock: CInfoPBRec;
        searchFSSpec: FSSpec;
        searchAttr: Byte;  {attribute we are searching for}
        exactMatch: Boolean;
      end;

{$i dosh.inc}

Implementation

{TODO Obtain disk size and disk free values for volumes > 2 GB.
 For this, PBXGetVolInfoSync can be used. However, this function
 is not available on older versions of Mac OS, so the function has
 to be weak linked. An alternative is to directly look into the VCB
 (Volume Control Block), but since this is on low leveel it is a
 compatibility risque.}

{TODO Perhaps make SearchRec.paramBlock opaque, so that uses macostp;
 is not needed in the interface part.}

{TODO Perhaps add some kind of "Procedure AddDisk" for accessing other
 volumes. At lest accessing the possible disk drives with
 driver number 1 and 2 should be easy.}

{TODO Perhaps implement Exec with Apple Events, calling ToolServer.}


{TODO Perhaps use LongDateTime for time functions. But the function
 calls must then be weak linked.}

Uses
  macutils,
  unixutil {for FNMatch};

function MacTimeToDosPackedTime(macfiletime: UInt32): Longint;
var
  mdt: DateTimeRec; {Mac OS datastructure}
  ddt: Datetime;    {Dos OS datastructure}
  dospackedtime: Longint;

begin
  SecondsToDate(macfiletime, mdt);
  with ddt do
    begin
      year := mdt.year;
      month := mdt.month;
      day := mdt.day;
      hour := mdt.hour;
      min := mdt.minute;
      sec := mdt.second;
    end;
  Packtime(ddt, dospackedtime);
  MacTimeToDosPackedTime:= dospackedtime;
end;


{******************************************************************************
                        --- Info / Date / Time ---
******************************************************************************}

function DosVersion:Word;

begin
  DosVersion:=
    (macosSystemVersion and $FF00) or
    ((macosSystemVersion and $00F0) shr 4);
end;

procedure GetDate (var year, month, mday, wday: word);

  var
    d: DateTimeRec;

begin
  Macostp.GetTime(d);
  year := d.year;
  month := d.month;
  mday := d.day;
  wday := d.dayOfWeek - 1;  {1-based on mac}
end;

procedure GetTime (var hour, minute, second, sec100: word);

  var
    d: DateTimeRec;

begin
  Macostp.GetTime(d);
  hour := d.hour;
  minute := d.minute;
  second := d.second;
  sec100 := 0;
end;

procedure Packtime(var t : datetime;var p : longint);
Begin
  p:=(t.sec shr 1)+(t.min shl 5)+(t.hour shl 11)+(t.day shl 16)+(t.month shl 21)+((t.year-1980) shl 25);
End;

procedure Unpacktime(p : longint;var t : datetime);
Begin
  t.sec:=(p and 31) shl 1;
  t.min:=(p shr 5) and 63;
  t.hour:=(p shr 11) and 31;
  t.day:=(p shr 16) and 31;
  t.month:=(p shr 21) and 15;
  t.year:=(p shr 25)+1980;
End;

Procedure SetDate(Year, Month, Day: Word);

  var
    d: DateTimeRec;

Begin
  Macostp.GetTime(d);
  d.year := year;
  d.month := month;
  d.day := day;
  Macostp.SetTime(d)
End;

Procedure SetTime(Hour, Minute, Second, Sec100: Word);

  var
    d: DateTimeRec;

Begin
  Macostp.GetTime(d);
  d.hour := hour;
  d.minute := minute;
  d.second := second;
  Macostp.SetTime(d)
End;

{******************************************************************************
                               --- Exec ---
******************************************************************************}

Procedure Exec (Const Path: PathStr; Const ComLine: ComStr);
Begin
  DosError:=8; //TODO A better error sometime
End;

Function DosExitCode: Word;
Begin
  DosExitCode := 3; //Indicate failure TODO a better error sometime.
End;

{******************************************************************************
                               --- Disk ---
******************************************************************************}

{If drive is 0 the free space on the volume of the working directory is returned.
 If drive is 1 or 2, the free space on the first or second floppy disk is returned.
 If drive is 3 the free space on the boot volume is returned.
 If the free space is > 2 GB, then 2 GB is reported.}
Function DiskFree(drive: Byte): Int64;

var
  myHPB: HParamBlockRec;
  myErr: OSErr;

begin
	myHPB.ioNamePtr := NIL;
	myHPB.ioVolIndex := 0;
  case drive of
    0: myHPB.ioVRefNum := GetWorkingDirectoryVRefNum;
    1: myHPB.ioVRefNum := 1;
    2: myHPB.ioVRefNum := 2;
    3: myHPB.ioVRefNum := macosBootVolumeVRefNum;
    else
      begin
        Diskfree:= -1;
        Exit;
      end;
  end;

  myErr := PBHGetVInfoSync(@myHPB);

  if myErr = noErr then
    Diskfree := myHPB.ioVAlBlkSiz * myHPB.ioVFrBlk
  else
    Diskfree:= -1;
End;

{If drive is 0 the size of the volume of the working directory is returned.
 If drive is 1 or 2, the size of the first or second floppy disk is returned.
 If drive is 3 the size of the boot volume is returned.
 If the actual size is > 2 GB, then 2 GB is reported.}
Function DiskSize(drive: Byte): Int64;

var
  myHPB: HParamBlockRec;
  myErr: OSErr;

Begin
	myHPB.ioNamePtr := NIL;
	myHPB.ioVolIndex := 0;
  case drive of
    0: myHPB.ioVRefNum := GetWorkingDirectoryVRefNum;
    1: myHPB.ioVRefNum := 1;
    2: myHPB.ioVRefNum := 2;
    3: myHPB.ioVRefNum := macosBootVolumeVRefNum;
    else
      begin
        DiskSize:= -1;
        Exit;
      end;
  end;

  myErr := PBHGetVInfoSync(@myHPB);

  if myErr = noErr then
    DiskSize := myHPB.ioVAlBlkSiz * myHPB.ioVNmAlBlks
  else
    DiskSize:=-1;
End;

{******************************************************************************
                       --- Findfirst FindNext ---
******************************************************************************}

(*
  {The one defined in Unixutils.pp is used instead}

  function FNMatch (const Pattern, Name: string): Boolean;

    var
      LenPat, LenName: longint;

    function DoFNMatch (i, j: longint): Boolean;

      var
        Found: boolean;

    begin
      Found := true;
      while Found and (i <= LenPat) do
        begin
          case Pattern[i] of
            '?': 
              Found := (j <= LenName);
            '*': 
              begin
                                {find the next character in pattern, different of ? and *}
                while Found and (i < LenPat) do
                  begin
                    i := i + 1;
                    case Pattern[i] of
                      '*': 
                        ;
                      '?': 
                        begin
                          j := j + 1;
                          Found := (j <= LenName);
                        end;
                      otherwise
                        Found := false;
                    end;
                  end;
                        {Now, find in name the character which i points to, if the * or ?}
                        {wasn 't the last character in the pattern, else, use up all the}
                        {chars in name }
                Found := true;
                if (i <= LenPat) then
                  begin
                    repeat
                                        {find a letter (not only first !) which maches pattern[i]}
                      while (j <= LenName) and (name[j] <> pattern[i]) do
                        j := j + 1;
                      if (j < LenName) then
                        begin
                          if DoFnMatch(i + 1, j + 1) then
                            begin
                              i := LenPat;
                              j := LenName;{we can stop}
                              Found := true;
                            end
                          else
                            j := j + 1;{We didn't find one, need to look further}
                        end;
                    until (j >= LenName);
                  end
                else
                  j := LenName;{we can stop}
              end;
            otherwise {not a wildcard character in pattern}
              Found := (j <= LenName) and (pattern[i] = name[j]);
          end;
          i := i + 1;
          j := j + 1;
        end;
      DoFnMatch := Found and (j > LenName);
    end;

  begin {start FNMatch}
    LenPat := Length(Pattern);
    LenName := Length(Name);
    FNMatch := DoFNMatch(1, 1);
  end;

*)

  function GetFileAttrFromPB (var paramBlock: CInfoPBRec): Word;

    var
      isLocked, isInvisible, isDirectory, isNameLocked: Boolean;
      attr: Word;

    {NOTE "nameLocked" was in pre-System 7 called "isSystem".
    It is used for files whose name and icon cannot be changed by the user,
    that is essentially system files. However in System 9 the folder
    "Applications (Mac OS 9)" also has this attribute, and since this is
    not a system file in traditional meaning, we will not use this attribute
    as the "sysfile" attribute.}

  begin
    with paramBlock do
      begin
        attr := 0;

        isDirectory := (ioFlAttrib and $10) <> 0;
        if isDirectory then
          attr := (attr or directory);

        isLocked := (ioFlAttrib and $01) <> 0;
        if isLocked then
          attr := (attr or readonly);

        if not isDirectory then
          begin
            isInvisible := (ioFlFndrInfo.fdFlags and 16384) <> 0;
            (* isNameLocked := (ioFlFndrInfo.fdFlags and 4096) <> 0; *)
          end
        else
          begin
            isInvisible := (ioDrUsrWds.frFlags and 16384) <> 0;
            (* isNameLocked := (ioDrUsrWds.frFlags and 4096) <> 0; *)
          end;

        if isInvisible then
          attr := (attr or hidden);

        (*
        if isNameLocked then
          attr := (attr or sysfile); 
        *)

        GetFileAttrFromPB := attr;
      end;
  end;

  procedure SetPBFromFileAttr (var paramBlock: CInfoPBRec; attr: Word);

  begin
    with paramBlock do
      begin
        (*
        {Doesn't seem to work, despite the documentation.}
        {Can instead be set by FSpSetFLock/FSpRstFLock}
        if (attr and readonly) <> 0 then
          ioFlAttrib := (ioFlAttrib or $01)
        else
          ioFlAttrib := (ioFlAttrib and not($01));
        *)

        if (attr and hidden) <> 0 then
          ioFlFndrInfo.fdFlags := (ioFlFndrInfo.fdFlags or 16384)
        else
          ioFlFndrInfo.fdFlags := (ioFlFndrInfo.fdFlags and not(16384))
      end;
  end;

  function GetFileSizeFromPB (var paramBlock: CInfoPBRec): Longint;

  begin
    with paramBlock do
      if ((ioFlAttrib and $10) <> 0) then {if directory}
        GetFileSizeFromPB := 0
      else
        GetFileSizeFromPB := ioFlLgLen + ioFlRLgLen;    {Add length of both forks}
  end;

  function DoFindOne (var spec: FSSpec; var paramBlock: CInfoPBRec): Integer;

    var
      err: OSErr;

  begin
    with paramBlock do
      begin
        ioVRefNum := spec.vRefNum;
        ioDirID := spec.parID;
        ioNamePtr := @spec.name;
        ioFDirIndex := 0;

        err := PBGetCatInfoSync(@paramBlock);

        DoFindOne := MacOSErr2RTEerr(err);
      end;
  end;

  {To be used after a call to DoFindOne, with the same spec and paramBlock.}
  {Change those parameters in paramBlock, which is to be changed.}
  function DoSetOne (var spec: FSSpec; var paramBlock: CInfoPBRec): Integer;

    var
      err: OSErr;

  begin
    with paramBlock do
      begin
        ioVRefNum := spec.vRefNum;
        ioDirID := spec.parID;
        ioNamePtr := @spec.name;

        err := PBSetCatInfoSync(@paramBlock);

        DoSetOne := MacOSErr2RTEerr(err);
      end;
  end;

  procedure DoFind (var F: SearchRec; firstTime: Boolean);

    var
      err: OSErr;
      s: Str255;

  begin
    with F, paramBlock do
      begin
        ioVRefNum := searchFSSpec.vRefNum;
        if firstTime then
          ioFDirIndex := 0;

        while true do
          begin
            s := '';
            ioDirID := searchFSSpec.parID;
            ioFDirIndex := ioFDirIndex + 1;
            ioNamePtr := @s;

            err := PBGetCatInfoSync(@paramBlock);

            if err <> noErr then
              begin
                if err = fnfErr then
                  DosError := 18
                else
                  DosError := MacOSErr2RTEerr(err);
                break;
              end;

            attr := GetFileAttrFromPB(f.paramBlock);
            if ((Attr and not(searchAttr)) = 0) then
              begin
                name := s;
                UpperString(s, true);

                if FNMatch(F.searchFSSpec.name, s) then
                  begin
                    size := GetFileSizeFromPB(paramBlock);
                    time := MacTimeToDosPackedTime(ioFlMdDat);
                    DosError := 0;
                    break;
                  end;
              end;
          end;
      end;
  end;

  procedure FindFirst (const path: pathstr; Attr: Word; var F: SearchRec);
    var
      s: Str255;

  begin
    fillchar(f, sizeof(f), 0);

    if path = '' then
      begin
        DosError := 3;
        Exit;
      end;

    {We always also search for readonly and archive, regardless of Attr.}
    F.searchAttr := (Attr or (archive or readonly));

    DosError := PathArgToFSSpec(path, F.searchFSSpec);
    with F do
      if (DosError = 0) or (DosError = 2) then
        begin
          SearchSpec := path;
          NamePos := Length(path) - Length(searchFSSpec.name);

          if (Pos('?', searchFSSpec.name) = 0) and (Pos('*', searchFSSpec.name) = 0) then  {No wildcards}
            begin  {If exact match, we don't have to scan the directory}
              exactMatch := true;
              DosError := DoFindOne(searchFSSpec, paramBlock);
              if DosError = 0 then
                begin
                  Attr := GetFileAttrFromPB(paramBlock);
                  if ((Attr and not(searchAttr)) = 0) then
                    begin
                      name := searchFSSpec.name;
                      size := GetFileSizeFromPB(paramBlock);
                      time := MacTimeToDosPackedTime(paramBlock.ioFlMdDat);
                    end
                  else
                    DosError := 18;
                end
              else if DosError = 2 then
                DosError := 18;
            end
          else
            begin
              exactMatch := false;

              s := searchFSSpec.name;
              UpperString(s, true);
              F.searchFSSpec.name := s;

              DoFind(F, true);
            end;
        end;
  end;

  procedure FindNext (var f: searchRec);

  begin
    if F.exactMatch then
      DosError := 18
    else
      DoFind(F, false);
  end;

  procedure FindClose (var f: searchRec);
  {Note: Even if this routine is empty, this doesn't mean it will}
  {be empty in the future. Please use it.}
  begin
  end;



{******************************************************************************
                               --- File ---
******************************************************************************}

  function FSearch (path: pathstr; dirlist: string): pathstr;
      {Searches for a file 'path' in the working directory and then in the list of }
      {directories in 'dirlist' . Returns a valid (possibly relative) path or an }
      {empty string if not found . Wildcards are NOT allowed }
      {The dirlist can be separated with ; or , but not :}

    var
      NewDir: string[255];
      p1: Longint;
      spec: FSSpec;
      fpcerr: Integer;

  begin
    FSearch := '';
    if (Length(path) = 0) then
      Exit;

    {Check for Wild Cards}
    if (Pos('?', Path) <> 0) or (Pos('*', Path) <> 0) then
      Exit;

    path := TranslatePathToMac(path, false);

    {Search in working directory, or as full path}
    fpcerr := PathArgToFSSpec(path, spec);
    if (fpcerr = 0) and not IsDirectory(spec) then
      begin
        FSearch := path;
        Exit;
      end
    else if not IsMacFullPath(path) then    {If full path, we do not need to continue.}
      begin
        {Replace ';' with native mac PathSeparator (',').}
        {Note: we cannot support unix style ':', because it is used as dir separator in MacOS}
        for p1 := 1 to length(dirlist) do
          if dirlist[p1] = ';' then
            dirlist[p1] := PathSeparator;

        repeat
          p1 := Pos(PathSeparator, DirList);
          if p1 = 0 then
            p1 := 255;
          NewDir := TranslatePathToMac(Copy(DirList, 1, P1 - 1), false);

          NewDir := ConcatMacPath(NewDir, Path);

          Delete(DirList, 1, p1);

          fpcerr := PathArgToFSSpec(NewDir, spec);
          if fpcerr = 0 then
            begin
              if IsDirectory(spec) then
                NewDir := '';
            end
          else
            NewDir := '';
        until (DirList = '') or (Length(NewDir) > 0);
        FSearch := NewDir;
      end;
  end;


{$UNDEF USE_FEXPAND_INC}

{$IFDEF USE_FEXPAND_INC}


{$DEFINE FPC_FEXPAND_VOLUMES}
{$DEFINE FPC_FEXPAND_NO_DEFAULT_PATHS}

{ TODO A lot of issues before this works}

{$I fexpand.inc}

{$UNDEF FPC_FEXPAND_VOLUMES}
{$UNDEF FPC_FEXPAND_NO_DEFAULT_PATHS}


{$ELSE}

{ TODO nonexisting dirs in path's doesnt work (nonexisting files do work)
       example: Writeln('FExpand on :nisse:kalle : ', FExpand(':nisse:kalle')); }

  function FExpand (const path: pathstr): pathstr;
  var
    fullpath: AnsiString;
  begin
    DosError:= PathArgToFullPath(path, fullpath);
    FExpand:= fullpath;
  end;

{$ENDIF}

  procedure FSplit (path: pathstr; var dir: dirstr; var name: namestr; var ext: extstr);

  var
    dotPos,colonPos,i : longint;
  
  begin
    colonPos:=0;
    dotPos:=256;
    i:=Length(path);
    while (i>0) and (colonPos=0) Do
      begin
        If (dotPos=256) and (path[i]='.') Then
          dotPos:=i;
        If (path[i]=':') Then
          colonPos:=i;
        Dec(i);
      end;
    ext:=Copy(path,dotPos,255);
    dir:=Copy(path,1,colonPos);
    name:=Copy(path,colonPos + 1,dotPos - colonPos - 1);
  end;

  procedure GetFTime (var f ; var time: longint);

    var
      spec: FSSpec;
      paramBlock: CInfoPBRec;

  begin
    DosError := PathArgToFSSpec(filerec(f).name, spec);
    if (DosError = 0) or (DosError = 2) then
      begin
        DosError := DoFindOne(spec, paramBlock);
        if DosError = 0 then
          time := MacTimeToDosPackedTime(paramBlock.ioFlMdDat);
      end;
  end;

  procedure SetFTime (var f ; time: longint);

    var
      spec: FSSpec;
      paramBlock: CInfoPBRec;
      d: DateTimeRec; {Mac OS datastructure}
      t: datetime; 
      macfiletime: UInt32;

  begin
    DosError := PathArgToFSSpec(filerec(f).name, spec);
    if (DosError = 0) or (DosError = 2) then
      begin
        DosError := DoFindOne(spec, paramBlock);
        if DosError = 0 then
          begin
            Unpacktime(time, t);
            with t do
              begin
                d.year := year;
                d.month := month;
                d.day := day;
                d.hour := hour;
                d.minute := min;
                d.second := sec;
              end;
            DateToSeconds(d, macfiletime);
            paramBlock.ioFlMdDat := macfiletime;
            DosError := DoSetOne(spec, paramBlock);
          end;
      end;
  end;

  procedure GetFAttr (var f ; var attr: word);

    var
      spec: FSSpec;
      paramBlock: CInfoPBRec;

  begin
    DosError := PathArgToFSSpec(filerec(f).name, spec);
    if (DosError = 0) or (DosError = 2) then
      begin
        DosError := DoFindOne(spec, paramBlock);
        if DosError = 0 then
          attr := GetFileAttrFromPB(paramBlock);
      end;
  end;

  procedure SetFAttr (var f ; attr: word);

    var
      spec: FSSpec;
      paramBlock: CInfoPBRec;

  begin
    if (attr and VolumeID) <> 0 then
      begin
        Doserror := 5;
      end;

    DosError := PathArgToFSSpec(filerec(f).name, spec);
    if (DosError = 0) or (DosError = 2) then
      begin
        DosError := DoFindOne(spec, paramBlock);
        if DosError = 0 then
          begin
            SetPBFromFileAttr(paramBlock, attr);
            DosError := DoSetOne(spec, paramBlock);

            if (paramBlock.ioFlAttrib and $10) = 0 then    {check not directory}
              if DosError = 0 then
                if (attr and readonly) <> 0 then
                  DosError := MacOSErr2RTEerr(FSpSetFLock(spec))
                else
                  DosError := MacOSErr2RTEerr(FSpRstFLock(spec));
          end;
      end;
  end;

{******************************************************************************
                             --- Environment ---
******************************************************************************}

Function EnvCount: Longint;
var
  envcnt : longint;
  p      : ppchar;
Begin
  envcnt:=0;
  p:=envp;      {defined in system}
  while (p^<>nil) do
   begin
     inc(envcnt);
     inc(p);
   end;
  EnvCount := envcnt
End;


Function EnvStr (Index: longint): String;

Var
  i : longint;
  p : ppchar;
Begin
  p:=envp;      {defined in system}
  i:=1;
  while (i<Index) and (p^<>nil) do
    begin
      inc(i);
      inc(p);
    end;
  if p=nil then
    envstr:=''
  else
    begin
      envstr:=strpas(p^) + '=' + strpas(p^+strlen(p^)+1)
    end;
End;


function c_getenv(varname: PChar): PChar; {TODO perhaps move to a separate inc file.}
  external 'StdCLib' name 'getenv';

Function GetEnv(EnvVar: String): String;
var
  p: PChar;
  name: String;
Begin
  name:= EnvVar+#0;
  p:= c_getenv(@name[1]);
  if p=nil then
   GetEnv:=''
  else
   GetEnv:=StrPas(p);
End;

{******************************************************************************
                      --- Do Nothing Procedures/Functions ---
******************************************************************************}

Procedure getintvec(intno : byte;var vector : pointer);
Begin
  {! No MacOS equivalent !}
End;

Procedure setintvec(intno : byte;vector : pointer);
Begin
  {! No MacOS equivalent !}
End;

Procedure SwapVectors;
Begin
  {! No MacOS equivalent !}
End;

Procedure Keep(exitcode : word);
Begin
  {! No MacOS equivalent !}
End;

Procedure GetCBreak(Var BreakValue: Boolean);
Begin
  {! Might be implemented in future on MacOS to handle Cmd-. (period) key press}
  breakvalue:=true
End;

Procedure SetCBreak(BreakValue: Boolean);
Begin
  {! Might be implemented in future on MacOS to handle Cmd-. (period) key press}
End;

Procedure GetVerify(Var Verify: Boolean);
Begin
  {! Might be implemented in future on MacOS}
  Verify:=true;
End;

Procedure SetVerify(Verify: Boolean);
Begin
  {! Might be implemented in future on MacOS}
End;

function  GetShortName(var p : String) : boolean;

begin
  { short=long under MacOS}
 GetShortName:=True;
end;

function  GetLongName(var p : String) : boolean;
begin
  { short=long under MacOS}
 GetLongName:=True;
end;

{******************************************************************************
                            --- Initialization ---
******************************************************************************}

End.
