{
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit handles the typecheck and node conversion pass

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
unit pass_1;

{$i fpcdefs.inc}

interface

    uses
       node;

    procedure resulttypepass(var p : tnode);
    function  do_resulttypepass(var p : tnode) : boolean;

    procedure firstpass(var p : tnode);
    function  do_firstpass(var p : tnode) : boolean;
{$ifdef state_tracking}
    procedure  do_track_state_pass(p:Tnode);
{$endif}


implementation

    uses
      globtype,systems,cclasses,
      cutils,globals,
      procinfo,
      cgbase,symdef
{$ifdef extdebug}
      ,verbose,htypechk
{$endif extdebug}
{$ifdef state_tracking}
      ,nstate
{$endif}
      ;

{*****************************************************************************
                            Global procedures
*****************************************************************************}

    procedure resulttypepass(var p : tnode);
      var
         oldcodegenerror  : boolean;
         oldlocalswitches : tlocalswitches;
         oldpos    : tfileposinfo;
         hp        : tnode;
      begin
        if (p.resulttype.def=nil) then
         begin
           oldcodegenerror:=codegenerror;
           oldpos:=aktfilepos;
           oldlocalswitches:=aktlocalswitches;
           codegenerror:=false;
           aktfilepos:=p.fileinfo;
           aktlocalswitches:=p.localswitches;
           hp:=p.det_resulttype;
           { should the node be replaced? }
           if assigned(hp) then
            begin
               p.free;
               { run resulttypepass }
               resulttypepass(hp);
               { switch to new node }
               p:=hp;
            end;
           aktlocalswitches:=oldlocalswitches;
           aktfilepos:=oldpos;
           if codegenerror then
            begin
              include(p.flags,nf_error);
              { default to errortype if no type is set yet }
              if p.resulttype.def=nil then
               p.resulttype:=generrortype;
            end;
           codegenerror:=codegenerror or oldcodegenerror;
         end
        else
         begin
           { update the codegenerror boolean with the previous result of this node }
           if (nf_error in p.flags) then
             codegenerror:=true;
         end;
      end;


    function do_resulttypepass(var p : tnode) : boolean;
      begin
         codegenerror:=false;
         resulttypepass(p);
         do_resulttypepass:=codegenerror;
      end;


    procedure firstpass(var p : tnode);
      var
         oldcodegenerror  : boolean;
         oldlocalswitches : tlocalswitches;
         oldpos    : tfileposinfo;
         hp : tnode;
      begin
         if (nf_pass1_done in p.flags) then
           exit;
         if not(nf_error in p.flags) then
           begin
              oldcodegenerror:=codegenerror;
              oldpos:=aktfilepos;
              oldlocalswitches:=aktlocalswitches;
              codegenerror:=false;
              aktfilepos:=p.fileinfo;
              aktlocalswitches:=p.localswitches;
              { checks make always a call }
              if ([cs_check_range,cs_check_overflow,cs_check_stack] * aktlocalswitches <> []) then
                include(current_procinfo.flags,pi_do_call);
              { determine the resulttype if not done }
              if (p.resulttype.def=nil) then
               begin
                 aktfilepos:=p.fileinfo;
                 aktlocalswitches:=p.localswitches;
                 hp:=p.det_resulttype;
                 { should the node be replaced? }
                 if assigned(hp) then
                  begin
                     p.free;
                     { run resulttypepass }
                     resulttypepass(hp);
                     { switch to new node }
                     p:=hp;
                  end;
                 if codegenerror then
                  begin
                    include(p.flags,nf_error);
                    { default to errortype if no type is set yet }
                    if p.resulttype.def=nil then
                     p.resulttype:=generrortype;
                  end;
                 aktlocalswitches:=oldlocalswitches;
                 aktfilepos:=oldpos;
                 codegenerror:=codegenerror or oldcodegenerror;
               end;
              if not(nf_error in p.flags) then
               begin
                 { first pass }
                 aktfilepos:=p.fileinfo;
                 aktlocalswitches:=p.localswitches;
                 hp:=p.pass_1;
                 { should the node be replaced? }
                 if assigned(hp) then
                  begin
                    p.free;
                    { run firstpass }
                    firstpass(hp);
                    { switch to new node }
                    p:=hp;
                  end;
                 if codegenerror then
                  include(p.flags,nf_error)
                 else
                  begin
{$ifdef EXTDEBUG}
                    if (p.expectloc=LOC_INVALID) then
                      Comment(V_Warning,'Expectloc is not set in firstpass: '+nodetype2str[p.nodetype]);
{$endif EXTDEBUG}
                  end;
               end;
              include(p.flags,nf_pass1_done);
              codegenerror:=codegenerror or oldcodegenerror;
              aktlocalswitches:=oldlocalswitches;
              aktfilepos:=oldpos;
           end
         else
           codegenerror:=true;
      end;


    function do_firstpass(var p : tnode) : boolean;
      begin
         codegenerror:=false;
         firstpass(p);
{$ifdef state_tracking}
         writeln('TRACKSTART');
         writeln('before');
         writenode(p);
         do_track_state_pass(p);
         writeln('after');
         writenode(p);
         writeln('TRACKDONE');
{$endif}
         do_firstpass:=codegenerror;
      end;

{$ifdef state_tracking}
     procedure do_track_state_pass(p:Tnode);

     begin
        aktstate:=Tstate_storage.create;
        p.track_state_pass(true);
            aktstate.destroy;
     end;
{$endif}

end.
