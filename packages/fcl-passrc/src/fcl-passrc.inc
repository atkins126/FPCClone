{$ifdef fpc}
  {$mode objfpc}{$H+}
  {$inline on}
  {$define UsePChar}
  {$define HasInt64}
  {$define UsePChar}
  {$define UseAnsiStrings}
  {$define HasStreams}
  {$IF Defined(FPC_FULLVERSION) and (FPC_FULLVERSION<30101)}
    {$define EmulateArrayInsert}
  {$endif}
  {$define HasFS}
{$endif}

{$IFDEF NODEJS}
  {$define HasFS}
{$ENDIF}

{$IF Defined(FPC_FULLVERSION) and (FPC_FULLVERSION>30100)}
  {$warn 6058 off : cannot inline}
  {$WARN 6018 off : Unreachable code}
{$ENDIF}

