{$H+}
Program AnsiTest;

Type
   PS=^String;

procedure test;
var
  P:PS;
Begin
  New(P);
  P^:='';
  P^:=P^+'BLAH';
  P^:=P^+' '+P^;
  Writeln(P^);
  Dispose(P);
end;

var
  membefore : longint;

begin
  membefore:=memavail;
  test;
  if membefore<>memavail then
    begin
      Writeln('Memory hole using pointers to ansi strings');
      Halt(1);
    end
  else
    Writeln('No memory hole with pointers to ansi strings');
end.

