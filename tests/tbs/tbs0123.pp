{ bug for shrd assemblerreader }
begin
  if false then
   begin
{$asmmode intel}
     asm
      SHRD [ESI-8], EAX, CL
      SHLD EBX,ECX,5
      IMUL ECX,dword [EBP-8],5
     end;
{$asmmode att}
     asm
      shrdl %cl,%eax,-8(%esi)
      shldl $5,%ecx,%ebx
      imull $5,-8(%ebp),%ecx
     end;
   end;
end.
