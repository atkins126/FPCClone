{
    $Id$
    Copyright (c) 1998-2003 by Peter Vreman, Florian Klaempfl and Carl Eric Codere

    Basic stuff for assembler readers

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
unit rabase;

{$i fpcdefs.inc}

  interface

    uses
      cclasses,
      systems;

    type
       tbaseasmreader = class
         constructor create;virtual;
         { the real return type is taasmoutput, but this would introduce too much unit circles }
         function Assemble: tlinkedlist;virtual;abstract;
       end;
       tcbaseasmreader = class of tbaseasmreader;

       pasmmodeinfo = ^tasmmodeinfo;
       tasmmodeinfo = packed record
          id    : tasmmode;
          idtxt : string[8];
          casmreader : tcbaseasmreader;
       end;

    var
      asmmodeinfos  : array[tasmmode] of pasmmodeinfo;

    function SetAsmReadMode(const s:string;var t:tasmmode):boolean;
    procedure RegisterAsmMode(const r:tasmmodeinfo);

  implementation

    uses
      cutils;


    procedure RegisterAsmmode(const r:tasmmodeinfo);
      var
        t : tasmmode;
      begin
        t:=r.id;
        if assigned(asmmodeinfos[t]) then
          writeln('Warning: Asmmode is already registered!')
        else
          Getmem(asmmodeinfos[t],sizeof(tasmmodeinfo));
        asmmodeinfos[t]^:=r;
      end;


    function SetAsmReadMode(const s:string;var t:tasmmode):boolean;
      var
        hs : string;
        ht : tasmmode;
      begin
        result:=false;
        { this should be case insensitive !! PM }
        hs:=upper(s);
        for ht:=low(tasmmode) to high(tasmmode) do
         if assigned(asmmodeinfos[ht]) and
            (asmmodeinfos[ht]^.idtxt=hs) then
          begin
            t:=asmmodeinfos[ht]^.id;
            result:=true;
          end;
      end;


    constructor tbaseasmreader.create;
      begin
        inherited create;
      end;

var
  asmmode : tasmmode;

initialization
  fillchar(asmmode,sizeof(asminfos),0);
finalization
  for asmmode:=low(tasmmode) to high(tasmmode) do
   if assigned(asmmodeinfos[asmmode]) then
    begin
      freemem(asmmodeinfos[asmmode],sizeof(tasmmodeinfo));
      asmmodeinfos[asmmode]:=nil;
    end;
end.
{
  $Log$
  Revision 1.1  2003-11-12 16:05:39  florian
    * assembler readers OOPed
    + typed currency constants
    + typed 128 bit float constants if the CPU supports it
}
