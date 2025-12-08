unit proctab;
interface
uses sysutils,windows;
{************************************************************************
* Tables of processor instructions. The whole of this file is full of   *
* tables that I constructed some time ago. The main instruction tables  *
* include three arguments for instructions, which was necessary to      *
* easily include instructions like shld r/m16,r16,CL. I was maybe       *
* overexcessive with the number of slightly different modr/ms that I    *
* included but the tables have served well, and when you build them up  *
* from scratch instruction by instruction you do actually find a lot of *
* slightly different encodings, and the modrm encodings generally       *
* indicate what is actually being referenced (like a 16:32 pointer in   *
* memory, etc). I included the Z80 processor because I knew the Z80     *
* processor quite well, but mostly just to show it isnt hard to do.     *
* At one point I decided that I needed a uid for each instruction to    *
* enable proper reconstruction of the disassembly from a saved database *
* and so each instruction also has a uid for this purpose.              *
* Flags for modrm may seem excessive, but consider encodings like 0fae  *
* which includes the strange sfence instruction with no arguments and a *
* code of 0fae /7, along with stmxcsr m32 with the encoding 0fae /3     *
* Hence the flag FLAGS_MODRM indicates a modrm byte. Any argument       *
* encodings may indicate usage of that byte, but may not be present at  *
* all.                                                                  *
* Whilst I havent found any errors in here for some time it would need  *
* a very careful analysis to find any which may be present. Certainly   *
* newer instruction encodings (mmx, kni) may need more work, and it is  *
* worth looking at decodings which should not be possible (eg forced    *
* memory operands only may require looking at as some possible          *
* instructions are illegal)                                             *
************************************************************************}
const
  FLAGS_INDEXREG  = $0001;
  TABLE_MAIN = 1;
  TABLE_EXT  = 2;
  TABLE_EXT2 = 3;

  PROC_8086       = $0001;
  PROC_80286      = $0002;
  PROC_80386      = $0004;
  PROC_80486      = $0008;
  PROC_PENTIUM    = $0010;
  PROC_PENTMMX    = $0020;
  PROC_PENTIUM2   = $0080;
  PROC_Z80        = $0100;
  PROC_PENTIUMPRO = $0200;
  PROC_ALL        = $FFFF;

  PROC_FROMPENTIUM2 = PROC_PENTIUM2;
  PROC_FROMPENTMMX  = PROC_PENTMMX or PROC_PENTIUM2;
  PROC_FROMPENTPRO  = PROC_PENTIUMPRO or PROC_FROMPENTMMX;
  PROC_FROMPENTIUM  = PROC_PENTIUM or PROC_FROMPENTPRO;
  PROC_FROM80486    = PROC_80486 or PROC_FROMPENTIUM;
  PROC_FROM80386    = PROC_80386 or PROC_FROM80486;
  PROC_FROM80286    = PROC_80286 or PROC_FROM80386;
  PROC_FROM8086     = PROC_8086 or PROC_FROM80286;

  FLAGS_MODRM      = $00001;  //contains mod r/m byte
  FLAGS_8BIT       = $00002;  //force 8-bit arguments
  FLAGS_16BIT      = $00004;  //force 16-bit arguments
  FLAGS_32BIT      = $00008;  //force 32-bit arguments
  FLAGS_REAL       = $00010;  //real mode only
  FLAGS_PMODE      = $00020;  //protected mode only
  FLAGS_PREFIX     = $00040;  //for lock and rep prefix
  FLAGS_MMX        = $00080;  //mmx instruction/registers
  FLAGS_FPU        = $00100;  //fpu instruction/registers
  FLAGS_CJMP       = $00200;  //codeflow - conditional jump
  FLAGS_JMP        = $00400;  //codeflow - jump
  FLAGS_IJMP       = $00800;  //codeflow - indexed jump
  FLAGS_CALL       = $01000;  //codeflow - call
  FLAGS_ICALL      = $02000;  //codeflow - indexed call
  FLAGS_RET        = $04000;  //codeflow - return
  FLAGS_SEGPREFIX  = $08000;  //segment prefix
  FLAGS_OPERPREFIX = $10000;  //operand prefix
  FLAGS_ADDRPREFIX = $20000;  //address prefix
  FLAGS_OMODE16    = $40000;  //16-bit operand mode only
  FLAGS_OMODE32    = $80000;  //32-bit operand mode only

type
  argtype=(
    ARG_NULL,ARG_REG,ARG_IMM,ARG_NONE,ARG_MODRM,ARG_REG_AX,ARG_REG_ES,
    ARG_REG_CS,ARG_REG_SS,ARG_REG_DS,ARG_REG_FS,ARG_REG_GS,ARG_REG_BX,
    ARG_REG_CX,ARG_REG_DX,ARG_REG_SP,ARG_REG_BP,ARG_REG_SI,ARG_REG_DI,
    ARG_IMM8,ARG_RELIMM8,ARG_FADDR,ARG_REG_AL,ARG_MEMLOC,ARG_SREG,ARG_RELIMM,
    ARG_16REG_DX,ARG_REG_CL,ARG_REG_DL,ARG_REG_BL,ARG_REG_AH,ARG_REG_CH,
    ARG_REG_DH,ARG_REG_BH,ARG_MODREG,ARG_CREG,ARG_DREG,ARG_TREG_67,ARG_TREG,
    ARG_MREG,ARG_MMXMODRM,ARG_MODRM8,ARG_IMM_1,ARG_MODRM_FPTR,ARG_MODRM_S,
    ARG_MODRMM512,ARG_MODRMQ,ARG_MODRM_SREAL,ARG_REG_ST0,ARG_FREG,
    ARG_MODRM_PTR,ARG_MODRM_WORD,ARG_MODRM_SINT,ARG_MODRM_EREAL,
    ARG_MODRM_DREAL,ARG_MODRM_WINT,ARG_MODRM_LINT,ARG_REG_BC,ARG_REG_DE,
    ARG_REG_HL,ARG_REG_DE_IND,ARG_REG_HL_IND,ARG_REG_BC_IND,ARG_REG_SP_IND,
    ARG_REG_A,ARG_REG_B,ARG_REG_C,ARG_REG_D,ARG_REG_E,ARG_REG_H,ARG_REG_L,
    ARG_IMM16,ARG_REG_AF,ARG_REG_AF2,ARG_MEMLOC16,ARG_IMM8_IND,ARG_BIT,
    ARG_REG_IX,ARG_REG_IX_IND,ARG_REG_IY,ARG_REG_IY_IND,ARG_REG_C_IND,
    ARG_REG_I,ARG_REG_R,ARG_IMM16_A,ARG_MODRM16,ARG_SIMM8,ARG_IMM32,
    ARG_STRING,ARG_MODRM_BCD,ARG_PSTRING,ARG_DOSSTRING,ARG_CUNICODESTRING,
    ARG_PUNICODESTRING,ARG_NONEBYTE,ARG_XREG,ARG_XMMMODRM,ARG_IMM_SINGLE,
    ARG_IMM_DOUBLE,ARG_IMM_LONGDOUBLE);

  pasminstdata=^tasminstdata;
  tasminstdata=record        //Asm Instructions data
    nam           :pchar;    //eg nop,NULL=subtable/undefined
    instbyte      :byte;     //   = $90/subtable number
    cpu           :word;     //   8086 or 386 or 486 or pentium,etc bitwise flags
    flags         :dword;    //   mod r/m,8/16/32 bit
    arg1,arg2,arg3:argtype;  //   argtypes=reg/none/immediate,etc
    uniq          :dword;    //   unique id for reconstructing saved databases
  end;
  pasminstdataarr=^tasminstdataarr;
  tasminstdataarr=array[0..1000] of tasminstdata;

type
  pasmtable=^tasmtable;
  tasmtable=record               //Assembly instruction tables
    table         :pasminstdata; //Pointer to table of instruction encodings
    typ           :byte;         // type - main table/extension
    extnum,extnum2:byte;         // bytes= first bytes of instruction
    divisor       :byte;         // number to divide by for look up
    mask          :byte;         // bit mask for look up
    minlim,maxlim :byte;         // limits on min/max entries.
    modrmpos      :byte;         // modrm byte position plus
  end;
  pasmtablearr=^tasmtablearr;
  tasmtablearr=array[0..1000] of tasmtable;

  proctable=record
    num:dword;
    nam:pchar;
    tab:pasmtable;
  end;

