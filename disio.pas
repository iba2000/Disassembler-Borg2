unit disio;
interface
uses sysutils,windows,common,gname,stacks,savefile,disasm,proctab,datas,
     mainwind,schedule,xref,menu,range;

{************************************************************************
* This is a fairly big class, and yet it was originally part of the     *
* larger disasm class. I finally got around to splitting off some of    *
* 3500 lines of code from that class into here. This represents the     *
* disasm I/O functions for window I/O and file I/O. Version 2.11 was    *
* when this was split. There are still a huge number of confusing       *
* functions and code in here which probably needs more work to clean it *
* up, and better split/define the classes. Some of the functions are    *
* friends of disasm because it has been difficult to split the classes  *
* effectively and both access the complex main disassembly structures   *
************************************************************************}
const
  DISPFLAG_NEGATE=1;

type
  tdisio=class
    curraddr,outend:lptr;
    subitem:dsmitemtype;  // subindex to top line of output
    retstack:tstack;
  public
    constructor create;
    destructor destroy; override;
    procedure dumptofile(fname:string; printaddrs:boolean);
    procedure dumpblocktofile(fname:string; printaddrs:boolean);
    procedure outcomment(inst:pdsmitem);
    procedure outargs(inst:pdsmitem; a:argtype);
    procedure updatewindow;
    procedure scroller(amount:dword);
    procedure updatewindowifinrange(loc:lptr);
    procedure savecuraddr;
    procedure findcurrentaddr(var loc:lptr);
    procedure vertsetpos(pos:dword);
    procedure jumpback;
    procedure jumpto(arg1:boolean);
    procedure setcuraddr(loc:lptr);
    procedure setpos(ypos:integer);
    procedure outinst(inst:pdsmitem; printaddrs:boolean);
    procedure outdb(var lp:lptr; printaddrs:boolean);
    procedure outprefix(prefixbyte:byte);
    procedure argoverdec;
    procedure arg_negate;
    procedure argoverhex;
    procedure argoveroffsetdseg;
    procedure argoverchar;
    procedure makecode;
    procedure makeword;
    procedure makedword;
    procedure makestring;
    procedure pascalstring;
    procedure ucstring;
    procedure upstring;
    procedure dosstring;
    procedure generalstring;
    function findcurrentline:pdsmitem;
    procedure argoversingle;
    procedure makelongdouble;
    procedure makedouble;
    procedure makesingle;
    procedure updatewindowifwithinrange(loc_start,loc_end:lptr);
    procedure printlineheader(loc:lptr; printaddrs:boolean);
    function isprefix(byt:byte):boolean;
    function issegprefix(byt:byte):boolean;
  end;

var
  dio:tdisio;

implementation

{************************************************************************
* globals                                                               *
* - actually some constants used in file i/o as a header                *
************************************************************************}

{************************************************************************
* constructor function                                                  *
* - this just enables window updates and sets the subline to null       *
* - the subline (subitem) is basically the line in the disassembly that *
*   you see for any given loc. As a loc may refer to many lines (like   *
*   segheader, comments, xref, actual instruction are all separate      *
*   line, and subline says which of these it is)                        *
************************************************************************}
constructor tdisio.create;
begin
  inherited create;
  subitem:=dsmnull;
  retstack:=tstack.create;
end;

destructor tdisio.destroy;
begin
  retstack.free;
end;

// argoverdec                                                            *
// - disio also acts as a go between for the user and the disasm engine  *
// - here we translate the users current line of the disassembly and     *
//   their request for a decimal override into a call to the disasm      *
//   engine to add the override to the instruction that is there         *
// - note that these kind of calls come from the scheduler and are part  *
//   of the secondary thread                                             *
procedure tdisio.argoverdec;
var outhere:lptr;
begin
  findcurrentaddr(outhere);
  dsm.disargoverdec(outhere);
end;

procedure tdisio.argoversingle;
var outhere:lptr;
begin
  findcurrentaddr(outhere);
  dsm.disargoversingle(outhere);
end; // user versions

procedure tdisio.arg_negate;
var outhere:lptr;
begin
  findcurrentaddr(outhere);
  dsm.disargnegate(outhere);
end;

procedure tdisio.argoverhex;
var outhere:lptr;
begin
  findcurrentaddr(outhere);
  dsm.disargoverhex(outhere);
end;

procedure tdisio.argoveroffsetdseg;
var outhere:lptr;
begin
  findcurrentaddr(outhere);
  dsm.disargoveroffsetdseg(outhere);
end;

procedure tdisio.argoverchar;
var outhere:lptr;
begin
  findcurrentaddr(outhere);
  dsm.disargoverchar(outhere);
end;

// makedword                                                             *
// - disio acts as a go between for the user and the disasm engine       *
// - here we translate the users current line of the disassembly and     *
//   their request for a dword into a call to the disasm engine to       *
//   disassemble a dword at the current point                            *
// - note that these kind of calls come from the scheduler and are part  *
//   of the secondary thread                                             *
procedure tdisio.makedword;
var outhere:lptr;
begin
  findcurrentaddr(outhere);
  if eq(outhere,curraddr) then subitem:=dsmnull;
  dsm.disdatadword(outhere,0);
end;

procedure tdisio.makesingle;
var outhere:lptr;
begin
  findcurrentaddr(outhere);
  if eq(outhere,curraddr) then subitem:=dsmnull;
  dsm.disdatasingle(outhere);
end;

procedure tdisio.makedouble;
var outhere:lptr;
begin
  findcurrentaddr(outhere);
  if eq(outhere,curraddr) then subitem:=dsmnull;
  dsm.disdatadouble(outhere);
end;

procedure tdisio.makelongdouble;
var outhere:lptr;
begin
  findcurrentaddr(outhere);
  if eq(outhere,curraddr) then subitem:=dsmnull;
  dsm.disdatalongdouble(outhere);
end;

procedure tdisio.makeword;
var outhere:lptr;
begin
  findcurrentaddr(outhere);
  if eq(outhere,curraddr) then subitem:=dsmnull;
  dsm.disdataword(outhere,0);
end;

procedure tdisio.makestring;
var outhere:lptr;
begin
  findcurrentaddr(outhere);
  if eq(outhere,curraddr) then subitem:=dsmnull;
  dsm.disdatastring(outhere);
end;

procedure tdisio.pascalstring;
var outhere:lptr;
begin
  findcurrentaddr(outhere);
  if eq(outhere,curraddr) then subitem:=dsmnull;
  dsm.disdatapstring(outhere);
end;

procedure tdisio.ucstring;
var outhere:lptr;
begin
  findcurrentaddr(outhere);
  if eq(outhere,curraddr) then subitem:=dsmnull;
  dsm.disdataucstring(outhere);
end;

procedure tdisio.upstring;
var outhere:lptr;
begin
  findcurrentaddr(outhere);
  if eq(outhere,curraddr) then subitem:=dsmnull;
  dsm.disdataupstring(outhere);
end;

procedure tdisio.dosstring;
var outhere:lptr;
begin
  findcurrentaddr(outhere);
  if eq(outhere,curraddr) then subitem:=dsmnull;
  dsm.disdatadosstring(outhere);
end;

procedure tdisio.generalstring;
var outhere:lptr;
begin
  findcurrentaddr(outhere);
  if eq(outhere,curraddr) then subitem:=dsmnull;
  dsm.disdatageneralstring(outhere);
end;

procedure tdisio.makecode;
var outhere:lptr;
begin
  findcurrentaddr(outhere);
  if eq(outhere,curraddr) then subitem:=dsmnull;
  dsm.disblock(outhere);
end;

// vertsetpos                                                            *
// - this function takes a position of the vertical scroll bar, from 0   *
//   to the VERTSCROLLRANGE and it sets the current address to that      *
//   point                                                               *
procedure tdisio.vertsetpos(pos:dword);
var sbarpos:single;
begin
  sbarpos:=(pos / VERTSCROLLRANGE)*total_data_size;
  setcuraddr(dta.getlocpos(round(sbarpos)));
end;

{************************************************************************
* setcuraddr                                                            *
* - sets the address as a location for the screen output to start at    *
* - also sets the scroll bar position for the vertical scroll bar       *
* - also ensures that its not set to a mid-instruction address and      *
*   sets the subline                                                    *
* - called from many places in the source code                          *
************************************************************************}
procedure tdisio.setcuraddr(loc:lptr);
var
  titem:tdsmitem;
  tblock:pdsmitem;
  sbarpos:single;
  l_ds:pdsegitem;
begin
  // check for non-existant address added v2.20
  l_ds:=dta.findseg(loc);
  if l_ds=nil then exit;
  curraddr:=loc;
  titem.addr:=curraddr;
  titem.typ :=dsmnull;
  dsm.findnext(listitem(@titem));
  tblock:=pdsmitem(dsm.nextiterator);
  if tblock<>nil then subitem:=tblock.typ else subitem:=dsmnull;
  tblock:=dsm.nextiter_code(tblock);
  if tblock<>nil then begin
    if between(loc,tblock.addr,tblock.addr,tblock.length-1) then curraddr:=tblock.addr;
  end;
  outend.o:=loc.o+50;
  usersel:=0;
  userselonscreen:=TRUE;
  updatewindow;
  current_data_pos:=dta.datagetpos(loc);
  sbarpos:=(current_data_pos / (total_data_size+1.0))*VERTSCROLLRANGE;
  SetScrollPos(mainwindow,SB_VERT,integer(round(sbarpos)),TRUE);
end;

// setpos                                                                *
// - when the left mouse button is pressed the line is changed to the    *
//   line the mouse points at. This routine sets the line, and asks for  *
//   a screen update if needed (the screen update method here is a       *
//   primary thread request that simply invalidates the window rather    *
//   than requesting through the scheduler...... but this is very very   *
//   old code....                                                        *
procedure tdisio.setpos(ypos:integer);
begin
  if usersel<>ypos div cyc then begin
    usersel:=ypos div cyc;
    InvalidateRect(mainwindow,nil,TRUE);
  end;
end;

