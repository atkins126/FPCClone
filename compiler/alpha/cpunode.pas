{
    $Id$
    Copyright (c) 2000-2002 by Florian Klaempfl

    Imports the Alpha code generator

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
  This unit imports the Alpha code generator.
}
unit cpunode;

{$i fpcdefs.inc}

  interface

  implementation

    uses
       { generic nodes }
       ncgbas,ncgld,ncgflw,ncgcnv,ncgmem,ncgcon,ncgcal,ncgset,ncginl
       { to be able to only parts of the generic code,
         the processor specific nodes must be included
         after the generic one (FK)
       }
//       naxpadd,
//       naxpcal,
//       naxpcon,
//       naxpflw,
//       naxpmem,
//       naxpset,
//       naxpinl,
//       nppcopt,
       { this not really a node }
//       naxpobj,
//       naxpmat,
//       naxpcnv
       ;

end.
{
  $Log$
  Revision 1.2  2002-09-29 23:54:12  florian
    * alpha compiles again, changes to common code not yet commited

  Revision 1.1  2002/08/18 09:13:02  florian
    * small fixes to the alpha stuff
}