const
  reg32ascii:array[0..7] of pchar=('eax','ecx','edx','ebx','esp','ebp','esi','edi');
  reg16ascii:array[0..7] of pchar=('ax','cx','dx','bx','sp','bp','si','di');
  reg8ascii :array[0..7] of pchar=('al','cl','dl','bl','ah','ch','dh','bh');
  regix16asc:array[0..7] of pchar=('bx+si','bx+di','bp+si','bp+di','si','di','bp','bx');
  regfascii :array[0..7] of pchar=('st(0)','st(1)','st(2)','st(3)','st(4)','st(5)','st(6)','st(7)');
  regmascii :array[0..7] of pchar=('mm0','mm1','mm2','mm3','mm4','mm5','mm6','mm7');
  regxascii :array[0..7] of pchar=('xmm0','xmm1','xmm2','xmm3','xmm4','xmm5','xmm6','xmm7');
  regsascii :array[0..7] of pchar=('es','cs','ss','ds','fs','gs','??','??');
  regcascii :array[0..7] of pchar=('cr0','cr1','cr2','cr3','cr4','cr5','cr6','cr7');
  regdascii :array[0..7] of pchar=('dr0','dr1','dr2','dr3','dr4','dr5','dr6','dr7');
  regtascii :array[0..7] of pchar=('tr0','tr1','tr2','tr3','tr4','tr5','tr6','tr7');
  regzascii :array[0..7] of pchar=('b','c','d','e','h','l','(hl)','a');

  _asm86:array[0..361] of tasminstdata=(
  (nam:'add';   instbyte:$00;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:1),
  (nam:'add';   instbyte:$01;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:2),
  (nam:'add';   instbyte:$01;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:3),
  (nam:'add';   instbyte:$02;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:4),
  (nam:'add';   instbyte:$03;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:5),
  (nam:'add';   instbyte:$03;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:6),
  (nam:'add';   instbyte:$04;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_REG_AL;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:7),
  (nam:'add';   instbyte:$05;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:8),
  (nam:'add';   instbyte:$05;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:9),
  (nam:'push';  instbyte:$06;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_REG_ES;arg2:ARG_NONE;arg3:ARG_NONE;uniq:10),
  (nam:'pop';   instbyte:$07;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_REG_ES;arg2:ARG_NONE;arg3:ARG_NONE;uniq:11),
  (nam:'or';    instbyte:$08;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:12),
  (nam:'or';    instbyte:$09;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:13),
  (nam:'or';    instbyte:$09;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:14),
  (nam:'or';    instbyte:$0a;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:15),
  (nam:'or';    instbyte:$0b;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:16),
  (nam:'or';    instbyte:$0b;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:17),
  (nam:'or';    instbyte:$0c;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_REG_AL;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:18),
  (nam:'or';    instbyte:$0d;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:19),
  (nam:'or';    instbyte:$0d;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:20),
  (nam:'push';  instbyte:$0e;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_REG_CS;arg2:ARG_NONE;arg3:ARG_NONE;uniq:21),
  (nam: nil;    instbyte:$0f;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:22),  //subtable = $0f
  (nam:'adc';   instbyte:$10;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:23),
  (nam:'adc';   instbyte:$11;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:24),
  (nam:'adc';   instbyte:$11;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:25),
  (nam:'adc';   instbyte:$12;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:26),
  (nam:'adc';   instbyte:$13;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:27),
  (nam:'adc';   instbyte:$13;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:28),
  (nam:'adc';   instbyte:$14;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_REG_AL;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:29),
  (nam:'adc';   instbyte:$15;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:30),
  (nam:'adc';   instbyte:$15;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:31),
  (nam:'push';  instbyte:$16;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_REG_SS;arg2:ARG_NONE;arg3:ARG_NONE;uniq:32),
  (nam:'pop';   instbyte:$17;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_REG_SS;arg2:ARG_NONE;arg3:ARG_NONE;uniq:33),
  (nam:'sbb';   instbyte:$18;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:34),
  (nam:'sbb';   instbyte:$19;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:35),
  (nam:'sbb';   instbyte:$19;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:36),
  (nam:'sbb';   instbyte:$1a;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:37),
  (nam:'sbb';   instbyte:$1b;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:38),
  (nam:'sbb';   instbyte:$1b;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:39),
  (nam:'sbb';   instbyte:$1c;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_REG_AL;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:40),
  (nam:'sbb';   instbyte:$1d;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:41),
  (nam:'sbb';   instbyte:$1d;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:42),
  (nam:'push';  instbyte:$1e;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_REG_DS;arg2:ARG_NONE;arg3:ARG_NONE;uniq:43),
  (nam:'pop';   instbyte:$1f;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_REG_DS;arg2:ARG_NONE;arg3:ARG_NONE;uniq:44),
  (nam:'and';   instbyte:$20;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:45),
  (nam:'and';   instbyte:$21;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:46),
  (nam:'and';   instbyte:$21;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:47),
  (nam:'and';   instbyte:$22;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:48),
  (nam:'and';   instbyte:$23;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:49),
  (nam:'and';   instbyte:$23;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:50),
  (nam:'and';   instbyte:$24;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_REG_AL;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:51),
  (nam:'and';   instbyte:$25;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:52),
  (nam:'and';   instbyte:$25;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:53),
  (nam:'es:';   instbyte:$26;cpu:PROC_FROM8086; flags:FLAGS_SEGPREFIX;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:54),
  (nam:'daa';   instbyte:$27;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:55),
  (nam:'sub';   instbyte:$28;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:56),
  (nam:'sub';   instbyte:$29;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:57),
  (nam:'sub';   instbyte:$29;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:58),
  (nam:'sub';   instbyte:$2a;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:59),
  (nam:'sub';   instbyte:$2b;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:60),
  (nam:'sub';   instbyte:$2b;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:61),
  (nam:'sub';   instbyte:$2c;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_REG_AL;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:62),
  (nam:'sub';   instbyte:$2d;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:63),
  (nam:'sub';   instbyte:$2d;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:64),
  (nam:'cs:';   instbyte:$2e;cpu:PROC_FROM8086; flags:FLAGS_SEGPREFIX;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:65),
  (nam:'das';   instbyte:$2f;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:66),
  (nam:'xor';   instbyte:$30;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:67),
  (nam:'xor';   instbyte:$31;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:68),
  (nam:'xor';   instbyte:$31;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:69),
  (nam:'xor';   instbyte:$32;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:70),
  (nam:'xor';   instbyte:$33;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:71),
  (nam:'xor';   instbyte:$33;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:72),
  (nam:'xor';   instbyte:$34;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_REG_AL;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:73),
  (nam:'xor';   instbyte:$35;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:74),
  (nam:'xor';   instbyte:$35;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:75),
  (nam:'ss:';   instbyte:$36;cpu:PROC_FROM8086; flags:FLAGS_SEGPREFIX;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:76),
  (nam:'aaa';   instbyte:$37;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:77),
  (nam:'cmp';   instbyte:$38;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:78),
  (nam:'cmp';   instbyte:$39;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:79),
  (nam:'cmp';   instbyte:$39;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:80),
  (nam:'cmp';   instbyte:$3a;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:81),
  (nam:'cmp';   instbyte:$3b;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:82),
  (nam:'cmp';   instbyte:$3b;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:83),
  (nam:'cmp';   instbyte:$3c;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_REG_AL;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:84),
  (nam:'cmp';   instbyte:$3d;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:85),
  (nam:'cmp';   instbyte:$3d;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:86),
  (nam:'ds:';   instbyte:$3e;cpu:PROC_FROM8086; flags:FLAGS_SEGPREFIX;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:87),
  (nam:'aas';   instbyte:$3f;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:88),
  (nam:'inc';   instbyte:$40;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:89),
  (nam:'inc';   instbyte:$40;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:90),
  (nam:'inc';   instbyte:$41;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_CX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:91),
  (nam:'inc';   instbyte:$41;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_CX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:92),
  (nam:'inc';   instbyte:$42;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_DX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:93),
  (nam:'inc';   instbyte:$42;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_DX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:94),
  (nam:'inc';   instbyte:$43;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_BX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:95),
  (nam:'inc';   instbyte:$43;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_BX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:96),
  (nam:'inc';   instbyte:$44;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_SP;arg2:ARG_NONE;arg3:ARG_NONE;uniq:97),
  (nam:'inc';   instbyte:$44;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_SP;arg2:ARG_NONE;arg3:ARG_NONE;uniq:98),
  (nam:'inc';   instbyte:$45;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_BP;arg2:ARG_NONE;arg3:ARG_NONE;uniq:99),
  (nam:'inc';   instbyte:$45;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_BP;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100),
  (nam:'inc';   instbyte:$46;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_SI;arg2:ARG_NONE;arg3:ARG_NONE;uniq:101),
  (nam:'inc';   instbyte:$46;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_SI;arg2:ARG_NONE;arg3:ARG_NONE;uniq:102),
  (nam:'inc';   instbyte:$47;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_DI;arg2:ARG_NONE;arg3:ARG_NONE;uniq:103),
  (nam:'inc';   instbyte:$47;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_DI;arg2:ARG_NONE;arg3:ARG_NONE;uniq:104),
  (nam:'dec';   instbyte:$48;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:105),
  (nam:'dec';   instbyte:$48;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106),
  (nam:'dec';   instbyte:$49;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_CX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:107),
  (nam:'dec';   instbyte:$49;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_CX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:108),
  (nam:'dec';   instbyte:$4a;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_DX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:109),
  (nam:'dec';   instbyte:$4a;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_DX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:110),
  (nam:'dec';   instbyte:$4b;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_BX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:111),
  (nam:'dec';   instbyte:$4b;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_BX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:112),
  (nam:'dec';   instbyte:$4c;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_SP;arg2:ARG_NONE;arg3:ARG_NONE;uniq:113),
  (nam:'dec';   instbyte:$4c;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_SP;arg2:ARG_NONE;arg3:ARG_NONE;uniq:114),
  (nam:'dec';   instbyte:$4d;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_BP;arg2:ARG_NONE;arg3:ARG_NONE;uniq:115),
  (nam:'dec';   instbyte:$4d;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_BP;arg2:ARG_NONE;arg3:ARG_NONE;uniq:116),
  (nam:'dec';   instbyte:$4e;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_SI;arg2:ARG_NONE;arg3:ARG_NONE;uniq:117),
  (nam:'dec';   instbyte:$4e;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_SI;arg2:ARG_NONE;arg3:ARG_NONE;uniq:118),
  (nam:'dec';   instbyte:$4f;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_DI;arg2:ARG_NONE;arg3:ARG_NONE;uniq:119),
  (nam:'dec';   instbyte:$4f;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_DI;arg2:ARG_NONE;arg3:ARG_NONE;uniq:120),
  (nam:'push';  instbyte:$50;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:121),
  (nam:'push';  instbyte:$50;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:122),
  (nam:'push';  instbyte:$51;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_CX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:123),
  (nam:'push';  instbyte:$51;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_CX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:124),
  (nam:'push';  instbyte:$52;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_DX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:125),
  (nam:'push';  instbyte:$52;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_DX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:126),
  (nam:'push';  instbyte:$53;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_BX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:127),
  (nam:'push';  instbyte:$53;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_BX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:128),
  (nam:'push';  instbyte:$54;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_SP;arg2:ARG_NONE;arg3:ARG_NONE;uniq:129),
  (nam:'push';  instbyte:$54;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_SP;arg2:ARG_NONE;arg3:ARG_NONE;uniq:130),
  (nam:'push';  instbyte:$55;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_BP;arg2:ARG_NONE;arg3:ARG_NONE;uniq:131),
  (nam:'push';  instbyte:$55;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_BP;arg2:ARG_NONE;arg3:ARG_NONE;uniq:132),
  (nam:'push';  instbyte:$56;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_SI;arg2:ARG_NONE;arg3:ARG_NONE;uniq:133),
  (nam:'push';  instbyte:$56;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_SI;arg2:ARG_NONE;arg3:ARG_NONE;uniq:134),
  (nam:'push';  instbyte:$57;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_DI;arg2:ARG_NONE;arg3:ARG_NONE;uniq:135),
  (nam:'push';  instbyte:$57;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_DI;arg2:ARG_NONE;arg3:ARG_NONE;uniq:136),
  (nam:'pop';   instbyte:$58;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:137),
  (nam:'pop';   instbyte:$58;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:138),
  (nam:'pop';   instbyte:$59;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_CX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:139),
  (nam:'pop';   instbyte:$59;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_CX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:140),
  (nam:'pop';   instbyte:$5a;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_DX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:141),
  (nam:'pop';   instbyte:$5a;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_DX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:142),
  (nam:'pop';   instbyte:$5b;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_BX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:143),
  (nam:'pop';   instbyte:$5b;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_BX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:144),
  (nam:'pop';   instbyte:$5c;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_SP;arg2:ARG_NONE;arg3:ARG_NONE;uniq:145),
  (nam:'pop';   instbyte:$5c;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_SP;arg2:ARG_NONE;arg3:ARG_NONE;uniq:146),
  (nam:'pop';   instbyte:$5d;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_BP;arg2:ARG_NONE;arg3:ARG_NONE;uniq:147),
  (nam:'pop';   instbyte:$5d;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_BP;arg2:ARG_NONE;arg3:ARG_NONE;uniq:148),
  (nam:'pop';   instbyte:$5e;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_SI;arg2:ARG_NONE;arg3:ARG_NONE;uniq:149),
  (nam:'pop';   instbyte:$5e;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_SI;arg2:ARG_NONE;arg3:ARG_NONE;uniq:150),
  (nam:'pop';   instbyte:$5f;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_DI;arg2:ARG_NONE;arg3:ARG_NONE;uniq:151),
  (nam:'pop';   instbyte:$5f;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_DI;arg2:ARG_NONE;arg3:ARG_NONE;uniq:152),
  (nam:'pusha'; instbyte:$60;cpu:PROC_FROM80286;flags:FLAGS_OMODE16;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:153),
  (nam:'pushad';instbyte:$60;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:154),
  (nam:'popa';  instbyte:$61;cpu:PROC_FROM80286;flags:FLAGS_OMODE16;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:155),
  (nam:'popad'; instbyte:$61;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:156),
  (nam:'bound'; instbyte:$62;cpu:PROC_FROM80286;flags:FLAGS_MODRM;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:157),
  (nam:'arpl';  instbyte:$63;cpu:PROC_FROM80286;flags:FLAGS_PMODE or FLAGS_16BIT or FLAGS_MODRM;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:158),
  (nam:'fs:';   instbyte:$64;cpu:PROC_FROM80386;flags:FLAGS_SEGPREFIX;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:159),
  (nam:'gs:';   instbyte:$65;cpu:PROC_FROM80386;flags:FLAGS_SEGPREFIX;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:160),
  (nam:'';      instbyte:$66;cpu:PROC_FROM80386;flags:FLAGS_OPERPREFIX;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:161),
  (nam:'';      instbyte:$67;cpu:PROC_FROM80386;flags:FLAGS_ADDRPREFIX;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:162),
  (nam:'push';  instbyte:$68;cpu:PROC_FROM80286;flags:FLAGS_OMODE16;
   arg1:ARG_IMM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:163),
  (nam:'push';  instbyte:$68;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_IMM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:164),
  (nam:'imul';  instbyte:$69;cpu:PROC_FROM80386;flags:FLAGS_MODRM;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_IMM;uniq:165),
  (nam:'push';  instbyte:$6a;cpu:PROC_FROM80286;flags:0;
   arg1:ARG_IMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:166),
  (nam:'imul';  instbyte:$6b;cpu:PROC_FROM80386;flags:FLAGS_MODRM;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_IMM8;uniq:167),
  (nam:'insb';  instbyte:$6c;cpu:PROC_FROM80286;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:168),
  (nam:'insw';  instbyte:$6d;cpu:PROC_FROM80286;flags:FLAGS_OMODE16;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:169),
  (nam:'insd';  instbyte:$6d;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:170),
  (nam:'outsb'; instbyte:$6e;cpu:PROC_FROM80286;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:171),
  (nam:'outsw'; instbyte:$6f;cpu:PROC_FROM80286;flags:FLAGS_OMODE16;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:172),
  (nam:'outsd'; instbyte:$6f;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:173),
  (nam:'jo';    instbyte:$70;cpu:PROC_FROM8086; flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:174),
  (nam:'jno';   instbyte:$71;cpu:PROC_FROM8086; flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:175),
  (nam:'jc';    instbyte:$72;cpu:PROC_FROM8086; flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:176),
  (nam:'jnc';   instbyte:$73;cpu:PROC_FROM8086; flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:177),
  (nam:'jz';    instbyte:$74;cpu:PROC_FROM8086; flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:178),
  (nam:'jnz';   instbyte:$75;cpu:PROC_FROM8086; flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:179),
  (nam:'jbe';   instbyte:$76;cpu:PROC_FROM8086; flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:180),
  (nam:'ja';    instbyte:$77;cpu:PROC_FROM8086; flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:181),
  (nam:'js';    instbyte:$78;cpu:PROC_FROM8086; flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:182),
  (nam:'jns';   instbyte:$79;cpu:PROC_FROM8086; flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:183),
  (nam:'jpe';   instbyte:$7a;cpu:PROC_FROM8086; flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:184),
  (nam:'jpo';   instbyte:$7b;cpu:PROC_FROM8086; flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:185),
  (nam:'jl';    instbyte:$7c;cpu:PROC_FROM8086; flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:186),
  (nam:'jge';   instbyte:$7d;cpu:PROC_FROM8086; flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:187),
  (nam:'jle';   instbyte:$7e;cpu:PROC_FROM8086; flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:188),
  (nam:'jg';    instbyte:$7f;cpu:PROC_FROM8086; flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:189),
  (nam:nil;     instbyte:$80;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:190),  //subtable $80
  (nam:nil;     instbyte:$81;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:191),  //subtable $81
  (nam:nil;     instbyte:$82;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:192),  //subtable $82
  (nam:nil;     instbyte:$83;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:193),  //subtable $83
  (nam:'test';  instbyte:$84;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:194),
  (nam:'test';  instbyte:$85;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:195),
  (nam:'test';  instbyte:$85;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:196),
  (nam:'xchg';  instbyte:$86;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:197),
  (nam:'xchg';  instbyte:$87;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:198),
  (nam:'xchg';  instbyte:$87;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:199),
  (nam:'mov';   instbyte:$88;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:200),
  (nam:'mov';   instbyte:$89;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:201),
  (nam:'mov';   instbyte:$89;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_REG;arg3:ARG_NONE;uniq:202),
  (nam:'mov';   instbyte:$8a;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:203),
  (nam:'mov';   instbyte:$8b;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:204),
  (nam:'mov';   instbyte:$8b;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:205),
  (nam:'mov';   instbyte:$8c;cpu:PROC_FROM8086; flags:FLAGS_MODRM;
   arg1:ARG_MODRM;arg2:ARG_SREG;arg3:ARG_NONE;uniq:206),
  (nam:'lea';   instbyte:$8d;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:207),
  (nam:'lea';   instbyte:$8d;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:208),
  (nam:'mov';   instbyte:$8e;cpu:PROC_FROM8086; flags:FLAGS_MODRM;
   arg1:ARG_SREG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:209),
  (nam:'pop';   instbyte:$8f;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:210),
  (nam:'pop';   instbyte:$8f;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:211),
  (nam:'nop';   instbyte:$90;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:212),
  (nam:'xchg';  instbyte:$91;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_REG_CX;arg3:ARG_NONE;uniq:213),
  (nam:'xchg';  instbyte:$91;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_REG_CX;arg3:ARG_NONE;uniq:214),
  (nam:'xchg';  instbyte:$92;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_REG_DX;arg3:ARG_NONE;uniq:215),
  (nam:'xchg';  instbyte:$92;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_REG_DX;arg3:ARG_NONE;uniq:216),
  (nam:'xchg';  instbyte:$93;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_REG_BX;arg3:ARG_NONE;uniq:217),
  (nam:'xchg';  instbyte:$93;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_REG_BX;arg3:ARG_NONE;uniq:218),
  (nam:'xchg';  instbyte:$94;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_REG_SP;arg3:ARG_NONE;uniq:219),
  (nam:'xchg';  instbyte:$94;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_REG_SP;arg3:ARG_NONE;uniq:220),
  (nam:'xchg';  instbyte:$95;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_REG_BP;arg3:ARG_NONE;uniq:221),
  (nam:'xchg';  instbyte:$95;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_REG_BP;arg3:ARG_NONE;uniq:222),
  (nam:'xchg';  instbyte:$96;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_REG_SI;arg3:ARG_NONE;uniq:223),
  (nam:'xchg';  instbyte:$96;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_REG_SI;arg3:ARG_NONE;uniq:224),
  (nam:'xchg';  instbyte:$97;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_REG_DI;arg3:ARG_NONE;uniq:225),
  (nam:'xchg';  instbyte:$97;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_REG_DI;arg3:ARG_NONE;uniq:226),
  (nam:'cbw';   instbyte:$98;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:227),
  (nam:'cwde';  instbyte:$98;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:228),
  (nam:'cwd';   instbyte:$99;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:229),
  (nam:'cdq';   instbyte:$99;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:230),
  (nam:'callf'; instbyte:$9a;cpu:PROC_FROM8086; flags:FLAGS_CALL or FLAGS_OMODE16;
   arg1:ARG_FADDR;arg2:ARG_NONE;arg3:ARG_NONE;uniq:231),
  (nam:'callf'; instbyte:$9a;cpu:PROC_FROM80386;flags:FLAGS_CALL or FLAGS_OMODE32;
   arg1:ARG_FADDR;arg2:ARG_NONE;arg3:ARG_NONE;uniq:232),
  (nam:'wait';  instbyte:$9b;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:233),
  (nam:'pushf'; instbyte:$9c;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:234),
  (nam:'pushfd';instbyte:$9c;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:235),
  (nam:'popf';  instbyte:$9d;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:236),
  (nam:'popfd'; instbyte:$9d;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:237),
  (nam:'sahf';  instbyte:$9e;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:238),
  (nam:'lahf';  instbyte:$9f;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:239),
  (nam:'mov';   instbyte:$a0;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_REG_AL;arg2:ARG_MEMLOC;arg3:ARG_NONE;uniq:240),
  (nam:'mov';   instbyte:$a1;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_MEMLOC;arg3:ARG_NONE;uniq:241),
  (nam:'mov';   instbyte:$a1;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_MEMLOC;arg3:ARG_NONE;uniq:242),
  (nam:'mov';   instbyte:$a2;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_MEMLOC;arg2:ARG_REG_AL;arg3:ARG_NONE;uniq:243),
  (nam:'mov';   instbyte:$a3;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_MEMLOC;arg2:ARG_REG_AX;arg3:ARG_NONE;uniq:244),
  (nam:'mov';   instbyte:$a3;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_MEMLOC;arg2:ARG_REG_AX;arg3:ARG_NONE;uniq:245),
  (nam:'movsb'; instbyte:$a4;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:246),
  (nam:'movsw'; instbyte:$a5;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:247),
  (nam:'movsd'; instbyte:$a5;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:248),
  (nam:'cmpsb'; instbyte:$a6;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:249),
  (nam:'cmpsw'; instbyte:$a7;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:250),
  (nam:'cmpsd'; instbyte:$a7;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:251),
  (nam:'test';  instbyte:$a8;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_REG_AL;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:252),
  (nam:'test';  instbyte:$a9;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:253),
  (nam:'test';  instbyte:$a9;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:254),
  (nam:'stosb'; instbyte:$aa;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:255),
  (nam:'stosw'; instbyte:$ab;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:256),
  (nam:'stosd'; instbyte:$ab;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:257),
  (nam:'lodsb'; instbyte:$ac;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:258),
  (nam:'lodsw'; instbyte:$ad;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:259),
  (nam:'lodsd'; instbyte:$ad;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:260),
  (nam:'scasb'; instbyte:$ae;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:261),
  (nam:'scasw'; instbyte:$af;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:262),
  (nam:'scasd'; instbyte:$af;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:263),
  (nam:'mov';   instbyte:$b0;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_REG_AL;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:264),
  (nam:'mov';   instbyte:$b1;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_REG_CL;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:265),
  (nam:'mov';   instbyte:$b2;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_REG_DL;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:266),
  (nam:'mov';   instbyte:$b3;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_REG_BL;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:267),
  (nam:'mov';   instbyte:$b4;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_REG_AH;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:268),
  (nam:'mov';   instbyte:$b5;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_REG_CH;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:269),
  (nam:'mov';   instbyte:$b6;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_REG_DH;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:270),
  (nam:'mov';   instbyte:$b7;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_REG_BH;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:271),
  (nam:'mov';   instbyte:$b8;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:272),
  (nam:'mov';   instbyte:$b8;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:273),
  (nam:'mov';   instbyte:$b9;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_CX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:274),
  (nam:'mov';   instbyte:$b9;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_CX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:275),
  (nam:'mov';   instbyte:$ba;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_DX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:276),
  (nam:'mov';   instbyte:$ba;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_DX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:277),
  (nam:'mov';   instbyte:$bb;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_BX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:278),
  (nam:'mov';   instbyte:$bb;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_BX;arg2:ARG_IMM;arg3:ARG_NONE;uniq:279),
  (nam:'mov';   instbyte:$bc;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_SP;arg2:ARG_IMM;arg3:ARG_NONE;uniq:280),
  (nam:'mov';   instbyte:$bc;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_SP;arg2:ARG_IMM;arg3:ARG_NONE;uniq:281),
  (nam:'mov';   instbyte:$bd;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_BP;arg2:ARG_IMM;arg3:ARG_NONE;uniq:282),
  (nam:'mov';   instbyte:$bd;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_BP;arg2:ARG_IMM;arg3:ARG_NONE;uniq:283),
  (nam:'mov';   instbyte:$be;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_SI;arg2:ARG_IMM;arg3:ARG_NONE;uniq:284),
  (nam:'mov';   instbyte:$be;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_SI;arg2:ARG_IMM;arg3:ARG_NONE;uniq:285),
  (nam:'mov';   instbyte:$bf;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_DI;arg2:ARG_IMM;arg3:ARG_NONE;uniq:286),
  (nam:'mov';   instbyte:$bf;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_DI;arg2:ARG_IMM;arg3:ARG_NONE;uniq:287),
  (nam:nil;     instbyte:$c0;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:288),  //subtable $c0
  (nam:nil;     instbyte:$c1;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:289),  //subtable $c1
  (nam:'ret';   instbyte:$c2;cpu:PROC_FROM8086; flags:FLAGS_16BIT or FLAGS_RET;
   arg1:ARG_IMM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:290),
  (nam:'ret';   instbyte:$c3;cpu:PROC_FROM8086; flags:FLAGS_RET;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:291),
  (nam:'les';   instbyte:$c4;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:292),
  (nam:'les';   instbyte:$c4;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:293),
  (nam:'lds';   instbyte:$c5;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:294),
  (nam:'lds';   instbyte:$c5;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_REG;arg2:ARG_MODRM;arg3:ARG_NONE;uniq:295),
  (nam:'mov';   instbyte:$c6;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:296),
  (nam:'mov';   instbyte:$c7;cpu:PROC_FROM8086; flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM;arg3:ARG_NONE;uniq:297),
  (nam:'mov';   instbyte:$c7;cpu:PROC_FROM80386;flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM;arg3:ARG_NONE;uniq:298),
  (nam:'enter'; instbyte:$c8;cpu:PROC_FROM80286;flags:FLAGS_16BIT;
   arg1:ARG_IMM16_A;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:299),
  (nam:'leave'; instbyte:$c9;cpu:PROC_FROM80286;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:300),
  (nam:'retf';  instbyte:$ca;cpu:PROC_FROM8086; flags:FLAGS_16BIT or FLAGS_RET;
   arg1:ARG_IMM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:301),
  (nam:'retf';  instbyte:$cb;cpu:PROC_FROM8086; flags:FLAGS_RET;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:302),
  (nam:'int 3'; instbyte:$cc;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:303),
  (nam:'int';   instbyte:$cd;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_IMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:304),
  (nam:'into';  instbyte:$ce;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:305),
  (nam:'iret';  instbyte:$cf;cpu:PROC_FROM8086; flags:FLAGS_RET;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:306),
  (nam:nil;     instbyte:$d0;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:307),  //subtable $d0
  (nam:nil;     instbyte:$d1;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:308),  //subtable $d1
  (nam:nil;     instbyte:$d2;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:309),  //subtable $d2
  (nam:nil;     instbyte:$d3;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:310),  //subtable $d3
  (nam:'aam';   instbyte:$d4;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_IMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:311),
  (nam:'aad';   instbyte:$d5;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_IMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:312),
  (nam:'setalc';instbyte:$d6;cpu:PROC_FROM80286;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:313), //UNDOCUMENTED
  (nam:'xlat';  instbyte:$d7;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:314),
  (nam:nil;     instbyte:$d8;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:315),  //subtable $d8
  (nam:nil;     instbyte:$d9;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:316),  //subtable $d9
  (nam:nil;     instbyte:$da;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:317),  //subtable $da
  (nam:nil;     instbyte:$db;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:318),  //subtable $db
  (nam:nil;     instbyte:$dc;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:319),  //subtable $dc
  (nam:nil;     instbyte:$dd;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:320),  //subtable $dd
  (nam:nil;     instbyte:$de;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:321),  //subtable $de
  (nam:nil;     instbyte:$df;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:322),  //subtable $df
  (nam:'loopnz';instbyte:$e0;cpu:PROC_FROM8086; flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:323),
  (nam:'loopz'; instbyte:$e1;cpu:PROC_FROM8086; flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:324),
  (nam:'loop';  instbyte:$e2;cpu:PROC_FROM8086; flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:325),
  (nam:'jcxz';  instbyte:$e3;cpu:PROC_FROM8086; flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:326),
  (nam:'in';    instbyte:$e4;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_REG_AL;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:327),
  (nam:'in';    instbyte:$e5;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:328),
  (nam:'in';    instbyte:$e5;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:329),
  (nam:'out';   instbyte:$e6;cpu:PROC_FROM8086; flags:FLAGS_8BIT;
   arg1:ARG_IMM8;arg2:ARG_REG_AL;arg3:ARG_NONE;uniq:330),
  (nam:'out';   instbyte:$e7;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_IMM8;arg2:ARG_REG_AX;arg3:ARG_NONE;uniq:331),
  (nam:'out';   instbyte:$e7;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_IMM8;arg2:ARG_REG_AX;arg3:ARG_NONE;uniq:332),
  (nam:'call';  instbyte:$e8;cpu:PROC_FROM8086; flags:FLAGS_CALL or FLAGS_OMODE16;
   arg1:ARG_RELIMM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:333),
  (nam:'call';  instbyte:$e8;cpu:PROC_FROM80386;flags:FLAGS_CALL or FLAGS_OMODE32;
   arg1:ARG_RELIMM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:334),
  (nam:'jmp';   instbyte:$e9;cpu:PROC_FROM8086; flags:FLAGS_JMP or FLAGS_OMODE16;
   arg1:ARG_RELIMM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:335),
  (nam:'jmp';   instbyte:$e9;cpu:PROC_FROM80386;flags:FLAGS_JMP or FLAGS_OMODE32;
   arg1:ARG_RELIMM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:336),
  (nam:'jmp';   instbyte:$ea;cpu:PROC_FROM8086; flags:FLAGS_JMP or FLAGS_OMODE16;
   arg1:ARG_FADDR;arg2:ARG_NONE;arg3:ARG_NONE;uniq:337),
  (nam:'jmp';   instbyte:$ea;cpu:PROC_FROM80386;flags:FLAGS_JMP or FLAGS_OMODE32;
   arg1:ARG_FADDR;arg2:ARG_NONE;arg3:ARG_NONE;uniq:338),
  (nam:'jmp';   instbyte:$eb;cpu:PROC_FROM8086; flags:FLAGS_JMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:339),
  (nam:'in';    instbyte:$ec;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_REG_AL;arg2:ARG_16REG_DX;arg3:ARG_NONE;uniq:340),
  (nam:'in';    instbyte:$ed;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_REG_AX;arg2:ARG_16REG_DX;arg3:ARG_NONE;uniq:341),
  (nam:'in';    instbyte:$ed;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_REG_AX;arg2:ARG_16REG_DX;arg3:ARG_NONE;uniq:342),
  (nam:'out';   instbyte:$ee;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_16REG_DX;arg2:ARG_REG_AL;arg3:ARG_NONE;uniq:343),
  (nam:'out';   instbyte:$ef;cpu:PROC_FROM8086; flags:FLAGS_OMODE16;
   arg1:ARG_16REG_DX;arg2:ARG_REG_AX;arg3:ARG_NONE;uniq:344),
  (nam:'out';   instbyte:$ef;cpu:PROC_FROM80386;flags:FLAGS_OMODE32;
   arg1:ARG_16REG_DX;arg2:ARG_REG_AX;arg3:ARG_NONE;uniq:345),
  (nam:'lock:'; instbyte:$f0;cpu:PROC_FROM8086; flags:FLAGS_PREFIX;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:346),
  (nam:'smi';   instbyte:$f1;cpu:PROC_FROM80386;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:347),  //UNDOCUMENTED/AMD ?
  (nam:'repne:';instbyte:$f2;cpu:PROC_FROM8086; flags:FLAGS_PREFIX;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:348),
  (nam:'rep:';  instbyte:$f3;cpu:PROC_FROM8086; flags:FLAGS_PREFIX;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:349),
  (nam:'hlt';   instbyte:$f4;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:350),
  (nam:'cmc';   instbyte:$f5;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:351),
  (nam:nil;     instbyte:$f6;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:352),  //subtable $f6
  (nam:nil;     instbyte:$f7;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:353),  //subtable $f7
  (nam:'clc';   instbyte:$f8;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:354),
  (nam:'stc';   instbyte:$f9;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:355),
  (nam:'cli';   instbyte:$fa;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:356),
  (nam:'sti';   instbyte:$fb;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:357),
  (nam:'cld';   instbyte:$fc;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:358),
  (nam:'std';   instbyte:$fd;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:359),
  (nam:nil;     instbyte:$fe;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:360),  //subtable $fe
  (nam:nil;     instbyte:$ff;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:361),  //subtable $ff
  (nam:nil;     instbyte:$00;cpu:0;             flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:0));

