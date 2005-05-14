{
    $Id$
    Copyright (c) 2001-2002 by Peter Vreman

    This unit implements support import,export,link routines for MacOS.

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

 ****************************************************************************
}
unit t_macos;

{$i fpcdefs.inc}

interface

  uses
     import,symsym,symdef,link;

  type
    timportlibmacos=class(timportlib)
      procedure preparelib(const s:string);override;
      procedure importprocedure(aprocdef:tprocdef;const module:string;index:longint;const name:string);override;
      procedure importvariable(vs:tglobalvarsym;const name,module:string);override;
      procedure generatelib;override;
    end;

    tlinkermpw=class(texternallinker)
    private
      Function  WriteResponseFile(isdll:boolean) : Boolean;
    public
      constructor Create;override;
      procedure SetDefaultInfo;override;
      function  MakeExecutable:boolean;override;
    end;

implementation

    uses
       cutils,cclasses,
       globtype,globals,systems,verbose,script,fmodule,i_macos,
       symconst;

{*****************************************************************************
                               TIMPORTLIBMACOS
*****************************************************************************}

procedure timportlibmacos.preparelib(const s : string);
begin
end;


procedure timportlibmacos.importprocedure(aprocdef:tprocdef;const module:string;index:longint;const name:string);
begin
  { insert sharedlibrary }
  current_module.linkothersharedlibs.add(SplitName(module),link_allways);
end;


procedure timportlibmacos.importvariable(vs:tglobalvarsym;const name,module:string);
begin
  { insert sharedlibrary }
  current_module.linkothersharedlibs.add(SplitName(module),link_allways);
  { reset the mangledname and turn off the dll_var option }
  vs.set_mangledname(name);
  exclude(vs.varoptions,vo_is_dll_var);
end;


procedure timportlibmacos.generatelib;
begin
end;

{*****************************************************************************
                                  TLINKERMPW
*****************************************************************************}

Constructor TLinkerMPW.Create;
begin
  Inherited Create;
  //LibrarySearchPath.AddPath('/lib;/usr/lib;/usr/X11R6/lib',true);
end;


procedure TLinkerMPW.SetDefaultInfo;

begin
  with Info do
   begin
     ExeCmd[1]:='Execute $RES'; {The link.res file contains the whole link command.}
     //ExeCmd[1]:='PPCLink $OPT $DYNLINK $STATIC $STRIP -tocdataref off -dead on -o $EXE -@filelist $RES';
     //DllCmd[1]:='PPCLink $OPT $INIT $FINI $SONAME -shared -o $EXE -@filelist $RES';
   end;
end;


Function TLinkerMPW.WriteResponseFile(isdll:boolean) : Boolean;
Var
  linkres      : TLinkRes;
  s,heapsizestr: string;

