{$mode objfpc}
uses sysutils;

var
  error: boolean;

{$r+}
function testlongint_int64(i: int64; shouldfail: boolean): boolean;
var
  l: longint;
  failed: boolean;
begin
  failed := false;
  try
    l := i;
  except
    failed := true;
  end;
  result := failed = shouldfail;
  error := error or not result;
end;

function testlongint_qword(i: qword; shouldfail: boolean): boolean;
var
  l: longint;
  failed: boolean;
begin
  failed := false;
  try
    l := i;
  except
    failed := true;
  end;
  result := failed = shouldfail;
  error := error or not result;
end;

function testdword_int64(i: int64; shouldfail: boolean): boolean;
var
  l: dword;
  failed: boolean;
begin
  failed := false;
  try
    l := i;
  except
    failed := true;
  end;
  result := failed = shouldfail;
  error := error or not result;
end;

function testdword_qword(i: qword; shouldfail: boolean): boolean;
var
  l: dword;
  failed: boolean;
begin
  failed := false;
  try
    l := i;
  except
    failed := true;
  end;
  result := failed = shouldfail;
  error := error or not result;
end;

{$r-}

var
  i: int64;
  q: qword;
begin
  error := false;
{ *********************** int64 to longint ********************* }
  writeln('int64 to longint');
  i := $ffffffffffffffff;
  writeln(i);
  if not testlongint_int64(i,false) then
    writeln('test1 failed');
  i := i and $ffffffff00000000;
  writeln(i);
  if not testlongint_int64(i,true) then
    writeln('test2 failed');
  inc(i);
  writeln(i);
  if not testlongint_int64(i,true) then
    writeln('test3 failed');
  longint(i) := $80000000;
  writeln(i);
  if not testlongint_int64(i,false) then
    writeln('test4 failed');
  i := 0;
  longint(i) := $80000000;
  writeln(i);
  if not testlongint_int64(i,true) then
    writeln('test5 failed');
  dec(i);
  writeln(i);
  if not testlongint_int64(i,false) then
    writeln('test6 failed');
  i := 0;
  longint(i) := $ffffffff;
  writeln(i);
  if not testlongint_int64(i,true) then
    writeln('test7 failed');
  i := 0;
  writeln(i);
  if not testlongint_int64(i,false) then
    writeln('test8 failed');

{ *********************** qword to longint ********************* }
  writeln;
  writeln('qword to longint');
  q := $ffffffffffffffff;
  writeln(q);
  if not testlongint_qword(q,true) then
    writeln('test1 failed');
  q := q and $ffffffff00000000;
  writeln(q);
  if not testlongint_qword(q,true) then
    writeln('test2 failed');
  inc(q);
  writeln(q);
  if not testlongint_qword(q,true) then
    writeln('test3 failed');
  longint(q) := $80000000;
  writeln(q);
  if not testlongint_qword(q,true) then
    writeln('test4 failed');
  q := 0;
  longint(q) := $80000000;
  writeln(q);
  if not testlongint_qword(q,true) then
    writeln('test5 failed');
  dec(q);
  writeln(q);
  if not testlongint_qword(q,false) then
    writeln('test6 failed');
  q := 0;
  longint(q) := $ffffffff;
  writeln(q);
  if not testlongint_qword(q,true) then
    writeln('test7 failed');
  q := 0;
  writeln(q);
  if not testlongint_qword(q,false) then
    writeln('test8 failed');

{ *********************** int64 to dword ********************* }
  writeln;
  writeln('int64 to dword');
  i := $ffffffffffffffff;
  writeln(i);
  if not testdword_int64(i,true) then
    writeln('test1 failed');
  i := i and $ffffffff00000000;
  writeln(i);
  if not testdword_int64(i,true) then
    writeln('test2 failed');
  inc(i);
  writeln(i);
  if not testdword_int64(i,true) then
    writeln('test3 failed');
  longint(i) := $80000000;
  writeln(i);
  if not testdword_int64(i,true) then
    writeln('test4 failed');
  i := 0;
  longint(i) := $80000000;
  writeln(i);
  if not testdword_int64(i,false) then
    writeln('test5 failed');
  dec(i);
  writeln(i);
  if not testdword_int64(i,false) then
    writeln('test6 failed');
  i := 0;
  longint(i) := $ffffffff;
  writeln(i);
  if not testdword_int64(i,false) then
    writeln('test7 failed');
  i := 0;
  writeln(i);
  if not testdword_int64(i,false) then
    writeln('test8 failed');

{ *********************** qword to dword ********************* }
  writeln;
  writeln('qword to dword');
  q := $ffffffffffffffff;
  writeln(q);
  if not testdword_qword(q,true) then
    writeln('test1 failed');
  q := q and $ffffffff00000000;
  writeln(q);
  if not testdword_qword(q,true) then
    writeln('test2 failed');
  inc(q);
  writeln(q);
  if not testdword_qword(q,true) then
    writeln('test3 failed');
  longint(q) := $80000000;
  writeln(q);
  if not testdword_qword(q,true) then
    writeln('test4 failed');
  q := 0;
  longint(q) := $80000000;
  writeln(q);
  if not testdword_qword(q,false) then
    writeln('test5 failed');
  dec(q);
  writeln(q);
  if not testdword_qword(q,false) then
    writeln('test6 failed');
  q := 0;
  longint(q) := $ffffffff;
  writeln(q);
  if not testdword_qword(q,false) then
    writeln('test7 failed');
  q := 0;
  writeln(q);
  if not testdword_qword(q,false) then
    writeln('test8 failed');

  if error then
    begin
      writeln;
      writeln('still range check problems!');
      halt(1);
    end;
end.
