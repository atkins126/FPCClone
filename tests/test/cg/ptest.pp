{
  Program to test linking between C and pascal units.

  Pascal counter part
}

unit ptest;

interface

{ Use C alignment of records }
{$PACKRECORDS C}
const
   RESULT_U8BIT = $55;
   RESULT_U16BIT = $500F;
   RESULT_U32BIT = $500F0000;
   RESULT_U64BIT = $1BCDABCD;
   RESULT_S16BIT = -12;
   RESULT_S32BIT = -120;
   RESULT_S64BIT = -12000;
   RESULT_FLOAT  = 14.54;
   RESULT_DOUBLE = 15.54;
   RESULT_LONGDOUBLE = 16.54;
   RESULT_PCHAR  = 'Hello world';

type
 _1byte_ = record
  u8 : byte;
 end;

 _3byte_ = record
  u8 : byte;
  u16 : word;
 end;

 _5byte_ = record
  u8 : byte;
  u32 : cardinal;
 end;

_7byte_ = record
  u8: byte;
  s64: int64;
  u16: word;
end;
  byte_array = array [0..1] of byte;
  word_array = array [0..1] of word;
  cardinal_array = array [0..1] of cardinal;
  qword_array = array [0..1] of qword;
  smallint_array = array [0..1] of smallint;
  longint_array = array [0..1] of longint;
  int64_array = array [0..1] of int64;
  single_array = array [0..1] of single;
  double_array = array [0..1] of double;
  extended_array = array [0..1] of extended;

var
  global_u8bit : byte; cvar;
  global_u16bit : word; cvar;
  global_u32bit : cardinal; cvar;
  global_u64bit : qword; cvar;
  global_s16bit : smallint; cvar;
  global_s32bit : longint; cvar;
  global_s64bit : int64; cvar;
  global_float : single; cvar;
  global_double : double; cvar;
  global_long_double : extended; cvar;

{ simple parameter passing }
procedure test_param_u8(x: byte); cdecl;
procedure test_param_u16(x : word); cdecl;
procedure test_param_u32(x: cardinal); cdecl;
procedure test_param_u64(x: qword); cdecl;
procedure test_param_s16(x : smallint); cdecl;
procedure test_param_s32(x: longint); cdecl;
procedure test_param_s64(x: int64); cdecl;
procedure test_param_float(x : single); cdecl;
procedure test_param_double(x: double); cdecl;
procedure test_param_longdouble(x: extended); cdecl;
procedure test_param_var_u8(var x: byte); cdecl;

{ array parameter passing }
procedure test_array_param_u8(x: byte_array); cdecl;
procedure test_array_param_u16(x : word_array); cdecl;
procedure test_array_param_u32(x: cardinal_array); cdecl;
procedure test_array_param_u64(x: qword_array); cdecl;
procedure test_array_param_s16(x :smallint_array); cdecl;
procedure test_array_param_s32(x: longint_array); cdecl;
procedure test_array_param_s64(x: int64_array); cdecl;
procedure test_array_param_float(x : single_array); cdecl;
procedure test_array_param_double(x: double_array); cdecl;
procedure test_array_param_longdouble(x: extended_array); cdecl;

