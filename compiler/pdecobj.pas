{
    $Id$
    Copyright (c) 1998-2002 by Florian Klaempfl

    Does object types for Free Pascal

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
unit pdecobj;

{$i fpcdefs.inc}

interface

    uses
      globtype,symtype,symdef;

    { parses a object declaration }
    function object_dec(const n : stringid;fd : tobjectdef) : tdef;

implementation

    uses
      cutils,cclasses,
      globals,verbose,systems,tokens,
      symconst,symbase,symsym,
      node,nld,nmem,ncon,ncnv,ncal,
      scanner,
      pbase,pexpr,pdecsub,pdecvar,ptype
      ;

    const
      { Please leave this here, this module should NOT use
        these variables.
        Declaring it as string here results in an error when compiling (PFV) }
      current_procinfo = 'error';


    function object_dec(const n : stringid;fd : tobjectdef) : tdef;
    { this function parses an object or class declaration }
      var
         there_is_a_destructor : boolean;
         classtype : tobjectdeftype;
         childof : tobjectdef;
         aktclass : tobjectdef;

      function constructor_head:tprocdef;
        var
          pd : tprocdef;
        begin
           consume(_CONSTRUCTOR);
           { must be at same level as in implementation }
           parse_proc_head(aktclass,potype_constructor,pd);
           if not assigned(pd) then
             begin
               consume(_SEMICOLON);
               exit;
             end;
           if (cs_constructor_name in aktglobalswitches) and
              (pd.procsym.name<>'INIT') then
             Message(parser_e_constructorname_must_be_init);
           consume(_SEMICOLON);
           include(aktclass.objectoptions,oo_has_constructor);
           { Set return type, class constructors return the
             created instance, object constructors return boolean }
           if is_class(pd._class) then
            pd.rettype.setdef(pd._class)
           else
            pd.rettype:=booltype;
           constructor_head:=pd;
        end;


      procedure property_dec;
        var
          p : tpropertysym;
        begin
           { check for a class }
           if not((is_class_or_interface(aktclass)) or
              (not(m_tp7 in aktmodeswitches) and (is_object(aktclass)))) then
             Message(parser_e_syntax_error);
           consume(_PROPERTY);
           p:=read_property_dec(aktclass);
           consume(_SEMICOLON);
           if try_to_consume(_DEFAULT) then
             begin
               if oo_has_default_property in aktclass.objectoptions then
                 message(parser_e_only_one_default_property);
               include(aktclass.objectoptions,oo_has_default_property);
               include(p.propoptions,ppo_defaultproperty);
               if not(ppo_hasparameters in p.propoptions) then
                 message(parser_e_property_need_paras);
               consume(_SEMICOLON);
             end;
           { hint directives, these can be separated by semicolons here,
             that needs to be handled here with a loop (PFV) }
           while try_consume_hintdirective(p.symoptions) do
             Consume(_SEMICOLON);
        end;


      function destructor_head:tprocdef;
        var
          pd : tprocdef;
        begin
           consume(_DESTRUCTOR);
           parse_proc_head(aktclass,potype_destructor,pd);
           if not assigned(pd) then
             begin
               consume(_SEMICOLON);
               exit;
             end;
           if (cs_constructor_name in aktglobalswitches) and
              (pd.procsym.name<>'DONE') then
             Message(parser_e_destructorname_must_be_done);
           if not(pd.maxparacount=0) and
              (m_fpc in aktmodeswitches) then
             Message(parser_e_no_paras_for_destructor);
           consume(_SEMICOLON);
           include(aktclass.objectoptions,oo_has_destructor);
           { no return value }
           pd.rettype:=voidtype;
           destructor_head:=pd;
        end;

      var
         pcrd       : tclassrefdef;
         tt     : ttype;
         old_object_option : tsymoptions;
         oldparse_only : boolean;
         storetypecanbeforward : boolean;

      procedure setclassattributes;

        begin
           { publishable }
           if classtype in [odt_interfacecom,odt_class] then
             begin
                aktclass.objecttype:=classtype;
                if (cs_generate_rtti in aktlocalswitches) or
                    (assigned(aktclass.childof) and
                     (oo_can_have_published in aktclass.childof.objectoptions)) then
                  begin
                     include(aktclass.objectoptions,oo_can_have_published);
                     { in "publishable" classes the default access type is published }
                     current_object_option:=[sp_published];
                  end;
             end;
        end;

     procedure setclassparent;

        begin
           if assigned(fd) then
             aktclass:=fd
           else
             aktclass:=tobjectdef.create(classtype,n,nil);
           { is the current class tobject?   }
           { so you could define your own tobject }
           if (cs_compilesystem in aktmoduleswitches) and (classtype=odt_class) and (upper(n)='TOBJECT') then
             class_tobject:=aktclass
           else if (cs_compilesystem in aktmoduleswitches) and (classtype=odt_interfacecom) and (upper(n)='IUNKNOWN') then
             interface_iunknown:=aktclass
           else
             begin
                case classtype of
                  odt_class:
                    childof:=class_tobject;
                  odt_interfacecom:
                    childof:=interface_iunknown;
                end;
                if (oo_is_forward in childof.objectoptions) then
                  Message1(parser_e_forward_declaration_must_be_resolved,childof.objrealname^);
                aktclass.set_parent(childof);
             end;
         end;

      procedure setinterfacemethodoptions;

        var
          i: longint;
          defs: TIndexArray;
          pd: tdef;
        begin
          include(aktclass.objectoptions,oo_has_virtual);
          defs:=aktclass.symtable.defindex;
          for i:=1 to defs.count do
            begin
              pd:=tdef(defs.search(i));
              if pd.deftype=procdef then
                begin
                  tprocdef(pd).extnumber:=aktclass.lastvtableindex;
                  inc(aktclass.lastvtableindex);
                  include(tprocdef(pd).procoptions,po_virtualmethod);
                  tprocdef(pd).forwarddef:=false;
                end;
            end;
        end;

      function readobjecttype : boolean;

        begin
           readobjecttype:=true;
           { distinguish classes and objects }
           case token of
              _OBJECT:
                begin
                   classtype:=odt_object;
                   consume(_OBJECT)
                end;
              _CPPCLASS:
                begin
                   classtype:=odt_cppclass;
                   consume(_CPPCLASS);
                end;
              _INTERFACE:
                begin
                   { need extra check here since interface is a keyword
                     in all pascal modes }
                   if not(m_class in aktmodeswitches) then
                     Message(parser_f_need_objfpc_or_delphi_mode);
                   if aktinterfacetype=it_interfacecom then
                     classtype:=odt_interfacecom
                   else {it_interfacecorba}
                     classtype:=odt_interfacecorba;
                   consume(_INTERFACE);
                   { forward declaration }
                   if not(assigned(fd)) and (token=_SEMICOLON) then
                     begin
                       { also anonym objects aren't allow (o : object a : longint; end;) }
                       if n='' then
                         Message(parser_f_no_anonym_objects);
                       aktclass:=tobjectdef.create(classtype,n,nil);
                       if (cs_compilesystem in aktmoduleswitches) and
                          (classtype=odt_interfacecom) and (upper(n)='IUNKNOWN') then
                         interface_iunknown:=aktclass;
                       include(aktclass.objectoptions,oo_is_forward);
                       object_dec:=aktclass;
                       typecanbeforward:=storetypecanbeforward;
                       readobjecttype:=false;
                       exit;
                     end;
                end;
              _CLASS:
                begin
                   classtype:=odt_class;
                   consume(_CLASS);
                   if not(assigned(fd)) and
                      (token=_OF) and
                      { Delphi only allows class of in type blocks.
                        Note that when parsing the type of a variable declaration
                        the blocktype is bt_type so the check for typecanbeforward
                        is also necessary (PFV) }
                      (((block_type=bt_type) and typecanbeforward) or
                       not(m_delphi in aktmodeswitches)) then
                     begin
                        { a hack, but it's easy to handle }
                        { class reference type }
                        consume(_OF);
                        single_type(tt,typecanbeforward);

                        { accept hp1, if is a forward def or a class }
                        if (tt.def.deftype=forwarddef) or
                           is_class(tt.def) then
                          begin
                             pcrd:=tclassrefdef.create(tt);
                             object_dec:=pcrd;
                          end
                        else
                          begin
                             object_dec:=generrortype.def;
                             Message1(type_e_class_type_expected,generrortype.def.typename);
                          end;
                        typecanbeforward:=storetypecanbeforward;
                        readobjecttype:=false;
                        exit;
                     end
                   { forward class }
                   else if not(assigned(fd)) and (token=_SEMICOLON) then
                     begin
                        { also anonym objects aren't allow (o : object a : longint; end;) }
                        if n='' then
                          Message(parser_f_no_anonym_objects);
                        aktclass:=tobjectdef.create(odt_class,n,nil);
                        if (cs_compilesystem in aktmoduleswitches) and (upper(n)='TOBJECT') then
                          class_tobject:=aktclass;
                        aktclass.objecttype:=odt_class;
                        include(aktclass.objectoptions,oo_is_forward);
                        { all classes must have a vmt !!  at offset zero }
                        if not(oo_has_vmt in aktclass.objectoptions) then
                          aktclass.insertvmt;

                        object_dec:=aktclass;
                        typecanbeforward:=storetypecanbeforward;
                        readobjecttype:=false;
                        exit;
                     end;
                end;
              else
                begin
                   classtype:=odt_class; { this is error but try to recover }
                   consume(_OBJECT);
                end;
           end;
        end;

      procedure handleimplementedinterface(implintf : tobjectdef);

        begin
            if not is_interface(implintf) then
              begin
                 Message1(type_e_interface_type_expected,implintf.typename);
                 exit;
              end;
            if aktclass.implementedinterfaces.searchintf(implintf)<>-1 then
              Message1(sym_e_duplicate_id,implintf.name)
            else
              begin
                 { allocate and prepare the GUID only if the class
                   implements some interfaces.
                 }
                 if aktclass.implementedinterfaces.count = 0 then
                   aktclass.prepareguid;
                 aktclass.implementedinterfaces.addintf(implintf);
              end;
        end;

      procedure readimplementedinterfaces;
        var
          tt      : ttype;
        begin
          while try_to_consume(_COMMA) do
            begin
               id_type(tt,false);
               if (tt.def.deftype<>objectdef) then
                 begin
                    Message1(type_e_interface_type_expected,tt.def.typename);
                    continue;
                 end;
               handleimplementedinterface(tobjectdef(tt.def));
            end;
        end;

      procedure readinterfaceiid;
        var
          p : tnode;
          valid : boolean;
        begin
          p:=comp_expr(true);
          if p.nodetype=stringconstn then
            begin
              stringdispose(aktclass.iidstr);
              aktclass.iidstr:=stringdup(strpas(tstringconstnode(p).value_str)); { or upper? }
              p.free;
              valid:=string2guid(aktclass.iidstr^,aktclass.iidguid^);
              if (classtype=odt_interfacecom) and not assigned(aktclass.iidguid) and not valid then
                Message(parser_e_improper_guid_syntax);
            end
          else
            begin
              p.free;
              Message(parser_e_illegal_expression);
            end;
        end;


      procedure readparentclasses;
        var
           hp : tobjectdef;
        begin
           hp:=nil;
           { reads the parent class }
           if try_to_consume(_LKLAMMER) then
             begin
                id_type(tt,false);
                childof:=tobjectdef(tt.def);
                if (not assigned(childof)) or
                   (childof.deftype<>objectdef) then
                 begin
                   if assigned(childof) then
                     Message1(type_e_class_type_expected,childof.typename);
                   childof:=nil;
                   aktclass:=tobjectdef.create(classtype,n,nil);
                 end
                else
                 begin
                   { a mix of class, interfaces, objects and cppclasses
                     isn't allowed }
                   case classtype of
                      odt_class:
                        if not(is_class(childof)) then
                          begin
                             if is_interface(childof) then
                               begin
                                  { we insert the interface after the child
                                    is set, see below
                                  }
                                  hp:=childof;
                                  childof:=class_tobject;
                               end
                             else
                               Message(parser_e_mix_of_classes_and_objects);
                          end;
                      odt_interfacecorba,
                      odt_interfacecom:
                        if not(is_interface(childof)) then
                          Message(parser_e_mix_of_classes_and_objects);
                      odt_cppclass:
                        if not(is_cppclass(childof)) then
                          Message(parser_e_mix_of_classes_and_objects);
                      odt_object:
                        if not(is_object(childof)) then
                          Message(parser_e_mix_of_classes_and_objects);
                   end;
                   { the forward of the child must be resolved to get
                     correct field addresses }
                   if assigned(fd) then
                    begin
                      if (oo_is_forward in childof.objectoptions) then
                       Message1(parser_e_forward_declaration_must_be_resolved,childof.objrealname^);
                      aktclass:=fd;
                      { we must inherit several options !!
                        this was missing !!
                        all is now done in set_parent
                        including symtable datasize setting PM }
                      fd.set_parent(childof);
                    end
                   else
                    aktclass:=tobjectdef.create(classtype,n,childof);
                   if aktclass.objecttype=odt_class then
                     begin
                        if assigned(hp) then
                          handleimplementedinterface(hp);
                        readimplementedinterfaces;
                     end;
                 end;
                consume(_RKLAMMER);
             end
           { if no parent class, then a class get tobject as parent }
           else if classtype in [odt_class,odt_interfacecom] then
             setclassparent
           else
             aktclass:=tobjectdef.create(classtype,n,nil);
           { read GUID }
             if (classtype in [odt_interfacecom,odt_interfacecorba]) and
                try_to_consume(_LECKKLAMMER) then
               begin
                 readinterfaceiid;
                 consume(_RECKKLAMMER);
               end;
        end;

        procedure chkcpp(pd:tprocdef);
        begin
           if is_cppclass(pd._class) then
            begin
              pd.proccalloption:=pocall_cppdecl;
              pd.setmangledname(target_info.Cprefix+pd.cplusplusmangledname);
            end;
        end;

      var
        pd : tprocdef;
        dummysymoptions : tsymoptions;
      begin
         old_object_option:=current_object_option;

         { forward is resolved }
         if assigned(fd) then
           exclude(fd.objectoptions,oo_is_forward);

         { objects and class types can't be declared local }
         if not(symtablestack.symtabletype in [globalsymtable,staticsymtable]) then
           Message(parser_e_no_local_objects);

         storetypecanbeforward:=typecanbeforward;
         { for tp7 don't allow forward types }
         if (m_tp7 in aktmodeswitches) then
           typecanbeforward:=false;

         if not(readobjecttype) then
           exit;

         { also anonym objects aren't allow (o : object a : longint; end;) }
         if n='' then
           Message(parser_f_no_anonym_objects);

         { read list of parent classes }
         readparentclasses;

         { default access is public }
         there_is_a_destructor:=false;
         current_object_option:=[sp_public];

         { set class flags and inherits published }
         setclassattributes;

         aktobjectdef:=aktclass;
         aktclass.symtable.next:=symtablestack;
         symtablestack:=aktclass.symtable;
         testcurobject:=1;
         curobjectname:=Upper(n);

         { short class declaration ? }
         if (classtype<>odt_class) or (token<>_SEMICOLON) then
          begin
          { Parse componenten }
            repeat
              case token of
                _ID :
                  begin
                    case idtoken of
                      _PRIVATE :
                        begin
                          if is_interface(aktclass) then
                             Message(parser_e_no_access_specifier_in_interfaces);
                           consume(_PRIVATE);
                           current_object_option:=[sp_private];
                           include(aktclass.objectoptions,oo_has_private);
                         end;
                       _PROTECTED :
                         begin
                           if is_interface(aktclass) then
                             Message(parser_e_no_access_specifier_in_interfaces);
                           consume(_PROTECTED);
                           current_object_option:=[sp_protected];
                           include(aktclass.objectoptions,oo_has_protected);
                         end;
                       _PUBLIC :
                         begin
                           if is_interface(aktclass) then
                             Message(parser_e_no_access_specifier_in_interfaces);
                           consume(_PUBLIC);
                           current_object_option:=[sp_public];
                         end;
                       _PUBLISHED :
                         begin
                           { we've to check for a pushlished section in non-  }
                           { publishable classes later, if a real declaration }
                           { this is the way, delphi does it                  }
                           if is_interface(aktclass) then
                             Message(parser_e_no_access_specifier_in_interfaces);
                           consume(_PUBLISHED);
                           current_object_option:=[sp_published];
                         end;
                       else
                         begin
                           if is_interface(aktclass) then
                             Message(parser_e_no_vars_in_interfaces);

                           if (sp_published in current_object_option) and
                             not(oo_can_have_published in aktclass.objectoptions) then
                             Message(parser_e_cant_have_published);

                           read_var_decs(false,true,false);
                         end;
                    end;
                  end;
                _PROPERTY :
                  begin
                    property_dec;
                  end;
                _PROCEDURE,
                _FUNCTION,
                _CLASS :
                  begin
                    if (sp_published in current_object_option) and
                       not(oo_can_have_published in aktclass.objectoptions) then
                      Message(parser_e_cant_have_published);

                    oldparse_only:=parse_only;
                    parse_only:=true;
                    pd:=parse_proc_dec(aktclass);

                    { this is for error recovery as well as forward }
                    { interface mappings, i.e. mapping to a method  }
                    { which isn't declared yet                      }
                    if assigned(pd) then
                     begin
                       parse_object_proc_directives(pd);
                       handle_calling_convention(pd);

                       { add definition to procsym }
                       proc_add_definition(pd);

                       { add procdef options to objectdef options }
                       if (po_msgint in pd.procoptions) then
                        include(aktclass.objectoptions,oo_has_msgint);
                       if (po_msgstr in pd.procoptions) then
                         include(aktclass.objectoptions,oo_has_msgstr);
                       if (po_virtualmethod in pd.procoptions) then
                         include(aktclass.objectoptions,oo_has_virtual);

                       chkcpp(pd);
                     end;

                    { Support hint directives }
                    dummysymoptions:=[];
                    while try_consume_hintdirective(dummysymoptions) do
                      Consume(_SEMICOLON);
                    if assigned(pd) then
                      pd.symoptions:=pd.symoptions+dummysymoptions;

                    parse_only:=oldparse_only;
                  end;
                _CONSTRUCTOR :
                  begin
                    if (sp_published in current_object_option) and
                      not(oo_can_have_published in aktclass.objectoptions) then
                      Message(parser_e_cant_have_published);

                    if not(sp_public in current_object_option) and
                       not(sp_published in current_object_option) then
                      Message(parser_w_constructor_should_be_public);

                    if is_interface(aktclass) then
                      Message(parser_e_no_con_des_in_interfaces);

                    oldparse_only:=parse_only;
                    parse_only:=true;
                    pd:=constructor_head;
                    parse_object_proc_directives(pd);
                    handle_calling_convention(pd);

                    { add definition to procsym }
                    proc_add_definition(pd);

                    { add procdef options to objectdef options }
                    if (po_virtualmethod in pd.procoptions) then
                      include(aktclass.objectoptions,oo_has_virtual);
                    chkcpp(pd);

                    { Support hint directives }
                    dummysymoptions:=[];
                    while try_consume_hintdirective(dummysymoptions) do
                      Consume(_SEMICOLON);
                    if assigned(pd) then
                      pd.symoptions:=pd.symoptions+dummysymoptions;

                    parse_only:=oldparse_only;
                  end;
                _DESTRUCTOR :
                  begin
                    if (sp_published in current_object_option) and
                      not(oo_can_have_published in aktclass.objectoptions) then
                      Message(parser_e_cant_have_published);

                    if there_is_a_destructor then
                      Message(parser_n_only_one_destructor);

                    if is_interface(aktclass) then
                      Message(parser_e_no_con_des_in_interfaces);

                    if not(sp_public in current_object_option) then
                      Message(parser_w_destructor_should_be_public);

                    there_is_a_destructor:=true;
                    oldparse_only:=parse_only;
                    parse_only:=true;
                    pd:=destructor_head;
                    parse_object_proc_directives(pd);
                    handle_calling_convention(pd);

                    { add definition to procsym }
                    proc_add_definition(pd);

                    { add procdef options to objectdef options }
                    if (po_virtualmethod in pd.procoptions) then
                      include(aktclass.objectoptions,oo_has_virtual);

                    chkcpp(pd);

                    { Support hint directives }
                    dummysymoptions:=[];
                    while try_consume_hintdirective(dummysymoptions) do
                      Consume(_SEMICOLON);
                    if assigned(pd) then
                      pd.symoptions:=pd.symoptions+dummysymoptions;

                    parse_only:=oldparse_only;
                  end;
                _END :
                  begin
                    consume(_END);
                    break;
                  end;
                else
                  consume(_ID); { Give a ident expected message, like tp7 }
              end;
            until false;
          end;

         { generate vmt space if needed }
         if not(oo_has_vmt in aktclass.objectoptions) and
            (([oo_has_virtual,oo_has_constructor,oo_has_destructor]*aktclass.objectoptions<>[]) or
             (classtype in [odt_class])
            ) then
           aktclass.insertvmt;

         if is_interface(aktclass) then
           setinterfacemethodoptions;

         { reset }
         testcurobject:=0;
         curobjectname:='';
         typecanbeforward:=storetypecanbeforward;
         { restore old state }
         symtablestack:=symtablestack.next;
         aktobjectdef:=nil;
         current_object_option:=old_object_option;

         object_dec:=aktclass;
      end;

end.
{
  $Log$
  Revision 1.87  2005-03-16 21:09:22  peter
    * allow property in objects in all modes except tp

  Revision 1.86  2005/02/14 17:13:07  peter
    * truncate log

  Revision 1.85  2005/02/01 08:46:13  michael
   * Patch from peter: fix macpas anonymous function procvar

}
