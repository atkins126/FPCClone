{
    $Id$
    Copyright (c) 2002 by Florian Klaempfl

    This unit implements an asmoutput class for PowerPC with MPW syntax

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
{
  This unit implements an asmoutput class for PowerPC with MPW syntax
}
unit agppcmpw;

{$i fpcdefs.inc}

interface

    uses
       aasmtai,
       globals,aasmbase,aasmcpu,assemble,
       cpubase;

    type
      TPPCMPWAssembler = class(TExternalAssembler)
        procedure WriteTree(p:TAAsmoutput);override;
        procedure WriteAsmList;override;
        Function  DoAssemble:boolean;override;
        procedure WriteExternals;
{$ifdef GDB}
        procedure WriteFileLineInfo(var fileinfo : tfileposinfo);
        procedure WriteFileEndInfo;
{$endif}
        procedure WriteAsmFileHeader;
        private
        procedure GenProcedureHeader(var hp:tai);
        procedure WriteDataExportHeader(var s:string; isGlobal, isConst:boolean);
      end;


  implementation

    uses
{$ifdef delphi}
      sysutils,
{$endif}
      cutils,globtype,systems,cclasses,
      verbose,finput,fmodule,script,cpuinfo,
      cgbase,
      itcpugas
      ;

    const
      line_length = 70;

      {Whether internal procedure references should be xxx[PR]: }
      use_PR = false;

      const_storage_class = '[RW]';



{$ifdef GDB}
var
      n_line       : byte;     { different types of source lines }
      linecount,
      includecount : longint;
      funcname     : pchar;
      stabslastfileinfo : tfileposinfo;
      isInFunction: Boolean;
      firstLineInFunction: longint;
{$endif}

    function ReplaceForbiddenChars(var s: string):Boolean;
         {Returns wheater a replacement has occured.}

        var
          i:Integer;

        {The dollar sign is not allowed in MPW PPCAsm}

    begin
      ReplaceForbiddenChars:=false;
      for i:=1 to Length(s) do
        if s[i]='$' then
          begin
            s[i]:='s';
            ReplaceForbiddenChars:=true;
          end;
    end;


{*** From here is copyed from agppcgas.pp, except where marked with CHANGED.
     Perhaps put in a third common file. ***}


    function getreferencestring(var ref : treference) : string;

    var
      s : string;
    begin
       with ref do
        begin
          inc(offset,offsetfixup);

          if (symaddr <> refs_full) then
            InternalError(2002110301)
          else if ((offset < -32768) or (offset > 32767)) then
            InternalError(19991);


          if assigned(symbol) then
            begin
              s:= symbol.name;
              ReplaceForbiddenChars(s);
              {if symbol.typ = AT_FUNCTION then
                  ;}

              s:= s+'[TC]' {ref to TOC entry }
            end
          else
            s:= '';


          if offset<0 then
            s:=s+tostr(offset)
          else
           if (offset>0) then
            begin
              if assigned(symbol) then
               s:=s+'+'+tostr(offset)
              else
               s:=s+tostr(offset);
            end;

          if (index=NR_NO) and (base<>NR_NO) then
            begin
              if offset=0 then
                if not assigned(symbol) then
                  s:=s+'0';
              s:=s+'('+gas_regname(base)+')';
            end
          else if (index<>NR_NO) and (base<>NR_NO) and (offset=0) then
            begin
              if (offset=0) then
                s:=s+gas_regname(base)+','+gas_regname(index)
              else
                internalerror(19992); //  *** ???
            end;
        end;
      getreferencestring:=s;
    end;

    function getopstr_jmp(const o:toper) : string;
    var
      hs : string;
    begin
      case o.typ of
        top_reg :
          getopstr_jmp:=gas_regname(o.reg);
        { no top_ref jumping for powerpc }
        top_const :
          getopstr_jmp:=tostr(o.val);
        top_symbol :
          begin
            hs:=o.sym.name;
            ReplaceForbiddenChars(hs);
            if o.symofs>0 then
             hs:=hs+'+'+tostr(o.symofs)
            else
             if o.symofs<0 then
              hs:=hs+tostr(o.symofs);
            getopstr_jmp:=hs;
          end;
        top_none:
          getopstr_jmp:='';
        else
          internalerror(2002070603);
      end;
    end;

    function getopstr(const o:toper) : string;
    var
      hs : string;
    begin
      case o.typ of
        top_reg:
          getopstr:=gas_regname(o.reg);
        top_const:
          getopstr:=tostr(longint(o.val));
        top_ref:
          getopstr:=getreferencestring(o.ref^);
        top_symbol:
          begin
            hs:=o.sym.name;
            ReplaceForbiddenChars(hs);
            if o.symofs>0 then
             hs:=hs+'+'+tostr(o.symofs)
            else
             if o.symofs<0 then
              hs:=hs+tostr(o.symofs);
            getopstr:=hs;
          end;
        else
          internalerror(2002070604);
      end;
    end;

    function branchmode(o: tasmop): string[4];
      var tempstr: string[4];
      begin
        tempstr := '';
        case o of
          A_BCCTR,A_BCCTRL: tempstr := 'ctr';
          A_BCLR,A_BCLRL: tempstr := 'lr';
        end;
        case o of
          A_BL,A_BLA,A_BCL,A_BCLA,A_BCCTRL,A_BCLRL: tempstr := tempstr+'l';
        end;
        case o of
          A_BA,A_BLA,A_BCA,A_BCLA: tempstr:=tempstr+'a';
        end;
        branchmode := tempstr;
      end;

    function cond2str(op: tasmop; c: tasmcond): string;
    { note: no checking is performed whether the given combination of }
    { conditions is valid                                             }
    var tempstr: string;
    begin
      tempstr:=#9;
      case c.simple of
        false: cond2str := tempstr+gas_op2str[op]+#9+tostr(c.bo)+','+
                           tostr(c.bi);
        true:
          if (op >= A_B) and (op <= A_BCLRL) then
            case c.cond of
              { unconditional branch }
              C_NONE:
                cond2str := tempstr+gas_op2str[op];
              { bdnzt etc }
              else
                begin
                  tempstr := tempstr+'b'+asmcondflag2str[c.cond]+
                              branchmode(op)+#9;
                  case c.cond of
                    C_LT..C_NU:
                      cond2str := tempstr+gas_regname(newreg(R_SPECIALREGISTER,c.cr,R_SUBNONE)); // *** R_SUBWHOLE ???
                    C_T..C_DZF:
                      cond2str := tempstr+tostr(c.crbit);
                  end;
                end;
            end
          { we have a trap instruction }
          else
            begin
              internalerror(2002070601);
              { not yet implemented !!!!!!!!!!!!!!!!!!!!! }
              { case tempstr := 'tw';}
            end;
      end;
    end;

    Function GetInstruction(hp : tai):string; {CHANGED from method to proc}
    var op: TAsmOp;
        s: string;
        i: byte;
        sep: string[3];
    begin
      op:=taicpu(hp).opcode;
      if is_calljmp(op) then
        begin
          { direct BO/BI in op[0] and op[1] not supported, put them in condition! }
          case op of
             A_B,A_BA:
               s:=#9+gas_op2str[op]+#9;
             A_BCTR,A_BCTRL,A_BLR,A_BLRL:
               s:=#9+gas_op2str[op];
             A_BL,A_BLA:
               s:=#9+gas_op2str[op]+#9'.';
             else
               s:=cond2str(op,taicpu(hp).condition)+',';
          end;
          if (taicpu(hp).oper[0]^.typ <> top_none) then
            s:=s+getopstr_jmp(taicpu(hp).oper[0]^);
          if use_PR then
            if (op=A_BL) or (op=A_BLA) then
              s:=s+'[PR]';
        end
      else
        { process operands }
        begin
          case op of
             A_MFSPR:
               case taicpu(hp).oper[1]^.reg of
                  NR_CR:
                    begin
                       op:=A_MFCR;
                       taicpu(hp).ops:=1;
                    end;
                  NR_LR:
                    begin
                       op:=A_MFLR;
                       taicpu(hp).ops:=1;
                    end;
                  else
                    internalerror(2002100701);
               end;
             A_MTSPR:
               case taicpu(hp).oper[1]^.reg of
                  NR_CR:
                    begin
                       op:=A_MTCR;
                       taicpu(hp).ops:=1;
                    end;
                  NR_LR:
                    begin
                       op:=A_MTLR;
                       taicpu(hp).ops:=1;
                    end;
                  else
                    internalerror(2002100701);
               end;
          end;
          s:=#9+gas_op2str[op];
          if taicpu(hp).ops<>0 then
            begin
               sep:=#9;
               for i:=0 to taicpu(hp).ops-1 do
                 begin
                   s:=s+sep+getopstr(taicpu(hp).oper[i]^);
                   sep:=',';
                 end;
            end;
        end;
      GetInstruction:=s;
    end;

    {*** Until here is copyed from agppcgas.pp. ***}


    function single2str(d : single) : string;
      var
         hs : string;
         p : byte;
      begin
         str(d,hs);
      { nasm expects a lowercase e }
         p:=pos('E',hs);
         if p>0 then
          hs[p]:='e';
         p:=pos('+',hs);
         if p>0 then
          delete(hs,p,1);
         single2str:=lower(hs);
      end;

    function double2str(d : double) : string;
      var
         hs : string;
         p : byte;
      begin
         str(d,hs);
      { nasm expects a lowercase e }
         p:=pos('E',hs);
         if p>0 then
          hs[p]:='e';
         p:=pos('+',hs);
         if p>0 then
          delete(hs,p,1);
         double2str:=lower(hs);
      end;

   function fixline(s:string):string;
   {
     return s with all leading and ending spaces and tabs removed
   }
     var
       i,j,k : longint;
     begin
       i:=length(s);
       while (i>0) and (s[i] in [#9,' ']) do
        dec(i);
       j:=1;
       while (j<i) and (s[j] in [#9,' ']) do
        inc(j);
       for k:=j to i do
        if s[k] in [#0..#31,#127..#255] then
         s[k]:='.';
       fixline:=Copy(s,j,i-j+1);
     end;


{****************************************************************************
                               PowerPC MPW Assembler
 ****************************************************************************}
    procedure TPPCMPWAssembler.GenProcedureHeader(var hp:tai);
      {Returns the current hp where the caller should continue from}
      {For multiple entry procedures, only the last is exported as xxx[PR]
       (if use_PR is set) }

      procedure WriteExportHeader(hp:tai);

        var
          s: string;
          replaced: boolean;

      begin
        s:= tai_symbol(hp).sym.name;
        replaced:= ReplaceForbiddenChars(s);

        if not use_PR then
          begin
            AsmWrite(#9'export'#9'.');
            AsmWrite(s);
            if replaced then
              begin
                AsmWrite(' => ''.');
                AsmWrite(tai_symbol(hp).sym.name);
                AsmWrite('''');
              end;
            AsmLn;
          end;

        AsmWrite(#9'export'#9);
        AsmWrite(s);
        AsmWrite('[DS]');
        if replaced then
          begin
            AsmWrite(' => ''');
            AsmWrite(tai_symbol(hp).sym.name);
            AsmWrite('[DS]''');
          end;
        AsmLn;

        {Entry in transition vector: }
        AsmWrite(#9'csect'#9); AsmWrite(s); AsmWriteLn('[DS]');

        AsmWrite(#9'dc.l'#9'.'); AsmWriteLn(s);

        AsmWriteln(#9'dc.l'#9'TOC[tc0]');

        {Entry in TOC: }
        AsmWriteLn(#9'toc');

        AsmWrite(#9'tc'#9);
        AsmWrite(s); AsmWrite('[TC],');
        AsmWrite(s); AsmWriteln('[DS]');
      end;

    function GetAdjacentTaiSymbol(var hp:tai):Boolean;

    begin
      GetAdjacentTaiSymbol:= false;
      while assigned(hp.next) do
        case tai(hp.next).typ of
          ait_symbol:
            begin
              hp:=tai(hp.next);
              GetAdjacentTaiSymbol:= true;
              Break;
            end;
          ait_stab_function_name:
            hp:=tai(hp.next);
          else
            begin
              //AsmWriteln('  ;#*#*# ' + tostr(Ord(tai(hp.next).typ)));
              Break;
            end;
        end;
    end;

    var
      first,last: tai;
      s: string;
      replaced: boolean;


    begin
      s:= tai_symbol(hp).sym.name;
      {Write all headers}
      first:= hp;
      repeat
        WriteExportHeader(hp);
        last:= hp;
      until not GetAdjacentTaiSymbol(hp);

      {Start the section of the body of the proc: }
      s:= tai_symbol(last).sym.name;
      replaced:= ReplaceForbiddenChars(s);

      if use_PR then
        begin
          AsmWrite(#9'export'#9'.'); AsmWrite(s); AsmWrite('[PR]');
          if replaced then
            begin
              AsmWrite(' => ''.');
              AsmWrite(tai_symbol(last).sym.name);
              AsmWrite('[PR]''');
            end;
          AsmLn;
        end;

      {Starts the section: }
      AsmWrite(#9'csect'#9'.');
      AsmWrite(s);
      AsmWriteLn('[PR]');

      {Info for the debugger: }
      AsmWrite(#9'function'#9'.');
      AsmWrite(s);
      AsmWriteLn('[PR]');

      {$ifdef GDB}
      if ((cs_debuginfo in aktmoduleswitches) or
           (cs_gdb_lineinfo in aktglobalswitches)) then
        begin
          //info for debuggers:
          firstLineInFunction:= stabslastfileinfo.line;
          AsmWriteLn(#9'beginf ' + tostr(firstLineInFunction));
          isInFunction:= true;
        end;
      {$endif}
      {Write all labels: }
      hp:= first;
      repeat
        s:= tai_symbol(hp).sym.name;
        ReplaceForbiddenChars(s);
        AsmWrite('.'); AsmWrite(s); AsmWriteLn(':');
      until not GetAdjacentTaiSymbol(hp);
    end;

    procedure TPPCMPWAssembler.WriteDataExportHeader(var s:string; isGlobal, isConst:boolean);
    // Returns in s the changed string
    var
      sym: string;
      replaced: boolean;

    begin
      sym:= s;
      replaced:= ReplaceForbiddenChars(s);

      if isGlobal then
        begin
          AsmWrite(#9'export'#9);
          AsmWrite(s);
          if isConst then
            AsmWrite(const_storage_class)
          else
            AsmWrite('[RW]');
          if replaced then
              begin
                AsmWrite(' => ''');
                AsmWrite(sym);
                AsmWrite('''');
              end;
          AsmLn;
        end;

      if not macos_direct_globals then
        begin
          AsmWriteLn(#9'toc');

          AsmWrite(#9'tc'#9);
          AsmWrite(s);
          AsmWrite('[TC], ');
          AsmWrite(s);
          if isConst then
            AsmWrite(const_storage_class)
          else
            AsmWrite('[RW]');
          AsmLn;

          AsmWrite(#9'csect'#9);
          AsmWrite(s);
          if isConst then
            AsmWrite(const_storage_class)
          else
            AsmWrite('[RW]');
        end
      else
        begin
          AsmWrite(#9'csect'#9);
          AsmWrite(s);
          AsmWrite('[TC]');
        end;

      AsmLn;
    end;

    var
      LasTSec : TSection;
      lastfileinfo : tfileposinfo;
      infile,
      lastinfile   : tinputfile;

    const
      ait_const2str:array[ait_const_32bit..ait_const_8bit] of string[8]=
        (#9'dc.l'#9,#9'dc.w'#9,#9'dc.b'#9);

    Function PadTabs(const p:string;addch:char):string;
    var
      s : string;
      i : longint;
    begin
      i:=length(p);
      if addch<>#0 then
       begin
         inc(i);
         s:=p+addch;
       end
      else
       s:=p;
      if i<8 then
       PadTabs:=s+#9#9
      else
       PadTabs:=s+#9;
    end;

{$ifdef GDB}
    procedure TPPCMPWAssembler.WriteFileLineInfo(var fileinfo : tfileposinfo);
        var
          curr_n : byte;
        begin
          if not ((cs_debuginfo in aktmoduleswitches) or
             (cs_gdb_lineinfo in aktglobalswitches)) then
           exit;
        { file changed ? (must be before line info) }
          if (fileinfo.fileindex<>0) and
             (stabslastfileinfo.fileindex<>fileinfo.fileindex) then
           begin
             infile:=current_module.sourcefiles.get_file(fileinfo.fileindex);
             if assigned(infile) then
              begin
              (*
                if includecount=0 then
                 curr_n:=n_sourcefile
                else
                 curr_n:=n_includefile;
                if (infile.path^<>'') then
                 begin
                   AsmWriteLn(#9'.stabs "'+lower(BsToSlash(FixPath(infile.path^,false)))+'",'+
                     tostr(curr_n)+',0,0,'+target_asm.labelprefix+'text'+ToStr(IncludeCount));
                 end;

                AsmWriteLn(#9'.stabs "'+lower(FixFileName(infile.name^))+'",'+
                  tostr(curr_n)+',0,0,'+target_asm.labelprefix+'text'+ToStr(IncludeCount));
              *)
              AsmWriteLn(#9'file '''+lower(FixFileName(infile.name^))+'''');

              (*
                AsmWriteLn(target_asm.labelprefix+'text'+ToStr(IncludeCount)+':');
              *)

                inc(includecount);
                { force new line info }
                stabslastfileinfo.line:=-1;
              end;
           end;
        { line changed ? }
          if (stabslastfileinfo.line<>fileinfo.line) and (fileinfo.line<>0) then
           begin
            (*
             if (n_line=n_textline) and assigned(funcname) and
                (target_info.use_function_relative_addresses) then
              begin
                AsmWriteLn(target_asm.labelprefix+'l'+tostr(linecount)+':');
                AsmWrite(#9'.stabn '+tostr(n_line)+',0,'+tostr(fileinfo.line)+','+
                           target_asm.labelprefix+'l'+tostr(linecount)+' - ');
                AsmWritePChar(FuncName);
                AsmLn;
                inc(linecount);
              end
             else
              AsmWriteLn(#9'.stabd'#9+tostr(n_line)+',0,'+tostr(fileinfo.line));
            *)
            if isInFunction then
              AsmWriteln(#9'line '+ tostr(fileinfo.line - firstLineInFunction - 1));
          end;
          stabslastfileinfo:=fileinfo;
        end;

      procedure TPPCMPWAssembler.WriteFileEndInfo;

        begin
          if not ((cs_debuginfo in aktmoduleswitches) or
             (cs_gdb_lineinfo in aktglobalswitches)) then
           exit;
          AsmLn;
          (*
          AsmWriteLn(ait_section2str(sec_code));
          AsmWriteLn(#9'.stabs "",'+tostr(n_sourcefile)+',0,0,'+target_asm.labelprefix+'etext');
          AsmWriteLn(target_asm.labelprefix+'etext:');
          *)
        end;

{$endif}

    procedure TPPCMPWAssembler.WriteTree(p:TAAsmoutput);
    var
      s,
      prefix,
      suffix   : string;
      hp       : tai;
      hp1      : tailineinfo;
      counter,
      lines,
      InlineLevel : longint;
      i,j,l    : longint;
      consttyp : taitype;
      found,
      do_line,DoNotSplitLine,
      quoted   : boolean;
      sep      : char;
      replaced : boolean;

    begin
      if not assigned(p) then
       exit;
      InlineLevel:=0;
      { lineinfo is only needed for codesegment (PFV) }
      do_line:=((cs_asm_source in aktglobalswitches) or
                (cs_lineinfo in aktmoduleswitches))
                 and (p=codesegment);
      DoNotSplitLine:=false;
      hp:=tai(p.first);
      while assigned(hp) do
       begin
         if not(hp.typ in SkipLineInfo) and
            not DoNotSplitLine then
           begin
             hp1 := hp as tailineinfo;

{$ifdef GDB}
             { write debug info }
             if (cs_debuginfo in aktmoduleswitches) or
                (cs_gdb_lineinfo in aktglobalswitches) then
               WriteFileLineInfo(hp1.fileinfo);
{$endif GDB}

             if do_line then
              begin
           { load infile }
             if lastfileinfo.fileindex<>hp1.fileinfo.fileindex then
              begin
                infile:=current_module.sourcefiles.get_file(hp1.fileinfo.fileindex);
                if assigned(infile) then
                 begin
                   { open only if needed !! }
                   if (cs_asm_source in aktglobalswitches) then
                    infile.open;
                 end;
                { avoid unnecessary reopens of the same file !! }
                lastfileinfo.fileindex:=hp1.fileinfo.fileindex;
                { be sure to change line !! }
                lastfileinfo.line:=-1;
              end;
           { write source }
             if (cs_asm_source in aktglobalswitches) and
                assigned(infile) then
              begin
                if (infile<>lastinfile) then
                  begin
                    AsmWriteLn(target_asm.comment+'['+infile.name^+']');
                    if assigned(lastinfile) then
                      lastinfile.close;
                  end;
                if (hp1.fileinfo.line<>lastfileinfo.line) and
                   ((hp1.fileinfo.line<infile.maxlinebuf) or (InlineLevel>0)) then
                  begin
                    if (hp1.fileinfo.line<>0) and
                       ((infile.linebuf^[hp1.fileinfo.line]>=0) or (InlineLevel>0)) then
                      AsmWriteLn(target_asm.comment+'['+tostr(hp1.fileinfo.line)+'] '+
                        fixline(infile.GetLineStr(hp1.fileinfo.line)));
                    { set it to a negative value !
                    to make that is has been read already !! PM }
                    if (infile.linebuf^[hp1.fileinfo.line]>=0) then
                      infile.linebuf^[hp1.fileinfo.line]:=-infile.linebuf^[hp1.fileinfo.line]-1;
                  end;
              end;
             lastfileinfo:=hp1.fileinfo;
             lastinfile:=infile;
           end;
          end;

         DoNotSplitLine:=false;

         case hp.typ of
            ait_comment:
              begin
                 AsmWrite(target_asm.comment);
                 AsmWritePChar(tai_comment(hp).str);
                 AsmLn;
              end;
            ait_regalloc,
            ait_tempalloc:
              ;
            ait_section:
              begin
                 {if LasTSec<>sec_none then
                  AsmWriteLn('_'+target_asm.secnames[LasTSec]+#9#9'ENDS');}
                 if tai_section(hp).sec<>sec_none then
                  begin
                    AsmLn;
                    AsmWriteLn(#9+target_asm.secnames[tai_section(hp).sec]);
{$ifdef GDB}
                  lastfileinfo.line:=-1;
{$endif GDB}
                  end;
                 LasTSec:=tai_section(hp).sec;
               end;
            ait_align:
              begin
                 case tai_align(hp).aligntype of
                   1:AsmWriteLn(#9'align 0');
                   2:AsmWriteLn(#9'align 1');
                   4:AsmWriteLn(#9'align 2');
                   otherwise internalerror(2002110302);
                 end;
              end;
            ait_datablock:
              begin
                 s:= tai_datablock(hp).sym.name;

                 WriteDataExportHeader(s, tai_datablock(hp).is_global, false);

                 if not macos_direct_globals then
                   begin
                     AsmWriteLn(#9'ds.b '+tostr(tai_datablock(hp).size));
                   end
                 else
                   begin
                     AsmWriteLn(PadTabs(s+':',#0)+'ds.b '+tostr(tai_datablock(hp).size));
                     {TODO: ? PadTabs(s,#0) }
                   end;
              end;
            ait_const_32bit,
            ait_const_8bit,
            ait_const_16bit :
              begin
                 AsmWrite(ait_const2str[hp.typ]+tostr(tai_const(hp).value));
                 consttyp:=hp.typ;
                 l:=0;
                 repeat
                   found:=(not (tai(hp.next)=nil)) and (tai(hp.next).typ=consttyp);
                   if found then
                    begin
                      hp:=tai(hp.next);
                      s:=','+tostr(tai_const(hp).value);
                      AsmWrite(s);
                      inc(l,length(s));
                    end;
                 until (not found) or (l>line_length);
                 AsmLn;
               end;
            ait_const_symbol:
              begin
                s:= tai_const_symbol(hp).sym.name;
                ReplaceForbiddenChars(s);

                AsmWrite(#9'dc.l'#9);
                if tai_const_symbol(hp).sym.typ = AT_FUNCTION then
                  begin
                    if use_PR then
                      AsmWrite('.');

                    AsmWrite(s);

                    if use_PR then
                      AsmWriteLn('[PR]')
                    else
                      AsmWriteLn('[DS]')
                  end
                else
                  begin
                    AsmWrite(s);
                    if not macos_direct_globals then
                      AsmWriteLn(const_storage_class);
                  end;

                (* TODO: the following might need to be included. Temporaily we
                generate an error

                if tai_const_symbol(hp).offset>0 then
                  AsmWrite('+'+tostr(tai_const_symbol(hp).offset))
                else if tai_const_symbol(hp).offset<0 then
                  AsmWrite(tostr(tai_const_symbol(hp).offset));
                *)

                if tai_const_symbol(hp).offset <> 0 then
                  InternalError(2002110101);

                AsmLn;
              end;
            ait_real_32bit:
              AsmWriteLn(#9'dc.l'#9'"'+single2str(tai_real_32bit(hp).value)+'"');
            ait_real_64bit:
              AsmWriteLn(#9'dc.d'#9'"'+double2str(tai_real_64bit(hp).value)+'"');
            ait_string:
              begin
                 {NOTE When a single quote char is encountered, it is
                 replaced with a numeric ascii value. It could also
                 have been replaced with the escape seq of double quotes.
                 Backslash seems to be used as an escape char, although
                 this is not mentioned in the PPCAsm documentation.}
                 counter := 0;
                 lines := tai_string(hp).len div line_length;
                 { separate lines in different parts }
                 if tai_string(hp).len > 0 then
                  Begin
                    for j := 0 to lines-1 do
                     begin
                       AsmWrite(#9'dc.b'#9);
                       quoted:=false;
                       for i:=counter to counter+line_length do
                          begin
                            { it is an ascii character. }
                            if (ord(tai_string(hp).str[i])>31) and
                               (ord(tai_string(hp).str[i])<128) and
                               (tai_string(hp).str[i]<>'''') and
                               (tai_string(hp).str[i]<>'\') then
                                begin
                                  if not(quoted) then
                                      begin
                                        if i>counter then
                                          AsmWrite(',');
                                        AsmWrite('''');
                                      end;
                                  AsmWrite(tai_string(hp).str[i]);
                                  quoted:=true;
                                end { if > 31 and < 128 and ord('"') }
                            else
                                begin
                                    if quoted then
                                        AsmWrite('''');
                                    if i>counter then
                                        AsmWrite(',');
                                    quoted:=false;
                                    AsmWrite(tostr(ord(tai_string(hp).str[i])));
                                end;
                         end; { end for i:=0 to... }
                       if quoted then AsmWrite('''');
                       AsmWrite(target_info.newline);
                       counter := counter+line_length;
                    end; { end for j:=0 ... }
                  { do last line of lines }
                  AsmWrite(#9'dc.b'#9);
                  quoted:=false;
                  for i:=counter to tai_string(hp).len-1 do
                    begin
                      { it is an ascii character. }
                      if (ord(tai_string(hp).str[i])>31) and
                         (ord(tai_string(hp).str[i])<128) and
                         (tai_string(hp).str[i]<>'''') and
                         (tai_string(hp).str[i]<>'\') then                          begin
                            if not(quoted) then
                                begin
                                  if i>counter then
                                    AsmWrite(',');
                                  AsmWrite('''');
                                end;
                            AsmWrite(tai_string(hp).str[i]);
                            quoted:=true;
                          end { if > 31 and < 128 and " }
                      else
                          begin
                            if quoted then
                              AsmWrite('''');
                            if i>counter then
                                AsmWrite(',');
                            quoted:=false;
                            AsmWrite(tostr(ord(tai_string(hp).str[i])));
                          end;
                    end; { end for i:=0 to... }
                  if quoted then
                    AsmWrite('''');
                  end;
                 AsmLn;
              end;
            ait_label:
              begin
                 if tai_label(hp).l.is_used then
                  begin
                    s:= tai_label(hp).l.name;
                    ReplaceForbiddenChars(s);
                    if s[1] = '@' then
                      //Local labels:
                      AsmWriteLn(s+':')
                    else
                      begin
                        //Procedure entry points:
                        if not macos_direct_globals then
                          begin
                            AsmWriteLn(#9'toc');
                            AsmWrite(#9'tc'#9); AsmWrite(s);
                            AsmWrite('[TC], '); AsmWrite(s);
                            AsmWriteLn(const_storage_class);

                            AsmWrite(#9'csect'#9); AsmWrite(s);
                            AsmWriteLn(const_storage_class);
                          end
                        else
                          begin
                            AsmWrite(#9'csect'#9); AsmWrite(s);
                            AsmWriteLn('[TC]');

                            AsmWriteLn(PadTabs(s+':',#0));
                          end;
                      end;
                  end;
               end;
             ait_direct:
               begin
                  AsmWritePChar(tai_direct(hp).str);
                  AsmLn;
               end;
             ait_symbol:
               begin
                  if tai_symbol(hp).sym.typ=AT_FUNCTION then
                    GenProcedureHeader(hp)
                  else if tai_symbol(hp).sym.typ=AT_DATA then
                    begin
                       s:= tai_symbol(hp).sym.name;

                       WriteDataExportHeader(s, tai_symbol(hp).is_global, true);

                       if macos_direct_globals then
                         begin
                           AsmWrite(s);
                           AsmWriteLn(':');
                         end;
                    end
                  else
                    InternalError(2003071301);
                end;
              ait_symbol_end:
{$ifdef GDB}
                if isInFunction then
                  if ((cs_debuginfo in aktmoduleswitches) or
                       (cs_gdb_lineinfo in aktglobalswitches)) then
                    begin
                      //info for debuggers:
                      AsmWriteLn(#9'endf ' + tostr(stabslastfileinfo.line));
                      isInFunction:= false;
                    end
{$endif GDB}
                ;
              ait_instruction:
                AsmWriteLn(GetInstruction(hp));
{$ifdef GDB}
              ait_stabn: ;
              ait_stabs: ;

              ait_force_line :
                 stabslastfileinfo.line:=0;

              ait_stab_function_name: ;
{$endif GDB}
              ait_cut :
                begin
                     { only reset buffer if nothing has changed }
                       if AsmSize=AsmStartSize then
                        AsmClear
                       else
                        begin
                          {
                          if LasTSec<>sec_none then
                           AsmWriteLn('_'+target_asm.secnames[LasTSec]+#9#9'ends');
                          AsmLn;
                          }
                          AsmWriteLn(#9'end');
                          AsmClose;
                          DoAssemble;
                          AsmCreate(tai_cut(hp).place);
                        end;
                     { avoid empty files }
                       while assigned(hp.next) and (tai(hp.next).typ in [ait_cut,ait_section,ait_comment]) do
                        begin
                          if tai(hp.next).typ=ait_section then
                           begin
                             lasTSec:=tai_section(hp.next).sec;
                           end;
                          hp:=tai(hp.next);
                        end;
                       WriteAsmFileHeader;

                       if lasTSec<>sec_none then
                         AsmWriteLn(#9+target_asm.secnames[lasTSec]);
                       {   AsmWriteLn('_'+target_asm.secnames[lasTSec]+#9#9+
                                     'SEGMENT'#9'PARA PUBLIC USE32 '''+
                                     target_asm.secnames[lasTSec]+'''');
                       }
                       AsmStartSize:=AsmSize;
                 end;
               ait_marker :
                 begin
                   if tai_marker(hp).kind=InlineStart then
                     inc(InlineLevel)
                   else if tai_marker(hp).kind=InlineEnd then
                     dec(InlineLevel);
                 end;
         else
          internalerror(2002110303);
         end;
         hp:=tai(hp.next);
       end;
    end;

    var
      currentasmlist : TExternalAssembler;

    procedure writeexternal(p:tnamedindexitem;arg:pointer);

      var
        s:string;
        replaced: boolean;

      begin
        if tasmsymbol(p).defbind=AB_EXTERNAL then
          begin
            //Writeln('ZZZ ',p.name,' ',p.classname,' ',Ord(tasmsymbol(p).typ));
            s:= p.name;
            replaced:= ReplaceForbiddenChars(s);

            with currentasmlist do
              case tasmsymbol(p).typ of
                AT_FUNCTION:
                  begin
                    AsmWrite(#9'import'#9'.');
                    AsmWrite(s);
                    if use_PR then
                     AsmWrite('[PR]');

                    if replaced then
                     begin
                       AsmWrite(' <= ''.');
                       AsmWrite(p.name);
                       if use_PR then
                         AsmWrite('[PR]''')
                       else
                         AsmWrite('''');
                     end;
                    AsmLn;

                    AsmWrite(#9'import'#9);
                    AsmWrite(s);
                    AsmWrite('[DS]');
                    if replaced then
                     begin
                       AsmWrite(' <= ''');
                       AsmWrite(p.name);
                       AsmWrite('[DS]''');
                     end;
                    AsmLn;

                    AsmWriteLn(#9'toc');

                    AsmWrite(#9'tc'#9);
                    AsmWrite(s);
                    AsmWrite('[TC],');
                    AsmWrite(s);
                    AsmWriteLn('[DS]');
                  end;
                AT_DATA:
                  begin
                    AsmWrite(#9'import'#9);
                    AsmWrite(s);
                    AsmWrite('[RW]');
                    if replaced then
                      begin
                        AsmWrite(' <= ''');
                        AsmWrite(p.name);
                        AsmWrite('''');
                      end;
                    AsmLn;

                    AsmWriteLn(#9'toc');
                    AsmWrite(#9'tc'#9);
                    AsmWrite(s);
                    AsmWrite('[TC],');
                    AsmWrite(s);
                    AsmWriteLn('[RW]');
                  end
                else
                  InternalError(2003090901);
              end;
          end;
      end;

    procedure TPPCMPWAssembler.WriteExternals;
      begin
        currentasmlist:=self;
        objectlibrary.symbolsearch.foreach_static({$ifdef fpcprocvar}@{$endif}writeexternal,nil);
      end;


    function TPPCMPWAssembler.DoAssemble : boolean;
    var f : file;
    begin
      DoAssemble:=Inherited DoAssemble;
      (*
      { masm does not seem to recognize specific extensions and uses .obj allways PM }
      if (aktoutputformat = as_i386_masm) then
        begin
          if not(cs_asm_extern in aktglobalswitches) then
            begin
              if Not FileExists(objfile) and
                 FileExists(ForceExtension(objfile,'.obj')) then
                begin
                  Assign(F,ForceExtension(objfile,'.obj'));
                  Rename(F,objfile);
                end;
            end
          else
            AsmRes.AddAsmCommand('mv',ForceExtension(objfile,'.obj')+' '+objfile,objfile);
        end;
      *)
    end;

    procedure TPPCMPWAssembler.WriteAsmFileHeader;

    begin
      (*
      AsmWriteLn(#9'.386p');
      { masm 6.11 does not seem to like LOCALS PM }
      if (aktoutputformat = as_i386_tasm) then
        begin
          AsmWriteLn(#9'LOCALS '+target_asm.labelprefix);
        end;
      AsmWriteLn('DGROUP'#9'GROUP'#9'_BSS,_DATA');
      AsmWriteLn(#9'ASSUME'#9'CS:_CODE,ES:DGROUP,DS:DGROUP,SS:DGROUP');
      AsmLn;
      *)

      AsmWriteLn(#9'string asis');  {Interpret strings just to be the content between the quotes.}
      AsmWriteLn(#9'aligning off'); {We do our own aligning.}
      AsmLn;
    end;

    procedure TPPCMPWAssembler.WriteAsmList;


{$ifdef GDB}
    var
      fileinfo : tfileposinfo;
{$endif GDB}

    begin
{$ifdef EXTDEBUG}
      if assigned(current_module.mainsource) then
       comment(v_info,'Start writing MPW-styled assembler output for '+current_module.mainsource^);
{$endif}
      LasTSec:=sec_none;
{$ifdef GDB}
      FillChar(stabslastfileinfo,sizeof(stabslastfileinfo),0);
{$endif GDB}
{$ifdef GDB}
      //n_line:=n_bssline;
      funcname:=nil;
      linecount:=1;
      includecount:=0;
      fileinfo.fileindex:=1;
      fileinfo.line:=1;

      isInFunction:= false;
      firstLineInFunction:= 0;

      { Write main file }
      WriteFileLineInfo(fileinfo);

{$endif GDB}

      WriteAsmFileHeader;
      WriteExternals;

    { PowerPC MPW ASM doesn't support stabs, as we know.
      WriteTree(debuglist);}

      WriteTree(codesegment);
      WriteTree(datasegment);
      WriteTree(consts);
      WriteTree(rttilist);
      WriteTree(resourcestringlist);
      WriteTree(bsssegment);
      {$ifdef GDB}
      WriteFileEndInfo;
      {$ENDIF}

      AsmWriteLn(#9'end');
      AsmLn;

{$ifdef EXTDEBUG}
      if assigned(current_module.mainsource) then
       comment(v_info,'Done writing MPW-styled assembler output for '+current_module.mainsource^);
{$endif EXTDEBUG}
   end;

{*****************************************************************************
                                  Initialize
*****************************************************************************}

    const
       as_powerpc_mpw_info : tasminfo =
          (
            id           : as_powerpc_mpw;
            idtxt  : 'MPW';
            asmbin : 'PPCAsm';
            asmcmd : '';
            supported_target : system_any; { what should I write here ?? }
            outputbinary: false;
            allowdirect : true;
            needar : true;
            labelprefix_only_inside_procedure : true;
            labelprefix : '@';
            comment : '; ';
            secnames : ('',
              'csect','csect [TC]','csect [TC]',  {TODO: Perhaps use other section types.}
              '','','','','','',
              '','','')
          );

initialization
  RegisterAssembler(as_powerpc_mpw_info,TPPCMPWAssembler);
end.
{
  $Log$
  Revision 1.28  2003-11-12 16:05:40  florian
    * assembler readers OOPed
    + typed currency constants
    + typed 128 bit float constants if the CPU supports it

  Revision 1.27  2003/10/25 10:37:26  florian
    * fixed compilation of ppc compiler

  Revision 1.26  2003/10/01 20:34:49  peter
    * procinfo unit contains tprocinfo
    * cginfo renamed to cgbase
    * moved cgmessage to verbose
    * fixed ppc and sparc compiles

  Revision 1.25  2003/09/12 12:30:27  olle
    * max lenght of symbols increased to 255
    * emitted strings can now contain backslashes

  Revision 1.24  2003/09/03 19:35:24  peter
    * powerpc compiles again

  Revision 1.23  2003/08/24 21:40:12  olle
    * minor adjustment

  Revision 1.21  2003/08/18 11:47:15  olle
    + added asm directive ALIGNING OFF to avoid unexpected aligning by the assembler

  Revision 1.20  2002/10/01 05:17:27  olle
    * minor fix

  Revision 1.19  2003/04/06 21:01:40  olle
    + line numbers are now emitted in the assembler code
    * bug in export and import directive fixed
    * made code more in sync with aggas.pas

  Revision 1.18  2003/01/13 17:17:50  olle
    * changed global var access, TOC now contain pointers to globals
    * fixed handling of function pointers

  Revision 1.17  2003/01/08 18:43:57  daniel
   * Tregister changed into a record

  Revision 1.16  2002/11/28 10:56:07  olle
    * changed proc ref from .xxx[PR] (refering to its section)
      to .xxx (refering to its label) to allow for multiple ref to a proc.

  Revision 1.15  2002/11/17 16:31:59  carl
    * memory optimization (3-4%) : cleanup of tai fields,
       cleanup of tdef and tsym fields.
    * make it work for m68k

  Revision 1.14  2002/11/07 15:50:23  jonas
    * fixed bctr(l) problems

  Revision 1.13  2002/11/04 18:24:53  olle
    * globals are located in TOC and relative r2, instead of absolute
    * symbols which only differs in case are treated as a single symbol
    + tai_const_symbol supported
    * only refs_full accepted

  Revision 1.12  2002/10/23 15:31:01  olle
    * branch b does not jump to dotted symbol now

  Revision 1.11  2002/10/19 23:52:40  olle
    * import directive changed

  Revision 1.10  2002/10/10 19:39:37  florian
    * changes from Olle to get simple programs compiled and assembled

  Revision 1.9  2002/10/07 21:19:53  florian
    * more mpw fixes

  Revision 1.8  2002/10/06 22:46:20  florian
    * fixed function exporting

  Revision 1.7  2002/10/02 22:14:15  florian
    * improve function imports

  Revision 1.6  2002/09/27 21:09:49  florian
    + readed because previous version was broken

  Revision 1.2  2002/08/31 12:43:31  florian
    * ppc compilation fixed

  Revision 1.1  2002/08/20 21:40:44  florian
    + target macos for ppc added
    + frame work for mpw assembler output
}
