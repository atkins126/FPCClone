{$mode objfpc}
{$H+}

uses
  sysutils;

Function PosIdx (Const Substr : AnsiString; Const Source : AnsiString;i:longint) : Longint;
var
  S : String;
begin
  PosIdx:=0;
  if Length(SubStr)=0 then
   exit;
  while (i <= length (Source) - length (substr)) do
   begin
     inc (i);
     S:=copy(Source,i,length(Substr));
     if S=SubStr then
      exit(i);
   end;
end;


   function trimspace(const s:string):string;
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

   function trimbegin(const s:string):string;
     var
       i,j : longint;
     begin
       i:=length(s);
       j:=1;
       while (j<i) and (s[j] in [#9,' ']) do
        inc(j);
       trimbegin:=Copy(s,j,i-j+1);
     end;

    procedure Replace(var s:string;const s1,s2:string);
      var
         last,
         i  : longint;
      begin
        last:=0;
        repeat
          i:=posidx(s1,uppercase(s),last);
          if (i>0) then
           begin
             Delete(s,i,length(s1));
             Insert(s2,s,i);
             last:=i+1;
           end;
        until (i=0);
      end;

procedure Conv(const fn: string);
var
  t,f : text;
  lasts,funcname,
  s,ups : string;
  k,i,j : integer;
  gotisfunc,
  impl : boolean;
begin
  writeln('processing ',fn);
  assign(t,fn);
  assign(f,'fixgtk.tmp');
  reset(t);
  rewrite(f);
  funcname:='';
  gotisfunc:=false;
  impl:=false;
  while not eof(t) do
   begin
     readln(t,s);
   { Remove unit part }
     if s='{$ifndef gtk_include_files}' then
      begin
        while not eof(t) do
         begin
           readln(t,s);
           if Pos('{$ifdef read_interface}',s)>0 then
            begin
              writeln(f,'{****************************************************************************');
              writeln(f,'                                 Interface');
              writeln(f,'****************************************************************************}');
              writeln(f,'');
              writeln(f,s);
              break;
            end;
           if Pos('{$ifdef read_implementation}',s)>0 then
            begin
              writeln(f,'{****************************************************************************');
              writeln(f,'                              Implementation');
              writeln(f,'****************************************************************************}');
              writeln(f,'');
              writeln(f,s);
              impl:=true;
              break;
            end;
           if Pos('$Log:',s)>0 then
            begin
              writeln(f,'{');
              writeln(f,s);
              break;
            end;
         end;
        continue;
      end;

     Replace(s,'PROCEDURE','procedure');
     Replace(s,'FUNCTION','function');
     Replace(s,'FUNCTION  ','function ');
     Replace(s,'PPG','PPG');
     Replace(s,'PG','PG');
     Replace(s,'GCHAR','gchar');
     Replace(s,'GUCHAR','guchar');
     Replace(s,'GINT','gint');
     Replace(s,'GUINT','guint');
     Replace(s,'GBOOL','gbool');
     Replace(s,'GSHORT','gshort');
     Replace(s,'GUSHORT','gushort');
     Replace(s,'GLONG','glong');
     Replace(s,'GULONG','gulong');
     Replace(s,'GFLOAT','gfloat');
     Replace(s,'GDOUBLE','gdouble');
     Replace(s,'GPOINTER','gpointer');
     Replace(s,'GCONSTPOINTER','gconstpointer');

     ups:=UpperCase(s);

     if Pos('IMPLEMENTATION',ups)>0 then
      impl:=true;

     i:=Pos('PROCEDURE',ups);
     if i>0 then
      if Pos('_PROCEDURE',ups)>0 then
       i:=0;
     if i=0 then
      begin
        i:=Pos('FUNCTION',ups);
        if Pos('_FUNCTION',ups)>0 then
         i:=0;
      end;
     if i<>0 then
      begin
      { Remove Spaces }
        j:=PosIdx('  ',s,i);
        while (j>0) do
         begin
           Delete(s,j,1);
           i:=j-1;
           j:=PosIdx('  ',s,i);
         end;
        ups:=UpperCase(s);
      { Fix Cdecl }
        if (Pos('g_',s)<>0) or (Pos('TGtkType',s)<>0) or
           ((i>2) and (s[i-2] in [':','='])) then
         begin
           j:=Pos('CDECL;',ups);
           if j=0 then
            j:=Length(s)+1
           else
            begin
              k:=Pos('{$IFNDEF WIN32}CDECL;{$ENDIF}',ups);
              if k>0 then
               begin
                 j:=k;
                 k:=29;
               end
              else
               begin
                 k:=Pos('{$IFDEF WIN32}STDCALL;{$ELSE}CDECL;{$ENDIF}',ups);
                 if k>0 then
                  begin
                    j:=k;
                    k:=43;
                  end
                 else
                  k:=6;
               end;
              Delete(s,j,k);
            end;
           Insert('cdecl;',s,j);
         end;
        ups:=UpperCase(s);

        if (not gotisfunc) and (Pos('function GTK_IS_',s)>0) then
         gotisfunc:=true;

        if not gotisfunc then
         begin
           j:=Pos('_GET_TYPE:TGTKTYPE',ups);
           funcname:=Copy(ups,14,j-14);
           if (i=1) and (j>0) then
            begin
              writeln(f,'function  GTK_'+funcname+'_TYPE'+Copy(s,j+9,Length(s)-(j+9)+1));
              if impl then
               begin
                 writeln(f,'function  GTK_IS_',funcname,'(obj:pointer):boolean;');
                 writeln(f,'begin');
                 writeln(f,'  GTK_IS_',funcname,':=(obj<>nil) and GTK_IS_',funcname,'_CLASS(PGtkTypeObject(obj)^.klass);');
                 writeln(f,'end;');
                 writeln(f,'function  GTK_IS_',funcname,'_CLASS(klass:pointer):boolean;');
                 writeln(f,'begin');
                 writeln(f,'  GTK_IS_',funcname,'_CLASS:=(klass<>nil) and (PGtkTypeClass(klass)^.thetype=GTK_',funcname,'_TYPE);');
                 writeln(f,'end;');
               end
              else
               begin
                 writeln(f,'function  GTK_IS_',funcname,'(obj:pointer):boolean;');
                 writeln(f,'function  GTK_IS_',funcname,'_CLASS(klass:pointer):boolean;');
               end;
              writeln(f,'');
            end;
         end;
      end
     else
     { No procedure/function }
      begin
        { Remove the GTK_IS_ type decls }
        if (Copy(s,1,9)='  GTK_IS_') and (Pos('=',s)>0) and (Pos(':=',s)=0) then
         begin
           lasts:=s;
           continue;
         end;
      end;

     { Align function with procedure }
     if Copy(s,1,8)='function' then
      Insert(' ',s,9);

     lasts:=s;
     writeln(f,s);
   end;
  close(f);
  close(t);
  erase(t);
  rename(f,fn);
end;

var
 i : integer;
 dir : tsearchrec;
begin
  for i:=1to paramcount do
   begin
     if findfirst(paramstr(i),$20,dir)=0 then
      repeat
        Conv(dir.name);
      until findnext(dir)<>0;
     findclose(dir);
   end;
end.