//Subtables needed - 0x0f, 0x80, 0x81, 0x82, 0x83, 0xc0, 0xc1,           ***done!
// 0xd0, 0xd1, 0xd2, 0xd3, 0xf6, 0xf7, 0xfe, 0xff                        ***done!
// 0xd8, 0xd9, 0xda, 0xdb, 0xdc, 0xdd, 0xde, 0xdf - FPU instructions
// 0x0f subtables : 0x00, 0x01, 0x18, 0x71, 0x72, 0x73, 0xae, 0xba, 0xc7 ***done!
//nb some instructions change when they have a segment overrider eg xlat.
// - how will this go in ?
//need to check undocumented instructions/amd insts- args/size/etc
//- setalc, smi

// subtable 0x0f
  _asm86sub0f:array[0..210] of tasminstdata=(
  (nam:nil;         instbyte:$00;cpu:PROC_FROM8086;     flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:1000), //subtable 0x0f/0x00
  (nam:nil;         instbyte:$01;cpu:PROC_FROM8086;     flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:1001), //subtable 0x0f/0x01
  (nam:'lar';       instbyte:$02;cpu:PROC_FROM80286;    flags:FLAGS_PMODE or FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1002),
  (nam:'lar';       instbyte:$02;cpu:PROC_FROM80386;    flags:FLAGS_PMODE or FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1003),
  (nam:'lsl';       instbyte:$03;cpu:PROC_FROM80286;    flags:FLAGS_PMODE or FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1004),
  (nam:'lsl';       instbyte:$03;cpu:PROC_FROM80386;    flags:FLAGS_PMODE or FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1005),
  (nam:'clts';      instbyte:$06;cpu:PROC_FROM80286;    flags:FLAGS_PMODE;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1006),
  (nam:'invd';      instbyte:$08;cpu:PROC_FROM80486;    flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1007),
  (nam:'wbinvd';    instbyte:$09;cpu:PROC_FROM80486;    flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1008),
  (nam:'cflsh';     instbyte:$0a;cpu:PROC_FROM80286;    flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1009),
  (nam:'ud2';       instbyte:$0b;cpu:PROC_FROM80286;    flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1010),
  (nam:'movups';    instbyte:$10;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1011),
  (nam:'movups';    instbyte:$11;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XMMMODRM; arg2:ARG_XREG;arg3:ARG_NONE;uniq:1012),
  (nam:'movlps';    instbyte:$12;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1013),
  (nam:'movlps';    instbyte:$13;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XMMMODRM; arg2:ARG_XREG;arg3:ARG_NONE;uniq:1014),
  (nam:'unpcklps';  instbyte:$14;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1015),
  (nam:'unpckhps';  instbyte:$15;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1016),
  (nam:'movhps';    instbyte:$16;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1017),
  (nam:'movhps';    instbyte:$17;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XMMMODRM; arg2:ARG_XREG;arg3:ARG_NONE;uniq:1018),
  (nam:nil;         instbyte:$18;cpu:PROC_FROM8086;     flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1019), // subtable 0x0f/0x18
  (nam:'mov';       instbyte:$20;cpu:PROC_FROM80386;    flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MODREG; arg2:ARG_CREG;arg3:ARG_NONE;uniq:1020),
  (nam:'mov';       instbyte:$21;cpu:PROC_FROM80386;    flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MODREG; arg2:ARG_DREG;arg3:ARG_NONE;uniq:1021),
  (nam:'mov';       instbyte:$22;cpu:PROC_FROM80386;    flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_CREG; arg2:ARG_MODREG;arg3:ARG_NONE;uniq:1022),
  (nam:'mov';       instbyte:$23;cpu:PROC_FROM80386;    flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_DREG; arg2:ARG_MODREG;arg3:ARG_NONE;uniq:1023),
  (nam:'mov';       instbyte:$24;cpu:PROC_80386 or PROC_80486;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MODREG; arg2:ARG_TREG_67;arg3:ARG_NONE;uniq:1024),
  (nam:'mov';       instbyte:$26;cpu:PROC_80386 or PROC_80486;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MODREG; arg2:ARG_TREG;arg3:ARG_NONE;uniq:1025),
  (nam:'movaps';    instbyte:$28;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1026),
  (nam:'movaps';    instbyte:$29;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XMMMODRM; arg2:ARG_XREG;arg3:ARG_NONE;uniq:1027),
  (nam:'cvtpi2ps';  instbyte:$2a;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1028),
  (nam:'movntps';   instbyte:$2b;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XMMMODRM; arg2:ARG_XREG;arg3:ARG_NONE;uniq:1029),
  (nam:'cvttps2pi'; instbyte:$2c;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1030),
  (nam:'cvtps2pi';  instbyte:$2d;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1031),
  (nam:'ucomiss';   instbyte:$2e;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1032),
  (nam:'comiss';    instbyte:$2f;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1033),
  (nam:'wrmsr';     instbyte:$30;cpu:PROC_FROMPENTIUM;  flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1034),
  (nam:'rdtsc';     instbyte:$31;cpu:PROC_FROMPENTIUM;  flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1035),
  (nam:'rdmsr';     instbyte:$32;cpu:PROC_FROMPENTIUM;  flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1036),
  (nam:'rdpmc';     instbyte:$33;cpu:PROC_FROMPENTPRO;  flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1037),
  (nam:'sysenter';  instbyte:$34;cpu:PROC_FROMPENTIUM2; flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1038),
  (nam:'sysexit';   instbyte:$35;cpu:PROC_FROMPENTIUM2; flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1039),
  (nam:'cmovo';     instbyte:$40;cpu:PROC_FROMPENTPRO;  flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1040),
  (nam:'cmovno';    instbyte:$41;cpu:PROC_FROMPENTPRO;  flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1041),
  (nam:'cmovc';     instbyte:$42;cpu:PROC_FROMPENTPRO;  flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1042),
  (nam:'cmovnc';    instbyte:$43;cpu:PROC_FROMPENTPRO;  flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1043),
  (nam:'cmovz';     instbyte:$44;cpu:PROC_FROMPENTPRO;  flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1044),
  (nam:'cmovnz';    instbyte:$45;cpu:PROC_FROMPENTPRO;  flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1045),
  (nam:'cmovbe';    instbyte:$46;cpu:PROC_FROMPENTPRO;  flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1046),
  (nam:'cmova';     instbyte:$47;cpu:PROC_FROMPENTPRO;  flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1047),
  (nam:'cmovs';     instbyte:$48;cpu:PROC_FROMPENTPRO;  flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1048),
  (nam:'cmovns';    instbyte:$49;cpu:PROC_FROMPENTPRO;  flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1049),
  (nam:'cmovpe';    instbyte:$4a;cpu:PROC_FROMPENTPRO;  flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1050),
  (nam:'cmovpo';    instbyte:$4b;cpu:PROC_FROMPENTPRO;  flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1051),
  (nam:'cmovl';     instbyte:$4c;cpu:PROC_FROMPENTPRO;  flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1052),
  (nam:'cmovge';    instbyte:$4d;cpu:PROC_FROMPENTPRO;  flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1053),
  (nam:'cmovle';    instbyte:$4e;cpu:PROC_FROMPENTPRO;  flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1054),
  (nam:'cmovg';     instbyte:$4f;cpu:PROC_FROMPENTPRO;  flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1055),
  (nam:'movmskps';  instbyte:$50;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_REG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1056),
  (nam:'sqrtps';    instbyte:$51;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1057),
  (nam:'rsqrtps';   instbyte:$52;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1058),
  (nam:'rcpps';     instbyte:$53;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1059),
  (nam:'andps';     instbyte:$54;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1060),
  (nam:'andnps';    instbyte:$55;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1061),
  (nam:'orps';      instbyte:$56;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1062),
  (nam:'xorps';     instbyte:$57;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1063),
  (nam:'addps';     instbyte:$58;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1064),
  (nam:'mulps';     instbyte:$59;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1065),
  (nam:'subps';     instbyte:$5c;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1066),
  (nam:'minps';     instbyte:$5d;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1067),
  (nam:'divps';     instbyte:$5e;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1068),
  (nam:'maxps';     instbyte:$5f;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:1069),
  (nam:'punpcklbw'; instbyte:$60;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1070),
  (nam:'punpcklwd'; instbyte:$61;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1071),
  (nam:'punpckldq'; instbyte:$62;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1072),
  (nam:'packsswb';  instbyte:$63;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1073),
  (nam:'pcmpgtb';   instbyte:$64;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1074),
  (nam:'pcmpgtw';   instbyte:$65;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1075),
  (nam:'pcmpgtd';   instbyte:$66;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1076),
  (nam:'packuswb';  instbyte:$67;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1077),
  (nam:'punpckhbw'; instbyte:$68;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1078),
  (nam:'punpckhwd'; instbyte:$69;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1079),
  (nam:'punpckhdq'; instbyte:$6a;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1080),
  (nam:'packssdw';  instbyte:$6b;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1081),
  (nam:'movd';      instbyte:$6e;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1082),
  (nam:'movq';      instbyte:$6f;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1083),
  (nam:'pshuf';     instbyte:$70;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_IMM8;uniq:1084),
  (nam:nil;         instbyte:$71;cpu:PROC_FROMPENTMMX; flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1085), //subtable 0x0f/0x71
  (nam:nil;         instbyte:$72;cpu:PROC_FROMPENTMMX; flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1086), //subtable 0x0f/0x72
  (nam:nil;         instbyte:$73;cpu:PROC_FROMPENTMMX; flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1087), //subtable 0x0f/0x73
  (nam:'pcmpeqb';   instbyte:$74;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1088),
  (nam:'pcmpeqw';   instbyte:$75;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1089),
  (nam:'pcmpeqd';   instbyte:$76;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1090),
  (nam:'emms';      instbyte:$77;cpu:PROC_FROMPENTMMX;  flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1091),
  (nam:'movd';      instbyte:$7e;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MODRM; arg2:ARG_MREG;arg3:ARG_NONE;uniq:1092),
  (nam:'movq';      instbyte:$7f;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MMXMODRM; arg2:ARG_MREG;arg3:ARG_NONE;uniq:1093),
  (nam:'jo';        instbyte:$80;cpu:PROC_FROM80386;    flags:FLAGS_CJMP;
   arg1:ARG_RELIMM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1094),
  (nam:'jno';       instbyte:$81;cpu:PROC_FROM80386;    flags:FLAGS_CJMP;
   arg1:ARG_RELIMM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1095),
  (nam:'jc';        instbyte:$82;cpu:PROC_FROM80386;    flags:FLAGS_CJMP;
   arg1:ARG_RELIMM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1096),
  (nam:'jnc';       instbyte:$83;cpu:PROC_FROM80386;    flags:FLAGS_CJMP;
   arg1:ARG_RELIMM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1097),
  (nam:'jz';        instbyte:$84;cpu:PROC_FROM80386;    flags:FLAGS_CJMP;
   arg1:ARG_RELIMM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1098),
  (nam:'jnz';       instbyte:$85;cpu:PROC_FROM80386;    flags:FLAGS_CJMP;
   arg1:ARG_RELIMM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1099),
  (nam:'jbe';       instbyte:$86;cpu:PROC_FROM80386;    flags:FLAGS_CJMP;
   arg1:ARG_RELIMM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1100),
  (nam:'ja';        instbyte:$87;cpu:PROC_FROM80386;    flags:FLAGS_CJMP;
   arg1:ARG_RELIMM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1101),
  (nam:'js';        instbyte:$88;cpu:PROC_FROM80386;    flags:FLAGS_CJMP;
   arg1:ARG_RELIMM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1102),
  (nam:'jns';       instbyte:$89;cpu:PROC_FROM80386;    flags:FLAGS_CJMP;
   arg1:ARG_RELIMM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1103),
  (nam:'jpe';       instbyte:$8a;cpu:PROC_FROM80386;    flags:FLAGS_CJMP;
   arg1:ARG_RELIMM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1104),
  (nam:'jpo';       instbyte:$8b;cpu:PROC_FROM80386;    flags:FLAGS_CJMP;
   arg1:ARG_RELIMM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1105),
  (nam:'jl';        instbyte:$8c;cpu:PROC_FROM80386;    flags:FLAGS_CJMP;
   arg1:ARG_RELIMM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1106),
  (nam:'jge';       instbyte:$8d;cpu:PROC_FROM80386;    flags:FLAGS_CJMP;
   arg1:ARG_RELIMM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1107),
  (nam:'jle';       instbyte:$8e;cpu:PROC_FROM80386;    flags:FLAGS_CJMP;
   arg1:ARG_RELIMM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1108),
  (nam:'jg';        instbyte:$8f;cpu:PROC_FROM80386;    flags:FLAGS_CJMP;
   arg1:ARG_RELIMM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1109),
  (nam:'seto';      instbyte:$90;cpu:PROC_FROM80386;    flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1110),
  (nam:'setno';     instbyte:$91;cpu:PROC_FROM80386;    flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1111),
  (nam:'setc';      instbyte:$92;cpu:PROC_FROM80386;    flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1112),
  (nam:'setnc';     instbyte:$93;cpu:PROC_FROM80386;    flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1113),
  (nam:'setz';      instbyte:$94;cpu:PROC_FROM80386;    flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1114),
  (nam:'setnz';     instbyte:$95;cpu:PROC_FROM80386;    flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1115),
  (nam:'setbe';     instbyte:$96;cpu:PROC_FROM80386;    flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1116),
  (nam:'seta';      instbyte:$97;cpu:PROC_FROM80386;    flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1117),
  (nam:'sets';      instbyte:$98;cpu:PROC_FROM80386;    flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1118),
  (nam:'setns';     instbyte:$99;cpu:PROC_FROM80386;    flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1119),
  (nam:'setpe';     instbyte:$9a;cpu:PROC_FROM80386;    flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1120),
  (nam:'setpo';     instbyte:$9b;cpu:PROC_FROM80386;    flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1121),
  (nam:'setl';      instbyte:$9c;cpu:PROC_FROM80386;    flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1122),
  (nam:'setge';     instbyte:$9d;cpu:PROC_FROM80386;    flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1123),
  (nam:'setle';     instbyte:$9e;cpu:PROC_FROM80386;    flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1124),
  (nam:'setg';      instbyte:$9f;cpu:PROC_FROM80386;    flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1125),
  (nam:'push';      instbyte:$a0;cpu:PROC_FROM80386;    flags:0;
   arg1:ARG_REG_FS; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1126),
  (nam:'pop';       instbyte:$a1;cpu:PROC_FROM80386;    flags:0;
   arg1:ARG_REG_FS; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1127),
  (nam:'cpuid';     instbyte:$a2;cpu:PROC_FROM80486;    flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1128),
  (nam:'bt';        instbyte:$a3;cpu:PROC_FROM80386;    flags:FLAGS_MODRM;
   arg1:ARG_MODRM; arg2:ARG_REG;arg3:ARG_NONE;uniq:1129),
  (nam:'shld';      instbyte:$a4;cpu:PROC_FROM80386;    flags:FLAGS_MODRM;
   arg1:ARG_MODRM; arg2:ARG_REG;arg3:ARG_IMM8;uniq:1130),
  (nam:'shld';      instbyte:$a5;cpu:PROC_FROM80386;    flags:FLAGS_MODRM;
   arg1:ARG_MODRM; arg2:ARG_REG;arg3:ARG_REG_CL;uniq:1131),
  (nam:'push';      instbyte:$a8;cpu:PROC_FROM80386;    flags:0;
   arg1:ARG_REG_GS; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1132),
  (nam:'pop';       instbyte:$a9;cpu:PROC_FROM80386;    flags:0;
   arg1:ARG_REG_GS; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1133),
  (nam:'rsm';       instbyte:$aa;cpu:PROC_FROM80386;    flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1134),
  (nam:'bts';       instbyte:$ab;cpu:PROC_FROM80386;    flags:FLAGS_MODRM;
   arg1:ARG_MODRM; arg2:ARG_REG;arg3:ARG_NONE;uniq:1135),
  (nam:'shrd';      instbyte:$ac;cpu:PROC_FROM80386;    flags:FLAGS_MODRM;
   arg1:ARG_MODRM; arg2:ARG_REG;arg3:ARG_IMM8;uniq:1136),
  (nam:'shrd';      instbyte:$ad;cpu:PROC_FROM80386;    flags:FLAGS_MODRM;
   arg1:ARG_MODRM; arg2:ARG_REG;arg3:ARG_REG_CL;uniq:1137),
  (nam:nil;         instbyte:$ae;cpu:PROC_FROMPENTIUM2; flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1138), //subtable 0x0f/0xae
  (nam:'imul';      instbyte:$af;cpu:PROC_FROM80386;    flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1139),
  (nam:'cmpxchg';   instbyte:$b0;cpu:PROC_FROM80486;    flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM; arg2:ARG_REG;arg3:ARG_NONE;uniq:1140),
  (nam:'cmpxchg';   instbyte:$b1;cpu:PROC_FROM80486;    flags:FLAGS_MODRM;
   arg1:ARG_MODRM; arg2:ARG_REG;arg3:ARG_NONE;uniq:1141),
  (nam:'lss';       instbyte:$b2;cpu:PROC_FROM80386;    flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1142),
  (nam:'btr';       instbyte:$b3;cpu:PROC_FROM80386;    flags:FLAGS_MODRM;
   arg1:ARG_MODRM; arg2:ARG_REG;arg3:ARG_NONE;uniq:1143),
  (nam:'lfs';       instbyte:$b4;cpu:PROC_FROM80386;    flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1144),
  (nam:'lgs';       instbyte:$b5;cpu:PROC_FROM80386;    flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1145),
  (nam:'movzx';     instbyte:$b6;cpu:PROC_FROM80386;    flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM8;arg3:ARG_NONE;uniq:1146),
  (nam:'movzx';     instbyte:$b7;cpu:PROC_FROM80386;    flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM16;arg3:ARG_NONE;uniq:1147),
  (nam:'ud1';       instbyte:$b9;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1148),
  (nam:nil;         instbyte:$ba;cpu:PROC_FROM8086; flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1149), //subtable 0x0f/0xba
  (nam:'btc';       instbyte:$bb;cpu:PROC_FROM80386;    flags:FLAGS_MODRM;
   arg1:ARG_MODRM; arg2:ARG_REG;arg3:ARG_NONE;uniq:1150),
  (nam:'bsf';       instbyte:$bc;cpu:PROC_FROM80386;    flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1151),
  (nam:'bsr';       instbyte:$bd;cpu:PROC_FROM80386;    flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM;arg3:ARG_NONE;uniq:1152),
  (nam:'movsx';     instbyte:$be;cpu:PROC_FROM80386;    flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM8;arg3:ARG_NONE;uniq:1153),
  (nam:'movsx';     instbyte:$bf;cpu:PROC_FROM80386;    flags:FLAGS_MODRM;
   arg1:ARG_REG; arg2:ARG_MODRM16;arg3:ARG_NONE;uniq:1154),
  (nam:'xadd';      instbyte:$c0;cpu:PROC_FROM80486;    flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM; arg2:ARG_REG;arg3:ARG_NONE;uniq:1155),
  (nam:'xadd';      instbyte:$c1;cpu:PROC_FROM80486;    flags:FLAGS_MODRM;
   arg1:ARG_MODRM; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1156),
  (nam:nil;         instbyte:$c2;cpu:PROC_FROMPENTIUM2; flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1157), //subtable 0x0f/0xc7
  (nam:'pinsrw';    instbyte:$c4;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MODRM;arg3:ARG_IMM8;uniq:1158),
  (nam:'pextrw';    instbyte:$c5;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_REG; arg2:ARG_MMXMODRM;arg3:ARG_IMM8;uniq:1159),
  (nam:'shufps';    instbyte:$c6;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG; arg2:ARG_XMMMODRM;arg3:ARG_IMM8;uniq:1160),
  (nam:nil;         instbyte:$c7;cpu:PROC_FROMPENTMMX; flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1161), //subtable 0x0f/0xc7
  (nam:'bswap';     instbyte:$c8;cpu:PROC_FROM80486;    flags:FLAGS_32BIT;
   arg1:ARG_REG_AX; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1162),
  (nam:'bswap';     instbyte:$c9;cpu:PROC_FROM80486;    flags:FLAGS_32BIT;
   arg1:ARG_REG_CX; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1163),
  (nam:'bswap';     instbyte:$ca;cpu:PROC_FROM80486;    flags:FLAGS_32BIT;
   arg1:ARG_REG_DX; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1164),
  (nam:'bswap';     instbyte:$cb;cpu:PROC_FROM80486;    flags:FLAGS_32BIT;
   arg1:ARG_REG_BX; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1165),
  (nam:'bswap';     instbyte:$cc;cpu:PROC_FROM80486;    flags:FLAGS_32BIT;
   arg1:ARG_REG_SP; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1166),
  (nam:'bswap';     instbyte:$cd;cpu:PROC_FROM80486;    flags:FLAGS_32BIT;
   arg1:ARG_REG_BP; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1167),
  (nam:'bswap';     instbyte:$ce;cpu:PROC_FROM80486;    flags:FLAGS_32BIT;
   arg1:ARG_REG_SI; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1168),
  (nam:'bswap';     instbyte:$cf;cpu:PROC_FROM80486;    flags:FLAGS_32BIT;
   arg1:ARG_REG_DI; arg2:ARG_NONE;arg3:ARG_NONE;uniq:1169),
  (nam:'psrlw';     instbyte:$d1;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1170),
  (nam:'psrld';     instbyte:$d2;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1171),
  (nam:'psrlq';     instbyte:$d3;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1172),
  (nam:'pmullw';    instbyte:$d5;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1173),
  (nam:'pmovmskb';  instbyte:$d7;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_REG; arg2:ARG_MMXMODRM;arg3:ARG_NONE; uniq:1174),
  (nam:'psubusb';   instbyte:$d8;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1175),
  (nam:'psubusw';   instbyte:$d9;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1176),
  (nam:'pminub';    instbyte:$da;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1177),
  (nam:'pand';      instbyte:$db;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1178),
  (nam:'paddusb';   instbyte:$dc;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1179),
  (nam:'paddusw';   instbyte:$dd;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1180),
  (nam:'pmaxub';    instbyte:$de;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1181),
  (nam:'pandn';     instbyte:$df;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1182),
  (nam:'pavgb';     instbyte:$e0;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1183),
  (nam:'psraw';     instbyte:$e1;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1184),
  (nam:'psrad';     instbyte:$e2;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1185),
  (nam:'pavgw';     instbyte:$e3;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1186),
  (nam:'pmulhuw';   instbyte:$e4;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1187),
  (nam:'pmulhw';    instbyte:$e5;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1188),
  (nam:'movntq';    instbyte:$e7;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MMXMODRM; arg2:ARG_MREG;arg3:ARG_NONE;uniq:1189),
  (nam:'psubsb';    instbyte:$e8;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1190),
  (nam:'psubsw';    instbyte:$e9;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1191),
  (nam:'pminsw';    instbyte:$ea;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:192),
  (nam:'por';       instbyte:$eb;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1193),
  (nam:'paddsb';    instbyte:$ec;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1194),
  (nam:'paddsw';    instbyte:$ed;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1195),
  (nam:'pmaxsw';    instbyte:$ee;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1196),
  (nam:'pxor';      instbyte:$ef;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1197),
  (nam:'psllw';     instbyte:$f1;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1198),
  (nam:'pslld';     instbyte:$f2;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1199),
  (nam:'psllq';     instbyte:$f3;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1200),
  (nam:'pmaddwd';   instbyte:$f5;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1201),
  (nam:'psadbw';    instbyte:$f6;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1202),
  (nam:'maskmovq';  instbyte:$f7;cpu:PROC_FROMPENTIUM2; flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1203),
  (nam:'psubb';     instbyte:$f8;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1204),
  (nam:'psubw';     instbyte:$f9;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1205),
  (nam:'psubd';     instbyte:$fa;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1206),
  (nam:'paddb';     instbyte:$fc;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1207),
  (nam:'paddw';     instbyte:$fd;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1208),
  (nam:'paddd';     instbyte:$fe;cpu:PROC_FROMPENTMMX;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MREG; arg2:ARG_MMXMODRM;arg3:ARG_NONE;uniq:1209),
  (nam:nil;         instbyte:$00;cpu:0;                 flags:0;
   arg1:ARG_NONE; arg2:ARG_NONE;arg3:ARG_NONE;uniq:0));  //end marker - processor=0 & opcode=0

