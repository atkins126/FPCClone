{
    $Id$
    Copyright (c) 1998-2002 by Peter Vreman

    This unit implements support information structures for AmigaOS

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
{ This unit implements support information structures for the AmigaOS. }
unit i_amiga;

  interface

    uses
       systems;

    const
       system_m68k_amiga_info : tsysteminfo =
          (
            system       : system_m68k_Amiga;
            name         : 'Commodore Amiga';
            shortname    : 'amiga';
            flags        : [];
            cpu          : cpu_m68k;
            unit_env     : '';
            extradefines : '';
            exeext       : '';
            defext       : '.def';
            scriptext    : '.sh';
            smartext     : '.sl';
            unitext      : '.ppu';
            unitlibext   : '.ppl';
            asmext       : '.s';
            objext       : '.o';
            resext       : '.res';
            resobjext    : '.or';
            sharedlibext : '.library';
            staticlibext : '.a';
            staticlibprefix : 'lib';
            sharedlibprefix : '';
            sharedClibext : '.library';
            staticClibext : '.a';
            staticClibprefix : 'lib';
            sharedClibprefix : '';
            p_ext_support : false;
            Cprefix      : '';
            newline      : #10;
            dirsep       : '/';
            files_case_relevent : true;
            assem        : as_gas;
            assemextern  : as_gas;
            link         : nil;
            linkextern   : nil;
            ar           : ar_gnu_ar;
            res          : res_none;
            script       : script_amiga;
            endian       : endian_big;
            alignment    :
              (
                procalign       : 4;
                loopalign       : 4;
                jumpalign       : 0;
                constalignmin   : 0;
                constalignmax   : 4;
                varalignmin     : 0;
                varalignmax     : 4;
                localalignmin   : 0;
                localalignmax   : 4;
                recordalignmin  : 0;
                recordalignmax  : 2;
                maxCrecordalign : 4
              );
            first_parm_offset : 8;
            stacksize    : 262144;
            DllScanSupported:false;
            use_function_relative_addresses : true
          );

       system_powerpc_amiga_info : tsysteminfo =
          (
            system       : system_powerpc_Amiga;
            name         : 'AmigaOS for PowerPC';
            shortname    : 'amigappc';
            flags        : [];
            cpu          : cpu_powerpc;
            unit_env     : '';
            extradefines : '';
            sourceext    : '.pp';
            pasext       : '.pas';
            exeext       : '';
            defext       : '.def';
            scriptext    : '.sh';
            smartext     : '.sl';
            unitext      : '.ppu';
            unitlibext   : '.ppl';
            asmext       : '.s';
            objext       : '.o';
            resext       : '.res';
            resobjext    : '.or';
            sharedlibext : '.library';
            staticlibext : '.a';
            staticlibprefix : 'lib';
            sharedlibprefix : '';
            sharedClibext : '.library';
            staticClibext : '.a';
            staticClibprefix : 'lib';
            sharedClibprefix : '';
            Cprefix      : '';
            newline      : #10;
            dirsep       : '/';
            files_case_relevent : true;
            assem        : as_gas;
            assemextern  : as_gas;
            link         : nil;
            linkextern   : nil;
            ar           : ar_gnu_ar;
            res          : res_none;
            script       : script_amiga;
            endian       : endian_big;
            alignment    :
              (
                procalign       : 4;
                loopalign       : 4;
                jumpalign       : 0;
                constalignmin   : 0;
                constalignmax   : 4;
                varalignmin     : 0;
                varalignmax     : 4;
                localalignmin   : 0;
                localalignmax   : 4;
                recordalignmin  : 0;
                recordalignmax  : 4;
                maxCrecordalign : 4
              );
            first_parm_offset : 8;
            stacksize    : 262144;
            DllScanSupported:false;
            use_function_relative_addresses : true
          );

  implementation

initialization
{$ifdef CPU68}
  {$ifdef AMIGA}
    set_source_info(system_m68k_Amiga_info);
  {$endif AMIGA}
{$endif CPU68}
{$ifdef CPUPOWERPC}
  {$ifdef AMIGA}
//    set_source_info(system_powerpc_Amiga_info);
  {$endif AMIGA}
{$endif CPUPOWERPC}
end.
{
  $Log$
  Revision 1.9  2005-03-20 22:36:45  olle
    * Cleaned up handling of source file extension.
    + Added support for .p extension for macos and darwin

  Revision 1.8  2005/02/14 17:13:10  peter
    * truncate log

  Revision 1.7  2005/02/03 03:54:06  karoly
  t_morph.pas

}