begin
  WriteResponseFile:=False;
  { Open link.res file }
  linkRes:=TLinkRes.Create(outputexedir+Info.ResName);

  with linkRes do
    begin
      {#182 is escape char in MPW (analog to backslash in unix). The space}
      {ensures there is whitespace separating items.}
      Add('PPCLink '#182);

      { Add MPW standard libraries}
      if apptype = app_cui then
          Add('"{PPCLibraries}PPCSIOW.o" '#182);

      {Even GUI apps must link to PPCToolLibs, because of the System unit
       which can be used by MPW tools as well as by GUI apps.}
      Add('"{PPCLibraries}PPCToolLibs.o" '#182);
      Add('"{SharedLibraries}InterfaceLib" '#182);
      Add('"{SharedLibraries}StdCLib" '#182);
      Add('"{SharedLibraries}MathLib" '#182);
      Add('"{PPCLibraries}StdCRuntime.o" '#182);
      Add('"{PPCLibraries}PPCCRuntime.o" '#182);

      {Add main objectfiles}
      while not ObjectFiles.Empty do
        begin
          s:=ObjectFiles.GetFirst;
          if s<>'' then
            Add(s+' '#182);
        end;

      {Add last lines of the link command}
      if apptype = app_tool then
        Add('-t "MPST" -c "MPS " '#182);

      if apptype = app_cui then {If SIOW, to avoid some warnings.}
        Add('-ignoredups __start -ignoredups .__start -ignoredups main -ignoredups .main -ignoredups qd '#182);

      Add('-tocdataref off -sym on -dead on -o '+ ScriptFixFileName(current_module.exefilename^));

      Add('Exit If "{Status}" != 0');

      if heapsize = 0 then
        heapsizestr:= HexStr(384000, 8)
      else
        heapsizestr:= HexStr(heapsize, 8);

      {Add a SIZE resource on the fly. It controls:
         * backgrounding is enabled, to facilitate debuging with Power Mac Debugger
         * it is signaled it is a 32 bit app. (perhaps not nessecary on PowerPC)
         * heapsize  }
      if apptype <> app_tool then
        begin
          Add('Echo "data ''SIZE'' (-1) '#182'{ $'#182'"1080 ' + heapsizestr + ' ' + heapsizestr +
                                         #182'" '#182'};" | Rez -a -o ' + ScriptFixFileName(current_module.exefilename^));
          Add('Exit If "{Status}" != 0');
        end;

      {Add mac resources}
      if apptype = app_cui then
        begin
          Add('Rez -a "{RIncludes}"SIOW.r -o ' + ScriptFixFileName(current_module.exefilename^));
          Add('Exit If "{Status}" != 0');
        end;

      while not (current_module.ResourceFiles.Empty) do
        begin
          s := Current_module.ResourceFiles.GetFirst;
          if Copy(s,Length(s)-1,Length(s)) = '.r' then
            Add('Rez -a ' + s + ' -o ' + ScriptFixFileName(current_module.exefilename^))
          else
            Add('DeRez ' + s + ' | Rez -a -o ' + ScriptFixFileName(current_module.exefilename^));
          Add('Exit If "{Status}" != 0');
        end;

    end;

  { Write and Close response }
  linkres.writetodisk;
  linkres.Free;

  WriteResponseFile:=True;
end;


function TLinkerMPW.MakeExecutable:boolean;
var
  binstr,
  cmdstr  : string;
  success : boolean;
  DynLinkStr : string[60];
  StaticStr,
  StripStr   : string[40];

  s: string;

begin
  //TODO Only external link in MPW is possible, otherwise yell.

  if not(cs_link_extern in aktglobalswitches) then
    Message1(exec_i_linking,current_module.exefilename^);

{ Create some replacements }
  StripStr:='';
(*
  StaticStr:='';
  DynLinkStr:='';
  if (cs_link_staticflag in aktglobalswitches) then
   StaticStr:='-static';
  if (cs_link_strip in aktglobalswitches) then
   StripStr:='-s';
  If (cs_profile in aktmoduleswitches) or
     ((Info.DynamicLinker<>'') and (not SharedLibFiles.Empty)) then
   DynLinkStr:='-dynamic-linker='+Info.DynamicLinker;
*)

{ Prepare linking }
  SplitBinCmd(Info.ExeCmd[1],binstr,cmdstr);
  Replace(cmdstr,'$EXE',maybequoted(ScriptFixFileName(current_module.exefilename^)));
  Replace(cmdstr,'$OPT',Info.ExtraOptions);
  Replace(cmdstr,'$RES',maybequoted(ScriptFixFileName(outputexedir+Info.ResName)));
  Replace(cmdstr,'$STATIC',StaticStr);
  Replace(cmdstr,'$STRIP',StripStr);
  Replace(cmdstr,'$DYNLINK',DynLinkStr);

        WriteResponseFile(false);

        success:= true;
        if cs_link_on_target in aktglobalswitches then
                success:=DoExec('SetFile', ' -c ''MPS '' -t ''TEXT'' ' +
                                                                 ScriptFixFileName(outputexedir+Info.ResName),true,false);

{ Call linker }
        if success then
                success:=DoExec('Execute',CmdStr,true,false);

{ Remove ReponseFile }
  if (success) and not(cs_link_extern in aktglobalswitches) then
    RemoveFile(outputexedir+Info.ResName);

  MakeExecutable:=success;   { otherwise a recursive call to link method }
end;



{*****************************************************************************
                                  Initialize
*****************************************************************************}

initialization
{$ifdef m68k}
  RegisterTarget(system_m68k_macos_info);
  RegisterImport(system_m68k_macos,timportlibmacos);
{$endif m68k}
{$ifdef powerpc}
  RegisterExternalLinker(system_powerpc_macos_info,TLinkerMPW);
  RegisterTarget(system_powerpc_macos_info);
  RegisterImport(system_powerpc_macos,timportlibmacos);
{$endif powerpc}
end.
{
  $Log$
  Revision 1.23  2005-05-14 12:15:18  olle
    * Fix small issue for link script

  Revision 1.22  2005/03/25 21:55:43  jonas
    * removed some unused variables

  Revision 1.21  2005/02/14 17:13:10  peter
    * truncate log

  Revision 1.20  2005/02/08 22:30:32  olle
    + added SIZE resource facilities

  Revision 1.19  2005/01/24 17:53:12  olle
    + Mac style resource files can now be included in MacOS

  Revision 1.18  2005/01/09 16:35:41  olle
    + linker response file is now removed after linking

}
