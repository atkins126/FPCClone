{
    $Id$
    Copyright (c) 1998-2000 by Florian Klaempfl

    This unit implements an extended file management

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

 ****************************************************************************
}
unit finput;

{$i defines.inc}

interface

    uses
      cutils,cobjects,cclasses;

    const
       InputFileBufSize=32*1024;
       linebufincrease=512;

    type
       tlongintarr = array[0..1000000] of longint;
       plongintarr = ^tlongintarr;

       tinputfile = class
         path,name : pstring;       { path and filename }
         next      : tinputfile;    { next file for reading }

         is_macro,
         endoffile,                 { still bytes left to read }
         closed       : boolean;    { is the file closed }

         buf          : pchar;      { buffer }
         bufstart,                  { buffer start position in the file }
         bufsize,                   { amount of bytes in the buffer }
         maxbufsize   : longint;    { size in memory for the buffer }

         saveinputpointer : pchar;  { save fields for scanner variables }
         savelastlinepos,
         saveline_no      : longint;

         linebuf    : plongintarr;  { line buffer to retrieve lines }
         maxlinebuf : longint;

         ref_index  : longint;      { to handle the browser refs }
         ref_next   : tinputfile;

         constructor create(const fn:string);
         destructor  destroy;override;
         procedure setpos(l:longint);
         procedure seekbuf(fpos:longint);
         procedure readbuf;
         function  open:boolean;
         procedure close;
         procedure tempclose;
         function  tempopen:boolean;
         procedure setmacro(p:pchar;len:longint);
         procedure setline(line,linepos:longint);
         function  getlinestr(l:longint):string;
       protected
         function fileopen(const filename: string): boolean; virtual;
         function fileseek(pos: longint): boolean; virtual;
         function fileread(var databuf; maxsize: longint): longint; virtual;
         function fileeof: boolean; virtual;
         function fileclose: boolean; virtual;
       end;

       tdosinputfile = class(tinputfile)
       protected
         function fileopen(const filename: string): boolean; override;
         function fileseek(pos: longint): boolean; override;
         function fileread(var databuf; maxsize: longint): longint; override;
         function fileeof: boolean; override;
         function fileclose: boolean; override;
       private
         f            : file;       { current file handle }
       end;

       tinputfilemanager = class
          files : tinputfile;
          last_ref_index : longint;
          cacheindex : longint;
          cacheinputfile : tinputfile;
          constructor create;
          destructor destroy;override;
          procedure register_file(f : tinputfile);
          procedure inverse_register_indexes;
          function  get_file(l:longint) : tinputfile;
          function  get_file_name(l :longint):string;
          function  get_file_path(l :longint):string;
       end;

{****************************************************************************
                                TModuleBase
 ****************************************************************************}

       tmodulebase = class(TLinkedListItem)
          { index }
          unit_index    : longint;  { global counter for browser }
          { sources }
          sourcefiles   : tinputfilemanager;
          { paths and filenames }
          path,                     { path where the module is find/created }
          outputpath,               { path where the .s / .o / exe are created }
          modulename,               { name of the module in uppercase }
          realmodulename,           { name of the module in the orignal case }
          objfilename,              { fullname of the objectfile }
          asmfilename,              { fullname of the assemblerfile }
          ppufilename,              { fullname of the ppufile }
          staticlibfilename,        { fullname of the static libraryfile }
          sharedlibfilename,        { fullname of the shared libraryfile }
          exefilename,              { fullname of the exefile }
          mainsource   : pstring;   { name of the main sourcefile }
          constructor create(const s:string);
          destructor destroy;override;
          procedure setfilename(const fn:string;allowoutput:boolean);
       end;


implementation

uses
{$ifdef Delphi}
  dmisc,
{$else Delphi}
  dos,
{$endif Delphi}
{$ifdef HEAPTRC}
  fmodule,
{$endif HEAPTRC}
  globals,systems
  ;

