{
    $Id$
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit implements some support functions

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published
    by the Free Software Foundation; either version 2 of the License, or
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
{# This unit contains some generic support functions which are used
   in the different parts of the compiler.
}
unit cutils;

{$i fpcdefs.inc}

interface


    type
{$ifdef ver1_0}
       ptrint = longint;
{$endif ver1_0}
       pstring = ^string;
       get_var_value_proc=function(const s:string):string of object;
       Tcharset=set of char;

    var
      internalerrorproc : procedure(i:longint);

    {# Returns the minimal value between @var(a) and @var(b) }
    function min(a,b : longint) : longint;{$ifdef USEINLINE}inline;{$endif}
    function min(a,b : int64) : int64;{$ifdef USEINLINE}inline;{$endif}
    {# Returns the maximum value between @var(a) and @var(b) }
    function max(a,b : longint) : longint;{$ifdef USEINLINE}inline;{$endif}
    function max(a,b : int64) : int64;{$ifdef USEINLINE}inline;{$endif}
    {# Returns the value in @var(x) swapped to different endian }
    Function SwapInt64(x : int64): int64;{$ifdef USEINLINE}inline;{$endif}
    {# Returns the value in @var(x) swapped to different endian }
    function SwapLong(x : longint): longint;{$ifdef USEINLINE}inline;{$endif}
    {# Returns the value in @va(x) swapped to different endian }
    function SwapWord(x : word): word;{$ifdef USEINLINE}inline;{$endif}
    {# Return value @var(i) aligned on @var(a) boundary }
    function align(i,a:longint):longint;{$ifdef USEINLINE}inline;{$endif}

    function used_align(varalign,minalign,maxalign:longint):longint;
    function size_2_align(len : longint) : longint;
    procedure Replace(var s:string;s1:string;const s2:string);
    procedure Replace(var s:AnsiString;s1:string;const s2:string);
    procedure ReplaceCase(var s:string;const s1,s2:string);
    function upper(const s : string) : string;
    function lower(const s : string) : string;
    function trimbspace(const s:string):string;
    function trimspace(const s:string):string;
    function space (b : longint): string;
    function PadSpace(const s:string;len:longint):string;
    function GetToken(var s:string;endchar:char):string;
    procedure uppervar(var s : string);
    function hexstr(val : cardinal;cnt : cardinal) : string;
    function realtostr(e:extended):string;{$ifdef USEINLINE}inline;{$endif}
    function tostr(i : qword) : string;{$ifdef USEINLINE}inline;{$endif}overload;
    function tostr(i : int64) : string;{$ifdef USEINLINE}inline;{$endif}overload;
    function tostr(i : longint) : string;{$ifdef USEINLINE}inline;{$endif}overload;
    function tostr_with_plus(i : int64) : string;{$ifdef USEINLINE}inline;{$endif}
    function DStr(l:longint):string;
    {# Returns true if the string s is a number }
    function is_number(const s : string) : boolean;{$ifdef USEINLINE}inline;{$endif}
    {# Returns true if value is a power of 2, the actual
       exponent value is returned in power.
    }
    function ispowerof2(value : int64;var power : longint) : boolean;
    function backspace_quote(const s:string;const qchars:Tcharset):string;
    function octal_quote(const s:string;const qchars:Tcharset):string;
    function maybequoted(const s:string):string;

    {# If the string is quoted, in accordance with pascal, it is
       dequoted and returned in s, and the function returns true.
       If it is not quoted, or if the quoting is bad, s is not touched,
       and false is returned.
    }
    function DePascalQuote(var s: string): Boolean;
    function CompareText(S1, S2: string): longint;

    { releases the string p and assignes nil to p }
    { if p=nil then freemem isn't called          }
    procedure stringdispose(var p : pstring);{$ifdef USEINLINE}inline;{$endif}


    { allocates mem for a copy of s, copies s to this mem and returns }
    { a pointer to this mem                                           }
    function stringdup(const s : string) : pstring;{$ifdef USEINLINE}inline;{$endif}

    {# Allocates memory for the string @var(s) and copies s as zero
       terminated string to that allocated memory and returns a pointer
       to that mem
    }
    function  strpnew(const s : string) : pchar;
    procedure strdispose(var p : pchar);

    function string_evaluate(s:string;get_var_value:get_var_value_proc;
                             const vars:array of string):Pchar;
    {# makes the character @var(c) lowercase, with spanish, french and german
       character set
    }
    function lowercase(c : char) : char;

    { makes zero terminated string to a pascal string }
    { the data in p is modified and p is returned     }
    function pchar2pstring(p : pchar) : pstring;

    { ambivalent to pchar2pstring }
    function pstring2pchar(p : pstring) : pchar;

    { Speed/Hash value }
    Function GetSpeedValue(Const s:String):cardinal;

    { Ansistring (pchar+length) support }
    procedure ansistringdispose(var p : pchar;length : longint);
    function compareansistrings(p1,p2 : pchar;length1,length2 : longint) : longint;
    function concatansistrings(p1,p2 : pchar;length1,length2 : longint) : pchar;

    function DeleteFile(const fn:string):boolean;

    {Lzw encode/decode to compress strings -> save memory.}
    function minilzw_encode(const s:string):string;
    function minilzw_decode(const s:string):string;


implementation

uses
  strings
  ;

    var
      uppertbl,
      lowertbl  : array[char] of char;


    function min(a,b : longint) : longint;{$ifdef USEINLINE}inline;{$endif}
    {
      return the minimal of a and b
    }
      begin
         if a>b then
           min:=b
         else
           min:=a;
      end;


    function min(a,b : int64) : int64;{$ifdef USEINLINE}inline;{$endif}
    {
      return the minimal of a and b
    }
      begin
         if a>b then
           min:=b
         else
           min:=a;
      end;


    function max(a,b : longint) : longint;{$ifdef USEINLINE}inline;{$endif}
    {
      return the maximum of a and b
    }
      begin
         if a<b then
           max:=b
         else
           max:=a;
      end;


    function max(a,b : int64) : int64;{$ifdef USEINLINE}inline;{$endif}
    {
      return the maximum of a and b
    }
      begin
         if a<b then
           max:=b
         else
           max:=a;
      end;


    Function SwapLong(x : longint): longint;{$ifdef USEINLINE}inline;{$endif}
      var
        y : word;
        z : word;
      Begin
        y := x shr 16;
        y := word(longint(y) shl 8) or (y shr 8);
        z := x and $FFFF;
        z := word(longint(z) shl 8) or (z shr 8);
        SwapLong := (longint(z) shl 16) or longint(y);
      End;


    Function SwapInt64(x : int64): int64;{$ifdef USEINLINE}inline;{$endif}
      Begin
        result:=swaplong(longint(hi(x)));
        result:=result or (swaplong(longint(lo(x))) shl 32);
      End;


    Function SwapWord(x : word): word;{$ifdef USEINLINE}inline;{$endif}
      var
        z : byte;
      Begin
        z := x shr 8;
        x := x and $ff;
        x := (x shl 8);
        SwapWord := x or z;
      End;


    function align(i,a:longint):longint;{$ifdef USEINLINE}inline;{$endif}
    {
      return value <i> aligned <a> boundary
    }
      begin
        { for 0 and 1 no aligning is needed }
        if a<=1 then
          result:=i
        else
          begin
            if i<0 then
              result:=((i-a+1) div a) * a
            else
              result:=((i+a-1) div a) * a;
          end;
      end;


    function size_2_align(len : longint) : longint;
      begin
         if len>16 then
           size_2_align:=32
         else if len>8 then
           size_2_align:=16
         else if len>4 then
           size_2_align:=8
         else if len>2 then
           size_2_align:=4
         else if len>1 then
           size_2_align:=2
         else
           size_2_align:=1;
      end;


    function used_align(varalign,minalign,maxalign:longint):longint;
      begin
        { varalign  : minimum alignment required for the variable
          minalign  : Minimum alignment of this structure, 0 = undefined
          maxalign  : Maximum alignment of this structure, 0 = undefined }
        if (minalign>0) and
           (varalign<minalign) then
         used_align:=minalign
        else
         begin
           if (maxalign>0) and
              (varalign>maxalign) then
            used_align:=maxalign
           else
            used_align:=varalign;
         end;
      end;


    procedure Replace(var s:string;s1:string;const s2:string);
      var
         last,
         i  : longint;
      begin
        s1:=upper(s1);
        last:=0;
        repeat
          i:=pos(s1,upper(s));
          if i=last then
           i:=0;
          if (i>0) then
           begin
             Delete(s,i,length(s1));
             Insert(s2,s,i);
             last:=i;
           end;
        until (i=0);
      end;


    procedure Replace(var s:AnsiString;s1:string;const s2:string);
      var
         last,
         i  : longint;
      begin
        s1:=upper(s1);
        last:=0;
        repeat
          i:=pos(s1,upper(s));
          if i=last then
           i:=0;
          if (i>0) then
           begin
             Delete(s,i,length(s1));
             Insert(s2,s,i);
             last:=i;
           end;
        until (i=0);
      end;


    procedure ReplaceCase(var s:string;const s1,s2:string);
      var
         last,
         i  : longint;
      begin
        last:=0;
        repeat
          i:=pos(s1,s);
          if i=last then
           i:=0;
          if (i>0) then
           begin
             Delete(s,i,length(s1));
             Insert(s2,s,i);
             last:=i;
           end;
        until (i=0);
      end;


    function upper(const s : string) : string;
    {
      return uppercased string of s
    }
      var
        i  : longint;
      begin
        for i:=1 to length(s) do
          upper[i]:=uppertbl[s[i]];
        upper[0]:=s[0];
      end;


    function lower(const s : string) : string;
    {
      return lowercased string of s
    }
      var
        i : longint;
      begin
        for i:=1 to length(s) do
          lower[i]:=lowertbl[s[i]];
        lower[0]:=s[0];
      end;


    procedure uppervar(var s : string);
    {
      uppercase string s
    }
      var
         i : longint;
      begin
         for i:=1 to length(s) do
          s[i]:=uppertbl[s[i]];
      end;


    procedure initupperlower;
      var
        c : char;
      begin
        for c:=#0 to #255 do
         begin
           lowertbl[c]:=c;
           uppertbl[c]:=c;
           case c of
             'A'..'Z' :
               lowertbl[c]:=char(byte(c)+32);
             'a'..'z' :
               uppertbl[c]:=char(byte(c)-32);
           end;
         end;
      end;


    function hexstr(val : cardinal;cnt : cardinal) : string;
      const
        HexTbl : array[0..15] of char='0123456789ABCDEF';
      var
        i,j : cardinal;
      begin
        { calculate required length }
        i:=0;
        j:=val;
        while (j>0) do
         begin
           inc(i);
           j:=j shr 4;
         end;
        { generate fillers }
        j:=0;
        while (i+j<cnt) do
         begin
           inc(j);
           hexstr[j]:='0';
         end;
        { generate hex }
        inc(j,i);
        hexstr[0]:=chr(j);
        while (val>0) do
         begin
           hexstr[j]:=hextbl[val and $f];
           dec(j);
           val:=val shr 4;
         end;
      end;


    function DStr(l:longint):string;
      var
        TmpStr : string[32];
        i : longint;
      begin
        Str(l,TmpStr);
        i:=Length(TmpStr);
        while (i>3) do
         begin
           dec(i,3);
           if TmpStr[i]<>'-' then
            insert('.',TmpStr,i+1);
         end;
        DStr:=TmpStr;
      end;


    function trimbspace(const s:string):string;
    {
      return s with all leading spaces and tabs removed
    }
      var
        i,j : longint;
      begin
        j:=1;
        i:=length(s);
        while (j<i) and (s[j] in [#9,' ']) do
         inc(j);
        trimbspace:=Copy(s,j,i-j+1);
      end;



    function trimspace(const s:string):string;
    {
      return s with all leading and ending spaces and tabs removed
    }
      var
        i,j : longint;
      begin
        i:=length(s);
        while (i>0) and (s[i] in [#9,' ']) do
         dec(i);
        j:=1;
        while (j<i) and (s[j] in [#9,' ']) do
         inc(j);
        trimspace:=Copy(s,j,i-j+1);
      end;


    function space (b : longint): string;
      var
       s: string;
      begin
        space[0] := chr(b);
        s[0] := chr(b);
        FillChar (S[1],b,' ');
        space:=s;
      end;


    function PadSpace(const s:string;len:longint):string;
    {
      return s with spaces add to the end
    }
      begin
         if length(s)<len then
          PadSpace:=s+Space(len-length(s))
         else
          PadSpace:=s;
      end;


    function GetToken(var s:string;endchar:char):string;
      var
        i : longint;
      begin
        GetToken:='';
        s:=TrimSpace(s);
        if s[1]='''' then
         begin
           i:=1;
           while (i<length(s)) do
            begin
              inc(i);
              if s[i]='''' then
               begin
                 { Remove double quote }
                 if (i<length(s)) and
                    (s[i+1]='''') then
                  begin
                    Delete(s,i,1);
                    inc(i);
                  end
                 else
                  begin
                    GetToken:=Copy(s,2,i-2);
                    Delete(s,1,i);
                    exit;
                  end;
               end;
            end;
           GetToken:=s;
           s:='';
         end
        else
         begin
           i:=pos(EndChar,s);
           if i=0 then
            begin
              GetToken:=s;
              s:='';
              exit;
            end
           else
            begin
              GetToken:=Copy(s,1,i-1);
              Delete(s,1,i);
              exit;
            end;
         end;
      end;


   function realtostr(e:extended):string;{$ifdef USEINLINE}inline;{$endif}
     begin
        str(e,result);
     end;


   function tostr(i : qword) : string;{$ifdef USEINLINE}inline;{$endif}overload;
   {
     return string of value i
   }
     begin
        str(i,result);
     end;


   function tostr(i : int64) : string;{$ifdef USEINLINE}inline;{$endif}overload;
   {
     return string of value i
   }
     begin
        str(i,result);
     end;


   function tostr(i : longint) : string;{$ifdef USEINLINE}inline;{$endif}overload;
   {
     return string of value i
   }
     begin
        str(i,result);
     end;


   function tostr_with_plus(i : int64) : string;{$ifdef USEINLINE}inline;{$endif}
   {
     return string of value i, but always include a + when i>=0
   }
     begin
        str(i,result);
        if i>=0 then
          result:='+'+result;
     end;


    function is_number(const s : string) : boolean;{$ifdef USEINLINE}inline;{$endif}
    {
      is string a correct number ?
    }
      var
         w : integer;
         l : longint;
      begin
         val(s,l,w);
         is_number:=(w=0);
      end;


    function ispowerof2(value : int64;var power : longint) : boolean;
    {
      return if value is a power of 2. And if correct return the power
    }
      var
         hl : int64;
         i : longint;
      begin
         if value and (value - 1) <> 0 then
           begin
             ispowerof2 := false;
             exit
           end;
         hl:=1;
         ispowerof2:=true;
         for i:=0 to 63 do
           begin
              if hl=value then
                begin
                   power:=i;
                   exit;
                end;
              hl:=hl shl 1;
           end;
         ispowerof2:=false;
      end;


    function backspace_quote(const s:string;const qchars:Tcharset):string;

    var i:byte;

    begin
      backspace_quote:='';
      for i:=1 to length(s) do
        begin
          if (s[i]=#10) and (#10 in qchars) then
            backspace_quote:=backspace_quote+'\n'
          else if (s[i]=#13) and (#13 in qchars) then
            backspace_quote:=backspace_quote+'\r'
          else
            begin
              if s[i] in qchars then
                backspace_quote:=backspace_quote+'\';
              backspace_quote:=backspace_quote+s[i];
            end;
        end;
    end;

    function octal_quote(const s:string;const qchars:Tcharset):string;

    var i:byte;

    begin
      octal_quote:='';
      for i:=1 to length(s) do
        begin
          if s[i] in qchars then
            begin
              if ord(s[i])<64 then
                octal_quote:=octal_quote+'\'+octstr(ord(s[i]),3)
              else
                octal_quote:=octal_quote+'\'+octstr(ord(s[i]),4);
            end
          else
            octal_quote:=octal_quote+s[i];
        end;
    end;

    function maybequoted(const s:string):string;
      var
        s1 : string;
        i  : integer;
        quoted : boolean;
      begin
        quoted:=false;
        s1:='"';
        for i:=1 to length(s) do
         begin
           case s[i] of
             '"' :
               begin
                 quoted:=true;
                 s1:=s1+'\"';
               end;
             ' ',
             #128..#255 :
               begin
                 quoted:=true;
                 s1:=s1+s[i];
               end;
             else
               s1:=s1+s[i];
           end;
         end;
        if quoted then
          maybequoted:=s1+'"'
        else
          maybequoted:=s;
      end;


    function DePascalQuote(var s: string): Boolean;
      var
        destPos, sourcePos, len: Integer;
        t: string;
        ch: Char;
    begin
      DePascalQuote:= false;
      len:= length(s);
      if (len >= 1) and (s[1] = '''') then
        begin
          {Remove quotes, exchange '' against ' }
          destPos := 0;
          sourcepos:=1;
          while (sourcepos<len) do
            begin
              inc(sourcePos);
              ch := s[sourcePos];
              if ch = '''' then
                begin
                  inc(sourcePos);
                  if (sourcePos <= len) and (s[sourcePos] = '''') then
                    {Add the quote as part of string}
                  else
                    begin
                      SetLength(t, destPos);
                      s:= t;
                      Exit(true);
                    end;
                end;
              inc(destPos);
              t[destPos] := ch;
            end;
        end;
    end;


    function pchar2pstring(p : pchar) : pstring;
      var
         w,i : longint;
      begin
         w:=strlen(p);
         for i:=w-1 downto 0 do
           p[i+1]:=p[i];
         p[0]:=chr(w);
         pchar2pstring:=pstring(p);
      end;


    function pstring2pchar(p : pstring) : pchar;
      var
         w,i : longint;
      begin
         w:=length(p^);
         for i:=1 to w do
           p^[i-1]:=p^[i];
         p^[w]:=#0;
         pstring2pchar:=pchar(p);
      end;


    function lowercase(c : char) : char;
       begin
          case c of
             #65..#90 : c := chr(ord (c) + 32);
             #154 : c:=#129;  { german }
             #142 : c:=#132;  { german }
             #153 : c:=#148;  { german }
             #144 : c:=#130;  { french }
             #128 : c:=#135;  { french }
             #143 : c:=#134;  { swedish/norge (?) }
             #165 : c:=#164;  { spanish }
             #228 : c:=#229;  { greek }
             #226 : c:=#231;  { greek }
             #232 : c:=#227;  { greek }
          end;
          lowercase := c;
       end;


    function strpnew(const s : string) : pchar;
      var
         p : pchar;
      begin
         getmem(p,length(s)+1);
         strpcopy(p,s);
         strpnew:=p;
      end;


    procedure strdispose(var p : pchar);
      begin
        if assigned(p) then
         begin
           freemem(p,strlen(p)+1);
           p:=nil;
         end;
      end;


    procedure stringdispose(var p : pstring);{$ifdef USEINLINE}inline;{$endif}
      begin
         if assigned(p) then
           begin
             freemem(p,length(p^)+1);
             p:=nil;
           end;
      end;


    function stringdup(const s : string) : pstring;{$ifdef USEINLINE}inline;{$endif}
      begin
         getmem(result,length(s)+1);
         result^:=s;
      end;


    function CompareText(S1, S2: string): longint;
      begin
        UpperVar(S1);
        UpperVar(S2);
        if S1<S2 then
         CompareText:=-1
        else
         if S1>S2 then
          CompareText:= 1
        else
         CompareText:=0;
      end;

    function string_evaluate(s:string;get_var_value:get_var_value_proc;
                             const vars:array of string):Pchar;

    {S contains a prototype of a stabstring. Stabstr_evaluate will expand
     variables and parameters.

     Output is s in ASCIIZ format, with the following expanded:

     ${varname}   - The variable name is expanded.
     $n           - The parameter n is expanded.
     $$           - Is expanded to $
    }

    const maxvalue=9;
          maxdata=1023;

    var i,j:byte;
        varname:string[63];
        varno,varcounter:byte;
        varvalues:array[0..9] of Pstring;
        {1 kb of parameters is the limit. 256 extra bytes are allocated to
         ensure buffer integrity.}
        varvaluedata:array[0..maxdata+256] of char;
        varptr:Pchar;
        len:cardinal;
        r:Pchar;

    begin
      {Two pass approach, first, calculate the length and receive variables.}
      i:=1;
      len:=0;
      varcounter:=0;
      varptr:=@varvaluedata;
      while i<=length(s) do
        begin
          if (s[i]='$') and (i<length(s)) then
            begin
             if s[i+1]='$' then
               begin
                 inc(len);
                 inc(i);
               end
             else if (s[i+1]='{') and (length(s)>2) and (i<length(s)-2) then
               begin
                 varname:='';
                 inc(i,2);
                 repeat
                   inc(varname[0]);
                   varname[length(varname)]:=s[i];
                   s[i]:=char(varcounter);
                   inc(i);
                 until s[i]='}';
                 varvalues[varcounter]:=Pstring(varptr);
                 if varptr>@varvaluedata+maxdata then
                   internalerrorproc(200411152);
                 Pstring(varptr)^:=get_var_value(varname);
                 inc(len,length(Pstring(varptr)^));
                 inc(varptr,length(Pstring(varptr)^)+1);
                 inc(varcounter);
               end
             else if s[i+1] in ['0'..'9'] then
               begin
                 inc(len,length(vars[byte(s[i+1])-byte('1')]));
                 inc(i);
               end;
            end
          else
            inc(len);
          inc(i);
        end;

      {Second pass, writeout stabstring.}
      getmem(r,len+1);
      string_evaluate:=r;
      i:=1;
      while i<=length(s) do
        begin
          if (s[i]='$') and (i<length(s)) then
            begin
             if s[i+1]='$' then
               begin
                 r^:='$';
                 inc(r);
                 inc(i);
               end
             else if (s[i+1]='{') and (length(s)>2) and (i<length(s)-2) then
               begin
                 varname:='';
                 inc(i,2);
                 varno:=byte(s[i]);
                 repeat
                   inc(i);
                 until s[i]='}';
                 for j:=1 to length(varvalues[varno]^) do
                   begin
                     r^:=varvalues[varno]^[j];
                     inc(r);
                   end;
               end
             else if s[i+1] in ['0'..'9'] then
               begin
                 for j:=1 to length(vars[byte(s[i+1])-byte('1')]) do
                   begin
                     r^:=vars[byte(s[i+1])-byte('1')][j];
                     inc(r);
                   end;
                 inc(i);
               end
            end
          else
            begin
              r^:=s[i];
              inc(r);
            end;
          inc(i);
        end;
      r^:=#0;
    end;

{*****************************************************************************
                               GetSpeedValue
*****************************************************************************}

{$ifdef ver1_0}
  {$R-}
{$endif}

    var
      Crc32Tbl : array[0..255] of cardinal;

    procedure MakeCRC32Tbl;
      var
        crc : cardinal;
        i,n : integer;
      begin
        for i:=0 to 255 do
         begin
           crc:=i;
           for n:=1 to 8 do
            if odd(longint(crc)) then
             crc:=cardinal(crc shr 1) xor cardinal($edb88320)
            else
             crc:=cardinal(crc shr 1);
           Crc32Tbl[i]:=crc;
         end;
      end;


    Function GetSpeedValue(Const s:String):cardinal;
      var
        i : integer;
        InitCrc : cardinal;
      begin
        InitCrc:=cardinal($ffffffff);
        for i:=1 to Length(s) do
         InitCrc:=Crc32Tbl[byte(InitCrc) xor ord(s[i])] xor (InitCrc shr 8);
        GetSpeedValue:=InitCrc;
      end;


{*****************************************************************************
                               Ansistring (PChar+Length)
*****************************************************************************}

    procedure ansistringdispose(var p : pchar;length : longint);
      begin
         if assigned(p) then
           begin
             freemem(p,length+1);
             p:=nil;
           end;
      end;


    { enable ansistring comparison }
    { 0 means equal }
    { 1 means p1 > p2 }
    { -1 means p1 < p2 }
    function compareansistrings(p1,p2 : pchar;length1,length2 :  longint) : longint;
      var
         i,j : longint;
      begin
         compareansistrings:=0;
         j:=min(length1,length2);
         i:=0;
         while (i<j) do
          begin
            if p1[i]>p2[i] then
             begin
               compareansistrings:=1;
               exit;
             end
            else
             if p1[i]<p2[i] then
              begin
                compareansistrings:=-1;
                exit;
              end;
            inc(i);
          end;
         if length1>length2 then
          compareansistrings:=1
         else
          if length1<length2 then
           compareansistrings:=-1;
      end;


    function concatansistrings(p1,p2 : pchar;length1,length2 : longint) : pchar;
      var
         p : pchar;
      begin
         getmem(p,length1+length2+1);
         move(p1[0],p[0],length1);
         move(p2[0],p[length1],length2+1);
         concatansistrings:=p;
      end;


{*****************************************************************************
                                 File Functions
*****************************************************************************}

    function DeleteFile(const fn:string):boolean;
      var
        f : file;
      begin
        {$I-}
         assign(f,fn);
         erase(f);
        {$I-}
        DeleteFile:=(IOResult=0);
      end;

{*****************************************************************************
                       Ultra basic KISS Lzw (de)compressor
*****************************************************************************}

    {This is an extremely basic implementation of the Lzw algorithm. It
     compresses 7-bit ASCII strings into 8-bit compressed strings.
     The Lzw dictionary is preinitialized with 0..127, therefore this
     part of the dictionary does not need to be stored in the arrays.
     The Lzw code size is allways 8 bit, so we do not need complex code
     that can write partial bytes.}

    function minilzw_encode(const s:string):string;

    var t,u,i:byte;
        c:char;
        data:array[128..255] of char;
        previous:array[128..255] of byte;
        lzwptr:byte;
        next_avail:set of 0..255;

    label l1;

    begin
      minilzw_encode:='';
      if s<>'' then
        begin
          lzwptr:=127;
          t:=byte(s[1]);
          i:=2;
          u:=128;
          next_avail:=[];
          while i<=length(s) do
            begin
              c:=s[i];
              if not(t in next_avail) or (u>lzwptr) then goto l1;
              while (previous[u]<>t) or (data[u]<>c) do
                begin
                  inc(u);
                  if u>lzwptr then goto l1;
                end;
              t:=u;
              inc(i);
              continue;
            l1:
              {It's a pity that we still need those awfull tricks
               with this modern compiler. Without this performance
               of the entire procedure drops about 3 times.}
              inc(minilzw_encode[0]);
              minilzw_encode[length(minilzw_encode)]:=char(t);
              if lzwptr=255 then
                begin
                  lzwptr:=127;
                  next_avail:=[];
                end
              else
                begin
                  inc(lzwptr);
                  data[lzwptr]:=c;
                  previous[lzwptr]:=t;
                  include(next_avail,t);
                end;
              t:=byte(c);
              u:=128;
              inc(i);
            end;
          inc(minilzw_encode[0]);
          minilzw_encode[length(minilzw_encode)]:=char(t);
        end;
    end;

    function minilzw_decode(const s:string):string;

    var oldc,newc,c:char;
        i,j:byte;
        data:array[128..255] of char;
        previous:array[128..255] of byte;
        lzwptr:byte;
        t:string;

    begin
      minilzw_decode:='';
      if s<>'' then
        begin
          lzwptr:=127;
          oldc:=s[1];
          c:=oldc;
          i:=2;
          minilzw_decode:=oldc;
          while i<=length(s) do
            begin
              newc:=s[i];
              if byte(newc)>lzwptr then
                begin
                  t:=c;
                  c:=oldc;
                end
              else
                begin
                  c:=newc;
                  t:='';
                end;
              while c>=#128 do
                begin
                  inc(t[0]);
                  t[length(t)]:=data[byte(c)];
                  byte(c):=previous[byte(c)];
                end;
              inc(minilzw_decode[0]);
              minilzw_decode[length(minilzw_decode)]:=c;
              for j:=length(t) downto 1 do
                begin
                  inc(minilzw_decode[0]);
                  minilzw_decode[length(minilzw_decode)]:=t[j];
                end;
              if lzwptr=255 then
                lzwptr:=127
              else
                begin
                  inc(lzwptr);
                  previous[lzwptr]:=byte(oldc);
                  data[lzwptr]:=c;
                end;
              oldc:=newc;
              inc(i);
            end;
        end;
    end;


    procedure defaulterror(i:longint);
      begin
        writeln('Internal error ',i);
        runerror(255);
      end;


initialization
  internalerrorproc:=@defaulterror;
  makecrc32tbl;
  initupperlower;
end.
{
  $Log$
  Revision 1.48  2005-01-20 17:05:53  peter
    * use val() for decoding integers

  Revision 1.47  2004/11/15 23:35:31  peter
    * tparaitem removed, use tparavarsym instead
    * parameter order is now calculated from paranr value in tparavarsym

  Revision 1.46  2004/10/15 09:14:16  mazen
  - remove $IFDEF DELPHI and related code
  - remove $IFDEF FPCPROCVAR and related code

  Revision 1.45  2004/10/14 14:55:12  mazen
  * use SysUtils unit instead of Dos Unit
  + overload Replace to use AnsiString

  Revision 1.44  2004/09/21 20:32:40  peter
    * range check error in swapint64

  Revision 1.43  2004/09/13 20:26:45  peter
    * for-loop variable access removed

  Revision 1.42  2004/08/31 21:44:18  olle
    + added proc DePascalQuote

  Revision 1.41  2004/06/20 08:55:29  florian
    * logs truncated

  Revision 1.40  2004/06/16 20:07:07  florian
    * dwarf branch merged

  Revision 1.39  2004/05/22 23:33:18  peter
  fix range check error when array size > maxlongint

  Revision 1.38.2.3  2004/04/29 19:07:22  peter
    * compile fixes

  Revision 1.38.2.2  2004/04/26 21:01:36  peter
    * aint fixes

  Revision 1.38.2.1  2004/04/20 16:35:58  peter
    * generate dwarf for stackframe entry

}
