{
    $Id$
    This file is part of the Free Pascal Integrated Development Environment
    Copyright (c) 2001 by Pierre Muller

    This unit is used to save and restore console modes

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit WConsole;

interface
{$ifdef UNIX}
   uses
     TermInfo,
{$Ifdef ver1_0}
     linux;
{$else}
     termio;
{$endif}
{$endif UNIX}

  type
    TConsoleMode =
{$ifdef OS2}
      dword
{$endif OS2}
{$ifdef UNIX}
      TermIos
{$endif UNIX}
{$ifdef Win32}
      dword
{$endif Win32}
{$ifdef go32v2}
      longint
{$endif go32v2}
{$ifdef netware}
      longint
{$endif netware}
    ;

Procedure SaveConsoleMode(var ConsoleMode : TConsoleMode);
Procedure RestoreConsoleMode(const ConsoleMode : TConsoleMode);

implementation
{$ifdef Win32}
  uses
    windows;
{$endif Win32}

Procedure SaveConsoleMode(var ConsoleMode : TConsoleMode);
Begin
{$ifdef UNIX}
  TCGetAttr(1,ConsoleMode);
{$endif UNIX}
{$ifdef Win32}
  GetConsoleMode(GetStdHandle(STD_INPUT_HANDLE),ConsoleMode);
{$endif Win32}
{$ifdef go32v2}
  ConsoleMode:=0;
{$endif go32v2}
{$ifdef netware}
  ConsoleMode:=0;
{$endif}
End;

Procedure RestoreConsoleMode(const ConsoleMode : TConsoleMode);
Begin
{$ifdef UNIX}
  TCSetAttr(1,TCSANOW,ConsoleMode);
{$endif UNIX}
{$ifdef Win32}
  SetConsoleMode(GetStdHandle(STD_INPUT_HANDLE),ConsoleMode);
{$endif Win32}
{$ifdef go32v2}
{$endif go32v2}
End;

end.

{
  $Log$
  Revision 1.8  2004-11-06 19:56:14  armin
  * support target netware

  Revision 1.7  2004/09/19 14:51:03  armin
  * added support for target netwlibc

  Revision 1.6  2003/11/19 17:11:40  marco
   * termio unit

  Revision 1.5  2002/10/12 19:42:01  hajny
    + OS/2 support

  Revision 1.4  2002/09/07 15:40:48  peter
    * old logs removed and tabs fixed

}