{ mixed parameter passing }
procedure test_param_mixed_u16(z: byte; x : word; y :byte); cdecl;
procedure test_param_mixed_u32(z: byte; x: cardinal; y: byte); cdecl;
procedure test_param_mixed_s64(z: byte; x: int64; y: byte); cdecl;
procedure test_param_mixed_float(x: single; y: byte); cdecl;
procedure test_param_mixed_double(x: double; y: byte); cdecl;
procedure test_param_mixed_long_double(x: extended; y: byte); cdecl;
procedure test_param_mixed_var_u8(var x: byte;y:byte); cdecl;
{ structure parameter testing }
procedure test_param_struct_tiny(buffer :   _1BYTE_); cdecl;
procedure test_param_struct_small(buffer :  _3BYTE_); cdecl;
procedure test_param_struct_medium(buffer : _5BYTE_); cdecl;
procedure test_param_struct_large(buffer :  _7BYTE_); cdecl;
{ mixed with structure parameter testing }
procedure test_param_mixed_struct_tiny(buffer :   _1BYTE_; y :byte); cdecl;
procedure test_param_mixed_struct_small(buffer :  _3BYTE_; y :byte); cdecl;
procedure test_param_mixed_struct_medium(buffer : _5BYTE_; y :byte); cdecl;
procedure test_param_mixed_struct_large(buffer :  _7BYTE_; y :byte); cdecl;
{ function result value testing }
function test_function_u8: byte; cdecl;
function test_function_u16: word; cdecl;
function test_function_u32: cardinal; cdecl;
function test_function_u64: qword; cdecl;
function test_function_s16: smallint; cdecl;
function test_function_s32: longint; cdecl;
function test_function_s64: int64; cdecl;
function test_function_pchar: pchar; cdecl;
function test_function_float : single; cdecl;
function test_function_double : double; cdecl;
function test_function_longdouble: extended; cdecl;
function test_function_tiny_struct : _1byte_; cdecl;
function test_function_small_struct : _3byte_; cdecl;
function test_function_medium_struct : _5byte_; cdecl;
function test_function_struct : _7byte_; cdecl;


implementation

{ simple parameter passing }
procedure test_param_u8(x: byte); cdecl;
  begin
    global_u8bit:=x;
  end;

procedure test_param_u16(x : word); cdecl;
  begin
    global_u16bit:=x;
  end;

procedure test_param_u32(x: cardinal); cdecl;
  begin
    global_u32bit:=x;
  end;

procedure test_param_u64(x: qword); cdecl;
  begin
    global_u64bit:=x;
  end;

procedure test_param_s16(x : smallint); cdecl;
  begin
    global_s16bit:=x;
  end;

procedure test_param_s32(x: longint); cdecl;
  begin
    global_s32bit:=x;
  end;

procedure test_param_s64(x: int64); cdecl;
  begin
    global_s64bit:=x;
  end;

procedure test_param_float(x : single); cdecl;
  begin
    global_float:=x;
  end;

procedure test_param_double(x: double); cdecl;
  begin
    global_double:=x;
  end;

procedure test_param_longdouble(x: extended); cdecl;
  begin
    global_long_double:=x;
  end;

procedure test_param_var_u8(var x: byte); cdecl;
  begin
    x:=RESULT_U8BIT;
  end;


{ array parameter passing }
procedure test_array_param_u8(x: byte_array); cdecl;
  begin
   global_u8bit:=x[1];
  end;

procedure test_array_param_u16(x : word_array); cdecl;
  begin
   global_u16bit:=x[1];
  end;

procedure test_array_param_u32(x: cardinal_array); cdecl;
  begin
   global_u32bit:=x[1];
  end;

procedure test_array_param_u64(x: qword_array); cdecl;
  begin
   global_u64bit:=x[1];
  end;

procedure test_array_param_s16(x :smallint_array); cdecl;
  begin
   global_s16bit:=x[1];
  end;

procedure test_array_param_s32(x: longint_array); cdecl;
  begin
   global_s32bit:=x[1];
  end;

procedure test_array_param_s64(x: int64_array); cdecl;
  begin
   global_s64bit:=x[1];
  end;

procedure test_array_param_float(x : single_array); cdecl;
  begin
   global_float:=x[1];
  end;

procedure test_array_param_double(x: double_array); cdecl;
  begin
   global_double:=x[1];
  end;

procedure test_array_param_longdouble(x: extended_array); cdecl;
  begin
   global_long_double:=x[1];
  end;


{ mixed parameter passing }
procedure test_param_mixed_u16(z: byte; x : word; y :byte); cdecl;
  begin
    global_u16bit:=x;
    global_u8bit:=y;
  end;

procedure test_param_mixed_u32(z: byte; x: cardinal; y: byte); cdecl;
  begin
    global_u32bit:=x;
    global_u8bit:=y;
  end;

procedure test_param_mixed_s64(z: byte; x: int64; y: byte); cdecl;
  begin
    global_s64bit:=x;
    global_u8bit:=y;
  end;

procedure test_param_mixed_float(x: single; y: byte); cdecl;
  begin
    global_float:=x;
    global_u8bit:=y;
  end;

procedure test_param_mixed_double(x: double; y: byte); cdecl;
  begin
    global_double:=x;
    global_u8bit:=y;
  end;

