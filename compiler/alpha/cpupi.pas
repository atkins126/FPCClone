{
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

 ****************************************************************************
}
{
  This unit contains the CPU specific part of tprocinfo.
}
unit cpupi;

{$i fpcdefs.inc}

  interface

    uses
       cgbase;

    type
       talphaprocinfo = class(tprocinfo)
       end;


  implementation

begin
   cprocinfo:=talphaprocinfo;
end.
{
  $Log$
  Revision 1.1  2002-09-29 23:54:12  florian
    * alpha compiles again, changes to common code not yet commited
}