// subtable 0x80
// - num is encoding of modrm bits 5,4,3 only
  _asm86sub80:array[0..8] of tasminstdata=(
  (nam:'add';       instbyte:$0;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:2000),
  (nam:'or';        instbyte:$1;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:2001),
  (nam:'adc';       instbyte:$2;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:2002),
  (nam:'sbb';       instbyte:$3;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:2003),
  (nam:'and';       instbyte:$4;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:2004),
  (nam:'sub';       instbyte:$5;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:2005),
  (nam:'xor';       instbyte:$6;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:2006),
  (nam:'cmp';       instbyte:$7;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:2007),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0x81
// - num is encoding of modrm bits 5,4,3 only
  _asm86sub81:array[0..16] of tasminstdata=(
  (nam:'add';       instbyte:$0;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM;arg3:ARG_NONE;uniq:3000),
  (nam:'add';       instbyte:$0;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM;arg3:ARG_NONE;uniq:3001),
  (nam:'or';        instbyte:$1;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM;arg3:ARG_NONE;uniq:3002),
  (nam:'or';        instbyte:$1;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM;arg3:ARG_NONE;uniq:3003),
  (nam:'adc';       instbyte:$2;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM;arg3:ARG_NONE;uniq:3004),
  (nam:'adc';       instbyte:$2;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM;arg3:ARG_NONE;uniq:3005),
  (nam:'sbb';       instbyte:$3;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM;arg3:ARG_NONE;uniq:3006),
  (nam:'sbb';       instbyte:$3;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM;arg3:ARG_NONE;uniq:3007),
  (nam:'and';       instbyte:$4;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM;arg3:ARG_NONE;uniq:3008),
  (nam:'and';       instbyte:$4;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM;arg3:ARG_NONE;uniq:3009),
  (nam:'sub';       instbyte:$5;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM;arg3:ARG_NONE;uniq:3010),
  (nam:'sub';       instbyte:$5;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM;arg3:ARG_NONE;uniq:3011),
  (nam:'xor';       instbyte:$6;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM;arg3:ARG_NONE;uniq:3012),
  (nam:'xor';       instbyte:$6;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM;arg3:ARG_NONE;uniq:3013),
  (nam:'cmp';       instbyte:$7;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM;arg3:ARG_NONE;uniq:3014),
  (nam:'cmp';       instbyte:$7;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM;arg3:ARG_NONE;uniq:3016),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:0));

