Unit nCrt;
{---------------------------------------------------------------------------
                                 CncWare
                         (c) Copyright 1999-2000
                   Portions copyright the FreePascal Team
 ---------------------------------------------------------------------------
  Filename..: ncrt.pp
  Programmer: Ken J. Wright, ken@cncware.com
  Date......: 03/01/99

  Purpose - A crt replacement using ncurses.

-------------------------------<< REVISIONS >>--------------------------------
  Ver  |   Date   | Prog| Description
-------+----------+-----+-----------------------------------------------------
  1.00 | 03/01/99 | kjw | Initial Release.
------------------------------------------------------------------------------
  2.00 | 12/13/99 | kjw | nCrt is now a drop-in replacement for the standard
                        | FPC crt unit. All the previous OOP features have
                        | been moved to a new unit, oCrt (object crt).
                        | See ocrt.pp & ncrt.inc for a complete revision
                        | history.
------------------------------------------------------------------------------
}
Interface

Uses Unix,ncurses;

{$i ncrt.inc}

Begin
   { initialize ncurses }
   If StartCurses(ActiveWn) Then
      { defaults, crtassign, etc. }
      nInit
   Else
      CursesFailed;
End. { of Unit nCrt }
{
  $Log$
  Revision 1.4  2001-01-21 21:38:52  marco
   * renamefest in packages

  Revision 1.3  2000/08/29 05:51:09  michael
  + Merged changes and additions from fixbranch

  Revision 1.2  2000/07/13 11:33:27  michael
  + removed logs
 
}
