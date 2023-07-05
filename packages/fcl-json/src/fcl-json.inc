{$if defined(fpc) or defined(NodeJS)}
  {$mode objfpc}{$H+}
  {$define HasFileWriter}
{$endif}

{$IF DEFINED(FPC_FULLVERSION) AND (FPC_FULLVERSION>30100)}
  {$warn 6058 off} // cannot inline
{$ENDIF}