// subtable 0x82
// - num is encoding of modrm bits 5,4,3 only
  _asm86sub82:array[0..8] of tasminstdata=(
  (nam:'add';       instbyte:$0;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:4000),
  (nam:'or';        instbyte:$1;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:4001),
  (nam:'adc';       instbyte:$2;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:4002),
  (nam:'sbb';       instbyte:$3;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:4003),
  (nam:'and';       instbyte:$4;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:4004),
  (nam:'sub';       instbyte:$5;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:4005),
  (nam:'xor';       instbyte:$6;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:4006),
  (nam:'cmp';       instbyte:$7;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:4007),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0x83
// - num is encoding of modrm bits 5,4,3 only
  _asm86sub83:array[0..16] of tasminstdata=(
  (nam:'add';       instbyte:$0;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:5000),
  (nam:'add';       instbyte:$0;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:5001),
  (nam:'or';        instbyte:$1;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:5002),
  (nam:'or';        instbyte:$1;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:5003),
  (nam:'adc';       instbyte:$2;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:5004),
  (nam:'adc';       instbyte:$2;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:5005),
  (nam:'sbb';       instbyte:$3;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:5006),
  (nam:'sbb';       instbyte:$3;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:5007),
  (nam:'and';       instbyte:$4;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:5008),
  (nam:'and';       instbyte:$4;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:5009),
  (nam:'sub';       instbyte:$5;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:5010),
  (nam:'sub';       instbyte:$5;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:5011),
  (nam:'xor';       instbyte:$6;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:5012),
  (nam:'xor';       instbyte:$6;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:5013),
  (nam:'cmp';       instbyte:$7;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:5014),
  (nam:'cmp';       instbyte:$7;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_SIMM8;arg3:ARG_NONE;uniq:5015),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xc0
// - num is encoding of modrm bits 5,4,3 only
  _asm86subc0:array[0..8] of tasminstdata=(
  (nam:'rol';       instbyte:$0;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:6000),
  (nam:'ror';       instbyte:$1;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:6001),
  (nam:'rcl';       instbyte:$2;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:6002),
  (nam:'rcr';       instbyte:$3;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:6003),
  (nam:'shl';       instbyte:$4;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:6004),
  (nam:'shr';       instbyte:$5;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:6005),
  (nam:'sal';       instbyte:$6;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:6006),
  (nam:'sar';       instbyte:$7;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:6007),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xc1
// - num is encoding of modrm bits 5,4,3 only
  _asm86subc1:array[0..16] of tasminstdata=(
  (nam:'rol';       instbyte:$0;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:7000),
  (nam:'rol';       instbyte:$0;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:7001),
  (nam:'ror';       instbyte:$1;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:7002),
  (nam:'ror';       instbyte:$1;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:7003),
  (nam:'rcl';       instbyte:$2;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:7004),
  (nam:'rcl';       instbyte:$2;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:7005),
  (nam:'rcr';       instbyte:$3;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:7006),
  (nam:'rcr';       instbyte:$3;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:7007),
  (nam:'shl';       instbyte:$4;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:7008),
  (nam:'shl';       instbyte:$4;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:7009),
  (nam:'shr';       instbyte:$5;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:7010),
  (nam:'shr';       instbyte:$5;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:7011),
  (nam:'sal';       instbyte:$6;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:7012),
  (nam:'sal';       instbyte:$6;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:7013),
  (nam:'sar';       instbyte:$7;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:7014),
  (nam:'sar';       instbyte:$7;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:7015),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xd0
// - num is encoding of modrm bits 5,4,3 only
  _asm86subd0:array[0..8] of tasminstdata=(
  (nam:'rol';       instbyte:$0;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:8000),
  (nam:'ror';       instbyte:$1;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:8001),
  (nam:'rcl';       instbyte:$2;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:8002),
  (nam:'rcr';       instbyte:$3;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:8003),
  (nam:'shl';       instbyte:$4;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:8004),
  (nam:'shr';       instbyte:$5;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:8005),
  (nam:'sal';       instbyte:$6;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:8006),
  (nam:'sar';       instbyte:$7;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:8007),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xd1
// - num is encoding of modrm bits 5,4,3 only
  _asm86subd1:array[0..16] of tasminstdata=(
  (nam:'rol';       instbyte:$0;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:9000),
  (nam:'rol';       instbyte:$0;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:9001),
  (nam:'ror';       instbyte:$1;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:9002),
  (nam:'ror';       instbyte:$1;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:9003),
  (nam:'rcl';       instbyte:$2;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:9004),
  (nam:'rcl';       instbyte:$2;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:9005),
  (nam:'rcr';       instbyte:$3;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:9006),
  (nam:'rcr';       instbyte:$3;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:9007),
  (nam:'shl';       instbyte:$4;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:9008),
  (nam:'shl';       instbyte:$4;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:9009),
  (nam:'shr';       instbyte:$5;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:9010),
  (nam:'shr';       instbyte:$5;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:9011),
  (nam:'sal';       instbyte:$6;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:9012),
  (nam:'sal';       instbyte:$6;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:9013),
  (nam:'sar';       instbyte:$7;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:9014),
  (nam:'sar';       instbyte:$7;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM_1;arg3:ARG_NONE;uniq:9015),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xd2
// - num is encoding of modrm bits 5,4,3 only
  _asm86subd2:array[0..8] of tasminstdata=(
  (nam:'rol';       instbyte:$0;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:10000),
  (nam:'ror';       instbyte:$1;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:10001),
  (nam:'rcl';       instbyte:$2;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:10002),
  (nam:'rcr';       instbyte:$3;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:10003),
  (nam:'shl';       instbyte:$4;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:10004),
  (nam:'shr';       instbyte:$5;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:10005),
  (nam:'sal';       instbyte:$6;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:10006),
  (nam:'sar';       instbyte:$7;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:10007),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xd3
// - num is encoding of modrm bits 5,4,3 only
  _asm86subd3:array[0..16] of tasminstdata=(
  (nam:'rol';       instbyte:$0;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:11000),
  (nam:'rol';       instbyte:$0;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:11001),
  (nam:'ror';       instbyte:$1;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:11002),
  (nam:'ror';       instbyte:$1;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:11003),
  (nam:'rcl';       instbyte:$2;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:11004),
  (nam:'rcl';       instbyte:$2;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:11005),
  (nam:'rcr';       instbyte:$3;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:11006),
  (nam:'rcr';       instbyte:$3;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:11007),
  (nam:'shl';       instbyte:$4;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:11008),
  (nam:'shl';       instbyte:$4;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:11009),
  (nam:'shr';       instbyte:$5;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:11010),
  (nam:'shr';       instbyte:$5;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:11011),
  (nam:'sal';       instbyte:$6;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:11012),
  (nam:'sal';       instbyte:$6;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:11013),
  (nam:'sar';       instbyte:$7;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:11014),
  (nam:'sar';       instbyte:$7;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_REG_CL;arg3:ARG_NONE;uniq:11015),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xf6
// - num is encoding of modrm bits 5,4,3 only
  _asm86subf6:array[0..8] of tasminstdata=(
  (nam:'test';      instbyte:$0;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:12000),
  (nam:'test';      instbyte:$1;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:12001),
  (nam:'not';       instbyte:$2;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:12002),
  (nam:'neg';       instbyte:$3;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:12003),
  (nam:'mul';       instbyte:$4;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:12004),
  (nam:'imul';      instbyte:$5;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:12005),
  (nam:'div';       instbyte:$6;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:12006),
  (nam:'idiv';      instbyte:$7;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:12007),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xf7
// - num is encoding of modrm bits 5,4,3 only
  _asm86subf7:array[0..16] of tasminstdata=(
  (nam:'test';      instbyte:$0;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM;arg3:ARG_NONE;uniq:13000),
  (nam:'test';      instbyte:$0;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM;arg3:ARG_NONE;uniq:13001),
  (nam:'test';      instbyte:$1;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_IMM;arg3:ARG_NONE;uniq:13002),
  (nam:'test';      instbyte:$1;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_IMM;arg3:ARG_NONE;uniq:13003),
  (nam:'not';       instbyte:$2;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:13004),
  (nam:'not';       instbyte:$2;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:13005),
  (nam:'neg';       instbyte:$3;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:13006),
  (nam:'neg';       instbyte:$3;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:13007),
  (nam:'mul';       instbyte:$4;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:13008),
  (nam:'mul';       instbyte:$4;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:13009),
  (nam:'imul';      instbyte:$5;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:13010),
  (nam:'imul';      instbyte:$5;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:13011),
  (nam:'div';       instbyte:$6;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:13012),
  (nam:'div';       instbyte:$6;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:13013),
  (nam:'idiv';      instbyte:$7;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:13014),
  (nam:'idiv';      instbyte:$7;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:13015),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xfe
// - num is encoding of modrm bits 5,4,3 only
  _asm86subfe:array[0..2] of tasminstdata=(
  (nam:'inc';       instbyte:$0;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:14000),
  (nam:'dec';       instbyte:$1;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_8BIT;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:14001),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xff
// - num is encoding of modrm bits 5,4,3 only
  _asm86subff:array[0..14] of tasminstdata=(
  (nam:'inc';       instbyte:$0;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:15000),
  (nam:'inc';       instbyte:$0;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:15001),
  (nam:'dec';       instbyte:$1;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:15002),
  (nam:'dec';       instbyte:$1;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:15003),
  (nam:'call';      instbyte:$2;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16 or FLAGS_CALL;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:15004),
  (nam:'call';      instbyte:$2;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32 or FLAGS_CALL;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:15005),
  (nam:'call';      instbyte:$3;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16 or FLAGS_CALL;
   arg1:ARG_MODRM_FPTR;arg2:ARG_NONE;arg3:ARG_NONE;uniq:15006),
  (nam:'call';      instbyte:$3;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32 or FLAGS_CALL;
   arg1:ARG_MODRM_FPTR;arg2:ARG_NONE;arg3:ARG_NONE;uniq:15007),
  (nam:'jmp';       instbyte:$4;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16 or FLAGS_JMP;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:15008),
  (nam:'jmp';       instbyte:$4;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32 or FLAGS_JMP;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:15009),
  (nam:'jmp';       instbyte:$5;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16 or FLAGS_JMP;
   arg1:ARG_MODRM_FPTR;arg2:ARG_NONE;arg3:ARG_NONE;uniq:15010),
  (nam:'jmp';       instbyte:$5;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32 or FLAGS_JMP;
   arg1:ARG_MODRM_FPTR;arg2:ARG_NONE;arg3:ARG_NONE;uniq:15011),
  (nam:'push';      instbyte:$6;cpu:PROC_FROM8086;      flags:FLAGS_MODRM or FLAGS_OMODE16;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:15012),
  (nam:'push';      instbyte:$6;cpu:PROC_FROM80386;     flags:FLAGS_MODRM or FLAGS_OMODE32;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:15013),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0x0f/0x00
// - num is encoding of modrm bits 5,4,3 only
  _asm86sub0f00:array[0..6] of tasminstdata=(
  (nam:'sldt';      instbyte:$0;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_16BIT;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:16000),
  (nam:'str';       instbyte:$1;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_16BIT;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:16001),
  (nam:'lldt';      instbyte:$2;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_16BIT;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:16002),
  (nam:'ltr';       instbyte:$3;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_16BIT;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:16003),
  (nam:'verr';      instbyte:$4;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_16BIT;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:16004),
  (nam:'verw';      instbyte:$5;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_16BIT;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:16005),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0x0f/0x01
// - num is encoding of modrm bits 5,4,3 only
  _asm86sub0f01:array[0..7] of tasminstdata=(
  (nam:'sgdt';      instbyte:$0;cpu:PROC_FROM80286;     flags:FLAGS_MODRM;
   arg1:ARG_MODRM_S;arg2:ARG_NONE;arg3:ARG_NONE;uniq:17000),
  (nam:'sidt';      instbyte:$1;cpu:PROC_FROM80286;     flags:FLAGS_MODRM;
   arg1:ARG_MODRM_S;arg2:ARG_NONE;arg3:ARG_NONE;uniq:17001),
  (nam:'lgdt';      instbyte:$2;cpu:PROC_FROM80286;     flags:FLAGS_MODRM;
   arg1:ARG_MODRM_S;arg2:ARG_NONE;arg3:ARG_NONE;uniq:17002),
  (nam:'lidt';      instbyte:$3;cpu:PROC_FROM80286;     flags:FLAGS_MODRM;
   arg1:ARG_MODRM_S;arg2:ARG_NONE;arg3:ARG_NONE;uniq:17003),
  (nam:'smsw';      instbyte:$4;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_16BIT;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:17004),
  (nam:'lmsw';      instbyte:$6;cpu:PROC_FROM80286;     flags:FLAGS_MODRM or FLAGS_16BIT;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:17005),
  (nam:'invlpg';    instbyte:$7;cpu:PROC_FROM80486;     flags:FLAGS_MODRM or FLAGS_16BIT;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:17006),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0x0f/0x18
// - num is encoding of modrm bits 5,4,3 only
  _asm86sub0f18:array[0..4] of tasminstdata=(
  (nam:'prefetchnta';       instbyte:$0;cpu:PROC_FROMPENTIUM2;  flags:FLAGS_MODRM;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:18000),
  (nam:'prefetcht0';        instbyte:$1;cpu:PROC_FROMPENTIUM2;  flags:FLAGS_MODRM;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:18001),
  (nam:'prefetcht1';        instbyte:$2;cpu:PROC_FROMPENTIUM2;  flags:FLAGS_MODRM;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:18002),
  (nam:'prefetcht2';        instbyte:$3;cpu:PROC_FROMPENTIUM2;  flags:FLAGS_MODRM;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:18003),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0x0f/0x71
// - num is encoding of modrm bits 5,4,3 only
  _asm86sub0f71:array[0..3] of tasminstdata=(
  (nam:'psrlw';     instbyte:$2;cpu:PROC_FROMPENTMMX;   flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MMXMODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:19000),
  (nam:'psraw';     instbyte:$4;cpu:PROC_FROMPENTMMX;   flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MMXMODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:19001),
  (nam:'psllw';     instbyte:$6;cpu:PROC_FROMPENTMMX;   flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MMXMODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:19002),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0x0f/0x72
// - num is encoding of modrm bits 5,4,3 only
  _asm86sub0f72:array[0..3] of tasminstdata=(
  (nam:'psrld';     instbyte:$2;cpu:PROC_FROMPENTMMX;   flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MMXMODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:20000),
  (nam:'psrad';     instbyte:$4;cpu:PROC_FROMPENTMMX;   flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MMXMODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:20001),
  (nam:'pslld';     instbyte:$6;cpu:PROC_FROMPENTMMX;   flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MMXMODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:20002),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0x0f/0x73
// - num is encoding of modrm bits 5,4,3 only
  _asm86sub0f73:array[0..2] of tasminstdata=(
  (nam:'psrlq';     instbyte:$2;cpu:PROC_FROMPENTMMX;   flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MMXMODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:21000),
  (nam:'psllq';     instbyte:$6;cpu:PROC_FROMPENTMMX;   flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MMXMODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:21001),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0x0f/0xae
// - num is encoding of modrm bits 5,4,3 only
  _asm86sub0fae:array[0..5] of tasminstdata=(
  (nam:'fxsave';    instbyte:$0;cpu:PROC_FROMPENTMMX;   flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MODRMM512;arg2:ARG_NONE;arg3:ARG_NONE;uniq:22000),
  (nam:'fxrstor';   instbyte:$1;cpu:PROC_FROMPENTMMX;   flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MODRMM512;arg2:ARG_NONE;arg3:ARG_NONE;uniq:22001),
  (nam:'ldmxcsr';   instbyte:$2;cpu:PROC_FROMPENTIUM2;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:22002),
  (nam:'stmxcsr';   instbyte:$3;cpu:PROC_FROMPENTIUM2;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_MODRM;arg2:ARG_NONE;arg3:ARG_NONE;uniq:22003),
  (nam:'sfence';    instbyte:$7;cpu:PROC_FROMPENTIUM2;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_NONEBYTE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:22004),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0x0f/0xba
// - num is encoding of modrm bits 5,4,3 only
  _asm86sub0fba:array[0..4] of tasminstdata=(
  (nam:'bt';        instbyte:$4;cpu:PROC_FROM80386;     flags:FLAGS_MODRM;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:23000),
  (nam:'bts';       instbyte:$5;cpu:PROC_FROM80386;     flags:FLAGS_MODRM;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:23001),
  (nam:'btr';       instbyte:$6;cpu:PROC_FROM80386;     flags:FLAGS_MODRM;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:23002),
  (nam:'btc';       instbyte:$7;cpu:PROC_FROM80386;     flags:FLAGS_MODRM;
   arg1:ARG_MODRM;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:23003),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0x0f/0xc2
// -num is the follow up byte
  _asm86sub0fc2:array[0..8] of tasminstdata=(
  (nam:'cmpeqps';   instbyte:$0;cpu:PROC_FROMPENTIUM2;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG;arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:24000),
  (nam:'cmpltps';   instbyte:$1;cpu:PROC_FROMPENTIUM2;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG;arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:24001),
  (nam:'cmpleps';   instbyte:$2;cpu:PROC_FROMPENTIUM2;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG;arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:24002),
  (nam:'cmpunordps';instbyte:$3;cpu:PROC_FROMPENTIUM2;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG;arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:24003),
  (nam:'cmpneqps';  instbyte:$4;cpu:PROC_FROMPENTIUM2;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG;arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:24004),
  (nam:'cmpnltps';  instbyte:$5;cpu:PROC_FROMPENTIUM2;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG;arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:24005),
  (nam:'cmpnleps';  instbyte:$6;cpu:PROC_FROMPENTIUM2;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG;arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:24006),
  (nam:'cmpordps';  instbyte:$7;cpu:PROC_FROMPENTIUM2;  flags:FLAGS_MODRM or FLAGS_32BIT;
   arg1:ARG_XREG;arg2:ARG_XMMMODRM;arg3:ARG_NONE;uniq:24007),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0x0f/0xc7
// - num is encoding of modrm bits 5,4,3 only
  _asm86sub0fc7:array[0..1] of tasminstdata=(
  (nam:'cmpxch8b';  instbyte:$1;cpu:PROC_FROMPENTIUM;   flags:FLAGS_MODRM;
   arg1:ARG_MODRMQ;arg2:ARG_NONE;arg3:ARG_NONE;uniq:25000),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// FPU Instructions

// subtable 0xd8/ modrm = 0x00-0xbf
// - num is encoding of modrm bits 5,4,3 only
  _asm86subd8a:array[0..8] of tasminstdata=(
  (nam:'fadd';      instbyte:$0;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_SREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:26000),
  (nam:'fmul';      instbyte:$1;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_SREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:26001),
  (nam:'fcom';      instbyte:$2;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_SREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:26002),
  (nam:'fcomp';     instbyte:$3;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_SREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:26003),
  (nam:'fsub';      instbyte:$4;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_SREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:26004),
  (nam:'fsubr';     instbyte:$5;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_SREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:26005),
  (nam:'fdiv';      instbyte:$6;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_SREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:26006),
  (nam:'fdivr';     instbyte:$7;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_SREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:26007),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xd8/ modrm = 0xc0-0xff
// - num is mod bits 7,6 only + bits 5,4,3 (ie modrm/8)
  _asm86subd8b:array[0..8] of tasminstdata=(
  (nam:'fadd';      instbyte:$18;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_REG_ST0;arg2:ARG_FREG;arg3:ARG_NONE;uniq:27000),
  (nam:'fmul';      instbyte:$19;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_REG_ST0;arg2:ARG_FREG;arg3:ARG_NONE;uniq:27001),
  (nam:'fcom';      instbyte:$1a;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_REG_ST0;arg2:ARG_FREG;arg3:ARG_NONE;uniq:27002),
  (nam:'fcomp';     instbyte:$1b;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_REG_ST0;arg2:ARG_FREG;arg3:ARG_NONE;uniq:27003),
  (nam:'fsub';      instbyte:$1c;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_REG_ST0;arg2:ARG_FREG;arg3:ARG_NONE;uniq:27004),
  (nam:'fsubr';     instbyte:$1d;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_REG_ST0;arg2:ARG_FREG;arg3:ARG_NONE;uniq:27005),
  (nam:'fdiv';      instbyte:$1e;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_REG_ST0;arg2:ARG_FREG;arg3:ARG_NONE;uniq:27006),
  (nam:'fdivr';     instbyte:$1f;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_REG_ST0;arg2:ARG_FREG;arg3:ARG_NONE;uniq:27007),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xd9/modrm = 0x00-0xbf
// - num is encoding of modrm bits 5,4,3 only
  _asm86subd9a:array[0..7] of tasminstdata=(
  (nam:'fld';       instbyte:$0;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_SREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:28000),
  (nam:'fst';       instbyte:$2;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_SREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:28001),
  (nam:'fstp';      instbyte:$3;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_SREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:28002),
  (nam:'fldenv';    instbyte:$4;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_PTR;arg2:ARG_NONE;arg3:ARG_NONE;uniq:28003),
  (nam:'fldcw';     instbyte:$5;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_WORD;arg2:ARG_NONE;arg3:ARG_NONE;uniq:28004),
  (nam:'fstenv';    instbyte:$6;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_PTR;arg2:ARG_NONE;arg3:ARG_NONE;uniq:28005),
  (nam:'fstcw';     instbyte:$7;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_WORD;arg2:ARG_NONE;arg3:ARG_NONE;uniq:28006),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xd9/ modrm = 0xc0-0xcf
// - num is mod bits 7,6 only + bits 5,4,3 (ie modrm/8)
  _asm86subd9b:array[0..2] of tasminstdata=(
  (nam:'fld';       instbyte:$18;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_NONE;arg3:ARG_NONE;uniq:29000),
  (nam:'fxch';      instbyte:$19;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_NONE;arg3:ARG_NONE;uniq:29001),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xd9/ modrm = 0xd0-0xff
  _asm86subd9c:array[0..28] of tasminstdata=(
  (nam:'fnop';      instbyte:$d0;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30000),
  (nam:'fchs';      instbyte:$e0;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30001),
  (nam:'fabs';      instbyte:$e1;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30002),
  (nam:'ftst';      instbyte:$e4;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30003),
  (nam:'fxam';      instbyte:$e5;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30004),
  (nam:'fld1';      instbyte:$e8;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30005),
  (nam:'fldl2t';    instbyte:$e9;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30006),
  (nam:'fldl2e';    instbyte:$ea;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30007),
  (nam:'fldpi';     instbyte:$eb;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30008),
  (nam:'fldlg2';    instbyte:$ec;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30009),
  (nam:'fldln2';    instbyte:$ed;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30010),
  (nam:'fldz';      instbyte:$ee;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30011),
  (nam:'f2xm1';     instbyte:$f0;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30012),
  (nam:'fyl2x';     instbyte:$f1;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30013),
  (nam:'fptan';     instbyte:$f2;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30014),
  (nam:'fpatan';    instbyte:$f3;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30015),
  (nam:'fxtract';   instbyte:$f4;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30016),
  (nam:'fprem1';    instbyte:$f5;cpu:PROC_FROM80386;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30017),
  (nam:'fdecstp';   instbyte:$f6;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30018),
  (nam:'fincstp';   instbyte:$f7;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30019),
  (nam:'fprem';     instbyte:$f8;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30020),
  (nam:'fyl2xp1';   instbyte:$f9;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30021),
  (nam:'fsqrt';     instbyte:$fa;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30022),
  (nam:'fsincos';   instbyte:$fb;cpu:PROC_FROM80386;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30023),
  (nam:'frndint';   instbyte:$fc;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30024),
  (nam:'fscale';    instbyte:$fd;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30025),
  (nam:'fsin';      instbyte:$fe;cpu:PROC_FROM80386;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30026),
  (nam:'fcos';      instbyte:$ff;cpu:PROC_FROM80386;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:30027),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xda/ modrm = 0x00-0xbf
// - num is encoding of modrm bits 5,4,3 only
  _asm86subdaa:array[0..8] of tasminstdata=(
  (nam:'fiadd';     instbyte:$0;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_SINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:31000),
  (nam:'fimul';     instbyte:$1;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_SINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:31001),
  (nam:'ficom';     instbyte:$2;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_SINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:31002),
  (nam:'ficomp';    instbyte:$3;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_SINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:31003),
  (nam:'fisub';     instbyte:$4;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_SINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:31004),
  (nam:'fisubr';    instbyte:$5;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_SINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:31005),
  (nam:'fidiv';     instbyte:$6;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_SINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:31006),
  (nam:'fidivr';    instbyte:$7;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_SINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:31007),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xda/ modrm = 0xc0-0xdf
// - num is mod bits 7,6 only + bits 5,4,3 (ie modrm/8)
  _asm86subdab:array[0..4] of tasminstdata=(
  (nam:'fmovb';     instbyte:$18;cpu:PROC_FROMPENTPRO;flags:0;
   arg1:ARG_REG_ST0;arg2:ARG_FREG;arg3:ARG_NONE;uniq:32000),
  (nam:'fmove';     instbyte:$19;cpu:PROC_FROMPENTPRO;flags:0;
   arg1:ARG_REG_ST0;arg2:ARG_FREG;arg3:ARG_NONE;uniq:32001),
  (nam:'fmovbe';    instbyte:$1a;cpu:PROC_FROMPENTPRO;flags:0;
   arg1:ARG_REG_ST0;arg2:ARG_FREG;arg3:ARG_NONE;uniq:32002),
  (nam:'fmovu';     instbyte:$1b;cpu:PROC_FROMPENTPRO;flags:0;
   arg1:ARG_REG_ST0;arg2:ARG_FREG;arg3:ARG_NONE;uniq:32003),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xda/ modrm = 0xe0-0xff
  _asm86subdac:array[0..1] of tasminstdata=(
  (nam:'fucompp';   instbyte:$e9;cpu:PROC_FROM80386;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:33000),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xdb/modrm = 0x00-0xbf
// - num is encoding of modrm bits 5,4,3 only
  _asm86subdba:array[0..5] of tasminstdata=(
  (nam:'fild';      instbyte:$0;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_SINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:34000),
  (nam:'fist';      instbyte:$2;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_SINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:34001),
  (nam:'fistp';     instbyte:$3;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_SINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:34002),
  (nam:'fld';       instbyte:$5;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_EREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:34003),
  (nam:'fstp';      instbyte:$7;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_EREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:34004),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xdb/ modrm = 0xc0-0xff
// - num is mod bits 7,6 only + bits 5,4,3 (ie modrm/8)
  _asm86subdbb:array[0..6] of tasminstdata=(
  (nam:'fcmovnb';   instbyte:$18;cpu:PROC_FROMPENTPRO;flags:0;
   arg1:ARG_REG_ST0;arg2:ARG_FREG;arg3:ARG_NONE;uniq:35000),
  (nam:'fcmovne';   instbyte:$19;cpu:PROC_FROMPENTPRO;flags:0;
   arg1:ARG_REG_ST0;arg2:ARG_FREG;arg3:ARG_NONE;uniq:35001),
  (nam:'fcmovnbe';  instbyte:$1a;cpu:PROC_FROMPENTPRO;flags:0;
   arg1:ARG_REG_ST0;arg2:ARG_FREG;arg3:ARG_NONE;uniq:35002),
  (nam:'fcmovnu';   instbyte:$1b;cpu:PROC_FROMPENTPRO;flags:0;
   arg1:ARG_REG_ST0;arg2:ARG_FREG;arg3:ARG_NONE;uniq:35003),
  (nam:'fucomi';    instbyte:$1d;cpu:PROC_FROMPENTPRO;flags:0;
   arg1:ARG_REG_ST0;arg2:ARG_FREG;arg3:ARG_NONE;uniq:35004),
  (nam:'fcomi';     instbyte:$1e;cpu:PROC_FROMPENTPRO;flags:0;
   arg1:ARG_REG_ST0;arg2:ARG_FREG;arg3:ARG_NONE;uniq:35005),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xdb/ modrm = 0xe0-0xff
  _asm86subdbc:array[0..7] of tasminstdata=(
  (nam:'feni';      instbyte:$e0;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:36000),
  (nam:'fdisi';     instbyte:$e1;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:36001),
  (nam:'fclex';     instbyte:$e2;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:36002),
  (nam:'finit';     instbyte:$e3;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:36003),
  (nam:'fsetpm';    instbyte:$e4;cpu:PROC_FROM80286;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:36004),
  (nam:'frstpm';    instbyte:$e5;cpu:PROC_FROM80286;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:36005),
  (nam:'frint2';    instbyte:$ec;cpu:PROC_FROM80386;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:36006),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xdc/ modrm = 0x00-0xbf
// - num is encoding of modrm bits 5,4,3 only
  _asm86subdca:array[0..8] of tasminstdata=(
  (nam:'fadd';      instbyte:$0;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_DREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:37000),
  (nam:'fmul';      instbyte:$1;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_DREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:37001),
  (nam:'fcom';      instbyte:$2;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_DREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:37002),
  (nam:'fcomp';     instbyte:$3;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_DREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:37003),
  (nam:'fsub';      instbyte:$4;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_DREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:37004),
  (nam:'fsubr';     instbyte:$5;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_DREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:37005),
  (nam:'fdiv';      instbyte:$6;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_DREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:37006),
  (nam:'fdivr';     instbyte:$7;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_DREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:37007),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xdc/ modrm = 0xc0-0xff
// - num is mod bits 7,6 only + bits 5,4,3 (ie modrm/8)
  _asm86subdcb:array[0..8] of tasminstdata=(
  (nam:'fadd';      instbyte:$18;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_REG_ST0;arg3:ARG_NONE;uniq:38000),
  (nam:'fmul';      instbyte:$19;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_REG_ST0;arg3:ARG_NONE;uniq:38001),
  (nam:'fcom2';     instbyte:$1a;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_REG_ST0;arg3:ARG_NONE;uniq:38002),
  (nam:'fcomp3';    instbyte:$1b;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_REG_ST0;arg3:ARG_NONE;uniq:38003),
  (nam:'fsub';      instbyte:$1c;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_REG_ST0;arg3:ARG_NONE;uniq:38004),
  (nam:'fsubr';     instbyte:$1d;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_REG_ST0;arg3:ARG_NONE;uniq:38005),
  (nam:'fdiv';      instbyte:$1e;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_REG_ST0;arg3:ARG_NONE;uniq:38006),
  (nam:'fdivr';     instbyte:$1f;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_REG_ST0;arg3:ARG_NONE;uniq:38007),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xdd/modrm = 0x00-0xbf
// - num is encoding of modrm bits 5,4,3 only
  _asm86subdda:array[0..6] of tasminstdata=(
  (nam:'fld';       instbyte:$0;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_DREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:39000),
  (nam:'fst';       instbyte:$2;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_DREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:39001),
  (nam:'fstp';      instbyte:$3;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_DREAL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:39002),
  (nam:'frstor';    instbyte:$4;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_PTR;arg2:ARG_NONE;arg3:ARG_NONE;uniq:39003),
  (nam:'fsave';     instbyte:$6;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_PTR;arg2:ARG_NONE;arg3:ARG_NONE;uniq:39004),
  (nam:'fstsw';     instbyte:$7;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_WORD;arg2:ARG_NONE;arg3:ARG_NONE;uniq:39005),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xdd/ modrm = 0xc0-0xff
// - num is mod bits 7,6 only + bits 5,4,3 (ie modrm/8)
  _asm86subddb:array[0..6] of tasminstdata=(
  (nam:'ffree';     instbyte:$18;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_NONE;arg3:ARG_NONE;uniq:40000),
  (nam:'fxch4';     instbyte:$19;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_NONE;arg3:ARG_NONE;uniq:40001),
  (nam:'fst';       instbyte:$1a;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_NONE;arg3:ARG_NONE;uniq:40002),
  (nam:'fstp';      instbyte:$1b;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_NONE;arg3:ARG_NONE;uniq:40003),
  (nam:'fucom';     instbyte:$1c;cpu:PROC_FROM80386;flags:0;
   arg1:ARG_REG_ST0;arg2:ARG_FREG;arg3:ARG_NONE;uniq:40004),
  (nam:'fucomp';    instbyte:$1d;cpu:PROC_FROM80386;flags:0;
   arg1:ARG_FREG;arg2:ARG_NONE;arg3:ARG_NONE;uniq:40005),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xde/ modrm = 0x00-0xbf
// - num is encoding of modrm bits 5,4,3 only
  _asm86subdea:array[0..8] of tasminstdata=(
  (nam:'fiadd';     instbyte:$0;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_WINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:41000),
  (nam:'fimul';     instbyte:$1;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_WINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:41001),
  (nam:'ficom';     instbyte:$2;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_WINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:41002),
  (nam:'ficomp';    instbyte:$3;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_WINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:41003),
  (nam:'fisub';     instbyte:$4;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_WINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:41004),
  (nam:'fisubr';    instbyte:$5;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_WINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:41005),
  (nam:'fidiv';     instbyte:$6;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_WINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:41006),
  (nam:'fidivr';    instbyte:$7;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_WINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:41007),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xde/ modrm = 0xc0-0xdf
// - num is mod bits 7,6 only + bits 5,4,3 (ie modrm/8)
  _asm86subdeb:array[0..7] of tasminstdata=(
  (nam:'faddp';     instbyte:$18;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_REG_ST0;arg3:ARG_NONE;uniq:42000),
  (nam:'fmulp';     instbyte:$19;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_REG_ST0;arg3:ARG_NONE;uniq:42001),
  (nam:'fcomp5';    instbyte:$1a;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_REG_ST0;arg3:ARG_NONE;uniq:42002),
  (nam:'fsubrp';    instbyte:$1c;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_REG_ST0;arg3:ARG_NONE;uniq:42003),
  (nam:'fsubp';     instbyte:$1d;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_REG_ST0;arg3:ARG_NONE;uniq:42004),
  (nam:'fdivrp';    instbyte:$1e;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_REG_ST0;arg3:ARG_NONE;uniq:42005),
  (nam:'fdivp';     instbyte:$1f;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_REG_ST0;arg3:ARG_NONE;uniq:42006),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xde/ modrm = 0xd8-0xdf
  _asm86subdec:array[0..1] of tasminstdata=(
  (nam:'fcompp';    instbyte:$d9;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:43000),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xdf/modrm = 0x00-0xbf
// - num is encoding of modrm bits 5,4,3 only
  _asm86subdfa:array[0..7] of tasminstdata=(
  (nam:'fild';      instbyte:$0;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_WINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:44000),
  (nam:'fist';      instbyte:$2;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_WINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:44001),
  (nam:'fistp';     instbyte:$3;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_WINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:44002),
  (nam:'fbld';      instbyte:$4;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_BCD;arg2:ARG_NONE;arg3:ARG_NONE;uniq:44003),
  (nam:'fild';      instbyte:$5;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_LINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:44004),
  (nam:'fbstp';     instbyte:$6;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_BCD;arg2:ARG_NONE;arg3:ARG_NONE;uniq:44005),
  (nam:'fistp';     instbyte:$7;cpu:PROC_FROM8086;      flags:FLAGS_MODRM;
   arg1:ARG_MODRM_LINT;arg2:ARG_NONE;arg3:ARG_NONE;uniq:44006),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xdf/ modrm = 0xc0-0xff
// - num is mod bits 7,6 only + bits 5,4,3 (ie modrm/8)
  _asm86subdfb:array[0..6] of tasminstdata=(
  (nam:'ffreep';    instbyte:$18;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_NONE;arg3:ARG_NONE;uniq:45000),
  (nam:'fxch7';     instbyte:$19;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_NONE;arg3:ARG_NONE;uniq:45001),
  (nam:'fstp8';     instbyte:$1a;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_NONE;arg3:ARG_NONE;uniq:45002),
  (nam:'fstp9';     instbyte:$1b;cpu:PROC_FROM8086;flags:0;
   arg1:ARG_FREG;arg2:ARG_NONE;arg3:ARG_NONE;uniq:45003),
  (nam:'fucomip';   instbyte:$1d;cpu:PROC_FROMPENTPRO;flags:0;
   arg1:ARG_REG_ST0;arg2:ARG_FREG;arg3:ARG_NONE;uniq:45004),
  (nam:'fcomip';    instbyte:$1e;cpu:PROC_FROMPENTPRO;flags:0;
   arg1:ARG_FREG;arg2:ARG_NONE;arg3:ARG_NONE;uniq:45005),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xdf/ modrm = 0xe0-0xff
  _asm86subdfc:array[0..4] of tasminstdata=(
  (nam:'fstsw';     instbyte:$e0;cpu:PROC_FROM8086;     flags:FLAGS_16BIT;
   arg1:ARG_REG_AX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:46000),
  (nam:'fstdw';     instbyte:$e1;cpu:PROC_FROM80386;flags:0;
   arg1:ARG_REG_AX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:46001),
  (nam:'fstsg';     instbyte:$e2;cpu:PROC_FROM80386;flags:0;
   arg1:ARG_REG_AX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:46002),
  (nam:'frinear';   instbyte:$e2;cpu:PROC_FROM80386;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:46003),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

  _asmz80:array[0..256] of tasminstdata=(
  (nam:'nop';       instbyte:$00;cpu:PROC_Z80;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100000),
  (nam:'ld';        instbyte:$01;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_BC;arg2:ARG_IMM16;arg3:ARG_NONE;uniq:100001),
  (nam:'ld';        instbyte:$02;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_BC_IND;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:100002),
  (nam:'inc';       instbyte:$03;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_BC;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100003),
  (nam:'inc';       instbyte:$04;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_B;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100004),
  (nam:'dec';       instbyte:$05;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_B;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100005),
  (nam:'ld';        instbyte:$06;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_B;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:100006),
  (nam:'rlca';      instbyte:$07;cpu:PROC_Z80;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100007),
  (nam:'ex';        instbyte:$08;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_AF;arg2:ARG_REG_AF2;arg3:ARG_NONE;uniq:100008),
  (nam:'add';       instbyte:$09;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_HL;arg2:ARG_REG_BC;arg3:ARG_NONE;uniq:100009),
  (nam:'ld';        instbyte:$0a;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_A;arg2:ARG_REG_BC_IND;arg3:ARG_NONE;uniq:100010),
  (nam:'dec';       instbyte:$0b;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_BC;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100011),
  (nam:'inc';       instbyte:$0c;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_C;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100012),
  (nam:'dec';       instbyte:$0d;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_C;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100013),
  (nam:'ld';        instbyte:$0e;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_C;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:100014),
  (nam:'rrca';      instbyte:$0f;cpu:PROC_Z80;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100015),
  (nam:'djnz';      instbyte:$10;cpu:PROC_Z80;  flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100016),
  (nam:'ld';        instbyte:$11;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_DE;arg2:ARG_IMM16;arg3:ARG_NONE;uniq:100017),
  (nam:'ld';        instbyte:$12;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_DE_IND;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:100018),
  (nam:'inc';       instbyte:$13;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_DE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100019),
  (nam:'inc';       instbyte:$14;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_D;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100020),
  (nam:'dec';       instbyte:$15;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_D;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100021),
  (nam:'ld';        instbyte:$16;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_D;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:100022),
  (nam:'rla';       instbyte:$17;cpu:PROC_Z80;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100023),
  (nam:'jr';        instbyte:$18;cpu:PROC_Z80;  flags:FLAGS_JMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100024),
  (nam:'add';       instbyte:$19;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_HL;arg2:ARG_REG_DE;arg3:ARG_NONE;uniq:100025),
  (nam:'ld';        instbyte:$1a;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_A;arg2:ARG_REG_DE_IND;arg3:ARG_NONE;uniq:100026),
  (nam:'dec';       instbyte:$1b;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_DE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100027),
  (nam:'inc';       instbyte:$1c;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_E;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100028),
  (nam:'dec';       instbyte:$1d;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_E;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100029),
  (nam:'ld';        instbyte:$1e;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_E;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:100030),
  (nam:'rra';       instbyte:$1f;cpu:PROC_Z80;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100031),
  (nam:'jr nz';     instbyte:$20;cpu:PROC_Z80;  flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100032),
  (nam:'ld';        instbyte:$21;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_HL;arg2:ARG_IMM16;arg3:ARG_NONE;uniq:100033),
  (nam:'ld';        instbyte:$22;cpu:PROC_Z80;flags:0;
   arg1:ARG_MEMLOC16;arg2:ARG_REG_HL;arg3:ARG_NONE;uniq:100034),
  (nam:'inc';       instbyte:$23;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_HL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100035),
  (nam:'inc';       instbyte:$24;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_H;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100036),
  (nam:'dec';       instbyte:$25;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_H;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100037),
  (nam:'ld';        instbyte:$26;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_H;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:100038),
  (nam:'daa';       instbyte:$27;cpu:PROC_Z80;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100039),
  (nam:'jr z';      instbyte:$28;cpu:PROC_Z80;  flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100040),
  (nam:'add';       instbyte:$29;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_HL;arg2:ARG_REG_HL;arg3:ARG_NONE;uniq:100041),
  (nam:'ld';        instbyte:$2a;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_HL;arg2:ARG_MEMLOC16;arg3:ARG_NONE;uniq:100042),
  (nam:'dec';       instbyte:$2b;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_HL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100043),
  (nam:'inc';       instbyte:$2c;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_L;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100044),
  (nam:'dec';       instbyte:$2d;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_L;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100045),
  (nam:'ld';        instbyte:$2e;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_L;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:100046),
  (nam:'cpl';       instbyte:$2f;cpu:PROC_Z80;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100047),
  (nam:'jr nc';     instbyte:$30;cpu:PROC_Z80;  flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100048),
  (nam:'ld';        instbyte:$31;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_SP;arg2:ARG_IMM16;arg3:ARG_NONE;uniq:100049),
  (nam:'ld';        instbyte:$32;cpu:PROC_Z80;flags:0;
   arg1:ARG_MEMLOC16;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:100050),
  (nam:'inc';       instbyte:$33;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_SP;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100051),
  (nam:'inc';       instbyte:$34;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_HL_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100052),
  (nam:'dec';       instbyte:$35;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_HL_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100053),
  (nam:'ld';        instbyte:$36;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_HL_IND;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:100054),
  (nam:'scf';       instbyte:$37;cpu:PROC_Z80;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100055),
  (nam:'jr c';      instbyte:$38;cpu:PROC_Z80;  flags:FLAGS_CJMP;
   arg1:ARG_RELIMM8;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100056),
  (nam:'add';       instbyte:$39;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_HL;arg2:ARG_REG_SP;arg3:ARG_NONE;uniq:100057),
  (nam:'ld';        instbyte:$3a;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_A;arg2:ARG_MEMLOC16;arg3:ARG_NONE;uniq:100058),
  (nam:'dec';       instbyte:$3b;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_SP;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100059),
  (nam:'inc';       instbyte:$3c;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_A;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100060),
  (nam:'dec';       instbyte:$3d;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_A;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100061),
  (nam:'ld';        instbyte:$3e;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_A;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:100062),
  (nam:'ccf';       instbyte:$3f;cpu:PROC_Z80;flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100063),
  (nam:'ld';        instbyte:$40;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_B;arg2:ARG_REG_B;arg3:ARG_NONE;uniq:100064),
  (nam:'ld';        instbyte:$41;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_B;arg2:ARG_REG_C;arg3:ARG_NONE;uniq:100065),
  (nam:'ld';        instbyte:$42;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_B;arg2:ARG_REG_D;arg3:ARG_NONE;uniq:100066),
  (nam:'ld';        instbyte:$43;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_B;arg2:ARG_REG_E;arg3:ARG_NONE;uniq:100067),
  (nam:'ld';        instbyte:$44;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_B;arg2:ARG_REG_H;arg3:ARG_NONE;uniq:100068),
  (nam:'ld';        instbyte:$45;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_B;arg2:ARG_REG_L;arg3:ARG_NONE;uniq:100069),
  (nam:'ld';        instbyte:$46;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_B;arg2:ARG_REG_HL_IND;arg3:ARG_NONE;uniq:100070),
  (nam:'ld';        instbyte:$47;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_B;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:100071),
  (nam:'ld';        instbyte:$48;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_C;arg2:ARG_REG_B;arg3:ARG_NONE;uniq:100072),
  (nam:'ld';        instbyte:$49;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_C;arg2:ARG_REG_C;arg3:ARG_NONE;uniq:100073),
  (nam:'ld';        instbyte:$4a;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_C;arg2:ARG_REG_D;arg3:ARG_NONE;uniq:100074),
  (nam:'ld';        instbyte:$4b;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_C;arg2:ARG_REG_E;arg3:ARG_NONE;uniq:100075),
  (nam:'ld';        instbyte:$4c;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_C;arg2:ARG_REG_H;arg3:ARG_NONE;uniq:100076),
  (nam:'ld';        instbyte:$4d;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_C;arg2:ARG_REG_L;arg3:ARG_NONE;uniq:100077),
  (nam:'ld';        instbyte:$4e;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_C;arg2:ARG_REG_HL_IND;arg3:ARG_NONE;uniq:100078),
  (nam:'ld';        instbyte:$4f;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_C;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:100079),
  (nam:'ld';        instbyte:$50;cpu:PROC_Z80;flags:0;
   arg1:ARG_REG_D;arg2:ARG_REG_B;arg3:ARG_NONE;uniq:100080),
  (nam:'ld';        instbyte:$51;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_D;arg2:ARG_REG_C;arg3:ARG_NONE;uniq:100081),
  (nam:'ld';        instbyte:$52;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_D;arg2:ARG_REG_D;arg3:ARG_NONE;uniq:100082),
  (nam:'ld';        instbyte:$53;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_D;arg2:ARG_REG_E;arg3:ARG_NONE;uniq:100083),
  (nam:'ld';        instbyte:$54;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_D;arg2:ARG_REG_H;arg3:ARG_NONE;uniq:100084),
  (nam:'ld';        instbyte:$55;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_D;arg2:ARG_REG_L;arg3:ARG_NONE;uniq:100085),
  (nam:'ld';        instbyte:$56;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_D;arg2:ARG_REG_HL_IND;arg3:ARG_NONE;uniq:100086),
  (nam:'ld';        instbyte:$57;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_D;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:100087),
  (nam:'ld';        instbyte:$58;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_E;arg2:ARG_REG_B;arg3:ARG_NONE;uniq:100088),
  (nam:'ld';        instbyte:$59;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_E;arg2:ARG_REG_C;arg3:ARG_NONE;uniq:100089),
  (nam:'ld';        instbyte:$5a;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_E;arg2:ARG_REG_D;arg3:ARG_NONE;uniq:100090),
  (nam:'ld';        instbyte:$5b;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_E;arg2:ARG_REG_E;arg3:ARG_NONE;uniq:100091),
  (nam:'ld';        instbyte:$5c;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_E;arg2:ARG_REG_H;arg3:ARG_NONE;uniq:100092),
  (nam:'ld';        instbyte:$5d;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_E;arg2:ARG_REG_L;arg3:ARG_NONE;uniq:100093),
  (nam:'ld';        instbyte:$5e;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_E;arg2:ARG_REG_HL_IND;arg3:ARG_NONE;uniq:100094),
  (nam:'ld';        instbyte:$5f;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_E;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:100095),
  (nam:'ld';        instbyte:$60;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_H;arg2:ARG_REG_B;arg3:ARG_NONE;uniq:100096),
  (nam:'ld';        instbyte:$61;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_H;arg2:ARG_REG_C;arg3:ARG_NONE;uniq:100097),
  (nam:'ld';        instbyte:$62;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_H;arg2:ARG_REG_D;arg3:ARG_NONE;uniq:100098),
  (nam:'ld';        instbyte:$63;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_H;arg2:ARG_REG_E;arg3:ARG_NONE;uniq:100099),
  (nam:'ld';        instbyte:$64;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_H;arg2:ARG_REG_H;arg3:ARG_NONE;uniq:100100),
  (nam:'ld';        instbyte:$65;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_H;arg2:ARG_REG_L;arg3:ARG_NONE;uniq:100101),
  (nam:'ld';        instbyte:$66;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_H;arg2:ARG_REG_HL_IND;arg3:ARG_NONE;uniq:100102),
  (nam:'ld';        instbyte:$67;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_H;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:100103),
  (nam:'ld';        instbyte:$68;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_L;arg2:ARG_REG_B;arg3:ARG_NONE;uniq:100104),
  (nam:'ld';        instbyte:$69;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_L;arg2:ARG_REG_C;arg3:ARG_NONE;uniq:100105),
  (nam:'ld';        instbyte:$6a;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_L;arg2:ARG_REG_D;arg3:ARG_NONE;uniq:100106),
  (nam:'ld';        instbyte:$6b;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_L;arg2:ARG_REG_E;arg3:ARG_NONE;uniq:100107),
  (nam:'ld';        instbyte:$6c;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_L;arg2:ARG_REG_H;arg3:ARG_NONE;uniq:100108),
  (nam:'ld';        instbyte:$6d;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_L;arg2:ARG_REG_L;arg3:ARG_NONE;uniq:100109),
  (nam:'ld';        instbyte:$6e;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_L;arg2:ARG_REG_HL_IND;arg3:ARG_NONE;uniq:100110),
  (nam:'ld';        instbyte:$6f;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_L;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:100111),
  (nam:'ld';        instbyte:$70;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_HL_IND;arg2:ARG_REG_B;arg3:ARG_NONE;uniq:100112),
  (nam:'ld';        instbyte:$71;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_HL_IND;arg2:ARG_REG_C;arg3:ARG_NONE;uniq:100113),
  (nam:'ld';        instbyte:$72;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_HL_IND;arg2:ARG_REG_D;arg3:ARG_NONE;uniq:100114),
  (nam:'ld';        instbyte:$73;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_HL_IND;arg2:ARG_REG_E;arg3:ARG_NONE;uniq:100115),
  (nam:'ld';        instbyte:$74;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_HL_IND;arg2:ARG_REG_H;arg3:ARG_NONE;uniq:100116),
  (nam:'ld';        instbyte:$75;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_HL_IND;arg2:ARG_REG_L;arg3:ARG_NONE;uniq:100117),
  (nam:'halt';      instbyte:$76;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100118),
  (nam:'ld';        instbyte:$77;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_HL_IND;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:100119),
  (nam:'ld';        instbyte:$78;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_B;arg3:ARG_NONE;uniq:100120),
  (nam:'ld';        instbyte:$79;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_C;arg3:ARG_NONE;uniq:100121),
  (nam:'ld';        instbyte:$7a;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_D;arg3:ARG_NONE;uniq:100122),
  (nam:'ld';        instbyte:$7b;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_E;arg3:ARG_NONE;uniq:100123),
  (nam:'ld';        instbyte:$7c;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_H;arg3:ARG_NONE;uniq:100124),
  (nam:'ld';        instbyte:$7d;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_L;arg3:ARG_NONE;uniq:100125),
  (nam:'ld';        instbyte:$7e;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_HL_IND;arg3:ARG_NONE;uniq:100126),
  (nam:'ld';        instbyte:$7f;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:100127),
  (nam:'add';       instbyte:$80;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_B;arg3:ARG_NONE;uniq:100128),
  (nam:'add';       instbyte:$81;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_C;arg3:ARG_NONE;uniq:100129),
  (nam:'add';       instbyte:$82;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_D;arg3:ARG_NONE;uniq:100130),
  (nam:'add';       instbyte:$83;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_E;arg3:ARG_NONE;uniq:100131),
  (nam:'add';       instbyte:$84;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_H;arg3:ARG_NONE;uniq:100132),
  (nam:'add';       instbyte:$85;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_L;arg3:ARG_NONE;uniq:100133),
  (nam:'add';       instbyte:$86;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_HL_IND;arg3:ARG_NONE;uniq:100134),
  (nam:'add';       instbyte:$87;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:100135),
  (nam:'adc';       instbyte:$88;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_B;arg3:ARG_NONE;uniq:100136),
  (nam:'adc';       instbyte:$89;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_C;arg3:ARG_NONE;uniq:100137),
  (nam:'adc';       instbyte:$8a;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_D;arg3:ARG_NONE;uniq:100138),
  (nam:'adc';       instbyte:$8b;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_E;arg3:ARG_NONE;uniq:100139),
  (nam:'adc';       instbyte:$8c;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_H;arg3:ARG_NONE;uniq:100140),
  (nam:'adc';       instbyte:$8d;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_L;arg3:ARG_NONE;uniq:100141),
  (nam:'adc';       instbyte:$8e;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_HL_IND;arg3:ARG_NONE;uniq:100142),
  (nam:'adc';       instbyte:$8f;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:100143),
  (nam:'sub';       instbyte:$90;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_B;arg3:ARG_NONE;uniq:100144),
  (nam:'sub';       instbyte:$91;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_C;arg3:ARG_NONE;uniq:100145),
  (nam:'sub';       instbyte:$92;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_D;arg3:ARG_NONE;uniq:100146),
  (nam:'sub';       instbyte:$93;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_E;arg3:ARG_NONE;uniq:100147),
  (nam:'sub';       instbyte:$94;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_H;arg3:ARG_NONE;uniq:100148),
  (nam:'sub';       instbyte:$95;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_L;arg3:ARG_NONE;uniq:100149),
  (nam:'sub';       instbyte:$96;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_HL_IND;arg3:ARG_NONE;uniq:100150),
  (nam:'sub';       instbyte:$97;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:100151),
  (nam:'sbc';       instbyte:$98;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_B;arg3:ARG_NONE;uniq:100152),
  (nam:'sbc';       instbyte:$99;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_C;arg3:ARG_NONE;uniq:100153),
  (nam:'sbc';       instbyte:$9a;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_D;arg3:ARG_NONE;uniq:100154),
  (nam:'sbc';       instbyte:$9b;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_E;arg3:ARG_NONE;uniq:100155),
  (nam:'sbc';       instbyte:$9c;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_H;arg3:ARG_NONE;uniq:100156),
  (nam:'sbc';       instbyte:$9d;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_L;arg3:ARG_NONE;uniq:100157),
  (nam:'sbc';       instbyte:$9e;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_HL_IND;arg3:ARG_NONE;uniq:100158),
  (nam:'sbc';       instbyte:$9f;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:100159),
  (nam:'and';       instbyte:$a0;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_B;arg3:ARG_NONE;uniq:100160),
  (nam:'and';       instbyte:$a1;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_C;arg3:ARG_NONE;uniq:100161),
  (nam:'and';       instbyte:$a2;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_D;arg3:ARG_NONE;uniq:100162),
  (nam:'and';       instbyte:$a3;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_E;arg3:ARG_NONE;uniq:100163),
  (nam:'and';       instbyte:$a4;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_H;arg3:ARG_NONE;uniq:100164),
  (nam:'and';       instbyte:$a5;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_L;arg3:ARG_NONE;uniq:100165),
  (nam:'and';       instbyte:$a6;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_HL_IND;arg3:ARG_NONE;uniq:100166),
  (nam:'and';       instbyte:$a7;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:100167),
  (nam:'xor';       instbyte:$a8;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_B;arg3:ARG_NONE;uniq:100168),
  (nam:'xor';       instbyte:$a9;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_C;arg3:ARG_NONE;uniq:100169),
  (nam:'xor';       instbyte:$aa;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_D;arg3:ARG_NONE;uniq:100170),
  (nam:'xor';       instbyte:$ab;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_E;arg3:ARG_NONE;uniq:100171),
  (nam:'xor';       instbyte:$ac;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_H;arg3:ARG_NONE;uniq:100172),
  (nam:'xor';       instbyte:$ad;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_L;arg3:ARG_NONE;uniq:100173),
  (nam:'xor';       instbyte:$ae;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_HL_IND;arg3:ARG_NONE;uniq:100174),
  (nam:'xor';       instbyte:$af;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:100175),
  (nam:'or';        instbyte:$b0;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_B;arg3:ARG_NONE;uniq:100176),
  (nam:'or';        instbyte:$b1;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_C;arg3:ARG_NONE;uniq:100177),
  (nam:'or';        instbyte:$b2;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_D;arg3:ARG_NONE;uniq:100178),
  (nam:'or';        instbyte:$b3;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_E;arg3:ARG_NONE;uniq:100179),
  (nam:'or';        instbyte:$b4;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_H;arg3:ARG_NONE;uniq:100180),
  (nam:'or';        instbyte:$b5;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_L;arg3:ARG_NONE;uniq:100181),
  (nam:'or';        instbyte:$b6;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_HL_IND;arg3:ARG_NONE;uniq:100182),
  (nam:'or';        instbyte:$b7;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:100183),
  (nam:'cp';        instbyte:$b8;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_B;arg3:ARG_NONE;uniq:100184),
  (nam:'cp';        instbyte:$b9;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_C;arg3:ARG_NONE;uniq:100185),
  (nam:'cp';        instbyte:$ba;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_D;arg3:ARG_NONE;uniq:100186),
  (nam:'cp';        instbyte:$bb;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_E;arg3:ARG_NONE;uniq:100187),
  (nam:'cp';        instbyte:$bc;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_H;arg3:ARG_NONE;uniq:100188),
  (nam:'cp';        instbyte:$bd;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_L;arg3:ARG_NONE;uniq:100189),
  (nam:'cp';        instbyte:$be;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_HL_IND;arg3:ARG_NONE;uniq:100190),
  (nam:'cp';        instbyte:$bf;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:100191),
  (nam:'ret nz';    instbyte:$c0;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100192),
  (nam:'pop';       instbyte:$c1;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_BC;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100193),
  (nam:'jp nz';     instbyte:$c2;cpu:PROC_Z80;  flags:FLAGS_CJMP;
  arg1:ARG_IMM16;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100194),
  (nam:'jp';        instbyte:$c3;cpu:PROC_Z80;  flags:FLAGS_JMP;
  arg1:ARG_IMM16;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100195),
  (nam:'call nz';   instbyte:$c4;cpu:PROC_Z80;  flags:FLAGS_CALL;
  arg1:ARG_IMM16;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100196),
  (nam:'push';      instbyte:$c5;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_BC;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100197),
  (nam:'add';       instbyte:$c6;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:100198),
  (nam:'rst 00h';   instbyte:$c7;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100199),
  (nam:'ret z';     instbyte:$c8;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100200),
  (nam:'ret';       instbyte:$c9;cpu:PROC_Z80;  flags:FLAGS_RET;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100201),
  (nam:'jp z';      instbyte:$ca;cpu:PROC_Z80;  flags:FLAGS_CJMP;
  arg1:ARG_IMM16;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100202),
  (nam:nil;         instbyte:$cb;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100203), // subtable 0xcb
  (nam:'call z';    instbyte:$cc;cpu:PROC_Z80;  flags:FLAGS_CALL;
  arg1:ARG_IMM16;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100204),
  (nam:'call';      instbyte:$cd;cpu:PROC_Z80;  flags:FLAGS_CALL;
  arg1:ARG_IMM16;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100205),
  (nam:'adc';       instbyte:$ce;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:100206),
  (nam:'rst 08h';   instbyte:$cf;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100207),
  (nam:'ret nc';    instbyte:$d0;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100208),
  (nam:'pop';       instbyte:$d1;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_DE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100209),
  (nam:'jp nc';     instbyte:$d2;cpu:PROC_Z80;  flags:FLAGS_CJMP;
  arg1:ARG_IMM16;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100210),
  (nam:'out';       instbyte:$d3;cpu:PROC_Z80;flags:0;
  arg1:ARG_IMM8_IND;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:100211),
  (nam:'call nc';   instbyte:$d4;cpu:PROC_Z80;  flags:FLAGS_CALL;
  arg1:ARG_IMM16;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100212),
  (nam:'push';      instbyte:$d5;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_DE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100213),
  (nam:'sub';       instbyte:$d6;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:100214),
  (nam:'rst 10h';   instbyte:$d7;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100215),
  (nam:'ret c';     instbyte:$d8;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100216),
  (nam:'exx';       instbyte:$d9;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100217),
  (nam:'jp c';      instbyte:$da;cpu:PROC_Z80;  flags:FLAGS_CJMP;
  arg1:ARG_IMM16;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100218),
  (nam:'in';        instbyte:$db;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_IMM8_IND;arg3:ARG_NONE;uniq:100219),
  (nam:'call c';    instbyte:$dc;cpu:PROC_Z80;  flags:FLAGS_CALL;
  arg1:ARG_IMM16;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100220),
  (nam:nil;         instbyte:$dd;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100221), // subtable 0xdd
  (nam:'sbc';       instbyte:$de;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:100222),
  (nam:'rst 18h';   instbyte:$df;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100223),
  (nam:'ret po';    instbyte:$e0;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100224),
  (nam:'pop';       instbyte:$e1;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_HL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100225),
  (nam:'jp po';     instbyte:$e2;cpu:PROC_Z80;  flags:FLAGS_CJMP;
  arg1:ARG_IMM16;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100226),
  (nam:'ex';        instbyte:$e3;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_SP_IND;arg2:ARG_REG_HL;arg3:ARG_NONE;uniq:100227),
  (nam:'call po';   instbyte:$e4;cpu:PROC_Z80;  flags:FLAGS_CALL;
  arg1:ARG_IMM16;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100228),
  (nam:'push';      instbyte:$e5;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_HL;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100229),
  (nam:'and';       instbyte:$e6;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:100230),
  (nam:'rst 20h';   instbyte:$e7;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100231),
  (nam:'ret pe';    instbyte:$e8;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100232),
  (nam:'jp';        instbyte:$e9;cpu:PROC_Z80;  flags:FLAGS_IJMP;
  arg1:ARG_REG_HL_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100233),
  (nam:'jp pe';     instbyte:$ea;cpu:PROC_Z80;  flags:FLAGS_CJMP;
  arg1:ARG_IMM16;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100234),
  (nam:'ex';        instbyte:$eb;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_DE;arg2:ARG_REG_HL;arg3:ARG_NONE;uniq:100235),
  (nam:'call pe';   instbyte:$ec;cpu:PROC_Z80;  flags:FLAGS_CALL;
  arg1:ARG_IMM16;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100236),
  (nam:nil;         instbyte:$ed;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100237), // subtable 0xed
  (nam:'xor';       instbyte:$ee;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:100238),
  (nam:'rst 28h';   instbyte:$ef;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100239),
  (nam:'ret p';     instbyte:$f0;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100240),
  (nam:'pop';       instbyte:$f1;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_AF;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100241),
  (nam:'jp p';      instbyte:$f2;cpu:PROC_Z80;  flags:FLAGS_CJMP;
  arg1:ARG_IMM16;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100242),
  (nam:'di';        instbyte:$f3;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100243),
  (nam:'call p';    instbyte:$f4;cpu:PROC_Z80;  flags:FLAGS_CALL;
  arg1:ARG_IMM16;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100244),
  (nam:'push';      instbyte:$f5;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_AF;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100245),
  (nam:'or';        instbyte:$f6;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:100246),
  (nam:'rst 30h';   instbyte:$f7;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100247),
  (nam:'ret m';     instbyte:$f8;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100248),
  (nam:'ld';        instbyte:$f9;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_SP;arg2:ARG_REG_HL;arg3:ARG_NONE;uniq:100249),
  (nam:'jp m';      instbyte:$fa;cpu:PROC_Z80;  flags:FLAGS_CJMP;
  arg1:ARG_IMM16;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100250),
  (nam:'ei';        instbyte:$fb;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100251),
  (nam:'call m';    instbyte:$fc;cpu:PROC_Z80;  flags:FLAGS_CALL;
  arg1:ARG_IMM16;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100252),
  (nam:nil;         instbyte:$fd;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100253), // subtable 0xfd
  (nam:'cp';        instbyte:$fe;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:100254),
  (nam:'rst 38h';   instbyte:$ff;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:100255),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// z80 subtable 0xcb
// - num = second byte/8
// - reg = second byte&7
  _asmz80subcba:array[0..7] of tasminstdata=(
  (nam:'rlc';       instbyte:$0;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG;arg2:ARG_NONE;arg3:ARG_NONE;uniq:101000),
  (nam:'rrc';       instbyte:$1;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG;arg2:ARG_NONE;arg3:ARG_NONE;uniq:101001),
  (nam:'rl';        instbyte:$2;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG;arg2:ARG_NONE;arg3:ARG_NONE;uniq:101002),
  (nam:'rr';        instbyte:$3;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG;arg2:ARG_NONE;arg3:ARG_NONE;uniq:101003),
  (nam:'sla';       instbyte:$4;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG;arg2:ARG_NONE;arg3:ARG_NONE;uniq:101004),
  (nam:'sra';       instbyte:$5;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG;arg2:ARG_NONE;arg3:ARG_NONE;uniq:101005),
  (nam:'srl';       instbyte:$7;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG;arg2:ARG_NONE;arg3:ARG_NONE;uniq:101006),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// z80 subtable 0xcb part2
// - num = second byte bits 7,6
// - bit = second byte bits 5,4,3
// - reg = second byte bits 2;uniq:1,0
  _asmz80subcbb:array[0..3] of tasminstdata=(
  (nam:'bit';       instbyte:$1;cpu:PROC_Z80;flags:0;
  arg1:ARG_BIT;arg2:ARG_REG;arg3:ARG_NONE;uniq:102000),
  (nam:'res';       instbyte:$2;cpu:PROC_Z80;flags:0;
  arg1:ARG_BIT;arg2:ARG_REG;arg3:ARG_NONE;uniq:102001),
  (nam:'set';       instbyte:$3;cpu:PROC_Z80;flags:0;
  arg1:ARG_BIT;arg2:ARG_REG;arg3:ARG_NONE;uniq:102002),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// subtable 0xdd
  _asmz80subdd:array[0..40] of tasminstdata=(
  (nam:'add';       instbyte:$09;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_IX;arg2:ARG_REG_BC;arg3:ARG_NONE;uniq:103000),
  (nam:'add';       instbyte:$19;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_IX;arg2:ARG_REG_DE;arg3:ARG_NONE;uniq:103001),
  (nam:'ld';        instbyte:$21;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_IX;arg2:ARG_IMM16;arg3:ARG_NONE;uniq:103002),
  (nam:'ld';        instbyte:$22;cpu:PROC_Z80;flags:0;
  arg1:ARG_MEMLOC16;arg2:ARG_REG_IX;arg3:ARG_NONE;uniq:103003),
  (nam:'inc';       instbyte:$23;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_IX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:103004),
  (nam:'add';       instbyte:$29;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_IX;arg2:ARG_REG_IX;arg3:ARG_NONE;uniq:103005),
  (nam:'ld';        instbyte:$2a;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_IX;arg2:ARG_MEMLOC16;arg3:ARG_NONE;uniq:103006),
  (nam:'dec';       instbyte:$2b;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_IX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:103007),
  (nam:'inc';       instbyte:$34;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IX_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:103008),
  (nam:'dec';       instbyte:$35;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IX_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:103009),
  (nam:'ld';        instbyte:$36;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IX_IND;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:103010),
  (nam:'add';       instbyte:$39;cpu:PROC_Z80;  flags:0;
  arg1:ARG_REG_IX;arg2:ARG_REG_SP;arg3:ARG_NONE;uniq:103011),
  (nam:'ld';        instbyte:$46;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_B;arg2:ARG_REG_IX_IND;arg3:ARG_NONE;uniq:103012),
  (nam:'ld';        instbyte:$4e;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_C;arg2:ARG_REG_IX_IND;arg3:ARG_NONE;uniq:103013),
  (nam:'ld';        instbyte:$56;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_D;arg2:ARG_REG_IX_IND;arg3:ARG_NONE;uniq:103014),
  (nam:'ld';        instbyte:$5e;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_E;arg2:ARG_REG_IX_IND;arg3:ARG_NONE;uniq:103015),
  (nam:'ld';        instbyte:$66;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_H;arg2:ARG_REG_IX_IND;arg3:ARG_NONE;uniq:103016),
  (nam:'ld';        instbyte:$6e;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_L;arg2:ARG_REG_IX_IND;arg3:ARG_NONE;uniq:103017),
  (nam:'ld';        instbyte:$70;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IX_IND;arg2:ARG_REG_B;arg3:ARG_NONE;uniq:103018),
  (nam:'ld';        instbyte:$71;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IX_IND;arg2:ARG_REG_C;arg3:ARG_NONE;uniq:103019),
  (nam:'ld';        instbyte:$72;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IX_IND;arg2:ARG_REG_D;arg3:ARG_NONE;uniq:103020),
  (nam:'ld';        instbyte:$73;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IX_IND;arg2:ARG_REG_E;arg3:ARG_NONE;uniq:103021),
  (nam:'ld';        instbyte:$74;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IX_IND;arg2:ARG_REG_H;arg3:ARG_NONE;uniq:103022),
  (nam:'ld';        instbyte:$75;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IX_IND;arg2:ARG_REG_L;arg3:ARG_NONE;uniq:103023),
  (nam:'ld';        instbyte:$77;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IX_IND;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:103024),
  (nam:'ld';        instbyte:$7e;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_A;arg2:ARG_REG_IX_IND;arg3:ARG_NONE;uniq:103025),
  (nam:'add';       instbyte:$86;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_A;arg2:ARG_REG_IX_IND;arg3:ARG_NONE;uniq:103026),
  (nam:'adc';       instbyte:$8e;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_A;arg2:ARG_REG_IX_IND;arg3:ARG_NONE;uniq:103027),
  (nam:'sub';       instbyte:$96;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_A;arg2:ARG_REG_IX_IND;arg3:ARG_NONE;uniq:103028),
  (nam:'sbc';       instbyte:$9e;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_A;arg2:ARG_REG_IX_IND;arg3:ARG_NONE;uniq:103029),
  (nam:'and';       instbyte:$a6;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_A;arg2:ARG_REG_IX_IND;arg3:ARG_NONE;uniq:103030),
  (nam:'xor';       instbyte:$ae;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_A;arg2:ARG_REG_IX_IND;arg3:ARG_NONE;uniq:103031),
  (nam:'or';        instbyte:$b6;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_A;arg2:ARG_REG_IX_IND;arg3:ARG_NONE;uniq:103032),
  (nam:'cp';        instbyte:$be;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_A;arg2:ARG_REG_IX_IND;arg3:ARG_NONE;uniq:103033),
  (nam:nil;         instbyte:$cb;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:103034), // subtable 0xdd/0xcb
  (nam:'pop';       instbyte:$e1;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_IX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:103035),
  (nam:'ex';        instbyte:$e3;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_SP_IND;arg2:ARG_REG_IX;arg3:ARG_NONE;uniq:103036),
  (nam:'push';      instbyte:$e5;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_IX;arg2:ARG_NONE;arg3:ARG_NONE;uniq:103037),
  (nam:'jp';        instbyte:$e9;cpu:PROC_Z80;  flags:FLAGS_IJMP;
  arg1:ARG_REG_IX_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:103038),
  (nam:'ld';        instbyte:$f9;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_SP;arg2:ARG_REG_IX;arg3:ARG_NONE;uniq:103039),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// z80 subtable 0xdd/0xcb
// - num = fourth byte
  _asmz80subddcba:array[0..7] of tasminstdata=(
  (nam:'rlc';       instbyte:$06;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IX_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:104000),
  (nam:'rrc';       instbyte:$0e;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IX_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:104001),
  (nam:'rl';        instbyte:$16;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IX_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:104002),
  (nam:'rr';        instbyte:$1e;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IX_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:104003),
  (nam:'sla';       instbyte:$26;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IX_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:104004),
  (nam:'sra';       instbyte:$2e;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IX_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:104005),
  (nam:'srl';       instbyte:$3e;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IX_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:104006),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// z80 subtable 0xdd/0xcb part2
// - num = second byte bits 7,6,2;uniq:1,0
// - bit = second byte bits 5,4,3
  _asmz80subddcbb:array[0..3] of tasminstdata=(
  (nam:'bit';       instbyte:$46;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_BIT;arg2:ARG_REG_IX_IND;arg3:ARG_NONE;uniq:105000),
  (nam:'res';       instbyte:$86;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_BIT;arg2:ARG_REG_IX_IND;arg3:ARG_NONE;uniq:105001),
  (nam:'set';       instbyte:$c6;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_BIT;arg2:ARG_REG_IX_IND;arg3:ARG_NONE;uniq:105002),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

  _asmz80subed:array[0..60] of tasminstdata=(
  (nam:'in';        instbyte:$40;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_B;arg2:ARG_REG_C_IND;arg3:ARG_NONE;uniq:106000),
  (nam:'out';       instbyte:$41;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_C_IND;arg2:ARG_REG_B;arg3:ARG_NONE;uniq:106001),
  (nam:'sbc';       instbyte:$42;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_HL;arg2:ARG_REG_BC;arg3:ARG_NONE;uniq:106002),
  (nam:'ld';        instbyte:$43;cpu:PROC_Z80;flags:0;
  arg1:ARG_MEMLOC16;arg2:ARG_REG_BC;arg3:ARG_NONE;uniq:106003),
  (nam:'neg';       instbyte:$44;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106004),
  (nam:'retn';      instbyte:$45;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106005),
  (nam:'im 0';      instbyte:$46;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106006),
  (nam:'ld';        instbyte:$47;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_I;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:106007),
  (nam:'in';        instbyte:$48;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_C;arg2:ARG_REG_C_IND;arg3:ARG_NONE;uniq:106008),
  (nam:'out';       instbyte:$49;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_C_IND;arg2:ARG_REG_C;arg3:ARG_NONE;uniq:106009),
  (nam:'adc';       instbyte:$4a;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_HL;arg2:ARG_REG_BC;arg3:ARG_NONE;uniq:106010),
  (nam:'ld';        instbyte:$4b;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_BC;arg2:ARG_MEMLOC16;arg3:ARG_NONE;uniq:106011),
  (nam:'reti';      instbyte:$4d;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106012),
  (nam:'ld';        instbyte:$4f;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_R;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:106013),
  (nam:'in';        instbyte:$50;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_D;arg2:ARG_REG_C_IND;arg3:ARG_NONE;uniq:106014),
  (nam:'out';       instbyte:$51;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_C_IND;arg2:ARG_REG_D;arg3:ARG_NONE;uniq:106015),
  (nam:'sbc';       instbyte:$52;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_HL;arg2:ARG_REG_DE;arg3:ARG_NONE;uniq:106016),
  (nam:'ld';        instbyte:$53;cpu:PROC_Z80;flags:0;
  arg1:ARG_MEMLOC16;arg2:ARG_REG_DE;arg3:ARG_NONE;uniq:106017),
  (nam:'im 1';      instbyte:$56;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106018),
  (nam:'ld';        instbyte:$57;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_I;arg3:ARG_NONE;uniq:106019),
  (nam:'in';        instbyte:$58;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_E;arg2:ARG_REG_C_IND;arg3:ARG_NONE;uniq:106020),
  (nam:'out';       instbyte:$59;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_C_IND;arg2:ARG_REG_E;arg3:ARG_NONE;uniq:106021),
  (nam:'adc';       instbyte:$5a;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_HL;arg2:ARG_REG_DE;arg3:ARG_NONE;uniq:106022),
  (nam:'ld';        instbyte:$5b;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_DE;arg2:ARG_MEMLOC16;arg3:ARG_NONE;uniq:106023),
  (nam:'im 2';      instbyte:$5e;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106024),
  (nam:'ld';        instbyte:$5f;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_R;arg3:ARG_NONE;uniq:106025),
  (nam:'in';        instbyte:$60;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_H;arg2:ARG_REG_C_IND;arg3:ARG_NONE;uniq:106026),
  (nam:'out';       instbyte:$61;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_C_IND;arg2:ARG_REG_H;arg3:ARG_NONE;uniq:106027),
  (nam:'sbc';       instbyte:$62;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_HL;arg2:ARG_REG_HL;arg3:ARG_NONE;uniq:106028),
  (nam:'ld';        instbyte:$63;cpu:PROC_Z80;flags:0;
  arg1:ARG_MEMLOC16;arg2:ARG_REG_HL;arg3:ARG_NONE;uniq:106029),
  (nam:'rrd';       instbyte:$67;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106030),
  (nam:'in';        instbyte:$68;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_L;arg2:ARG_REG_C_IND;arg3:ARG_NONE;uniq:106031),
  (nam:'out';       instbyte:$69;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_C_IND;arg2:ARG_REG_L;arg3:ARG_NONE;uniq:106032),
  (nam:'adc';       instbyte:$6a;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_HL;arg2:ARG_REG_HL;arg3:ARG_NONE;uniq:106033),
  (nam:'ld';        instbyte:$6b;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_HL;arg2:ARG_MEMLOC16;arg3:ARG_NONE;uniq:106034),
  (nam:'rld';       instbyte:$6f;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106035),
  (nam:'in';        instbyte:$70;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_HL_IND;arg2:ARG_REG_C_IND;arg3:ARG_NONE;uniq:106036),
  (nam:'out';       instbyte:$71;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_C_IND;arg2:ARG_REG_HL_IND;arg3:ARG_NONE;uniq:106037),
  (nam:'sbc';       instbyte:$72;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_HL;arg2:ARG_REG_SP;arg3:ARG_NONE;uniq:106038),
  (nam:'ld';        instbyte:$73;cpu:PROC_Z80;flags:0;
  arg1:ARG_MEMLOC16;arg2:ARG_REG_SP;arg3:ARG_NONE;uniq:106039),
  (nam:'in';        instbyte:$78;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_A;arg2:ARG_REG_C_IND;arg3:ARG_NONE;uniq:106040),
  (nam:'out';       instbyte:$79;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_C_IND;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:106041),
  (nam:'adc';       instbyte:$7a;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_HL;arg2:ARG_REG_SP;arg3:ARG_NONE;uniq:106042),
  (nam:'ld';        instbyte:$7b;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_SP;arg2:ARG_MEMLOC16;arg3:ARG_NONE;uniq:106043),
  (nam:'ldi';       instbyte:$a0;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106044),
  (nam:'cpi';       instbyte:$a1;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106045),
  (nam:'ini';       instbyte:$a2;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106046),
  (nam:'outi';      instbyte:$a3;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106047),
  (nam:'ldd';       instbyte:$a8;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106048),
  (nam:'cpd';       instbyte:$a9;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106049),
  (nam:'ind';       instbyte:$aa;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106050),
  (nam:'outd';      instbyte:$ab;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106051),
  (nam:'ldir';      instbyte:$b0;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106052),
  (nam:'cpir';      instbyte:$b1;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106053),
  (nam:'inir';      instbyte:$b2;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106054),
  (nam:'outir';     instbyte:$b3;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106055),
  (nam:'lddr';      instbyte:$b8;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106056),
  (nam:'cpdr';      instbyte:$b9;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106057),
  (nam:'indr';      instbyte:$ba;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106058),
  (nam:'otdr';      instbyte:$bb;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:106059),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

  _asmz80subfd:array[0..40] of tasminstdata=(
  (nam:'add';       instbyte:$09;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_IY;arg2:ARG_REG_BC;arg3:ARG_NONE;uniq:107000),
  (nam:'add';       instbyte:$19;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_IY;arg2:ARG_REG_DE;arg3:ARG_NONE;uniq:107001),
  (nam:'ld';        instbyte:$21;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_IY;arg2:ARG_IMM16;arg3:ARG_NONE;uniq:107002),
  (nam:'ld';        instbyte:$22;cpu:PROC_Z80;flags:0;
  arg1:ARG_MEMLOC16;arg2:ARG_REG_IY;arg3:ARG_NONE;uniq:107003),
  (nam:'inc';       instbyte:$23;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_IY;arg2:ARG_NONE;arg3:ARG_NONE;uniq:107004),
  (nam:'add';       instbyte:$29;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_IY;arg2:ARG_REG_IX;arg3:ARG_NONE;uniq:107005),
  (nam:'ld';        instbyte:$2a;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_IY;arg2:ARG_MEMLOC16;arg3:ARG_NONE;uniq:107006),
  (nam:'dec';       instbyte:$2b;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_IY;arg2:ARG_NONE;arg3:ARG_NONE;uniq:107007),
  (nam:'inc';       instbyte:$34;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IY_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:107008),
  (nam:'dec';       instbyte:$35;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IY_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:107009),
  (nam:'ld';        instbyte:$36;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IY_IND;arg2:ARG_IMM8;arg3:ARG_NONE;uniq:107010),
  (nam:'add';       instbyte:$39;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_IY;arg2:ARG_REG_SP;arg3:ARG_NONE;uniq:107011),
  (nam:'ld';        instbyte:$46;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_B;arg2:ARG_REG_IY_IND;arg3:ARG_NONE;uniq:107012),
  (nam:'ld';        instbyte:$4e;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_C;arg2:ARG_REG_IY_IND;arg3:ARG_NONE;uniq:107013),
  (nam:'ld';        instbyte:$56;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_D;arg2:ARG_REG_IY_IND;arg3:ARG_NONE;uniq:107014),
  (nam:'ld';        instbyte:$5e;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_E;arg2:ARG_REG_IY_IND;arg3:ARG_NONE;uniq:107015),
  (nam:'ld';        instbyte:$66;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_H;arg2:ARG_REG_IY_IND;arg3:ARG_NONE;uniq:107016),
  (nam:'ld';        instbyte:$6e;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_L;arg2:ARG_REG_IY_IND;arg3:ARG_NONE;uniq:107017),
  (nam:'ld';        instbyte:$70;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IY_IND;arg2:ARG_REG_B;arg3:ARG_NONE;uniq:107018),
  (nam:'ld';        instbyte:$71;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IY_IND;arg2:ARG_REG_C;arg3:ARG_NONE;uniq:107019),
  (nam:'ld';        instbyte:$72;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IY_IND;arg2:ARG_REG_D;arg3:ARG_NONE;uniq:107020),
  (nam:'ld';        instbyte:$73;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IY_IND;arg2:ARG_REG_E;arg3:ARG_NONE;uniq:107021),
  (nam:'ld';        instbyte:$74;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IY_IND;arg2:ARG_REG_H;arg3:ARG_NONE;uniq:107022),
  (nam:'ld';        instbyte:$75;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IY_IND;arg2:ARG_REG_L;arg3:ARG_NONE;uniq:107023),
  (nam:'ld';        instbyte:$77;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IY_IND;arg2:ARG_REG_A;arg3:ARG_NONE;uniq:107024),
  (nam:'ld';        instbyte:$7e;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_A;arg2:ARG_REG_IY_IND;arg3:ARG_NONE;uniq:107025),
  (nam:'add';       instbyte:$86;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_A;arg2:ARG_REG_IY_IND;arg3:ARG_NONE;uniq:107026),
  (nam:'adc';       instbyte:$8e;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_A;arg2:ARG_REG_IY_IND;arg3:ARG_NONE;uniq:107027),
  (nam:'sub';       instbyte:$96;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_A;arg2:ARG_REG_IY_IND;arg3:ARG_NONE;uniq:107028),
  (nam:'sbc';       instbyte:$9e;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_A;arg2:ARG_REG_IY_IND;arg3:ARG_NONE;uniq:107029),
  (nam:'and';       instbyte:$a6;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_A;arg2:ARG_REG_IY_IND;arg3:ARG_NONE;uniq:107030),
  (nam:'xor';       instbyte:$ae;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_A;arg2:ARG_REG_IY_IND;arg3:ARG_NONE;uniq:107031),
  (nam:'or';        instbyte:$b6;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_A;arg2:ARG_REG_IY_IND;arg3:ARG_NONE;uniq:107032),
  (nam:'cp';        instbyte:$be;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_A;arg2:ARG_REG_IY_IND;arg3:ARG_NONE;uniq:107033),
  (nam:nil;         instbyte:$cb;cpu:PROC_Z80;flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:107034), // subtable 0xfd/0xcb
  (nam:'pop';       instbyte:$e1;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_IY;arg2:ARG_NONE;arg3:ARG_NONE;uniq:107035),
  (nam:'ex';        instbyte:$e3;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_SP_IND;arg2:ARG_REG_IY;arg3:ARG_NONE;uniq:107036),
  (nam:'push';      instbyte:$e5;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_IY;arg2:ARG_NONE;arg3:ARG_NONE;uniq:107037),
  (nam:'jp';        instbyte:$e9;cpu:PROC_Z80;  flags:FLAGS_IJMP;
  arg1:ARG_REG_IY_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:107038),
  (nam:'ld';        instbyte:$f9;cpu:PROC_Z80;flags:0;
  arg1:ARG_REG_SP;arg2:ARG_REG_IY;arg3:ARG_NONE;uniq:107039),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
  arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// z80 subtable 0xfd/0xcb
// - num = fourth byte
  _asmz80subfdcba:array[0..7] of tasminstdata=(
  (nam:'rlc';       instbyte:$06;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IY_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:108000),
  (nam:'rrc';       instbyte:$0e;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IY_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:108001),
  (nam:'rl';        instbyte:$16;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IY_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:108002),
  (nam:'rr';        instbyte:$1e;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IY_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:108003),
  (nam:'sla';       instbyte:$26;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IY_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:108004),
  (nam:'sra';       instbyte:$2e;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IY_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:108005),
  (nam:'srl';       instbyte:$3e;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_REG_IY_IND;arg2:ARG_NONE;arg3:ARG_NONE;uniq:108006),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

// z80 subtable 0xfd/0xcb part2
// - num = second byte bits 7,6,2;uniq:1,0
// - bit = second byte bits 5,4,3
  _asmz80subfdcbb:array[0..3] of tasminstdata=(
  (nam:'bit';       instbyte:$46;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_BIT;arg2:ARG_REG_IY_IND;arg3:ARG_NONE;uniq:109000),
  (nam:'res';       instbyte:$86;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_BIT;arg2:ARG_REG_IY_IND;arg3:ARG_NONE;uniq:109001),
  (nam:'set';       instbyte:$c6;cpu:PROC_Z80;  flags:FLAGS_INDEXREG;
  arg1:ARG_BIT;arg2:ARG_REG_IY_IND;arg3:ARG_NONE;uniq:109002),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

  _asmdword:array[0..1] of tasminstdata=(
  (nam:'dd';        instbyte:$00;cpu:PROC_ALL;flags:0;
  arg1:ARG_IMM32;arg2:ARG_NONE;arg3:ARG_NONE;uniq:200000),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

  _asmword:array[0..1] of tasminstdata=(
  (nam:'dw';        instbyte:$00;cpu:PROC_ALL;flags:0;
  arg1:ARG_IMM16;arg2:ARG_NONE;arg3:ARG_NONE;uniq:201000),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

  _asmstr:array[0..5] of tasminstdata=(
  (nam:'db';        instbyte:$00;cpu:PROC_ALL;flags:0;
  arg1:ARG_STRING;arg2:ARG_NONE;arg3:ARG_NONE;uniq:202000),
  (nam:'db';        instbyte:$00;cpu:PROC_ALL;flags:0;
  arg1:ARG_PSTRING;arg2:ARG_NONE;arg3:ARG_NONE;uniq:202001),
  (nam:'db';        instbyte:$00;cpu:PROC_ALL;flags:0;
  arg1:ARG_DOSSTRING;arg2:ARG_NONE;arg3:ARG_NONE;uniq:202002),
  (nam:'db';        instbyte:$00;cpu:PROC_ALL;flags:0;
  arg1:ARG_CUNICODESTRING;arg2:ARG_NONE;arg3:ARG_NONE;uniq:202003),
  (nam:'db';        instbyte:$00;cpu:PROC_ALL;flags:0;
  arg1:ARG_PUNICODESTRING;arg2:ARG_NONE;arg3:ARG_NONE;uniq:202004),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

  _asm_fp:array[0..3] of tasminstdata=(
  (nam:'dword';     instbyte:$00;cpu:PROC_ALL;flags:0;
  arg1:ARG_IMM_SINGLE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:203000),
  (nam:'qword';     instbyte:$00;cpu:PROC_ALL;flags:0;
  arg1:ARG_IMM_DOUBLE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:203001),
  (nam:'tbyte';     instbyte:$00;cpu:PROC_ALL;flags:0;
  arg1:ARG_IMM_LONGDOUBLE;arg2:ARG_NONE;arg3:ARG_NONE;uniq:203002),
  (nam:nil;         instbyte:$0;cpu:0;                  flags:0;
   arg1:ARG_NONE;arg2:ARG_NONE;arg3:ARG_NONE; uniq:0));

  tables86:array[0..47] of tasmtable=(
  (table:@_asm86;typ:TABLE_MAIN;extnum:$00;extnum2:$00;divisor:0;mask:$ff;minlim:0;maxlim:$ff;modrmpos:0),
  (table:@_asm86sub0f;typ:TABLE_EXT;extnum:$0f;extnum2:$0;divisor:0;mask:$ff;minlim:0;maxlim:$ff;modrmpos:1),
  (table:@_asm86sub80;typ:TABLE_EXT;extnum:$80;extnum2:$0;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:0),
  (table:@_asm86sub81;typ:TABLE_EXT;extnum:$81;extnum2:$0;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:0),
  (table:@_asm86sub82;typ:TABLE_EXT;extnum:$82;extnum2:$0;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:0),
  (table:@_asm86sub83;typ:TABLE_EXT;extnum:$83;extnum2:$0;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:0),
  (table:@_asm86subc0;typ:TABLE_EXT;extnum:$c0;extnum2:$0;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:0),
  (table:@_asm86subc1;typ:TABLE_EXT;extnum:$c1;extnum2:$0;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:0),
  (table:@_asm86subd0;typ:TABLE_EXT;extnum:$d0;extnum2:$0;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:0),
  (table:@_asm86subd1;typ:TABLE_EXT;extnum:$d1;extnum2:$0;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:0),
  (table:@_asm86subd2;typ:TABLE_EXT;extnum:$d2;extnum2:$0;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:0),
  (table:@_asm86subd3;typ:TABLE_EXT;extnum:$d3;extnum2:$0;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:0),
  (table:@_asm86subf6;typ:TABLE_EXT;extnum:$f6;extnum2:$0;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:0),
  (table:@_asm86subf7;typ:TABLE_EXT;extnum:$f7;extnum2:$0;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:0),
  (table:@_asm86subfe;typ:TABLE_EXT;extnum:$fe;extnum2:$0;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:0),
  (table:@_asm86subff;typ:TABLE_EXT;extnum:$ff;extnum2:$0;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:0),
  (table:@_asm86sub0f00;typ:TABLE_EXT2;extnum:$0f;extnum2:$00;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:1),
  (table:@_asm86sub0f01;typ:TABLE_EXT2;extnum:$0f;extnum2:$01;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:1),
  (table:@_asm86sub0f18;typ:TABLE_EXT2;extnum:$0f;extnum2:$18;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:1),
  (table:@_asm86sub0f71;typ:TABLE_EXT2;extnum:$0f;extnum2:$71;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:1),
  (table:@_asm86sub0f72;typ:TABLE_EXT2;extnum:$0f;extnum2:$72;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:1),
  (table:@_asm86sub0f73;typ:TABLE_EXT2;extnum:$0f;extnum2:$73;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:1),
  (table:@_asm86sub0fae;typ:TABLE_EXT2;extnum:$0f;extnum2:$ae;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:1),
  (table:@_asm86sub0fba;typ:TABLE_EXT2;extnum:$0f;extnum2:$ba;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:1),
  (table:@_asm86sub0fc2;typ:TABLE_EXT2;extnum:$0f;extnum2:$c2;divisor:0;mask:$00;minlim:0;maxlim:$ff;modrmpos:1),
  (table:@_asm86sub0fc7;typ:TABLE_EXT2;extnum:$0f;extnum2:$c7;divisor:8;mask:$07;minlim:0;maxlim:$ff;modrmpos:1),
  (table:@_asm86subd8a;typ:TABLE_EXT;extnum:$d8;extnum2:$0;divisor:8;mask:$07;minlim:0;maxlim:$bf;modrmpos:0),
  (table:@_asm86subd8b;typ:TABLE_EXT;extnum:$d8;extnum2:$0;divisor:8;mask:$1f;minlim:$c0;maxlim:$ff;modrmpos:0),
  (table:@_asm86subd9a;typ:TABLE_EXT;extnum:$d9;extnum2:$0;divisor:8;mask:$07;minlim:0;maxlim:$bf;modrmpos:0),
  (table:@_asm86subd9b;typ:TABLE_EXT;extnum:$d9;extnum2:$0;divisor:8;mask:$1f;minlim:$c0;maxlim:$ff;modrmpos:0),
  (table:@_asm86subd9c;typ:TABLE_EXT;extnum:$d9;extnum2:$0;divisor:1;mask:$ff;minlim:$c0;maxlim:$ff;modrmpos:1),
  (table:@_asm86subdaa;typ:TABLE_EXT;extnum:$da;extnum2:$0;divisor:8;mask:$07;minlim:0;maxlim:$bf;modrmpos:0),
  (table:@_asm86subdab;typ:TABLE_EXT;extnum:$da;extnum2:$0;divisor:8;mask:$1f;minlim:$c0;maxlim:$ff;modrmpos:0),
  (table:@_asm86subdac;typ:TABLE_EXT;extnum:$da;extnum2:$0;divisor:1;mask:$ff;minlim:$c0;maxlim:$ff;modrmpos:1),
  (table:@_asm86subdba;typ:TABLE_EXT;extnum:$db;extnum2:$0;divisor:8;mask:$07;minlim:0;maxlim:$bf;modrmpos:0),
  (table:@_asm86subdbb;typ:TABLE_EXT;extnum:$db;extnum2:$0;divisor:8;mask:$1f;minlim:$c0;maxlim:$ff;modrmpos:0),
  (table:@_asm86subdbc;typ:TABLE_EXT;extnum:$db;extnum2:$0;divisor:1;mask:$ff;minlim:$c0;maxlim:$ff;modrmpos:1),
  (table:@_asm86subdca;typ:TABLE_EXT;extnum:$dc;extnum2:$0;divisor:8;mask:$07;minlim:0;maxlim:$bf;modrmpos:0),
  (table:@_asm86subdcb;typ:TABLE_EXT;extnum:$dc;extnum2:$0;divisor:8;mask:$1f;minlim:$c0;maxlim:$ff;modrmpos:0),
  (table:@_asm86subdda;typ:TABLE_EXT;extnum:$dd;extnum2:$0;divisor:8;mask:$07;minlim:0;maxlim:$bf;modrmpos:0),
  (table:@_asm86subddb;typ:TABLE_EXT;extnum:$dd;extnum2:$0;divisor:8;mask:$1f;minlim:$c0;maxlim:$ff;modrmpos:0),
  (table:@_asm86subdea;typ:TABLE_EXT;extnum:$de;extnum2:$0;divisor:8;mask:$07;minlim:0;maxlim:$bf;modrmpos:0),
  (table:@_asm86subdeb;typ:TABLE_EXT;extnum:$de;extnum2:$0;divisor:8;mask:$1f;minlim:$c0;maxlim:$ff;modrmpos:0),
  (table:@_asm86subdec;typ:TABLE_EXT;extnum:$de;extnum2:$0;divisor:1;mask:$ff;minlim:$c0;maxlim:$ff;modrmpos:1),
  (table:@_asm86subdfa;typ:TABLE_EXT;extnum:$df;extnum2:$0;divisor:8;mask:$07;minlim:0;maxlim:$bf;modrmpos:0),
  (table:@_asm86subdfb;typ:TABLE_EXT;extnum:$df;extnum2:$0;divisor:8;mask:$1f;minlim:$c0;maxlim:$ff;modrmpos:0),
  (table:@_asm86subdfc;typ:TABLE_EXT;extnum:$df;extnum2:$0;divisor:1;mask:$ff;minlim:$c0;maxlim:$ff;modrmpos:1),
  (table:nil;typ:0;extnum:$0;extnum2:$0;divisor:0;mask:$0;minlim:$0;maxlim:$0;modrmpos:0));

 tablesz80:array[0..10] of tasmtable=(
  (table:@_asmz80;typ:TABLE_MAIN;extnum:$0;extnum2:$0;divisor:0;mask:$ff;minlim:$0;maxlim:$ff;modrmpos:0),
  (table:@_asmz80subcba;typ:TABLE_EXT;extnum:$cb;extnum2:$0;divisor:8;mask:$1f;minlim:$0;maxlim:$39;modrmpos:0),
  (table:@_asmz80subcbb;typ:TABLE_EXT;extnum:$cb;extnum2:$0;divisor:$64;mask:$03;minlim:$40;maxlim:$ff;modrmpos:0),
  (table:@_asmz80subdd;typ:TABLE_EXT;extnum:$dd;extnum2:$0;divisor:0;mask:$ff;minlim:$0;maxlim:$ff;modrmpos:0),
  (table:@_asmz80subddcba;typ:TABLE_EXT2;extnum:$dd;extnum2:$cb;divisor:0;mask:$ff;minlim:$0;maxlim:$ff;modrmpos:0),
  (table:@_asmz80subddcbb;typ:TABLE_EXT2;extnum:$dd;extnum2:$cb;divisor:0;mask:$c7;minlim:$0;maxlim:$ff;modrmpos:0),
  (table:@_asmz80subed;typ:TABLE_EXT;extnum:$ed;extnum2:$0;divisor:0;mask:$ff;minlim:$0;maxlim:$ff;modrmpos:0),
  (table:@_asmz80subfd;typ:TABLE_EXT;extnum:$fd;extnum2:$0;divisor:0;mask:$ff;minlim:$0;maxlim:$ff;modrmpos:0),
  (table:@_asmz80subfdcba;typ:TABLE_EXT2;extnum:$fd;extnum2:$cb;divisor:0;mask:$ff;minlim:$0;maxlim:$ff;modrmpos:0),
  (table:@_asmz80subfdcbb;typ:TABLE_EXT2;extnum:$fd;extnum2:$cb;divisor:0;mask:$c7;minlim:$0;maxlim:$ff;modrmpos:0),
  (table:nil;typ:0;extnum:$0;extnum2:$0;divisor:0;mask:$0;minlim:$0;maxlim:$0;modrmpos:0));

  reconstruct:array[0..61] of pasminstdata=(
    @_asm86,@_asm86sub0f,@_asm86sub80,@_asm86sub81,@_asm86sub82,@_asm86sub83,@_asm86subc0,@_asm86subc1,@_asm86subd0,
    @_asm86subd1,@_asm86subd2,@_asm86subd3,@_asm86subf6,@_asm86subf7,@_asm86subfe,@_asm86subff,@_asm86sub0f00,
    @_asm86sub0f01,@_asm86sub0f18,@_asm86sub0f71,@_asm86sub0f72,@_asm86sub0f73,@_asm86sub0fae,@_asm86sub0fba,
    @_asm86sub0fc2,@_asm86sub0fc7,@_asm86subd8a,@_asm86subd8b,@_asm86subd9a,@_asm86subd9b,@_asm86subd9c,
    @_asm86subdaa,@_asm86subdab,@_asm86subdac,@_asm86subdba,@_asm86subdbb,@_asm86subdbc,@_asm86subdca,@_asm86subdcb,
    @_asm86subdda,@_asm86subddb,@_asm86subdea,@_asm86subdeb,@_asm86subdec,@_asm86subdfa,@_asm86subdfb,@_asm86subdfc,
    @_asmz80,@_asmz80subcba,@_asmz80subcbb,@_asmz80subdd,@_asmz80subddcba,@_asmz80subddcbb,@_asmz80subed,@_asmz80subfd,
    @_asmz80subfdcba,@_asmz80subfdcbb,@_asmdword,@_asmword,@_asmstr,@_asm_fp,nil);

  procnames:array[0..9] of proctable=(
    (num:PROC_8086;      nam:'8086';               tab:@tables86),
    (num:PROC_80286;     nam:'80286';              tab:@tables86),
    (num:PROC_80386;     nam:'80386';              tab:@tables86),
    (num:PROC_80486;     nam:'80486';              tab:@tables86),
    (num:PROC_PENTIUM;   nam:'Pentium';            tab:@tables86),
    (num:PROC_PENTIUMPRO;nam:'Pentium Pro';        tab:@tables86),
    (num:PROC_PENTMMX;   nam:'Pentium MMX';        tab:@tables86),
    (num:PROC_PENTIUM2;  nam:'Pentium II with KNI';tab:@tables86),
    (num:PROC_Z80;       nam:'Z-80';               tab:@tablesz80),
    (num:0;              nam:'';                   tab:nil));

implementation

begin
end.

