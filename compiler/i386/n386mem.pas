{
    $Id$
    Copyright (c) 1998-2000 by Florian Klaempfl

    Generate i386 assembler for in memory related nodes

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
unit n386mem;

{$i defines.inc}

interface

    uses
      node,nmem;

    type
       ti386loadvmtnode = class(tloadvmtnode)
          procedure pass_2;override;
       end;

       ti386hnewnode = class(thnewnode)
          procedure pass_2;override;
       end;

       ti386newnode = class(tnewnode)
          procedure pass_2;override;
       end;

       ti386hdisposenode = class(thdisposenode)
          procedure pass_2;override;
       end;

       ti386simplenewdisposenode = class(tsimplenewdisposenode)
          procedure pass_2;override;
       end;

       ti386addrnode = class(taddrnode)
          procedure pass_2;override;
       end;

       ti386doubleaddrnode = class(tdoubleaddrnode)
          procedure pass_2;override;
       end;

       ti386derefnode = class(tderefnode)
          procedure pass_2;override;
       end;

       ti386subscriptnode = class(tsubscriptnode)
          procedure pass_2;override;
       end;

       ti386vecnode = class(tvecnode)
          procedure pass_2;override;
       end;

       ti386selfnode = class(tselfnode)
          procedure pass_2;override;
       end;

       ti386withnode = class(twithnode)
          procedure pass_2;override;
       end;

implementation

    uses
{$ifdef delphi}
      sysutils,
{$else}
      strings,
{$endif}
{$ifdef GDB}
      gdb,
{$endif GDB}
      globtype,systems,
      cutils,cobjects,verbose,globals,
      symconst,symbase,symdef,symsym,symtable,aasm,types,
      hcodegen,temp_gen,pass_2,
      pass_1,nld,ncon,nadd,
      cpubase,cpuasm,
      cgai386,tgeni386,n386util;

{*****************************************************************************
                            TI386LOADNODE
*****************************************************************************}

    procedure ti386loadvmtnode.pass_2;
      begin
         location.register:=getregister32;
         emit_sym_ofs_reg(A_MOV,
            S_L,newasmsymbol(pobjectdef(pclassrefdef(resulttype)^.pointertype.def)^.vmt_mangledname),0,
            location.register);
      end;


{*****************************************************************************
                            TI386HNEWNODE
*****************************************************************************}

    procedure ti386hnewnode.pass_2;
      begin
      end;


{*****************************************************************************
                            TI386NEWNODE
*****************************************************************************}

    procedure ti386newnode.pass_2;
      var
         pushed : tpushed;
         r : preference;
      begin
         if assigned(left) then
           begin
              secondpass(left);
              location.register:=left.location.register;
           end
         else
           begin
              pushusedregisters(pushed,$ff);

              gettempofsizereference(target_os.size_of_pointer,location.reference);

              { determines the size of the mem block }
              push_int(ppointerdef(resulttype)^.pointertype.def^.size);
              emit_push_lea_loc(location,false);
              emitcall('FPC_GETMEM');

              if ppointerdef(resulttype)^.pointertype.def^.needs_inittable then
                begin
                   new(r);
                   reset_reference(r^);
                   r^.symbol:=pstoreddef(ppointerdef(left.resulttype)^.pointertype.def)^.get_inittable_label;
                   emitpushreferenceaddr(r^);
                   dispose(r);
                   { push pointer we just allocated, we need to initialize the
                     data located at that pointer not the pointer self (PFV) }
                   emit_push_loc(location);
                   emitcall('FPC_INITIALIZE');
                end;
              popusedregisters(pushed);
              { may be load ESI }
              maybe_loadesi;
           end;
         if codegenerror then
           exit;
      end;


{*****************************************************************************
                         TI386HDISPOSENODE
*****************************************************************************}

    procedure ti386hdisposenode.pass_2;
      begin
         secondpass(left);
         if codegenerror then
           exit;
         reset_reference(location.reference);
         case left.location.loc of
            LOC_REGISTER:
              location.reference.index:=left.location.register;
            LOC_CREGISTER:
              begin
                 location.reference.index:=getregister32;
                 emit_reg_reg(A_MOV,S_L,
                   left.location.register,
                   location.reference.index);
              end;
            LOC_MEM,LOC_REFERENCE :
              begin
                 del_reference(left.location.reference);
                 location.reference.index:=getregister32;
                 emit_ref_reg(A_MOV,S_L,newreference(left.location.reference),
                   location.reference.index);
              end;
         end;
      end;


{*****************************************************************************
                         TI386SIMPLENEWDISPOSENODE
*****************************************************************************}

    procedure ti386simplenewdisposenode.pass_2;

      var
         pushed : tpushed;
         r : preference;

      begin
         secondpass(left);
         if codegenerror then
           exit;

         pushusedregisters(pushed,$ff);

         { call the mem handling procedures }
         case nodetype of
           simpledisposen:
             begin
                if ppointerdef(left.resulttype)^.pointertype.def^.needs_inittable then
                  begin
                     new(r);
                     reset_reference(r^);
                     r^.symbol:=pstoreddef(ppointerdef(left.resulttype)^.pointertype.def)^.get_inittable_label;
                     emitpushreferenceaddr(r^);
                     dispose(r);
                     { push pointer adress }
                     emit_push_loc(left.location);
                     emitcall('FPC_FINALIZE');
                  end;
                emit_push_lea_loc(left.location,true);
                emitcall('FPC_FREEMEM');
             end;
           simplenewn:
             begin
                { determines the size of the mem block }
                push_int(ppointerdef(left.resulttype)^.pointertype.def^.size);
                emit_push_lea_loc(left.location,true);
                emitcall('FPC_GETMEM');
                if ppointerdef(left.resulttype)^.pointertype.def^.needs_inittable then
                  begin
                     new(r);
                     reset_reference(r^);
                     r^.symbol:=pstoreddef(ppointerdef(left.resulttype)^.pointertype.def)^.get_inittable_label;
                     emitpushreferenceaddr(r^);
                     dispose(r);
                     emit_push_loc(left.location);
                     emitcall('FPC_INITIALIZE');
                  end;
             end;
         end;
         popusedregisters(pushed);
         { may be load ESI }
         maybe_loadesi;
      end;


{*****************************************************************************
                             TI386ADDRNODE
*****************************************************************************}

    procedure ti386addrnode.pass_2;
      begin
         secondpass(left);

         { when loading procvar we do nothing with this node, so load the
           location of left }
         if nf_procvarload in flags then
          begin
            set_location(location,left.location);
            exit;
          end;

         location.loc:=LOC_REGISTER;
         del_reference(left.location.reference);
         location.register:=getregister32;
         {@ on a procvar means returning an address to the procedure that
           is stored in it.}
         { yes but left.symtableentry can be nil
           for example on @self !! }
         { symtableentry can be also invalid, if left is no tree node }
         if (m_tp_procvar in aktmodeswitches) and
           (left.nodetype=loadn) and
           assigned(tloadnode(left).symtableentry) and
           (tloadnode(left).symtableentry^.typ=varsym) and
           (pvarsym(tloadnode(left).symtableentry)^.vartype.def^.deftype=procvardef) then
           emit_ref_reg(A_MOV,S_L,
             newreference(left.location.reference),
             location.register)
         else
           emit_ref_reg(A_LEA,S_L,
             newreference(left.location.reference),
             location.register);
           { for use of other segments }
           if left.location.reference.segment<>R_NO then
             location.segment:=left.location.reference.segment;
      end;


{*****************************************************************************
                         TI386DOUBLEADDRNODE
*****************************************************************************}

    procedure ti386doubleaddrnode.pass_2;
      begin
         secondpass(left);
         location.loc:=LOC_REGISTER;
         del_reference(left.location.reference);
         location.register:=getregister32;
         emit_ref_reg(A_LEA,S_L,
         newreference(left.location.reference),
           location.register);
      end;


{*****************************************************************************
                           TI386DEREFNODE
*****************************************************************************}

    procedure ti386derefnode.pass_2;
      var
         hr : tregister;
      begin
         secondpass(left);
         reset_reference(location.reference);
         case left.location.loc of
            LOC_REGISTER:
              location.reference.base:=left.location.register;
            LOC_CREGISTER:
              begin
                 { ... and reserve one for the pointer }
                 hr:=getregister32;
                 emit_reg_reg(A_MOV,S_L,left.location.register,hr);
                 location.reference.base:=hr;
              end;
            else
              begin
                 { free register }
                 del_reference(left.location.reference);

                 { ...and reserve one for the pointer }
                 hr:=getregister32;
                 emit_ref_reg(
                   A_MOV,S_L,newreference(left.location.reference),
                   hr);
                 location.reference.base:=hr;
              end;
         end;
         if ppointerdef(left.resulttype)^.is_far then
          location.reference.segment:=R_FS;
         if not ppointerdef(left.resulttype)^.is_far and
            (cs_gdb_heaptrc in aktglobalswitches) and
            (cs_checkpointer in aktglobalswitches) then
              begin
                 emit_reg(
                   A_PUSH,S_L,location.reference.base);
                 emitcall('FPC_CHECKPOINTER');
              end;
      end;


{*****************************************************************************
                          TI386SUBSCRIPTNODE
*****************************************************************************}

    procedure ti386subscriptnode.pass_2;
      var
         hr : tregister;
      begin
         secondpass(left);
         if codegenerror then
           exit;
         { classes must be dereferenced implicit }
         if (left.resulttype^.deftype=objectdef) and
           pobjectdef(left.resulttype)^.is_class then
           begin
             reset_reference(location.reference);
             case left.location.loc of
                LOC_REGISTER:
                  location.reference.base:=left.location.register;
                LOC_CREGISTER:
                  begin
                     { ... and reserve one for the pointer }
                     hr:=getregister32;
                     emit_reg_reg(A_MOV,S_L,left.location.register,hr);
                       location.reference.base:=hr;
                  end;
                else
                  begin
                     { free register }
                     del_reference(left.location.reference);

                     { ... and reserve one for the pointer }
                     hr:=getregister32;
                     emit_ref_reg(
                       A_MOV,S_L,newreference(left.location.reference),
                       hr);
                     location.reference.base:=hr;
                  end;
             end;
           end
         else
           set_location(location,left.location);

         inc(location.reference.offset,vs^.address);
      end;


{*****************************************************************************
                             TI386VECNODE
*****************************************************************************}

    procedure ti386vecnode.pass_2;
      var
        is_pushed : boolean;
        ind,hr : tregister;
        //_p : tnode;

          function get_mul_size:longint;
          begin
            if nf_memindex in flags then
             get_mul_size:=1
            else
             begin
               if (left.resulttype^.deftype=arraydef) then
                get_mul_size:=parraydef(left.resulttype)^.elesize
               else
                get_mul_size:=resulttype^.size;
             end
          end;

          procedure calc_emit_mul;
          var
             l1,l2 : longint;
          begin
            l1:=get_mul_size;
            case l1 of
             1,2,4,8 : location.reference.scalefactor:=l1;
            else
              begin
                 if ispowerof2(l1,l2) then
                   emit_const_reg(A_SHL,S_L,l2,ind)
                 else
                   emit_const_reg(A_IMUL,S_L,l1,ind);
              end;
            end;
          end;

      var
         extraoffset : longint;
         { rl stores the resulttype of the left node, this is necessary }
         { to detect if it is an ansistring                          }
         { because in constant nodes which constant index              }
         { the left tree is removed                                  }
         t   : tnode;
         hp  : preference;
         href : treference;
         tai : Paicpu;
         pushed : tpushed;
         hightree : tnode;
         hl,otl,ofl : pasmlabel;
      begin
         secondpass(left);
         { we load the array reference to location }

         { an ansistring needs to be dereferenced }
         if is_ansistring(left.resulttype) or
           is_widestring(left.resulttype) then
           begin
              reset_reference(location.reference);
              if nf_callunique in flags then
                begin
                   if left.location.loc<>LOC_REFERENCE then
                     begin
                        CGMessage(cg_e_illegal_expression);
                        exit;
                     end;
                   pushusedregisters(pushed,$ff);
                   emitpushreferenceaddr(left.location.reference);
                   if is_ansistring(left.resulttype) then
                     emitcall('FPC_ANSISTR_UNIQUE')
                   else
                     emitcall('FPC_WIDESTR_UNIQUE');
                   maybe_loadesi;
                   popusedregisters(pushed);
                end;

              if left.location.loc in [LOC_REGISTER,LOC_CREGISTER] then
                begin
                   location.reference.base:=left.location.register;
                end
              else
                begin
                   del_reference(left.location.reference);
                   location.reference.base:=getregister32;
                   emit_ref_reg(A_MOV,S_L,
                     newreference(left.location.reference),
                     location.reference.base);
                end;

              { check for a zero length string,
                we can use the ansistring routine here }
              if (cs_check_range in aktlocalswitches) then
                begin
                   pushusedregisters(pushed,$ff);
                   emit_reg(A_PUSH,S_L,location.reference.base);
                   emitcall('FPC_ANSISTR_CHECKZERO');
                   maybe_loadesi;
                   popusedregisters(pushed);
                end;

              if is_ansistring(left.resulttype) then
                { in ansistrings S[1] is pchar(S)[0] !! }
                dec(location.reference.offset)
              else
                begin
                   { in widestrings S[1] is pwchar(S)[0] !! }
                   dec(location.reference.offset,2);
                   emit_const_reg(A_SHL,S_L,
                     1,location.reference.base);
                end;

              { we've also to keep left up-to-date, because it is used   }
              { if a constant array index occurs, subject to change (FK) }
              set_location(left.location,location);
           end
         else if is_dynamic_array(left.resulttype) then
         { ... also a dynamic string }
           begin
              reset_reference(location.reference);

              if left.location.loc in [LOC_REGISTER,LOC_CREGISTER] then
                begin
                   location.reference.base:=left.location.register;
                end
              else
                begin
                   del_reference(left.location.reference);
                   location.reference.base:=getregister32;
                   emit_ref_reg(A_MOV,S_L,
                     newreference(left.location.reference),
                     location.reference.base);
                end;
{$warning FIXME}
              { check for a zero length string,
                we can use the ansistring routine here }
              if (cs_check_range in aktlocalswitches) then
                begin
                   pushusedregisters(pushed,$ff);
                   emit_reg(A_PUSH,S_L,location.reference.base);
                   emitcall('FPC_ANSISTR_CHECKZERO');
                   maybe_loadesi;
                   popusedregisters(pushed);
                end;

              { we've also to keep left up-to-date, because it is used   }
              { if a constant array index occurs, subject to change (FK) }
              set_location(left.location,location);
           end
         else
           set_location(location,left.location);

         { offset can only differ from 0 if arraydef }
         if (left.resulttype^.deftype=arraydef) and
           not(is_dynamic_array(left.resulttype)) then
           dec(location.reference.offset,
               get_mul_size*parraydef(left.resulttype)^.lowrange);
         if right.nodetype=ordconstn then
           begin
              { offset can only differ from 0 if arraydef }
              if (left.resulttype^.deftype=arraydef) then
                begin
                   if not(is_open_array(left.resulttype)) and
                      not(is_array_of_const(left.resulttype)) and
                      not(is_dynamic_array(left.resulttype)) then
                     begin
                        if (tordconstnode(right).value>parraydef(left.resulttype)^.highrange) or
                           (tordconstnode(right).value<parraydef(left.resulttype)^.lowrange) then
                           begin
                              if (cs_check_range in aktlocalswitches) then
                                CGMessage(parser_e_range_check_error)
                              else
                                CGMessage(parser_w_range_check_error);
                           end;
                        dec(left.location.reference.offset,
                            get_mul_size*parraydef(left.resulttype)^.lowrange);
                     end
                   else
                     begin
                        { range checking for open and dynamic arrays !!!! }
{$warning FIXME}
                        {!!!!!!!!!!!!!!!!!}
                     end;
                end
              else if (left.resulttype^.deftype=stringdef) then
                begin
                   if (tordconstnode(right).value=0) and not(is_shortstring(left.resulttype)) then
                     CGMessage(cg_e_can_access_element_zero);

                   if (cs_check_range in aktlocalswitches) then
                     case pstringdef(left.resulttype)^.string_typ of
                        { it's the same for ansi- and wide strings }
                        st_widestring,
                        st_ansistring:
                          begin
                             pushusedregisters(pushed,$ff);
                             push_int(tordconstnode(right).value);
                             hp:=newreference(location.reference);
                             dec(hp^.offset,7);
                             emit_ref(A_PUSH,S_L,hp);
                             emitcall('FPC_ANSISTR_RANGECHECK');
                             popusedregisters(pushed);
                             maybe_loadesi;
                          end;

                        st_shortstring:
                          begin
                             {!!!!!!!!!!!!!!!!!}
                          end;

                        st_longstring:
                          begin
                             {!!!!!!!!!!!!!!!!!}
                          end;
                     end;
                end;
              inc(left.location.reference.offset,
                  get_mul_size*tordconstnode(right).value);
              if nf_memseg in flags then
                left.location.reference.segment:=R_FS;
              {
              left.resulttype:=resulttype;
              disposetree(right);
              _p:=left;
              putnode(p);
              p:=_p;
              }
              set_location(location,left.location);
           end
         else
         { not nodetype=ordconstn }
           begin
              if (cs_regalloc in aktglobalswitches) and
              { if we do range checking, we don't }
              { need that fancy code (it would be }
              { buggy)                            }
                not(cs_check_range in aktlocalswitches) and
                (left.resulttype^.deftype=arraydef) then
                begin
                   extraoffset:=0;
                   if (right.nodetype=addn) then
                     begin
                        if taddnode(right).right.nodetype=ordconstn then
                          begin
                             extraoffset:=tordconstnode(taddnode(right).right).value;
                             t:=taddnode(right).left;
                             { First pass processed this with the assumption   }
                             { that there was an add node which may require an }
                             { extra register. Fake it or die with IE10 (JM)   }
                             t.registers32 := taddnode(right).registers32;
                             taddnode(right).left:=nil;
                             right.free;
                             right:=t;
                          end
                        else if tordconstnode(taddnode(right).left).nodetype=ordconstn then
                          begin
                             extraoffset:=tordconstnode(taddnode(right).left).value;
                             t:=taddnode(right).right;
                             t.registers32 :=  right.registers32;
                             taddnode(right).right:=nil;
                             right.free;
                             right:=t;
                          end;
                     end
                   else if (right.nodetype=subn) then
                     begin
                        if taddnode(right).right.nodetype=ordconstn then
                          begin
{ this was "extraoffset:=right.right.value;" Looks a bit like
  copy-paste bug :) (JM) }
                             extraoffset:=-tordconstnode(taddnode(right).right).value;
                             t:=taddnode(right).left;
                             t.registers32 :=  right.registers32;
                             taddnode(right).left:=nil;
                             right.free;
                             right:=t;
                          end
{ You also have to negate right.right in this case! I can't add an
  unaryminusn without causing a crash, so I've disabled it (JM)
                        else if right.left.nodetype=ordconstn then
                          begin
                             extraoffset:=right.left.value;
                             t:=right.right;
                             t^.registers32 :=  right.registers32;
                             putnode(right);
                             putnode(right.left);
                             right:=t;
                         end;}
                     end;
                   inc(location.reference.offset,
                       get_mul_size*extraoffset);
                end;
              { calculate from left to right }
              if (location.loc<>LOC_REFERENCE) and
                 (location.loc<>LOC_MEM) then
                CGMessage(cg_e_illegal_expression);
              if (right.location.loc=LOC_JUMP) then
               begin
                 otl:=truelabel;
                 getlabel(truelabel);
                 ofl:=falselabel;
                 getlabel(falselabel);
               end;
              is_pushed:=maybe_push(right.registers32,self,false);
              secondpass(right);
              if is_pushed then
                restore(self,false);
              { here we change the location of right
                and the update was forgotten so it
                led to wrong code in emitrangecheck later PM
                so make range check before }

              if cs_check_range in aktlocalswitches then
               begin
                 if left.resulttype^.deftype=arraydef then
                   begin
                     if is_open_array(left.resulttype) or
                        is_array_of_const(left.resulttype) then
                      begin
                        reset_reference(href);
                        parraydef(left.resulttype)^.genrangecheck;
                        href.symbol:=newasmsymbol(parraydef(left.resulttype)^.getrangecheckstring);
                        href.offset:=4;
                        getsymonlyin(tloadnode(left).symtable,
                          'high'+pvarsym(tloadnode(left).symtableentry)^.name);
                        hightree:=genloadnode(pvarsym(srsym),tloadnode(left).symtable);
                        firstpass(hightree);
                        secondpass(hightree);
                        emit_mov_loc_ref(hightree.location,href,S_L,true);
                        hightree.free;
                        hightree:=nil;
                      end;
                     emitrangecheck(right,left.resulttype);
                   end;
               end;

              case right.location.loc of
                 LOC_REGISTER:
                   begin
                      ind:=right.location.register;
                      case right.resulttype^.size of
                         1:
                           begin
                              hr:=reg8toreg32(ind);
                              emit_reg_reg(A_MOVZX,S_BL,ind,hr);
                              ind:=hr;
                           end;
                         2:
                           begin
                              hr:=reg16toreg32(ind);
                              emit_reg_reg(A_MOVZX,S_WL,ind,hr);
                              ind:=hr;
                           end;
                      end;
                   end;
                 LOC_CREGISTER:
                   begin
                      ind:=getregister32;
                      case right.resulttype^.size of
                         1:
                           emit_reg_reg(A_MOVZX,S_BL,right.location.register,ind);
                         2:
                           emit_reg_reg(A_MOVZX,S_WL,right.location.register,ind);
                         4:
                           emit_reg_reg(A_MOV,S_L,right.location.register,ind);
                      end;
                   end;
                 LOC_FLAGS:
                   begin
                      ind:=getregister32;
                      emit_flag2reg(right.location.resflags,reg32toreg8(ind));
                      emit_reg_reg(A_MOVZX,S_BL,reg32toreg8(ind),ind);
                   end;
                 LOC_JUMP :
                   begin
                     ind:=getregister32;
                     emitlab(truelabel);
                     truelabel:=otl;
                     emit_const_reg(A_MOV,S_L,1,ind);
                     getlabel(hl);
                     emitjmp(C_None,hl);
                     emitlab(falselabel);
                     falselabel:=ofl;
                     emit_reg_reg(A_XOR,S_L,ind,ind);
                     emitlab(hl);
                   end;
                 LOC_REFERENCE,LOC_MEM :
                   begin
                      del_reference(right.location.reference);
                      ind:=getregister32;
                      { Booleans are stored in an 8 bit memory location, so
                        the use of MOVL is not correct }
                      case right.resulttype^.size of
                       1 : tai:=new(paicpu,op_ref_reg(A_MOVZX,S_BL,newreference(right.location.reference),ind));
                       2 : tai:=new(Paicpu,op_ref_reg(A_MOVZX,S_WL,newreference(right.location.reference),ind));
                       4 : tai:=new(Paicpu,op_ref_reg(A_MOV,S_L,newreference(right.location.reference),ind));
                      end;
                      exprasmlist^.concat(tai);
                   end;
                 else
                   internalerror(5913428);
                end;

            { produce possible range check code: }
              if cs_check_range in aktlocalswitches then
               begin
                 if left.resulttype^.deftype=arraydef then
                   begin
                     { done defore (PM) }
                   end
                 else if (left.resulttype^.deftype=stringdef) then
                   begin
                      case pstringdef(left.resulttype)^.string_typ of
                         { it's the same for ansi- and wide strings }
                         st_widestring,
                         st_ansistring:
                           begin
                              pushusedregisters(pushed,$ff);
                              emit_reg(A_PUSH,S_L,ind);
                              hp:=newreference(location.reference);
                              dec(hp^.offset,7);
                              emit_ref(A_PUSH,S_L,hp);
                              emitcall('FPC_ANSISTR_RANGECHECK');
                              popusedregisters(pushed);
                              maybe_loadesi;
                           end;
                         st_shortstring:
                           begin
                              {!!!!!!!!!!!!!!!!!}
                           end;
                         st_longstring:
                           begin
                              {!!!!!!!!!!!!!!!!!}
                           end;
                      end;
                   end;
               end;

              if location.reference.index=R_NO then
               begin
                 location.reference.index:=ind;
                 calc_emit_mul;
               end
              else
               begin
                 if location.reference.base=R_NO then
                  begin
                    case location.reference.scalefactor of
                     2 : emit_const_reg(A_SHL,S_L,1,location.reference.index);
                     4 : emit_const_reg(A_SHL,S_L,2,location.reference.index);
                     8 : emit_const_reg(A_SHL,S_L,3,location.reference.index);
                    end;
                    calc_emit_mul;
                    location.reference.base:=location.reference.index;
                    location.reference.index:=ind;
                  end
                 else
                  begin
                    emit_ref_reg(
                      A_LEA,S_L,newreference(location.reference),
                      location.reference.index);
                    ungetregister32(location.reference.base);
                    { the symbol offset is loaded,             }
                    { so release the symbol name and set symbol  }
                    { to nil                                 }
                    location.reference.symbol:=nil;
                    location.reference.offset:=0;
                    calc_emit_mul;
                    location.reference.base:=location.reference.index;
                    location.reference.index:=ind;
                  end;
               end;

              if nf_memseg in flags then
                location.reference.segment:=R_FS;
           end;
      end;

{*****************************************************************************
                            TI386SELFNODE
*****************************************************************************}

    procedure ti386selfnode.pass_2;
      begin
         reset_reference(location.reference);
         getexplicitregister32(R_ESI);
         if (resulttype^.deftype=classrefdef) or
           ((resulttype^.deftype=objectdef)
             and pobjectdef(resulttype)^.is_class
           ) then
           location.register:=R_ESI
         else
           location.reference.base:=R_ESI;
      end;


{*****************************************************************************
                            TI386WITHNODE
*****************************************************************************}

    procedure ti386withnode.pass_2;
      var
        usetemp,with_expr_in_temp : boolean;
{$ifdef GDB}
        withstartlabel,withendlabel : pasmlabel;
        pp : pchar;
        mangled_length  : longint;

      const
        withlevel : longint = 0;
{$endif GDB}
      begin
         if assigned(left) then
            begin
               secondpass(left);
               if left.location.reference.segment<>R_NO then
                 message(parser_e_no_with_for_variable_in_other_segments);

               new(withreference);

               usetemp:=false;
               if (left.nodetype=loadn) and
                  (tloadnode(left).symtable=aktprocsym^.definition^.localst) then
                 begin
                    { for locals use the local storage }
                    withreference^:=left.location.reference;
                    include(flags,nf_islocal);
                 end
               else
                { call can have happend with a property }
                if (left.resulttype^.deftype=objectdef) and
                   pobjectdef(left.resulttype)^.is_class then
                 begin
{$ifndef noAllocEdi}
                    getexplicitregister32(R_EDI);
{$endif noAllocEdi}
                    emit_mov_loc_reg(left.location,R_EDI);
                    usetemp:=true;
                 end
               else
                 begin
{$ifndef noAllocEdi}
                   getexplicitregister32(R_EDI);
{$endif noAllocEdi}
                   emit_lea_loc_reg(left.location,R_EDI,false);
                   usetemp:=true;
                 end;

               release_loc(left.location);

               { if the with expression is stored in a temp    }
               { area we must make it persistent and shouldn't }
               { release it (FK)                               }
               if (left.location.loc in [LOC_MEM,LOC_REFERENCE]) and
                 istemp(left.location.reference) then
                 begin
                    normaltemptopersistant(left.location.reference.offset);
                    with_expr_in_temp:=true;
                 end
               else
                 with_expr_in_temp:=false;

               { if usetemp is set the value must be in %edi }
               if usetemp then
                begin
                  gettempofsizereference(4,withreference^);
                  normaltemptopersistant(withreference^.offset);
                  { move to temp reference }
                  emit_reg_ref(A_MOV,S_L,R_EDI,newreference(withreference^));
{$ifndef noAllocEdi}
                  ungetregister32(R_EDI);
{$endif noAllocEdi}
{$ifdef GDB}
                  if (cs_debuginfo in aktmoduleswitches) then
                    begin
                      inc(withlevel);
                      getaddrlabel(withstartlabel);
                      getaddrlabel(withendlabel);
                      emitlab(withstartlabel);
                      withdebuglist^.concat(new(pai_stabs,init(strpnew(
                         '"with'+tostr(withlevel)+':'+tostr(symtablestack^.getnewtypecount)+
                         '=*'+pstoreddef(left.resulttype)^.numberstring+'",'+
                         tostr(N_LSYM)+',0,0,'+tostr(withreference^.offset)))));
                      mangled_length:=length(aktprocsym^.definition^.mangledname);
                      getmem(pp,mangled_length+50);
                      strpcopy(pp,'192,0,0,'+withstartlabel^.name);
                      if (target_os.use_function_relative_addresses) then
                        begin
                          strpcopy(strend(pp),'-');
                          strpcopy(strend(pp),aktprocsym^.definition^.mangledname);
                        end;
                      withdebuglist^.concat(new(pai_stabn,init(strnew(pp))));
                    end;
{$endif GDB}
                end;

               { right can be optimize out !!! }
               if assigned(right) then
                 secondpass(right);

               if usetemp then
                 begin
                   ungetpersistanttemp(withreference^.offset);
{$ifdef GDB}
                   if (cs_debuginfo in aktmoduleswitches) then
                     begin
                       emitlab(withendlabel);
                       strpcopy(pp,'224,0,0,'+withendlabel^.name);
                      if (target_os.use_function_relative_addresses) then
                        begin
                          strpcopy(strend(pp),'-');
                          strpcopy(strend(pp),aktprocsym^.definition^.mangledname);
                        end;
                       withdebuglist^.concat(new(pai_stabn,init(strnew(pp))));
                       freemem(pp,mangled_length+50);
                       dec(withlevel);
                     end;
{$endif GDB}
                 end;

               if with_expr_in_temp then
                 ungetpersistanttemp(left.location.reference.offset);

               dispose(withreference);
               withreference:=nil;
            end;
       end;

begin
   cloadvmtnode:=ti386loadvmtnode;
   chnewnode:=ti386hnewnode;
   cnewnode:=ti386newnode;
   chdisposenode:=ti386hdisposenode;
   csimplenewdisposenode:=ti386simplenewdisposenode;
   caddrnode:=ti386addrnode;
   cdoubleaddrnode:=ti386doubleaddrnode;
   cderefnode:=ti386derefnode;
   csubscriptnode:=ti386subscriptnode;
   cvecnode:=ti386vecnode;
   cselfnode:=ti386selfnode;
   cwithnode:=ti386withnode;
end.
{
  $Log$
  Revision 1.4  2000-10-31 22:02:57  peter
    * symtable splitted, no real code changes

  Revision 1.3  2000/10/31 14:18:53  jonas
    * merged double deleting of left location when using a temp in
      secondwith (merged from fixes branch). This also fixes web bug1194

  Revision 1.2  2000/10/21 18:16:13  florian
    * a lot of changes:
       - basic dyn. array support
       - basic C++ support
       - some work for interfaces done
       ....

  Revision 1.1  2000/10/15 09:33:32  peter
    * moved n386*.pas to i386/ cpu_target dir

  Revision 1.2  2000/10/14 21:52:54  peter
    * fixed memory leaks

  Revision 1.1  2000/10/14 10:14:49  peter
    * moehrendorf oct 2000 rewrite

}