{
    $Id$
    Copyright (c) 1998-2002 by Florian Klaempfl

    Version/target constants

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
unit version;

{$i fpcdefs.inc}

interface

    const
       { word version for ppu file }
       wordversion = (1 shl 14)+(1 shl 7) + 0;

       { version string }
       version_nr = '1';
       release_nr = '1';
       patch_nr   = '0';
{$ifdef newcg}
       minorpatch = ' NCG';
{$else newcg}
       minorpatch = '';
{$endif newcg}

       { date string }
{$ifdef FPC}
       date_string = {$I %DATE%};
{$else}
       date_string = 'N/A';
{$endif}

       { target cpu string }
{$ifdef i386}
       target_cpu_string = 'i386';
{$endif}
{$ifdef sparc}
       target_cpu_string = 'sparc';
{$endif}
{$ifdef m68k}
       target_cpu_string = 'm68k';
{$endif}
{$ifdef alpha}
       target_cpu_string = 'alpha';
{$endif}
{$ifdef powerpc}
       target_cpu_string = 'powerpc';
{$endif}
{$ifdef ia64}
       target_cpu_string = 'ia64';
{$endif}

       { source cpu string }
{$ifdef cpu86}
        source_cpu_string = 'i386';
{$endif}
{$ifdef cpu68}
        source_cpu_string = 'm68k';
{$endif}
{$ifdef cpuia64}
       target_cpu_string = 'ia64';
{$endif}

function version_string:string;
function full_version_string:string;


implementation

function version_string:string;
begin
  if patch_nr='0' then
   version_string := version_nr+'.'+release_nr
  else
   version_string := version_nr+'.'+release_nr+'.'+patch_nr;
end;


function full_version_string:string;
begin
  if patch_nr='0' then
   full_version_string := version_nr+'.'+release_nr+minorpatch
  else
   full_version_string := version_nr+'.'+release_nr+'.'+patch_nr+minorpatch;
end;

end.
{
  $Log$
  Revision 1.12  2002-05-18 13:34:21  peter
    * readded missing revisions

  Revision 1.11  2002/05/16 19:46:47  carl
  + defines.inc -> fpcdefs.inc to avoid conflicts if compiling by hand
  + try to fix temp allocation (still in ifdef)
  + generic constructor calls
  + start of tassembler / tmodulebase class cleanup

  Revision 1.9  2002/03/24 19:12:11  carl
  + patch for SPARC from Mazen NEIFER

  Revision 1.8  2002/03/01 12:47:21  pierre
   * used shl 7 for release number

}
