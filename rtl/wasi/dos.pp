{
    This file is part of the Free Pascal run time library.
    Copyright (c) 1999-2000 by Michael Van Canneyt and Peter Vreman,
    members of the Free Pascal development team

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
Unit Dos;
Interface

Const
  FileNameLen = 255;

Type
  SearchRec =
{$ifndef FPC_REQUIRES_PROPER_ALIGNMENT}
    packed
{$endif FPC_REQUIRES_PROPER_ALIGNMENT}
    Record
  {Fill : array[1..21] of byte;  Fill replaced with below}
    SearchPos  : UInt64;      {directory position}
    SearchNum  : LongInt;     {to track which search this is}
    DirFD      : LongInt;     {directory fd handle for reading directory}
    SearchType : Byte;        {0=normal, 1=open will close, 2=only 1 file}
    SearchAttr : Byte;        {attribute we are searching for}
    Mode       : Word;
    Fill       : Array[1..1] of Byte; {future use}
  {End of fill}
    Attr       : Byte;        {attribute of found file}
    Time       : LongInt;     {last modify date of found file}
    Size       : LongInt;     {file size of found file}
    Reserved   : Word;        {future use}
    Name       : String[FileNameLen]; {name of found file}
    SearchSpec : String[FileNameLen]; {search pattern}
    NamePos    : Word;        {end of path, start of name position}
  End;

{$DEFINE HAS_FILENAMELEN}
{$i dosh.inc}

{Extra Utils}
function weekday(y,m,d : longint) : longint; platform;
Procedure WasiDateToDt(NanoSecsPast: UInt64; Var Dt: DateTime); platform;
Function DTToWasiDate(DT: DateTime): UInt64; platform;

{Disk}
//Function AddDisk(const path:string) : byte; platform;

Implementation

Uses
  WasiAPI, WasiUtil;

{$DEFINE HAS_GETMSCOUNT}

{$DEFINE FPC_FEXPAND_TILDE} { Tilde is expanded to home }
{$DEFINE FPC_FEXPAND_GETENVPCHAR} { GetEnv result is a PChar }

{$I dos.inc}


{******************************************************************************
                           --- Link C Lib if set ---
******************************************************************************}


{******************************************************************************
                        --- Info / Date / Time ---
******************************************************************************}

Function DosVersion:Word;
Begin
End;

function WeekDay (y,m,d:longint):longint;
{
  Calculates th day of the week. returns -1 on error
}
var
  u,v : longint;
begin
  if (m<1) or (m>12) or (y<1600) or (y>4000) or
     (d<1) or (d>30+((m+ord(m>7)) and 1)-ord(m=2)) or
     ((m*d=58) and (((y mod 4>0) or (y mod 100=0)) and (y mod 400>0))) then
   WeekDay:=-1
  else
   begin
     u:=m;
     v:=y;
     if m<3 then
      begin
        inc(u,12);
        dec(v);
      end;
     WeekDay:=(d+2*u+((3*(u+1)) div 5)+v+(v div 4)-(v div 100)+(v div 400)+1) mod 7;
   end;
end;


Procedure GetDate(Var Year, Month, MDay, WDay: Word);
var
  NanoSecsPast: __wasi_timestamp_t;
  DT: DateTime;
begin
  if __wasi_clock_time_get(__WASI_CLOCKID_REALTIME,10000000,@NanoSecsPast)=__WASI_ERRNO_SUCCESS then
  begin
    { todo: convert UTC to local time, as soon as we can get the local timezone
      from WASI: https://github.com/WebAssembly/WASI/issues/239 }
    WasiDateToDT(NanoSecsPast,DT);
    Year:=DT.Year;
    Month:=DT.Month;
    MDay:=DT.Day;
    WDay:=weekday(DT.Year,DT.Month,DT.Day);
  end
  else
  begin
    Year:=0;
    Month:=0;
    MDay:=0;
    WDay:=0;
  end;
end;


procedure  SetTime(Hour,Minute,Second,sec100:word);
begin
end;

procedure SetDate(Year,Month,Day:Word);
begin
end;


Function SetDateTime(Year,Month,Day,hour,minute,second:Word) : Boolean;
begin
end;


Procedure GetTime(Var Hour, Minute, Second, Sec100: Word);
var
  NanoSecsPast: __wasi_timestamp_t;
begin
  if __wasi_clock_time_get(__WASI_CLOCKID_REALTIME,10000000,@NanoSecsPast)=__WASI_ERRNO_SUCCESS then
  begin
    { todo: convert UTC to local time, as soon as we can get the local timezone
      from WASI: https://github.com/WebAssembly/WASI/issues/239 }
    NanoSecsPast:=NanoSecsPast div 10000000;
    Sec100:=NanoSecsPast mod 100;
    NanoSecsPast:=NanoSecsPast div 100;
    Second:=NanoSecsPast mod 60;
    NanoSecsPast:=NanoSecsPast div 60;
    Minute:=NanoSecsPast mod 60;
    NanoSecsPast:=NanoSecsPast div 60;
    Hour:=NanoSecsPast mod 24;
  end
  else
  begin
    Hour:=0;
    Minute:=0;
    Second:=0;
    Sec100:=0;
  end;
end;


Function DTToWasiDate(DT: DateTime): UInt64;
const
  days_in_month: array [boolean, 1..12] of Byte =
    ((31,28,31,30,31,30,31,31,30,31,30,31),
     (31,29,31,30,31,30,31,31,30,31,30,31));
  days_before_month: array [boolean, 1..12] of Word =
    ((0,
      0+31,
      0+31+28,
      0+31+28+31,
      0+31+28+31+30,
      0+31+28+31+30+31,
      0+31+28+31+30+31+30,
      0+31+28+31+30+31+30+31,
      0+31+28+31+30+31+30+31+31,
      0+31+28+31+30+31+30+31+31+30,
      0+31+28+31+30+31+30+31+31+30+31,
      0+31+28+31+30+31+30+31+31+30+31+30),
     (0,
      0+31,
      0+31+29,
      0+31+29+31,
      0+31+29+31+30,
      0+31+29+31+30+31,
      0+31+29+31+30+31+30,
      0+31+29+31+30+31+30+31,
      0+31+29+31+30+31+30+31+31,
      0+31+29+31+30+31+30+31+31+30,
      0+31+29+31+30+31+30+31+31+30+31,
      0+31+29+31+30+31+30+31+31+30+31+30));
var
  leap: Boolean;
  days_in_year: LongInt;
  y,m: LongInt;
begin
  if (DT.year<1970) or (DT.month<1) or (DT.month>12) or (DT.day<1) or (DT.day>31) or
     (DT.hour>=24) or (DT.min>=60) or (DT.sec>=60) then
  begin
    DTToWasiDate:=-1;
    exit;
  end;
  leap:=((DT.year mod 4)=0) and (((DT.year mod 100)<>0) or ((DT.year mod 400)=0));
  if DT.day>days_in_month[leap,DT.month] then
  begin
    DTToWasiDate:=-1;
    exit;
  end;
  DTToWasiDate:=0;
  for y:=1970 to DT.year-1 do
    if ((y mod 4)=0) and (((y mod 100)<>0) or ((y mod 400)=0)) then
      Inc(DTToWasiDate,366)
    else
      Inc(DTToWasiDate,365);
  Inc(DTToWasiDate,days_before_month[leap,DT.month]);
  Inc(DTToWasiDate,DT.day-1);
  DTToWasiDate:=((((DTToWasiDate*24+DT.hour)*60+DT.min)*60)+DT.sec)*1000000000;
end;


Procedure WasiDateToDt(NanoSecsPast: UInt64; Var Dt: DateTime);
const
  days_in_month: array [boolean, 1..12] of Byte =
    ((31,28,31,30,31,30,31,31,30,31,30,31),
     (31,29,31,30,31,30,31,31,30,31,30,31));
var
  leap: Boolean;
  days_in_year: LongInt;
Begin
  { todo: convert UTC to local time, as soon as we can get the local timezone
    from WASI: https://github.com/WebAssembly/WASI/issues/239 }
  NanoSecsPast:=NanoSecsPast div 1000000000;
  Dt.Sec:=NanoSecsPast mod 60;
  NanoSecsPast:=NanoSecsPast div 60;
  Dt.Min:=NanoSecsPast mod 60;
  NanoSecsPast:=NanoSecsPast div 60;
  Dt.Hour:=NanoSecsPast mod 24;
  NanoSecsPast:=NanoSecsPast div 24;
  Dt.Year:=1970;
  leap:=false;
  days_in_year:=365;
  while NanoSecsPast>=days_in_year do
  begin
    Dec(NanoSecsPast,days_in_year);
    Inc(Dt.Year);
    leap:=((Dt.Year mod 4)=0) and (((Dt.Year mod 100)<>0) or ((Dt.Year mod 400)=0));
    if leap then
      days_in_year:=366
    else
      days_in_year:=365;
  end;
  Dt.Month:=1;
  Inc(NanoSecsPast);
  while NanoSecsPast>days_in_month[leap,Dt.Month] do
  begin
    Dec(NanoSecsPast,days_in_month[leap,Dt.Month]);
    Inc(Dt.Month);
  end;
  Dt.Day:=Word(NanoSecsPast);
End;


function GetMsCount: int64;
var
  NanoSecsPast: __wasi_timestamp_t;
begin
  if __wasi_clock_time_get(__WASI_CLOCKID_REALTIME,1000000,@NanoSecsPast)=__WASI_ERRNO_SUCCESS then
    GetMsCount:=NanoSecsPast div 1000000
  else
    GetMsCount:=0;
end;


{******************************************************************************
                               --- Exec ---
******************************************************************************}

Procedure Exec (Const Path: PathStr; Const ComLine: ComStr);
Begin
End;


{******************************************************************************
                               --- Disk ---
******************************************************************************}

{
  The Diskfree and Disksize functions need a file on the specified drive, since this
  is required for the fpstatfs system call.
  These filenames are set in drivestr[0..26], and have been preset to :
   0 - '.'      (default drive - hence current dir is ok.)
   1 - '/fd0/.'  (floppy drive 1 - should be adapted to local system )
   2 - '/fd1/.'  (floppy drive 2 - should be adapted to local system )
   3 - '/'       (C: equivalent of dos is the root partition)
   4..26          (can be set by you're own applications)
  ! Use AddDisk() to Add new drives !
  They both return -1 when a failure occurs.
}
Const
  FixDriveStr : array[0..3] of pchar=(
    '.',
    '/fd0/.',
    '/fd1/.',
    '/.'
    );
const
  Drives   : byte = 4;
var
  DriveStr : array[4..26] of pchar;

Function AddDisk(const path:string) : byte;
begin
{  if not (DriveStr[Drives]=nil) then
   FreeMem(DriveStr[Drives]);
  GetMem(DriveStr[Drives],length(Path)+1);
  StrPCopy(DriveStr[Drives],path);
  AddDisk:=Drives;
  inc(Drives);
  if Drives>26 then
    Drives:=4;}
end;



Function DiskFree(Drive: Byte): int64;
{var
  fs : tstatfs;}
Begin
{  if ((Drive<4) and (not (fixdrivestr[Drive]=nil)) and (fpStatFS(fixdrivestr[drive],@fs)<>-1)) or
     ((not (drivestr[Drive]=nil)) and (fpStatFS(drivestr[drive],@fs)<>-1)) then
   Diskfree:=int64(fs.bavail)*int64(fs.bsize)
  else
   Diskfree:=-1;}
End;



Function DiskSize(Drive: Byte): int64;
{var
  fs : tstatfs;}
Begin
{  if ((Drive<4) and (not (fixdrivestr[Drive]=nil)) and (fpStatFS(fixdrivestr[drive],@fs)<>-1)) or
     ((not (drivestr[Drive]=nil)) and (fpStatFS(drivestr[drive],@fs)<>-1)) then
   DiskSize:=int64(fs.blocks)*int64(fs.bsize)
  else
   DiskSize:=-1;}
End;



Procedure FreeDriveStr;
{var
  i: longint;}
begin
{  for i:=low(drivestr) to high(drivestr) do
    if assigned(drivestr[i]) then
      begin
        freemem(drivestr[i]);
        drivestr[i]:=nil;
      end;}
end;

{******************************************************************************
                       --- Findfirst FindNext ---
******************************************************************************}


Const
  RtlFindSize = 15;
Type
  RtlFindRecType = Record
    DirFD    : LongInt;
    SearchNum,
    LastUsed : LongInt;
  End;
Var
  RtlFindRecs   : Array[1..RtlFindSize] of RtlFindRecType;
  CurrSearchNum : LongInt;


Procedure FindClose(Var f: SearchRec);
{
  Closes dirfd if it is open
}
Var
  res: __wasi_errno_t;
  i : longint;
Begin
  if f.SearchType=0 then
   begin
     i:=1;
     repeat
       if (RtlFindRecs[i].SearchNum=f.SearchNum) then
        break;
       inc(i);
     until (i>RtlFindSize);
     If i<=RtlFindSize Then
      Begin
        RtlFindRecs[i].SearchNum:=0;
        if f.dirfd<>-1 then
          repeat
            res:=__wasi_fd_close(f.dirfd);
          until (res=__WASI_ERRNO_SUCCESS) or (res<>__WASI_ERRNO_INTR);
      End;
   end;
  f.dirfd:=-1;
End;


Function FindGetFileInfo(const s:string;var f:SearchRec):boolean;
var
  DT   : DateTime;
  st   : __wasi_filestat_t;
  fd   : __wasi_fd_t;
  pr   : RawByteString;
  Info : record
    FMode: LongInt;
    FSize: __wasi_filesize_t;
    FMTime: __wasi_timestamp_t;
  end;
begin
  FindGetFileInfo:=false;
  if ConvertToFdRelativePath(s,fd,pr)<>0 then
    exit;
  { todo: __WASI_LOOKUPFLAGS_SYMLINK_FOLLOW??? }
  if __wasi_path_filestat_get(fd,0,PChar(pr),Length(pr),@st)<>__WASI_ERRNO_SUCCESS then
    exit;
  info.FSize:=st.size;
  info.FMTime:=st.mtim;
  if st.filetype=__WASI_FILETYPE_DIRECTORY then
   info.fmode:=$10
  else
   info.fmode:=$0;
  {if (st.st_mode and STAT_IWUSR)=0 then
   info.fmode:=info.fmode or 1;}
  if s[f.NamePos+1]='.' then
   info.fmode:=info.fmode or $2;

  If ((Info.FMode and Not(f.searchattr))=0) Then
   Begin
     f.Name:=Copy(s,f.NamePos+1,255);
     f.Attr:=Info.FMode;
     f.Size:=Info.FSize;
     {f.mode:=st.st_mode;}
     WasiDateToDT(Info.FMTime, DT);
     PackTime(DT,f.Time);
     FindGetFileInfo:=true;
   End;
end;


Function  FindLastUsed: Longint;
{
  Find unused or least recently used dirpointer slot in findrecs array
}
Var
  BestMatch,i : Longint;
  Found       : Boolean;
Begin
  BestMatch:=1;
  i:=1;
  Found:=False;
  While (i <= RtlFindSize) And (Not Found) Do
   Begin
     If (RtlFindRecs[i].SearchNum = 0) Then
      Begin
        BestMatch := i;
        Found := True;
      End
     Else
      Begin
        If RtlFindRecs[i].LastUsed > RtlFindRecs[BestMatch].LastUsed Then
         BestMatch := i;
      End;
     Inc(i);
   End;
  FindLastUsed := BestMatch;
End;



Procedure FindNext(Var f: SearchRec);
{
  re-opens dir if not already in array and calls FindWorkProc
}
Var
  fd,ourfd: __wasi_fd_t;
  pr: RawByteString;
  res: __wasi_errno_t;
  DirName  : RawByteString;
  i,
  ArrayPos : Longint;
  FName,
  SName    : string;
  Found,
  Finished : boolean;
  Buf: array [0..SizeOf(__wasi_dirent_t)+256-1] of Byte;
  BufUsed: __wasi_size_t;
Begin
  If f.SearchType=0 Then
   Begin
     ArrayPos:=0;
     For i:=1 to RtlFindSize Do
      Begin
        If RtlFindRecs[i].SearchNum = f.SearchNum Then
         ArrayPos:=i;
        Inc(RtlFindRecs[i].LastUsed);
      End;
     If ArrayPos=0 Then
      Begin
        If f.NamePos = 0 Then
         DirName:='./'
        Else
         DirName:=Copy(f.SearchSpec,1,f.NamePos);
        if ConvertToFdRelativePath(DirName,fd,pr)=0 then
         begin
           repeat
             res:=__wasi_path_open(fd,
                                   0,
                                   PChar(pr),
                                   length(pr),
                                   __WASI_OFLAGS_DIRECTORY,
                                   __WASI_RIGHTS_FD_READDIR,
                                   __WASI_RIGHTS_FD_READDIR,
                                   0,
                                   @ourfd);
           until (res=__WASI_ERRNO_SUCCESS) or (res<>__WASI_ERRNO_INTR);
           If res=__WASI_ERRNO_SUCCESS Then
            begin
              f.DirFD := ourfd;
              ArrayPos:=FindLastUsed;
              If RtlFindRecs[ArrayPos].SearchNum > 0 Then
                repeat
                  res:=__wasi_fd_close(RtlFindRecs[arraypos].DirFD);
                until (res=__WASI_ERRNO_SUCCESS) or (res<>__WASI_ERRNO_INTR);
              RtlFindRecs[ArrayPos].SearchNum := f.SearchNum;
              RtlFindRecs[ArrayPos].DirFD := f.DirFD;
            end
           else
            f.DirFD:=-1;
         end
        else
         f.DirFD:=-1;
      End;
     if ArrayPos>0 then
       RtlFindRecs[ArrayPos].LastUsed:=0;
   end;
{Main loop}
  SName:=Copy(f.SearchSpec,f.NamePos+1,255);
  Found:=False;
  Finished:=(f.DirFD=-1);
  While Not Finished Do
   Begin
     res:=__wasi_fd_readdir(f.DirFD,
                            @buf,
                            SizeOf(buf),
                            f.searchpos,
                            @bufused);
     if (res<>__WASI_ERRNO_SUCCESS) or (bufused<=SizeOf(__wasi_dirent_t)) then
      FName:=''
     else
      begin
        if P__wasi_dirent_t(@buf)^.d_namlen<=255 then
          SetLength(FName,P__wasi_dirent_t(@buf)^.d_namlen)
        else
          SetLength(FName,255);
        Move(buf[SizeOf(__wasi_dirent_t)],FName[1],Length(FName));
        f.searchpos:=P__wasi_dirent_t(@buf)^.d_next;
      end;
     If FName='' Then
      Finished:=True
     Else
      Begin
        If FNMatch(SName,FName) Then
         Begin
           Found:=FindGetFileInfo(Copy(f.SearchSpec,1,f.NamePos)+FName,f);
           if Found then
            Finished:=true;
         End;
      End;
   End;
{Shutdown}
  If Found Then
   DosError:=0
  Else
   Begin
     FindClose(f);
     DosError:=18;
   End;
End;


Procedure FindFirst(Const Path: PathStr; Attr: Word; Var f: SearchRec);
{
  opens dir and calls FindWorkProc
}
Begin
  fillchar(f,sizeof(f),0);
  if Path='' then
   begin
     DosError:=3;
     exit;
   end;
{Create Info}
  f.SearchSpec := Path;
  {We always also search for readonly and archive, regardless of Attr:}
  f.SearchAttr := Attr or archive or readonly;
  f.SearchPos  := 0;
  f.NamePos := Length(f.SearchSpec);
  while (f.NamePos>0) and not (f.SearchSpec[f.NamePos] in AllowDirectorySeparators) do
   dec(f.NamePos);
{Wildcards?}
  if (Pos('?',Path)=0)  and (Pos('*',Path)=0) then
   begin
     if FindGetFileInfo(Path,f) then
      DosError:=0
     else
      begin
        { According to tdos2 test it should return 18
        if ErrNo=Sys_ENOENT then
         DosError:=3
        else }
         DosError:=18;
      end;
     f.DirFD:=-1;
     f.SearchType:=1;
     f.searchnum:=-1;
   end
  else
{Find Entry}
   begin
     Inc(CurrSearchNum);
     f.SearchNum:=CurrSearchNum;
     f.SearchType:=0;
     FindNext(f);
   end;
End;


{******************************************************************************
                               --- File ---
******************************************************************************}

Function FSearch(path : pathstr;dirlist : string) : pathstr;
{Var
  info : BaseUnix.stat;}
Begin
{  if (length(Path)>0) and (path[1]='/') and (fpStat(path,info)>=0) and (not fpS_ISDIR(Info.st_Mode)) then
    FSearch:=path
  else
    FSearch:=Unix.FSearch(path,dirlist);}
End;

Procedure GetFAttr(var f; var attr : word);
Var
  pr: RawByteString;
  fd: __wasi_fd_t;
  Info: __wasi_filestat_t;
Begin
  DosError:=0;
  Attr:=0;
  if ConvertToFdRelativePath(textrec(f).name,fd,pr)<>0 then
    begin
      DosError:=3;
      exit;
    end;
  if __wasi_path_filestat_get(fd,__WASI_LOOKUPFLAGS_SYMLINK_FOLLOW,PChar(pr),length(pr),@Info)<>__WASI_ERRNO_SUCCESS then
    begin
      DosError:=3;
      exit;
    end;
  if Info.filetype=__WASI_FILETYPE_DIRECTORY then
    Attr:=$10;
  if filerec(f).name[0]='.' then
    Attr:=Attr or $2;
end;

Procedure getftime (var f; var time : longint);
Var
  res: __wasi_errno_t;
  Info: __wasi_filestat_t;
  DT: DateTime;
Begin
  doserror:=0;
  res:=__wasi_fd_filestat_get(filerec(f).handle,@Info);
  if res<>__WASI_ERRNO_SUCCESS then
   begin
     Time:=0;
     case res of
       __WASI_ERRNO_ACCES,
       __WASI_ERRNO_NOTCAPABLE:
         doserror:=5;
       else
         doserror:=6;
     end;
     exit
   end
  else
   WasiDateToDt(Info.mtim,DT);
  PackTime(DT,Time);
End;

Procedure setftime(var f; time : longint);
Var
  DT: DateTime;
  modtime: UInt64;
  pr: RawByteString;
  fd: __wasi_fd_t;
Begin
  doserror:=0;
  UnPackTime(Time,DT);
  modtime:=DTToWasiDate(DT);
  if ConvertToFdRelativePath(textrec(f).name,fd,pr)<>0 then
    begin
      doserror:=3;
      exit;
    end;
  if __wasi_path_filestat_set_times(fd,0,PChar(pr),length(pr),0,modtime,
     __WASI_FSTFLAGS_MTIM or __WASI_FSTFLAGS_ATIM_NOW)<>__WASI_ERRNO_SUCCESS then
    doserror:=3;
End;

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
  if p<>nil then
    while p^<>nil do
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
  if (Index <= 0) or (envp=nil) then
    envstr:=''
  else
    begin
      p:=envp;      {defined in system}
      i:=1;
      while (i<Index) and (p^<>nil) do
        begin
          inc(i);
          inc(p);
        end;
      if p^=nil then
        envstr:=''
      else
        envstr:=strpas(p^)
    end;
end;


Function GetEnv(EnvVar: String): String;
var
  hp : ppchar;
  hs : string;
  eqpos : longint;
Begin
  getenv:='';
  hp:=envp;
  if hp<>nil then
    while assigned(hp^) do
      begin
        hs:=strpas(hp^);
        eqpos:=pos('=',hs);
        if copy(hs,1,eqpos-1)=envvar then
          begin
            getenv:=copy(hs,eqpos+1,length(hs)-eqpos);
            break;
          end;
        inc(hp);
      end;
End;


Procedure setfattr (var f;attr : word);
Begin
  {! No WASI equivalent !}
  { Fail for setting VolumeId }
  if (attr and VolumeID)<>0 then
   doserror:=5;
End;



{******************************************************************************
                            --- Initialization ---
******************************************************************************}

//Finalization
//  FreeDriveStr;
End.
