const
   q2 : qword = 1234;
   i2 : int64 = -1234;

var
   q : qword;
   i : int64;
   l1,l2 : longint;
   s : string;

procedure p1(q : qword;i : int64);

  begin
  end;

function f1 : qword;

  begin
  end;

function f2 : int64;

  begin
  end;

begin
   p1(q,i);
   q:=f1;
   i:=f2;
   q:=q+q;
   i:=((i+i) xor (i+i)) or ((i+i) xor (i+i));
   q:=q shl l1;
   q:=q shr l1;
   q:=(q shl l1)+(q shl l1);

   q:=not(q);
   i:=not(i);
   q:=not(q xor q);
   i:=not(i or i);

   { unary minus }
   q:=-q;
   i:=-i;
   q:=-(q xor q);
   i:=-(i or i);

   { multiplication }
   q:=q*q;
   i:=i*i;

   q:=q*(q*q);
   i:=i*(i*i);

   q:=(q*q)*(q*q);
   q:=((q*q)*(q*q))*((q*q)*(q*q));

   if q<>q then
     begin
        writeln('Error :(');
     end;

   if q>q then
     begin
        writeln('Error :(');
     end;

   if i>f2 then
     begin
        writeln('Error :(');
     end;
   if l1>l2 then
     begin
        writeln('Error :(');
     end;

   write(q);
   write(i);
   read(q);
   read(i);
   str(q,s);
   str(i,s);
end.