{****************************************************************************
                                  TINPUTFILE
 ****************************************************************************}

    constructor tinputfile.create(const fn:string);
      var
        p:dirstr;
        n:namestr;
        e:extstr;
      begin
        FSplit(fn,p,n,e);
        name:=stringdup(n+e);
        path:=stringdup(p);
        next:=nil;
      { file info }
        is_macro:=false;
        endoffile:=false;
        closed:=true;
        buf:=nil;
        bufstart:=0;
        bufsize:=0;
        maxbufsize:=InputFileBufSize;
      { save fields }
        saveinputpointer:=nil;
        saveline_no:=0;
        savelastlinepos:=0;
      { indexing refs }
        ref_next:=nil;
        ref_index:=0;
      { line buffer }
        linebuf:=nil;
        maxlinebuf:=0;
      end;


    destructor tinputfile.destroy;
      begin
        if not closed then
         close;
        stringdispose(path);
        stringdispose(name);
      { free memory }
        if assigned(linebuf) then
         freemem(linebuf,maxlinebuf shl 2);
      end;


    procedure tinputfile.setpos(l:longint);
      begin
        bufstart:=l;
      end;


    procedure tinputfile.seekbuf(fpos:longint);
      begin
        if closed then
         exit;
        fileseek(fpos);
        bufstart:=fpos;
        bufsize:=0;
      end;


    procedure tinputfile.readbuf;
      begin
        if is_macro then
         endoffile:=true;
        if closed then
         exit;
        inc(bufstart,bufsize);
        bufsize:=fileread(buf^,maxbufsize-1);
        buf[bufsize]:=#0;
        endoffile:=fileeof;
      end;


    function tinputfile.open:boolean;
      begin
        open:=false;
        if not closed then
         Close;
        if not fileopen(path^+name^) then
         exit;
      { file }
        endoffile:=false;
        closed:=false;
        Getmem(buf,MaxBufsize);
        bufstart:=0;
        bufsize:=0;
        open:=true;
      end;


    procedure tinputfile.close;
      begin
        if is_macro then
         begin
           if assigned(buf) then
             Freemem(buf,maxbufsize);
           buf:=nil;
           {is_macro:=false;
           still needed for dispose in scanner PM }
           closed:=true;
           exit;
         end;
        if not closed then
         begin
           if fileclose then;
           closed:=true;
         end;
        if assigned(buf) then
          begin
             Freemem(buf,maxbufsize);
             buf:=nil;
          end;
        bufstart:=0;
      end;


    procedure tinputfile.tempclose;
      begin
        if is_macro then
         exit;
        if not closed then
         begin
           if fileclose then;
           Freemem(buf,maxbufsize);
           buf:=nil;
           closed:=true;
         end;
      end;

    function tinputfile.tempopen:boolean;
      begin
        tempopen:=false;
        if is_macro then
         begin
           { seek buffer postion to bufstart }
           if bufstart>0 then
            begin
              move(buf[bufstart],buf[0],bufsize-bufstart+1);
              bufstart:=0;
            end;
           tempopen:=true;
           exit;
         end;
        if not closed then
         exit;
        if not fileopen(path^+name^) then
         exit;
        closed:=false;
      { get new mem }
        Getmem(buf,maxbufsize);
      { restore state }
        fileseek(BufStart);
        bufsize:=0;
        readbuf;
        tempopen:=true;
      end;


    procedure tinputfile.setmacro(p:pchar;len:longint);
      begin
      { create new buffer }
        getmem(buf,len+1);
        move(p^,buf^,len);
        buf[len]:=#0;
      { reset }
        bufstart:=0;
        bufsize:=len;
        maxbufsize:=len+1;
        is_macro:=true;
        endoffile:=true;
        closed:=true;
      end;


    procedure tinputfile.setline(line,linepos:longint);
      var
        oldlinebuf  : plongintarr;
      begin
        if line<1 then
         exit;
        while (line>=maxlinebuf) do
         begin
           oldlinebuf:=linebuf;
         { create new linebuf and move old info }
           getmem(linebuf,(maxlinebuf+linebufincrease) shl 2);
           if assigned(oldlinebuf) then
            begin
              move(oldlinebuf^,linebuf^,maxlinebuf shl 2);
              freemem(oldlinebuf,maxlinebuf shl 2);
            end;
           fillchar(linebuf^[maxlinebuf],linebufincrease shl 2,0);
           inc(maxlinebuf,linebufincrease);
         end;
        linebuf^[line]:=linepos;
      end;


    function tinputfile.getlinestr(l:longint):string;
      var
        c    : char;
        i,
        fpos : longint;
        p    : pchar;
      begin
        getlinestr:='';
        if l<maxlinebuf then
         begin
           fpos:=linebuf^[l];
           { fpos is set negativ if the line was already written }
           { but we still know the correct value                 }
           if fpos<0 then
             fpos:=-fpos+1;
           if closed then
            open;
         { in current buf ? }
           if (fpos<bufstart) or (fpos>bufstart+bufsize) then
            begin
              seekbuf(fpos);
              readbuf;
            end;
         { the begin is in the buf now simply read until #13,#10 }
           i:=0;
           p:=@buf[fpos-bufstart];
           repeat
             c:=p^;
             if c=#0 then
              begin
                if endoffile then
                 break;
                readbuf;
                p:=buf;
                c:=p^;
              end;
             if c in [#10,#13] then
              break;
             inc(i);
             getlinestr[i]:=c;
             inc(longint(p));
           until (i=255);
           getlinestr[0]:=chr(i);
         end;
      end;


    function tinputfile.fileopen(const filename: string): boolean;
      begin
        abstract;
        fileopen:=false;
      end;


    function tinputfile.fileseek(pos: longint): boolean;
      begin
        abstract;
        fileseek:=false;
      end;


    function tinputfile.fileread(var databuf; maxsize: longint): longint;
      begin
        abstract;
        fileread:=0;
      end;


    function tinputfile.fileeof: boolean;
      begin
        abstract;
        fileeof:=false;
      end;


    function tinputfile.fileclose: boolean;
      begin
        abstract;
        fileclose:=false;
      end;


{****************************************************************************
                                TDOSINPUTFILE
 ****************************************************************************}

    function tdosinputfile.fileopen(const filename: string): boolean;
      var
        ofm : byte;
      begin
        ofm:=filemode;
        filemode:=0;
        Assign(f,filename);
        {$I-}
         reset(f,1);
        {$I+}
        filemode:=ofm;
        fileopen:=(ioresult=0);
      end;


    function tdosinputfile.fileseek(pos: longint): boolean;
      begin
        {$I-}
         seek(f,Pos);
        {$I+}
        fileseek:=(ioresult=0);
      end;


    function tdosinputfile.fileread(var databuf; maxsize: longint): longint;
      var
        w : longint;
      begin
        blockread(f,databuf,maxsize,w);
        fileread:=w;
      end;


    function tdosinputfile.fileeof: boolean;
      begin
        fileeof:=eof(f);
      end;


    function tdosinputfile.fileclose: boolean;
      begin
        {$I-}
         system.close(f);
        {$I+}
        fileclose:=(ioresult=0);
      end;


{****************************************************************************
                                Tinputfilemanager
 ****************************************************************************}

    constructor tinputfilemanager.create;
      begin
         files:=nil;
         last_ref_index:=0;
         cacheindex:=0;
         cacheinputfile:=nil;
      end;


    destructor tinputfilemanager.destroy;
      var
         hp : tinputfile;
      begin
         hp:=files;
         while assigned(hp) do
          begin
            files:=files.ref_next;
            hp.free;
            hp:=files;
          end;
         last_ref_index:=0;
      end;


    procedure tinputfilemanager.register_file(f : tinputfile);
      begin
         { don't register macro's }
         if f.is_macro then
          exit;
         inc(last_ref_index);
         f.ref_next:=files;
         f.ref_index:=last_ref_index;
         files:=f;
         { update cache }
         cacheindex:=last_ref_index;
         cacheinputfile:=f;
{$ifdef HEAPTRC}
         writeln(stderr,f.name^,' index ',current_module.unit_index*100000+f.ref_index);
{$endif HEAPTRC}
      end;


   { this procedure is necessary after loading the
     sources files from a PPU file  PM }
   procedure tinputfilemanager.inverse_register_indexes;
     var
        f : tinputfile;
     begin
        f:=files;
        while assigned(f) do
          begin
             f.ref_index:=last_ref_index-f.ref_index+1;
             f:=f.ref_next;
          end;
        { reset cache }
        cacheindex:=0;
        cacheinputfile:=nil;
     end;



   function tinputfilemanager.get_file(l :longint) : tinputfile;
     var
        ff : tinputfile;
     begin
       { check cache }
       if (l=cacheindex) and assigned(cacheinputfile) then
        begin
          get_file:=cacheinputfile;
          exit;
        end;
       ff:=files;
       while assigned(ff) and (ff.ref_index<>l) do
         ff:=ff.ref_next;
       get_file:=ff;
     end;


   function tinputfilemanager.get_file_name(l :longint):string;
     var
       hp : tinputfile;
     begin
       hp:=get_file(l);
       if assigned(hp) then
        get_file_name:=hp.name^
       else
        get_file_name:='';
     end;


   function tinputfilemanager.get_file_path(l :longint):string;
     var
       hp : tinputfile;
     begin
       hp:=get_file(l);
       if assigned(hp) then
        get_file_path:=hp.path^
       else
        get_file_path:='';
     end;


{****************************************************************************
                                TModuleBase
 ****************************************************************************}

    procedure tmodulebase.setfilename(const fn:string;allowoutput:boolean);
      var
        p : dirstr;
        n : NameStr;
        e : ExtStr;
      begin
         stringdispose(objfilename);
         stringdispose(asmfilename);
         stringdispose(ppufilename);
         stringdispose(staticlibfilename);
         stringdispose(sharedlibfilename);
         stringdispose(exefilename);
         stringdispose(outputpath);
         stringdispose(path);
         { Create names }
         fsplit(fn,p,n,e);
         n:=FixFileName(n);
         { set path }
         path:=stringdup(FixPath(p,false));
         { obj,asm,ppu names }
         p:=path^;
         if AllowOutput then
          begin
            if (OutputUnitDir<>'') then
             p:=OutputUnitDir
            else
             if (OutputExeDir<>'') then
              p:=OutputExeDir;
          end;
         outputpath:=stringdup(p);
         objfilename:=stringdup(p+n+target_info.objext);
         asmfilename:=stringdup(p+n+target_info.asmext);
         ppufilename:=stringdup(p+n+target_info.unitext);
         { lib and exe could be loaded with a file specified with -o }
         if AllowOutput and (OutputFile<>'') and (compile_level=1) then
          n:=OutputFile;
         staticlibfilename:=stringdup(p+target_os.libprefix+n+target_os.staticlibext);
         if target_info.target=target_i386_WIN32 then
           sharedlibfilename:=stringdup(p+n+target_os.sharedlibext)
         else
           sharedlibfilename:=stringdup(p+target_os.libprefix+n+target_os.sharedlibext);
         { output dir of exe can be specified separatly }
         if AllowOutput and (OutputExeDir<>'') then
          p:=OutputExeDir
         else
          p:=path^;
         exefilename:=stringdup(p+n+target_info.exeext);
      end;


    constructor tmodulebase.create(const s:string);
      begin
        modulename:=stringdup(Upper(s));
        realmodulename:=stringdup(s);
        mainsource:=nil;
        ppufilename:=nil;
        objfilename:=nil;
        asmfilename:=nil;
        staticlibfilename:=nil;
        sharedlibfilename:=nil;
        exefilename:=nil;
        outputpath:=nil;
        path:=nil;
        { unit index }
        inc(global_unit_count);
        unit_index:=global_unit_count;
        { sources }
        sourcefiles:=TInputFileManager.Create;
      end;


    destructor tmodulebase.destroy;
      begin
        if assigned(sourcefiles) then
         sourcefiles.free;
        sourcefiles:=nil;
        stringdispose(objfilename);
        stringdispose(asmfilename);
        stringdispose(ppufilename);
        stringdispose(staticlibfilename);
        stringdispose(sharedlibfilename);
        stringdispose(exefilename);
        stringdispose(outputpath);
        stringdispose(path);
        stringdispose(modulename);
        stringdispose(realmodulename);
        stringdispose(mainsource);
        inherited destroy;
      end;

end.
{
  $Log$
  Revision 1.7  2001-03-13 18:43:17  peter
    * made memdebug and heaptrc compilable again

  Revision 1.6  2000/12/25 00:07:25  peter
    + new tlinkedlist class (merge of old tstringqueue,tcontainer and
      tlinkedlist objects)

  Revision 1.5  2000/11/07 20:48:33  peter
    * removed ref_count from tinputfile it's not used

  Revision 1.4  2000/10/31 22:02:46  peter
    * symtable splitted, no real code changes

  Revision 1.3  2000/10/14 21:52:54  peter
    * fixed memory leaks

  Revision 1.2  2000/09/24 15:06:16  peter
    * use defines.inc

  Revision 1.1  2000/08/27 16:11:50  peter
    * moved some util functions from globals,cobjects to cutils
    * splitted files into finput,fmodule

}
