{
   $Id$
}

{****************************************************************************
                                 Interface
****************************************************************************}

{$ifdef read_interface}

    type
       PGtkHScrollbar = ^TGtkHScrollbar;
       TGtkHScrollbar = record
            scrollbar : TGtkScrollbar;
         end;

       PGtkHScrollbarClass = ^TGtkHScrollbarClass;
       TGtkHScrollbarClass = record
            parent_class : TGtkScrollbarClass;
         end;

Type
  GTK_HSCROLLBAR=PGtkHScrollbar;
  GTK_HSCROLLBAR_CLASS=PGtkHScrollbarClass;

function  GTK_HSCROLLBAR_TYPE:TGtkType;cdecl;external gtkdll name 'gtk_hscrollbar_get_type';
function  GTK_IS_HSCROLLBAR(obj:pointer):boolean;
function  GTK_IS_HSCROLLBAR_CLASS(klass:pointer):boolean;

function  gtk_hscrollbar_get_type:TGtkType;cdecl;external gtkdll name 'gtk_hscrollbar_get_type';
function  gtk_hscrollbar_new (adjustment:PGtkAdjustment):PGtkWidget;cdecl;external gtkdll name 'gtk_hscrollbar_new';

{$endif read_interface}


{****************************************************************************
                              Implementation
****************************************************************************}

{$ifdef read_implementation}

function  GTK_IS_HSCROLLBAR(obj:pointer):boolean;
begin
  GTK_IS_HSCROLLBAR:=(obj<>nil) and GTK_IS_HSCROLLBAR_CLASS(PGtkTypeObject(obj)^.klass);
end;

function  GTK_IS_HSCROLLBAR_CLASS(klass:pointer):boolean;
begin
  GTK_IS_HSCROLLBAR_CLASS:=(klass<>nil) and (PGtkTypeClass(klass)^.thetype=GTK_HSCROLLBAR_TYPE);
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

  Revision 1.9  1999/10/06 17:42:49  peter
    * external is now only in the interface
    * removed gtk 1.0 support

  Revision 1.8  1999/07/23 16:12:29  peter
    * use packrecords C

  Revision 1.7  1999/05/11 00:38:44  peter
    * win32 fixes

  Revision 1.6  1999/05/10 15:19:35  peter
    * cdecl fixes

  Revision 1.5  1999/05/07 15:10:07  peter
    * more fixes

  Revision 1.4  1998/11/09 10:10:01  peter
    + C type casts are now correctly handled

  Revision 1.3  1998/10/21 20:22:39  peter
    * cdecl, packrecord fixes (from the gtk.tar.gz)
    * win32 support
    * gtk.pp,gdk.pp for an all in one unit

}

