{
    $Id$
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit does the parsing process

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
unit parser;

{$i fpcdefs.inc}

interface

{$ifdef PREPROCWRITE}
    procedure preprocess(const filename:string);
{$endif PREPROCWRITE}
    procedure compile(const filename:string);
    procedure initparser;
    procedure doneparser;

implementation

    uses
      cutils,cclasses,
      globtype,version,tokens,systems,globals,verbose,
      symbase,symtable,symsym,
      finput,fmodule,fppu,
      aasmbase,aasmtai,
      cgbase,
      script,gendef,
{$ifdef BrowserLog}
      browlog,
{$endif BrowserLog}
{$ifdef UseExcept}
      tpexcept,
{$endif UseExcept}
{$ifdef GDB}
      gdb,
{$endif GDB}
      comphook,
      scanner,scandir,
      pbase,ptype,psystem,pmodules,psub,
      cresstr,cpuinfo,procinfo;


    procedure initparser;
      begin
         { ^M means a string or a char, because we don't parse a }
         { type declaration                                      }
         ignore_equal:=false;

         { we didn't parse a object or class declaration }
         { and no function header                        }
         testcurobject:=0;

         { Current compiled module/proc }
         objectlibrary:=nil;
         current_module:=nil;
         compiled_module:=nil;
         current_procinfo:=nil;

         loaded_units:=TLinkedList.Create;

         usedunits:=TLinkedList.Create;

         { global switches }
         aktglobalswitches:=initglobalswitches;

         aktsourcecodepage:=initsourcecodepage;

         { initialize scanner }
         InitScanner;
         InitScannerDirectives;

         { scanner }
         c:=#0;
         pattern:='';
         orgpattern:='';
         current_scanner:=nil;

         { register all nodes and tais }
         registernodes;
         registertais;

         { memory sizes }
         if stacksize=0 then
           stacksize:=target_info.stacksize;

         { open assembler response }
         if cs_link_on_target in aktglobalswitches then
           GenerateAsmRes(outputexedir+inputfile+'_ppas')
         else
           GenerateAsmRes(outputexedir+'ppas');

         { open deffile }
         DefFile:=TDefFile.Create(outputexedir+inputfile+target_info.defext);

         { list of generated .o files, so the linker can remove them }
         SmartLinkOFiles:=TStringList.Create;

         { codegen }
         if paraprintnodetree<>0 then
           printnode_reset;

         { target specific stuff }
         case target_info.system of
           system_powerpc_morphos:
             include(supported_calling_conventions,pocall_syscall);
           system_m68k_amiga:
             include(supported_calling_conventions,pocall_syscall);
         end;
      end;


    procedure doneparser;
      begin
         { Reset current compiling info, so destroy routines can't
           reference the data that might already be destroyed }
         objectlibrary:=nil;
         current_module:=nil;
         compiled_module:=nil;
         current_procinfo:=nil;

         { unload units }
         loaded_units.free;
         usedunits.free;

         { if there was an error in the scanner, the scanner is
           still assinged }
         if assigned(current_scanner) then
          begin
            current_scanner.free;
            current_scanner:=nil;
          end;

         { close scanner }
         DoneScanner;

         { close ppas,deffile }
         asmres.free;
         deffile.free;

         { free list of .o files }
         SmartLinkOFiles.Free;
      end;




{$ifdef PREPROCWRITE}
    procedure preprocess(const filename:string);
      var
        i : longint;
      begin
         new(preprocfile,init('pre'));
       { initialize a module }
         current_module:=new(pmodule,init(filename,false));

         macrosymtablestack:= initialmacrosymtable;
         current_module.localmacrosymtable:= tmacrosymtable.create(false);
         current_module.localmacrosymtable.next:= initialmacrosymtable;
         macrosymtablestack:= current_module.localmacrosymtable;
         ConsolidateMode;

         main_module:=current_module;
       { startup scanner, and save in current_module }
         current_scanner:=new(pscannerfile,Init(filename));
         current_module.scanner:=current_scanner;
       { loop until EOF is found }
         repeat
           current_scanner^.readtoken;
           preprocfile^.AddSpace;
           case token of
             _ID :
               begin
                 preprocfile^.Add(orgpattern);
               end;
             _REALNUMBER,
             _INTCONST :
               preprocfile^.Add(pattern);
             _CSTRING :
               begin
                 i:=0;
                 while (i<length(pattern)) do
                  begin
                    inc(i);
                    if pattern[i]='''' then
                     begin
                       insert('''',pattern,i);
                       inc(i);
                     end;
                  end;
                 preprocfile^.Add(''''+pattern+'''');
               end;
             _CCHAR :
               begin
                 case pattern[1] of
                   #39 :
                     pattern:='''''''';
                   #0..#31,
                   #128..#255 :
                     begin
                       str(ord(pattern[1]),pattern);
                       pattern:='#'+pattern;
                     end;
                   else
                     pattern:=''''+pattern[1]+'''';
                 end;
                 preprocfile^.Add(pattern);
               end;
             _EOF :
               break;
             else
               preprocfile^.Add(tokeninfo^[token].str)
           end;
         until false;
       { free scanner }
         dispose(current_scanner,done);
         current_scanner:=nil;
       { close }
         dispose(preprocfile,done);
      end;
{$endif PREPROCWRITE}


{*****************************************************************************
                      Create information for a new module
*****************************************************************************}

    procedure init_module;
      begin
         { Create assembler output lists for CG }
         exprasmlist:=taasmoutput.create;
         datasegment:=taasmoutput.create;
         codesegment:=taasmoutput.create;
         bsssegment:=taasmoutput.create;
         debuglist:=taasmoutput.create;
         withdebuglist:=taasmoutput.create;
         consts:=taasmoutput.create;
         rttilist:=taasmoutput.create;
         picdata:=taasmoutput.create;
         if target_info.system=system_powerpc_darwin then
           picdata.concat(tai_simple.create(ait_non_lazy_symbol_pointer));
         ResourceStringList:=Nil;
         importssection:=nil;
         exportssection:=nil;
         resourcesection:=nil;
         { Resource strings }
         ResourceStrings:=TResourceStrings.Create;
         { use the librarydata from current_module }
         objectlibrary:=current_module.librarydata;
      end;


    procedure done_module;
{$ifdef MEMDEBUG}
      var
        d : tmemdebug;
{$endif}
      begin
{$ifdef MEMDEBUG}
         d:=tmemdebug.create(current_module.modulename^+' - asmlists');
{$endif}
         exprasmlist.free;
         codesegment.free;
         bsssegment.free;
         datasegment.free;
         debuglist.free;
         withdebuglist.free;
         consts.free;
         rttilist.free;
         picdata.free;
         if assigned(ResourceStringList) then
          ResourceStringList.free;
         if assigned(importssection) then
          importssection.free;
         if assigned(exportssection) then
          exportssection.free;
         if assigned(resourcesection) then
          resourcesection.free;
{$ifdef MEMDEBUG}
         d.free;
{$endif}
         { resource strings }
         ResourceStrings.free;
         objectlibrary:=nil;
      end;


{*****************************************************************************
                             Compile a source file
*****************************************************************************}

    procedure compile(const filename:string);
      type
        polddata=^tolddata;
        tolddata=record
        { scanner }
          oldidtoken,
          oldtoken       : ttoken;
          oldtokenpos    : tfileposinfo;
          oldc           : char;
          oldpattern,
          oldorgpattern  : string;
          old_block_type : tblock_type;
        { symtable }
          oldrefsymtable,
          olddefaultsymtablestack,
          oldsymtablestack : tsymtable;
          olddefaultmacrosymtablestack,
          oldmacrosymtablestack : tsymtable;
          oldaktprocsym    : tprocsym;
        { cg }
          oldparse_only  : boolean;
        { asmlists }
          oldimports,
          oldexports,
          oldresource,
          oldrttilist,
          oldpicdata,
          oldresourcestringlist,
          oldbsssegment,
          olddatasegment,
          oldcodesegment,
          oldexprasmlist,
          olddebuglist,
          oldwithdebuglist,
          oldconsts     : taasmoutput;
          oldobjectlibrary : tasmlibrarydata;
        { resourcestrings }
          OldResourceStrings : tResourceStrings;
        { akt.. things }
          oldaktlocalswitches  : tlocalswitches;
          oldaktmoduleswitches : tmoduleswitches;
          oldaktfilepos      : tfileposinfo;
          oldaktpackrecords,
          oldaktpackenum,oldaktmaxfpuregisters : longint;
          oldaktalignment  : talignmentinfo;
          oldaktoutputformat : tasm;
          oldaktspecificoptprocessor,
          oldaktoptprocessor : tprocessors;
          oldaktfputype      : tfputype;
          oldaktasmmode      : tasmmode;
          oldaktinterfacetype: tinterfacetypes;
          oldaktmodeswitches : tmodeswitches;
          old_compiled_module : tmodule;
          oldcurrent_procinfo : tprocinfo;
          oldaktdefproccall : tproccalloption;
          oldsourcecodepage : tcodepagestring;
{$ifdef GDB}
          store_dbx : plongint;
{$endif GDB}
        end;

      var
         olddata : polddata;
{$ifdef USEEXCEPT}
         recoverpos    : jmp_buf;
         oldrecoverpos : pjmp_buf;
{$endif useexcept}
       begin
         inc(compile_level);
         parser_current_file:=filename;
         { Uses heap memory instead of placing everything on the
           stack. This is needed because compile() can be called
           recursively }
         new(olddata);
         with olddata^ do
          begin
            old_compiled_module:=compiled_module;
          { save symtable state }
            oldsymtablestack:=symtablestack;
            oldmacrosymtablestack:=macrosymtablestack;
            olddefaultsymtablestack:=defaultsymtablestack;
            olddefaultmacrosymtablestack:=defaultmacrosymtablestack;
            oldrefsymtable:=refsymtable;
            oldcurrent_procinfo:=current_procinfo;
            oldaktdefproccall:=aktdefproccall;
          { save scanner state }
            oldc:=c;
            oldpattern:=pattern;
            oldorgpattern:=orgpattern;
            oldtoken:=token;
            oldidtoken:=idtoken;
            old_block_type:=block_type;
            oldtokenpos:=akttokenpos;
            oldsourcecodepage:=aktsourcecodepage;
          { save cg }
            oldparse_only:=parse_only;
          { save assembler lists }
            olddatasegment:=datasegment;
            oldbsssegment:=bsssegment;
            oldcodesegment:=codesegment;
            olddebuglist:=debuglist;
            oldwithdebuglist:=withdebuglist;
            oldconsts:=consts;
            oldrttilist:=rttilist;
            oldpicdata:=picdata;
            oldexprasmlist:=exprasmlist;
            oldimports:=importssection;
            oldexports:=exportssection;
            oldresource:=resourcesection;
            oldresourcestringlist:=resourcestringlist;
            oldobjectlibrary:=objectlibrary;
            OldResourceStrings:=ResourceStrings;
          { save akt... state }
          { handle the postponed case first }
           if localswitcheschanged then
             begin
               aktlocalswitches:=nextaktlocalswitches;
               localswitcheschanged:=false;
             end;
            oldaktlocalswitches:=aktlocalswitches;
            oldaktmoduleswitches:=aktmoduleswitches;
            oldaktalignment:=aktalignment;
            oldaktpackenum:=aktpackenum;
            oldaktpackrecords:=aktpackrecords;
            oldaktfputype:=aktfputype;
            oldaktmaxfpuregisters:=aktmaxfpuregisters;
            oldaktoutputformat:=aktoutputformat;
            oldaktoptprocessor:=aktoptprocessor;
            oldaktspecificoptprocessor:=aktspecificoptprocessor;
            oldaktasmmode:=aktasmmode;
            oldaktinterfacetype:=aktinterfacetype;
            oldaktfilepos:=aktfilepos;
            oldaktmodeswitches:=aktmodeswitches;
{$ifdef GDB}
            store_dbx:=dbx_counter;
            dbx_counter:=nil;
{$endif GDB}
          end;
       { show info }
         Message1(parser_i_compiling,filename);

       { reset symtable }
         symtablestack:=nil;
         macrosymtablestack:=nil;
         defaultsymtablestack:=nil;
         defaultmacrosymtablestack:=nil;
         systemunit:=nil;
         refsymtable:=nil;
         aktdefproccall:=initdefproccall;
         registerdef:=true;
         aktexceptblock:=0;
         exceptblockcounter:=0;
         aktmaxfpuregisters:=-1;
       { reset the unit or create a new program }
         { a unit compiled at command line must be inside the loaded_unit list }
         if (compile_level=1) then
           begin
             if assigned(current_module) then
               internalerror(200501158);
             current_module:=tppumodule.create(nil,filename,'',false);
             addloadedunit(current_module);
             main_module:=current_module;
             current_module.state:=ms_compile;
           end;
         if not(assigned(current_module) and
                (current_module.state in [ms_compile,ms_second_compile])) then
           internalerror(200212281);

         { Set the module to use for verbose }
         compiled_module:=current_module;
         SetCompileModule(current_module);
         Fillchar(aktfilepos,0,sizeof(aktfilepos));

         { Load current state from the init values }
         aktlocalswitches:=initlocalswitches;
         aktmoduleswitches:=initmoduleswitches;
         aktmodeswitches:=initmodeswitches;
         {$IFDEF Testvarsets}
         aktsetalloc:=initsetalloc;
         {$ENDIF}
         aktalignment:=initalignment;
         aktfputype:=initfputype;
         aktpackenum:=initpackenum;
         aktpackrecords:=0;
         aktoutputformat:=initoutputformat;
         set_target_asm(aktoutputformat);
         aktoptprocessor:=initoptprocessor;
         aktspecificoptprocessor:=initspecificoptprocessor;
         aktasmmode:=initasmmode;
         aktinterfacetype:=initinterfacetype;

         { startup scanner and load the first file }
         current_scanner:=tscannerfile.Create(filename);
         current_scanner.firstfile;
         current_module.scanner:=current_scanner;

         { init macros before anything in the file is parsed.}
         macrosymtablestack:= initialmacrosymtable;
         current_module.localmacrosymtable:= tmacrosymtable.create(false);
         current_module.localmacrosymtable.next:= initialmacrosymtable;
         macrosymtablestack:= current_module.localmacrosymtable;

         { read the first token }
         current_scanner.readtoken;

         { init code generator for a new module }
         init_module;

         { If the compile level > 1 we get a nice "unit expected" error
           message if we are trying to use a program as unit.}
{$ifdef USEEXCEPT}
         if setjmp(recoverpos)=0 then
          begin
            oldrecoverpos:=recoverpospointer;
            recoverpospointer:=@recoverpos;
{$endif USEEXCEPT}

            if (token=_UNIT) or (compile_level>1) then
              begin
                current_module.is_unit:=true;
                proc_unit;
              end
            else
              proc_program(token=_LIBRARY);
{$ifdef USEEXCEPT}
            recoverpospointer:=oldrecoverpos;
          end
         else
          begin
            recoverpospointer:=oldrecoverpos;
            longjump_used:=true;
          end;
{$endif USEEXCEPT}

         { restore old state }
         done_module;

         if assigned(current_module) then
          begin
            { module is now compiled }
            tppumodule(current_module).state:=ms_compiled;

            { free ppu }
            if assigned(tppumodule(current_module).ppufile) then
             begin
               tppumodule(current_module).ppufile.free;
               tppumodule(current_module).ppufile:=nil;
             end;

            { free scanner }
            if assigned(current_module.scanner) then
             begin
               if current_scanner=tscannerfile(current_module.scanner) then
                 current_scanner:=nil;
               tscannerfile(current_module.scanner).free;
               current_module.scanner:=nil;
             end;
          end;

         if (compile_level>1) then
           begin
              with olddata^ do
               begin
                 { restore scanner }
                 c:=oldc;
                 pattern:=oldpattern;
                 orgpattern:=oldorgpattern;
                 token:=oldtoken;
                 idtoken:=oldidtoken;
                 akttokenpos:=oldtokenpos;
                 block_type:=old_block_type;
                 { restore cg }
                 parse_only:=oldparse_only;
                 { restore asmlists }
                 exprasmlist:=oldexprasmlist;
                 datasegment:=olddatasegment;
                 bsssegment:=oldbsssegment;
                 codesegment:=oldcodesegment;
                 consts:=oldconsts;
                 debuglist:=olddebuglist;
                 withdebuglist:=oldwithdebuglist;
                 importssection:=oldimports;
                 exportssection:=oldexports;
                 resourcesection:=oldresource;
                 rttilist:=oldrttilist;
                 picdata:=oldpicdata;
                 resourcestringlist:=oldresourcestringlist;
                 { object data }
                 ResourceStrings:=OldResourceStrings;
                 objectlibrary:=oldobjectlibrary;
                 { restore previous scanner }
                 if assigned(old_compiled_module) then
                   current_scanner:=tscannerfile(old_compiled_module.scanner)
                 else
                   current_scanner:=nil;
                 if assigned(current_scanner) then
                   parser_current_file:=current_scanner.inputfile.name^;
                 { restore symtable state }
                 refsymtable:=oldrefsymtable;
                 symtablestack:=oldsymtablestack;
                 macrosymtablestack:=oldmacrosymtablestack;
                 defaultsymtablestack:=olddefaultsymtablestack;
                 defaultmacrosymtablestack:=olddefaultmacrosymtablestack;
                 aktdefproccall:=oldaktdefproccall;
                 current_procinfo:=oldcurrent_procinfo;
                 aktsourcecodepage:=oldsourcecodepage;
                 aktlocalswitches:=oldaktlocalswitches;
                 aktmoduleswitches:=oldaktmoduleswitches;
                 aktalignment:=oldaktalignment;
                 aktpackenum:=oldaktpackenum;
                 aktpackrecords:=oldaktpackrecords;
                 aktmaxfpuregisters:=oldaktmaxfpuregisters;
                 aktoutputformat:=oldaktoutputformat;
                 set_target_asm(aktoutputformat);
                 aktoptprocessor:=oldaktoptprocessor;
                 aktspecificoptprocessor:=oldaktspecificoptprocessor;
                 aktfputype:=oldaktfputype;
                 aktasmmode:=oldaktasmmode;
                 aktinterfacetype:=oldaktinterfacetype;
                 aktfilepos:=oldaktfilepos;
                 aktmodeswitches:=oldaktmodeswitches;
                 aktexceptblock:=0;
                 exceptblockcounter:=0;
{$ifdef GDB}
                 dbx_counter:=store_dbx;
{$endif GDB}
               end;
           end
         else
           begin
             parser_current_file:='';
             { Shut down things when the last file is compiled }
             if (compile_level=1) then
              begin
                { Close script }
                if (not AsmRes.Empty) then
                 begin
                   Message1(exec_i_closing_script,AsmRes.Fn);
                   AsmRes.WriteToDisk;
                 end;

{$ifdef USEEXCEPT}
                if not longjump_used then
{$endif USEEXCEPT}
                 begin
                   { do not create browsers on errors !! }
                   if status.errorcount=0 then
                    begin
{$ifdef BrowserLog}
                      { Write Browser Log }
                      if (cs_browser_log in aktglobalswitches) and
                         (cs_browser in aktmoduleswitches) then
                       begin
                         if browserlog.elements_to_list.empty then
                          begin
                            Message1(parser_i_writing_browser_log,browserlog.Fname);
                            WriteBrowserLog;
                          end
                         else
                          browserlog.list_elements;
                       end;
{$endif BrowserLog}

                      { Write Browser Collections }
                      do_extractsymbolinfo{$ifdef FPC}(){$endif};
                    end;
                 end;

{$ifdef dummy}
                if current_module.in_second_compile then
                 begin
                   current_module.in_second_compile:=false;
                   current_module.in_compile:=true;
                 end
                else
                 current_module.in_compile:=false;
{$endif dummy}
              end;
           end;

         dec(compile_level);
         compiled_module:=olddata^.old_compiled_module;

         dispose(olddata);

{$ifdef USEEXCEPT}
         if longjump_used then
           longjmp(recoverpospointer^,1);
{$endif USEEXCEPT}
      end;

end.
{
  $Log$
  Revision 1.70  2005-01-19 22:19:41  peter
    * unit mapping rewrite
    * new derefmap added

  Revision 1.69  2005/01/09 20:24:43  olle
    * rework of macro subsystem
    + exportable macros for mode macpas

  Revision 1.68  2004/10/25 15:38:41  peter
    * heap and heapsize removed
    * checkpointer fixes

  Revision 1.67  2004/10/15 09:14:17  mazen
  - remove $IFDEF DELPHI and related code
  - remove $IFDEF FPCPROCVAR and related code

  Revision 1.66  2004/06/20 08:55:30  florian
    * logs truncated

  Revision 1.65  2004/05/12 13:21:09  karoly
    * few small changes to add syscall support to M68k/Amiga target

  Revision 1.64  2004/04/28 15:19:03  florian
    + syscall directive support for MorphOS added

  Revision 1.63  2004/03/16 16:20:49  peter
    * reset current_module,current_procinfo so the destroy routines
      can't access their info anymore, because that can be already
      destroyed

  Revision 1.62  2004/03/14 20:08:37  peter
    * packrecords fixed for settings from $PACKRECORDS
    * default packrecords now uses value 0 and uses info from aligment
      structure only, initpackrecords removed

  Revision 1.61  2004/03/02 17:32:12  florian
    * make cycle fixed
    + pic support for darwin
    + support of importing vars from shared libs on darwin implemented

}
