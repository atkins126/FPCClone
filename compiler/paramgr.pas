{
    $Id$
    Copyright (c) 2002 by Florian Klaempfl

    Generic calling convention handling

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
{# Parameter passing manager. Used to manage how
   parameters are passed to routines.
}
unit paramgr;

{$i fpcdefs.inc}

  interface

    uses
       cclasses,globtype,
       cpubase,cgbase,
       parabase,
       aasmtai,
       symconst,symtype,symsym,symdef;

    type
       {# This class defines some methods to take care of routine
          parameters. It should be overriden for each new processor
       }
       tparamanager = class
          { true if the location in paraloc can be reused as localloc }
          function param_use_paraloc(const cgpara:tcgpara):boolean;virtual;
          {# Returns true if the return value is actually a parameter
             pointer.
          }
          function ret_in_param(def : tdef;calloption : tproccalloption) : boolean;virtual;

          function push_high_param(varspez:tvarspez;def : tdef;calloption : tproccalloption) : boolean;virtual;

          { Returns true if a parameter is too large to copy and only
            the address is pushed
          }
          function push_addr_param(varspez:tvarspez;def : tdef;calloption : tproccalloption) : boolean;virtual;abstract;
          { return the size of a push }
          function push_size(varspez:tvarspez;def : tdef;calloption : tproccalloption) : longint;
          {# Returns a structure giving the information on
            the storage of the parameter (which must be
            an integer parameter). This is only used when calling
            internal routines directly, where all parameters must
            be 4-byte values.

            In case the location is a register, this register is allocated.
            Call freeintparaloc() after the call to free the locations again.
            Default implementation: don't do anything at all (in case you don't
            use register parameter passing)

            @param(list Current assembler list)
            @param(nr Parameter number of routine, starting from 1)
          }
          function get_para_align(calloption : tproccalloption):byte;virtual;
          function get_volatile_registers_int(calloption : tproccalloption):tcpuregisterset;virtual;
          function get_volatile_registers_fpu(calloption : tproccalloption):tcpuregisterset;virtual;
          function get_volatile_registers_flags(calloption : tproccalloption):tcpuregisterset;virtual;
          function get_volatile_registers_mm(calloption : tproccalloption):tcpuregisterset;virtual;

          procedure getintparaloc(calloption : tproccalloption; nr : longint;var cgpara:TCGPara);virtual;abstract;

          {# allocate a parameter location created with create_paraloc_info

            @param(list Current assembler list)
            @param(loc Parameter location)
          }
          procedure allocparaloc(list: taasmoutput; const cgpara: TCGPara); virtual;

          {# free a parameter location allocated with alloccgpara

            @param(list Current assembler list)
            @param(loc Parameter location)
          }
          procedure freeparaloc(list: taasmoutput; const cgpara: TCGPara); virtual;

          { This is used to populate the location information on all parameters
            for the routine as seen in either the caller or the callee. It returns
            the size allocated on the stack
          }
          function  create_paraloc_info(p : tabstractprocdef; side: tcallercallee):longint;virtual;abstract;

          { This is used to populate the location information on all parameters
            for the routine when it is being inlined. It returns
            the size allocated on the stack
          }
          function  create_inline_paraloc_info(p : tabstractprocdef):longint;virtual;

          { This is used to populate the location information on all parameters
            for the routine that are passed as varargs. It returns
            the size allocated on the stack (including the normal parameters)
          }
          function  create_varargs_paraloc_info(p : tabstractprocdef; varargspara:tvarargsparalist):longint;virtual;abstract;

          procedure createtempparaloc(list: taasmoutput;calloption : tproccalloption;parasym : tparavarsym;var cgpara:TCGPara);virtual;
          procedure duplicateparaloc(list: taasmoutput;calloption : tproccalloption;parasym : tparavarsym;var cgpara:TCGPara);

          function parseparaloc(parasym : tparavarsym;const s : string) : boolean;virtual;abstract;
       end;


    var
       paramanager : tparamanager;


