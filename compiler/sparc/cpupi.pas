{*****************************************************************************
    $Id$
    Copyright (c) 2002 by Florian Klaempfl

    This unit contains the CPU specific part of tprocinfo

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

 ****************************************************************************}
{ This unit contains the CPU specific part of tprocinfo. }
unit cpupi;
{$INCLUDE fpcdefs.inc}
interface
uses
	cutils,
	cgbase,cpuinfo;
type
  TSparcprocinfo=class(TProcInfo)
    {overall size of allocated stack space, currently this is used for the
    PowerPC only}
    localsize:aword;
    {max of space need for parameters, currently used by the PowerPC port only}
    maxpushedparasize:aword;
    constructor create;override;
    procedure after_header;override;
    procedure after_pass1;override;
  end;
implementation
uses
	globtype,globals,
	aasmtai,
	tgobj;
constructor TSparcprocinfo.create;
	begin
		inherited create;
		maxpushedparasize:=0;
		localsize:=0;
	end;
procedure TSparcprocinfo.after_header;
	begin
  	{ this value is necessary for nested procedures }
		procdef.localst.address_fixup:=align(procdef.parast.datasize,16);
	end;
procedure TSparcprocinfo.after_pass1;
	begin
		procdef.parast.address_fixup:=align(maxpushedparasize,16);
	  WriteLn('Parameter copies start at: %i6+'+tostr(procdef.parast.address_fixup));
    procdef.localst.address_fixup:=align(procdef.parast.address_fixup+procdef.parast.datasize,16);
		WriteLn(strpnew('Locals start at: %o6+'+tostr(procdef.localst.address_fixup)));
		procinfo.firsttemp_offset:=align(procdef.localst.address_fixup+procdef.localst.datasize,16);
	  WriteLn('Temp. space start: %o6+'+tostr(procinfo.firsttemp_offset));
		tg.firsttemp:=procinfo.firsttemp_offset;
		tg.lasttemp:=procinfo.firsttemp_offset;
	end;
begin
  cprocinfo:=TSparcprocinfo;
end.
{
  $Log$
  Revision 1.4  2002-10-20 19:01:38  mazen
  + op_raddr_reg and op_caddr_reg added to fix functions prologue

  Revision 1.3  2002/10/10 15:10:39  mazen
  * Internal error fixed, but usually i386 parameter model used

  Revision 1.2  2002/08/29 11:02:36  mazen
  added support for SPARC processors

  Revision 1.1  2002/08/23 10:08:28  mazen
  *** empty log message ***

  Revision 1.2  2002/08/18 20:06:30  peter
    * inlining is now also allowed in interface
    * renamed write/load to ppuwrite/ppuload
    * tnode storing in ppu
    * nld,ncon,nbas are already updated for storing in ppu

  Revision 1.1  2002/08/17 09:23:49  florian
    * first part of procinfo rewrite
}
