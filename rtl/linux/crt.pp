{
    $Id$
    This file is part of the Free Pascal run time library.
    Copyright (c) 1999-2000 by Michael Van Canneyt and Peter Vreman,
    members of the Free Pascal development team.

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit Crt;
Interface

Const
{ Controlling consts }
  Flushing=false;               {if true then don't buffer output}

{ CRT modes }
  BW40          = 0;            { 40x25 B/W on Color Adapter }
  CO40          = 1;            { 40x25 Color on Color Adapter }
  BW80          = 2;            { 80x25 B/W on Color Adapter }
  CO80          = 3;            { 80x25 Color on Color Adapter }
  Mono          = 7;            { 80x25 on Monochrome Adapter }
  Font8x8       = 256;          { Add-in for ROM font }

{ Mode constants for 3.0 compatibility }
  C40           = CO40;
  C80           = CO80;

{ Foreground and background color constants }
  Black         = 0;
  Blue          = 1;
  Green         = 2;
  Cyan          = 3;
  Red           = 4;
  Magenta       = 5;
  Brown         = 6;
  LightGray     = 7;

{ Foreground color constants }
  DarkGray      = 8;
  LightBlue     = 9;
  LightGreen    = 10;
  LightCyan     = 11;
  LightRed      = 12;
  LightMagenta  = 13;
  Yellow        = 14;
  White         = 15;

{ Add-in for blinking }
  Blink         = 128;

{Other Defaults}
  TextAttr   : Byte = $07;
  LastMode   : Word = 3;
  WindMin    : Word = $0;
  WindMax    : Word = $184f;
var
  CheckBreak,
  CheckEOF,
  CheckSnow,
  DirectVideo: Boolean;

Const
  ScreenHeight : longint=25;
  ScreenWidth  : longint=80;

  ConsoleMaxX=1024;
  ConsoleMaxY=1024;
Type
  TCharAttr=packed record
    ch   : char;
    attr : byte;
  end;
  TConsoleBuf=Array[0..ConsoleMaxX*ConsoleMaxY-1] of TCharAttr;
  PConsoleBuf=^TConsoleBuf;
var
  ConsoleBuf : PConsoleBuf;


Procedure AssignCrt(Var F: Text);
Function  KeyPressed: Boolean;
Function  ReadKey: Char;
Procedure TextMode(Mode: Integer);
Procedure Window(X1, Y1, X2, Y2: Byte);
Procedure GoToXy(X: Byte; Y: Byte);
Function  WhereX: Byte;
Function  WhereY: Byte;
Procedure ClrScr;
Procedure ClrEol;
Procedure InsLine;
Procedure DelLine;
Procedure TextColor(Color: Byte);
Procedure TextBackground(Color: Byte);
Procedure LowVideo;
Procedure HighVideo;
Procedure NormVideo;
Procedure Delay(DTime: Word);
Procedure Sound(Hz: Word);
Procedure NoSound;

{ extra }
procedure CursorBig;
procedure CursorOn;
procedure CursorOff;


Implementation

uses Linux;

{
  The definitions of TextRec and FileRec are in separate files.
}
{$i textrec.inc}

Const
  OldTextAttr : byte = $07;
Var
  CurrX,CurrY : Byte;
  ExitSave    : Pointer;
  OutputRedir, InputRedir       : boolean; { is the output/input being redirected (not a TTY) }


{*****************************************************************************
                    Some Handy Functions Not in the System.PP
*****************************************************************************}

Function Str(l:longint):string;
{
  Return a String of the longint
}
var
  hstr : string[32];
begin
  System.Str(l,hstr);
  Str:=hstr;
end;



Function Max(l1,l2:longint):longint;
{
  Return the maximum of l1 and l2
}
begin
  if l1>l2 then
   Max:=l1
  else
   Max:=l2;
end;



Function Min(l1,l2:longint):longint;
{
  Return the minimum of l1 and l2
}
begin
  if l1<l2 then
   Min:=l1
  else
   Min:=l2;
end;


{*****************************************************************************
                      Optimal AnsiString Conversion Routines
*****************************************************************************}

Function XY2Ansi(x,y,ox,oy:longint):String;
{
  Returns a string with the escape sequences to go to X,Y on the screen
}
Begin
  if y=oy then
   begin
     if x=ox then
      begin
        XY2Ansi:='';
        exit;
      end;
     if x=1 then
      begin
        XY2Ansi:=#13;
        exit;
      end;
     if x>ox then
      begin
        XY2Ansi:=#27'['+Str(x-ox)+'C';
        exit;
      end
     else
      begin
        XY2Ansi:=#27'['+Str(ox-x)+'D';
        exit;
      end;
   end;
  if x=ox then
   begin
     if y>oy then
      begin
        XY2Ansi:=#27'['+Str(y-oy)+'B';
        exit;
      end
     else
      begin
        XY2Ansi:=#27'['+Str(oy-y)+'A';
        exit;
      end;
   end;
  if (x=1) and (oy+1=y) then
   XY2Ansi:=#13#10
  else
   XY2Ansi:=#27'['+Str(y)+';'+Str(x)+'H';
End;



const
  AnsiTbl : string[8]='04261537';
Function Attr2Ansi(Attr,OAttr:longint):string;
{
  Convert Attr to an Ansi String, the Optimal code is calculate
  with use of the old OAttr
}
var
  hstr : string[16];
  OFg,OBg,Fg,Bg : longint;

  procedure AddSep(ch:char);
  begin
    if length(hstr)>0 then
     hstr:=hstr+';';
    hstr:=hstr+ch;
  end;

begin
  if Attr=OAttr then
   begin
     Attr2Ansi:='';
     exit;
   end;
  Hstr:='';
  Fg:=Attr and $f;
  Bg:=Attr shr 4;
  OFg:=OAttr and $f;
  OBg:=OAttr shr 4;
  if (OFg<>7) or (Fg=7) or ((OFg>7) and (Fg<8)) or ((OBg>7) and (Bg<8)) then
   begin
     hstr:='0';
     OFg:=7;
     OBg:=0;
   end;
  if (Fg>7) and (OFg<8) then
   begin
     AddSep('1');
     OFg:=OFg or 8;
   end;
  if (Bg and 8)<>(OBg and 8) then
   begin
     AddSep('5');
     OBg:=OBg or 8;
   end;
  if (Fg<>OFg) then
   begin
     AddSep('3');
     hstr:=hstr+AnsiTbl[(Fg and 7)+1];
   end;
  if (Bg<>OBg) then
   begin
     AddSep('4');
     hstr:=hstr+AnsiTbl[(Bg and 7)+1];
   end;
  if hstr='0' then
   hstr:='';
  Attr2Ansi:=#27'['+hstr+'m';
end;



Function Ansi2Attr(Const HStr:String;oattr:longint):longint;
{
  Convert an Escape sequence to an attribute value, uses Oattr as the last
  color written
}
var
  i,j : longint;
begin
  i:=2;
  if (Length(HStr)<3) or (Hstr[1]<>#27) or (Hstr[2]<>'[') then
   i:=255;
  while (i<length(Hstr)) do
   begin
     inc(i);
     case Hstr[i] of
      '0' : OAttr:=7;
      '1' : OAttr:=OAttr or $8;
      '5' : OAttr:=OAttr or $80;
      '3' : begin
              inc(i);
              j:=pos(Hstr[i],AnsiTbl);
              if j>0 then
               OAttr:=(OAttr and $f8) or (j-1);
            end;
      '4' : begin
              inc(i);
              j:=pos(Hstr[i],AnsiTbl);
              if j>0 then
               OAttr:=(OAttr and $8f) or ((j-1) shl 4);
            end;
      'm' : i:=length(HStr);
     end;
   end;
  Ansi2Attr:=OAttr;
end;



{*****************************************************************************
                          Buffered StdIn/StdOut IO
*****************************************************************************}

const
  ttyIn=0;  {Handles for stdin/stdout}
  ttyOut=1;
  ttyFlush:boolean=true;
{Buffered Input/Output}
  InSize=256;
  OutSize=1024;
var
  InBuf  : array[0..InSize-1] of char;
  InCnt,
  InHead,
  InTail : longint;
  OutBuf : array[0..OutSize-1] of char;
  OutCnt : longint;


{Flush Output Buffer}
procedure ttyFlushOutput;
begin
  if OutCnt>0 then
   begin
     fdWrite(ttyOut,OutBuf,OutCnt);
     OutCnt:=0;
   end;
end;



Function ttySetFlush(b:boolean):boolean;
begin
  ttySetFlush:=ttyFlush;
  ttyFlush:=b;
  if ttyFlush then
   ttyFlushOutput;
end;


{Send Char to Remote}
Procedure ttySendChar(c:char);
Begin
  if OutCnt<OutSize then
   begin
     OutBuf[OutCnt]:=c;
     inc(OutCnt);
   end;
{Full ?}
  if (OutCnt>=OutSize) then
   ttyFlushOutput;
End;



{Send String to Remote}
procedure ttySendStr(const hstr:string);
var
  i : longint;
begin
  for i:=1to length(hstr) do
   ttySendChar(hstr[i]);
  if ttyFlush then
   ttyFlushOutput;
end;



{Get Char from Remote}
function ttyRecvChar:char;
var
  Readed,i : longint;
begin
{Buffer Empty? Yes, Input from StdIn}
  if (InHead=InTail) then
   begin
   {Calc Amount of Chars to Read}
     i:=InSize-InHead;
     if InTail>InHead then
      i:=InTail-InHead;
   {Read}
     Readed:=fdRead(TTYIn,InBuf[InHead],i);
   {Increase Counters}
     inc(InCnt,Readed);
     inc(InHead,Readed);
   {Wrap if End has Reached}
     if InHead>=InSize then
      InHead:=0;
   end;
{Check Buffer}
  if (InCnt=0) then
   ttyRecvChar:=#0
  else
   begin
     ttyRecvChar:=InBuf[InTail];
     dec(InCnt);
     inc(InTail);
     if InTail>=InSize then
      InTail:=0;
   end;
end;


{*****************************************************************************
                       Screen Routines not Window Depended
*****************************************************************************}

procedure ttyGotoXY(x,y:longint);
{
  Goto XY on the Screen, if a value is 0 the goto the current
  postion of that value and always recalc the ansicode for it
}
begin
  if x=0 then
   begin
     x:=CurrX;
     CurrX:=$ff;
   end;
  if y=0 then
   begin
     y:=CurrY;
     CurrY:=$ff;
   end;
  if OutputRedir then
   begin
     if longint(y)-longint(CurrY)=1 then
      ttySendStr(#10);
   end
  else
   ttySendStr(XY2Ansi(x,y,CurrX,CurrY));
  CurrX:=x;
  CurrY:=y;
end;



procedure ttyColor(a:longint);
{
  Set Attribute to A, only output if not the last attribute is set
}
begin
  if a<>OldTextAttr then
   begin
     if not OutputRedir then
      ttySendStr(Attr2Ansi(a,OldTextAttr));
     TextAttr:=a;
     OldTextAttr:=a;
   end;
end;



procedure ttyWrite(const s:string);
{
  Write a string to the output, memory copy and Current X&Y are also updated
}
var
  idx,i : longint;
begin
  ttySendStr(s);
{Update MemCopy}
  idx:=(CurrY-1)*ScreenWidth-1;
  for i:=1to length(s) do
   if s[i]=#8 then
    begin
      if CurrX>1 then
       dec(CurrX);
    end
   else
    begin
      ConsoleBuf^[idx+CurrX].ch:=s[i];
      ConsoleBuf^[idx+CurrX].attr:=TextAttr;
      inc(CurrX);
      if CurrX>ScreenWidth then
       CurrX:=ScreenWidth;
    end;
end;



Function WinMinX: Longint;
{
  Current Minimum X coordinate
}
Begin
  WinMinX:=(WindMin and $ff)+1;
End;



Function WinMinY: Longint;
{
  Current Minimum Y Coordinate
}
Begin
  WinMinY:=(WindMin shr 8)+1;
End;



Function WinMaxX: Longint;
{
  Current Maximum X coordinate
}
Begin
  WinMaxX:=(WindMax and $ff)+1;
End;



Function WinMaxY: Longint;
{
  Current Maximum Y coordinate;
}
Begin
  WinMaxY:=(WindMax shr 8) + 1;
End;



Function FullWin:boolean;
{
  Full Screen 80x25? Window(1,1,80,25) is used, allows faster routines
}
begin
  FullWin:=(WinMinX=1) and (WinMinY=1) and
           (WinMaxX=ScreenWidth) and (WinMaxY=ScreenHeight);
end;


procedure LineWrite(const temp:String);
{
  Write a Line to the screen, doesn't write on 80,25 under Dos
  the Current CurrX is set to WinMax. NO MEMORY UPDATE!
}
begin
  CurrX:=WinMaxX+1;
  if (CurrX>=ScreenWidth) then
   CurrX:=WinMaxX;
  ttySendStr(Temp);
end;



procedure DoEmptyLine(y,xl,xh:longint);
{
  Write an Empty line at Row Y from Col Xl to XH, Memory is also updated
}
var
  len : longint;
begin
  ttyGotoXY(xl,y);
  len:=xh-xl+1;
  LineWrite(Space(len));
  FillWord(ConsoleBuf^[(y-1)*ScreenWidth+xl-1],len,(TextAttr shl 8)+ord(' '));
end;



procedure DoScrollLine(y1,y2,xl,xh:longint);
{
  Move Line y1 to y2, use only columns Xl-Xh, Memory is updated also
}
var
  Temp    : string;
  idx,
  OldAttr,
  x,attr  : longint;
begin
  ttyGotoXY(xl,y2);
{ precalc ConsoleBuf[] y-offset }
  idx:=(y1-1)*ScreenWidth-1;
{ update screen }
  OldAttr:=$ff;
  Temp:='';
  For x:=xl To xh Do
   Begin
     attr:=ConsoleBuf^[idx+x].attr;
     if (attr<>OldAttr) and (not OutputRedir) then
      begin
        temp:=temp+Attr2Ansi(Attr,OldAttr);
        OldAttr:=Attr;
      end;
     Temp:=Temp+ConsoleBuf^[idx+x].ch;
     if (x=xh) or (length(Temp)>240) then
      begin
        LineWrite(Temp);
        Temp:='';
      end;
   End;
{Update memory copy}
  Move(ConsoleBuf^[(y1-1)*ScreenWidth+xl-1],ConsoleBuf^[(y2-1)*ScreenWidth+xl-1],(xh-xl+1)*2);
end;



Procedure TextColor(Color: Byte);
{
  Switch foregroundcolor
}
  var AddBlink : byte;
Begin
  If (Color>15) Then
    AddBlink:=Blink
  else
    AddBlink:=0;
  ttyColor((Color and $f) or (TextAttr and $70) or AddBlink);
End;



Procedure TextBackground(Color: Byte);
{
  Switch backgroundcolor
}
Begin
  TextAttr:=((Color shl 4) and ($f0 and not Blink)) or (TextAttr and ($0f OR Blink));
  ttyColor(TextAttr);
End;



Procedure HighVideo;
{
  Set highlighted output.
}
Begin
  TextColor(TextAttr Or $08);
End;



Procedure LowVideo;
{
  Set normal output
}
Begin
  TextColor(TextAttr And $77);
End;



Procedure NormVideo;
{
  Set normal back and foregroundcolors.
}
Begin
  TextColor(7);
  TextBackGround(0);
End;



Procedure GotoXy(X: Byte; Y: Byte);
{
  Go to coordinates X,Y in the current window.
}
Begin
  If (X>0) and (X<=WinMaxX- WinMinX+1) and
     (Y>0) and (Y<=WinMaxY-WinMinY+1) Then
   Begin
     Inc(X,WinMinX-1);
     Inc(Y,WinMinY-1);
     ttyGotoXY(x,y);
   End;
End;



Procedure Window(X1, Y1, X2, Y2: Byte);
{
  Set screen window to the specified coordinates.
}
Begin
  if (X1>X2) or (X2>ScreenWidth) or
     (Y1>Y2) or (Y2>ScreenHeight) then
   exit;
  WindMin:=((Y1-1) Shl 8)+(X1-1);
  WindMax:=((Y2-1) Shl 8)+(X2-1);
  GoToXY(1,1);
End;



Procedure ClrScr;
{
  Clear the current window, and set the cursor on x1,y1
}
Var
  CY,i      : Longint;
  oldflush  : boolean;
Begin
  { See if color has changed }
  if OldTextAttr<>TextAttr then
   begin
     i:=TextAttr;
     TextAttr:=OldTextAttr;
     ttyColor(i);
   end;
  oldflush:=ttySetFlush(Flushing);
  if FullWin then
   begin
     if not OutputRedir then
      ttySendStr(#27'[H'#27'[2J');
     CurrX:=1;
     CurrY:=1;
     FillWord(ConsoleBuf^,ScreenWidth*ScreenHeight,(TextAttr shl 8)+ord(' '));
   end
  else
   begin
     For Cy:=WinMinY To WinMaxY Do
      DoEmptyLine(Cy,WinMinX,WinMaxX);
     GoToXY(1,1);
   end;
  ttySetFlush(oldflush);
End;



Procedure ClrEol;
{
  Clear from current position to end of line.
}
var
  len,i : longint;
  IsLastLine : boolean;
Begin
  { See if color has changed }
  if OldTextAttr<>TextAttr then
   begin
     i:=TextAttr;
     TextAttr:=OldTextAttr;
     ttyColor(i);
   end;
  if FullWin or (WinMaxX = ScreenWidth) then
   begin
     if not OutputRedir then
      ttySendStr(#27'[K');
   end
  else
   begin
   { Tweak windmax so no scrolling happends }
     len:=WinMaxX-CurrX+1;
     IsLastLine:=false;
     if CurrY=WinMaxY then
      begin
        inc(WindMax,$0203);
        IsLastLine:=true;
      end;
     ttySendStr(Space(len));
     if IsLastLine then
      dec(WindMax,$0203);
     ttyGotoXY(0,0);
   end;
End;



Function WhereX: Byte;
{
  Return current X-position of cursor.
}
Begin
  WhereX:=CurrX-WinMinX+1;
End;



Function WhereY: Byte;
{
  Return current Y-position of cursor.
}
Begin
  WhereY:=CurrY-WinMinY+1;
End;



Procedure ScrollScrnRegionUp(xl,yl,xh,yh, count: longint);
{
  Scroll the indicated region count lines up. The empty lines are filled
  with blanks in the current color. The screen position is restored
  afterwards.
}
Var
  y,oldx,oldy : byte;
  oldflush    : boolean;
Begin
  oldflush:=ttySetFlush(Flushing);
  oldx:=CurrX;
  oldy:=CurrY;
{Scroll}
  For y:=yl to yh-count do
   DoScrollLine(y+count,y,xl,xh);
{Restore TextAttr}
  ttySendStr(Attr2Ansi(TextAttr,$ff));
{Fill the rest with empty lines}
  for y:=yh-count+1 to yh do
   DoEmptyLine(y,xl,xh);
{Restore current position}
  ttyGotoXY(OldX,OldY);
  ttySetFlush(oldflush);
End;



Procedure ScrollScrnRegionDown(xl,yl,xh,yh, count: longint);
{
  Scroll the indicated region count lines down. The empty lines are filled
  with blanks in the current color. The screen position is restored
  afterwards.
}
Var
  y,oldx,oldy : byte;
  oldflush    : boolean;
Begin
  oldflush:=ttySetFlush(Flushing);
  oldx:=CurrX;
  oldy:=CurrY;
{Scroll}
  for y:=yh downto yl+count do
   DoScrollLine(y-count,y,xl,xh);
{Restore TextAttr}
  ttySendStr(Attr2Ansi(TextAttr,$ff));
{Fill the rest with empty lines}
  for y:=yl to yl+count-1 do
   DoEmptyLine(y,xl,xh);
{Restore current position}
  ttyGotoXY(OldX,OldY);
  ttySetFlush(oldflush);
End;



{*************************************************************************
                            KeyBoard
*************************************************************************}

Const
  KeyBufferSize = 20;
var
  KeyBuffer : Array[0..KeyBufferSize-1] of Char;
  KeyPut,
  KeySend   : longint;

Procedure PushKey(Ch:char);
Var
  Tmp : Longint;
Begin
  Tmp:=KeyPut;
  Inc(KeyPut);
  If KeyPut>=KeyBufferSize Then
   KeyPut:=0;
  If KeyPut<>KeySend Then
   KeyBuffer[Tmp]:=Ch
  Else
   KeyPut:=Tmp;
End;



Function PopKey:char;
Begin
  If KeyPut<>KeySend Then
   Begin
     PopKey:=KeyBuffer[KeySend];
     Inc(KeySend);
     If KeySend>=KeyBufferSize Then
      KeySend:=0;
   End
  Else
   PopKey:=#0;
End;



Procedure PushExt(b:byte);
begin
  PushKey(#0);
  PushKey(chr(b));
end;



const
  AltKeyStr  : string[38]='qwertyuiopasdfghjklzxcvbnm1234567890-=';
  AltCodeStr : string[38]=#016#017#018#019#020#021#022#023#024#025#030#031#032#033#034#035#036#037#038+
                          #044#045#046#047#048#049#050#120#121#122#123#124#125#126#127#128#129#130#131;
Function FAltKey(ch:char):byte;
var
  Idx : longint;
Begin
  Idx:=Pos(ch,AltKeyStr);
  if Idx>0 then
   FAltKey:=byte(AltCodeStr[Idx])
  else
   FAltKey:=0;
End;



Function KeyPressed:Boolean;
var
  fdsin : fdSet;
Begin
  if (KeySend<>KeyPut) or (InCnt>0) then
   KeyPressed:=true
  else
   begin
     FD_Zero(fdsin);
     fd_Set(TTYin,fdsin);
     Keypressed:=(Select(TTYIn+1,@fdsin,nil,nil,0)>0);
   end;
End;


Function ReadKey:char;
Var
  ch       : char;
  OldState,
  State    : longint;
  FDS      : FDSet;
Begin
{Check Buffer first}
  if KeySend<>KeyPut then
   begin
     ReadKey:=PopKey;
     exit;
   end;
{Wait for Key}

  FD_Zero (FDS);
  FD_Set (0,FDS);
  Select (1,@FDS,nil,nil,nil);

  ch:=ttyRecvChar;
{Esc Found ?}
  CASE ch OF
  #27: begin
     State:=1;
     Delay(10);
     while (State<>0) and (KeyPressed) do
      begin
        ch:=ttyRecvChar;
        OldState:=State;
        State:=0;
        case OldState of
        1 : begin {Esc}
              case ch of
          'a'..'z',
          '0'..'9',
           '-','=' : PushExt(FAltKey(ch));
               #10 : PushKey(#10);
               '[' : State:=2;
               else
                begin
                  PushKey(ch);
                  PushKey(#27);
                end;
               end;
            end;
        2 : begin {Esc[}
              case ch of
               '[' : State:=3;
               'A' : PushExt(72);
               'B' : PushExt(80);
               'C' : PushExt(77);
               'D' : PushExt(75);
               {$IFDEF FREEBSD}
               {'E' - Center key, not handled in DOS TP7}
               'F' : PushExt(79); {End}
               'G': PushExt(81); {PageDown}
               {$ELSE}
               'G' : PushKey('5'); {Center key, Linux}
               {$ENDIF}
               'H' : PushExt(71);
               {$IFDEF FREEBSD}
               'I' : PushExt(73); {PageUp}
               {$ENDIF}
               'K' : PushExt(79);
               {$IFDEF FREEBSD}
               'L' : StoExt(82);   {Insert - Deekoo}
               'M' : StoExt(59);   {F1-F10 - Deekoo}
               'N' : StoExt(60);   {F2}
               'O' : StoExt(61);   {F3}
               'P' : StoExt(62);   {F4}
               'Q' : StoExt(63);   {F5}
               'R' : StoExt(64);   {F6}
               'S' : StoExt(65);   {F7}
               'T' : StoExt(66);   {F8}
               'U' : StoExt(67);   {F9}
               'V' : StoExt(68);   {F10}
               {Not sure if TP/BP handles F11 and F12 like this normally;
                   In pcemu, a TP7 executable handles 'em this way, though.}
               'W' : StoExt(133);   {F11}
               'X' : StoExt(134);   {F12}
               'Y' : StoExt(84);   {Shift-F1}
               'Z' : StoExt(85);   {Shift-F2}
               'a' : StoExt(86);   {Shift-F3}
               'b' : StoExt(87);   {Shift-F4}
               'c' : StoExt(88);   {Shift-F5}
               'd' : StoExt(89);   {Shift-F6}
               'e' : StoExt(90);   {Shift-F7}
               'f' : StoExt(91);   {Shift-F8}
               'g' : StoExt(92);   {Shift-F9}
               'h' : StoExt(93);   {Shift-F10}
               'i' : StoExt(135);   {Shift-F11}
               'j' : StoExt(136);   {Shift-F12}
               'k' : StoExt(94);        {Ctrl-F1}
               'l' : StoExt(95);
               'm' : StoExt(96);
               'n' : StoExt(97);
               'o' : StoExt(98);
               'p' : StoExt(99);
               'q' : StoExt(100);
               'r' : StoExt(101);
               's' : StoExt(102);
               't' : StoExt(103);   {Ctrl-F10}
               'u' : StoExt(137);   {Ctrl-F11}
               'v' : StoExt(138);   {Ctrl-F12}
               {$ENDIF}
               '1' : State:=4;
               '2' : State:=5;
               '3' : State:=6;
               '4' : PushExt(79);
               '5' : PushExt(73);
               '6' : PushExt(81);
              else
               begin
                 PushKey(ch);
                 PushKey('[');
                 PushKey(#27);
               end;
              end;
              if ch in ['4'..'6'] then
               State:=255;
            end;
        3 : begin {Esc[[}
              case ch of
               'A' : PushExt(59);
               'B' : PushExt(60);
               'C' : PushExt(61);
               'D' : PushExt(62);
               'E' : PushExt(63);
              end;
            end;
        4 : begin {Esc[1}
              case ch of
               '~' : PushExt(71);
               '7' : PushExt(64);
               '8' : PushExt(65);
               '9' : PushExt(66);
              end;
              if (Ch<>'~') then
               State:=255;
            end;
        5 : begin {Esc[2}
              case ch of
               '~' : PushExt(82);
               '0' : pushExt(67);
               '1' : PushExt(68);
               '3' : PushExt(133); {F11}
                {Esc[23~ is also shift-F1,shift-F11}
               '4' : PushExt(134); {F12}
                {Esc[24~ is also shift-F2,shift-F12}
               '5' : PushExt(86); {Shift-F3}
               '6' : PushExt(87); {Shift-F4}
               '8' : PushExt(88); {Shift-F5}
               '9' : PushExt(89); {Shift-F6}
              end;
              if (Ch<>'~') then
               State:=255;
            end;
        6 : begin {Esc[3}
              case ch of
               '~' : PushExt(83); {Del}
               '1' : PushExt(90); {Shift-F7}
               '2' : PushExt(91); {Shift-F8}
               '3' : PushExt(92); {Shift-F9}
               '4' : PushExt(93); {Shift-F10}
              end;
              if (Ch<>'~') then
               State:=255;
            end;
      255 : ;
        end;
        if State<>0 then
         Delay(10);
      end;
     if State=1 then
      PushKey(ch);
   end;
  #127: PushKey(#8);
  else PushKey(ch);
  End;
  ReadKey:=PopKey;
End;


Procedure Delay(DTime: Word);
{
  Wait for DTime milliseconds.
}
Begin
  Select(0,nil,nil,nil,DTime);
End;


{****************************************************************************
                        Write(ln)/Read(ln) support
****************************************************************************}

procedure DoLn;
begin
  if CurrY=WinMaxY then
   begin
     if FullWin then
      begin
        ttySendStr(#10#13);
        CurrX:=WinMinX;
        CurrY:=WinMaxY;
      end
     else
      begin
        ScrollScrnRegionUp(WinMinX,WinMinY,WinMaxX,WinMaxY,1);
        ttyGotoXY(WinMinX,WinMaxY);
      end;
   end
  else
   ttyGotoXY(WinMinX,CurrY+1);
end;


var
  Lastansi  : boolean;
  AnsiCode  : string;
Procedure DoWrite(const s:String);
{
  Write string to screen, parse most common AnsiCodes
}
var
  found,
  OldFlush  : boolean;
  x,y,
  i,j,
  SendBytes : longint;

  function AnsiPara(var hstr:string):byte;
  var
    k,j  : longint;
    code : word;
  begin
    j:=pos(';',hstr);
    if j=0 then
     j:=length(hstr);
    val(copy(hstr,3,j-3),k,code);
    Delete(hstr,3,j-2);
    if k=0 then
     k:=1;
    AnsiPara:=k;
  end;

  procedure SendText;
  var
    LeftX : longint;
  begin
    while (SendBytes>0) do
     begin
       LeftX:=WinMaxX-CurrX+1;
       if (SendBytes>LeftX) or (CurrX+SendBytes=81) then
        begin
          ttyWrite(Copy(s,i-SendBytes,LeftX));
          dec(SendBytes,LeftX);
          DoLn;
        end
       else
        begin
          ttyWrite(Copy(s,i-SendBytes,SendBytes));
          SendBytes:=0;
        end;
     end;
  end;

begin
  oldflush:=ttySetFlush(Flushing);
{ Support textattr:= changing }
  if OldTextAttr<>TextAttr then
   begin
     i:=TextAttr;
     TextAttr:=OldTextAttr;
     ttyColor(i);
   end;
{ write the stuff }
  SendBytes:=0;
  i:=1;
  while (i<=length(s)) do
   begin
     if (s[i]=#27) or (LastAnsi) then
      begin
        SendText;
        LastAnsi:=false;
        j:=i;
        found:=false;
        while (j<=length(s)) and (not found) do
         begin
           found:=not (s[j] in [#27,'[','0'..'9',';','?']);
           inc(j);
         end;
        Ansicode:=AnsiCode+Copy(s,i,j-i);
        if found then
         begin
           case AnsiCode[length(AnsiCode)] of
            'm' : ttyColor(Ansi2Attr(AnsiCode,TextAttr));
            'H' : begin {No other way :( Coz First Para=Y}
                    y:=AnsiPara(AnsiCode);
                    x:=AnsiPara(AnsiCode);
                    GotoXY(x,y);
                  end;
            'J' : if AnsiPara(AnsiCode)=2 then
                   ClrScr;
            'K' : ClrEol;
            'A' : GotoXY(CurrX,Max(CurrY-AnsiPara(AnsiCode),WinMinY));
            'B' : GotoXY(CurrX,Min(CurrY+AnsiPara(AnsiCode),WinMaxY));
            'C' : GotoXY(Min(CurrX+AnsiPara(AnsiCode),WinMaxX),CurrY);
            'D' : GotoXY(Max(CurrX-AnsiPara(AnsiCode),WinMinX),CurrY);
            'h' : ; {Stupid Thedraw [?7h Code}
           else
            found:=false;
           end;
         end
        else
         begin
           LastAnsi:=true;
           found:=true;
         end;
      {Clear AnsiCode?}
        if not LastAnsi then
         AnsiCode:='';
      {Increase Idx or SendBytes}
        if found then
         i:=j-1
        else
         inc(SendBytes);
      end
     else
      begin
        LastAnsi:=false;
        case s[i] of
         #13 : begin {CR}
                 SendText;
                 ttyGotoXY(WinMinX,CurrY);
               end;
         #10 : begin {NL}
                 SendText;
                 DoLn;
               end;
          #9 : begin {Tab}
                 SendText;
                 ttyWrite(Space(9-((CurrX-1) and $08)));
               end;
          #8 : begin {BackSpace}
                 SendText;
                 ttyWrite(#8);
               end;
        else
         inc(SendBytes);
        end;
      end;
     inc(i);
   end;
  if SendBytes>0 then
   SendText;
  ttySetFlush(oldFLush);
end;


Function CrtWrite(Var F: TextRec): Integer;
{
  Top level write function for CRT
}
Var
  Temp : String;
  idx,i : Longint;
  oldflush : boolean;
Begin
  oldflush:=ttySetFlush(Flushing);
  idx:=0;
  while (F.BufPos>0) do
   begin
     i:=F.BufPos;
     if i>255 then
      i:=255;
     Move(F.BufPTR^[idx],Temp[1],F.BufPos);
     Temp[0]:=Chr(i);
     DoWrite(Temp);
     dec(F.BufPos,i);
     inc(idx,i);
   end;

  ttySetFlush(oldFLush);
  CrtWrite:=0;
End;


Function CrtRead(Var F: TextRec): Integer;
{
  Read from CRT associated file.
}
var
  i : longint;
Begin
  F.BufEnd:=fdRead(F.Handle, F.BufPtr^, F.BufSize);
{ fix #13 only's -> #10 to overcome terminal setting }
  for i:=1to F.BufEnd do
   begin
     if (F.BufPtr^[i-1]=#13) and (F.BufPtr^[i]<>#10) then
      F.BufPtr^[i-1]:=#10;
   end;
  F.BufPos:=F.BufEnd;
  if not(OutputRedir or InputRedir) then
    CrtWrite(F)
  else F.BufPos := 0;
  CrtRead:=0;
End;


Function CrtReturn(Var F:TextRec):Integer;
Begin
  CrtReturn:=0;
end;


Function CrtClose(Var F: TextRec): Integer;
{
  Close CRT associated file.
}
Begin
  F.Mode:=fmClosed;
  CrtClose:=0;
End;


Function CrtOpen(Var F: TextRec): Integer;
{
  Open CRT associated file.
}
Begin
  If F.Mode=fmOutput Then
   begin
     TextRec(F).InOutFunc:=@CrtWrite;
     TextRec(F).FlushFunc:=@CrtWrite;
   end
  Else
   begin
     F.Mode:=fmInput;
     TextRec(F).InOutFunc:=@CrtRead;
     TextRec(F).FlushFunc:=@CrtReturn;
   end;
  TextRec(F).CloseFunc:=@CrtClose;
  CrtOpen:=0;
End;


procedure AssignCrt(var F: Text);
{
  Assign a file to the console. All output on file goes to console instead.
}
begin
  Assign(F,'');
  TextRec(F).OpenFunc:=@CrtOpen;
end;


{******************************************************************************
                            High Level Functions
******************************************************************************}

Procedure DelLine;
{
  Delete current line. Scroll subsequent lines up
}
Begin
  ScrollScrnRegionUp(WinMinX, CurrY, WinMaxX, WinMaxY, 1);
End;



Procedure InsLine;
{
  Insert line at current cursor position. Scroll subsequent lines down.
}
Begin
  ScrollScrnRegionDown(WinMinX, CurrY, WinMaxX, WinMaxY, 1);
End;



Procedure Sound(Hz: Word);
{
  Does nothing under linux
}
begin
end;



Procedure NoSound;
{
  Does nothing under linux
}
begin
end;



Procedure TextMode(Mode: Integer);
{
  Only Clears Screen under linux
}
begin
  ClrScr;
end;


{******************************************************************************
                                     Extra
******************************************************************************}

procedure CursorBig;
begin
  ttySendStr(#27'[?17;0;64c');
end;


procedure CursorOn;
begin
  ttySendStr(#27'[?2c');
end;


procedure CursorOff;
begin
  ttySendStr(#27'[?1c');
end;


{******************************************************************************
                               Initialization
******************************************************************************}

var
  OldIO : TermIos;
Procedure SetRawMode(b:boolean);
Var
  Tio : Termios;
Begin
  if b then
   begin
     TCGetAttr(1,Tio);
     OldIO:=Tio;
     CFMakeRaw(Tio);
   end
  else
   Tio:=OldIO;
  TCSetAttr(1,TCSANOW,Tio);
End;



procedure GetXY(var x,y:byte);
var
  fds    : fdSet;
  i,j,
  readed : longint;
  buf    : array[0..255] of char;
  s      : string[16];
begin
  x:=0;
  y:=0;
  s:=#27'[6n';
  fdWrite(0,s[1],length(s));
  FD_Zero(fds);
  FD_Set(1,fds);
  if (Select(2,@fds,nil,nil,1000)>0) then
   begin
     readed:=fdRead(1,buf,sizeof(buf));
     i:=0;
     while (i+5<readed) and (buf[i]<>#27) and (buf[i+1]<>'[') do
      inc(i);
     if i+5<readed then
      begin
        s:=space(16);
        move(buf[i+2],s[1],16);
        i:=Pos(';',s);
        if i>0 then
         begin
           Val(Copy(s,1,i-1),y);
           j:=Pos('R',s);
           if j=0 then
            j:=length(s);
           Val(Copy(s,i+1,j-(i+1)),x);
         end;
      end;
   end;
end;


Procedure GetConsoleBuf;
var
  WinInfo : TWinSize;
begin
  if Assigned(ConsoleBuf) then
   FreeMem(ConsoleBuf,ScreenHeight*ScreenWidth*2);
  if (not OutputRedir) and IOCtl(TextRec(Output).Handle,TIOCGWINSZ,@Wininfo) then
   begin
     ScreenWidth:=Wininfo.ws_col;
     ScreenHeight:=Wininfo.ws_row;
   end
  else
   begin
     ScreenWidth:=80;
     ScreenHeight:=25;
   end;
  GetMem(ConsoleBuf,ScreenHeight*ScreenWidth*2);
  FillChar(ConsoleBuf^,ScreenHeight*ScreenWidth*2,0);
end;


Procedure CrtExit;
{
  We need to restore normal keyboard mode upon exit !!
}
Begin
  ttyFlushOutput;
  SetRawMode(False);
{ remove console buf }
  if Assigned(ConsoleBuf) then
   FreeMem(ConsoleBuf,ScreenHeight*ScreenWidth*2);
  ExitProc:=ExitSave;
End;



Begin
{Hook Exit}
  ExitSave:=ExitProc;
  ExitProc:=@CrtExit;
{ Redirect the standard output }
  assigncrt(Output);
  Rewrite(Output);
  TextRec(Output).Handle:=StdOutputHandle;
  assigncrt(Input);
  Reset(Input);
  TextRec(Input).Handle:=StdInputHandle;
{ Are we redirected to a file ? }
 OutputRedir:= not IsAtty(TextRec(Output).Handle);
{ does the input come from another console or from a file? }
 InputRedir :=
   not IsAtty(TextRec(Input).Handle) or
   (not OutputRedir and
    (TTYName(TextRec(Input).Handle) <> TTYName(TextRec(Output).Handle)));
{ Get Size of terminal and set WindMax to the window }
  GetConsoleBuf;
  WindMax:=((ScreenHeight-1) Shl 8)+(ScreenWidth-1);
{Get Current X&Y or Reset to Home}
  if OutputRedir then
   begin
     CurrX:=1;
     CurrY:=1;
   end
  else
   begin
   { Set default Terminal Settings }
     SetRawMode(True);
   { Get current X,Y if not set already }
     GetXY(CurrX,CurrY);
     if (CurrX=0) then
      begin
        CurrX:=1;
        CurrY:=1;
        ttySendStr(#27'[H');
      end;
   {Reset Attribute (TextAttr=7 at startup)}
      ttySendStr(#27'[m');
    end;
End.
{
  $Log$
  Revision 1.24  2000-04-14 12:15:31  pierre
   * several bugs fixed

  Revision 1.23  2000/04/07 13:26:27  jonas
    * fix for web bug 917
    * also do not mirror input if input is another TTY than output or if
      input is redirected

  Revision 1.22  2000/02/09 16:59:31  peter
    * truncated log

  Revision 1.21  2000/01/07 16:41:39  daniel
    * copyright 2000

  Revision 1.20  2000/01/07 16:32:26  daniel
    * copyright 2000 added

  Revision 1.19  1999/10/22 14:36:20  peter
    * crtreturn also needs f:textrec as parameter

  Revision 1.18  1999/09/07 07:47:46  peter
    * write > 255 chars

  Revision 1.17  1999/09/07 07:38:09  michael
  + Applied readkey patch from Deekoo L

}