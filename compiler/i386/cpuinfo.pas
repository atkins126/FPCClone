{
    Copyright (c) 1998-2004 by Florian Klaempfl

    Basic Processor information

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
Unit cpuinfo;

{$i fpcdefs.inc}

Interface

  uses
    globtype;

Type
   bestreal = extended;
{$ifdef FPC_HAS_TYPE_EXTENDED}
   bestrealrec = TExtended80Rec;
{$else}
   bestrealrec = TDoubleRec;
{$endif}
   ts32real = single;
   ts64real = double;
   ts80real = extended;
   ts128real = type extended;
   ts64comp = type extended;

   pbestreal=^bestreal;

   { possible supported processors for this target }
   tcputype =
      (cpu_none,
       cpu_386,
       cpu_486,
       cpu_Pentium,
       cpu_Pentium2,
       cpu_Pentium3,
       cpu_Pentium4,
       cpu_PentiumM,
       cpu_core_i,
       cpu_core_avx,
       cpu_core_avx2
      );

   tfputype =
     (fpu_none,
//      fpu_soft,
      fpu_x87,
      fpu_sse,
      fpu_sse2,
      fpu_sse3,
      fpu_ssse3,
      fpu_sse41,
      fpu_sse42,
      fpu_avx,
      fpu_avx2,
      fpu_avx512f
     );

   tcontrollertype =
     (ct_none
     );

   tcontrollerdatatype = record
      controllertypestr, controllerunitstr: string[20];
      cputype: tcputype; fputype: tfputype;
      flashbase, flashsize, srambase, sramsize, eeprombase, eepromsize, bootbase, bootsize: dword;
   end;


Const
   { Is there support for dealing with multiple microcontrollers available }
   { for this platform? }
   ControllerSupport = false;

   { We know that there are fields after sramsize
     but we don't care about this warning }
   {$PUSH}
    {$WARN 3177 OFF}
   embedded_controllers : array [tcontrollertype] of tcontrollerdatatype =
   (
      (controllertypestr:''; controllerunitstr:''; cputype:cpu_none; fputype:fpu_none; flashbase:0; flashsize:0; srambase:0; sramsize:0));
   {$POP}

   { calling conventions supported by the code generator }
   supported_calling_conventions : tproccalloptions = [
     pocall_internproc,
     pocall_register,
     pocall_safecall,
     pocall_stdcall,
     pocall_cdecl,
     pocall_cppdecl,
     pocall_far16,
     pocall_pascal,
     pocall_oldfpccall,
     pocall_mwpascal
   ];

   cputypestr : array[tcputype] of string[10] = ('',
     '80386',
     '80486',
     'PENTIUM',
     'PENTIUM2',
     'PENTIUM3',
     'PENTIUM4',
     'PENTIUMM',
     'COREI',
     'COREAVX',
     'COREAVX2'
   );

   fputypestr : array[tfputype] of string[7] = (
     'NONE',
//     'SOFT',
     'X87',
     'SSE',
     'SSE2',
     'SSE3',
     'SSSE3',
     'SSE41',
     'SSE42',
     'AVX',
     'AVX2',
     'AVX512F'
   );

   sse_singlescalar = [fpu_sse..fpu_avx512f];
   sse_doublescalar = [fpu_sse2..fpu_avx512f];

   fpu_avx_instructionsets = [fpu_avx,fpu_avx2,fpu_avx512f];

   { Supported optimizations, only used for information }
   supported_optimizerswitches = genericlevel1optimizerswitches+
                                 genericlevel2optimizerswitches+
                                 genericlevel3optimizerswitches-
                                 { no need to write info about those }
                                 [cs_opt_level1,cs_opt_level2,cs_opt_level3]+
                                 [cs_opt_peephole{$ifndef llvm},cs_opt_regvar{$endif},cs_opt_stackframe,
                                  cs_opt_loopunroll,cs_opt_uncertain,
                                  cs_opt_tailrecursion,cs_opt_nodecse,cs_useebp,
				  cs_opt_reorder_fields,cs_opt_fastmath];

   level1optimizerswitches = genericlevel1optimizerswitches;
   level2optimizerswitches = genericlevel2optimizerswitches + level1optimizerswitches +
     [{$ifndef llvm}cs_opt_regvar,{$endif}cs_opt_stackframe,cs_opt_tailrecursion,cs_opt_nodecse];
   level3optimizerswitches = genericlevel3optimizerswitches + level2optimizerswitches;
   level4optimizerswitches = genericlevel4optimizerswitches + level3optimizerswitches + [cs_useebp];

type
   tcpuflags =
      (CPUX86_HAS_BTX,          { Bit-test instructions (BT, BTC, BTR and BTS) are available }
       CPUX86_HAS_FAST_XCHG,    { XCHG %reg,%reg executes in 2 cycles or less }
       CPUX86_HAS_CMOV,         { CMOVcc instructions are available }
       CPUX86_HAS_FAST_BTX,     { BT/C/R/S instructions with register operands are at least as fast as logical instructions }
       CPUX86_HAS_FAST_BT_MEM,  { BT instructions with memory operands are at least as fast as logical instructions }
       CPUX86_HAS_FAST_BTX_MEM, { BTC/R/S instructions with memory operands are at least as fast as logical instructions }
       CPUX86_HAS_SSEUNIT,      { SSE instructions are available }
       CPUX86_HAS_SSE2,         { SSE2 instructions are available }
       CPUX86_HAS_BMI1,         { BMI1 instructions are available }
       CPUX86_HAS_BMI2,         { BMI2 instructions are available }
       CPUX86_HAS_POPCNT,       { POPCNT is available }
       CPUX86_HAS_LZCNT,        { LZCNT is available }
       CPUX86_HAS_MOVBE         { MOVBE is available }
      );

   tfpuflags =
      (FPUX86_HAS_AVXUNIT,
       FPUX86_HAS_FMA,
       FPUX86_HAS_FMA4,
       FPUX86_HAS_AVX512F,
       FPUX86_HAS_AVX512VL,
       FPUX86_HAS_AVX512DQ
      );

 const
   cpu_capabilities : array[tcputype] of set of tcpuflags = (
     { cpu_none      } [],
     { cpu_386       } [CPUX86_HAS_BTX],
     { cpu_486       } [CPUX86_HAS_BTX],
     { cpu_Pentium   } [CPUX86_HAS_BTX],
     { cpu_Pentium2  } [CPUX86_HAS_BTX,CPUX86_HAS_CMOV,CPUX86_HAS_FAST_BTX],
     { cpu_Pentium3  } [CPUX86_HAS_BTX,CPUX86_HAS_CMOV,CPUX86_HAS_FAST_BTX,CPUX86_HAS_SSEUNIT],
     { cpu_Pentium4  } [CPUX86_HAS_BTX,CPUX86_HAS_CMOV,CPUX86_HAS_FAST_BTX,CPUX86_HAS_SSEUNIT,CPUX86_HAS_SSE2],
     { cpu_PentiumM  } [CPUX86_HAS_BTX,CPUX86_HAS_FAST_XCHG,CPUX86_HAS_CMOV,CPUX86_HAS_FAST_BTX,CPUX86_HAS_SSEUNIT,CPUX86_HAS_SSE2],
     { cpu_core_i    } [CPUX86_HAS_BTX,CPUX86_HAS_FAST_XCHG,CPUX86_HAS_CMOV,CPUX86_HAS_FAST_BTX,CPUX86_HAS_SSEUNIT,CPUX86_HAS_SSE2,CPUX86_HAS_POPCNT],
     { cpu_core_avx  } [CPUX86_HAS_BTX,CPUX86_HAS_FAST_XCHG,CPUX86_HAS_CMOV,CPUX86_HAS_FAST_BTX,CPUX86_HAS_SSEUNIT,CPUX86_HAS_SSE2,CPUX86_HAS_POPCNT],
     { cpu_core_avx2 } [CPUX86_HAS_BTX,CPUX86_HAS_FAST_XCHG,CPUX86_HAS_CMOV,CPUX86_HAS_FAST_BTX,CPUX86_HAS_SSEUNIT,CPUX86_HAS_SSE2,CPUX86_HAS_POPCNT,CPUX86_HAS_BMI1,CPUX86_HAS_BMI2,CPUX86_HAS_LZCNT,CPUX86_HAS_MOVBE]
   );

   fpu_capabilities : array[tfputype] of set of tfpuflags = (
      { fpu_none     } [],
      { fpu_x87      } [],
      { fpu_sse      } [],
      { fpu_sse2     } [],
      { fpu_sse3     } [],
      { fpu_ssse3    } [],
      { fpu_sse41    } [],
      { fpu_sse42    } [],
      { fpu_avx      } [FPUX86_HAS_AVXUNIT],
      { fpu_avx2     } [FPUX86_HAS_AVXUNIT,FPUX86_HAS_FMA],
      { fpu_avx512   } [FPUX86_HAS_AVXUNIT,FPUX86_HAS_FMA,FPUX86_HAS_AVX512F,FPUX86_HAS_AVX512VL,FPUX86_HAS_AVX512DQ]
   );

Implementation

end.
