{ Source provided for Free Pascal Bug Report 2908 }
{ Submitted by "marcov (gory bugs department)" on  2004-01-19 }
{ e-mail:  }

{$mode delphi}
asm
//and [eax],$ff0000000
and [edx + ebx + 3], $0000ffff
and [edx + 3], $00ffffff
end.
