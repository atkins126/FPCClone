{
    $Id$
    Copyright (c) 1998-2002 by Peter Vreman and Florian Klaempfl

    Convert spreg.dat to several .inc files for usage with
    the Free pascal compiler

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
program mkspreg;

const Version = '1.00';
      max_regcount = 200;

var s : string;
    i : longint;
    line : longint;
    regcount:byte;
    regcount_bsstart:byte;
    supregs,
    subregs,
    names,
    regtypes,
    numbers,
    stdnames,
    stabs : array[0..max_regcount-1] of string[63];
    regnumber_index,
    std_regname_index : array[0..max_regcount-1] of byte;

{$ifndef FPC}
  procedure readln(var t:text;var s:string);
  var
    c : char;
    i : longint;
  begin
    c:=#0;
    i:=0;
    while (not eof(t)) and (c<>#10) do
     begin
       read(t,c);
       if c<>#10 then
        begin
          inc(i);
          s[i]:=c;
        end;
     end;
    if (i>0) and (s[i]=#13) then
     dec(i);
    s[0]:=chr(i);
  end;
{$endif}

function tostr(l : longint) : string;

begin
  str(l,tostr);
end;

function readstr : string;

  var
     result : string;

  begin
     result:='';
     while (s[i]<>',') and (i<=length(s)) do
       begin
          result:=result+s[i];
          inc(i);
       end;
     readstr:=result;
  end;


procedure readcomma;
  begin
     if s[i]<>',' then
       begin
         writeln('Missing "," at line ',line);
         writeln('Line: "',s,'"');
         halt(1);
       end;
     inc(i);
  end;


procedure skipspace;

  begin
     while (s[i] in [' ',#9]) do
       inc(i);
  end;

procedure openinc(var f:text;const fn:string);
begin
  writeln('creating ',fn);
  assign(f,fn);
  rewrite(f);
  writeln(f,'{ don''t edit, this file is generated from spreg.dat }');
end;


procedure closeinc(var f:text);
begin
  writeln(f);
  close(f);
end;

procedure build_regnum_index;

var h,i,j,p,t:byte;

begin
  {Build the registernumber2regindex index.
   Step 1: Fill.}
  for i:=0 to regcount-1 do
    regnumber_index[i]:=i;
  {Step 2: Sort. We use a Shell-Metzner sort.}
  p:=regcount_bsstart;
  repeat
    for h:=0 to regcount-p-1 do
      begin
        i:=h;
        repeat
          j:=i+p;
          if numbers[regnumber_index[j]]>=numbers[regnumber_index[i]] then
            break;
          t:=regnumber_index[i];
          regnumber_index[i]:=regnumber_index[j];
          regnumber_index[j]:=t;
          if i<p then
            break;
          dec(i,p);
        until false;
      end;
    p:=p shr 1;
  until p=0;
end;

procedure build_std_regname_index;

var h,i,j,p,t:byte;

begin
  {Build the registernumber2regindex index.
   Step 1: Fill.}
  for i:=0 to regcount-1 do
    std_regname_index[i]:=i;
  {Step 2: Sort. We use a Shell-Metzner sort.}
  p:=regcount_bsstart;
  repeat
    for h:=0 to regcount-p-1 do
      begin
        i:=h;
        repeat
          j:=i+p;
          if stdnames[std_regname_index[j]]>=stdnames[std_regname_index[i]] then
            break;
          t:=std_regname_index[i];
          std_regname_index[i]:=std_regname_index[j];
          std_regname_index[j]:=t;
          if i<p then
            break;
          dec(i,p);
        until false;
      end;
    p:=p shr 1;
  until p=0;
end;


procedure read_spreg_file;
var
  infile:text;
begin
   { open dat file }
   assign(infile,'spreg.dat');
   reset(infile);
   while not(eof(infile)) do
     begin
        { handle comment }
        readln(infile,s);
        inc(line);
        while (s[1]=' ') do
         delete(s,1,1);
        if (s='') or (s[1]=';') then
          continue;

        i:=1;
        names[regcount]:=readstr;
        readcomma;
        regtypes[regcount]:=readstr;
        readcomma;
        subregs[regcount]:=readstr;
        readcomma;
        supregs[regcount]:=readstr;
        readcomma;
        stdnames[regcount]:=readstr;
        readcomma;
        stabs[regcount]:=readstr;
        { Create register number }
        if supregs[regcount][1]<>'$' then
          begin
            writeln('Missing $ before number, at line ',line);
            writeln('Line: "',s,'"');
            halt(1);
          end;
        numbers[regcount]:=regtypes[regcount]+copy(subregs[regcount],2,255)+'00'+copy(supregs[regcount],2,255);
        if i<length(s) then
          begin
            writeln('Extra chars at end of line, at line ',line);
            writeln('Line: "',s,'"');
            halt(1);
          end;
        inc(regcount);
        if regcount>max_regcount then
          begin
            writeln('Error: Too much registers, please increase maxregcount in source');
            halt(2);
          end;
     end;
   close(infile);
end;

procedure write_inc_files;

var
    norfile,stdfile,supfile,
    numfile,stabfile,confile,
    rnifile,srifile:text;
    first:boolean;

begin
  { create inc files }
  openinc(confile,'rspcon.inc');
  openinc(supfile,'rspsup.inc');
  openinc(numfile,'rspnum.inc');
  openinc(stdfile,'rspstd.inc');
  openinc(stabfile,'rspstab.inc');
  openinc(norfile,'rspnor.inc');
  openinc(rnifile,'rsprni.inc');
  openinc(srifile,'rspsri.inc');
  first:=true;
  for i:=0 to regcount-1 do
    begin
      if not first then
        begin
          writeln(numfile,',');
          writeln(stdfile,',');
          writeln(stabfile,',');
          writeln(rnifile,',');
          writeln(srifile,',');
        end
      else
        first:=false;
      writeln(confile,'NR_',names[i],' = tregister(',numbers[i],');');
      writeln(supfile,'RS_',names[i],' = ',supregs[i],';');
      write(numfile,'NR_',names[i]);
      write(stdfile,'''',stdnames[i],'''');
      write(stabfile,stabs[i]);
      write(rnifile,regnumber_index[i]);
      write(srifile,std_regname_index[i]);
    end;
  write(norfile,regcount);
  close(confile);
  close(supfile);
  closeinc(numfile);
  closeinc(stdfile);
  closeinc(stabfile);
  closeinc(norfile);
  closeinc(rnifile);
  closeinc(srifile);
  writeln('Done!');
  writeln(regcount,' registers procesed');
end;


begin
   writeln('Register Table Converter Version ',Version);
   line:=0;
   regcount:=0;
   read_spreg_file;
   regcount_bsstart:=1;
   while 2*regcount_bsstart<regcount do
     regcount_bsstart:=regcount_bsstart*2;
   build_regnum_index;
   build_std_regname_index;
   write_inc_files;
end.
{
  $Log$
  Revision 1.5  2004-01-12 16:39:41  peter
    * sparc updates, mostly float related

  Revision 1.4  2003/09/03 20:33:28  peter
    * fixed sorting of register number

  Revision 1.3  2003/09/03 16:28:16  peter
    * also generate superregisters

  Revision 1.2  2003/09/03 15:55:02  peter
    * NEWRA branch merged

  Revision 1.1.2.1  2003/08/31 21:08:16  peter
    * first batch of sparc fixes

}
