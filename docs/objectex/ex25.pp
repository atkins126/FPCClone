Program ex21;

{ Program to demonstrate the TCollection.Foreach method }

Uses Objects,MyObject; { For TMyObject definition and registration }

Var C : PCollection;
    M : PMyObject;
    I : Longint;

Function CheckField (Dummy: Pointer;P : PMyObject) : Longint;

begin
  If P^.GetField<56 then
    Checkfield:=1
  else
    CheckField:=0;
end;
    
begin
  C:=New(PCollection,Init(100,10));
  For I:=1 to 100 do
    begin
    M:=New(PMyObject,Init);
    M^.SetField(I);
    C^.Insert(M);
    end;
  Writeln ('Inserted ',C^.Count,' objects');
  Writeln ('Last one for which Field<56  has index (should be 54) : ',
            C^.IndexOf(C^.LastThat(@CheckField)));
  C^.FreeAll;
  Dispose(C,Done);
end.