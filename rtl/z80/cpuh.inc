{

    This file is part of the Free Pascal run time library.
    Copyright (c) 2016 by the Free Pascal development team.

    CPU specific system unit header file

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

{$ifndef FPUNONE}
{$define FPC_SYSTEM_FPUCW_IMMUTABLE}
{$endif}

const
  {$I cpuinnr.inc}

function fpc_z80_inport(port : byte) : byte;[internproc:fpc_in_z80_inport];
procedure fpc_z80_outport(port : byte;data : byte);[internproc:fpc_in_z80_outport];