{************************************************************************
* printlineheader                                                       *
* - prints an appropriate line header with the address if needed and    *
*   sets the cursor position for the next LastPrintBuff call            *
************************************************************************}
procedure tdisio.printlineheader(loc:lptr; printaddrs:boolean);
begin
  if options.mode32 then begin
    if printaddrs then PrintBuff('%4.4x:%8.8x',[loc.s,loc.o])
    else PrintBuff('',['']);
    LastPrintBuffEpos(BYTEPOS);
  end else begin
    if printaddrs then PrintBuff('%4.4x:%4.4x',[loc.s,loc.o])
    else PrintBuff('',['']);
    LastPrintBuffEpos(BYTEPOS-4);
  end;
end;

{************************************************************************
* outinst                                                               *
* - this is the routine which results in the output of an address, hex  *
*   bytes, instruction and arguments                                    *
************************************************************************}
procedure tdisio.outinst(inst:pdsmitem; printaddrs:boolean);
var
  dblock:pdsegitem;
  i,prefixptr:integer;
  pbyte:byte;
begin
  printlineheader(inst.addr,printaddrs);
if $0102cb1f=inst.addr.o then begin
  i:=i;
end;
  dblock:=dta.findseg(inst.addr);      // find segment item.
  case inst.typ of
   dsmcode:
    begin
      i:=inst.length;
      if printaddrs then begin
        while i<>0 do begin
          if dblock<>nil then begin
            if dblock.typ=uninitdata then LastPrintBuff('??',[''])
            else LastPrintBuff('%2.2x',[byte(inst.data[inst.length-i])]);
          end else LastPrintBuff('%2.2x',[byte(inst.data[inst.length-i])]);
          dec(i);
          if ((i+8)<inst.length)and(inst.length>10) then begin
            LastPrintBuff('..',['']);
            break;
          end;
        end;
      end;
      if options.mode32 then LastPrintBuffEpos(ASMPOS+4) else LastPrintBuffEpos(ASMPOS);
      if inst.flags and FLAGS_PREFIX<>0 then begin
        prefixptr:=0;
        while(not isprefix(byte(inst.data[prefixptr])))and(prefixptr<15) do inc(prefixptr);
        pbyte:=byte(inst.data[prefixptr]);
        outprefix(pbyte);
      end;
      LastPrintBuff(pasminstdata(inst.tptr).nam,['']);
      LastPrintBuff(' ',['']);
      if options.mode32 then LastPrintBuffEpos(ARGPOS+4) else LastPrintBuffEpos(ARGPOS);
      if dblock<>nil then begin
        if dblock.typ=uninitdata then LastPrintBuff('?',[''])
        else begin
          outargs(inst,pasminstdata(inst.tptr).arg1);
          if pasminstdata(inst.tptr).arg2<>ARG_NONE then begin
            LastPrintBuff(', ',['']);
            outargs(inst,pasminstdata(inst.tptr).arg2);
          end;
          if pasminstdata(inst.tptr).arg3<>ARG_NONE then begin
            LastPrintBuff(', ',['']);
            outargs(inst,pasminstdata(inst.tptr).arg3);
          end;
        end;
      end else begin
        outargs(inst,pasminstdata(inst.tptr).arg1);
        if pasminstdata(inst.tptr).arg2<>ARG_NONE then begin
          LastPrintBuff(', ',['']);
          outargs(inst,pasminstdata(inst.tptr).arg2);
        end;
        if pasminstdata(inst.tptr).arg3<>ARG_NONE then begin
          LastPrintBuff(', ',['']);
          outargs(inst,pasminstdata(inst.tptr).arg3);
        end;
      end;
    end;
  end;
end;

{************************************************************************
* outdb                                                                 *
* - this is similar to outinst, but when there is no disassembly for a  *
*   loc we call this to output a db xxh or a db ? if its uninitdata     *
************************************************************************}
procedure tdisio.outdb(var lp:lptr; printaddrs:boolean);
var
  dblock:pdsegitem;
  aaddr:dword;
  mcode:pchar;
begin
  mcode:=nil;
  printlineheader(lp,printaddrs);
  dblock:=dta.findseg(lp);      // find segment item.
  if dblock=nil then begin
    if printaddrs then LastPrintBuff('??',['']);
  end else if dblock.typ=uninitdata then begin
    if printaddrs then LastPrintBuff('??',['']);
  end else begin
    aaddr:=(lp.o-dblock.addr.o);
    mcode:=@dblock.data[aaddr];
    if printaddrs then LastPrintBuff('%2.2x',[byte(mcode[0])]);
  end;
  if options.mode32 then LastPrintBuffEpos(ASMPOS+4) else LastPrintBuffEpos(ASMPOS);
  LastPrintBuff('db',['']);
  if options.mode32 then LastPrintBuffEpos(ARGPOS+4) else LastPrintBuffEpos(ARGPOS);
  // changed to single ? - 2.25
  if dblock=nil then begin
    LastPrintBuff('?',[''])
  end else if dblock.typ=uninitdata then begin
    LastPrintBuff('?',['']);
  end else begin
    LastPrintBuffHexValue(byte(mcode[0]));
    if isprint(mcode[0]) then begin
      LastPrintBuffEpos(COMMENTPOS);
      LastPrintBuff(';'+'''%s''',[mcode[0]]);
    end;
  end;
end;

{************************************************************************
* issegprefix                                                           *
* - returns true if byte is a segment prefix valid value                *
************************************************************************}
function tdisio.issegprefix(byt:byte):boolean;
begin
 if byt in[$2e,$36,$3e,$26,$64,$65] then result:=true else result:=false;
end;

{************************************************************************
* isprefix                                                              *
* - returns true if byte is a prefix valid value (rep/repne/lock)       *
************************************************************************}
function tdisio.isprefix(byt:byte):boolean;
begin
 if byt in[$f0,$f2,$f3] then result:=true else result:=false;
end;

// outprefix                                                             *
// - here we output a prefix segment override                            *
procedure tdisio.outprefix(prefixbyte:byte);
begin
  case prefixbyte of
   $2e:   LastPrintBuff('cs:',['']);
   $36:   LastPrintBuff('ss:',['']);
   $3e:   LastPrintBuff('ds:',['']);
   $26:   LastPrintBuff('es:',['']);
   $64:   LastPrintBuff('fs:',['']);
   $65:   LastPrintBuff('gs:',['']);
   $f0:   LastPrintBuff('lock ',['']);
   $f2:   LastPrintBuff('repne ',['']);
   $f3:   LastPrintBuff('rep ',['']);
   else   LastPrintBuff('err:',['']);
  end;
end;

// jumpback                                                              *
// - when the user presses ESC, or selects jump back we get the last     *
//   address from the top of the address stack and call setcuraddr and   *
//   update the window and so the disassembly listing flicks back        *
procedure tdisio.jumpback;
var outhere:lptr;
begin
  outhere:=retstack.pop;
  if outhere.s<>0 then setcuraddr(outhere);
  updatewindow;
end;

{************************************************************************
* jumpto                                                                *
* - more complex than the jumpback is the jumpto. The complexity lies   *
*   in deciding where we are jumping to and what the arguments value is *
*   and if the location exists. Actually making the jump consists of    *
*   saving the current location to the address stack and then changing  *
*   the curraddr for output, and updating the window                    *
* - most of this routine is a complex decipherment of a modrm address   *
*   to jump to                                                          *
* NB I need to stick this in a function of its own at some point, as it *
* would be quite useful to just get an argument address in several      *
* places in the code                                                    *
************************************************************************}
procedure tdisio.jumpto(arg1:boolean);
var
  tblock:pdsmitem;
  outhere:lptr;
  data:pchar;
  madejump:boolean;
  modrm,sib:byte;
  rm:word;