procedure test_param_mixed_long_double(x: extended; y: byte); cdecl;
  begin
    global_long_double:=x;
    global_u8bit:=y;
  end;

procedure test_param_mixed_var_u8(var x: byte;y:byte); cdecl;
  begin
    x:=RESULT_U8BIT;
    global_u8bit:=y;
  end;

{ structure parameter testing }
procedure test_param_struct_tiny(buffer :   _1BYTE_); cdecl;
  begin
    global_u8bit:=buffer.u8;
  end;

procedure test_param_struct_small(buffer :  _3BYTE_); cdecl;
  begin
    global_u8bit:=buffer.u8;
    global_u16bit:=buffer.u16;
  end;

procedure test_param_struct_medium(buffer : _5BYTE_); cdecl;
  begin
    global_u8bit:=buffer.u8;
    global_u32bit:=buffer.u32;
  end;

procedure test_param_struct_large(buffer :  _7BYTE_); cdecl;
  begin
    global_u8bit:=buffer.u8;
    global_u16bit:=buffer.u16;
    global_s64bit:=buffer.s64;
  end;

{ mixed with structure parameter testing }
procedure test_param_mixed_struct_tiny(buffer :   _1BYTE_; y :byte); cdecl;
  begin
    global_u8bit := y;
  end;

procedure test_param_mixed_struct_small(buffer :  _3BYTE_; y :byte); cdecl;
  begin
    global_u8bit := y;
    global_u16bit := buffer.u16;
  end;

procedure test_param_mixed_struct_medium(buffer : _5BYTE_; y :byte); cdecl;
  begin
    global_u8bit := y;
    global_u32bit := buffer.u32;
  end;

procedure test_param_mixed_struct_large(buffer :  _7BYTE_; y :byte); cdecl;
  begin
    global_u8bit:=y;
    global_u16bit:=buffer.u16;
    global_s64bit:=buffer.s64;
  end;

{ function result value testing }
function test_function_u8: byte; cdecl;
  begin
    test_function_u8:=RESULT_U8BIT;
  end;

function test_function_u16: word; cdecl;
  begin
    test_function_u16:=RESULT_U16BIT;
  end;

function test_function_u32: cardinal; cdecl;
  begin
    test_function_u32:=RESULT_U32BIT;
  end;

function test_function_u64: qword; cdecl;
  begin
    test_function_u64:=RESULT_U64BIT;
  end;

function test_function_s16: smallint; cdecl;
  begin
    test_function_s16:=RESULT_S16BIT;
  end;

function test_function_s32: longint; cdecl;
  begin
    test_function_s32:=RESULT_S32BIT;
  end;

function test_function_s64: int64; cdecl;
  begin
    test_function_s64:=RESULT_S64BIT;
  end;

function test_function_pchar: pchar; cdecl;
  begin
    test_function_pchar:=RESULT_PCHAR;
  end;

function test_function_float : single; cdecl;
  begin
    test_function_float:=RESULT_FLOAT;
  end;

function test_function_double : double; cdecl;
  begin
    test_function_double:=RESULT_DOUBLE;
  end;

function test_function_longdouble: extended; cdecl;
  begin
    test_function_longdouble:=RESULT_LONGDOUBLE;
  end;

function test_function_tiny_struct : _1byte_; cdecl;
  begin
    test_function_tiny_struct.u8:=RESULT_U8BIT;
  end;

function test_function_small_struct : _3byte_; cdecl;
  begin
    test_function_small_struct.u8:=RESULT_U8BIT;
    test_function_small_struct.u16:=RESULT_U16BIT;
  end;

function test_function_medium_struct : _5byte_; cdecl;
  begin
    test_function_medium_struct.u8:=RESULT_U8BIT;
    test_function_medium_struct.u32:=RESULT_U32BIT;
  end;

function test_function_struct : _7byte_; cdecl;
  begin
    test_function_struct.u8:=RESULT_U8BIT;
    test_function_struct.u16:=RESULT_U16BIT;
    test_function_struct.s64:=RESULT_S64BIT;
  end;




end.

{
  $Log$
  Revision 1.1  2002-11-04 15:17:45  pierre
   * compatibility with C checks improved


}
