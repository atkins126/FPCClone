{
    $Id$
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit implements the base class for the register allocator

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

{$i fpcdefs.inc}

{ Allow duplicate allocations, can be used to get the .s file written }
{ $define ALLOWDUPREG}


unit rgobj;

  interface

    uses
      cutils, cpubase,
      aasmbase,aasmtai,aasmcpu,
      cclasses,globtype,cgbase,cgutils,
      cpuinfo
      ;

    type
      {
        The interference bitmap contains of 2 layers:
          layer 1 - 256*256 blocks with pointers to layer 2 blocks
          layer 2 - blocks of 32*256 (32 bytes = 256 bits)
      }
      Tinterferencebitmap2 = array[byte] of set of byte;
      Pinterferencebitmap2 = ^Tinterferencebitmap2;
      Tinterferencebitmap1 = array[byte] of Pinterferencebitmap2;
      pinterferencebitmap1 = ^tinterferencebitmap1;

      Tinterferencebitmap=class
      private
        maxx1,
        maxy1    : byte;
        fbitmap  : pinterferencebitmap1;
        function getbitmap(x,y:tsuperregister):boolean;
        procedure setbitmap(x,y:tsuperregister;b:boolean);
      public
        constructor create;
        destructor destroy;override;
        property bitmap[x,y:tsuperregister]:boolean read getbitmap write setbitmap;default;
      end;

      Tmovelistheader=record
        count,
        maxcount,
        sorted_until : cardinal;
      end;

      Tmovelist=record
        header : Tmovelistheader;
        data : array[tsuperregister] of Tlinkedlistitem;
      end;
      Pmovelist=^Tmovelist;

      {In the register allocator we keep track of move instructions.
       These instructions are moved between five linked lists. There
       is also a linked list per register to keep track about the moves
       it is associated with. Because we need to determine quickly in
       which of the five lists it is we add anu enumeradtion to each
       move instruction.}

      Tmoveset=(ms_coalesced_moves,ms_constrained_moves,ms_frozen_moves,
                ms_worklist_moves,ms_active_moves);
      Tmoveins=class(Tlinkedlistitem)
        moveset:Tmoveset;
        x,y:Tsuperregister;
      end;

      Treginfoflag=(ri_coalesced,ri_selected);
      Treginfoflagset=set of Treginfoflag;

      Treginfo=record
        live_start,
        live_end   : Tai;
        subreg   : tsubregister;
        alias    : Tsuperregister;
        { The register allocator assigns each register a colour }
        colour   : Tsuperregister;
        movelist : Pmovelist;
        adjlist  : Psuperregisterworklist;
        degree   : TSuperregister;
        flags    : Treginfoflagset;
      end;
      Preginfo=^TReginfo;

      tspillreginfo = record
        spillreg : tregister;
        orgreg : tsuperregister;
        tempreg : tregister;
        regread,regwritten, mustbespilled: boolean;
      end;
      tspillregsinfo = array[0..2] of tspillreginfo;

      {#------------------------------------------------------------------

      This class implements the default register allocator. It is used by the
      code generator to allocate and free registers which might be valid
      across nodes. It also contains utility routines related to registers.

      Some of the methods in this class should be overriden
      by cpu-specific implementations.

      --------------------------------------------------------------------}
      trgobj=class
        preserved_by_proc : tcpuregisterset;
        used_in_proc : tcpuregisterset;

        constructor create(Aregtype:Tregistertype;
                           Adefaultsub:Tsubregister;
                           const Ausable:array of tsuperregister;
                           Afirst_imaginary:Tsuperregister;
                           Apreserved_by_proc:Tcpuregisterset);
        destructor destroy;override;

        {# Allocate a register. An internalerror will be generated if there is
         no more free registers which can be allocated.}
        function getregister(list:Taasmoutput;subreg:Tsubregister):Tregister;virtual;
        {# Get the register specified.}
        procedure getcpuregister(list:Taasmoutput;r:Tregister);virtual;
        procedure ungetcpuregister(list:Taasmoutput;r:Tregister);virtual;
        {# Get multiple registers specified.}
        procedure alloccpuregisters(list:Taasmoutput;r:Tcpuregisterset);virtual;
        {# Free multiple registers specified.}
        procedure dealloccpuregisters(list:Taasmoutput;r:Tcpuregisterset);virtual;
        function uses_registers:boolean;virtual;
        procedure add_reg_instruction(instr:Tai;r:tregister);
        procedure add_move_instruction(instr:Taicpu);
        {# Do the register allocation.}
        procedure do_register_allocation(list:Taasmoutput;headertai:tai);virtual;
        { Adds an interference edge.
          don't move this to the protected section, the arm cg requires to access this (FK) }
        procedure add_edge(u,v:Tsuperregister);
      protected
        regtype           : Tregistertype;
        { default subregister used }
        defaultsub        : tsubregister;
        live_registers:Tsuperregisterworklist;
        { can be overriden to add cpu specific interferences }
        procedure add_cpu_interferences(p : tai);virtual;
        procedure add_constraints(reg:Tregister);virtual;
        function  getregisterinline(list:Taasmoutput;subreg:Tsubregister):Tregister;
        procedure ungetregisterinline(list:Taasmoutput;r:Tregister);
        function  get_spill_subreg(r : tregister) : tsubregister;virtual;
        function  do_spill_replace(list:Taasmoutput;instr:taicpu;orgreg:tsuperregister;const spilltemp:treference):boolean;virtual;
        procedure do_spill_read(list:Taasmoutput;pos:tai;const spilltemp:treference;tempreg:tregister);virtual;
        procedure do_spill_written(list:Taasmoutput;pos:tai;const spilltemp:treference;tempreg:tregister);virtual;

        function instr_spill_register(list:Taasmoutput;
                                      instr:taicpu;
                                      const r:Tsuperregisterset;
                                      const spilltemplist:Tspill_temp_list): boolean;virtual;
      private
        {# First imaginary register.}
        first_imaginary   : Tsuperregister;
        {# Highest register allocated until now.}
        reginfo           : PReginfo;
        maxreginfo,
        maxreginfoinc,
        maxreg            : Tsuperregister;
        usable_registers_cnt : word;
        usable_registers  : array[0..maxcpuregister-1] of tsuperregister;
        ibitmap           : Tinterferencebitmap;
        spillednodes,
        simplifyworklist,
        freezeworklist,
        spillworklist,
        coalescednodes,
        selectstack       : tsuperregisterworklist;
        worklist_moves,
        active_moves,
        frozen_moves,
        coalesced_moves,
        constrained_moves : Tlinkedlist;
{$ifdef EXTDEBUG}
        procedure writegraph(loopidx:longint);
{$endif EXTDEBUG}
        {# Disposes of the reginfo array.}
        procedure dispose_reginfo;
        {# Prepare the register colouring.}
        procedure prepare_colouring;
        {# Clean up after register colouring.}
        procedure epilogue_colouring;
        {# Colour the registers; that is do the register allocation.}
        procedure colour_registers;
        procedure insert_regalloc_info(list:Taasmoutput;u:tsuperregister);
        procedure insert_regalloc_info_all(list:Taasmoutput);
        procedure generate_interference_graph(list:Taasmoutput;headertai:tai);
        procedure translate_registers(list:Taasmoutput);
        function  spill_registers(list:Taasmoutput;headertai:tai):boolean;virtual;
        function  getnewreg(subreg:tsubregister):tsuperregister;
        procedure add_edges_used(u:Tsuperregister);
        procedure add_to_movelist(u:Tsuperregister;data:Tlinkedlistitem);
        function move_related(n:Tsuperregister):boolean;
        procedure make_work_list;
        procedure sort_simplify_worklist;
        procedure enable_moves(n:Tsuperregister);
        procedure decrement_degree(m:Tsuperregister);
        procedure simplify;
        function get_alias(n:Tsuperregister):Tsuperregister;
        procedure add_worklist(u:Tsuperregister);
        function adjacent_ok(u,v:Tsuperregister):boolean;
        function conservative(u,v:Tsuperregister):boolean;
        procedure combine(u,v:Tsuperregister);
        procedure coalesce;
        procedure freeze_moves(u:Tsuperregister);
        procedure freeze;
        procedure select_spill;
        procedure assign_colours;
        procedure clear_interferences(u:Tsuperregister);
      end;

    const
      first_reg = 0;
      last_reg = high(tsuperregister)-1;
      maxspillingcounter = 20;


  implementation

    uses
       systems,
       globals,verbose,tgobj,procinfo;


    procedure sort_movelist(ml:Pmovelist);

    {Ok, sorting pointers is silly, but it does the job to make Trgobj.combine
     faster.}

    var h,i,p:word;
        t:Tlinkedlistitem;

    begin
      with ml^ do
        begin
          if header.count<2 then
            exit;
          p:=1;
          while 2*p<header.count do
            p:=2*p;
          while p<>0 do
            begin
              for h:=p to header.count-1 do
                begin
                  i:=h;
                  t:=data[i];
                  repeat
                    if ptrint(data[i-p])<=ptrint(t) then
                      break;
                    data[i]:=data[i-p];
                    dec(i,p);
                  until i<p;
                  data[i]:=t;
                end;
              p:=p shr 1;
            end;
          header.sorted_until:=header.count-1;
        end;
    end;

{******************************************************************************
                              tinterferencebitmap
******************************************************************************}

    constructor tinterferencebitmap.create;
      begin
        inherited create;
        maxx1:=1;
        getmem(fbitmap,sizeof(tinterferencebitmap1)*2);
        fillchar(fbitmap^,sizeof(tinterferencebitmap1)*2,0);
      end;


    destructor tinterferencebitmap.destroy;

    var i,j:byte;

    begin
      for i:=0 to maxx1 do
        for j:=0 to maxy1 do
          if assigned(fbitmap[i,j]) then
            dispose(fbitmap[i,j]);
      freemem(fbitmap);
    end;


    function tinterferencebitmap.getbitmap(x,y:tsuperregister):boolean;
      var
        page : pinterferencebitmap2;
      begin
        result:=false;
        if (x shr 8>maxx1) then
          exit;
        page:=fbitmap[x shr 8,y shr 8];
        result:=assigned(page) and
          ((x and $ff) in page^[y and $ff]);
      end;


    procedure tinterferencebitmap.setbitmap(x,y:tsuperregister;b:boolean);
      var
        x1,y1 : byte;
      begin
        x1:=x shr 8;
        y1:=y shr 8;
        if x1>maxx1 then
          begin
            reallocmem(fbitmap,sizeof(tinterferencebitmap1)*(x1+1));
            fillchar(fbitmap[maxx1+1],sizeof(tinterferencebitmap1)*(x1-maxx1),0);
            maxx1:=x1;
          end;
        if not assigned(fbitmap[x1,y1]) then
          begin
            if y1>maxy1 then
              maxy1:=y1;
            new(fbitmap[x1,y1]);
            fillchar(fbitmap[x1,y1]^,sizeof(tinterferencebitmap2),0);
          end;
        if b then
          include(fbitmap[x1,y1]^[y and $ff],(x and $ff))
        else
          exclude(fbitmap[x1,y1]^[y and $ff],(x and $ff));
      end;


{******************************************************************************
                                trgobj
******************************************************************************}

    constructor trgobj.create(Aregtype:Tregistertype;
                              Adefaultsub:Tsubregister;
                              const Ausable:array of tsuperregister;
                              Afirst_imaginary:Tsuperregister;
                              Apreserved_by_proc:Tcpuregisterset);
       var
         i : Tsuperregister;
       begin
         { empty super register sets can cause very strange problems }
         if high(Ausable)=0 then
           internalerror(200210181);
         first_imaginary:=Afirst_imaginary;
         maxreg:=Afirst_imaginary;
         regtype:=Aregtype;
         defaultsub:=Adefaultsub;
         preserved_by_proc:=Apreserved_by_proc;
         used_in_proc:=[];
         live_registers.init;
         { Get reginfo for CPU registers }
         maxreginfo:=first_imaginary;
         maxreginfoinc:=16;
         worklist_moves:=Tlinkedlist.create;
         reginfo:=allocmem(first_imaginary*sizeof(treginfo));
         for i:=0 to first_imaginary-1 do
           begin
             reginfo[i].degree:=high(tsuperregister);
             reginfo[i].alias:=RS_INVALID;
           end;
         { Usable registers }
         fillchar(usable_registers,sizeof(usable_registers),0);
         for i:=low(Ausable) to high(Ausable) do
           usable_registers[i]:=Ausable[i];
         usable_registers_cnt:=high(Ausable)+1;
         { Initialize Worklists }
         spillednodes.init;
         simplifyworklist.init;
         freezeworklist.init;
         spillworklist.init;
         coalescednodes.init;
         selectstack.init;
      end;

    destructor trgobj.destroy;

    begin
      spillednodes.done;
      simplifyworklist.done;
      freezeworklist.done;
      spillworklist.done;
      coalescednodes.done;
      selectstack.done;
      live_registers.done;
      worklist_moves.free;
      dispose_reginfo;
    end;

    procedure Trgobj.dispose_reginfo;

    var i:Tsuperregister;

    begin
      if reginfo<>nil then
        begin
          for i:=0 to maxreg-1 do
            with reginfo[i] do
              begin
                if adjlist<>nil then
                  dispose(adjlist,done);
                if movelist<>nil then
                  dispose(movelist);
              end;
          freemem(reginfo);
          reginfo:=nil;
        end;
    end;

    function trgobj.getnewreg(subreg:tsubregister):tsuperregister;
      var
        oldmaxreginfo : tsuperregister;
      begin
        result:=maxreg;
        inc(maxreg);
        if maxreg>=last_reg then
          internalerror(200310146);
        if maxreg>=maxreginfo then
          begin
            oldmaxreginfo:=maxreginfo;
            inc(maxreginfo,maxreginfoinc);
            if maxreginfoinc<256 then
              maxreginfoinc:=maxreginfoinc*2;
            reallocmem(reginfo,maxreginfo*sizeof(treginfo));
            { Do we really need it to clear it ? At least for 1.0.x (PFV) }
            fillchar(reginfo[oldmaxreginfo],(maxreginfo-oldmaxreginfo)*sizeof(treginfo),0);
          end;
        reginfo[result].subreg:=subreg;
      end;


    function trgobj.getregister(list:Taasmoutput;subreg:Tsubregister):Tregister;
      begin
        {$ifdef EXTDEBUG}
        if reginfo=nil then
          InternalError(2004020901);
        {$endif EXTDEBUG}
        if defaultsub=R_SUBNONE then
          result:=newreg(regtype,getnewreg(R_SUBNONE),R_SUBNONE)
        else
          result:=newreg(regtype,getnewreg(subreg),subreg);
      end;


    function trgobj.uses_registers:boolean;
      begin
        result:=(maxreg>first_imaginary);
      end;


    procedure trgobj.ungetcpuregister(list:Taasmoutput;r:Tregister);
      begin
        if (getsupreg(r)>=first_imaginary) then
          InternalError(2004020901);
        list.concat(Tai_regalloc.dealloc(r,nil));
      end;


    procedure trgobj.getcpuregister(list:Taasmoutput;r:Tregister);
      var
        supreg:Tsuperregister;
      begin
        supreg:=getsupreg(r);
        if supreg>=first_imaginary then
          internalerror(2003121503);
        include(used_in_proc,supreg);
        list.concat(Tai_regalloc.alloc(r,nil));
      end;


    procedure trgobj.alloccpuregisters(list:Taasmoutput;r:Tcpuregisterset);

    var i:Tsuperregister;

    begin
      for i:=0 to first_imaginary-1 do
        if i in r then
          getcpuregister(list,newreg(regtype,i,defaultsub));
    end;


    procedure trgobj.dealloccpuregisters(list:Taasmoutput;r:Tcpuregisterset);

    var i:Tsuperregister;

    begin
      for i:=0 to first_imaginary-1 do
        if i in r then
          ungetcpuregister(list,newreg(regtype,i,defaultsub));
    end;


    procedure trgobj.do_register_allocation(list:Taasmoutput;headertai:tai);
      var
        spillingcounter:byte;
        endspill:boolean;
      begin
        { Insert regalloc info for imaginary registers }
        insert_regalloc_info_all(list);
        ibitmap:=tinterferencebitmap.create;
        generate_interference_graph(list,headertai);
        { Don't do the real allocation when -sr is passed }
        if (cs_no_regalloc in aktglobalswitches) then
          exit;
        {Do register allocation.}
        spillingcounter:=0;
        repeat
          prepare_colouring;
          colour_registers;
          epilogue_colouring;
          endspill:=true;
          if spillednodes.length<>0 then
            begin
              inc(spillingcounter);
              if spillingcounter>maxspillingcounter then
                exit;
              if spillingcounter>maxspillingcounter then
                internalerror(200309041);
              endspill:=not spill_registers(list,headertai);
            end;
        until endspill;
        ibitmap.free;
        translate_registers(list);
        dispose_reginfo;
      end;


    procedure trgobj.add_constraints(reg:Tregister);

    begin
    end;


    procedure trgobj.add_edge(u,v:Tsuperregister);

    {This procedure will add an edge to the virtual interference graph.}

      procedure addadj(u,v:Tsuperregister);

      begin
        with reginfo[u] do
          begin
            if adjlist=nil then
              new(adjlist,init);
            adjlist^.add(v);
          end;
      end;

    begin
      if (u<>v) and not(ibitmap[v,u]) then
        begin
          ibitmap[v,u]:=true;
          ibitmap[u,v]:=true;
          {Precoloured nodes are not stored in the interference graph.}
          if (u>=first_imaginary) then
            addadj(u,v);
          if (v>=first_imaginary) then
            addadj(v,u);
        end;
    end;


    procedure trgobj.add_edges_used(u:Tsuperregister);

    var i:word;

    begin
      with live_registers do
        if length>0 then
          for i:=0 to length-1 do
            add_edge(u,get_alias(buf^[i]));
    end;

{$ifdef EXTDEBUG}
    procedure trgobj.writegraph(loopidx:longint);

    {This procedure writes out the current interference graph in the
    register allocator.}


    var f:text;
        i,j:Tsuperregister;

    begin
      assign(f,'igraph'+tostr(loopidx));
      rewrite(f);
      writeln(f,'Interference graph');
      writeln(f);
      write(f,'    ');
      for i:=0 to 15 do
        for j:=0 to 15 do
          write(f,hexstr(i,1));
      writeln(f);
      write(f,'    ');
      for i:=0 to 15 do
        write(f,'0123456789ABCDEF');
      writeln(f);
      for i:=0 to maxreg-1 do
        begin
          write(f,hexstr(i,2):4);
          for j:=0 to maxreg-1 do
            if ibitmap[i,j] then
              write(f,'*')
            else
              write(f,'-');
          writeln(f);
        end;
      close(f);
    end;
{$endif EXTDEBUG}

    procedure trgobj.add_to_movelist(u:Tsuperregister;data:Tlinkedlistitem);
    begin
      with reginfo[u] do
        begin
          if movelist=nil then
            begin
              getmem(movelist,sizeof(tmovelistheader)+60*sizeof(pointer));
              movelist^.header.maxcount:=60;
              movelist^.header.count:=0;
              movelist^.header.sorted_until:=0;
            end
          else
            begin
              if movelist^.header.count>=movelist^.header.maxcount then
                begin
                  movelist^.header.maxcount:=movelist^.header.maxcount*2;
                  reallocmem(movelist,sizeof(tmovelistheader)+movelist^.header.maxcount*sizeof(pointer));
                end;
            end;
          movelist^.data[movelist^.header.count]:=data;
          inc(movelist^.header.count);
        end;
    end;


    procedure trgobj.add_reg_instruction(instr:Tai;r:tregister);
      var
        supreg : tsuperregister;
      begin
        supreg:=getsupreg(r);
{$ifdef extdebug}
        if supreg>=maxreginfo then
          internalerror(200411061);
{$endif extdebug}
        if supreg>=first_imaginary then
          with reginfo[supreg] do
            begin
              if not assigned(live_start) then
                live_start:=instr;
              live_end:=instr;
            end;
      end;


    procedure trgobj.add_move_instruction(instr:Taicpu);

    {This procedure notifies a certain as a move instruction so the
     register allocator can try to eliminate it.}

    var i:Tmoveins;
        ssupreg,dsupreg:Tsuperregister;

    begin
    {$ifdef extdebug}
      if (instr.oper[O_MOV_SOURCE]^.typ<>top_reg) or
         (instr.oper[O_MOV_DEST]^.typ<>top_reg) then
        internalerror(200311291);
    {$endif}
      i:=Tmoveins.create;
      i.moveset:=ms_worklist_moves;
      worklist_moves.insert(i);
      ssupreg:=getsupreg(instr.oper[O_MOV_SOURCE]^.reg);
      add_to_movelist(ssupreg,i);
      dsupreg:=getsupreg(instr.oper[O_MOV_DEST]^.reg);
      if ssupreg<>dsupreg then
        {Avoid adding the same move instruction twice to a single register.}
        add_to_movelist(dsupreg,i);
      i.x:=ssupreg;
      i.y:=dsupreg;
    end;

    function trgobj.move_related(n:Tsuperregister):boolean;

    var i:cardinal;

    begin
      move_related:=false;
      with reginfo[n] do
        if movelist<>nil then
          with movelist^ do
            for i:=0 to header.count-1 do
              if Tmoveins(data[i]).moveset in [ms_worklist_moves,ms_active_moves] then
                begin
                  move_related:=true;
                  break;
                end;
    end;

    procedure Trgobj.sort_simplify_worklist;

    {Sorts the simplifyworklist by the number of interferences the
     registers in it cause. This allows simplify to execute in
     constant time.}

    var p,h,i,leni,lent:word;
        t:Tsuperregister;
        adji,adjt:Psuperregisterworklist;

    begin
      with simplifyworklist do
        begin
          if length<2 then
            exit;
          p:=1;
          while 2*p<length do
            p:=2*p;
          while p<>0 do
            begin
              for h:=p to length-1 do
                begin
                  i:=h;
                  t:=buf^[i];
                  adjt:=reginfo[buf^[i]].adjlist;
                  lent:=0;
                  if adjt<>nil then
                    lent:=adjt^.length;
                  repeat
                    adji:=reginfo[buf^[i-p]].adjlist;
                    leni:=0;
                    if adji<>nil then
                      leni:=adji^.length;
                    if leni<=lent then
                      break;
                    buf^[i]:=buf^[i-p];
                    dec(i,p)
                  until i<p;
                  buf^[i]:=t;
                end;
              p:=p shr 1;
            end;
        end;
    end;

    procedure trgobj.make_work_list;

    var n:Tsuperregister;

    begin
      {If we have 7 cpu registers, and the degree of a node is 7, we cannot
       assign it to any of the registers, thus it is significant.}
      for n:=first_imaginary to maxreg-1 do
        with reginfo[n] do
          begin
            if adjlist=nil then
              degree:=0
            else
              degree:=adjlist^.length;
            if degree>=usable_registers_cnt then
              spillworklist.add(n)
            else if move_related(n) then
              freezeworklist.add(n)
            else
              simplifyworklist.add(n);
          end;
      sort_simplify_worklist;
    end;


    procedure trgobj.prepare_colouring;
    begin
      make_work_list;
      active_moves:=Tlinkedlist.create;
      frozen_moves:=Tlinkedlist.create;
      coalesced_moves:=Tlinkedlist.create;
      constrained_moves:=Tlinkedlist.create;
      selectstack.clear;
    end;

    procedure trgobj.enable_moves(n:Tsuperregister);

    var m:Tlinkedlistitem;
        i:cardinal;

    begin
      with reginfo[n] do
        if movelist<>nil then
          for i:=0 to movelist^.header.count-1 do
            begin
              m:=movelist^.data[i];
              if Tmoveins(m).moveset in [ms_worklist_moves,ms_active_moves] then
                if Tmoveins(m).moveset=ms_active_moves then
                  begin
                    {Move m from the set active_moves to the set worklist_moves.}
                    active_moves.remove(m);
                    Tmoveins(m).moveset:=ms_worklist_moves;
                    worklist_moves.concat(m);
                  end;
          end;
    end;

    procedure Trgobj.decrement_degree(m:Tsuperregister);

    var adj : Psuperregisterworklist;
        n : tsuperregister;
        d,i : word;

    begin
      with reginfo[m] do
        begin
          d:=degree;
          if d=0 then
            internalerror(200312151);
          dec(degree);
          if d=usable_registers_cnt then
            begin
              {Enable moves for m.}
              enable_moves(m);
              {Enable moves for adjacent.}
              adj:=adjlist;
              if adj<>nil then
                for i:=1 to adj^.length do
                  begin
                    n:=adj^.buf^[i-1];
                    if reginfo[n].flags*[ri_selected,ri_coalesced]<>[] then
                      enable_moves(n);
                  end;
              {Remove the node from the spillworklist.}
              if not spillworklist.delete(m) then
                internalerror(200310145);

              if move_related(m) then
                freezeworklist.add(m)
              else
                simplifyworklist.add(m);
            end;
        end;
    end;

    procedure trgobj.simplify;

    var adj : Psuperregisterworklist;
        m,n : Tsuperregister;
        i : word;
    begin
      {We take the element with the least interferences out of the
       simplifyworklist. Since the simplifyworklist is now sorted, we
       no longer need to search, but we can simply take the first element.}
      m:=simplifyworklist.get;

      {Push it on the selectstack.}
      selectstack.add(m);
      with reginfo[m] do
        begin
          include(flags,ri_selected);
          adj:=adjlist;
        end;
      if adj<>nil then
        for i:=1 to adj^.length do
          begin
            n:=adj^.buf^[i-1];
            if (n>=first_imaginary) and
               (reginfo[n].flags*[ri_selected,ri_coalesced]=[]) then
              decrement_degree(n);
          end;
    end;

    function trgobj.get_alias(n:Tsuperregister):Tsuperregister;

    begin
      while ri_coalesced in reginfo[n].flags do
        n:=reginfo[n].alias;
      get_alias:=n;
    end;

    procedure trgobj.add_worklist(u:Tsuperregister);
      begin
        if (u>=first_imaginary) and
           (not move_related(u)) and
           (reginfo[u].degree<usable_registers_cnt) then
          begin
            if not freezeworklist.delete(u) then
              internalerror(200308161); {must be found}
            simplifyworklist.add(u);
          end;
      end;


    function trgobj.adjacent_ok(u,v:Tsuperregister):boolean;

    {Check wether u and v should be coalesced. u is precoloured.}

      function ok(t,r:Tsuperregister):boolean;

      begin
        ok:=(t<first_imaginary) or
            (reginfo[t].degree<usable_registers_cnt) or
            ibitmap[r,t];
      end;

    var adj : Psuperregisterworklist;
        i : word;
        n : tsuperregister;

    begin
      with reginfo[v] do
        begin
          adjacent_ok:=true;
          adj:=adjlist;
          if adj<>nil then
            for i:=1 to adj^.length do
              begin
                n:=adj^.buf^[i-1];
                if (flags*[ri_coalesced,ri_selected]=[]) and not ok(n,u) then
                  begin
                    adjacent_ok:=false;
                    break;
                  end;
              end;
        end;
    end;

    function trgobj.conservative(u,v:Tsuperregister):boolean;

    var adj : Psuperregisterworklist;
        done : Tsuperregisterset; {To prevent that we count nodes twice.}
        i,k:word;
        n : tsuperregister;

    begin
      k:=0;
      supregset_reset(done,false,maxreg);
      with reginfo[u] do
        begin
          adj:=adjlist;
          if adj<>nil then
            for i:=1 to adj^.length do
              begin
                n:=adj^.buf^[i-1];
                if flags*[ri_coalesced,ri_selected]=[] then
                  begin
                    supregset_include(done,n);
                    if reginfo[n].degree>=usable_registers_cnt then
                      inc(k);
                  end;
              end;
        end;
      adj:=reginfo[v].adjlist;
      if adj<>nil then
        for i:=1 to adj^.length do
          begin
            n:=adj^.buf^[i-1];
            if not supregset_in(done,n) and
               (reginfo[n].degree>=usable_registers_cnt) and
               (reginfo[u].flags*[ri_coalesced,ri_selected]=[]) then
              inc(k);
          end;
      conservative:=(k<usable_registers_cnt);
    end;


    procedure trgobj.combine(u,v:Tsuperregister);

    var adj : Psuperregisterworklist;
        i,n,p,q:cardinal;
        t : tsuperregister;
        searched:Tlinkedlistitem;

    label l1;

    begin
      if not freezeworklist.delete(v) then
        spillworklist.delete(v);
      coalescednodes.add(v);
      include(reginfo[v].flags,ri_coalesced);
      reginfo[v].alias:=u;

      {Combine both movelists. Since the movelists are sets, only add
       elements that are not already present. The movelists cannot be
       empty by definition; nodes are only coalesced if there is a move
       between them. To prevent quadratic time blowup (movelists of
       especially machine registers can get very large because of moves
       generated during calls) we need to go into disgusting complexity.

       (See webtbs/tw2242 for an example that stresses this.)

       We want to sort the movelist to be able to search logarithmically.
       Unfortunately, sorting the movelist every time before searching
       is counter-productive, since the movelist usually grows with a few
       items at a time. Therefore, we split the movelist into a sorted
       and an unsorted part and search through both. If the unsorted part
       becomes too large, we sort.}
      if assigned(reginfo[u].movelist) then
        begin
          {We have to weigh the cost of sorting the list against searching
           the cost of the unsorted part. I use factor of 8 here; if the
           number of items is less than 8 times the numer of unsorted items,
           we'll sort the list.}
          with reginfo[u].movelist^ do
            if header.count<8*(header.count-header.sorted_until) then
              sort_movelist(reginfo[u].movelist);

          if assigned(reginfo[v].movelist) then
            begin
              for n:=0 to reginfo[v].movelist^.header.count-1 do
                begin
                  {Binary search the sorted part of the list.}
                  searched:=reginfo[v].movelist^.data[n];
                  p:=0;
                  q:=reginfo[u].movelist^.header.sorted_until;
                  i:=0;
                  if q<>0 then
                    repeat
                      i:=(p+q) shr 1;
                      if ptrint(searched)>ptrint(reginfo[u].movelist^.data[i]) then
                        p:=i+1
                      else
                        q:=i;
                    until p=q;
                  with reginfo[u].movelist^ do
                    if searched<>data[i] then
                      begin
                        {Linear search the unsorted part of the list.}
                        for i:=header.sorted_until+1 to header.count-1 do
                          if searched=data[i] then
                            goto l1;
                        {Not found -> add}
                        add_to_movelist(u,searched);
                      l1:
                      end;
                end;
            end;
        end;

      enable_moves(v);

      adj:=reginfo[v].adjlist;
      if adj<>nil then
        for i:=1 to adj^.length do
          begin
            t:=adj^.buf^[i-1];
            with reginfo[t] do
              if not(ri_coalesced in flags) then
                begin
                  {t has a connection to v. Since we are adding v to u, we
                   need to connect t to u. However, beware if t was already
                   connected to u...}
                  if (ibitmap[t,u]) and not (ri_selected in flags) then
                    {... because in that case, we are actually removing an edge
                     and the degree of t decreases.}
                    decrement_degree(t)
                  else
                    begin
                      add_edge(t,u);
                      {We have added an edge to t and u. So their degree increases.
                       However, v is added to u. That means its neighbours will
                       no longer point to v, but to u instead. Therefore, only the
                       degree of u increases.}
                      if (u>=first_imaginary) and not (ri_selected in flags) then
                        inc(reginfo[u].degree);
                    end;
                end;
          end;
      if (reginfo[u].degree>=usable_registers_cnt) and freezeworklist.delete(u) then
        spillworklist.add(u);
    end;


    procedure trgobj.coalesce;

    var m:Tmoveins;
        x,y,u,v:Tsuperregister;

    begin
      m:=Tmoveins(worklist_moves.getfirst);
      x:=get_alias(m.x);
      y:=get_alias(m.y);
      if (y<first_imaginary) then
        begin
          u:=y;
          v:=x;
        end
      else
        begin
          u:=x;
          v:=y;
        end;
      if (u=v) then
        begin
          m.moveset:=ms_coalesced_moves;  {Already coalesced.}
          coalesced_moves.insert(m);
          add_worklist(u);
        end
      {Do u and v interfere? In that case the move is constrained. Two
       precoloured nodes interfere allways. If v is precoloured, by the above
       code u is precoloured, thus interference...}
      else if (v<first_imaginary) or ibitmap[u,v] then
        begin
          m.moveset:=ms_constrained_moves;  {Cannot coalesce yet...}
          constrained_moves.insert(m);
          add_worklist(u);
          add_worklist(v);
        end
      {Next test: is it possible and a good idea to coalesce??}
      else if ((u<first_imaginary) and adjacent_ok(u,v)) or
              ((u>=first_imaginary) and conservative(u,v)) then
        begin
          m.moveset:=ms_coalesced_moves;  {Move coalesced!}
          coalesced_moves.insert(m);
          combine(u,v);
          add_worklist(u);
        end
      else
        begin
          m.moveset:=ms_active_moves;
          active_moves.insert(m);
        end;
    end;

    procedure trgobj.freeze_moves(u:Tsuperregister);

    var i:cardinal;
        m:Tlinkedlistitem;
        v,x,y:Tsuperregister;

    begin
      if reginfo[u].movelist<>nil then
        for i:=0 to reginfo[u].movelist^.header.count-1 do
          begin
            m:=reginfo[u].movelist^.data[i];
            if Tmoveins(m).moveset in [ms_worklist_moves,ms_active_moves] then
              begin
                x:=Tmoveins(m).x;
                y:=Tmoveins(m).y;
                if get_alias(y)=get_alias(u) then
                  v:=get_alias(x)
                else
                  v:=get_alias(y);
                {Move m from active_moves/worklist_moves to frozen_moves.}
                if Tmoveins(m).moveset=ms_active_moves then
                  active_moves.remove(m)
                else
                  worklist_moves.remove(m);
                Tmoveins(m).moveset:=ms_frozen_moves;
                frozen_moves.insert(m);

                if (v>=first_imaginary) and not(move_related(v)) and
                   (reginfo[v].degree<usable_registers_cnt) then
                  begin
                    freezeworklist.delete(v);
                    simplifyworklist.add(v);
                  end;
              end;
          end;
    end;

    procedure trgobj.freeze;

    var n:Tsuperregister;

    begin
      { We need to take a random element out of the freezeworklist. We take
        the last element. Dirty code! }
      n:=freezeworklist.get;
      {Add it to the simplifyworklist.}
      simplifyworklist.add(n);
      freeze_moves(n);
    end;

    procedure trgobj.select_spill;

    var
      n : tsuperregister;
      adj : psuperregisterworklist;
      max,p,i:word;

    begin
      { We must look for the element with the most interferences in the
        spillworklist. This is required because those registers are creating
        the most conflicts and keeping them in a register will not reduce the
        complexity and even can cause the help registers for the spilling code
        to get too much conflicts with the result that the spilling code
        will never converge (PFV) }
      max:=0;
      p:=0;
      with spillworklist do
        begin
          {Safe: This procedure is only called if length<>0}
          for i:=0 to length-1 do
            begin
              adj:=reginfo[buf^[i]].adjlist;
              if assigned(adj) and (adj^.length>max) then
                begin
                  p:=i;
                  max:=adj^.length;
                end;
            end;
          n:=buf^[p];
          deleteidx(p);
        end;

      simplifyworklist.add(n);
      freeze_moves(n);
    end;

    procedure trgobj.assign_colours;

    {Assign_colours assigns the actual colours to the registers.}

    var adj : Psuperregisterworklist;
        i,j,k : word;
        n,a,c : Tsuperregister;
        colourednodes : Tsuperregisterset;
        adj_colours:set of 0..255;
        found : boolean;

    begin
      spillednodes.clear;
      {Reset colours}
      for n:=0 to maxreg-1 do
        reginfo[n].colour:=n;
      {Colour the cpu registers...}
      supregset_reset(colourednodes,false,maxreg);
      for n:=0 to first_imaginary-1 do
        supregset_include(colourednodes,n);
      {Now colour the imaginary registers on the select-stack.}
      for i:=selectstack.length downto 1 do
        begin
          n:=selectstack.buf^[i-1];
          {Create a list of colours that we cannot assign to n.}
          adj_colours:=[];
          adj:=reginfo[n].adjlist;
          if adj<>nil then
            for j:=0 to adj^.length-1 do
              begin
                a:=get_alias(adj^.buf^[j]);
                if supregset_in(colourednodes,a) and (reginfo[a].colour<=255) then
                  include(adj_colours,reginfo[a].colour);
              end;
          if regtype=R_INTREGISTER then
            include(adj_colours,RS_STACK_POINTER_REG);
          {Assume a spill by default...}
          found:=false;
          {Search for a colour not in this list.}
          for k:=0 to usable_registers_cnt-1 do
            begin
              c:=usable_registers[k];
               if not(c in adj_colours) then
                 begin
                   reginfo[n].colour:=c;
                   found:=true;
                   supregset_include(colourednodes,n);
                   include(used_in_proc,c);
                   break;
                 end;
            end;
          if not found then
            spillednodes.add(n);
        end;
      {Finally colour the nodes that were coalesced.}
      for i:=1 to coalescednodes.length do
        begin
          n:=coalescednodes.buf^[i-1];
          k:=get_alias(n);
          reginfo[n].colour:=reginfo[k].colour;
          if reginfo[k].colour<maxcpuregister then
            include(used_in_proc,reginfo[k].colour);
        end;
    end;

    procedure trgobj.colour_registers;

    begin
      repeat
        if simplifyworklist.length<>0 then
          simplify
        else if not(worklist_moves.empty) then
          coalesce
        else if freezeworklist.length<>0 then
          freeze
        else if spillworklist.length<>0 then
          select_spill;
      until (simplifyworklist.length=0) and
            worklist_moves.empty and
            (freezeworklist.length=0) and
            (spillworklist.length=0);
      assign_colours;
    end;

    procedure trgobj.epilogue_colouring;
    var
      i : Tsuperregister;
    begin
      worklist_moves.clear;
      active_moves.destroy;
      active_moves:=nil;
      frozen_moves.destroy;
      frozen_moves:=nil;
      coalesced_moves.destroy;
      coalesced_moves:=nil;
      constrained_moves.destroy;
      constrained_moves:=nil;
      for i:=0 to maxreg-1 do
        with reginfo[i] do
          if movelist<>nil then
            begin
              dispose(movelist);
              movelist:=nil;
            end;
    end;


    procedure trgobj.clear_interferences(u:Tsuperregister);

    {Remove node u from the interference graph and remove all collected
     move instructions it is associated with.}

    var i : word;
        v : Tsuperregister;
        adj,adj2 : Psuperregisterworklist;

    begin
      adj:=reginfo[u].adjlist;
      if adj<>nil then
        begin
          for i:=1 to adj^.length do
            begin
              v:=adj^.buf^[i-1];
              {Remove (u,v) and (v,u) from bitmap.}
              ibitmap[u,v]:=false;
              ibitmap[v,u]:=false;
              {Remove (v,u) from adjacency list.}
              adj2:=reginfo[v].adjlist;
              if adj2<>nil then
                begin
                  adj2^.delete(u);
                  if adj2^.length=0 then
                    begin
                      dispose(adj2,done);
                      reginfo[v].adjlist:=nil;
                    end;
                end;
            end;
          {Remove ( u,* ) from adjacency list.}
          dispose(adj,done);
          reginfo[u].adjlist:=nil;
        end;
    end;


    function trgobj.getregisterinline(list:Taasmoutput;subreg:Tsubregister):Tregister;
      var
        p : Tsuperregister;
      begin
        p:=getnewreg(subreg);
        live_registers.add(p);
        result:=newreg(regtype,p,subreg);
        add_edges_used(p);
        add_constraints(result);
      end;


    procedure trgobj.ungetregisterinline(list:Taasmoutput;r:Tregister);
      var
        supreg:Tsuperregister;
      begin
        supreg:=getsupreg(r);
        live_registers.delete(supreg);
        insert_regalloc_info(list,supreg);
      end;


    procedure trgobj.insert_regalloc_info(list:Taasmoutput;u:tsuperregister);
      var
        p : tai;
        r : tregister;
        palloc,
        pdealloc : tai_regalloc;
      begin
        { Insert regallocs for all imaginary registers }
        with reginfo[u] do
          begin
            r:=newreg(regtype,u,subreg);
            if assigned(live_start) then
              begin
                { Generate regalloc and bind it to an instruction, this
                  is needed to find all live registers belonging to an
                  instruction during the spilling }
                if live_start.typ=ait_instruction then
                  palloc:=tai_regalloc.alloc(r,live_start)
                else
                  palloc:=tai_regalloc.alloc(r,nil);
                if live_end.typ=ait_instruction then
                  pdealloc:=tai_regalloc.dealloc(r,live_end)
                else
                  pdealloc:=tai_regalloc.dealloc(r,nil);
                { Insert live start allocation before the instruction/reg_a_sync }
                list.insertbefore(palloc,live_start);
                { Insert live end deallocation before reg allocations
                  to reduce conflicts }
                p:=live_end;
                while assigned(p) and
                      assigned(p.previous) and
                      (tai(p.previous).typ=ait_regalloc) and
                      (tai_regalloc(p.previous).ratype=ra_alloc) and
                      (tai_regalloc(p.previous).reg<>r) do
                  p:=tai(p.previous);
                { , but add release after a reg_a_sync }
                if assigned(p) and
                   (p.typ=ait_regalloc) and
                   (tai_regalloc(p).ratype=ra_sync) then
                  p:=tai(p.next);
                if assigned(p) then
                  list.insertbefore(pdealloc,p)
                else
                  list.concat(pdealloc);
              end
{$ifdef EXTDEBUG}
            else
              Comment(V_Warning,'Register '+std_regname(r)+' not used');
{$endif EXTDEBUG}
          end;
      end;


    procedure trgobj.insert_regalloc_info_all(list:Taasmoutput);
      var
        supreg : tsuperregister;
      begin
        { Insert regallocs for all imaginary registers }
        for supreg:=first_imaginary to maxreg-1 do
          insert_regalloc_info(list,supreg);
      end;


    procedure trgobj.add_cpu_interferences(p : tai);
      begin
      end;


    procedure trgobj.generate_interference_graph(list:Taasmoutput;headertai:tai);
      var
        p : tai;
        i : integer;
        supreg : tsuperregister;
      begin
        { All allocations are available. Now we can generate the
          interference graph. Walk through all instructions, we can
          start with the headertai, because before the header tai is
          only symbols. }
        live_registers.clear;
        p:=headertai;
        while assigned(p) do
          begin
            if p.typ=ait_regalloc then
              with Tai_regalloc(p) do
                begin
                  if (getregtype(reg)=regtype) then
                    begin
                      supreg:=getsupreg(reg);
                      case ratype of
                        ra_alloc :
                          begin
                            live_registers.add(supreg);
                            add_edges_used(supreg);
                          end;
                        ra_dealloc :
                          begin
                            live_registers.delete(supreg);
                            add_edges_used(supreg);
                          end;
                      end;
                      { constraints needs always to be updated }
                      add_constraints(reg);
                    end;
                end;
            add_cpu_interferences(p);
            p:=Tai(p.next);
          end;

{$ifdef EXTDEBUG}
        if live_registers.length>0 then
          begin
            for i:=0 to live_registers.length-1 do
              begin
                { Only report for imaginary registers }
                if live_registers.buf^[i]>=first_imaginary then
                  Comment(V_Warning,'Register '+std_regname(newreg(R_INTREGISTER,live_registers.buf^[i],defaultsub))+' not released');
              end;
          end;
{$endif}
      end;


    procedure Trgobj.translate_registers(list:taasmoutput);
      var
        hp,p,q:Tai;
        i:shortint;
{$ifdef arm}
        so:pshifterop;
{$endif arm}


      begin
        { Leave when no imaginary registers are used }
        if maxreg<=first_imaginary then
          exit;
        p:=Tai(list.first);
        while assigned(p) do
          begin
            case p.typ of
              ait_regalloc:
                with Tai_regalloc(p) do
                  begin
                    if (getregtype(reg)=regtype) then
                      begin
                        { Only alloc/dealloc is needed for the optimizer, remove
                          other regalloc }
                        if not(ratype in [ra_alloc,ra_dealloc]) then
                          begin
                            q:=Tai(next);
                            list.remove(p);
                            p.free;
                            p:=q;
                            continue;
                          end
                        else
                          begin
                            setsupreg(reg,reginfo[getsupreg(reg)].colour);
                            {
                              Remove sequences of release and
                              allocation of the same register like. Other combinations
                              of release/allocate need to stay in the list.

                                 # Register X released
                                 # Register X allocated
                            }
                            if assigned(previous) and
                               (ratype=ra_alloc) and
                               (Tai(previous).typ=ait_regalloc) and
                               (Tai_regalloc(previous).reg=reg) and
                               (Tai_regalloc(previous).ratype=ra_dealloc) then
                              begin
                                q:=Tai(next);
                                hp:=tai(previous);
                                list.remove(hp);
                                hp.free;
                                list.remove(p);
                                p.free;
                                p:=q;
                                continue;
                              end;
                          end;
                      end;
                  end;
              ait_instruction:
                with Taicpu(p) do
                  begin
                    aktfilepos:=fileinfo;
                    for i:=0 to ops-1 do
                      with oper[i]^ do
                        case typ of
                          Top_reg:
                             if (getregtype(reg)=regtype) then
                               setsupreg(reg,reginfo[getsupreg(reg)].colour);
                          Top_ref:
                            begin
                              if regtype=R_INTREGISTER then
                                with ref^ do
                                  begin
                                    if base<>NR_NO then
                                      setsupreg(base,reginfo[getsupreg(base)].colour);
                                    if index<>NR_NO then
                                      setsupreg(index,reginfo[getsupreg(index)].colour);
                                  end;
                            end;
{$ifdef arm}
                          Top_shifterop:
                            begin
                              if regtype=R_INTREGISTER then
                                begin
                                  so:=shifterop;
                                  if so^.rs<>NR_NO then
                                    setsupreg(so^.rs,reginfo[getsupreg(so^.rs)].colour);
                                end;
                            end;
{$endif arm}
                        end;

                    { Maybe the operation can be removed when
                      it is a move and both arguments are the same }
                    if is_same_reg_move(regtype) then
                      begin
                        q:=Tai(p.next);
                        list.remove(p);
                        p.free;
                        p:=q;
                        continue;
                      end;
                  end;
            end;
            p:=Tai(p.next);
          end;
        aktfilepos:=current_procinfo.exitpos;
      end;


    function trgobj.spill_registers(list:Taasmoutput;headertai:tai):boolean;
    { Returns true if any help registers have been used }
      var
        i : word;
        t : tsuperregister;
        p,q : Tai;
        regs_to_spill_set:Tsuperregisterset;
        spill_temps : ^Tspill_temp_list;
        supreg : tsuperregister;
        templist : taasmoutput;
      begin
        spill_registers:=false;
        live_registers.clear;
        for i:=first_imaginary to maxreg-1 do
          exclude(reginfo[i].flags,ri_selected);
        spill_temps:=allocmem(sizeof(treference)*maxreg);
        supregset_reset(regs_to_spill_set,false,$ffff);
        { Allocate temps and insert in front of the list }
        templist:=taasmoutput.create;
        {Safe: this procedure is only called if there are spilled nodes.}
        with spillednodes do
          for i:=0 to length-1 do
            begin
              t:=buf^[i];
              {Alternative representation.}
              supregset_include(regs_to_spill_set,t);
              {Clear all interferences of the spilled register.}
              clear_interferences(t);
              {Get a temp for the spilled register, the size must at least equal a complete register,
               take also care of the fact that subreg can be larger than a single register like doubles
               that occupy 2 registers }
              tg.gettemp(templist,
                         max(tcgsize2size[reg_cgsize(newreg(regtype,t,R_SUBWHOLE))],
                             tcgsize2size[reg_cgsize(newreg(regtype,t,reginfo[t].subreg))]),
                         tt_noreuse,spill_temps^[t]);
            end;
        list.insertlistafter(headertai,templist);
        templist.free;
        { Walk through all instructions, we can start with the headertai,
          because before the header tai is only symbols }
        p:=headertai;
        while assigned(p) do
          begin
            case p.typ of
              ait_regalloc:
                with Tai_regalloc(p) do
                  begin
                    if (getregtype(reg)=regtype) then
                      begin
                        {A register allocation of a spilled register can be removed.}
                        supreg:=getsupreg(reg);
                        if supregset_in(regs_to_spill_set,supreg) then
                          begin
                            q:=Tai(p.next);
                            list.remove(p);
                            p.free;
                            p:=q;
                            continue;
                          end
                        else
                          begin
                            case ratype of
                              ra_alloc :
                               live_registers.add(supreg);
                              ra_dealloc :
                               live_registers.delete(supreg);
                            end;
                          end;
                      end;
                  end;
              ait_instruction:
                with Taicpu(p) do
                  begin
                    aktfilepos:=fileinfo;
                    if instr_spill_register(list,taicpu(p),regs_to_spill_set,spill_temps^) then
                      spill_registers:=true;
                  end;
            end;
            p:=Tai(p.next);
          end;
        aktfilepos:=current_procinfo.exitpos;
        {Safe: this procedure is only called if there are spilled nodes.}
        with spillednodes do
          for i:=0 to length-1 do
            tg.ungettemp(list,spill_temps^[buf^[i]]);
        freemem(spill_temps);
      end;


    function trgobj.do_spill_replace(list:Taasmoutput;instr:taicpu;orgreg:tsuperregister;const spilltemp:treference):boolean;
      begin
        result:=false;
      end;


    procedure Trgobj.do_spill_read(list:Taasmoutput;pos:tai;const spilltemp:treference;tempreg:tregister);
      begin
        list.insertafter(spilling_create_load(spilltemp,tempreg),pos);
      end;


    procedure Trgobj.do_spill_written(list:Taasmoutput;pos:tai;const spilltemp:treference;tempreg:tregister);
      begin
        list.insertafter(spilling_create_store(tempreg,spilltemp),pos);
      end;


    function trgobj.get_spill_subreg(r : tregister) : tsubregister;
      begin
        result:=defaultsub;
      end;


    function trgobj.instr_spill_register(list:Taasmoutput;
                                         instr:taicpu;
                                         const r:Tsuperregisterset;
                                         const spilltemplist:Tspill_temp_list): boolean;
      var
        counter, regindex: longint;
        regs: tspillregsinfo;
        spilled: boolean;

      procedure addreginfo(reg: tregister; operation: topertype);
        var
          i, tmpindex: longint;
          supreg : tsuperregister;
        begin
          tmpindex := regindex;
          supreg:=getsupreg(reg);
          { did we already encounter this register? }
          for i := 0 to pred(regindex) do
            if (regs[i].orgreg = supreg) then
              begin
                tmpindex := i;
                break;
              end;
          if tmpindex > high(regs) then
            internalerror(2003120301);
          regs[tmpindex].orgreg := supreg;
          regs[tmpindex].spillreg:=reg;
          if supregset_in(r,supreg) then
            begin
              { add/update info on this register }
              regs[tmpindex].mustbespilled := true;
              case operation of
                operand_read:
                  regs[tmpindex].regread := true;
                operand_write:
                  regs[tmpindex].regwritten := true;
                operand_readwrite:
                  begin
                    regs[tmpindex].regread := true;
                    regs[tmpindex].regwritten := true;
                  end;
              end;
              spilled := true;
            end;
          inc(regindex,ord(regindex=tmpindex));
        end;


      procedure tryreplacereg(var reg: tregister);
        var
          i: longint;
          supreg: tsuperregister;
        begin
          supreg:=getsupreg(reg);
          for i:=0 to pred(regindex) do
            if (regs[i].mustbespilled) and
               (regs[i].orgreg=supreg) then
              begin
                { Only replace supreg }
                setsupreg(reg,getsupreg(regs[i].tempreg));
                break;
              end;
        end;

      var
        loadpos,
        storepos : tai;
        oldlive_registers : tsuperregisterworklist;
      begin
        result := false;
        fillchar(regs,sizeof(regs),0);
        for counter := low(regs) to high(regs) do
          regs[counter].orgreg := RS_INVALID;
        spilled := false;
        regindex := 0;

        { check whether and if so which and how (read/written) this instructions contains
          registers that must be spilled }
        for counter := 0 to instr.ops-1 do
         with instr.oper[counter]^ do
          begin
            case typ of
              top_reg:
                begin
                  if (getregtype(reg) = regtype) then
                    addreginfo(reg,instr.spilling_get_operation_type(counter));
                end;
              top_ref:
                begin
                  if regtype in [R_INTREGISTER,R_ADDRESSREGISTER] then
                    with ref^ do
                      begin
                        if (base <> NR_NO) then
                          addreginfo(base,operand_read);
                        if (index <> NR_NO) then
                          addreginfo(index,operand_read);
                      end;
                end;
{$ifdef ARM}
              top_shifterop:
                begin
                  if regtype in [R_INTREGISTER,R_ADDRESSREGISTER] then
                    if shifterop^.rs<>NR_NO then
                      addreginfo(shifterop^.rs,operand_read);
                end;
{$endif ARM}
            end;
          end;

        { if no spilling for this instruction we can leave }
        if not spilled then
          exit;

{$ifdef x86}
        { Try replacing the register with the spilltemp. This is usefull only
          for the i386,x86_64 that support memory locations for several instructions }
        for counter := 0 to pred(regindex) do
          with regs[counter] do
            begin
              if mustbespilled then
                begin
                  if do_spill_replace(list,instr,orgreg,spilltemplist[orgreg]) then
                    mustbespilled:=false;
                end;
            end;
{$endif x86}

        {
          There are registers that need are spilled. We generate the
          following code for it. The used positions where code need
          to be inserted are marked using #. Note that code is always inserted
          before the positions using pos.previous. This way the position is always
          the same since pos doesn't change, but pos.previous is modified everytime
          new code is inserted.

          [
            - reg_allocs load spills
            - load spills
          ]
          [#loadpos
            - reg_deallocs
            - reg_allocs
          ]
          [
            - reg_deallocs for load-only spills
            - reg_allocs for store-only spills
          ]
          [#instr
            - original instruction
          ]
          [
            - store spills
            - reg_deallocs store spills
          ]
          [#storepos
          ]
        }

        result := true;
        oldlive_registers.copyfrom(live_registers);

        { Process all tai_regallocs belonging to this instruction. All
          released registers are also added to the live_registers because
          they can't be used during the spilling }
        loadpos:=tai(instr.previous);
        while assigned(loadpos) and
              (loadpos.typ=ait_regalloc) and
              (tai_regalloc(loadpos).instr=instr) do
          begin
            if tai_regalloc(loadpos).ratype=ra_dealloc then
              live_registers.add(getsupreg(tai_regalloc(loadpos).reg));
            loadpos:=tai(loadpos.previous);
          end;
        loadpos:=tai(loadpos.next);

        { Load the spilled registers }
        for counter := 0 to pred(regindex) do
          with regs[counter] do
            begin
              if mustbespilled and regread then
                begin
                  tempreg:=getregisterinline(list,get_spill_subreg(regs[counter].spillreg));
                  do_spill_read(list,tai(loadpos.previous),spilltemplist[orgreg],tempreg);
                end;
            end;

        { Release temp registers of read-only registers, and add reference of the instruction
          to the reginfo }
        for counter := 0 to pred(regindex) do
          with regs[counter] do
            begin
              if mustbespilled and regread and (not regwritten) then
                begin
                  { The original instruction will be the next that uses this register }
                  add_reg_instruction(instr,tempreg);
                  ungetregisterinline(list,tempreg);
                end;
            end;

        { Allocate temp registers of write-only registers, and add reference of the instruction
          to the reginfo }
        for counter := 0 to pred(regindex) do
          with regs[counter] do
            begin
              if mustbespilled and regwritten then
                begin
                  { When the register is also loaded there is already a register assigned }
                  if (not regread) then
                    tempreg:=getregisterinline(list,get_spill_subreg(regs[counter].spillreg));
                  { The original instruction will be the next that uses this register, this
                    also needs to be done for read-write registers }
                  add_reg_instruction(instr,tempreg);
                end;
            end;

        { store the spilled registers }
        storepos:=tai(instr.next);
        for counter := 0 to pred(regindex) do
          with regs[counter] do
            begin
              if mustbespilled and regwritten then
                begin
                  do_spill_written(list,tai(storepos.previous),spilltemplist[orgreg],tempreg);
                  ungetregisterinline(list,tempreg);
                end;
            end;

        { now all spilling code is generated we can restore the live registers. This
          must be done after the store because the store can need an extra register
          that also needs to conflict with the registers of the instruction }
        live_registers.done;
        live_registers:=oldlive_registers;

        { substitute registers }
        for counter:=0 to instr.ops-1 do
         with instr.oper[counter]^ do
          begin
            case typ of
              top_reg:
                begin
                  if (getregtype(reg) = regtype) then
                    tryreplacereg(reg);
                end;
              top_ref:
                begin
                  if regtype in [R_INTREGISTER,R_ADDRESSREGISTER] then
                    begin
                      tryreplacereg(ref^.base);
                      tryreplacereg(ref^.index);
                    end;
                end;
{$ifdef ARM}
              top_shifterop:
                begin
                  if regtype in [R_INTREGISTER,R_ADDRESSREGISTER] then
                    tryreplacereg(shifterop^.rs);
                end;
{$endif ARM}
            end;
          end;
      end;

end.
{
  $Log$
  Revision 1.151  2004-11-06 18:58:18  florian
    * debug writeln removed

  Revision 1.150  2004/11/06 17:44:47  florian
    + additional extdebug check for wrong add_reg_instructions added
    * too long manglednames are cut off at 200 chars using a crc

  Revision 1.149  2004/11/01 10:34:08  peter
    * regalloc bind to instructions need to get real ait_instruction

  Revision 1.148  2004/10/31 23:18:29  jonas
    * make sure live_start/end is never a tai_regalloc, as those can be
      removed by the register allocator and thus become invalid. This fixed
      make cycle with -Or for ppc, but I'm not sure what the warning on
      symsym.pas:1663 means. Since the tlocation change, even regular make
      cycle doesn't work anymore though...

  Revision 1.147  2004/10/31 21:45:03  peter
    * generic tlocation
    * move tlocation to cgutils

  Revision 1.146  2004/10/31 16:04:30  florian
    * fixed compilation of system unit on arm

  Revision 1.145  2004/10/30 15:21:37  florian
    * fixed generic optimizer
    * enabled generic optimizer for sparc

  Revision 1.144  2004/10/24 17:04:01  peter
    * during translation only process regalloc for the current regtype

  Revision 1.143  2004/10/15 09:14:17  mazen
  - remove $IFDEF DELPHI and related code
  - remove $IFDEF FPCPROCVAR and related code

  Revision 1.142  2004/10/13 21:12:51  peter
    * -Or fixes for open array

  Revision 1.141  2004/10/11 15:47:03  peter
    * removed warning about register used only once

  Revision 1.140  2004/10/06 20:14:08  peter
    * live_registers must be restored after the spilling store code
      is generate to add correct conflicts for extra temporary registers

  Revision 1.139  2004/10/05 20:41:01  peter
    * more spilling rewrites

  Revision 1.138  2004/10/04 20:46:22  peter
    * spilling code rewritten for x86. It now used the generic
      spilling routines. Special x86 optimization still needs
      to be added.
    * Spilling fixed when both operands needed to be spilled
    * Cleanup of spilling routine, do_spill_readwritten removed

  Revision 1.137  2004/09/26 17:45:30  peter
    * simple regvar support, not yet finished

  Revision 1.136  2004/09/25 14:23:54  peter
    * ungetregister is now only used for cpuregisters, renamed to
      ungetcpuregister
    * renamed (get|unget)explicitregister(s) to ..cpuregister
    * removed location-release/reference_release

  Revision 1.135  2004/09/21 17:25:12  peter
    * paraloc branch merged

  Revision 1.134.4.2  2004/09/21 17:03:26  peter
    * Include aliases of coalesce registers when adding conflicts

  Revision 1.134.4.1  2004/09/12 13:36:40  peter
    * fixed alignment issues

  Revision 1.134  2004/08/24 21:02:32  florian
    * fixed longbool(<int64>) on sparc

  Revision 1.133  2004/07/09 21:38:30  daniel
    * Add check <= 255 when adding to adj_colours

  Revision 1.132  2004/07/08 09:57:55  daniel
    * Use a normal pascal set in assign_colours, since it only will contain
      real registers

  Revision 1.131  2004/07/07 17:35:26  daniel
    * supregset_reset clears 8kb of memory. However, it is being called in
      inner loops, see for example colour_registers. According to profile data
      this causes fillchar to be the most time consuming procedure.
      Some modifications done to make it clear less than 8kb of memory each
      call. Divides time spent in fillchar by two, but it still is the no.1
      procedure.

  Revision 1.130  2004/06/22 18:24:18  florian
    * fixed arm compilation

  Revision 1.129  2004/06/20 08:55:30  florian
    * logs truncated

  Revision 1.128  2004/06/20 08:47:33  florian
    * spilling of doubles on sparc fixed

  Revision 1.127  2004/06/16 20:07:09  florian
    * dwarf branch merged

  Revision 1.126  2004/05/22 23:34:28  peter
  tai_regalloc.allocation changed to ratype to notify rgobj of register size changes

  Revision 1.125  2004/04/26 19:57:50  jonas
    * do not remove "allocation,deallocation" pairs, as those are important
      for the optimizer

  Revision 1.124.2.3  2004/06/13 10:51:16  florian
    * fixed several register allocator problems (sparc/arm)

}