begin
  tblock:=findcurrentline;
  outhere.s:=0; outhere.o:=0;
  if tblock<>nil then if tblock.typ<>dsmcode then exit;
  madejump:=false;
  if tblock<>nil then begin
    if arg1 then
     case pasminstdata(tblock.tptr).arg1 of
      ARG_FADDR:
       begin
         data:=tblock.data+tblock.length;
         if tblock.mode32 then begin
           dec(data,6);
           outhere.s:=pw(@data[4])^;
           outhere.o:=pd(@data[0])^;
         end else begin
           dec(data,4);
           outhere.s:=pw(@data[2])^;
           outhere.o:=pd(@data[0])^;
         end;
         if dta.findseg(outhere)<>nil then begin
           retstack.push(curraddr);
           setcuraddr(outhere);
           updatewindow;
           madejump:=true;
         end;
       end;
      ARG_IMM32:
       if tblock.overrid=over_dsoffset then begin
         data:=tblock.data+tblock.length;
         dec(data,4);
         outhere.s:=options.dseg;
         outhere.o:=pd(@data[0])^;
         if dta.findseg(outhere)<>nil then begin
           retstack.push(curraddr);
           setcuraddr(outhere);
           updatewindow;
           madejump:=true;
         end;
       end;
      ARG_MEMLOC:
       begin
         data:=tblock.data+tblock.length;
         if options.mode32 then begin
           dec(data,4);
           outhere.s:=tblock.addr.s; outhere.o:=pd(@data[0])^;
         end else begin
           dec(data,2);
           outhere.s:=tblock.addr.s; outhere.o:=pw(@data[0])^;
         end;
         if dta.findseg(outhere)<>nil then begin
           retstack.push(curraddr);
           setcuraddr(outhere);
           updatewindow;
           madejump:=true;
         end;
       end;
      ARG_IMM:
       if tblock.overrid=over_dsoffset then begin
         if options.mode32 then begin
           data:=tblock.data+tblock.length;
           dec(data,4);
           outhere.s:=options.dseg;
           outhere.o:=pd(@data[0])^;
           if dta.findseg(outhere)<>nil then begin
             retstack.push(curraddr);
             setcuraddr(outhere);
             updatewindow;
             madejump:=true;
           end;
         end;
       end;
      ARG_RELIMM:
       begin
         data:=tblock.data+tblock.length;
         outhere:=tblock.addr;
         if tblock.mode32 then begin
           dec(data,4);
           inc(outhere.o,pd(@data[0])^+tblock.length);
         end else begin
           dec(data,2);
           inc(outhere.o,pw(@data[0])^+tblock.length);
         end;
         if dta.findseg(outhere)<>nil then begin
           retstack.push(curraddr);
           setcuraddr(outhere);
           updatewindow;
           madejump:=true;
         end;
       end;
      ARG_RELIMM8:
       begin
         data:=tblock.data+tblock.length-1;
         outhere:=tblock.addr;
         if tblock.mode32 then begin
           if byte(data[0]) and $80<>0 then
             inc(outhere.o,dword(data[0])+$ffffff00+tblock.length)
           else inc(outhere.o,dword(data[0])+tblock.length);
         end else begin
           if byte(data[0]) and $80<>0 then
             inc(outhere.o,word(data[0])+$ff00+tblock.length)
           else inc(outhere.o,word(data[0])+tblock.length);
         end;
         if dta.findseg(outhere)<>nil then begin
           retstack.push(curraddr);
           setcuraddr(outhere);
           updatewindow;
           madejump:=true;
         end;
       end;
      ARG_MMXMODRM,ARG_XMMMODRM,ARG_MODRM_S,ARG_MODRMM512,ARG_MODRMQ,
      ARG_MODRM_SREAL,ARG_MODRM_PTR,ARG_MODRM_WORD,ARG_MODRM_SINT,
      ARG_MODRM_EREAL,ARG_MODRM_DREAL,ARG_MODRM_WINT,ARG_MODRM_LINT,
      ARG_MODRM_BCD,ARG_MODRM_FPTR,ARG_MODRM:
       begin
         data:=tblock.data+tblock.modrm;
         rm:=(byte(data[0]) and $C0) shr 6;
         modrm:=byte(data[0]) and $07;
         case rm of
          0:
           begin
             if options.mode32 then begin
               if modrm=5 then begin
                 outhere.s:=tblock.addr.s;
                 outhere.o:=pd(@data[1])^;
               end else if modrm=4 then begin        // case 4=sib
                 sib:=byte(data[1]);
                 if (sib and $07)=5 then begin // disp32
                   outhere.s:=tblock.addr.s;
                   outhere.o:=pd(@data[2])^;
                 end;
               end;
             end else
               if modrm=6 then begin
                 outhere.s:=tblock.addr.s;
                 outhere.o:=pw(@data[1])^;
               end;
           end;
          1: ;
          2:
           begin
             if options.mode32 then begin
               outhere.s:=tblock.addr.s; outhere.o:=pd(@data[1])^;
               if modrm=4 then begin        // case 4=sib
                 outhere.s:=tblock.addr.s; outhere.o:=pd(@data[2])^;
               end;
             end else begin
               outhere.s:=tblock.addr.s; outhere.o:=pw(@data[1])^;
             end;
           end;
          3: ;
         end;
         if dta.findseg(outhere)<>nil then begin
           retstack.push(curraddr);
           setcuraddr(outhere);
           updatewindow;
           madejump:=true;
         end;
       end;
     else
  end;
  if not madejump then begin
   case pasminstdata(tblock.tptr).arg2 of
    ARG_IMM32:
     if tblock.overrid=over_dsoffset then begin
       data:=tblock.data+tblock.length;
       dec(data,4);
       outhere.s:=options.dseg;
       outhere.o:=pd(@data[0])^;
       if dta.findseg(outhere)<>nil then begin
         retstack.push(curraddr);
         setcuraddr(outhere);
         updatewindow;
       end;
     end;
    ARG_IMM:
     if tblock.overrid=over_dsoffset then begin
       if options.mode32 then begin
         data:=tblock.data+tblock.length;
         dec(data,4);
         outhere.s:=options.dseg;
         outhere.o:=pd(@data[0])^;
         if dta.findseg(outhere)<>nil then begin
           retstack.push(curraddr);
           setcuraddr(outhere);
           updatewindow;
         end;
       end;
     end;
    ARG_MEMLOC:
     begin
       data:=tblock.data+tblock.length;
       if options.mode32 then begin
         dec(data,4);
         outhere.s:=tblock.addr.s;
         outhere.o:=pd(@data[0])^;
       end else begin
         dec(data,2);
         outhere.s:=tblock.addr.s;
         outhere.o:=pd(@data[0])^;
       end;
       if dta.findseg(outhere)<>nil then begin
         retstack.push(curraddr);
         setcuraddr(outhere);
         updatewindow;
       end;
     end;
    ARG_MMXMODRM,ARG_XMMMODRM,ARG_MODRM_S,ARG_MODRMM512,ARG_MODRMQ,
    ARG_MODRM_SREAL,ARG_MODRM_PTR,ARG_MODRM_WORD,ARG_MODRM_SINT,
    ARG_MODRM_EREAL,ARG_MODRM_DREAL,ARG_MODRM_WINT,ARG_MODRM_LINT,
    ARG_MODRM_BCD,ARG_MODRM_FPTR,ARG_MODRM:
     begin
       data:=tblock.data+tblock.modrm;
       rm:=(byte(data[0]) and $C0) shr 6;
       modrm:=byte(data[0]) and $07;
       case rm of
        0:
         if options.mode32 then begin
           if modrm=5 then begin
             outhere.s:=tblock.addr.s;
             outhere.o:=pd(@data[1])^;
           end else if modrm=4 then begin        // case 4=sib
             sib:=byte(data[1]);
             if (sib and $07)=5 then begin // disp32
               outhere.s:=tblock.addr.s;
               outhere.o:=pd(@data[2])^;
             end;
           end;
         end else begin
           if modrm=6 then begin
             outhere.s:=tblock.addr.s;
             outhere.o:=pd(@data[1])^;
           end;
       end;
      1: ;
      2:
       if options.mode32 then begin
         outhere.s:=tblock.addr.s;
         outhere.o:=pd(@data[1])^;
         if modrm=4 then begin        // case 4=sib
           outhere.s:=tblock.addr.s;
           outhere.o:=pd(@data[2])^;
         end;
       end else begin
         outhere.s:=tblock.addr.s;
         outhere.o:=pw(@data[1])^;
       end;
      3: ;
     end;
     if dta.findseg(outhere)<>nil then begin
       retstack.push(curraddr);
       setcuraddr(outhere);
       updatewindow;
     end;
  end;
  end;
  end;
  end;
end;

{************************************************************************
* findcurrentline                                                       *
* - this routine finds the current screen address and output line in    *
*   the disassembly database and from there works out the disassembly   *
*   item on the currently selected line.                                *
* - it is used by jumpto, when the user presses return to follow a jump *
* - comments added to the procedure, it is a useful one to follow and   *
*   see the strategy employed, which is a fairly common Borg strategy   *
************************************************************************}
function tdisio.findcurrentline:pdsmitem;
var
  titem:tdsmitem;
  tblock:pdsmitem;
  outhere:lptr;
  i:dword;
  // strategy
  // - use pointer to first item if available (so comments,etc included in list
  // - otherwise use address.
begin
  titem.addr:=curraddr;
  titem.typ :=subitem;
  // hunt for current addr and subitem
  tblock:=pdsmitem(dsm.find(listitem(@titem)));
  if tblock<>nil then
    tblock:=pdsmitem(dsm.nextiterator);
  // on overlap - reset the curraddr.
  // [on the spot error correction]
  if tblock<>nil then begin
    if between(curraddr,tblock.addr,tblock.addr,tblock.length-1)
    then curraddr.o:=tblock.addr.o;
  end;
  // ensure we point to the right item, or the next one
  if tblock<>nil then begin
    if le(tblock.addr,curraddr)or(eq(tblock.addr,curraddr)and(tblock.typ<subitem))
    then tblock:=pdsmitem(dsm.nextiterator);
  end;
  // now at the top of the screen, the next loop moves down to the user selection line
  outhere:=curraddr;
  for i:=0 to usersel-1 do begin
    if tblock<>nil then begin
      if outhere.o=tblock.addr.o then begin
        inc(outhere.o,tblock.length);
        tblock:=pdsmitem(dsm.nextiterator);
      end else inc(outhere.o);
    end else inc(outhere.o);
    // check if gone beyond seg, get next seg.
    if dta.beyondseg(outhere) then begin
      dec(outhere.o);
      dta.nextseg(outhere);
    end;
    if outhere.s=0 then break;
  end;
  // now we either have the line we are pointing to, in the database
  // or we have moved beyond the database and have a null
  // or we have an address which would be a db
  if tblock<>nil then if outhere.o<>tblock.addr.o then begin result:=nil; exit; end;
  result:=tblock;
end;

{************************************************************************
* findcurrentaddr                                                       *
* - this is very similar to findcurrentline, but it instead finds just  *
*   the location. the search strategy is the same                       *
************************************************************************}
procedure tdisio.findcurrentaddr(var loc:lptr);
var
  titem:tdsmitem;
  tblock:pdsmitem;
  outhere:lptr;
  i:dword;
begin
  // strategy
  // - use pointer to first item if available (so comments,etc included in list
  // - otherwise use address.
  titem.addr:=curraddr;
  titem.typ :=subitem;
  dsm.find(listitem(@titem));
  tblock:=pdsmitem(dsm.nextiterator);
  if tblock<>nil then begin
    if between(curraddr,tblock.addr,tblock.addr,tblock.length-1)
    then curraddr.o:=tblock.addr.o;
  end;
  if tblock<>nil then begin
    if tblock.addr.o<curraddr.o then tblock:=pdsmitem(dsm.nextiterator);
  end;
  // added 2.25 - bugfix - wasnt find correct lines when in mid-line...
  if tblock<>nil then begin
    while eq(tblock.addr,curraddr)and(tblock.typ<subitem) do begin
      tblock:=pdsmitem(dsm.nextiterator);
      if tblock=nil then break;
    end;
  end;
  outhere:=curraddr;
  for i:=0 to usersel-1 do begin
    if tblock<>nil then begin
      if outhere.o=tblock.addr.o then begin
        inc(outhere.o,tblock.length);
        tblock:=pdsmitem(dsm.nextiterator);
      end else inc(outhere.o);
    end else inc(outhere.o);
    // check if gone beyond seg, get next seg.
    if dta.beyondseg(outhere) then begin
      dec(outhere.o);
      dta.nextseg(outhere);
    end;
    if outhere.s=0 then break;
  end;
  if outhere.s<>0 then begin
    loc.s:=outhere.s; loc.o:=outhere.o;
  end else begin
    loc.s:=curraddr.s; loc.o:=curraddr.o;
  end;
end;

// savecuraddr                                                           *
// - this simply saves the window top line location to the return stack  *
// - this is called when the user selects to jump somewhere (like to a   *
//   named location) rather than the 'jumpto' routine used to jump to a  *
//   location specified by a disassembly argument                        *
procedure tdisio.savecuraddr;
begin
  retstack.push(curraddr);