implementation

    uses
       systems,
       cgobj,tgobj,cgutils,
       defutil,verbose;

    { true if the location in paraloc can be reused as localloc }
    function tparamanager.param_use_paraloc(const cgpara:tcgpara):boolean;
      begin
        result:=false;
      end;


    { true if uses a parameter as return value }
    function tparamanager.ret_in_param(def : tdef;calloption : tproccalloption) : boolean;
      begin
         ret_in_param:=((def.deftype=arraydef) and not(is_dynamic_array(def))) or
           (def.deftype=recorddef) or
           ((def.deftype=stringdef) and (tstringdef(def).string_typ in [st_shortstring,st_longstring])) or
           ((def.deftype=procvardef) and (po_methodpointer in tprocvardef(def).procoptions)) or
           ((def.deftype=objectdef) and is_object(def)) or
           (def.deftype=variantdef) or
           ((def.deftype=setdef) and (tsetdef(def).settype<>smallset));
      end;


    function tparamanager.push_high_param(varspez:tvarspez;def : tdef;calloption : tproccalloption) : boolean;
      begin
         push_high_param:=not(calloption in [pocall_cdecl,pocall_cppdecl]) and
                          (
                           is_open_array(def) or
                           is_open_string(def) or
                           is_array_of_const(def)
                          );
      end;


    { return the size of a push }
    function tparamanager.push_size(varspez:tvarspez;def : tdef;calloption : tproccalloption) : longint;
      begin
        push_size:=-1;
        case varspez of
          vs_out,
          vs_var :
            push_size:=sizeof(aint);
          vs_value,
          vs_const :
            begin
                if push_addr_param(varspez,def,calloption) then
                  push_size:=sizeof(aint)
                else
                  begin
                    { special array are normally pushed by addr, only for
                      cdecl array of const it comes here and the pushsize
                      is unknown }
                    if is_array_of_const(def) then
                      push_size:=0
                    else
                      push_size:=def.size;
                  end;
            end;
        end;
      end;


    function tparamanager.get_para_align(calloption : tproccalloption):byte;
      begin
        result:=std_param_align;
      end;


    function tparamanager.get_volatile_registers_int(calloption : tproccalloption):tcpuregisterset;
      begin
        result:=[];
      end;


    function tparamanager.get_volatile_registers_fpu(calloption : tproccalloption):tcpuregisterset;
      begin
        result:=[];
      end;


    function tparamanager.get_volatile_registers_flags(calloption : tproccalloption):tcpuregisterset;
      begin
        result:=[];
      end;


    function tparamanager.get_volatile_registers_mm(calloption : tproccalloption):tcpuregisterset;
      begin
        result:=[];
      end;


    procedure tparamanager.allocparaloc(list: taasmoutput; const cgpara: TCGPara);
      var
        paraloc : pcgparalocation;
      begin
        paraloc:=cgpara.location;
        while assigned(paraloc) do
          begin
            case paraloc^.loc of
              LOC_REGISTER,
              LOC_CREGISTER:
                begin
                  if getsupreg(paraloc^.register)<first_int_imreg then
                    cg.getcpuregister(list,paraloc^.register);
                end;
              LOC_FPUREGISTER,
              LOC_CFPUREGISTER:
                begin
                  if getsupreg(paraloc^.register)<first_fpu_imreg then
                    cg.getcpuregister(list,paraloc^.register);
                end;
              LOC_MMREGISTER,
              LOC_CMMREGISTER :
                begin
                  if getsupreg(paraloc^.register)<first_mm_imreg then
                    cg.getcpuregister(list,paraloc^.register);
                end;
            end;
            paraloc:=paraloc^.next;
          end;
      end;


    procedure tparamanager.freeparaloc(list: taasmoutput; const cgpara: TCGPara);
      var
        paraloc : Pcgparalocation;
{$ifdef cputargethasfixedstack}
        href : treference;
{$endif cputargethasfixedstack}
      begin
        paraloc:=cgpara.location;
        while assigned(paraloc) do
          begin
            case paraloc^.loc of
              LOC_VOID:
                ;
              LOC_REGISTER,
              LOC_CREGISTER:
                begin
                  if getsupreg(paraloc^.register)<first_int_imreg then
                    cg.ungetcpuregister(list,paraloc^.register);
                end;
              LOC_FPUREGISTER,
              LOC_CFPUREGISTER:
                begin
                  if getsupreg(paraloc^.register)<first_fpu_imreg then
                    cg.ungetcpuregister(list,paraloc^.register);
                end;
              LOC_MMREGISTER,
              LOC_CMMREGISTER :
                begin
                  if getsupreg(paraloc^.register)<first_mm_imreg then
                    cg.ungetcpuregister(list,paraloc^.register);
                end;
              LOC_REFERENCE,
              LOC_CREFERENCE :
                begin
{$ifdef cputargethasfixedstack}
                  { don't use reference_reset_base, because that will depend on cgobj }
                  fillchar(href,sizeof(href),0);
                  href.base:=paraloc^.reference.index;
                  href.offset:=paraloc^.reference.offset;
                  tg.ungettemp(list,href);
{$endif cputargethasfixedstack}
                end;
              else
                internalerror(2004110212);
            end;
            paraloc:=paraloc^.next;
          end;
      end;


    procedure tparamanager.createtempparaloc(list: taasmoutput;calloption : tproccalloption;parasym : tparavarsym;var cgpara:TCGPara);
      var
        href : treference;
        len  : aint;
        paraloc,
        newparaloc : pcgparalocation;
      begin
        cgpara.reset;
        cgpara.size:=parasym.paraloc[callerside].size;
        cgpara.intsize:=parasym.paraloc[callerside].intsize;
        cgpara.alignment:=parasym.paraloc[callerside].alignment;
{$ifdef powerpc}
        cgpara.composite:=parasym.paraloc[callerside].composite;
{$endif powerpc}
        paraloc:=parasym.paraloc[callerside].location;
        while assigned(paraloc) do
          begin
            if paraloc^.size=OS_NO then
              len:=push_size(parasym.varspez,parasym.vartype.def,calloption)
            else
              len:=tcgsize2size[paraloc^.size];
            newparaloc:=cgpara.add_location;
            newparaloc^.size:=paraloc^.size;
{$warning maybe release this optimization for all targets?}
{$ifdef sparc}
            { Does it fit a register? }
            if len<=sizeof(aint) then
              newparaloc^.loc:=LOC_REGISTER
            else
{$endif sparc}
              newparaloc^.loc:=paraloc^.loc;
            case newparaloc^.loc of
              LOC_REGISTER :
                newparaloc^.register:=cg.getintregister(list,paraloc^.size);
              LOC_FPUREGISTER :
                newparaloc^.register:=cg.getfpuregister(list,paraloc^.size);
              LOC_MMREGISTER :
                newparaloc^.register:=cg.getmmregister(list,paraloc^.size);
              LOC_REFERENCE :
                begin
                  tg.gettemp(list,len,tt_persistent,href);
                  newparaloc^.reference.index:=href.base;
                  newparaloc^.reference.offset:=href.offset;
                end;
            end;
            paraloc:=paraloc^.next;
          end;
      end;


    procedure tparamanager.duplicateparaloc(list: taasmoutput;calloption : tproccalloption;parasym : tparavarsym;var cgpara:TCGPara);
      var
        paraloc,
        newparaloc : pcgparalocation;
      begin
        cgpara.reset;
        cgpara.size:=parasym.paraloc[callerside].size;
        cgpara.intsize:=parasym.paraloc[callerside].intsize;
        cgpara.alignment:=parasym.paraloc[callerside].alignment;
{$ifdef powerpc}
        cgpara.composite:=parasym.paraloc[callerside].composite;
{$endif powerpc}
        paraloc:=parasym.paraloc[callerside].location;
        while assigned(paraloc) do
          begin
            newparaloc:=cgpara.add_location;
            move(paraloc^,newparaloc^,sizeof(newparaloc^));
            newparaloc^.next:=nil;
            paraloc:=paraloc^.next;
          end;
      end;


    function tparamanager.create_inline_paraloc_info(p : tabstractprocdef):longint;
      begin
        { We need to return the size allocated }
        create_paraloc_info(p,callerside);
        result:=create_paraloc_info(p,calleeside);
      end;


initialization
  ;
finalization
  paramanager.free;
end.

{
   $Log$
   Revision 1.87  2005-02-08 16:40:16  florian
     * dyn. arrays are returned in registers

   Revision 1.86  2005/02/03 20:04:49  peter
     * push_addr_param must be defined per target

   Revision 1.85  2005/01/20 17:47:01  peter
     * remove copy_value_on_stack and a_param_copy_ref

   Revision 1.84  2005/01/18 22:19:20  peter
     * multiple location support for i386 a_param_ref
     * remove a_param_copy_ref for i386

   Revision 1.83  2005/01/10 21:50:05  jonas
     + support for passing records in registers under darwin
     * tcgpara now also has an intsize field, which contains the size in
       bytes of the whole parameter

   Revision 1.82  2004/11/21 17:17:03  florian
     * changed funcret location back to tlocation

   Revision 1.81  2004/11/15 23:35:31  peter
     * tparaitem removed, use tparavarsym instead
     * parameter order is now calculated from paranr value in tparavarsym

   Revision 1.80  2004/10/31 21:45:03  peter
     * generic tlocation
     * move tlocation to cgutils

   Revision 1.79  2004/09/25 14:23:54  peter
     * ungetregister is now only used for cpuregisters, renamed to
       ungetcpuregister
     * renamed (get|unget)explicitregister(s) to ..cpuregister
     * removed location-release/reference_release

   Revision 1.78  2004/09/21 17:25:12  peter
     * paraloc branch merged

   Revision 1.77.4.1  2004/08/31 20:43:06  peter
     * paraloc patch

   Revision 1.77  2004/07/09 23:41:04  jonas
     * support register parameters for inlined procedures + some inline
       cleanups

   Revision 1.76  2004/06/20 08:55:30  florian
     * logs truncated

   Revision 1.75  2004/06/16 20:07:09  florian
     * dwarf branch merged

   Revision 1.74  2004/04/18 15:22:24  florian
     + location support for arguments, currently PowerPC/MorphOS only

   Revision 1.73.2.5  2004/05/03 20:18:52  peter
     * fixes for tprintf

   Revision 1.73.2.4  2004/05/02 20:20:59  florian
     * started to fix callee side result value handling

   Revision 1.73.2.3  2004/05/02 12:45:32  peter
     * enabled cpuhasfixedstack for x86-64 again
     * fixed size of temp allocation for parameters

}

