{
    $Id$
    Copyright (c) 2002 by Florian Klaempfl

    Generates the argument location information for i386

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published bymethodpointer
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
unit cpupara;

{$i fpcdefs.inc}

  interface

    uses
       globtype,
       aasmtai,cpubase,cgbase,
       symconst,symtype,symsym,symdef,
       parabase,paramgr;

    type
       ti386paramanager = class(tparamanager)
          function param_use_paraloc(const cgpara:tcgpara):boolean;override;
          function ret_in_param(def : tdef;calloption : tproccalloption) : boolean;override;
          function push_addr_param(varspez:tvarspez;def : tdef;calloption : tproccalloption) : boolean;override;
          function get_para_align(calloption : tproccalloption):byte;override;
          function get_volatile_registers_int(calloption : tproccalloption):tcpuregisterset;override;
          function get_volatile_registers_fpu(calloption : tproccalloption):tcpuregisterset;override;
          function get_volatile_registers_mm(calloption : tproccalloption):tcpuregisterset;override;
          { Returns the location for the nr-st 32 Bit int parameter
            if every parameter before is an 32 Bit int parameter as well
            and if the calling conventions for the helper routines of the
            rtl are used.
          }
          procedure getintparaloc(calloption : tproccalloption; nr : longint;var cgpara:TCGPara);override;
          function create_paraloc_info(p : tabstractprocdef; side: tcallercallee):longint;override;
          function create_varargs_paraloc_info(p : tabstractprocdef; varargspara:tvarargsparalist):longint;override;
          procedure createtempparaloc(list: taasmoutput;calloption : tproccalloption;parasym : tparavarsym;var cgpara:TCGPara);override;
       private
          procedure create_funcretloc_info(p : tabstractprocdef; side: tcallercallee);
          procedure create_stdcall_paraloc_info(p : tabstractprocdef; side: tcallercallee;paras:tparalist;var parasize:longint);
          procedure create_register_paraloc_info(p : tabstractprocdef; side: tcallercallee;paras:tparalist;var parareg,parasize:longint);
       end;


  implementation

    uses
       cutils,
       systems,verbose,
       defutil,
       cgutils;

      const
        parasupregs : array[0..2] of tsuperregister = (RS_EAX,RS_EDX,RS_ECX);

{****************************************************************************
                                TI386PARAMANAGER
****************************************************************************}

    function ti386paramanager.param_use_paraloc(const cgpara:tcgpara):boolean;
      var
        paraloc : pcgparalocation;
      begin
        if not assigned(cgpara.location) then
          internalerror(200410102);
        result:=true;
        { All locations are LOC_REFERENCE }
        paraloc:=cgpara.location;
        while assigned(paraloc) do
          begin
            if (paraloc^.loc<>LOC_REFERENCE) then
              begin
                result:=false;
                exit;
              end;
            paraloc:=paraloc^.next;
          end;
      end;


    function ti386paramanager.ret_in_param(def : tdef;calloption : tproccalloption) : boolean;
      begin
        case target_info.system of
          system_i386_win32 :
            begin
              case def.deftype of
                recorddef :
                  begin
                    { Win32 GCC returns small records in the FUNCTION_RETURN_REG.
                      For stdcall we follow delphi instead of GCC }
                    if (calloption in [pocall_cdecl,pocall_cppdecl]) and
                       (def.size<=8) then
                     begin
                       result:=false;
                       exit;
                     end;
                  end;
              end;
            end;
        end;
        result:=inherited ret_in_param(def,calloption);
      end;


    function ti386paramanager.push_addr_param(varspez:tvarspez;def : tdef;calloption : tproccalloption) : boolean;
      begin
        result:=false;
        { var,out always require address }
        if varspez in [vs_var,vs_out] then
          begin
            result:=true;
            exit;
          end;
        { Only vs_const, vs_value here }
        case def.deftype of
          variantdef,
          formaldef :
            result:=true;
          recorddef :
            begin
              { Win32 passes small records on the stack for call by
                value }
              if (target_info.system=system_i386_win32) and
                 (calloption in [pocall_stdcall,pocall_cdecl,pocall_cppdecl]) and
                 (varspez=vs_value) and
                 (def.size<=8) then
                result:=false
              else
                result:=not(calloption in [pocall_cdecl,pocall_cppdecl]) and (def.size>sizeof(aint));
            end;
          arraydef :
            begin
              { Win32 passes arrays on the stack for call by
                value }
              if (target_info.system=system_i386_win32) and
                 (calloption in [pocall_stdcall,pocall_cdecl,pocall_cppdecl]) and
                 (varspez=vs_value) and
                 (tarraydef(def).highrange>=tarraydef(def).lowrange) then
                result:=false
              else
              { array of const values are pushed on the stack }
                if (calloption in [pocall_cdecl,pocall_cppdecl]) then
                  result:=not is_array_of_const(def)
              else
                begin
                  result:=(
                           (tarraydef(def).highrange>=tarraydef(def).lowrange) and
                           (def.size>sizeof(aint))
                          ) or
                          is_open_array(def) or
                          is_array_of_const(def) or
                          is_array_constructor(def);
                end;
            end;
          objectdef :
            result:=is_object(def);
          stringdef :
            result:=not(calloption in [pocall_cdecl,pocall_cppdecl]) and (tstringdef(def).string_typ in [st_shortstring,st_longstring]);
          procvardef :
            result:=not(calloption in [pocall_cdecl,pocall_cppdecl]) and (po_methodpointer in tprocvardef(def).procoptions);
          setdef :
            result:=not(calloption in [pocall_cdecl,pocall_cppdecl]) and (tsetdef(def).settype<>smallset);
        end;
      end;


    function ti386paramanager.get_para_align(calloption : tproccalloption):byte;
      begin
        if calloption=pocall_oldfpccall then
          begin
            if target_info.system in [system_i386_go32v2,system_i386_watcom] then
              result:=2
            else
              result:=4;
          end
        else
          result:=std_param_align;
      end;


    function ti386paramanager.get_volatile_registers_int(calloption : tproccalloption):tcpuregisterset;
      begin
        case calloption of
          pocall_internproc :
            result:=[];
          pocall_compilerproc :
            begin
              if pocall_default=pocall_oldfpccall then
                result:=[RS_EAX,RS_EDX,RS_ECX,RS_ESI,RS_EDI,RS_EBX]
              else
                result:=[RS_EAX,RS_EDX,RS_ECX];
            end;
          pocall_inline,
          pocall_register,
          pocall_safecall,
          pocall_stdcall,
          pocall_cdecl,
          pocall_cppdecl :
            result:=[RS_EAX,RS_EDX,RS_ECX];
          pocall_far16,
          pocall_pascal,
          pocall_oldfpccall :
            result:=[RS_EAX,RS_EDX,RS_ECX,RS_ESI,RS_EDI,RS_EBX];
          else
            internalerror(200309071);
        end;
      end;


    function ti386paramanager.get_volatile_registers_fpu(calloption : tproccalloption):tcpuregisterset;
      begin
        result:=[0..first_fpu_imreg-1];
      end;


    function ti386paramanager.get_volatile_registers_mm(calloption : tproccalloption):tcpuregisterset;
      begin
        result:=[0..first_mm_imreg-1];
      end;


    procedure ti386paramanager.getintparaloc(calloption : tproccalloption; nr : longint;var cgpara:TCGPara);
      var
        paraloc : pcgparalocation;
      begin
        cgpara.reset;
        cgpara.size:=OS_INT;
        cgpara.intsize:=tcgsize2size[OS_INT];
        cgpara.alignment:=get_para_align(calloption);
        paraloc:=cgpara.add_location;
        with paraloc^ do
         begin
           size:=OS_INT;
           if calloption=pocall_register then
             begin
               if (nr<=high(parasupregs)+1) then
                 begin
                   if nr=0 then
                     internalerror(200309271);
                   loc:=LOC_REGISTER;
                   register:=newreg(R_INTREGISTER,parasupregs[nr-1],R_SUBWHOLE);
                 end
               else
                 begin
                   loc:=LOC_REFERENCE;
                   reference.index:=NR_STACK_POINTER_REG;
                   reference.offset:=sizeof(aint)*nr;
                 end;
             end
           else
             begin
               loc:=LOC_REFERENCE;
               reference.index:=NR_STACK_POINTER_REG;
               reference.offset:=sizeof(aint)*nr;
             end;
          end;
      end;


    procedure ti386paramanager.create_funcretloc_info(p : tabstractprocdef; side: tcallercallee);
      var
        retcgsize  : tcgsize;
      begin
        { Constructors return self instead of a boolean }
        if (p.proctypeoption=potype_constructor) then
          retcgsize:=OS_ADDR
        else
          retcgsize:=def_cgsize(p.rettype.def);

        location_reset(p.funcretloc[side],LOC_INVALID,OS_NO);
        { void has no location }
        if is_void(p.rettype.def) then
          begin
            location_reset(p.funcretloc[side],LOC_VOID,OS_NO);
            exit;
          end;
        { Return in FPU register? }
        if p.rettype.def.deftype=floatdef then
          begin
            p.funcretloc[side].loc:=LOC_FPUREGISTER;
            p.funcretloc[side].register:=NR_FPU_RESULT_REG;
            p.funcretloc[side].size:=retcgsize;
          end
        else
         { Return in register? }
         if not ret_in_param(p.rettype.def,p.proccalloption) then
          begin
            if retcgsize in [OS_64,OS_S64] then
             begin
               { low 32bits }
               p.funcretloc[side].loc:=LOC_REGISTER;
               p.funcretloc[side].size:=OS_64;
               if side=callerside then
                 p.funcretloc[side].register64.reglo:=NR_FUNCTION_RESULT64_LOW_REG
               else
                 p.funcretloc[side].register64.reglo:=NR_FUNCTION_RETURN64_LOW_REG;
               { high 32bits }
               if side=callerside then
                 p.funcretloc[side].register64.reghi:=NR_FUNCTION_RESULT64_HIGH_REG
               else
                 p.funcretloc[side].register64.reghi:=NR_FUNCTION_RETURN64_HIGH_REG;
             end
            else
             begin
               p.funcretloc[side].loc:=LOC_REGISTER;
               p.funcretloc[side].size:=retcgsize;
               if side=callerside then
                 p.funcretloc[side].register:=newreg(R_INTREGISTER,RS_FUNCTION_RESULT_REG,cgsize2subreg(retcgsize))
               else
                 p.funcretloc[side].register:=newreg(R_INTREGISTER,RS_FUNCTION_RETURN_REG,cgsize2subreg(retcgsize));
             end;
          end
        else
          begin
            p.funcretloc[side].loc:=LOC_REFERENCE;
            p.funcretloc[side].size:=retcgsize;
          end;
      end;


    procedure ti386paramanager.create_stdcall_paraloc_info(p : tabstractprocdef; side: tcallercallee;paras:tparalist;var parasize:longint);
      var
        i  : integer;
        hp : tparavarsym;
        paraloc : pcgparalocation;
        l,
        paralen,
        varalign   : longint;
        paraalign  : shortint;
        pushaddr   : boolean;
        paracgsize : tcgsize;
      begin
        paraalign:=get_para_align(p.proccalloption);
        { we push Flags and CS as long
          to cope with the IRETD
          and we save 6 register + 4 selectors }
        if po_interrupt in p.procoptions then
          inc(parasize,8+6*4+4*2);
        { Offset is calculated like:
           sub esp,12
           mov [esp+8],para3
           mov [esp+4],para2
           mov [esp],para1
           call function
          That means for pushes the para with the
          highest offset (see para3) needs to be pushed first
        }
        for i:=0 to paras.count-1 do
          begin
            hp:=tparavarsym(paras[i]);
            pushaddr:=push_addr_param(hp.varspez,hp.vartype.def,p.proccalloption);
            if pushaddr then
              begin
                paralen:=sizeof(aint);
                paracgsize:=OS_ADDR;
              end
            else
              begin
                paralen:=push_size(hp.varspez,hp.vartype.def,p.proccalloption);
                paracgsize:=def_cgsize(hp.vartype.def);
              end;
            hp.paraloc[side].reset;
            hp.paraloc[side].size:=paracgsize;
            hp.paraloc[side].intsize:=paralen;
            hp.paraloc[side].Alignment:=paraalign;
            { Copy to stack? }
            if paracgsize=OS_NO then
              begin
                paraloc:=hp.paraloc[side].add_location;
                paraloc^.loc:=LOC_REFERENCE;
                paraloc^.size:=paracgsize;
                if side=callerside then
                  paraloc^.reference.index:=NR_STACK_POINTER_REG
                else
                  paraloc^.reference.index:=NR_FRAME_POINTER_REG;
                varalign:=used_align(size_2_align(paralen),paraalign,paraalign);
                paraloc^.reference.offset:=parasize;
                parasize:=align(parasize+paralen,varalign);
              end
            else
              begin
                if paralen=0 then
                  internalerror(200501163);
                while (paralen>0) do
                  begin
                    { We can allocate at maximum 32 bits per location }
                    if paralen>sizeof(aint) then
                      l:=sizeof(aint)
                    else
                      l:=paralen;
                    paraloc:=hp.paraloc[side].add_location;
                    paraloc^.loc:=LOC_REFERENCE;
                    paraloc^.size:=int_cgsize(l);
                    if side=callerside then
                      paraloc^.reference.index:=NR_STACK_POINTER_REG
                    else
                      paraloc^.reference.index:=NR_FRAME_POINTER_REG;
                    varalign:=used_align(size_2_align(l),paraalign,paraalign);
                    paraloc^.reference.offset:=parasize;
                    parasize:=align(parasize+l,varalign);
                    dec(paralen,l);
                  end;
              end;
          end;
        { Adapt offsets for left-to-right calling }
        if p.proccalloption in pushleftright_pocalls then
          begin
            for i:=0 to paras.count-1 do
              begin
                hp:=tparavarsym(paras[i]);
                l:=push_size(hp.varspez,hp.vartype.def,p.proccalloption);
                varalign:=used_align(size_2_align(l),paraalign,paraalign);
                l:=align(l,varalign);
                with hp.paraloc[side].location^ do
                  begin
                    reference.offset:=parasize-reference.offset-l;
                    if side=calleeside then
                      inc(reference.offset,target_info.first_parm_offset);
                  end;
              end;
          end
        else
          begin
            { Only need to adapt the callee side to include the
              standard stackframe size }
            if side=calleeside then
              begin
                for i:=0 to paras.count-1 do
                  begin
                    hp:=tparavarsym(paras[i]);
                    inc(hp.paraloc[side].location^.reference.offset,target_info.first_parm_offset);
                  end;
               end;
          end;
      end;


    procedure ti386paramanager.create_register_paraloc_info(p : tabstractprocdef; side: tcallercallee;paras:tparalist;
                                                            var parareg,parasize:longint);
      var
        hp : tparavarsym;
        paraloc : pcgparalocation;
        paracgsize : tcgsize;
        i : integer;
        l,
        paralen,
        varalign : longint;
        pushaddr : boolean;
        paraalign : shortint;
      begin
        paraalign:=get_para_align(p.proccalloption);
        { Register parameters are assigned from left to right }
        for i:=0 to paras.count-1 do
          begin
            hp:=tparavarsym(paras[i]);
            pushaddr:=push_addr_param(hp.varspez,hp.vartype.def,p.proccalloption);
            if pushaddr then
              begin
                paralen:=sizeof(aint);
                paracgsize:=OS_ADDR;
              end
            else
              begin
                paralen:=push_size(hp.varspez,hp.vartype.def,p.proccalloption);
                paracgsize:=def_cgsize(hp.vartype.def);
              end;
            hp.paraloc[side].reset;
            hp.paraloc[side].size:=paracgsize;
            hp.paraloc[side].intsize:=paralen;
            hp.paraloc[side].Alignment:=paraalign;
            {
              EAX
              EDX
              ECX
              Stack
              Stack

              64bit values,floats,arrays and records are always
              on the stack.
            }
            if (parareg<=high(parasupregs)) and
               (paralen<=sizeof(aint)) and
               (
                not(hp.vartype.def.deftype in [floatdef,recorddef,arraydef]) or
                pushaddr
               ) then
              begin
                paraloc:=hp.paraloc[side].add_location;
                paraloc^.size:=paracgsize;
                paraloc^.loc:=LOC_REGISTER;
                paraloc^.register:=newreg(R_INTREGISTER,parasupregs[parareg],cgsize2subreg(paracgsize));
                inc(parareg);
              end
            else
              begin
                { Copy to stack? }
                if paracgsize=OS_NO then
                  begin
                    paraloc:=hp.paraloc[side].add_location;
                    paraloc^.loc:=LOC_REFERENCE;
                    paraloc^.size:=paracgsize;
                    if side=callerside then
                      paraloc^.reference.index:=NR_STACK_POINTER_REG
                    else
                      paraloc^.reference.index:=NR_FRAME_POINTER_REG;
                    varalign:=used_align(size_2_align(paralen),paraalign,paraalign);
                    paraloc^.reference.offset:=parasize;
                    parasize:=align(parasize+paralen,varalign);
                  end
                else
                  begin
                    if paralen=0 then
                      internalerror(200501163);
                    while (paralen>0) do
                      begin
                        { We can allocate at maximum 32 bits per location }
                        if paralen>sizeof(aint) then
                          l:=sizeof(aint)
                        else
                          l:=paralen;
                        paraloc:=hp.paraloc[side].add_location;
                        paraloc^.loc:=LOC_REFERENCE;
                        paraloc^.size:=int_cgsize(l);
                        if side=callerside then
                          paraloc^.reference.index:=NR_STACK_POINTER_REG
                        else
                          paraloc^.reference.index:=NR_FRAME_POINTER_REG;
                        varalign:=used_align(size_2_align(l),paraalign,paraalign);
                        paraloc^.reference.offset:=parasize;
                        parasize:=align(parasize+l,varalign);
                        dec(paralen,l);
                      end;
                  end;
              end;
          end;
        { Register parameters are assigned from left-to-right, adapt offset
          for calleeside to be reversed }
        for i:=0 to paras.count-1 do
          begin
            hp:=tparavarsym(paras[i]);
            with hp.paraloc[side].location^ do
              begin
                if (loc=LOC_REFERENCE) then
                  begin
                    l:=push_size(hp.varspez,hp.vartype.def,p.proccalloption);
                    varalign:=used_align(size_2_align(l),paraalign,paraalign);
                    l:=align(l,varalign);
                    reference.offset:=parasize-reference.offset-l;
                    if side=calleeside then
                      inc(reference.offset,target_info.first_parm_offset);
                  end;
               end;
          end;
      end;


    function ti386paramanager.create_paraloc_info(p : tabstractprocdef; side: tcallercallee):longint;
      var
        parasize,
        parareg : longint;
      begin
        parasize:=0;
        parareg:=0;
        case p.proccalloption of
          pocall_register :
            create_register_paraloc_info(p,side,p.paras,parareg,parasize);
          pocall_inline,
          pocall_compilerproc,
          pocall_internproc :
            begin
              { Use default calling }
              if (pocall_default=pocall_register) then
                create_register_paraloc_info(p,side,p.paras,parareg,parasize)
              else
                create_stdcall_paraloc_info(p,side,p.paras,parasize);
            end;
          else
            create_stdcall_paraloc_info(p,side,p.paras,parasize);
        end;
        create_funcretloc_info(p,side);
        result:=parasize;
      end;


    function ti386paramanager.create_varargs_paraloc_info(p : tabstractprocdef; varargspara:tvarargsparalist):longint;
      var
        parasize : longint;
      begin
        parasize:=0;
        { calculate the registers for the normal parameters }
        create_stdcall_paraloc_info(p,callerside,p.paras,parasize);
        { append the varargs }
        create_stdcall_paraloc_info(p,callerside,varargspara,parasize);
        result:=parasize;
      end;


    procedure ti386paramanager.createtempparaloc(list: taasmoutput;calloption : tproccalloption;parasym : tparavarsym;var cgpara:TCGPara);
      var
        paraloc : pcgparalocation;
      begin
        paraloc:=parasym.paraloc[callerside].location;
        { No need for temps when value is pushed }
        if assigned(paraloc) and
           (paraloc^.loc=LOC_REFERENCE) and
           (paraloc^.reference.index=NR_STACK_POINTER_REG) then
          duplicateparaloc(list,calloption,parasym,cgpara)
        else
          inherited createtempparaloc(list,calloption,parasym,cgpara);
      end;


begin
   paramanager:=ti386paramanager.create;
end.
{
  $Log$
  Revision 1.65  2005-02-03 20:04:49  peter
    * push_addr_param must be defined per target

  Revision 1.64  2005/01/30 11:03:22  peter
    * revert last commit

  Revision 1.62  2005/01/18 22:19:20  peter
    * multiple location support for i386 a_param_ref
    * remove a_param_copy_ref for i386

  Revision 1.61  2005/01/10 21:50:05  jonas
    + support for passing records in registers under darwin
    * tcgpara now also has an intsize field, which contains the size in
      bytes of the whole parameter

  Revision 1.60  2004/11/22 22:01:19  peter
    * fixed varargs
    * replaced dynarray with tlist

  Revision 1.59  2004/11/21 17:54:59  peter
    * ttempcreatenode.create_reg merged into .create with parameter
      whether a register is allowed
    * funcret_paraloc renamed to funcretloc

  Revision 1.58  2004/11/21 17:17:04  florian
    * changed funcret location back to tlocation

  Revision 1.57  2004/11/15 23:35:31  peter
    * tparaitem removed, use tparavarsym instead
    * parameter order is now calculated from paranr value in tparavarsym

  Revision 1.56  2004/10/31 21:45:03  peter
    * generic tlocation
    * move tlocation to cgutils

  Revision 1.55  2004/09/21 17:25:12  peter
    * paraloc branch merged

  Revision 1.54.4.1  2004/08/31 20:43:06  peter
    * paraloc patch

  Revision 1.54  2004/07/09 23:30:13  jonas
    *  changed first_sse_imreg to first_mm_imreg

  Revision 1.53  2004/07/09 23:09:02  peter
    * varargs calculation fixed, it's now the same as the other
      targets

  Revision 1.52  2004/06/20 08:55:31  florian
    * logs truncated

  Revision 1.51  2004/06/16 20:07:10  florian
    * dwarf branch merged

  Revision 1.50.2.3  2004/05/02 21:37:35  florian
    * setting of func. ret. for i386 fixed

  Revision 1.50.2.2  2004/05/02 12:45:32  peter
    * enabled cpuhasfixedstack for x86-64 again
    * fixed size of temp allocation for parameters

  Revision 1.50.2.1  2004/05/01 16:02:10  peter
    * POINTER_SIZE replaced with sizeof(aint)
    * aint,aword,tconst*int moved to globtype

  Revision 1.50  2004/02/09 22:14:17  peter
    * more x86_64 parameter fixes
    * tparalocation.lochigh is now used to indicate if register64.reghi
      is used and what the type is

}
