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

{#******************************************************************************

@abstract(Abstract register allocator unit)

Register allocator introduction.

Free Pascal uses a Chaitin style register allocator. We use a variant similair
to the one described in the book "Modern compiler implementation in C" by
Andrew W. Appel., published by Cambridge University Press.

The register allocator that is described by Appel uses a much improved way
of register coalescing, called "iterated register coalescing". Instead
of doing coalescing as a prepass to the register allocation, the coalescing
is done inside the register allocator. This has the advantage that the
register allocator can coalesce very aggresively without introducing spills.

Reading this book is recommended for a complete understanding. Here is a small
introduction.
The code generator thinks it has an infinite amount of registers. Our processor
has a limited amount of registers. Therefore we must reduce the amount of
registers until there are less enough to fit into the processors registers.

Registers can interfere or not interfere. If two imaginary registers interfere
they cannot be placed into the same psysical register. Reduction of registers
is done by:

- "coalescing" Two registers that do not interfere are combined
   into one register.
- "spilling" A register is changed into a memory location and the generated
   code is modified to use the memory location instead of the register.

Register allocation is a graph colouring problem. Each register is a colour, and
if two registers interfere there is a connection between them in the graph.

In addition to the imaginary registers in the code generator, the psysical
CPU registers are also present in this graph. This allows us to make
interferences between imaginary registers and cpu registers. This is very
usefull for describing architectural constraints, like for example that
the div instruction modifies edx, so variables that are in use at that time
cannot be stored into edx. This can be modelled by making edx interfere
with those variables.

Graph colouring is an NP complete problem. Therefore we use an approximation
that pushes registers to colour on to a stack. This is done in the "simplify"
procedure.

The register allocator first checks which registers are a candidate for
coalescing.

*******************************************************************************}


