{
   $Id$
}

{****************************************************************************
                                 Interface
****************************************************************************}

{$ifdef read_interface}

  type
     PGtkFixed = ^TGtkFixed;
     TGtkFixed = record
          container : TGtkContainer;
          children : PGList;
       end;

     PGtkFixedClass = ^TGtkFixedClass;
     TGtkFixedClass = record
          parent_class : TGtkContainerClass;
       end;

     PGtkFixedChild = ^TGtkFixedChild;
     TGtkFixedChild = record
          widget : PGtkWidget;
          x : gint16;
          y : gint16;
       end;

Type
  GTK_FIXED=PGtkFixed;
  GTK_FIXED_CLASS=PGtkFixedClass;

function  GTK_FIXED_TYPE:TGtkType;cdecl;external gtkdll name 'gtk_fixed_get_type';
function  GTK_IS_FIXED(obj:pointer):boolean;
function  GTK_IS_FIXED_CLASS(klass:pointer):boolean;

function  gtk_fixed_get_type:TGtkType;cdecl;external gtkdll name 'gtk_fixed_get_type';
function  gtk_fixed_new : PGtkWidget;cdecl;external gtkdll name 'gtk_fixed_new';
procedure gtk_fixed_put(fixed:PGtkFixed; widget:PGtkWidget; x:gint16; y:gint16);cdecl;external gtkdll name 'gtk_fixed_put';
procedure gtk_fixed_move(fixed:PGtkFixed; widget:PGtkWidget; x:gint16; y:gint16);cdecl;external gtkdll name 'gtk_fixed_move';

{$endif read_interface}


{****************************************************************************
                              Implementation
****************************************************************************}

{$ifdef read_implementation}

function  GTK_IS_FIXED(obj:pointer):boolean;
begin
  GTK_IS_FIXED:=(obj<>nil) and GTK_IS_FIXED_CLASS(PGtkTypeObject(obj)^.klass);
end;

function  GTK_IS_FIXED_CLASS(klass:pointer):boolean;
begin
  GTK_IS_FIXED_CLASS:=(klass<>nil) and (PGtkTypeClass(klass)^.thetype=GTK_FIXED_TYPE);
end;

{$endif read_implementation}


{
  $Log$
  Revision 1.1  1999-11-24 23:36:35  peter
    * moved to packages dir

  Revision 1.10  1999/10/21 08:42:01  florian
    * some changes to get it work with gtk 1.3 under Windows 98:
      - removed some trailing space after the import name
      - In gtkbindings.h is
        #define  gtk_binding_entry_add          gtk_binding_entry_clear
        so in the pascal headers the import name of gtk_bindings_entry_add should be
        gtk_binding_entry_clear!
      - removed the declaration of
        gtk_drag_source_unset in gtkdnd.pp it isn't in gtk-1.3.dll!
      - in gdk.pp glibdll must be set to gdk-1.3:
        const
           gdkdll='gdk-1.3';
           glibdll='gdk-1.3';
        else the whole gdk_* calls are imported from glib-1.3.dll which is wrong!

  Revision 1.9  1999/10/06 17:42:48  peter
    * external is now only in the interface
    * removed gtk 1.0 support

  Revision 1.8  1999/07/23 16:12:19  peter
    * use packrecords C

  Revision 1.7  1999/05/11 00:38:33  peter
    * win32 fixes

  Revision 1.6  1999/05/10 15:19:23  peter
    * cdecl fixes

  Revision 1.5  1999/05/07 17:40:22  peter
    * more updates

  Revision 1.4  1998/11/09 10:09:52  peter
    + C type casts are now correctly handled

  Revision 1.3  1998/10/21 20:22:29  peter
    * cdecl, packrecord fixes (from the gtk.tar.gz)
    * win32 support
    * gtk.pp,gdk.pp for an all in one unit

}

