{
    $Id$
    Copyright (c) 1993-98 by Florian Klaempfl

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
{$ifdef tp}
  {$E+,N+,D+,F+}
{$endif}
unit parser;

  interface

    procedure compile(const filename:string;compile_system:boolean);
    procedure initparser;

  implementation

    uses
       dos,cobjects,globals,scanner,systems,symtable,tree,aasm,
       types,strings,pass_1,hcodegen,files,verbose,script,import
{$ifdef i386}
       ,i386
       ,cgi386
       ,cgai386
       ,tgeni386
       ,aopt386
{$endif i386}
{$ifdef m68k}
        ,m68k
        ,cg68k
        ,tgen68k
        ,cga68k
{$endif m68k}
       { parser units }
       ,pbase,pmodules,pdecl,
       { assembling & linking }
       assemble,
       link;

  { dummy variable for search when calling exec }
  var
     file_found : boolean;

    procedure readconstdefs;

      begin
         s32bitdef:=porddef(globaldef('longint'));
         u32bitdef:=porddef(globaldef('ulong'));
         cstringdef:=pstringdef(globaldef('string'));
         clongstringdef:=pstringdef(globaldef('longstring'));
         cansistringdef:=pstringdef(globaldef('ansistring'));
         cwidestringdef:=pstringdef(globaldef('widestring'));
         cchardef:=porddef(globaldef('char'));
{$ifdef i386}
         c64floatdef:=pfloatdef(globaldef('s64real'));
{$endif}
{$ifdef m68k}
         c64floatdef:=pfloatdef(globaldef('s32real'));
{$endif m68k}
         s80floatdef:=pfloatdef(globaldef('s80real'));
         s32fixeddef:=pfloatdef(globaldef('cs32fixed'));
         voiddef:=porddef(globaldef('void'));
         u8bitdef:=porddef(globaldef('byte'));
         u16bitdef:=porddef(globaldef('word'));
         booldef:=porddef(globaldef('boolean'));
         voidpointerdef:=ppointerdef(globaldef('void_pointer'));
         cfiledef:=pfiledef(globaldef('file'));
      end;

    procedure initparser;

      begin
         forwardsallowed:=false;

         { ^M means a string or a char, because we don't parse a }
         { type declaration                                      }
         block_type:=bt_general;
         ignore_equal:=false;

         { we didn't parse a object or class declaration }
         { and no function header                        }
         testcurobject:=0;

         { create error defintion }
         generrordef:=new(perrordef,init);

         symtablestack:=nil;

         { a long time, this was forgotten }
         aktprocsym:=nil;

         current_module:=nil;

         loaded_units.init;

         usedunits.init;
      end;

    { moved out to save stack }
    var
       addparam : string;

    procedure compile(const filename:string;compile_system:boolean);
      var
         hp : pmodule;
         old_comp_unit : boolean;

         { some variables to save the compiler state }
         oldtoken : ttoken;
{$ifdef UseTokenInfo}
         oldtokenpos : tfileposinfo;
{$endif UseTokenInfo}
         oldpattern : stringid;

         oldpreprocstack : ppreprocstack;
         oldorgpattern,oldprocprefix : string;
         old_block_type : tblock_type;
         oldinputbuffer,
         oldinputpointer : pchar;
         olds_point,oldparse_only : boolean;
         oldc : char;
         oldcomment_level : word;

         oldimports,oldexports,oldresource,oldrttilist,
         oldbsssegment,olddatasegment,oldcodesegment,
         oldexprasmlist,olddebuglist,
         oldinternals,oldexternals,oldconsts : paasmoutput;


         oldnextlabelnr : longint;

         oldswitches : Tcswitches;
         oldmacros,oldrefsymtable,oldsymtablestack : psymtable;


      procedure def_macro(const s : string);

        var
          mac : pmacrosym;

        begin
           mac:=pmacrosym(macros^.search(s));
           if mac=nil then
             begin
               mac:=new(pmacrosym,init(s));
               Message1(parser_m_macro_defined,mac^.name);
               macros^.insert(mac);
             end;
           mac^.defined:=true;
        end;

      procedure set_macro(const s : string;value : string);

        var
          mac : pmacrosym;

        begin
           mac:=pmacrosym(macros^.search(s));
           if mac=nil then
             begin
               mac:=new(pmacrosym,init(s));
               macros^.insert(mac);
             end
           else
             begin
                if assigned(mac^.buftext) then
                  freemem(mac^.buftext,mac^.buflen);
             end;
           Message2(parser_m_macro_set_to,mac^.name,value);
           mac^.buflen:=length(value);
           getmem(mac^.buftext,mac^.buflen);
           move(value[1],mac^.buftext^,mac^.buflen);
           mac^.defined:=true;
        end;

      procedure define_macros;

        var
           hp : pstring_item;

        begin
           hp:=pstring_item(commandlinedefines.first);
           while assigned(hp) do
             begin
               def_macro(hp^.str^);
               hp:=pstring_item(hp^.next);
             end;

           { set macros for version checking }
           set_macro('FPC_VERSION',version_nr);
           set_macro('FPC_RELEASE',release_nr);
           set_macro('FPC_PATCH',patch_nr);
        end;

      label
         done;

      begin {compile}
         inc(compile_level);
         { save old state }

         { save symtable state }
         oldsymtablestack:=symtablestack;
         symtablestack:=nil;
         oldrefsymtable:=refsymtable;
         refsymtable:=nil;
         oldprocprefix:=procprefix;
         old_comp_unit:=comp_unit;

         { a long time, this was only in init_parser
           but it should be reset to zero for each module }
         aktprocsym:=nil;

         { first, we assume a program }
         if not(assigned(current_module)) then
           begin
              current_module:=new(pmodule,init(filename,false));
              main_module:=current_module;
           end;

         { save scanner state }
         oldmacros:=macros;
         oldpattern:=pattern;
         oldtoken:=token;
{$ifdef UseTokenInfo}
         oldtokenpos:=tokenpos;
{$endif UseTokenInfo}
         oldorgpattern:=orgpattern;
         old_block_type:=block_type;
         oldpreprocstack:=preprocstack;

         oldinputbuffer:=inputbuffer;
         oldinputpointer:=inputpointer;
         olds_point:=s_point;
         oldc:=c;
         oldcomment_level:=comment_level;

         oldparse_only:=parse_only;

         { save assembler lists }
         olddatasegment:=datasegment;
         oldbsssegment:=bsssegment;
         oldcodesegment:=codesegment;
         olddebuglist:=debuglist;
         oldexternals:=externals;
         oldinternals:=internals;
         oldconsts:=consts;
         oldrttilist:=rttilist;
         oldexprasmlist:=exprasmlist;
         oldimports:=importssection;
         oldexports:=exportssection;
         oldresource:=resourcesection;

         oldswitches:=aktswitches;
         oldnextlabelnr:=nextlabelnr;

         Message1(parser_i_compiling,filename);

         InitScanner(filename);

         aktswitches:=initswitches;

         { we need this to make the system unit }
         if compile_system then
          aktswitches:=aktswitches+[cs_compilesystem];

         aktpackrecords:=initpackrecords;

         { init code generator for a new module }
         codegen_newmodule;
         macros:=new(psymtable,init(macrosymtable));

         define_macros;

         { startup scanner }
         token:=yylex;

         reset_gdb_info;
         { init asm writing }
         datasegment:=new(paasmoutput,init);
         codesegment:=new(paasmoutput,init);
         bsssegment:=new(paasmoutput,init);
         debuglist:=new(paasmoutput,init);
         externals:=new(paasmoutput,init);
         internals:=new(paasmoutput,init);
         consts:=new(paasmoutput,init);
         rttilist:=new(paasmoutput,init);
         importssection:=nil;
         exportssection:=nil;
         resourcesection:=nil;

         { global switches are read, so further changes aren't allowed }
         current_module^.in_main:=true;

         { open assembler response }
         if (compile_level=1) then
          AsmRes.Init('ppas');

         { if the current file isn't a system unit  }
         { the the system unit will be loaded       }
         if not(cs_compilesystem in aktswitches) then
           begin
              { should be done in unit system (changing the field system_unit)
                                                                      FK
              }
              hp:=loadunit(upper(target_info.system_unit),true,true);
              systemunit:=hp^.symtable;
              readconstdefs;
              { we could try to overload caret by default }
              symtablestack:=systemunit;
              { if POWER is defined in the RTL then use it for starstar overloading }
              getsym('POWER',false);
              if assigned(srsym) and (srsym^.typ=procsym) and
                 (overloaded_operators[STARSTAR]=nil) then
                overloaded_operators[STARSTAR]:=pprocsym(srsym);
           end
         else
           begin
              { create definitions for constants }
              registerdef:=false;
              s32bitdef:=new(porddef,init(s32bit,$80000000,$7fffffff));
              u32bitdef:=new(porddef,init(u32bit,0,$ffffffff));
              cstringdef:=new(pstringdef,init(255));
              { should we give a length to the default long and ansi string definition ?? }
              clongstringdef:=new(pstringdef,longinit(-1));
              cansistringdef:=new(pstringdef,ansiinit(-1));
              cwidestringdef:=new(pstringdef,wideinit(-1));
              cchardef:=new(porddef,init(uchar,0,255));
{$ifdef i386}
              c64floatdef:=new(pfloatdef,init(s64real));
              s80floatdef:=new(pfloatdef,init(s80real));
{$endif}
{$ifdef m68k}
              c64floatdef:=new(pfloatdef,init(s32real));
              if (cs_fp_emulation in aktswitches) then
               s80floatdef:=new(pfloatdef,init(s32real))
              else
               s80floatdef:=new(pfloatdef,init(s80real));
{$endif}
              s32fixeddef:=new(pfloatdef,init(f32bit));

              { some other definitions }
              voiddef:=new(porddef,init(uvoid,0,0));
              u8bitdef:=new(porddef,init(u8bit,0,255));
              u16bitdef:=new(porddef,init(u16bit,0,65535));
              booldef:=new(porddef,init(bool8bit,0,1));
              voidpointerdef:=new(ppointerdef,init(voiddef));
              cfiledef:=new(pfiledef,init(ft_untyped,nil));
              systemunit:=nil;
           end;
         registerdef:=true;

         { current return type is void }
         procinfo.retdef:=voiddef;

         { reset lexical level }
         lexlevel:=0;

         { parse source }
{***BUGFIX}
         if (token=_UNIT) or (compile_level>1) then
            begin
                {If the compile level > 1 we get a nice "unit expected" error
                 message if we are trying to use a program as unit.}
                proc_unit;
                if current_module^.compiled then
                    goto done;
                comp_unit:=true;
            end
         else
           begin
              proc_program(token=_LIBRARY);
              comp_unit:=false;
           end;

         { Why? The definition of Pascal requires that everything
           after 'end.' is ignored!
         if not(cs_tp_compatible in aktswitches) then
            consume(_EOF); }

         if errorcount=0 then
           begin
             if current_module^.uses_imports then
              importlib^.generatelib;

             GenerateAsm(filename);

           { add the files for the linker from current_module}
             addlinkerfiles(current_module);

             if smartlink then
              begin
                Linker.SetLibName(FileName);
                Linker.MakeStaticLibrary(SmartLinkPath(FileName));
              end;

             { Check linking  => we are at first level in compile }
             if (compile_level=1) then
              begin
                if not comp_unit then
                 begin
                   if (cs_no_linking in initswitches) then
                    externlink:=true;
                   if Linker.ExeName='' then
                    Linker.SetExeName(FileName);
                   Linker.MakeExecutable;
                 end;
              end;

           end
         else
           begin
              Message1(unit_e_total_errors,tostr(errorcount));
              Message(unit_f_errors_in_unit);
           end;
         { clear memory }
{$ifdef Splitheap}
         if testsplit then
           begin
           { temp heap should be empty after that !!!}
           codegen_donemodule;
           Releasetempheap;
           end;
         {else
           codegen_donemodule;}
{$endif Splitheap}
         { restore old state }
         { if already compiled jumps directly here }
done:
         { close trees }
         if dispose_asm_lists then
           begin
              dispose(datasegment,Done);
              dispose(codesegment,Done);
              dispose(bsssegment,Done);
              dispose(debuglist,Done);
              dispose(externals,Done);
              dispose(internals,Done);
              dispose(consts,Done);
           end;

         reset_gdb_info;
         { restore symtable state }
{$ifdef UseBrowser}
         if (compile_level>1) then
{ we want to keep the current symtablestack }
{$endif UseBrowser}
           begin
              refsymtable:=oldrefsymtable;
              symtablestack:=oldsymtablestack;
           end;

         procprefix:=oldprocprefix;

         { close the inputfiles }
{$ifndef UseBrowser}
         { but not if we want the names for the browser ! }
         current_module^.sourcefiles.done;
{$endif not UseBrowser}
         { restore scanner state }
         pattern:=oldpattern;
         token:=oldtoken;
{$ifdef UseTokenInfo}
         tokenpos:=oldtokenpos;
{$endif UseTokenInfo}
         orgpattern:=oldorgpattern;
         block_type:=old_block_type;
         comp_unit:=old_comp_unit;

         { call donescanner before restoring preprocstack, because }
         { donescanner tests for a empty preprocstack              }
         { and can also check for unused macros                    }
         donescanner(current_module^.compiled);
         dispose(macros,done);
         macros:=oldmacros;


         preprocstack:=oldpreprocstack;

         aktswitches:=oldswitches;
         inputbuffer:=oldinputbuffer;
         inputpointer:=oldinputpointer;
         s_point:=olds_point;
         c:=oldc;
         comment_level:=oldcomment_level;

         parse_only:=oldparse_only;

         { restore asmlists }
         datasegment:=olddatasegment;
         bsssegment:=oldbsssegment;
         codesegment:=oldcodesegment;
         debuglist:=olddebuglist;
         externals:=oldexternals;
         internals:=oldinternals;
         importssection:=oldimports;
         exportssection:=oldexports;
         resourcesection:=oldresource;

         nextlabelnr:=oldnextlabelnr;
         exprasmlist:=oldexprasmlist;
         consts:=oldconsts;

         nextlabelnr:=oldnextlabelnr;

         if (compile_level=1) then
          begin
            if (not AsmRes.Empty) then
             begin
               Message1(exec_i_closing_script,AsmRes.Fn);
               AsmRes.WriteToDisk;
             end;
          end;
         dec(compile_level);
      end;

end.
{
  $Log$
  Revision 1.13  1998-05-06 08:38:42  pierre
    * better position info with UseTokenInfo
      UseTokenInfo greatly simplified
    + added check for changed tree after first time firstpass
      (if we could remove all the cases were it happen
      we could skip all firstpass if firstpasscount > 1)
      Only with ExtDebug

  Revision 1.12  1998/05/04 17:54:28  peter
    + smartlinking works (only case jumptable left todo)
    * redesign of systems.pas to support assemblers and linkers
    + Unitname is now also in the PPU-file, increased version to 14

  Revision 1.11  1998/05/01 16:38:45  florian
    * handling of private and protected fixed
    + change_keywords_to_tp implemented to remove
      keywords which aren't supported by tp
    * break and continue are now symbols of the system unit
    + widestring, longstring and ansistring type released

  Revision 1.10  1998/05/01 07:43:56  florian
    + basics for rtti implemented
    + switch $m (generate rtti for published sections)

  Revision 1.9  1998/04/30 15:59:40  pierre
    * GDB works again better :
      correct type info in one pass
    + UseTokenInfo for better source position
    * fixed one remaining bug in scanner for line counts
    * several little fixes

  Revision 1.8  1998/04/29 10:33:55  pierre
    + added some code for ansistring (not complete nor working yet)
    * corrected operator overloading
    * corrected nasm output
    + started inline procedures
    + added starstarn : use ** for exponentiation (^ gave problems)
    + started UseTokenInfo cond to get accurate positions

  Revision 1.7  1998/04/27 23:10:28  peter
    + new scanner
    * $makelib -> if smartlink
    * small filename fixes pmodule.setfilename
    * moved import from files.pas -> import.pas

  Revision 1.6  1998/04/21 10:16:48  peter
    * patches from strasbourg
    * objects is not used anymore in the fpc compiled version

  Revision 1.5  1998/04/10 14:41:43  peter
    * removed some Hints
    * small speed optimization for AsmLn

  Revision 1.4  1998/04/08 16:58:03  pierre
    * several bugfixes
      ADD ADC and AND are also sign extended
      nasm output OK (program still crashes at end
      and creates wrong assembler files !!)
      procsym types sym in tdef removed !!

  Revision 1.3  1998/04/07 22:45:04  florian
    * bug0092, bug0115 and bug0121 fixed
    + packed object/class/array
}