end;

{************************************************************************
* updatewindowifwithinrange                                             *
* - adds a scheduler task for a window update if the current window     *
*   overlaps with the specified range                                   *
************************************************************************}
procedure tdisio.updatewindowifwithinrange(loc_start,loc_end:lptr);
begin
  if greq(loc_end,curraddr) and leeq(loc_start,outend)
  then scheduler.addtask(windowupdate,priority_window,nlptr,0,nil);
end;

{************************************************************************
* updatewindowifinrange                                                 *
* - adds a scheduler task for a window update if the current window     *
*   contains the loc specified                                          *
************************************************************************}
procedure tdisio.updatewindowifinrange(loc:lptr);
begin
  if between(loc,curraddr,outend,0)
  then scheduler.addtask(windowupdate,priority_window,nlptr,0,nil);
end;

// updatewindow                                                          *
// - this function rewrites the buffers for the disassembly output to    *
//   the window, and then requests a screen refresh which will paint the *
//   buffers into the window. The ClearBuff and DoneBuff functions       *
//   when the buffers are full and it is safe to refresh the screen with *
//   a repaint                                                           *
procedure tdisio.updatewindow;
var
  titem:tdsmitem;
  tblock:pdsmitem;
  outhere:lptr;
  i:integer;
begin
  // find current position.
  titem.addr:=curraddr;
  titem.typ :=subitem;
  tblock:=pdsmitem(dsm.find(listitem(@titem)));
  if tblock<>nil then
    tblock:=pdsmitem(dsm.nextiterator);
  // now tblock= current position, or previous one.
  // check if in middle of instruction
  if tblock<>nil then begin
    // bugfix 2.27
    if tblock.length>1 then begin
      if between(curraddr,tblock.addr,tblock.addr,tblock.length-1) then begin
        curraddr.o:=tblock.addr.o;
        subitem:=tblock.typ;
      end;
    end;
  end;
  // check if previous one. get next
  if tblock<>nil then begin
    if (tblock.addr.o<curraddr.o)or
      ((tblock.addr.o=curraddr.o)and(tblock.typ<subitem))
    then tblock:=pdsmitem(dsm.nextiterator);
  end;
  // tblock is now top of the page.
  outhere:=curraddr;
  ClearBuff;                        // start again
  for i:=0 to buffer_lines-1 do begin
    if tblock<>nil then begin
      if outhere.o=tblock.addr.o then begin
        case tblock.typ of
         dsmcode:    outinst(tblock,true);
         dsmnameloc:
          begin
            printlineheader(tblock.addr,true);
            LastPrintBuff('%s:',[strpas(tblock.data)]);
          end;
         dsmxref:
          begin
            printlineheader(tblock.addr,true);
            LastPrintBuff(';',['']);
            LastPrintBuffEpos(COMMENTPOS);
            LastPrintBuff('XREFS First: ',['']);
            xrefs.printfirst(tblock.addr);
          end;
         else
           printlineheader(tblock.addr,true);
           outcomment(tblock);
        end;
        inc(outhere.o,tblock.length);
        tblock:=pdsmitem(dsm.nextiterator);
      end else begin
        outdb(outhere,TRUE);
        inc(outhere.o);
      end;
    end else begin
      outdb(outhere,TRUE);
      inc(outhere.o);
    end;
    // check if gone beyond seg, get next seg.
    if dta.beyondseg(outhere) then begin
      dec(outhere.o);
      dta.nextseg(outhere);
    end;
    if outhere.s=0 then break else outend:=outhere;
  end;
  DoneBuff;                         // mark as done
  InvalidateRect(mainwindow,nil,TRUE);
end;

// scroller                                                              *
// - this routine controls simple vertical scrolls. A vertical scroll is *
//   a movement of the currently selected line. Only is this line moves  *
//   beyond the boundaries of the window do we need to move the windowed *
//   disassembly output itself. Simple moves are handled quickly, and if *
//   we need to regenerate the buffers then we first recalculate the top *
//   position and then we call windowupdate to handle the rest.          *
procedure tdisio.scroller(amount:dword);
var
  titem:tdsmitem;
  tblock:pdsmitem;
  r:tRECT;
  sbarpos:single;
begin
  // simple move on screen
  if (amount=1)and(usersel<=nScreenRows-3) then begin
    inc(usersel);
    r.left:=0;
    r.right:=rrr;
    r.top:=(usersel-1)*cyc;
    r.bottom:=(usersel+1)*cyc;
    InvalidateRect(mainwindow,@r,TRUE);
    exit;
  end;
  // simple move on screen
  if (amount=dword(-1))and(usersel<>0) then begin
    dec(usersel);
    r.left:=0;
    r.right:=rrr;
    r.top:=usersel*cyc;
    r.bottom:=(usersel+2)*cyc;
    InvalidateRect(mainwindow,@r,TRUE);
    exit;
  end;
  // find top of page
  titem.addr:=curraddr;
  titem.typ :=subitem;
  tblock:=pdsmitem(dsm.find(listitem(@titem)));
  // tblock is now top of page or previous item.
  // if moving up find previous inst
  if amount<100 then
    if tblock<>nil then
      tblock:=pdsmitem(dsm.nextiterator);
  if(amount>100) and (tblock<>nil) then begin
    if eq(tblock.addr,titem.addr)and(tblock.typ=subitem)
    then tblock:=pdsmitem(dsm.lastiterator);
  end;
  // move up - tblock=previous inst.
  // if moving down, check if tblock=previous item.
  if(amount<100) and (tblock<>nil) then begin
    if le(tblock.addr,curraddr)or(eq(tblock.addr,curraddr)and(tblock.typ<subitem))
    then tblock:=pdsmitem(dsm.nextiterator);
  end;
  // moving down - tblock=current top.
  if amount<100 then begin
    while amount<>0 do begin
      if usersel<=nScreenRows-3 then inc(usersel)
      else begin
        if tblock<>nil then begin
          if curraddr.o=tblock.addr.o then begin
            inc(curraddr.o,tblock.length);
            tblock:=pdsmitem(dsm.nextiterator);
            if tblock<>nil then begin
              if curraddr.o=tblock.addr.o then subitem:=tblock.typ
              else subitem:=dsmcode;
            end else subitem:=dsmcode;
          end else begin
            subitem:=dsmnull;
            inc(curraddr.o);
          end;
        end else begin
          subitem:=dsmnull;
          inc(curraddr.o);
        end;
        // check if gone beyond seg, get next seg.
        if dta.beyondseg(curraddr) then begin
          dec(curraddr.o);
          dta.nextseg(curraddr);
          subitem:=dsmnull;
        end;
        if curraddr.s=0 then break;
        titem.addr:=curraddr;
      end;
      dec(amount);
    end //while
  end else begin
    while amount<>0 do begin
      if usersel<>0 then dec(usersel) else begin
        if tblock<>nil then begin
          if curraddr.o=tblock.addr.o+tblock.length then begin
            dec(curraddr.o,tblock.length);
            subitem:=tblock.typ;
            tblock:=pdsmitem(dsm.lastiterator);
          end else begin
            subitem:=dsmcode;
            dec(curraddr.o);
          end;
        end else begin
          subitem:=dsmnull;
          dec(curraddr.o);
        end;
        // check if gone beyond seg, get next seg.
        if dta.beyondseg(curraddr) then begin
          inc(curraddr.o); //??
          dta.lastseg(curraddr);
        end;
        if curraddr.s=0 then break;
        titem.addr:=curraddr;
      end;
      inc(amount);
    end; //while
  end;
  if curraddr.s=0 then curraddr:=titem.addr;
  updatewindow;
  current_data_pos:=dta.datagetpos(curraddr);
  sbarpos:=(current_data_pos / (total_data_size+1.0))*VERTSCROLLRANGE;
  SetScrollPos(mainwindow,SB_VERT,round(sbarpos),TRUE);
end;

// outargs                                                               *
// - this is a very long routine which handles every kind of argument    *
//   that we have set up in the processor tables. It outputs the ascii   *
//   form of the instructions arguments to the buffer. It handles        *
//   complex modrm and sib encodings, the display of names and locations *
//   which must be decoded, etc.                                         *
procedure tdisio.outargs(inst:pdsmitem; a:argtype);
var
  dta:pchar;
  modrm,sib:byte;
  // rm extended to word. build 15. re M Ogden and VC++ warnings.
  rm:word;
  a1,a2:argtype;
  targetd:dword;
  targetw:dword;
  loc:lptr;
  fbuff:array[0..40] of char;
  i,sp:integer;
  pbyte:byte; // prefix byte.
  prefixptr:integer;
