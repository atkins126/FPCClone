{ Old file: tbs0227.pp }
{ external var does strange things when declared in localsymtable OK 0.99.11 (PFV) }

function getheapsize:longint;assembler;
var
  heapsize : longint;external name 'HEAPSIZE';
//  sbrk : longint;external name '___sbrk';
asm
{$ifdef CPUI386}
        movl    HEAPSIZE,%eax
end ['EAX'];
{$endif CPUI386}
{$ifdef CPUX86_64}
        movl    HEAPSIZE,%eax
end ['EAX'];
{$endif CPUX86_64}
{$ifdef CPU68K}
        move.l    HEAPSIZE,d0
end ['D0'];
{$endif CPU68K}
{$ifdef cpupowerpc}
       lis r3, heapsize@ha
       lwz r3, heapsize@l(r3)
end;
{$endif cpupowerpc}
{$ifdef cpusparc}
       sethi   %hi(heapsize),%i0
       or      %i0,%lo(heapsize),%i0
end;
{$endif cpusparc}
begin
  writeln(getheapsize);
end.