unit rgobj;

  interface

    uses
      cutils, cpubase,
      aasmbase,aasmtai,aasmcpu,
      cclasses,globtype,cgbase,node,
{$ifdef delphi}
      dmisc,
{$endif}
      cpuinfo
      ;

    type
{
       regvarother_longintarray = array[tregisterindex] of longint;
       regvarother_booleanarray = array[tregisterindex] of boolean;
       regvarint_longintarray = array[first_int_supreg..last_int_supreg] of longint;
       regvarint_ptreearray = array[first_int_supreg..last_int_supreg] of tnode;
}

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

      Tmovelist=record
        count:cardinal;
        data:array[0..$ffff] of Tlinkedlistitem;
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
//        is_reg_var : Tsuperregisterset; {old regvars}
//        reg_var_loaded:Tsuperregisterset; {old regvars}

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
        procedure getexplicitregister(list:Taasmoutput;r:Tregister);virtual;
        {# Get multiple registers specified.}
        procedure allocexplicitregisters(list:Taasmoutput;r:Tcpuregisterset);virtual;
        {# Free multiple registers specified.}
        procedure deallocexplicitregisters(list:Taasmoutput;r:Tcpuregisterset);virtual;
        function uses_registers:boolean;virtual;
        {# Deallocate any kind of register }
        procedure ungetregister(list:Taasmoutput;r:Tregister);virtual;
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
        function  get_insert_pos(p:Tai;huntfor1,huntfor2,huntfor3:Tsuperregister):Tai;
        procedure forward_allocation(pfrom,pto:Tai);
        procedure getregisterinline(list:Taasmoutput;position:Tai;subreg:Tsubregister;var result:Tregister);
        procedure ungetregisterinline(list:Taasmoutput;position:Tai;r:Tregister);
        procedure add_constraints(reg:Tregister);virtual;

        procedure do_spill_read(list:Taasmoutput;instr:Taicpu_abstract;
                                pos:Tai;regidx:word;
                                const spilltemplist:Tspill_temp_list;
                                const regs:Tspillregsinfo);virtual;
        procedure do_spill_written(list:Taasmoutput;instr:Taicpu_abstract;
                                   pos:Tai;regidx:word;
                                   const spilltemplist:Tspill_temp_list;
                                   const regs:Tspillregsinfo);virtual;
        procedure do_spill_readwritten(list:Taasmoutput;instr:Taicpu_abstract;
                                       pos:Tai;regidx:word;
                                       const spilltemplist:Tspill_temp_list;
                                       const regs:Tspillregsinfo);virtual;

        function instr_spill_register(list:Taasmoutput;
                                      instr:taicpu_abstract;
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
        {# Spills certain registers in the specified assembler list.}
        procedure insert_regalloc_info(list:Taasmoutput;headertai:tai);
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
         if defaultsub=R_SUBNONE then
           result:=newreg(regtype,getnewreg(R_SUBNONE),R_SUBNONE)
         else
           result:=newreg(regtype,getnewreg(subreg),subreg);
      end;


    function trgobj.uses_registers:boolean;
      begin
        result:=(maxreg>first_imaginary);
      end;


    procedure trgobj.ungetregister(list:Taasmoutput;r:Tregister);
      begin
        { Only explicit allocs insert regalloc info }
        if getsupreg(r)<first_imaginary then
          list.concat(Tai_regalloc.dealloc(r));
      end;


    procedure trgobj.getexplicitregister(list:Taasmoutput;r:Tregister);
      var
        supreg:Tsuperregister;
      begin
        supreg:=getsupreg(r);
        if supreg>=first_imaginary then
          internalerror(2003121503);
        include(used_in_proc,supreg);
        list.concat(Tai_regalloc.alloc(r));
      end;


    procedure trgobj.allocexplicitregisters(list:Taasmoutput;r:Tcpuregisterset);

    var i:Tsuperregister;

    begin
      for i:=0 to first_imaginary-1 do
        if i in r then
          getexplicitregister(list,newreg(regtype,i,defaultsub));
    end;


    procedure trgobj.deallocexplicitregisters(list:Taasmoutput;r:Tcpuregisterset);

    var i:Tsuperregister;

    begin
      for i:=0 to first_imaginary-1 do
        if i in r then
          ungetregister(list,newreg(regtype,i,defaultsub));
    end;


    procedure trgobj.do_register_allocation(list:Taasmoutput;headertai:tai);
      var
        spillingcounter:byte;
        endspill:boolean;
        i:Tsuperregister;
      begin
        { Insert regalloc info for imaginary registers }
        insert_regalloc_info(list,headertai);
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
            add_edge(u,buf^[i]);
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

    var cursize:cardinal;

    begin
      with reginfo[u] do
        begin
          if movelist=nil then
            begin
              getmem(movelist,64);
              movelist^.count:=0;
            end
          else
            begin
              cursize:=memsize(movelist);
              if (4*(movelist^.count+1)=cursize) then
                reallocmem(movelist,cursize*2);
            end;
          movelist^.data[movelist^.count]:=data;
          inc(movelist^.count);
        end;
    end;


    procedure trgobj.add_reg_instruction(instr:Tai;r:tregister);
      var
        supreg : tsuperregister;
      begin
        supreg:=getsupreg(r);
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
            for i:=0 to count-1 do
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

    var p,h,i,j,leni,lenj:word;
        t:Tsuperregister;
        adji,adjj:Psuperregisterworklist;

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
              for h:=0 to length-p-1 do
                begin
                  i:=h;
                  repeat
                    j:=i+p;
                    adji:=reginfo[buf^[i]].adjlist;
                    adjj:=reginfo[buf^[j]].adjlist;
                    if adji=nil then
                      leni:=0
                    else
                      leni:=adji^.length;
                    if adjj=nil then
                      lenj:=0
                    else
                      lenj:=adjj^.length;
                    if lenj>=leni then
                      break;
                    t:=buf^[i];
                    buf^[i]:=buf^[j];
                    buf^[j]:=t;
                    if i<p then
                      break;
                    dec(i,p)
                  until false;
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

    var i:word;

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
          for i:=0 to movelist^.count-1 do
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
      supregset_reset(done,false);
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
        i : word;
        t : tsuperregister;
        n,o : cardinal;
        decrement : boolean;
{	moves:Tsuperregisterset;}
        vm:Pmovelist;

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
       between them.}

{     Nice attempt; it didn't work.
      supregset_reset(moves,false);
      supregset_include(moves,u);
      with reginfo[u].movelist^ do
        for n:=0 to count-1 do
	  begin
	    if Tmoveins(data[n]).x=u then
              supregset_include(moves,Tmoveins(data[n]).y)
	    else
              supregset_include(moves,Tmoveins(data[n]).x)
          end;
      with reginfo[v].movelist^ do
        for n:=0 to count-1 do
	  begin
	    if Tmoveins(data[n]).x=v then
	      begin
	        if supregset_in(moves,Tmoveins(data[n]).y) then
        	  add_to_movelist(u,data[n]);
              end
	    else
	      begin
	        if supregset_in(moves,Tmoveins(data[n]).x) then
        	  add_to_movelist(u,data[n]);
              end;
	  end;}

      {This loop is a performance bottleneck for large procedures and therefore
       optimized by hand as much as possible. This is because machine registers
       generally collect large movelists (for example around procedure calls data
       is moved into machine registers). The loop below is unfortunately quadratic,
       and guess what this means when a procedure has collected several thousand
       moves.... Test webtbs/tw2242 is a good example to illustrate this.}
      vm:=reginfo[v].movelist;
      for n:=0 to vm^.count-1 do
        with reginfo[u].movelist^ do
          begin
            for o:=0 to count-1 do
              if data[o]=vm^.data[n] then
                goto l1; {Continue outer loop.}
            add_to_movelist(u,vm^.data[n]);
          l1:
          end;

      enable_moves(v);

      adj:=reginfo[v].adjlist;
      if adj<>nil then
        for i:=1 to adj^.length do
          begin
            t:=adj^.buf^[i-1];
            if not(ri_coalesced in reginfo[t].flags) then
              begin
                {t has a connection to v. Since we are adding v to u, we
                 need to connect t to u. However, beware if t was already
                 connected to u...}
                if (ibitmap[t,u]) and not (ri_selected in reginfo[t].flags) then
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
                    if (u>=first_imaginary) and not (ri_selected in reginfo[t].flags) then
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
        for i:=0 to reginfo[u].movelist^.count-1 do
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
        adj_colours,
        colourednodes : Tsuperregisterset;
        found : boolean;

    begin
      spillednodes.clear;
      {Reset colours}
      for n:=0 to maxreg-1 do
        reginfo[n].colour:=n;
      {Colour the cpu registers...}
      supregset_reset(colourednodes,false);
      for n:=0 to first_imaginary-1 do
        supregset_include(colourednodes,n);
      {Now colour the imaginary registers on the select-stack.}
      for i:=selectstack.length downto 1 do
        begin
          n:=selectstack.buf^[i-1];
          {Create a list of colours that we cannot assign to n.}
          supregset_reset(adj_colours,false);
          adj:=reginfo[n].adjlist;
          if adj<>nil then
            for j:=0 to adj^.length-1 do
              begin
                a:=get_alias(adj^.buf^[j]);
                if supregset_in(colourednodes,a) then
                  supregset_include(adj_colours,reginfo[a].colour);
              end;
            supregset_include(adj_colours,RS_STACK_POINTER_REG);
          {Assume a spill by default...}
          found:=false;
          {Search for a colour not in this list.}
          for k:=0 to usable_registers_cnt-1 do
            begin
              c:=usable_registers[k];
              if not(supregset_in(adj_colours,c)) then
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
{$ifdef ra_debug}
      if aktfilepos.line=179 then
        begin
          writeln('colourlist');
          for i:=0 to maxreg-1 do
            writeln(i:4,'   ',reginfo[i].colour:4)
        end;
{$endif ra_debug}
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

    procedure trgobj.getregisterinline(list:Taasmoutput;
                  position:Tai;subreg:Tsubregister;var result:Tregister);
    var p:Tsuperregister;
        r:Tregister;
    begin
       p:=getnewreg(subreg);
       live_registers.add(p);
       r:=newreg(regtype,p,subreg);
       if position=nil then
         list.insert(Tai_regalloc.alloc(r))
       else
         list.insertafter(Tai_regalloc.alloc(r),position);
       add_edges_used(p);
       add_constraints(r);
       result:=r;
    end;


    procedure trgobj.ungetregisterinline(list:Taasmoutput;
                position:Tai;r:Tregister);

    var supreg:Tsuperregister;

    begin
      supreg:=getsupreg(r);
      live_registers.delete(supreg);
      if position=nil then
        list.insert(Tai_regalloc.dealloc(r))
      else
        list.insertafter(Tai_regalloc.dealloc(r),position);
    end;


    procedure trgobj.insert_regalloc_info(list:Taasmoutput;headertai:tai);
      var
        supreg : tsuperregister;
        p : tai;
        r : tregister;
      begin
        { Insert regallocs for all imaginary registers }
        for supreg:=first_imaginary to maxreg-1 do
          with reginfo[supreg] do
            begin
              r:=newreg(regtype,supreg,subreg);
              if assigned(live_start) then
                begin
{$ifdef EXTDEBUG}
                  if live_start=live_end then
                    Comment(V_Warning,'Register '+std_regname(r)+' is only used once');
{$endif EXTDEBUG}
                  list.insertbefore(Tai_regalloc.alloc(r),live_start);
                  { Insert live end deallocation before reg allocations
                  to reduce conflicts }
                  p:=live_end;
                  while assigned(p) and
                        assigned(p.previous) and
                        (tai(p.previous).typ=ait_regalloc) and
                         tai_regalloc(p.previous).allocation and
                        (tai_regalloc(p.previous).reg<>r) do
                    p:=tai(p.previous);
                  list.insertbefore(Tai_regalloc.dealloc(r),p);
                end
{$ifdef EXTDEBUG}
              else
                Comment(V_Warning,'Register '+std_regname(r)+' not used');
{$endif EXTDEBUG}
            end;
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
                      if allocation then
                        live_registers.add(supreg)
                      else
                        live_registers.delete(supreg);
                      add_edges_used(supreg);
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
                      setsupreg(reg,reginfo[getsupreg(reg)].colour);
  
                    {
                      Remove sequences of release and
                      allocation of the same register like:
  
                         # Register X released
                         # Register X allocated
                    }
                    if assigned(previous) and
                       (Tai(previous).typ=ait_regalloc) and
                       (Tai_regalloc(previous).reg=reg) and
                       { allocation,deallocation or deallocation,allocation }
                       (Tai_regalloc(previous).allocation xor allocation) then
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
              ait_instruction:
                with Taicpu_abstract(p) do
                  begin
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
                              so:=shifterop;
                              if so^.rs<>NR_NO then
                                setsupreg(so^.rs,reginfo[getsupreg(so^.rs)].colour);
                            end;
{$endif arm}
                        end;
  
                    { Maybe the operation can be removed when
                      it is a move and both arguments are the same }
                    if is_same_reg_move then
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
      end;


    function trgobj.get_insert_pos(p:Tai;huntfor1,huntfor2,huntfor3:Tsuperregister):Tai;
      var
        back   : Tsuperregisterworklist;
        supreg : tsuperregister;
      begin
        back.copyfrom(live_registers);
        result:=p;
        while (p<>nil) and (p.typ=ait_regalloc) do
          begin
            supreg:=getsupreg(Tai_regalloc(p).reg);
            {Rewind the register allocation.}
            if Tai_regalloc(p).allocation then
              live_registers.delete(supreg)
            else
              begin
                live_registers.add(supreg);
                if supreg=huntfor1 then
                  begin
                    get_insert_pos:=Tai(p.previous);
                    back.done;
                    back.copyfrom(live_registers);
                  end;
                if supreg=huntfor2 then
                  begin
                    get_insert_pos:=Tai(p.previous);
                    back.done;
                    back.copyfrom(live_registers);
                  end;
                if supreg=huntfor3 then
                  begin
                    get_insert_pos:=Tai(p.previous);
                    back.done;
                    back.copyfrom(live_registers);
                  end;
              end;
            p:=Tai(p.previous);
          end;
        live_registers.done;
        live_registers:=back;
      end;


    procedure trgobj.forward_allocation(pfrom,pto:Tai);
      var
        p : tai;
      begin
        {Forward the register allocation again.}
        p:=pfrom;
        while (p<>pto) do
          begin
            if p.typ<>ait_regalloc then
              internalerror(200305311);
            if Tai_regalloc(p).allocation then
              live_registers.add(getsupreg(Tai_regalloc(p).reg))
            else
              live_registers.delete(getsupreg(Tai_regalloc(p).reg));
            p:=Tai(p.next);
          end;
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
        supregset_reset(regs_to_spill_set,false);
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
              {Get a temp for the spilled register}
              tg.gettemp(templist,4,tt_noreuse,spill_temps^[t]);
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
                          if allocation then
                            live_registers.add(supreg)
                          else
                            live_registers.delete(supreg);
                      end;
                  end;
              ait_instruction:
                with Taicpu_abstract(p) do
                  begin
                    aktfilepos:=fileinfo;
                    if instr_spill_register(list,Taicpu_abstract(p),regs_to_spill_set,spill_temps^) then
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


    procedure Trgobj.do_spill_read(list:Taasmoutput;instr:Taicpu_abstract;
                                   pos:Tai;regidx:word;
                                   const spilltemplist:Tspill_temp_list;
                                   const regs:Tspillregsinfo);

    var helpins:Tai;

    begin
      with regs[regidx] do
        begin
          helpins:=instr.spilling_create_load(spilltemplist[orgreg],tempreg);
          if pos=nil then
            list.insertafter(helpins,list.first)
          else
            list.insertafter(helpins,pos.next);
          ungetregisterinline(list,instr,tempreg);
          forward_allocation(tai(helpins.next),instr);
        end;
    end;


    procedure Trgobj.do_spill_written(list:Taasmoutput;instr:Taicpu_abstract;
                                      pos:Tai;regidx:word;
                                      const spilltemplist:Tspill_temp_list;
                                      const regs:Tspillregsinfo);

    var helpins:Tai;

    begin
      with regs[regidx] do
        begin
          helpins:=instr.spilling_create_store(tempreg,spilltemplist[orgreg]);
          list.insertafter(helpins,instr);
          ungetregisterinline(list,helpins,tempreg);
        end;
    end;


    procedure Trgobj.do_spill_readwritten(list:Taasmoutput;instr:Taicpu_abstract;
                                          pos:Tai;regidx:word;
                                          const spilltemplist:Tspill_temp_list;
                                          const regs:Tspillregsinfo);

    var helpins1,helpins2:Tai;

    begin
      with regs[regidx] do
        begin
          helpins1:=instr.spilling_create_load(spilltemplist[orgreg],tempreg);
          if pos=nil then
            list.insertafter(helpins1,list.first)
          else
            list.insertafter(helpins1,pos.next);
          helpins2:=instr.spilling_create_store(tempreg,spilltemplist[orgreg]);
          list.insertafter(helpins2,instr);
          ungetregisterinline(list,helpins2,tempreg);
          forward_allocation(tai(helpins1.next),instr);
        end;
    end;


    function trgobj.instr_spill_register(list:Taasmoutput;
                                         instr:taicpu_abstract;
                                         const r:Tsuperregisterset;
                                         const spilltemplist:Tspill_temp_list): boolean;
      var
        counter, regindex: longint;
        pos: tai;
        regs: tspillregsinfo;
        spilled: boolean;

      procedure addreginfo(reg: tsuperregister; operation: topertype);
        var
          i, tmpindex: longint;
        begin
          tmpindex := regindex;
          // did we already encounter this register?
          for i := 0 to pred(regindex) do
            if (regs[i].orgreg = reg) then
              begin
                tmpindex := i;
                break;
              end;
          if tmpindex > high(regs) then
            internalerror(2003120301);
          regs[tmpindex].orgreg := reg;
          if supregset_in(r,reg) then
            begin
              // add/update info on this register
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
          if (getregtype(reg) = R_INTREGISTER) then
            begin
              supreg := getsupreg(reg);
              for i := 0 to pred(regindex) do
                if (regs[i].mustbespilled) and
                   (regs[i].orgreg = supreg) then
                  begin
                    reg := regs[i].tempreg;
                    break;
                  end;
            end;
        end;


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
                    addreginfo(getsupreg(reg),instr.spilling_get_operation_type(counter));
                end;
              top_ref:
                begin
                  if regtype in [R_INTREGISTER,R_ADDRESSREGISTER] then
                    with ref^ do
                      begin
                        if (base <> NR_NO) then
                          addreginfo(getsupreg(base),operand_read);
                        if (index <> NR_NO) then
                          addreginfo(getsupreg(index),operand_read);
                      end;
                end;
{$ifdef ARM}
              top_shifterop:
                begin
                  if shifterop^.rs<>NR_NO then
                    addreginfo(getsupreg(shifterop^.rs),operand_read);
                end;
{$endif ARM}
            end;
          end;

        { if no spilling for this instruction we can leave }
        if not spilled then
          exit;

        { generate the spilling code }
        result := true;
        for counter := 0 to pred(regindex) do
          with regs[counter] do
            begin
              if mustbespilled then
                begin
                  pos:=get_insert_pos(Tai(instr.previous),regs[0].orgreg,regs[1].orgreg,regs[2].orgreg);
                  getregisterinline(list,pos,defaultsub,tempreg);
                  if regread then
                    if regwritten then
                      do_spill_readwritten(list,instr,pos,counter,spilltemplist,regs)
                    else
                      do_spill_read(list,instr,pos,counter,spilltemplist,regs)
                  else
                    do_spill_written(list,instr,pos,counter,spilltemplist,regs)
                end;
            end;

        { substitute registers }
        for counter := 0 to instr.ops-1 do
         with instr.oper[counter]^ do
          begin
            case typ of
              top_reg:
                begin
                  tryreplacereg(reg);
                end;
              top_ref:
                begin
                  tryreplacereg(ref^.base);
                  tryreplacereg(ref^.index);
                end;
{$ifdef ARM}
              top_shifterop:
                begin
                  tryreplacereg(shifterop^.rs);
                end;
{$endif ARM}
            end;
          end;
      end;




end.
{
  $Log$
  Revision 1.118  2004-02-07 23:28:34  daniel
    * Take advantage of our new with statement optimization

  Revision 1.117  2004/02/06 13:34:46  daniel
    * Some changes to better accomodate very large movelists
      * movelist resizing now exponential (avoids heap fragmentation, saves
        300 kb memory in make cycle)
      * Trgobj.combine hand-optimized (still too slow)

  Revision 1.116  2004/01/28 22:16:31  peter
    * more record alignment fixes

  Revision 1.115  2004/01/26 17:40:11  florian
    * made DoSpill* overrideable
    + add_cpu_interferences added

  Revision 1.114  2004/01/26 16:12:28  daniel
    * reginfo now also only allocated during register allocation
    * third round of gdb cleanups: kick out most of concatstabto

  Revision 1.112  2004/01/12 16:37:59  peter
    * moved spilling code from taicpu to rg

  Revision 1.109  2003/12/26 14:02:30  peter
    * sparc updates
    * use registertype in spill_register

  Revision 1.108  2003/12/22 23:09:34  peter
    * only report unreleased imaginary registers

  Revision 1.107  2003/12/22 22:13:46  peter
    * made decrease_degree working, but not really fixed

  Revision 1.106  2003/12/18 17:06:21  florian
    * arm compiler compilation fixed

  Revision 1.105  2003/12/17 21:59:05  peter
    * don't insert dealloc before alloc of the same register

  Revision 1.104  2003/12/16 09:41:44  daniel
    * Automatic conversion from integer constants to pointer constants is no
      longer done except in Delphi mode

  Revision 1.103  2003/12/15 21:25:49  peter
    * reg allocations for imaginary register are now inserted just
      before reg allocation
    * tregister changed to enum to allow compile time check
    * fixed several tregister-tsuperregister errors

  Revision 1.102  2003/12/15 16:37:47  daniel
    * More microoptimizations

  Revision 1.101  2003/12/15 15:58:58  peter
    * fix statedebug compile

  Revision 1.100  2003/12/14 20:24:28  daniel
    * Register allocator speed optimizations
      - Worklist no longer a ringbuffer
      - No find operations are left
      - Simplify now done in constant time
      - unusedregs is now a Tsuperregisterworklist
      - Microoptimizations

  Revision 1.99  2003/12/12 17:16:17  peter
    * rg[tregistertype] added in tcg

  Revision 1.98  2003/12/04 23:27:32  peter
    * remove redundant calls to add_edge_used

  Revision 1.97  2003/11/29 17:36:41  peter
    * check for add_move_instruction

  Revision 1.96  2003/11/24 15:17:37  florian
    * changed some types to prevend range check errors

  Revision 1.95  2003/11/10 19:05:50  peter
    * fixed alias/colouring > 255

  Revision 1.94  2003/11/07 15:58:32  florian
    * Florian's culmutative nr. 1; contains:
      - invalid calling conventions for a certain cpu are rejected
      - arm softfloat calling conventions
      - -Sp for cpu dependend code generation
      - several arm fixes
      - remaining code for value open array paras on heap

  Revision 1.93  2003/10/30 16:22:40  peter
    * call firstpass before allocation and codegeneration is started
    * move leftover code from pass_2.generatecode() to psub

  Revision 1.92  2003/10/29 21:29:14  jonas
    * some ALLOWDUPREG improvements

  Revision 1.91  2003/10/21 15:15:36  peter
    * taicpu_abstract.oper[] changed to pointers

  Revision 1.90  2003/10/19 12:36:36  florian
    * improved speed; reduced memory usage of the interference bitmap

  Revision 1.89  2003/10/19 01:34:30  florian
    * some ppc stuff fixed
    * memory leak fixed

  Revision 1.88  2003/10/18 15:41:26  peter
    * made worklists dynamic in size

  Revision 1.87  2003/10/17 16:16:08  peter
    * fixed last commit

  Revision 1.86  2003/10/17 15:25:18  florian
    * fixed more ppc stuff

  Revision 1.85  2003/10/17 14:38:32  peter
    * 64k registers supported
    * fixed some memory leaks

  Revision 1.84  2003/10/11 16:06:42  florian
    * fixed some MMX<->SSE
    * started to fix ppc, needs an overhaul
    + stabs info improve for spilling, not sure if it works correctly/completly
    - MMX_SUPPORT removed from Makefile.fpc

  Revision 1.83  2003/10/10 17:48:14  peter
    * old trgobj moved to x86/rgcpu and renamed to trgx86fpu
    * tregisteralloctor renamed to trgobj
    * removed rgobj from a lot of units
    * moved location_* and reference_* to cgobj
    * first things for mmx register allocation

  Revision 1.82  2003/10/09 21:31:37  daniel
    * Register allocator splitted, ans abstract now

  Revision 1.81  2003/10/01 20:34:49  peter
    * procinfo unit contains tprocinfo
    * cginfo renamed to cgbase
    * moved cgmessage to verbose
    * fixed ppc and sparc compiles

  Revision 1.80  2003/09/30 19:54:42  peter
    * reuse registers with the least conflicts

  Revision 1.79  2003/09/29 20:58:56  peter
    * optimized releasing of registers

  Revision 1.78  2003/09/28 13:41:12  peter
    * return reg 255 when allowdupreg is defined

  Revision 1.77  2003/09/25 16:19:32  peter
    * fix filepositions
    * insert spill temp allocations at the start of the proc

  Revision 1.76  2003/09/16 16:17:01  peter
    * varspez in calls to push_addr_param

  Revision 1.75  2003/09/12 19:07:42  daniel
    * Fixed fast spilling functionality by re-adding the code that initializes
      precoloured nodes to degree 255. I would like to play hangman on the one
      who removed that code.

  Revision 1.74  2003/09/11 11:54:59  florian
    * improved arm code generation
    * move some protected and private field around
    * the temp. register for register parameters/arguments are now released
      before the move to the parameter register is done. This improves
      the code in a lot of cases.

  Revision 1.73  2003/09/09 20:59:27  daniel
    * Adding register allocation order

  Revision 1.72  2003/09/09 15:55:44  peter
    * use register with least interferences in spillregister

  Revision 1.71  2003/09/07 22:09:35  peter
    * preparations for different default calling conventions
    * various RA fixes

  Revision 1.70  2003/09/03 21:06:45  peter
    * fixes for FPU register allocation

  Revision 1.69  2003/09/03 15:55:01  peter
    * NEWRA branch merged

  Revision 1.68  2003/09/03 11:18:37  florian
    * fixed arm concatcopy
    + arm support in the common compiler sources added
    * moved some generic cg code around
    + tfputype added
    * ...

  Revision 1.67.2.5  2003/08/31 20:44:07  peter
    * fixed getexplicitregisterint tregister value

  Revision 1.67.2.4  2003/08/31 20:40:50  daniel
    * Fixed add_edges_used

  Revision 1.67.2.3  2003/08/29 17:28:59  peter
    * next batch of updates

  Revision 1.67.2.2  2003/08/28 18:35:08  peter
    * tregister changed to cardinal

  Revision 1.67.2.1  2003/08/27 19:55:54  peter
    * first tregister patch

  Revision 1.67  2003/08/23 10:46:21  daniel
    * Register allocator bugfix for h2pas

  Revision 1.66  2003/08/17 16:59:20  jonas
    * fixed regvars so they work with newra (at least for ppc)
    * fixed some volatile register bugs
    + -dnotranslation option for -dnewra, which causes the registers not to
      be translated from virtual to normal registers. Requires support in
      the assembler writer as well, which is only implemented in aggas/
      agppcgas currently

  Revision 1.65  2003/08/17 14:32:48  daniel
    * Precoloured nodes now have an infinite degree approached with 255,
      like they should.

  Revision 1.64  2003/08/17 08:48:02  daniel
   * Another register allocator bug fixed.
   * usable_registers_cnt set to 6 for i386

  Revision 1.63  2003/08/09 18:56:54  daniel
    * cs_regalloc renamed to cs_regvars to avoid confusion with register
      allocator
    * Some preventive changes to i386 spillinh code

  Revision 1.62  2003/08/03 14:09:50  daniel
    * Fixed a register allocator bug
    * Figured out why -dnewra generates superfluous "mov reg1,reg2"
      statements: changes in location_force. These moves are now no longer
      constrained so they are optimized away.

  Revision 1.61  2003/07/21 13:32:39  jonas
    * add_edges_used() is now also called for registers allocated with
      getexplicitregisterint()
    * writing the intereference graph is now only done with -dradebug2 and
      the created files are now called "igraph.<module_name>"

  Revision 1.60  2003/07/06 15:31:21  daniel
    * Fixed register allocator. *Lots* of fixes.

  Revision 1.59  2003/07/06 15:00:47  jonas
    * fixed my previous completely broken commit. It's not perfect though,
      registers > last_int_supreg and < max_intreg may still be "translated"

  Revision 1.58  2003/07/06 14:45:05  jonas
    * support integer registers that are not managed by newra (ie. don't
      translate register numbers that fall outside the range
      first_int_supreg..last_int_supreg)

  Revision 1.57  2003/07/02 22:18:04  peter
    * paraloc splitted in callerparaloc,calleeparaloc
    * sparc calling convention updates

  Revision 1.56  2003/06/17 16:34:44  jonas
    * lots of newra fixes (need getfuncretparaloc implementation for i386)!
    * renamed all_intregisters to volatile_intregisters and made it
      processor dependent

  Revision 1.55  2003/06/14 14:53:50  jonas
    * fixed newra cycle for x86
    * added constants for indicating source and destination operands of the
      "move reg,reg" instruction to aasmcpu (and use those in rgobj)

  Revision 1.54  2003/06/13 21:19:31  peter
    * current_procdef removed, use current_procinfo.procdef instead

  Revision 1.53  2003/06/12 21:11:10  peter
    * ungetregisterfpu gets size parameter

  Revision 1.52  2003/06/12 16:43:07  peter
    * newra compiles for sparc

  Revision 1.51  2003/06/09 14:54:26  jonas
    * (de)allocation of registers for parameters is now performed properly
      (and checked on the ppc)
    - removed obsolete allocation of all parameter registers at the start
      of a procedure (and deallocation at the end)

  Revision 1.50  2003/06/03 21:11:09  peter
    * cg.a_load_* get a from and to size specifier
    * makeregsize only accepts newregister
    * i386 uses generic tcgnotnode,tcgunaryminus

  Revision 1.49  2003/06/03 13:01:59  daniel
    * Register allocator finished

  Revision 1.48  2003/06/01 21:38:06  peter
    * getregisterfpu size parameter added
    * op_const_reg size parameter added
    * sparc updates

  Revision 1.47  2003/05/31 20:31:11  jonas
    * set inital costs of assigning a variable to a register to 120 for
      non-i386, because the used register must be store to memory at the
      start and loaded again at the end

  Revision 1.46  2003/05/30 18:55:21  jonas
    * fixed several regvar related bugs for non-i386. make cycle with -Or now
      works for ppc

  Revision 1.45  2003/05/30 12:36:13  jonas
    * use as little different registers on the ppc until newra is released,
      since every used register must be saved

  Revision 1.44  2003/05/17 13:30:08  jonas
    * changed tt_persistant to tt_persistent :)
    * tempcreatenode now doesn't accept a boolean anymore for persistent
      temps, but a ttemptype, so you can also create ansistring temps etc

  Revision 1.43  2003/05/16 14:33:31  peter
    * regvar fixes

  Revision 1.42  2003/04/26 20:03:49  daniel
    * Bug fix in simplify

  Revision 1.41  2003/04/25 20:59:35  peter
    * removed funcretn,funcretsym, function result is now in varsym
      and aliases for result and function name are added using absolutesym
    * vs_hidden parameter for funcret passed in parameter
    * vs_hidden fixes
    * writenode changed to printnode and released from extdebug
    * -vp option added to generate a tree.log with the nodetree
    * nicer printnode for statements, callnode

  Revision 1.40  2003/04/25 08:25:26  daniel
    * Ifdefs around a lot of calls to cleartempgen
    * Fixed registers that are allocated but not freed in several nodes
    * Tweak to register allocator to cause less spills
    * 8-bit registers now interfere with esi,edi and ebp
      Compiler can now compile rtl successfully when using new register
      allocator

  Revision 1.39  2003/04/23 20:23:06  peter
    * compile fix for no-newra

  Revision 1.38  2003/04/23 14:42:07  daniel
    * Further register allocator work. Compiler now smaller with new
      allocator than without.
    * Somebody forgot to adjust ppu version number

  Revision 1.37  2003/04/22 23:50:23  peter
    * firstpass uses expectloc
    * checks if there are differences between the expectloc and
      location.loc from secondpass in EXTDEBUG

  Revision 1.36  2003/04/22 10:09:35  daniel
    + Implemented the actual register allocator
    + Scratch registers unavailable when new register allocator used
    + maybe_save/maybe_restore unavailable when new register allocator used

  Revision 1.35  2003/04/21 19:16:49  peter
    * count address regs separate

  Revision 1.34  2003/04/17 16:48:21  daniel
    * Added some code to keep track of move instructions in register
      allocator

  Revision 1.33  2003/04/17 07:50:24  daniel
    * Some work on interference graph construction

  Revision 1.32  2003/03/28 19:16:57  peter
    * generic constructor working for i386
    * remove fixed self register
    * esi added as address register for i386

  Revision 1.31  2003/03/11 21:46:24  jonas
    * lots of new regallocator fixes, both in generic and ppc-specific code
      (ppc compiler still can't compile the linux system unit though)

  Revision 1.30  2003/03/09 21:18:59  olle
    + added cutils to the uses clause

  Revision 1.29  2003/03/08 20:36:41  daniel
    + Added newra version of Ti386shlshrnode
    + Added interference graph construction code

  Revision 1.28  2003/03/08 13:59:16  daniel
    * Work to handle new register notation in ag386nsm
    + Added newra version of Ti386moddivnode

  Revision 1.27  2003/03/08 10:53:48  daniel
    * Created newra version of secondmul in n386add.pas

  Revision 1.26  2003/03/08 08:59:07  daniel
    + $define newra will enable new register allocator
    + getregisterint will return imaginary registers with $newra
    + -sr switch added, will skip register allocation so you can see
      the direct output of the code generator before register allocation

  Revision 1.25  2003/02/26 20:50:45  daniel
    * Fixed ungetreference

  Revision 1.24  2003/02/19 22:39:56  daniel
    * Fixed a few issues

  Revision 1.23  2003/02/19 22:00:14  daniel
    * Code generator converted to new register notation
    - Horribily outdated todo.txt removed

  Revision 1.22  2003/02/02 19:25:54  carl
    * Several bugfixes for m68k target (register alloc., opcode emission)
    + VIS target
    + Generic add more complete (still not verified)

  Revision 1.21  2003/01/08 18:43:57  daniel
   * Tregister changed into a record

  Revision 1.20  2002/10/05 12:43:28  carl
    * fixes for Delphi 6 compilation
     (warning : Some features do not work under Delphi)

  Revision 1.19  2002/08/23 16:14:49  peter
    * tempgen cleanup
    * tt_noreuse temp type added that will be used in genentrycode

  Revision 1.18  2002/08/17 22:09:47  florian
    * result type handling in tcgcal.pass_2 overhauled
    * better tnode.dowrite
    * some ppc stuff fixed

  Revision 1.17  2002/08/17 09:23:42  florian
    * first part of procinfo rewrite

  Revision 1.16  2002/08/06 20:55:23  florian
    * first part of ppc calling conventions fix

  Revision 1.15  2002/08/05 18:27:48  carl
    + more more more documentation
    + first version include/exclude (can't test though, not enough scratch for i386 :()...

  Revision 1.14  2002/08/04 19:06:41  carl
    + added generic exception support (still does not work!)
    + more documentation

  Revision 1.13  2002/07/07 09:52:32  florian
    * powerpc target fixed, very simple units can be compiled
    * some basic stuff for better callparanode handling, far from being finished

  Revision 1.12  2002/07/01 18:46:26  peter
    * internal linker
    * reorganized aasm layer

  Revision 1.11  2002/05/18 13:34:17  peter
    * readded missing revisions

  Revision 1.10  2002/05/16 19:46:44  carl
  + defines.inc -> fpcdefs.inc to avoid conflicts if compiling by hand
  + try to fix temp allocation (still in ifdef)
  + generic constructor calls
  + start of tassembler / tmodulebase class cleanup

  Revision 1.8  2002/04/21 15:23:03  carl
  + makeregsize
  + changeregsize is now a local routine

  Revision 1.7  2002/04/20 21:32:25  carl
  + generic FPC_CHECKPOINTER
  + first parameter offset in stack now portable
  * rename some constants
  + move some cpu stuff to other units
  - remove unused constents
  * fix stacksize for some targets
  * fix generic size problems which depend now on EXTEND_SIZE constant

  Revision 1.6  2002/04/15 19:03:31  carl
  + reg2str -> std_reg2str()

  Revision 1.5  2002/04/06 18:13:01  jonas
    * several powerpc-related additions and fixes

  Revision 1.4  2002/04/04 19:06:04  peter
    * removed unused units
    * use tlocation.size in cg.a_*loc*() routines

  Revision 1.3  2002/04/02 17:11:29  peter
    * tlocation,treference update
    * LOC_CONSTANT added for better constant handling
    * secondadd splitted in multiple routines
    * location_force_reg added for loading a location to a register
      of a specified size
    * secondassignment parses now first the right and then the left node
      (this is compatible with Kylix). This saves a lot of push/pop especially
      with string operations
    * adapted some routines to use the new cg methods

  Revision 1.2  2002/04/01 19:24:25  jonas
    * fixed different parameter name in interface and implementation
      declaration of a method (only 1.0.x detected this)

  Revision 1.1  2002/03/31 20:26:36  jonas
    + a_loadfpu_* and a_loadmm_* methods in tcg
    * register allocation is now handled by a class and is mostly processor
      independent (+rgobj.pas and i386/rgcpu.pas)
    * temp allocation is now handled by a class (+tgobj.pas, -i386\tgcpu.pas)
    * some small improvements and fixes to the optimizer
    * some register allocation fixes
    * some fpuvaroffset fixes in the unary minus node
    * push/popusedregisters is now called rg.save/restoreusedregisters and
      (for i386) uses temps instead of push/pop's when using -Op3 (that code is
      also better optimizable)
    * fixed and optimized register saving/restoring for new/dispose nodes
    * LOC_FPU locations now also require their "register" field to be set to
      R_ST, not R_ST0 (the latter is used for LOC_CFPUREGISTER locations only)
    - list field removed of the tnode class because it's not used currently
      and can cause hard-to-find bugs

}