begin
  pbyte:=0;
  if inst.flags and FLAGS_SEGPREFIX<>0 then begin
    prefixptr:=0;
    while not issegprefix(byte(inst.data[prefixptr]))and(prefixptr<15) do inc(prefixptr);
    pbyte:=byte(inst.data[prefixptr]);
  end;
  if inst.flags and FLAGS_ADDRPREFIX<>0 then options.mode32:= not options.mode32;
  case a of
   ARG_REG_AX:
     if inst.mode32 then LastPrintBuff('eax',['']) else LastPrintBuff('ax',['']);
   ARG_REG_BX:
     if inst.mode32 then LastPrintBuff('ebx',['']) else LastPrintBuff('bx',['']);
   ARG_REG_CX:
     if inst.mode32 then LastPrintBuff('ecx',['']) else LastPrintBuff('cx',['']);
   ARG_REG_DX:
     if inst.mode32 then LastPrintBuff('edx',['']) else LastPrintBuff('dx',['']);
   ARG_16REG_DX: LastPrintBuff('dx',['']);
   ARG_REG_SP:
     if inst.mode32 then LastPrintBuff('esp',['']) else LastPrintBuff('sp',['']);
   ARG_REG_BP:
     if inst.mode32 then LastPrintBuff('ebp',['']) else LastPrintBuff('bp',['']);
   ARG_REG_SI:
     if inst.mode32 then LastPrintBuff('esi',['']) else LastPrintBuff('si',['']);
   ARG_REG_DI:
     if inst.mode32 then LastPrintBuff('edi',['']) else LastPrintBuff('di',['']);
   ARG_REG_AL:    LastPrintBuff('al',['']);
   ARG_REG_AH:    LastPrintBuff('ah',['']);
   ARG_REG_BL:    LastPrintBuff('bl',['']);
   ARG_REG_BH:    LastPrintBuff('bh',['']);
   ARG_REG_CL:    LastPrintBuff('cl',['']);
   ARG_REG_CH:    LastPrintBuff('ch',['']);
   ARG_REG_DL:    LastPrintBuff('dl',['']);
   ARG_REG_DH:    LastPrintBuff('dh',['']);
   ARG_REG_ST0:   LastPrintBuff('st(0)',['']);
   ARG_REG_ES:    LastPrintBuff('es',['']);
   ARG_REG_CS:    LastPrintBuff('cs',['']);
   ARG_REG_DS:    LastPrintBuff('ds',['']);
   ARG_REG_SS:    LastPrintBuff('ss',['']);
   ARG_REG_FS:    LastPrintBuff('fs',['']);
   ARG_REG_GS:    LastPrintBuff('gs',['']);
   ARG_REG_A:     LastPrintBuff('a',['']);
   ARG_REG_B:     LastPrintBuff('b',['']);
   ARG_REG_C:     LastPrintBuff('c',['']);
   ARG_REG_D:     LastPrintBuff('d',['']);
   ARG_REG_E:     LastPrintBuff('e',['']);
   ARG_REG_H:     LastPrintBuff('h',['']);
   ARG_REG_L:     LastPrintBuff('l',['']);
   ARG_REG_I:     LastPrintBuff('i',['']);
   ARG_REG_R:     LastPrintBuff('r',['']);
   ARG_REG_HL_IND:LastPrintBuff('(hl)',['']);
   ARG_REG_BC:    LastPrintBuff('bc',['']);
   ARG_REG_DE:    LastPrintBuff('de',['']);
   ARG_REG_HL:    LastPrintBuff('hl',['']);
   ARG_REG_BC_IND:LastPrintBuff('(bc)',['']);
   ARG_REG_DE_IND:LastPrintBuff('(de)',['']);
   ARG_REG_SP_IND:LastPrintBuff('(sp)',['']);
   ARG_REG_IX:    LastPrintBuff('ix',['']);
   ARG_REG_IX_IND:
    begin
      LastPrintBuff('(ix',['']);
      if inst.flags and FLAGS_INDEXREG<>0 then begin
        dta:=inst.data+2;
        LastPrintBuff('+',['']);
        LastPrintBuffLongHexValue(word(dta[0]));
      end; LastPrintBuff(')',['']);
    end;
   ARG_REG_IY:     LastPrintBuff('iy',['']);
   ARG_REG_IY_IND:
    begin
      LastPrintBuff('(iy',['']);
      if inst.flags and FLAGS_INDEXREG<>0 then begin
        dta:=inst.data+2;
        LastPrintBuff('+',['']);
        LastPrintBuffLongHexValue(word(dta[0]));
      end; LastPrintBuff(')',['']);
    end;
   ARG_REG_C_IND: LastPrintBuff('(c)',['']);
   ARG_REG_AF:    LastPrintBuff('af',['']);
   ARG_REG_AF2:   LastPrintBuff('af''',['']);
   ARG_IMM:
    begin
      dta:=inst.data+inst.length;
      if inst.mode32 then begin
        dec(dta,4);
        case inst.overrid of
         over_decimal:
          if inst.displayflags and DISPFLAG_NEGATE<>0 then
            LastPrintBuff('-%2.2d',[0-pd(@dta[0])^])
          else LastPrintBuff('%2.2d',[pd(@dta[0])^]);
         over_char:
          begin
           LastPrintBuff('''',['']);
           for i:=3 downto 0 do if dta[i]<>#0 then LastPrintBuff('%s',[dta[i]]);
           LastPrintBuff('''',['']);
          end;
         over_dsoffset:
          begin
            loc.s:=inst.addr.s;
            loc.o:=pd(@dta[0])^;
            LastPrintBuff('offset ',['']);
            if nam.isname(loc) then nam.printname(loc)
            else if import.isname(loc) then import.printname(loc)
            else if expt.isname(loc) then expt.printname(loc)
            else LastPrintBuffLongHexValue(pd(@dta[0])^);
          end;
         over_single: LastPrintBuff('(float)%g',[pfloat(dta[0])^]);
         else
           if inst.displayflags and DISPFLAG_NEGATE<>0 then begin
             LastPrintBuff('-',['']);
             LastPrintBuffLongHexValue(0-pd(@dta[0])^);
           end else
             LastPrintBuffLongHexValue(pd(@dta[0])^);
        end;
      end else begin
        dec(dta,2);
        if inst.overrid=over_decimal then begin
          if inst.displayflags and DISPFLAG_NEGATE<>0 then
            LastPrintBuff('-%2.2d',[$10000-pw(@dta[0])^])
          else LastPrintBuff('%2.2d',[pw(@dta[0])^]);
        end else if inst.overrid=over_char then begin
          LastPrintBuff('''',['']);
          for i:=1 downto 0 do if dta[i]<>#0 then LastPrintBuff('%s',[dta[i]]);
           LastPrintBuff('''',['']);
        end else if inst.displayflags and DISPFLAG_NEGATE<>0 then begin
          LastPrintBuff('-',['']);
          LastPrintBuffLongHexValue($10000-pw(@dta[0])^);
        end else
          LastPrintBuffLongHexValue(pw(@dta[0])^);
      end;
    end;
   ARG_IMM_SINGLE:
    begin
      dta:=inst.data+inst.length-4;
      LastPrintBuff('%g',[pfloat(dta[0])^]);
    end;
   ARG_IMM_DOUBLE:
    begin
      dta:=inst.data+inst.length-8;
      LastPrintBuff('%g',[pdouble(dta[0])^]);
    end;
   ARG_IMM_LONGDOUBLE:
    begin
      dta:=inst.data+inst.length-10;
      LastPrintBuff('%Lg',[pextended(dta[0])^]);
    end;
   ARG_IMM32:
    begin
      dta:=inst.data+inst.length-4;
      case inst.overrid of
       over_decimal:
         if inst.displayflags and DISPFLAG_NEGATE<>0 then
           LastPrintBuff('-%2.2d',[0-pd(@dta[0])^])
         else LastPrintBuff('%2.2d',[pd(@dta[0])^]);
       over_char:
        begin
          LastPrintBuff('''',['']);
          for i:=3 downto 0 do if dta[i]<>#0 then LastPrintBuff('%s',[dta[i]]);
          LastPrintBuff('''',['']);
        end;
       over_dsoffset:
        begin
          loc.s:=inst.addr.s;
          loc.o:=pd(@dta[0])^;
          LastPrintBuff('offset ',['']);
          if nam.isname(loc) then nam.printname(loc)
          else if import.isname(loc) then import.printname(loc)
          else if expt.isname(loc) then expt.printname(loc)
          else LastPrintBuffLongHexValue(loc.o);
        end;
       over_single: LastPrintBuff('(float)%g',[pfloat(dta[0])^]);
       else
          if inst.displayflags and DISPFLAG_NEGATE<>0 then begin
            LastPrintBuff('-',['']);
            LastPrintBuffLongHexValue(0-pd(@dta[0])^);
          end else
            LastPrintBuffLongHexValue(pd(@dta[0])^);
        end;
      end;
   ARG_STRING:
    begin
      LastPrintBuff('"',['']);
      rm:=0; sp:=0;
      while inst.data[rm]<>#0 do begin
        if inst.data[rm]<#32 then begin
          LastPrintBuff('",',['']);
          LastPrintBuffHexValue(byte(inst.data[rm]));
          LastPrintBuff(',"',['']);
        end else
          LastPrintBuff('%s',[inst.data[rm]]);
        inc(rm); inc(sp);
        if sp>max_stringprint then break;
      end;
      LastPrintBuff('",00h',['']);
    end;
   ARG_PSTRING:
    begin
      dta:=inst.data;
      rm:=byte(dta[0]);
      inc(dta);
      LastPrintBuffHexValue(byte(rm));
      LastPrintBuff(',"',['']);
      sp:=0;
      while rm<>0 do begin
        if dta[0]<#32 then begin
          LastPrintBuff('",',['']);
          LastPrintBuffHexValue(byte(dta[0]));
          LastPrintBuff(',"',['']);
        end else
          LastPrintBuff('%s',[dta[0]]);
        inc(dta);
        dec(rm);
        inc(sp);
        if sp>max_stringprint then break
      end;
      LastPrintBuff('"',['']);
    end;
   ARG_DOSSTRING:
    begin
      dta:=inst.data;
      rm:=inst.length;
      dec(rm);
      sp:=0;
      LastPrintBuff('"',['']);
      while rm<>0 do begin
        if inst.data[rm]<#32 then begin
          LastPrintBuff('",',['']);
          LastPrintBuffHexValue(byte(inst.data[rm]));
          LastPrintBuff(',"',['']);
        end else
          LastPrintBuff('%s',[dta[0]]);
        inc(dta);
        dec(rm);
        inc(sp);
        if sp>max_stringprint then break
      end;
      LastPrintBuff('"',['']);
    end;
   ARG_CUNICODESTRING:
    begin
      dta:=inst.data;
      rm:=inst.length;
      dec(rm,2);
      sp:=0;
      LastPrintBuff('"',['']);
      while rm<>0 do begin
        if dta[0]<#32 then begin
          LastPrintBuff('",',['']);
          LastPrintBuffHexValue(byte(dta[0]));
          LastPrintBuff(',"',['']);
        end else
          LastPrintBuff('%s',[dta[0]]);
        inc(dta,2);
        dec(rm,2);
        inc(sp);
        if sp>max_stringprint then break
      end;
      LastPrintBuff('"',['']);
    end;
   ARG_PUNICODESTRING:
    begin
      dta:=inst.data+2;
      rm:=inst.length;
      dec(rm,2);
      sp:=0;
      LastPrintBuffHexValue(rm div 2);
      LastPrintBuff(',"',['']);
      while rm<>0 do begin
        if dta[0]<#32 then begin
          LastPrintBuff('",',['']);
          LastPrintBuffHexValue(byte(dta[0]));
          LastPrintBuff(',"',['']);
        end else
          LastPrintBuff('%s',[dta[0]]);
        inc(dta,2);
        dec(rm,2);
        inc(sp);
        if sp>max_stringprint then break
      end;
      LastPrintBuff('"',['']);
    end;
   ARG_MEMLOC:
    begin
      if inst.flags and FLAGS_SEGPREFIX<>0 then outprefix(pbyte);
      dta:=inst.data+inst.length;
      if options.mode32 then begin
        dec(dta,4);
        loc.s:=inst.addr.s;
        loc.o:=pd(@dta[0])^;
        if inst.flags and FLAGS_8BIT<>0 then
          LastPrintBuff('byte ptr',[''])
        else if inst.flags and FLAGS_ADDRPREFIX<>0 then
          LastPrintBuff('word ptr',[''])
        else
          LastPrintBuff('dword ptr',['']);
        LastPrintBuff(' [',['']);
        if nam.isname(loc) then nam.printname(loc)
        else if import.isname(loc) then import.printname(loc)
        else if expt.isname(loc) then expt.printname(loc)
        else LastPrintBuffLongHexValue(loc.o);
        LastPrintBuff(']',['']);
      end else begin
        dec(dta,2);
        loc.s:=inst.addr.s;
        loc.o:=pw(@dta[0])^;
        if inst.flags and FLAGS_8BIT<>0 then
          LastPrintBuff('byte ptr',[''])
        else if inst.flags and FLAGS_ADDRPREFIX<>0 then
          LastPrintBuff('dword ptr',[''])
        else
          LastPrintBuff('word ptr',['']);
        LastPrintBuff(' [',['']);
        if nam.isname(loc) then nam.printname(loc)
        else if import.isname(loc) then import.printname(loc)
        else if expt.isname(loc) then expt.printname(loc)
        else LastPrintBuffLongHexValue(loc.o);
        LastPrintBuff(']',['']);
      end;
    end;
   ARG_MEMLOC16:
    begin
      if inst.flags and FLAGS_SEGPREFIX<>0 then outprefix(pbyte);
      dta:=inst.data+inst.length-2;
      if options.processor=PROC_Z80 then begin
        loc.s:=inst.addr.s;
        loc.o:=pd(@dta[0])^;
        LastPrintBuff('[',['']);
        if nam.isname(loc) then nam.printname(loc)
        else if import.isname(loc) then import.printname(loc)
        else if expt.isname(loc) then expt.printname(loc)
        else LastPrintBuffLongHexValue(loc.o);
        LastPrintBuff(']',['']);
      end else begin
        loc.s:=inst.addr.s;
        loc.o:=pw(@dta[0])^;
        LastPrintBuff('[',['']);
        if nam.isname(loc) then nam.printname(loc)
        else if import.isname(loc) then import.printname(loc)
        else if expt.isname(loc) then expt.printname(loc)
        else LastPrintBuffLongHexValue(loc.o);
        LastPrintBuff(']',['']);
      end;
    end;
   ARG_SIMM8:
    begin
      dta:=inst.data+inst.length-1;
      if inst.overrid=over_char then begin
        LastPrintBuff('''',['']);
        for i:=0 downto 0 do if dta[i]<>#0 then LastPrintBuff('%s',[dta[i]]);
        LastPrintBuff('''',['']);
      end else if byte(dta[0]) and $80<>0 then begin
        if inst.overrid=over_decimal then
         LastPrintBuff('%2.2d',[word($100)-byte(dta[0])])
        else begin
          LastPrintBuff('-',['']);
          LastPrintBuffLongHexValue(word($100)-byte(dta[0]));
        end;
      end else begin if inst.overrid=over_decimal then
         LastPrintBuff('%2.2d',[byte(dta[0])])
        else LastPrintBuffLongHexValue(word(dta[0]));
      end;
    end;
   ARG_IMM8:
    begin
      dta:=inst.data+inst.length-1;
      if inst.overrid=over_decimal then begin
        if inst.displayflags and DISPFLAG_NEGATE<>0 then begin
          LastPrintBuff('-',['']);
          LastPrintBuffLongHexValue($100-word(dta[0]));
        end else
          LastPrintBuffLongHexValue(word(dta[0]));
      end else if inst.overrid=over_char then begin
        LastPrintBuff('''',['']);
        for i:=0 downto 0 do if dta[i]<>#0 then LastPrintBuff('%s',[dta[i]]);
        LastPrintBuff('''',['']);
      end else begin
        if inst.displayflags and DISPFLAG_NEGATE<>0 then begin
          LastPrintBuff('-',['']);
          LastPrintBuffLongHexValue($100-word(dta[0]));
        end else
          LastPrintBuffLongHexValue(word(dta[0]));
      end;
    end;
   ARG_IMM8_IND:
    begin
      dta:=inst.data+inst.length-1;
      LastPrintBuff('(',['']);
      LastPrintBuffLongHexValue(word(dta[0]));
      LastPrintBuff(')',['']);
    end;
   ARG_IMM16:
    begin
      dta:=inst.data+inst.length-2;
      if inst.overrid=over_decimal then begin
        if inst.displayflags and DISPFLAG_NEGATE<>0 then begin
          LastPrintBuff('-',['']);
          LastPrintBuffLongHexValue($10000-pw(@dta[0])^);
        end else
          LastPrintBuffLongHexValue(pw(@dta[0])^);
      end else if inst.overrid=over_char then begin
        LastPrintBuff('''',['']);
        for i:=1 downto 0 do if dta[i]<>#0 then LastPrintBuff('%s',[dta[i]]);
        LastPrintBuff('''',['']);
      end else begin
        if inst.displayflags and DISPFLAG_NEGATE<>0 then begin
          LastPrintBuff('-',['']);
          LastPrintBuffLongHexValue($10000-pw(@dta[0])^);
        end else
          LastPrintBuffLongHexValue(pw(@dta[0])^);
      end;
    end;
   ARG_IMM16_A:
    begin
      dta:=inst.data+inst.length-3;
      LastPrintBuffLongHexValue(pw(@dta[0])^);
    end;
   ARG_RELIMM8:
    begin
      dta:=inst.data+inst.length-1;
      if inst.mode32 then begin
        if byte(dta[0]) and $80<>0 then
         targetd:=dword(dta[0])+$ffffff00+inst.addr.o+inst.length
        else targetd:=dword(dta[0])+inst.addr.o+inst.length;
        loc.s:=inst.addr.s;
        loc.o:=targetd;
        if nam.isname(loc) then nam.printname(loc)
        else if import.isname(loc) then import.printname(loc)
        else if expt.isname(loc) then expt.printname(loc)
        else LastPrintBuffLongHexValue(loc.o);
      end else begin
        if byte(dta[0]) and $80<>0 then
          targetw:=word(dta[0])+$ff00+inst.addr.o+inst.length
        else targetw:=word(dta[0])+inst.addr.o+inst.length;
        loc.s:=inst.addr.s;
        loc.o:=targetw;
        if nam.isname(loc) then nam.printname(loc)
        else if import.isname(loc) then import.printname(loc)
        else if expt.isname(loc) then expt.printname(loc)
        else LastPrintBuffLongHexValue(loc.o);
      end;
    end;
   ARG_RELIMM:
    begin
      dta:=inst.data+inst.length;
      if inst.mode32 then begin
        dec(dta,4);
        targetd:=pd(@dta[0])^;
        inc(targetd,inst.addr.o);
        inc(targetd,inst.length);
        loc.s:=inst.addr.s;
        loc.o:=targetd;
        if nam.isname(loc) then nam.printname(loc)
        else if import.isname(loc) then import.printname(loc)
        else if expt.isname(loc) then expt.printname(loc)
        else LastPrintBuffLongHexValue(loc.o);
      end else begin
        dec(dta,2);
        targetw:=pw(@dta[0])^+inst.addr.o+inst.length;
        loc.s:=inst.addr.s;
        loc.o:=targetw;
        if nam.isname(loc) then nam.printname(loc)
        else if import.isname(loc) then import.printname(loc)
        else if expt.isname(loc) then expt.printname(loc)
        else LastPrintBuffLongHexValue(loc.o);
      end;
    end;
   ARG_REG:
    begin
      dta:=inst.data+inst.modrm;
      if options.processor=PROC_Z80 then LastPrintBuff(regzascii[byte(dta[0]) and $07],[''])
      else if pasminstdata(inst.tptr).flags and FLAGS_8BIT<>0
      then LastPrintBuff(reg8ascii[(byte(dta[0]) shr 3) and $07],[''])
      else if inst.mode32
      then LastPrintBuff(reg32ascii[(byte(dta[0]) shr 3) and $07],[''])
      else LastPrintBuff(reg16ascii[(byte(dta[0]) shr 3) and $07],['']);
    end;
   ARG_MREG:
    begin
      dta:=inst.data+inst.modrm;
      LastPrintBuff(regmascii[(byte(dta[0]) shr 3) and 07],['']);
    end;
   ARG_XREG:
    begin
      dta:=inst.data+inst.modrm;
      LastPrintBuff(regxascii[(byte(dta[0]) shr 3) and $07],['']);
    end;
   ARG_FREG:
    begin
      dta:=inst.data+inst.modrm;
      LastPrintBuff(regfascii[byte(dta[0]) and $07],['']);
    end;
   ARG_SREG:
    begin
      dta:=inst.data+inst.modrm;
      LastPrintBuff(regsascii[(byte(dta[0]) shr 3) and $07],['']);
    end;
   ARG_CREG:
    begin
      dta:=inst.data+inst.modrm;
      LastPrintBuff(regcascii[(byte(dta[0]) shr 3) and $07],['']);
    end;
   ARG_DREG:
    begin
      dta:=inst.data+inst.modrm;
      LastPrintBuff(regdascii[(byte(dta[0]) shr 3) and $07],['']);
    end;
   ARG_TREG,
   ARG_TREG_67:
    begin
      dta:=inst.data+inst.modrm;
      LastPrintBuff(regtascii[(byte(dta[0]) shr 3) and $07],['']);
    end;
   ARG_MODREG,
   ARG_MMXMODRM,
   ARG_XMMMODRM,
   ARG_MODRM8,
   ARG_MODRM16,
   ARG_MODRM_S,
   ARG_MODRMM512,
   ARG_MODRMQ,
   ARG_MODRM_SREAL,
   ARG_MODRM_PTR,
   ARG_MODRM_WORD,
   ARG_MODRM_BCD,
   ARG_MODRM_SINT,
   ARG_MODRM_EREAL,
   ARG_MODRM_DREAL,
   ARG_MODRM_WINT,
   ARG_MODRM_LINT,
   ARG_MODRM_FPTR,
   ARG_MODRM:
    begin
      dta:=@inst.data[inst.modrm];
      rm:=(byte(dta[0]) and $c0) shr 6;
      modrm:=byte(dta[0]) and $07;
      a1:=pasminstdata(inst.tptr).arg1;
      a2:=pasminstdata(inst.tptr).arg2;
      sib:=byte(dta[1]);
      if (a1=ARG_IMM)or(a2=ARG_IMM)or(a1=ARG_IMM8)or(a2=ARG_IMM8)or(a2=ARG_NONE)
        or(a1=ARG_SIMM8)or(a2=ARG_SIMM8)
        or((modrm=5)and(rm=0))or((modrm=4)and(rm=2)and(((sib)and $07)=5))
        or((modrm=4)and(rm=0)and(((sib)and $07)=5))
      then begin
        if rm<3 then begin
          case a of
           ARG_MODRM8:       LastPrintBuff('byte ptr ',['']);
           ARG_MODRM16,
           ARG_MODRM_WORD:   LastPrintBuff('word ptr ',['']);
           ARG_MMXMODRM,
           ARG_XMMMODRM:     LastPrintBuff('dword ptr ',['']);
           ARG_MODRMQ:       LastPrintBuff('qword ptr ',['']);
           ARG_MODRM_S:      LastPrintBuff('fword ptr ',['']);// 6 bytes=fword
           ARG_MODRM_SREAL:  LastPrintBuff('dword ptr ',['']);// single real=4 bytes=dword
           ARG_MODRM_BCD:    LastPrintBuff('tbyte ptr ',['']);// packed bcd=10 bytes=tbyte
           ARG_MODRM_SINT:   LastPrintBuff('dword ptr ',['']);// short int=4 bytes
           ARG_MODRM_WINT:   LastPrintBuff('word ptr ',['']); // word int =2 bytes
           ARG_MODRM_LINT:   LastPrintBuff('qword ptr ',['']);// long int = 8 bytes
           ARG_MODRMM512:    LastPrintBuff('byte ptr ',['']); // points to 512 bits=64 bytes of memory...
           ARG_MODRM_EREAL:  LastPrintBuff('tbyte ptr ',['']);// extended real=10 bytes
           ARG_MODRM_DREAL:  LastPrintBuff('qword ptr ',['']);// double real=8 bytes
           ARG_MODRM:
            begin
              if inst.flags and FLAGS_8BIT<>0 then LastPrintBuff('byte ptr ',[''])
              else if inst.mode32 then LastPrintBuff('dword ptr ',[''])
              else LastPrintBuff('word ptr ',['']);
            end;
          end;
        end;
      end else if (a1=ARG_REG)or(a2=ARG_REG) then begin
        if rm<3 then begin
          case a of               // re movzx, movsx type instructions
           ARG_MODRM8:  LastPrintBuff('byte ptr ',['']);
           ARG_MODRM16: LastPrintBuff('word ptr ',['']);
          end;
        end;
      end;
      case rm of
       0:
        begin
          if inst.flags and FLAGS_SEGPREFIX<>0 then outprefix(pbyte);
          if options.mode32 then begin
            if modrm=5 then begin
              loc.s:=inst.addr.s;
              loc.o:=pd(@dta[1])^;
              LastPrintBuff('[',['']);
              if nam.isname(loc) then nam.printname(loc)
              else if import.isname(loc) then import.printname(loc)
              else if expt.isname(loc) then expt.printname(loc)
              else LastPrintBuffLongHexValue(loc.o);
              LastPrintBuff(']',['']);
            end else if modrm=4 then begin        // case 4=sib
              sib:=byte(dta[1]);
              if (sib and 07)=5 then begin // disp32
                loc.s:=inst.addr.s; loc.o:=pd(@dta[2])^;
                LastPrintBuff('[',['']);
                if nam.isname(loc) then begin
                  nam.printname(loc);
                end else if import.isname(loc) then begin
                  import.printname(loc);
                end else if expt.isname(loc) then begin
                  expt.printname(loc);
                end else begin
                  LastPrintBuffLongHexValue(loc.o);
                end;
                LastPrintBuff(']',['']);
              end else begin
                LastPrintBuff('[%s]',[reg32ascii[sib and $07]]);
              end;
              if ((sib shr 3) and $07)=4 then begin // no scaled index reg
              end else begin
                LastPrintBuff('[%s',[reg32ascii[(sib shr 3) and $07]]);
                case sib shr 6 of
                 0:      LastPrintBuff(']',['']);
                 1:      LastPrintBuff('*2]',['']);
                 2:      LastPrintBuff('*4]',['']);
                 3:      LastPrintBuff('*8]',['']);
                end;
              end;
            end else
              LastPrintBuff('[%s]',[reg32ascii[byte(dta[0]) and $07]]);
          end else begin
            if modrm=6 then begin
              loc.s:=inst.addr.s;
              loc.o:=pw(@dta[1])^;
              LastPrintBuff('[',['']);
              if nam.isname(loc) then nam.printname(loc)
              else if import.isname(loc) then import.printname(loc)
              else if expt.isname(loc) then expt.printname(loc)
              else LastPrintBuffLongHexValue(loc.o);
              LastPrintBuff(']',['']);
            end else
              LastPrintBuff('[%s]',[regix16asc[byte(dta[0]) and $07]]);
          end;
        end;
       1:
        begin
          if inst.flags and FLAGS_SEGPREFIX<>0 then outprefix(pbyte);
          if options.mode32 then begin
            if modrm=4 then begin       // case 4=sib
              sib:=byte(dta[1]);
              if byte(dta[2]) and $80<>0 then begin
                LastPrintBuff('[%s-',[reg32ascii[byte(dta[1]) and $07]]);
///2016
                LastPrintBuffHexValue($100-byte(dta[2]));
              end else begin
                LastPrintBuff('[%s+',[reg32ascii[byte(dta[1]) and $07]]);
                LastPrintBuffHexValue(byte(dta[2]));
              end;
              if ((sib shr 3) and $07)=4 then // no scaled index reg
                LastPrintBuff(']',[''])
              else begin
                LastPrintBuff('][%s',[reg32ascii[(sib shr 3) and $07]]);
                case sib shr 6 of
                 0:    LastPrintBuff(']',['']);
                 1:    LastPrintBuff('*2]',['']);
                 2:    LastPrintBuff('*4]',['']);
                 3:    LastPrintBuff('*8]',['']);
                end;
              end;
            end else if byte(dta[1]) and $80<>0 then begin
              LastPrintBuff('[%s-',[reg32ascii[byte(dta[0]) and $07]]);
///2016 -byte to $100-byte
              LastPrintBuffHexValue($100-byte(dta[1]));
              LastPrintBuff(']',['']);
            end else begin
              LastPrintBuff('[%s+',[reg32ascii[byte(dta[0]) and $07]]);
              LastPrintBuffHexValue(byte(dta[1]));
              LastPrintBuff(']',['']);
            end;
            end else begin
              if byte(dta[1]) and $80<>0 then
                LastPrintBuff('[%s-%2.2xh]',[regix16asc[byte(dta[0]) and $07],$100-byte(dta[1])])
              else
                LastPrintBuff('[%s+%2.2xh]',[regix16asc[byte(dta[0]) and $07],byte(dta[1])]);
            end;
        end;
       2:
        begin
          if inst.flags and FLAGS_SEGPREFIX<>0 then outprefix(pbyte);
          if options.mode32 then begin
            loc.s:=inst.addr.s;
            loc.o:=pd(@dta[1])^;
            if modrm=4 then begin      // case 4=sib
              sib:=byte(dta[1]);
              loc.s:=inst.addr.s; loc.o:=pd(@dta[2])^;
              LastPrintBuff('[',['']);
              if nam.isname(loc) then begin
                LastPrintBuff('][%s',[reg32ascii[sib and $07]]);
                nam.printname(loc);
              end else if import.isname(loc) then begin
                LastPrintBuff('][%s',[reg32ascii[sib and $07]]);
                import.printname(loc);
              end else if expt.isname(loc) then begin
                LastPrintBuff('][%s',[reg32ascii[sib and $07]]);
                expt.printname(loc);
              end else if byte(dta[5]) and $80<>0 then begin
                LastPrintBuff('%s-',[reg32ascii[sib and $07]]);
                LastPrintBuffLongHexValue(0-pd(@dta[2])^);
              end else begin
                LastPrintBuff('%s+',[reg32ascii[sib and $07]]);
                LastPrintBuffLongHexValue(pd(@dta[2])^);
              end;
              if (sib shr 3) and $07=4 then // no scaled index reg
                LastPrintBuff(']',[''])
              else begin
                LastPrintBuff('][%s',[reg32ascii[(sib shr 3) and 07]]);
                case sib shr 6 of
                 0:           LastPrintBuff(']',['']);
                 1:           LastPrintBuff('*2]',['']);
                 2:           LastPrintBuff('*4]',['']);
                 3:           LastPrintBuff('*8]',['']);
                end;
              end;
            end else if nam.isname(loc) then begin
              nam.printname(loc);
              LastPrintBuff('[%s]',[reg32ascii[byte(dta[0]) and $07]]);
            end else if import.isname(loc) then begin
              import.printname(loc);
              LastPrintBuff('[%s]',[reg32ascii[byte(dta[0]) and $07]]);
            end else if expt.isname(loc) then begin
              expt.printname(loc);
              LastPrintBuff('[%s]',[reg32ascii[byte(dta[0]) and $07]]);
            end else if byte(dta[4]) and $80<>0 then begin
              LastPrintBuff('[%s-',[reg32ascii[byte(dta[0]) and $07]]);
              LastPrintBuffLongHexValue(0-pd(@dta[1])^);
              LastPrintBuff(']',['']);
            end else begin
              LastPrintBuff('[%s+',[reg32ascii[byte(dta[0]) and $07]]);
              LastPrintBuffLongHexValue(pd(@dta[1])^);
              LastPrintBuff(']',['']);
            end;
          end else begin
            loc.s:=inst.addr.s;
            loc.o:=pw(@dta[1])^;
            if nam.isname(loc) then begin
              nam.printname(loc);
              LastPrintBuff('[%s]',[regix16asc[byte(dta[0]) and $07]]);
            end else if import.isname(loc) then begin
              import.printname(loc);
              LastPrintBuff('[%s]',[regix16asc[byte(dta[0]) and $07]]);
            end else if expt.isname(loc) then begin
              expt.printname(loc);
              LastPrintBuff('[%s]',[regix16asc[byte(dta[0]) and $07]]);
            end else if byte(dta[2]) and $80<>0 then begin
              LastPrintBuff('[%s-',[regix16asc[byte(dta[0]) and $07]]);
              LastPrintBuffLongHexValue($10000-pw(@dta[1])^);
              LastPrintBuff(']',['']);
            end else begin
              LastPrintBuff('[%s+',[regix16asc[byte(dta[0]) and $07]]);
              LastPrintBuffLongHexValue(pw(@dta[1])^);
              LastPrintBuff(']',['']);
            end;
          end;
        end;
       3:
        begin
          if a=ARG_MMXMODRM then LastPrintBuff(regmascii[byte(dta[0]) and $07],[''])
          else if a=ARG_XMMMODRM then LastPrintBuff(regxascii[byte(dta[0]) and $07],[''])
          else if (pasminstdata(inst.tptr).flags and FLAGS_8BIT<>0)or
           (a=ARG_MODRM8) then LastPrintBuff(reg8ascii[byte(dta[0]) and $07],[''])
          else if (inst.mode32)and(a<>ARG_MODRM16) then LastPrintBuff(reg32ascii[byte(dta[0]) and $07],[''])
          else LastPrintBuff(reg16ascii[byte(dta[0]) and $07],['']);
        end;
      end;
    end;
   ARG_IMM_1:
     if inst.overrid=over_decimal then LastPrintBuff('1',[''])
     else LastPrintBuff('1h',['']);
   ARG_FADDR:
    begin
      dta:=inst.data+inst.length;
      if options.mode32 then begin
        dec(dta,6);
        loc.s:=pw(@dta[4])^;
        loc.o:=pd(@dta[0])^;
        if nam.isname(loc) then nam.printname(loc)
        else if import.isname(loc) then import.printname(loc)
        else if expt.isname(loc) then expt.printname(loc)
        else LastPrintBuff('%4.4x:%8.8xh',[loc.s,loc.o]);
      end else begin
        dec(dta,4);
        loc.s:=pw(@dta[2])^;
        loc.o:=pw(@dta[0])^;
        if nam.isname(loc) then nam.printname(loc)
        else if import.isname(loc) then import.printname(loc)
        else if expt.isname(loc) then expt.printname(loc)
        else LastPrintBuff('%4.4x:%8.8xh',[loc.s,loc.o]);
      end;
    end;
   ARG_BIT:
    begin
      dta:=inst.data+inst.length-1;
      LastPrintBuff('%x',[(byte(dta[0]) shr 3) and 7]);
    end;
   ARG_NONE: if inst.flags and FLAGS_SEGPREFIX<>0 then outprefix(pbyte);
   ARG_NONEBYTE:
  end;
  if inst.flags and FLAGS_ADDRPREFIX<>0 then options.mode32:= not options.mode32;
end;

{************************************************************************
* outcomment                                                            *
* - prints a disassembly comment to the buffer                          *
************************************************************************}
procedure tdisio.outcomment(inst:pdsmitem);
begin
  LastPrintBuff(';%s',[pchar(inst.tptr)]);
end;

// dumptofile                                                            *
// - this is the text and asm output routine. It needs a lot more work   *
//   doing to it and is presently a fairly simple dump of the code.      *
procedure tdisio.dumptofile(fname:string; printaddrs:boolean);
var
  i,q:integer;
  fo:textfile;
  tblock:pdsmitem;
  dblock,nxtblock:pdsegitem;
  outhere,nptr:lptr;
begin
  scheduler.stopthread;
try
  assignfile(fo,fname); rewrite(fo);
  writeln(fo,'; '+strpas(winname));
  writeln(fo,';');
  writeln(fo,strpas(hdr));
  writeln(fo);
  // find current position.
  dsm.resetiterator;
  tblock:=pdsmitem(dsm.nextiterator);
  // now tblock= first position
  dta.resetiterator;
  dblock:=pdsegitem(dta.nextiterator);
  outhere:=dblock.addr;
  while dblock<>nil do begin
    ClearBuff;
    for i:=0 to buffer_lines-2 do begin
      if tblock<>nil then begin
        if outhere.o=tblock.addr.o then begin
          case tblock.typ of
           dsmcode:    outinst(tblock,printaddrs);
           dsmnameloc:
            begin
              printlineheader(tblock.addr,printaddrs);
              LastPrintBuff('%s:',[tblock.data]);
            end;
           dsmxref:
            begin
              printlineheader(tblock.addr,printaddrs);
              LastPrintBuff(';',['']);
              LastPrintBuffEpos(COMMENTPOS);
              LastPrintBuff('XREFS First: ',['']);
              xrefs.printfirst(tblock.addr);
            end;
           else
             printlineheader(tblock.addr,printaddrs);
             outcomment(tblock);
          end;
          inc(outhere.o,tblock.length);
          tblock:=pdsmitem(dsm.nextiterator);
        end else begin
          outdb(outhere,printaddrs);
          inc(outhere.o);
        end;
      end else begin
        outdb(outhere,printaddrs);
        inc(outhere.o);
      end;
      // check if gone beyond seg, get next seg.
      // rewritten build 17. seeks dseg from start, and finds next now.
      if outhere.o>=dblock.addr.o+dblock.size then begin
        dta.resetiterator;
        nxtblock:=pdsegitem(dta.nextiterator);
        while nxtblock<>nil do begin
          if nxtblock.addr.o=dblock.addr.o then begin
            dblock:=pdsegitem(dta.nextiterator);
            break;
          end;
          nxtblock:=pdsegitem(dta.nextiterator);
          if nxtblock=nil then dblock:=nil;
        end;
        if dblock=nil then break;
        outhere:=dblock.addr;
      end;
      if outhere.s=0 then break;
    end;
    for q:=0 to lastline-1 do writeln(fo,strpas(@MainBuff[q*max_length]));
  end;
  DoneBuff;
finally
  closefile(fo);
end;
  scheduler.continuethread;
  scheduler.addtask(windowupdate,priority_window,nlptr,0,nil);
end;

// dumpblocktofile                                                       *
// - this is the text and asm output routine. It needs a lot more work   *
//   doing to it and is presently a fairly simple dump of a block of     *
//   code.                                                               *
// - this routine was a quick hack and complete rip of the dumptofile    *
//   routine which follows. the two routines need the common workings    *
//   put together and both need rewriting                                *
procedure tdisio.dumpblocktofile(fname:string; printaddrs:boolean);
var
  i,q:integer;
  fo:textfile;
  tblock:pdsmitem;
  fdsm:tdsmitem;
  dblock,nxtblock:pdsegitem;
  outhere,nptr:lptr;
begin
  if not blk.checkblock then exit;
  scheduler.stopthread;
  assignfile(fo,fname); rewrite(fo);
  writeln(fo,'; '+strpas(winname));
  writeln(fo,';');
  writeln(fo,strpas(hdr));
  writeln(fo);
  writeln(fo,format('; block dump from: %4.4x:%8.8xh to %4.4x:%8.8xh',
   [blk.top.s,blk.top.o,blk.bottom.s,blk.bottom.o]));
  // find current position.
  fdsm.addr:=blk.top;
  fdsm.typ :=dsmnull;
  tblock:=pdsmitem(dsm.find(listitem(@fdsm)));
  while tblock<>nil do begin
    if le(tblock.addr,blk.top) then tblock:=pdsmitem(dsm.nextiterator) else break;
  end;
  // now tblock= first position
  dblock:=pdsegitem(dta.findseg(blk.top));
  outhere:=blk.top;
  while (dblock<>nil)and leeq(outhere,blk.bottom) do begin
    ClearBuff; // clear buffer - ready to start
    for i:=0 to buffer_lines-2 do begin
      if tblock<>nil then begin
        if eq(outhere,tblock.addr) then begin
          case tblock.typ of
           dsmcode:     outinst(tblock,printaddrs);
           dsmnameloc:
            begin
              printlineheader(tblock.addr,printaddrs);
              LastPrintBuff('%s:',[tblock.data]);
            end;
           dsmxref:
            begin
              // temp measure - print first (build 17)
              printlineheader(tblock.addr,printaddrs);
              LastPrintBuff(';',['']);
              LastPrintBuffEpos(COMMENTPOS);
              LastPrintBuff('XREFS First: ',['']);
              xrefs.printfirst(tblock.addr);
            end;
           else
             //printlineheader(tblock.addr,printaddrs); //??
             outcomment(tblock);
          end;
          inc(outhere.o,tblock.length);
          tblock:=pdsmitem(dsm.nextiterator);
        end else begin
          outdb(outhere,printaddrs);
          inc(outhere.o);
        end;
      end else begin
        outdb(outhere,printaddrs);
        inc(outhere.o);
      end;
      // check if gone beyond seg, get next seg.
      // rewritten build 17. seeks dseg from start, and finds next now.
      if outhere.o>=(dblock.addr.o+dblock.size) then begin
        dta.resetiterator;
        nxtblock:=pdsegitem(dta.nextiterator);
        while nxtblock<>nil do begin
          if eq(nxtblock.addr,dblock.addr) then begin
            dblock:=pdsegitem(dta.nextiterator); break;
          end;
          nxtblock:=pdsegitem(dta.nextiterator);
          if nxtblock=nil then dblock:=nil;
        end;
        if dblock=nil then break;
        outhere:=dblock.addr;
      end;
      if gr(outhere,blk.bottom) then break;
      if outhere.s=0 then break;
    end;
    for q:=0 to lastline-1 do writeln(fo,strpas(@MainBuff[q*max_length]));
  end;
  DoneBuff;
  closefile(fo);
  scheduler.continuethread;
  scheduler.addtask(windowupdate,priority_window,nlptr,0,nil);
end;

initialization
  dio:=tdisio.create;
finalization
  dio.free;
end.

