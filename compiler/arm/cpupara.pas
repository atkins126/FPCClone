{
    $Id$
    Copyright (c) 2003 by Florian Klaempfl

    ARM specific calling conventions

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
{ ARM specific calling conventions are handled by this unit
}
unit cpupara;

{$i fpcdefs.inc}

  interface

    uses
       globtype,
       aasmtai,
       cpuinfo,cpubase,cgbase,
       symconst,symbase,symtype,symdef,parabase,paramgr;

    type
       tarmparamanager = class(tparamanager)
          function get_volatile_registers_int(calloption : tproccalloption):tcpuregisterset;override;
          function get_volatile_registers_fpu(calloption : tproccalloption):tcpuregisterset;override;
          function push_addr_param(varspez:tvarspez;def : tdef;calloption : tproccalloption) : boolean;override;
          procedure getintparaloc(calloption : tproccalloption; nr : longint;var cgpara:TCGPara);override;
          function create_paraloc_info(p : tabstractprocdef; side: tcallercallee):longint;override;
          function create_varargs_paraloc_info(p : tabstractprocdef; varargspara:tvarargspara):longint;override;
         private
          procedure init_values(var curintreg, curfloatreg, curmmreg: tsuperregister; var cur_stack_offset: aword);
          function create_paraloc_info_intern(p : tabstractprocdef; side: tcallercallee; firstpara: tparaitem;
            var curintreg, curfloatreg, curmmreg: tsuperregister; var cur_stack_offset: aword):longint;
       end;

  implementation

    uses
       verbose,systems,
       rgobj,
       defutil,symsym;


    function tarmparamanager.get_volatile_registers_int(calloption : tproccalloption):tcpuregisterset;
      begin
        result:=VOLATILE_INTREGISTERS;
      end;


    function tarmparamanager.get_volatile_registers_fpu(calloption : tproccalloption):tcpuregisterset;
      begin
        result:=VOLATILE_FPUREGISTERS;
      end;


    procedure tarmparamanager.getintparaloc(calloption : tproccalloption; nr : longint;var cgpara:TCGPara);
      var
        paraloc : pcgparalocation;
      begin
        if nr<1 then
          internalerror(2002070801);
        cgpara.reset;
        cgpara.size:=OS_INT;
        cgpara.alignment:=std_param_align;
        paraloc:=cgpara.add_location;
        with paraloc^ do
          begin
            { the four first parameters are passed into registers }
            if nr<=4 then
              begin
                loc:=LOC_REGISTER;
                register:=newreg(R_INTREGISTER,RS_R0+nr-1,R_SUBWHOLE);
              end
            else
              begin
                { the other parameters are passed on the stack }
                loc:=LOC_REFERENCE;
                reference.index:=NR_STACK_POINTER_REG;
                reference.offset:=(nr-5)*4;
              end;
          end;
      end;


    function getparaloc(calloption : tproccalloption; p : tdef) : tcgloc;
      begin
         { Later, the LOC_REFERENCE is in most cases changed into LOC_REGISTER
           if push_addr_param for the def is true
         }
         case p.deftype of
            orddef:
              getparaloc:=LOC_REGISTER;
            floatdef:
              if calloption=pocall_softfloat then
                getparaloc:=LOC_REGISTER
              else
                getparaloc:=LOC_FPUREGISTER;
            enumdef:
              getparaloc:=LOC_REGISTER;
            pointerdef:
              getparaloc:=LOC_REGISTER;
            formaldef:
              getparaloc:=LOC_REGISTER;
            classrefdef:
              getparaloc:=LOC_REGISTER;
            recorddef:
              getparaloc:=LOC_REFERENCE;
            objectdef:
              if is_object(p) then
                getparaloc:=LOC_REFERENCE
              else
                getparaloc:=LOC_REGISTER;
            stringdef:
              if is_shortstring(p) or is_longstring(p) then
                getparaloc:=LOC_REFERENCE
              else
                getparaloc:=LOC_REGISTER;
            procvardef:
              if (po_methodpointer in tprocvardef(p).procoptions) then
                getparaloc:=LOC_REFERENCE
              else
                getparaloc:=LOC_REGISTER;
            filedef:
              getparaloc:=LOC_REGISTER;
            arraydef:
              getparaloc:=LOC_REFERENCE;
            setdef:
              if is_smallset(p) then
                getparaloc:=LOC_REGISTER
              else
                getparaloc:=LOC_REFERENCE;
            variantdef:
              getparaloc:=LOC_REFERENCE;
            { avoid problems with errornous definitions }
            errordef:
              getparaloc:=LOC_REGISTER;
            else
              internalerror(2002071001);
         end;
      end;


    function tarmparamanager.push_addr_param(varspez:tvarspez;def : tdef;calloption : tproccalloption) : boolean;
      begin
        if varspez in [vs_var,vs_out] then
          begin
            result:=true;
            exit;
          end;
        case def.deftype of
          recorddef:
            result:=true;
          arraydef:
            result:=(tarraydef(def).highrange>=tarraydef(def).lowrange) or
                             is_open_array(def) or
                             is_array_of_const(def) or
                             is_array_constructor(def);
          setdef :
            result:=(tsetdef(def).settype<>smallset);
          stringdef :
            result:=tstringdef(def).string_typ in [st_shortstring,st_longstring];
          procvardef :
            result:=po_methodpointer in tprocvardef(def).procoptions;
          else
            result:=inherited push_addr_param(varspez,def,calloption);
        end;
      end;


    procedure tarmparamanager.init_values(var curintreg, curfloatreg, curmmreg: tsuperregister; var cur_stack_offset: aword);
      begin
        curintreg:=RS_R0;
        curfloatreg:=RS_F0;
        curmmreg:=RS_D0;
        cur_stack_offset:=0;
      end;


    function tarmparamanager.create_paraloc_info_intern(p : tabstractprocdef; side: tcallercallee; firstpara: tparaitem;
        var curintreg, curfloatreg, curmmreg: tsuperregister; var cur_stack_offset: aword):longint;

      var
        nextintreg,nextfloatreg,nextmmreg : tsuperregister;
        paradef : tdef;
        paraloc : pcgparalocation;
        stack_offset : aword;
        hp : tparaitem;
        loc : tcgloc;
        is_64bit: boolean;

      procedure assignintreg;
        begin
           if nextintreg<=ord(NR_R3) then
             begin
               paraloc^.loc:=LOC_REGISTER;
               paraloc^.register:=newreg(R_INTREGISTER,nextintreg,R_SUBWHOLE);
               inc(nextintreg);
             end
           else
             begin
               paraloc^.loc:=LOC_REFERENCE;
               paraloc^.reference.index:=NR_STACK_POINTER_REG;
               paraloc^.reference.offset:=stack_offset;
               inc(stack_offset,4);
            end;
        end;


      begin
        result:=0;
        nextintreg:=curintreg;
        nextfloatreg:=curfloatreg;
        nextmmreg:=curmmreg;
        stack_offset:=cur_stack_offset;

        hp:=firstpara;
        while assigned(hp) do
          begin
            { currently only support C-style array of const,
              there should be no location assigned to the vararg array itself }
            if (p.proccalloption in [pocall_cdecl,pocall_cppdecl]) and
               is_array_of_const(hp.paratype.def) then
              begin
                paraloc:=hp.paraloc[side].add_location;
                { hack: the paraloc must be valid, but is not actually used }
                paraloc^.loc:=LOC_REGISTER;
                paraloc^.register:=NR_R0;
                paraloc^.size:=OS_ADDR;
                break;
              end;

             hp.paraloc[side].reset;
             hp.paraloc[side].size:=paracgsize;
             hp.paraloc[side].Alignment:=std_param_align;
             paralen:=tcgsize2size[paracgsize];

             if (hp.paratyp in [vs_var,vs_out]) then
               begin
                 paradef:=voidpointertype.def;
                 loc:=LOC_REGISTER;
               end
             else
               begin
                 paradef:=hp.paratype.def;
                 loc:=getparaloc(p.proccalloption,paradef);
               end;

             paraloc:=hp.paraloc[side].add_location;
             case loc of
                LOC_REGISTER:
                  begin
                    paraloc^.size := def_cgsize(paradef);
                    { for things like formaldef }
                    if paraloc^.size = OS_NO then
                      paraloc^.size := OS_ADDR;
                    is_64bit:=paraloc^.size in [OS_64,OS_S64,OS_F64];
                    { this is not abi compliant }
                    if nextintreg<=(RS_R3-ord(is_64bit)) then
                      begin
                        paraloc^.loc:=LOC_REGISTER;
                        paraloc^.registerlow:=newreg(R_INTREGISTER,nextintreg,R_SUBWHOLE);
                        inc(nextintreg);
                        if is_64bit then
                         begin
                           paraloc^.lochigh:=LOC_REGISTER;
                           paraloc.registerhigh:=newreg(R_INTREGISTER,nextintreg,R_SUBWHOLE);
                           inc(nextintreg);
                         end;
                      end
                    else
                       begin
                         nextintreg:=RS_R4;
                         paraloc.loc:=LOC_REFERENCE;
                         paraloc.reference.index:=NR_STACK_POINTER_REG;
                         paraloc.reference.offset:=stack_offset;
                         if not is_64bit then
                           inc(stack_offset,4)
                         else
                           inc(stack_offset,8);
                      end;
                  end;
                LOC_FPUREGISTER:
                  begin
                    paraloc.size:=def_cgsize(paradef);
                    if nextfloatreg<=RS_F3 then
                      begin
                        paraloc.loc:=LOC_FPUREGISTER;
                        paraloc.register:=newreg(R_FPUREGISTER,nextfloatreg,R_SUBWHOLE);
                        inc(nextfloatreg);
                      end
                    else
                      begin
                        paraloc^.size:=def_cgsize(paradef);
                        nextintreg:=RS_F4;
                        paraloc^.loc:=LOC_REFERENCE;
                        paraloc^.reference.index:=NR_STACK_POINTER_REG;
                        paraloc^.reference.offset:=stack_offset;
                        case paraloc.size of
                          OS_F32:
                            inc(stack_offset,4);
                          OS_F64:
                            inc(stack_offset,8);
                          OS_F80:
                            inc(stack_offset,10);
                          OS_F128:
                            inc(stack_offset,16);
                          else
                            internalerror(200403201);
                        end;
                      end;
                  end;
                LOC_REFERENCE:
                  begin
                    paraloc^.size:=OS_ADDR;
                    if push_addr_param(hp.paratyp,paradef,p.proccalloption) or
                      is_open_array(paradef) or
                      is_array_of_const(paradef) then
                      assignintreg
                    else
                      begin
                         paraloc.loc:=LOC_REFERENCE;
                         paraloc.reference.index:=NR_STACK_POINTER_REG;
                         paraloc.reference.offset:=stack_offset;
                         inc(stack_offset,hp.paratype.def.size);
                      end;
                  end;
                else
                  internalerror(2002071002);
             end;
             if side=calleeside then
               begin
                 if paraloc.loc=LOC_REFERENCE then
                   begin
                     paraloc.reference.index:=NR_FRAME_POINTER_REG;
                     inc(paraloc.reference.offset,4);
                   end;
               end;
             hp.paraloc[side]:=paraloc;
             hp:=tparaitem(hp.next);
          end;
        curintreg:=nextintreg;
        curfloatreg:=nextfloatreg;
        curmmreg:=nextmmreg;
        cur_stack_offset:=stack_offset;
        result:=cur_stack_offset;
      end;


    function tarmparamanager.create_paraloc_info(p : tabstractprocdef; side: tcallercallee):longint;
      var
        paraloc : tparalocation;
        cur_stack_offset: aword;
        curintreg, curfloatreg, curmmreg: tsuperregister;
      begin
        init_values(curintreg,curfloatreg,curmmreg,cur_stack_offset);

        result:=create_paraloc_info_intern(p,side,tparaitem(p.para.first),curintreg,curfloatreg,curmmreg,cur_stack_offset);

        { Function return }
        fillchar(paraloc,sizeof(tparalocation),0);
        paraloc.lochigh:=LOC_INVALID;
        paraloc.size:=def_cgsize(p.rettype.def);
        { Return in FPU register? }
        if p.rettype.def.deftype=floatdef then
          begin
            paraloc.loc:=LOC_FPUREGISTER;
            paraloc.register:=NR_FPU_RESULT_REG;
          end
        else
          { Return in register? }
          if not ret_in_param(p.rettype.def,p.proccalloption) then
            begin
              paraloc.loc:=LOC_REGISTER;
              if paraloc.size in [OS_64,OS_S64] then
                begin
                  paraloc.lochigh:=LOC_REGISTER;
                  paraloc.register:=NR_FUNCTION_RETURN64_LOW_REG;
                  paraloc.registerhigh:=NR_FUNCTION_RETURN64_HIGH_REG;
                end
              else
                paraloc.register:=NR_FUNCTION_RETURN_REG;
            end
        else
          begin
            paraloc.loc:=LOC_REFERENCE;
          end;
        p.funcret_paraloc[side]:=paraloc;
     end;


    function tarmparamanager.create_varargs_paraloc_info(p : tabstractprocdef; varargspara:tvarargspara):longint;
      var
        cur_stack_offset: aword;
        parasize, l: longint;
        curintreg, curfloatreg, curmmreg: tsuperregister;
        hp: tparaitem;
        paraloc: tparalocation;
      begin
        init_values(curintreg,curfloatreg,curmmreg,cur_stack_offset);

        result:=create_paraloc_info_intern(p,callerside,tparaitem(p.para.first),curintreg,curfloatreg,curmmreg,cur_stack_offset);
        if (p.proccalloption in [pocall_cdecl,pocall_cppdecl]) then
          { just continue loading the parameters in the registers }
          result:=create_paraloc_info_intern(p,callerside,tparaitem(varargspara.first),curintreg,curfloatreg,curmmreg,cur_stack_offset)
        else
          begin
            hp:=tparaitem(varargspara.first);
            parasize:=cur_stack_offset;
            while assigned(hp) do
              begin
                paraloc.size:=def_cgsize(hp.paratype.def);
                paraloc.lochigh:=LOC_INVALID;
                paraloc.loc:=LOC_REFERENCE;
                paraloc.alignment:=4;
                paraloc.reference.index:=NR_STACK_POINTER_REG;
                l:=push_size(hp.paratyp,hp.paratype.def,p.proccalloption);
                paraloc.reference.offset:=parasize;
                parasize:=parasize+l;
                hp.paraloc[callerside]:=paraloc;
                hp:=tparaitem(hp.next);
              end;
            result := parasize;
          end;
      end;

begin
   paramanager:=tarmparamanager.create;
end.
{
  $Log$
  Revision 1.20  2004-10-22 16:36:57  florian
    * first arm fixes for new paraloc handling

  Revision 1.19  2004/06/20 08:55:31  florian
    * logs truncated

  Revision 1.18  2004/06/16 20:07:10  florian
    * dwarf branch merged

  Revision 1.17.2.1  2004/06/13 20:38:38  florian
    * fixed floating point register spilling on sparc

  Revision 1.17  2004/03/20 21:11:01  florian
    + float parameters can be on the stack now as well

  Revision 1.16  2004/03/20 20:55:36  florian
    + implemented cdecl'd varargs on arm
    + -dCMEM supported by the compiler
    * label/goto asmsymbol type with -dextdebug fixed

  Revision 1.15  2004/03/07 00:16:59  florian
    * compilation of arm rtl fixed

}
