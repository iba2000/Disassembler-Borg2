unit disasm;
interface
uses sysutils,windows,proctab,common,gname,relocs,xref,datas,schedule;
{************************************************************************
* This is a fairly big class, even having split off the disio class.    *
* The class is the class responsible for maintaining the main           *
* disassembly structures of Borg, and for performing the disassembly    *
* analysis. The class has some very old code in it, and hasn't          *
* undergone much improvement for some time, so parts could do with      *
* rewriting.                                                            *
************************************************************************}

type
  tdisasm=class(tslist)
    itable :pasmtable;
    lastdis:pdsmitem;
    itables,jtables,irefs:integer; // number of jump tables detected
  public
    constructor create;
    procedure dissettable;
    procedure discomment(loc:lptr;typ:dsmitemtype;comment:pchar);
    procedure delcomment(loc:lptr;typ:dsmitemtype);
    procedure disblock(loc:lptr);
    procedure disexportblock(loc:lptr);
    procedure disxref(loc:lptr);
    procedure disjumptable(loc:lptr);
    procedure disdataword(loc:lptr; x:dword);
    procedure disdatadword(loc:lptr; x:dword);
    procedure disdatadsoffword(loc:lptr);
    procedure disdatastring(loc:lptr);
    procedure disdatapstring(loc:lptr);
    procedure disdataucstring(loc:lptr);
    procedure disdataupstring(loc:lptr);
    procedure disdatadosstring(loc:lptr);
    procedure disdatageneralstring(loc:lptr);
    procedure disargoverdec(loc:lptr);
    procedure disargnegate(loc:lptr);
    procedure disargoverhex(loc:lptr);
    procedure disargoverchar(loc:lptr);
    procedure disargoveroffsetdseg(loc:lptr);
    procedure codeseek(loc:lptr);
    function oktoname(loc:lptr):boolean;
    procedure undefineline;
    procedure undefinelines;
    procedure undefinelines_long;
    function getlength(loc:lptr):integer;
    function nextiter_code(tblock:pdsmitem):pdsmitem;
    procedure disargoversingle(loc:lptr);
    procedure addcomment(loc:lptr; x:dword; comment:pchar);
    function disname_or_ordinal(loc:lptr; comment_ctrl:boolean):integer;
    procedure disdialog(loc:lptr; basename:pchar);
    procedure disstringtable(loc:lptr; basename:pchar);
    procedure disdatasingle(loc:lptr);
    procedure disdatadouble(loc:lptr);
    procedure disdatalongdouble(loc:lptr);
    procedure disautocomment(loc:lptr; typ:dsmitemtype; comment:pchar);
    procedure undefineblock(ufrom,uto:lptr);
    function compare(a,b:listitem):integer;override;
    procedure delfunc(d:listitem);override;
  private
    function decodeinst(ibuff,mcode:pchar;loc:lptr;x:dword;tabtype:byte;omode32:boolean;depth:integer):pdsmitem;
    function arglength(a:argtype; modrmbyte,sibbyte:char; flgs:dword; omode32:boolean):byte;
    function checkvalid(newdsm:pdsmitem):boolean;
    function interpretmod(data:pchar; toffs:pd; indexreg,indexreg2,indexamount:pchar; numjumps:pd):boolean;
    procedure setcodeoverride(loc:lptr;typ:byteoverride);
    procedure initnewdsm(newdsm:pdsmitem;loc:lptr;typ:dsmitemtype);
    procedure disdata(loc:lptr;asmwd:pasminstdata;len:byte;overr:byteoverride);
    function dsmitem_contains_loc(d:pdsmitem;loc:lptr):boolean;
    function dsmfindaddrtype(loc:lptr; typ:dsmitemtype):pdsmitem;
  end;

const
  DISPFLAG_NEGATE = 1;

var
  dsm:tdisasm;

implementation
uses disio;

constructor tdisasm.create;
begin
  inherited create;
  lastdis:=nil;
  itables:=0;
  jtables:=0;
  irefs  :=0;
end;

// initnewdsm                                                            *
// - this is some common code i pulled out and put into a function on    *
//   its own. when a new disassembly item is created it initialises some *
//   of the stucture.                                                    *
procedure tdisasm.initnewdsm(newdsm:pdsmitem;loc:lptr;typ:dsmitemtype);
begin
  newdsm.addr   :=loc;
  newdsm.typ    :=typ;
  newdsm.overrid:=over_null;
  newdsm.modrm  :=0;
  newdsm.mode32 :=options.mode32;
  newdsm.flags  :=0;
  newdsm.displayflags:=0;
end;

// dissettable                                                           *
// - this function sets up the processor table. It should be called once *
//   when the processor has been selected and before disassembly begins  *
procedure tdisasm.dissettable;
var i:integer;
begin
  i:=0;
  while((procnames[i].num<>0)and(procnames[i].num<>options.processor)) do inc(i);
  itable:=procnames[i].tab;
end;

// nextiter_code                                                         *
// - a basic building block piece of code which skips to the next        *
//   code/data item in the disassembly (identified by having a length),  *
//   or returns null if it gets to the end                               *
function tdisasm.nextiter_code(tblock:pdsmitem):pdsmitem;
begin
  if(tblock<>nil) then
  while tblock.length=0 do begin
    tblock:=pdsmitem(nextiterator);
    if tblock=nil then break;
  end;
  result:=tblock;
end;

{************************************************************************
* dsmitem_contains_loc                                                  *
* - a basic building block piece of code which returns true if the      *
*   dsmitem straddles loc                                               *
* - added in v2.22                                                      *
************************************************************************}
function tdisasm.dsmitem_contains_loc(d:pdsmitem;loc:lptr):boolean;
begin
  result:=le(d.addr,loc) and (d.addr.o+d.length>loc.o);
end;

{************************************************************************
* dsmfindaddrtype                                                       *
* - a basic building block piece of code which returns a dsmitem        *
*   pointer using the list class find to find it by loc and type        *
* - added in v2.22                                                      *
************************************************************************}
function tdisasm.dsmfindaddrtype(loc:lptr; typ:dsmitemtype):pdsmitem;
var fnd:tdsmitem;
begin
  fnd.addr:=loc;
  fnd.typ :=typ;
  result:=pdsmitem(find(listitem(@fnd)));
end;

// oktoname                                                              *
// - this checks that we arent trying to name a location which is in the *
//   middle of an instruction and returns true if it is ok to assign a   *
//   name here                                                           *
function tdisasm.oktoname(loc:lptr):boolean;
var checker:pdsmitem;
begin
  result:=true;
  // check table for the given address
  checker:=dsmfindaddrtype(loc,dsmcode);
  // NULL returned - must be ok.
  if checker=nil then exit;
  // check bounds.
  if dsmitem_contains_loc(checker,loc) then result:=false;
end;

{************************************************************************
* checkvalid                                                            *
* - this is called when adding an instruction disassembly to the list   *
* - it checks that an instruction isnt being added which would overlap  *
*   with instructions already in the database                           *
* - it will delete any names and xrefs or comments which get in the way *
************************************************************************}
function tdisasm.checkvalid(newdsm:pdsmitem):boolean;
var
  lstdsm:pdsmitem;
  deldsm:pdsmitem;
begin
  result:=true;
  lstdsm:=dsmfindaddrtype(newdsm.addr,dsmnull);
  if lstdsm=nil then exit;
  // go through the disassembly items nearby and check for any overlaps.
  repeat
    if lstdsm.length<>0 then begin
      if between(newdsm.addr,lstdsm.addr,lstdsm.addr,lstdsm.length-1)
      then begin result:=false; exit; end;
      if between(lstdsm.addr,newdsm.addr,newdsm.addr,newdsm.length-1)
      then begin result:=false; exit; end;
    end;
    if lstdsm.addr.o>=newdsm.addr.o+newdsm.length then break;
    lstdsm:=pdsmitem(nextiterator);
  until lstdsm=nil;
  deldsm:=dsmfindaddrtype(newdsm.addr,dsmnull);
  // now go through them again, and this time delete any names/xrefs which get
  // in the way.
  repeat
    if (deldsm.length=0)and(deldsm.addr.s=newdsm.addr.s) then begin
      if dsmitem_contains_loc(newdsm,deldsm.addr) then begin
        case deldsm.typ of
         dsmnameloc : nam.delname(deldsm.addr);
         dsmxref    : ;
        end;
        delfrom(listitem(deldsm));
        deldsm:=dsmfindaddrtype(newdsm.addr,dsmnull);
        if deldsm=nil then exit;
      end;
    end;
    if newdsm.addr.o+newdsm.length<=deldsm.addr.o then break;
    deldsm:=pdsmitem(nextiterator);
  until lstdsm=nil;
end;

// setcodeoverride                                                       *
// - sets a particular override for a given location                     *
// - this subfunction was created in v211 as it was duplicated code in   *
//   several functions                                                   *
procedure tdisasm.setcodeoverride(loc:lptr;typ:byteoverride);
var findit:pdsmitem;
begin
  findit:=dsmfindaddrtype(loc,dsmcode);
  if findit<>nil then begin
    if (findit.addr.o=loc.o)and(findit.typ=dsmcode) then begin
      findit.overrid:=typ;
      dio.updatewindowifinrange(loc);
    end;
  end;
end;

// disargnegate                                                          *
// - as well as an override I added some displayflags for a disassembly  *
//   item. There is a negation item which allows immediates to be        *
//   negated when displayed, and this function sets or resets the flag   *
procedure tdisasm.disargnegate(loc:lptr);
var findit:pdsmitem;
begin
  findit:=dsmfindaddrtype(loc,dsmcode);
  if findit<>nil then begin
    if (findit.addr.o=loc.o)and(findit.typ=dsmcode) then begin
      findit.displayflags:=byte(findit.displayflags xor DISPFLAG_NEGATE);
      dio.updatewindowifinrange(loc);
    end;
  end;
end;

// disargoverdec                                                         *
// - sets the decimal override for a disassembly item, given the         *
//   location                                                            *
procedure tdisasm.disargoverdec(loc:lptr);
begin
  setcodeoverride(loc,over_decimal);
end;

// disargoversingle                                                      *
// - sets the single (float) override for a disassembly item, given the  *
//   location                                                            *
procedure tdisasm.disargoversingle(loc:lptr);
begin
  setcodeoverride(loc,over_single);
end;

// disargoverhex                                                         *
// - sets the hex (null) override for a disassembly item, given the      *
//   location                                                            *
procedure tdisasm.disargoverhex(loc:lptr);
begin
  setcodeoverride(loc,over_null);
end;

//disargoverchar                                                        *
// - sets the character override for a disassembly item, given the       *
//   location                                                            *
procedure tdisasm.disargoverchar(loc:lptr);
begin
  setcodeoverride(loc,over_char);
end;

// disargoveroffsetdseg                                                  *
// - sets the dseg override for a disassembly item, given the location   *
// - NB at present it does not affect xrefs, to be done.......           *
procedure tdisasm.disargoveroffsetdseg(loc:lptr);
var
  findit:pdsmitem;
  j:lptr;
begin
  findit:=dsmfindaddrtype(loc,dsmcode);
  if findit<>nil then begin
    if (findit.addr.o=loc.o)and(findit.typ=dsmcode) then begin
      findit.overrid:=over_dsoffset;
      dio.updatewindowifinrange(loc);
      if (options.mode32)and(findit.length>=4) then begin
        j.s:=options.dseg;
        j.o:=pd(@findit.data[findit.length-4])^;
        xrefs.addxref(j,loc,0);
      end;
    end;
  end;
end;

// disdatastring                                                         *
// - disassembles a string at location loc.                              *
// - also names the location using the string.                           *
// - C style                                                             *
procedure tdisasm.disdatastring(loc:lptr);
var
  dblock:pdsegitem;
  newdsm:pdsmitem;
  maxlen,actuallen:dword;
  callit:array[0..GNAME_MAXLEN] of char;
begin
  dblock:=dta.findseg(loc);
  if dblock=nil then exit;
  maxlen:=dblock.size-(loc.o-dblock.addr.o);
  if maxlen<2 then exit;
  actuallen:=0;
  while dblock.data[(loc.o-dblock.addr.o)+actuallen]<>#0 do begin
    inc(actuallen);
    dec(maxlen);
    if maxlen=0 then exit;
  end;
  inc(actuallen);
  if actuallen>$FFFF then exit; // tooo big
  getmem(newdsm,sizeof(tdsmitem));
  initnewdsm(newdsm,loc,dsmcode);
  newdsm.tptr:=@_asmstr[0];
  newdsm.length:=word(actuallen);           // string length
  newdsm.data:=dblock.data+(loc.o-dblock.addr.o);
  if checkvalid(newdsm) then begin
    callit[0]:='s';
    callit[1]:='_';
    if actuallen>GNAME_MAXLEN-2 then begin
      callit[GNAME_MAXLEN]:=#0;
      lstrcpyn(callit+2,@newdsm.data^,GNAME_MAXLEN-3);
    end else lstrcpy(callit+2,@newdsm.data^);
    cleanstring(callit);
    addto(listitem(newdsm));
    nam.addname(newdsm.addr,callit);
    //check if need to update window.
    dio.updatewindowifinrange(loc);
  end else freemem(newdsm);
end;

// disdataucstring                                                       *
// - disassembles a string at location loc.                              *
// - also names the location using the string.                           *
// - unicode C style                                                     *
procedure tdisasm.disdataucstring(loc:lptr);
var
  dblock:pdsegitem;
  newdsm:pdsmitem;
  maxlen,actuallen:dword;
  i:integer;
  callit:array[0..GNAME_MAXLEN] of char;
begin
  dblock:=dta.findseg(loc);
  if dblock=nil then exit;
  maxlen:=dblock.size-(loc.o-dblock.addr.o);
  if maxlen<2 then exit;
  actuallen:=0;
  while dblock.data[(loc.o-dblock.addr.o)+actuallen]<>#0 do begin
    inc(actuallen);
    dec(maxlen);
    if maxlen=0 then exit;
    inc(actuallen);
    dec(maxlen);
    if maxlen=0 then exit;
  end;
  inc(actuallen,2);
  if actuallen>$FFFF then exit; // tooo big
  getmem(newdsm,sizeof(tdsmitem));
  initnewdsm(newdsm,loc,dsmcode);
  newdsm.tptr:=@_asmstr[3];
  newdsm.length:=word(actuallen);              // string length
  newdsm.data:=dblock.data+(loc.o-dblock.addr.o);
  if checkvalid(newdsm) then begin
    callit[0]:='s';
    callit[1]:='_';
    i:=2;
    while i<GNAME_MAXLEN-1 do begin
      callit[i]:=newdsm.data[(i-2)*2];
      inc(i); if i*2>actuallen then break;
    end;
    callit[i]:=#0;
    cleanstring(callit);
    addto(listitem(newdsm));
    nam.addname(newdsm.addr,callit);
    //check if need to update window.
    dio.updatewindowifinrange(loc);
  end else freemem(newdsm);
end;

// disdataupstring                                                       *
// - disassembles a string at location loc.                              *
// - also names the location using the string.                           *
// - Unicode Pascal style                                                *
procedure tdisasm.disdataupstring(loc:lptr);
var
  dblock:pdsegitem;
  newdsm:pdsmitem;
  tlen:word;
  maxlen,actuallen:dword;
  i:integer;
  callit:array[0..GNAME_MAXLEN] of char;
begin
  dblock:=dta.findseg(loc);
  if dblock=nil then exit;
  maxlen:=dblock.size-(loc.o-dblock.addr.o);
  if maxlen<2 then exit;
  dec(maxlen);
  actuallen:=0;
  tlen:=pw(@dblock.data[loc.o-dblock.addr.o])^;
  while tlen<>0 do begin
    inc(actuallen);
    dec(tlen);
    dec(maxlen);
    if maxlen=0 then exit;
    inc(actuallen);
    dec(maxlen);
    if maxlen=0 then exit;
  end;
  inc(actuallen,2);
  if actuallen>$FFFF then exit; // tooo big
  getmem(newdsm,sizeof(tdsmitem));
  initnewdsm(newdsm,loc,dsmcode);
  newdsm.tptr:=@_asmstr[4];
  newdsm.length:=word(actuallen);              // string length
  newdsm.data:=dblock.data+(loc.o-dblock.addr.o);
  if checkvalid(newdsm) then begin
    callit[0]:='s';
    callit[1]:='_';
    i:=2;
    while i<GNAME_MAXLEN-1 do begin
      callit[i]:=newdsm.data[(i-1)*2];
      inc(i);
      if i*2>actuallen then break;
    end;
    callit[i]:=#0;
    cleanstring(callit);
    addto(listitem(newdsm));
    nam.addname(newdsm.addr,callit);
    //check if need to update window.
    dio.updatewindowifinrange(loc);
  end else freemem(newdsm);
end;

// disdatadosstring                                                      *
// - disassembles a string at location loc.                              *
// - also names the location using the string.                           *
// - DOS style                                                           *
procedure tdisasm.disdatadosstring(loc:lptr);
var
  dblock:pdsegitem;
  newdsm:pdsmitem;
  maxlen,actuallen:dword;
  callit:array[0..GNAME_MAXLEN] of char;
begin
  dblock:=dta.findseg(loc);
  if dblock=nil then exit;
  maxlen:=dblock.size-(loc.o-dblock.addr.o);
  if maxlen<2 then exit;
  actuallen:=0;
  while dblock.data[(loc.o-dblock.addr.o)+actuallen]<>'$' do begin
    inc(actuallen);
    dec(maxlen);
    if maxlen=0 then exit;
  end;
  inc(actuallen);
  if actuallen>$FFFF then exit; // tooo big
  getmem(newdsm,sizeof(tdsmitem));
  initnewdsm(newdsm,loc,dsmcode);
  newdsm.tptr:=@_asmstr[2];
  newdsm.length:=word(actuallen);              // string length
  newdsm.data:=dblock.data+(loc.o-dblock.addr.o);
  if checkvalid(newdsm) then begin
    callit[0]:='s';
    callit[1]:='_';
    callit[GNAME_MAXLEN]:=#0;
    if actuallen>GNAME_MAXLEN-2 then lstrcpyn(callit+2,@newdsm.data^,GNAME_MAXLEN-3)
    else lstrcpyn(callit+2,@newdsm.data^,actuallen);
    cleanstring(callit);
    addto(listitem(newdsm));
    nam.addname(newdsm.addr,callit);
    //check if need to update window.
    dio.updatewindowifinrange(loc);
  end else freemem(newdsm);
end;

// disdatageneralstring                                                  *
// - disassembles a string at location loc.                              *
// - also names the location using the string.                           *
// - general string is defined as printable characters                   *
procedure tdisasm.disdatageneralstring(loc:lptr);
var
  dblock:pdsegitem;
  newdsm:pdsmitem;
  maxlen,actuallen:dword;
  callit:array[0..GNAME_MAXLEN] of char;
begin
  dblock:=dta.findseg(loc);
  if dblock=nil then exit;
  maxlen:=dblock.size-(loc.o-dblock.addr.o);
  if maxlen<2 then exit;
  actuallen:=0;
  while isprint(dblock.data[(loc.o-dblock.addr.o)+actuallen]) do begin
    inc(actuallen);
    dec(maxlen);
    if maxlen=0 then exit;
  end;
  inc(actuallen);
  if actuallen>$FFFF then exit; // tooo big
  getmem(newdsm,sizeof(tdsmitem));
  initnewdsm(newdsm,loc,dsmcode);
  newdsm.tptr:=@_asmstr[2];
  newdsm.length:=word(actuallen);              // string length
  newdsm.data:=dblock.data+(loc.o-dblock.addr.o);
  if checkvalid(newdsm) then begin
    callit[0]:='s';
    callit[1]:='_';
    callit[GNAME_MAXLEN]:=#0;
    if actuallen>GNAME_MAXLEN-2 then lstrcpyn(callit+2,@newdsm.data^,GNAME_MAXLEN-3)
    else lstrcpyn(callit+2,@newdsm.data^,actuallen);
    cleanstring(callit);
    addto(listitem(newdsm));
    nam.addname(newdsm.addr,callit);
    //check if need to update window.
    dio.updatewindowifinrange(loc);
  end else freemem(newdsm);
end;

// disdatapstring                                                        *
// - disassembles a string at location loc.                              *
// - also names the location using the string.                           *
// - Pascal style                                                        *
procedure tdisasm.disdatapstring(loc:lptr);
var
  dblock:pdsegitem;
  newdsm:pdsmitem;
  tlen:byte;
  maxlen,actuallen:dword;
  callit:array[0..GNAME_MAXLEN] of char;
begin
  dblock:=dta.findseg(loc);
  if dblock=nil then exit;
  maxlen:=dblock.size-(loc.o-dblock.addr.o);
  if maxlen<2 then exit;
  actuallen:=0;
  tlen:=byte(dblock.data[loc.o-dblock.addr.o]);
  while tlen<>0 do begin
    inc(actuallen);
    dec(tlen);
    dec(maxlen);
    if maxlen=0 then exit;
  end;
  inc(actuallen);
  if actuallen>$FFFF then exit; // tooo big
  getmem(newdsm,sizeof(tdsmitem));
  initnewdsm(newdsm,loc,dsmcode);
  newdsm.tptr:=@_asmstr[1];
  newdsm.length:=word(actuallen);              // string length
  newdsm.data:=dblock.data+(loc.o-dblock.addr.o);
  if checkvalid(newdsm) then begin
    callit[0]:='s';
    callit[1]:='_';
    if actuallen>GNAME_MAXLEN-2 then begin
      callit[GNAME_MAXLEN]:=#0;
      lstrcpyn(callit+2,@newdsm.data[1],GNAME_MAXLEN-3);
    end else begin
      callit[actuallen+2]:=#0;
      lstrcpyn(callit+2,@newdsm.data[1],actuallen);
    end;
    cleanstring(callit);
    addto(listitem(newdsm));
    nam.addname(newdsm.addr,callit);
    //check if need to update window.
    dio.updatewindowifinrange(loc);
  end else freemem(newdsm);
end;

// disdata                                                               *
// - disassembles a dataitem, the common parts of the routines which     *
//   disassemble particular types (words,dwords, etc)                    *
procedure tdisasm.disdata(loc:lptr;asmwd:pasminstdata;len:byte;overr:byteoverride);
var
  dblock:pdsegitem;
  newdsm:pdsmitem;
begin
  dblock:=dta.findseg(loc);
  if dblock=nil then exit;
  getmem(newdsm,sizeof(tdsmitem));
  initnewdsm(newdsm,loc,dsmcode);
  newdsm.tptr:=asmwd;
  newdsm.length:=len;
  newdsm.data:=dblock.data+(loc.o-dblock.addr.o);
  newdsm.overrid:=overr;
  if checkvalid(newdsm) then begin
    addto(listitem(newdsm));
    //check if need to update window.
    dio.updatewindowifinrange(loc);
  end else freemem(newdsm);
end;

// disdataword                                                           *
// - disassembles a word at location loc.                                *
procedure tdisasm.disdataword(loc:lptr; x:dword);
begin
  inc(loc.o,x);
  disdata(loc,@_asmword[0],2,over_null);
end;

// disdatadword                                                          *
// - disassembles a dword at location loc.                                *
procedure tdisasm.disdatadword(loc:lptr; x:dword);
begin
  inc(loc.o,x);
  disdata(loc,@_asmdword[0],4,over_null);
end;

procedure tdisasm.disdatadsoffword(loc:lptr);
begin
  disdata(loc,@_asmdword[0],4,over_dsoffset);
end;

// codeseek                                                              *
// - this is the aggressive code search if it is chosen as an option. It *
//   has a low priority, and so appears near the end of the queue. It    *
//   hunts for possible code to disassemble in the code segments (added  *
//   as a task during file load for each code segment). When it finds an *
//   undisassembled byte it tries to disassemble from that point, and    *
//   drops into the background again until disassembly has been done     *
// - note that if it doesnt find anything in a short time it exits and   *
//   puts a continuation request in to the scheduler, this ensures that  *
//   userrequests are answered quickly                                   *
procedure tdisasm.codeseek(loc:lptr);
var
  doneblock:boolean;
  dblock:pdsegitem;
  tblock:pdsmitem;
  dcount,ilength:integer;
begin
  // check if already done.
  dblock:=dta.findseg(loc);      // find segment item.
  dcount:=0;
  if dblock=nil then exit;
  repeat
    doneblock:=FALSE;
    ilength:=1;
    dsmfindaddrtype(loc,dsmnull);
    tblock:=pdsmitem(nextiterator);
    tblock:=nextiter_code(tblock);
    if tblock<>nil then begin
      if (tblock.addr.s=loc.s)and(dsmitem_contains_loc(tblock,loc)) then doneblock:=TRUE;
      while eq(tblock.addr,loc) do begin
        if tblock.length<>0 then ilength:=tblock.length;
        if tblock.typ<>dsmcomment then begin
          doneblock:=TRUE; break;
        end;
        tblock:=pdsmitem(nextiterator);
        if tblock=nil then break;
      end;
    end;
    if doneblock then begin
      inc(loc.o,ilength);
      inc(dcount);
      if loc.o>=dblock.addr.o+dblock.size then exit;
      if dcount>1000 then begin
        // dont forget the main thread!
        scheduler.addtask(seek_code,priority_continuation,loc,0,nil);
        exit;
      end;
    end;
  until not doneblock;
  // decode it.
  scheduler.addtask(seek_code,priority_aggressivesearch,loc,1,nil);
  scheduler.addtask(dis_code,priority_possiblecode,loc,0,nil);
end;

{************************************************************************
* disexportblock                                                        *
* - this disassembles a block of code, from an export address, but only *
*   if the export address is in a code segment                          *
************************************************************************}
procedure tdisasm.disexportblock(loc:lptr);
var dblock:pdsegitem;
begin
   dblock:=dta.findseg(loc);
   if dblock=nil then exit;
   if dblock.typ=code32 then disblock(loc);
end;

{************************************************************************
* disblock                                                              *
* - disassembles a block from the starting point loc, calling           *
*   decodeinst for each instruction.                                    *
* - we dont just keep going in here, but only disassemble a few         *
*   instructions then ask for a continuation and quit back to the       *
*   scheduler for userrequests to be processed. If Borg seems to slow   *
*   on your machine when you scroll around and it is still analysing    *
*   then try dropping the number of instructions to disassemble and     *
*   window updates should occur more often.                             *
* - If Borg cannot disassemble for whatever reason, or if a ret or jmp  *
*   type instruction is reached then we finish.                         *
************************************************************************}
procedure tdisasm.disblock(loc:lptr);
var
  ibuff:array[0..19] of char; // ibuff is the disassembly buffer - m/c is moved here
  dblock:pdsegitem;
  i,disasmcount:integer;
  doneblock:boolean;
  tblock:pdsmitem;
  aaddr:dword;
  mcode:pchar;
  codefound:pasminstdata;
begin
  dblock:=dta.findseg(loc);      // find segment item.
  disasmcount:=0;
  if dblock=nil then exit;
  if dblock.typ=uninitdata then exit;
  if loc.o>=(dblock.addr.o+dblock.size) then exit;
  doneblock:=false;
  while not doneblock do begin
    // don't spend too long in here
    inc(disasmcount);
    if disasmcount>50 then begin
      scheduler.addtask(dis_code,priority_continuation,loc,0,nil);
      exit;
    end;
    fillchar(ibuff,20,0);
    // check if already done.
    dsmfindaddrtype(loc,dsmnull);
    tblock:=pdsmitem(nextiterator);
    tblock:=nextiter_code(tblock);
    if tblock<>nil then begin
      if (tblock.addr.s=loc.s)and dsmitem_contains_loc(tblock,loc) then doneblock:=true;
      while eq(tblock.addr,loc) do begin
        if tblock.typ<>dsmcomment then begin
          doneblock:=true;
          break;
        end;
        tblock:=pdsmitem(nextiterator);
        if tblock=nil then break;
      end;
    end;
    // decode it.
    if doneblock then break;
    aaddr:=loc.o-dblock.addr.o;
    mcode:=dblock.data+aaddr;
    i:=0;
    while (i<15)and(aaddr<dblock.size) do begin
      ibuff[i]:=mcode[i];
      inc(i);
      inc(aaddr);
    end;
if $0102cb1f=loc.o then
  i:=i;
    tblock:=decodeinst(ibuff,mcode,loc,0,TABLE_MAIN,options.mode32,0);
    if tblock<>nil then if not checkvalid(tblock) then begin
      freemem(tblock); tblock:=nil;
    end;
    if tblock<>nil then begin
      addto(listitem(tblock));
      //check if need to update window.
      dio.updatewindowifinrange(loc);
      inc(loc.o,tblock.length);
      if (loc.o-dblock.addr.o)>dblock.size then begin
        doneblock:=true;
        delfrom(listitem(tblock));
      end;
    end else doneblock:=true;
    if doneblock then break;
    // check if end (jmp,ret,etc)
    codefound:=pasminstdata(tblock.tptr);
    if (codefound.flags and FLAGS_JMP)or(codefound.flags and FLAGS_RET)<>0
    then doneblock:=true;
  end;
end;

// decodeinst                                                            *
// - disassembles one instruction                                        *
// - in some ways this is the single most important function in Borg. It *
//   disassembles an instruction adding a disassembled item to the       *
//   database. It uses the options we have set, and the processor tables *
//   identified.                                                         *
// - If some kind of call or conditional jump is reached then Borg       *
//   just adds another disassembly task to the scheduler to look at      *
//   later, and then carries on.                                         *
// - Note that this function is recursive, for handling some complex     *
//   x86 overrides, note that the recursion depth is limited but Borg    *
//   should handle complex prefix byte sequences and 'double sequences'  *
// - The majority of the code here is some of the oldest code in Borg,   *
//   and probably some of the most complex.                              *
// - xreffing and windowupdates are performed from here                  *
function tdisasm.decodeinst(ibuff,mcode:pchar;loc:lptr;x:dword;tabtype:byte;omode32:boolean;depth:integer):pdsmitem;
var
  itab:pasmtablearr;
  tablenum:integer;               // asmtable table number
  instnum:integer;                // instruction num in table
  insttab:pasminstdataarr;
  newdsm:pdsmitem;
  flgs:dword;                     // inst flags
  a1,a2,a3:argtype;               // inst args
  i,j:lptr;                         // jump/call target
  dta:pchar;
  length:byte;
  imp:pgnameitem;
  impname:pchar;
  righttable:boolean;
  cbyte,mbyte:byte;
  fupbyte:boolean;
begin
try
  inc(loc.o,x);
  tablenum:=0;
  cbyte:=byte(ibuff[0]);
  itab:=@itable^;
  result:=nil;
  if tabtype=TABLE_EXT  then cbyte:=byte(ibuff[1]);
  if tabtype=TABLE_EXT2 then cbyte:=byte(ibuff[2]);
  if(tabtype=TABLE_EXT2)and(options.processor=PROC_Z80) then cbyte:=byte(ibuff[3]);
  while itab^[tablenum].table<>nil do begin  // search tables
    righttable:=TRUE;
    if (itab^[tablenum].typ<>tabtype)or(itab^[tablenum].minlim>cbyte)or
       (itab^[tablenum].maxlim<cbyte)
    then righttable:=FALSE;
    if ((tabtype=TABLE_EXT)or(tabtype=TABLE_EXT2))and(byte(ibuff[0])<>itab^[tablenum].extnum)
    then righttable:=FALSE;
    if (tabtype=TABLE_EXT2)and(byte(ibuff[1])<>itab^[tablenum].extnum2)
    then righttable:=FALSE;
    if righttable then begin
      insttab:=@itab^[tablenum].table^;      // need to search this now
      instnum:=0;
      mbyte:=cbyte;
      fupbyte:=FALSE;
      if itab^[tablenum].divisor<>0 then mbyte:=mbyte div itab^[tablenum].divisor;
      if itab^[tablenum].mask<>0    then mbyte:=mbyte and itab^[tablenum].mask
      else begin     // follow up byte encodings (KNI,AMD3DNOW)
        fupbyte:=TRUE;
        flgs:=insttab^[instnum].flags;
        a1  :=insttab^[instnum].arg1;
        a2  :=insttab^[instnum].arg2;
        a3  :=insttab^[instnum].arg3;
        length:=1+arglength(a1,mcode[1+itab^[tablenum].modrmpos],mcode[2+itab^[tablenum].modrmpos],flgs,TRUE)
           +arglength(a2,mcode[1+itab^[tablenum].modrmpos],mcode[2+itab^[tablenum].modrmpos],flgs,TRUE)
           +arglength(a3,mcode[1+itab^[tablenum].modrmpos],mcode[2+itab^[tablenum].modrmpos],flgs,TRUE)
           +itab^[tablenum].modrmpos;
        // addition for table extensions where inst is part of modrm byte
        if ((tabtype=TABLE_EXT)or(tabtype=TABLE_EXT2))and(length=1) then inc(length);
        mbyte:=byte(ibuff[length]);
      end;
      while (insttab^[instnum].nam<>nil)or(insttab^[instnum].instbyte<>0)or(insttab^[instnum].cpu<>0) do begin
        if omode32 and(insttab^[instnum].flags and FLAGS_OMODE16<>0) then
        else if not omode32 and(insttab^[instnum].flags and FLAGS_OMODE32<>0) then
        else if (insttab^[instnum].instbyte=mbyte)and(insttab^[instnum].cpu and options.processor<>0)
        then begin // found it
          if insttab^[instnum].nam=nil then begin
            if(tabtype=TABLE_MAIN) then
              result:=decodeinst(ibuff,mcode,loc,0,TABLE_EXT,omode32,5)
            else
              result:=decodeinst(ibuff,mcode,loc,0,TABLE_EXT2,omode32,5);
            exit;
          end else begin
            // interpret flags,etc
            flgs:=insttab^[instnum].flags;
            if (flgs and FLAGS_OPERPREFIX<>0)and(depth<5) then begin
              newdsm:=decodeinst(ibuff+1,mcode+1,loc,1,tabtype,not omode32,depth+1);
              if newdsm=nil then exit;
              dec(newdsm.addr.o);
              inc(newdsm.length);
              inc(newdsm.modrm);
              dec(newdsm.data);
              result:=newdsm;
              exit;
            end;
            if (flgs and FLAGS_ADDRPREFIX<>0)and(depth<5) then begin
              options.mode32:=not options.mode32;
              options.mode16:=not options.mode16;
              newdsm:=decodeinst(ibuff+1,mcode+1,loc,1,tabtype,omode32,depth+1);
              options.mode32:=not options.mode32;
              options.mode16:=not options.mode16;
              if newdsm=nil then exit;
              dec(newdsm.addr.o);
              inc(newdsm.length);
              inc(newdsm.modrm);
              dec(newdsm.data);
              newdsm.flags:=newdsm.flags or FLAGS_ADDRPREFIX;
              result:=newdsm;
              exit;
            end;
            if (flgs and FLAGS_SEGPREFIX<>0)and(depth<5) then begin
              newdsm:=decodeinst(ibuff+1,mcode+1,loc,1,tabtype,omode32,depth+1);
              if newdsm=nil then exit;
              dec(newdsm.addr.o);
              inc(newdsm.length);
              inc(newdsm.modrm);
              dec(newdsm.data);
              newdsm.flags:=newdsm.flags or FLAGS_SEGPREFIX;
              result:=newdsm;
              exit;
            end;
            if (flgs and FLAGS_PREFIX<>0)and(depth<5) then begin
              newdsm:=decodeinst(ibuff+1,mcode+1,loc,1,tabtype,omode32,depth+1);
              if newdsm=nil then exit;
              dec(newdsm.addr.o);
              inc(newdsm.length);
              inc(newdsm.modrm);
              dec(newdsm.data);
              newdsm.flags:=newdsm.flags or FLAGS_PREFIX;
              result:=newdsm;
              exit;
            end;
            getmem(newdsm,sizeof(tdsmitem));
            initnewdsm(newdsm,loc,dsmcode);
            newdsm.tptr:=@insttab^[instnum];
            newdsm.modrm:=byte(1+itab^[tablenum].modrmpos);
            newdsm.data:=mcode;
            newdsm.mode32:=omode32;
            if flgs and FLAGS_16BIT<>0 then newdsm.mode32:=FALSE;
            if flgs and FLAGS_32BIT<>0 then newdsm.mode32:=TRUE;
            newdsm.flags:=flgs;
            a1:=insttab^[instnum].arg1;
            a2:=insttab^[instnum].arg2;
            a3:=insttab^[instnum].arg3;
            length:=1+arglength(a1,mcode[1+itab^[tablenum].modrmpos],mcode[2+itab^[tablenum].modrmpos],flgs,newdsm.mode32)
               +arglength(a2,mcode[1+itab^[tablenum].modrmpos],mcode[2+itab^[tablenum].modrmpos],flgs,newdsm.mode32)
               +arglength(a3,mcode[1+itab^[tablenum].modrmpos],mcode[2+itab^[tablenum].modrmpos],flgs,newdsm.mode32)
               +itab^[tablenum].modrmpos;
            // addition for table extensions where inst is part of modrm byte
            if ((tabtype=TABLE_EXT)or(tabtype=TABLE_EXT2))and((length=1)or(options.processor=PROC_Z80))
            then inc(length);
            if options.processor=PROC_Z80 then begin
              if tabtype=TABLE_EXT2 then inc(length);
              if flgs and FLAGS_INDEXREG<>0 then inc(length);
            end;
            if fupbyte then inc(length);
            newdsm.length:=length;
            if not checkvalid(newdsm) then begin
              freemem(newdsm); exit;
            end;
            if flgs and (FLAGS_JMP or FLAGS_CALL or FLAGS_CJMP)<>0 then begin
              case a1 of
               ARG_RELIMM:
                begin
                  j:=loc;
                  dta:=@mcode[length];
                  if options.mode32 then begin
                    dec(dta,4);
                    inc(j.o,pd(@dta[0])^+length);
                  end else begin
                    dec(dta,2);
                    inc(j.o,pw(@dta[0])^+length);
                  end;
                  scheduler.addtask(dis_code,priority_definitecode,j,0,nil);
                  xrefs.addxref(j,newdsm.addr,0);
                end;
               ARG_RELIMM8:
                begin
                  j:=loc;
                  dta:=@mcode[length-1];
                  if options.mode32 then begin
                    if byte(dta[0]) and $80<>0 then
                      inc(j.o,dword(dta[0])+$ffffff00+length)
                    else
                      inc(j.o,dword(dta[0])+length);
                  end else begin
                    if byte(dta[0]) and $80<>0 then
                      inc(j.o,word(dta[0])+$ff00+length)
                    else
                      inc(j.o,word(dta[0])+length);
                  end;
                  scheduler.addtask(dis_code,priority_definitecode,j,0,nil);
                  xrefs.addxref(j,newdsm.addr,0);
                end;
               ARG_FADDR:
                begin
                  dta:=@mcode[length];
                  if options.mode32 then begin
                    dec(dta,6);
                    j.s:=pw(@dta[4])^; j.o:=pd(@dta[0])^;
                  end else begin
                    dec(dta,4);
                    j.s:=pw(@dta[2])^; j.o:=pw(@dta[0])^;
                  end;
                  scheduler.addtask(dis_code,priority_definitecode,j,0,nil);
                  xrefs.addxref(j,newdsm.addr,0);
                end;
               ARG_MODRM,
               ARG_MODRM_FPTR:
                begin
                  if options.mode32 then begin
                    if (newdsm.data[0]=#$ff)and(newdsm.data[1]=#$25)and(tabtype=TABLE_EXT) then begin
                      j.s:=loc.s; j.o:=pd(@newdsm.data[2])^;
                      if import.isname(j) then begin
                        imp:=pgnameitem(import.nextiterator);
                        getmem(impname,GNAME_MAXLEN+1);
                        impname[0]:='_';
                        impname[GNAME_MAXLEN]:=#0;
                        lstrcpyn(@impname[1],imp.nam,GNAME_MAXLEN-2);
if ($102cd22 = loc.o) or ($102cb1f = loc.o) then
  i:=i;

                        scheduler.addtask(namecurloc,priority_nameloc,loc,0,impname);
                      end;
                    end;
                  end;
                  scheduler.addtask(dis_jumptable,priority_definitecode,loc,0,nil);
                end;
              end; {case}
            end;
            case a1 of
             ARG_IMM32:
              if reloc.isreloc(loc,length-4) then begin
                newdsm.overrid:=over_dsoffset;
                dta:=@mcode[length-4];
                j.s:=options.dseg; j.o:=pd(@dta[0])^;
                xrefs.addxref(j,newdsm.addr,0);
              end;
             ARG_IMM:
              if options.mode32 then begin
                if reloc.isreloc(loc,length-4) then begin
                  newdsm.overrid:=over_dsoffset;
                  dta:=@mcode[length-4];
                  j.s:=options.dseg; j.o:=pd(@dta[0])^;
                  xrefs.addxref(j,newdsm.addr,0);
                end;
              end;
             ARG_MEMLOC:
              if options.mode32 then begin
                newdsm.overrid:=over_dsoffset;
                dta:=@mcode[length-4];
                j.s:=options.dseg; j.o:=pd(@dta[0])^;
                xrefs.addxref(j,newdsm.addr,0);
              end;
             ARG_MMXMODRM,
             ARG_XMMMODRM,
             ARG_MODRM_S,
             ARG_MODRMM512,
             ARG_MODRMQ,
             ARG_MODRM_SREAL,
             ARG_MODRM_PTR,
             ARG_MODRM_WORD,
             ARG_MODRM_SINT,
             ARG_MODRM_EREAL,
             ARG_MODRM_DREAL,
             ARG_MODRM_WINT,
             ARG_MODRM_LINT,
             ARG_MODRM_BCD,
             ARG_MODRM_FPTR,
             ARG_MODRM:
              if options.mode32 then begin
                if (byte(newdsm.data[newdsm.modrm]) and $c7)=5 then begin
                  // straight disp32
                  dta:=@mcode[newdsm.modrm+1];
                  j.s:=options.dseg; j.o:=pd(@dta[0])^;
                  xrefs.addxref(j,newdsm.addr,0);
                end;
              end;
            end;
            case a2 of
             ARG_IMM32:
              if reloc.isreloc(loc,length-4) then begin
                newdsm.overrid:=over_dsoffset;
                dta:=@mcode[length-4];
                j.s:=options.dseg; j.o:=pd(@dta[0])^;
                xrefs.addxref(j,newdsm.addr,0);
              end;
             ARG_IMM:
              if options.mode32 then begin
                if reloc.isreloc(loc,length-4) then begin
                  newdsm.overrid:=over_dsoffset;
                  dta:=@mcode[length-4];
                  j.s:=options.dseg; j.o:=pd(@dta[0])^;
                  xrefs.addxref(j,newdsm.addr,0);
                end;
              end;
             ARG_MEMLOC:
              if options.mode32 then begin
                newdsm.overrid:=over_dsoffset;
                dta:=@mcode[length-4];
                j.s:=options.dseg; j.o:=pd(@dta[0])^;
                xrefs.addxref(j,newdsm.addr,0);
              end;
             ARG_MMXMODRM,
             ARG_XMMMODRM,
             ARG_MODRM_S,
             ARG_MODRMM512,
             ARG_MODRMQ,
             ARG_MODRM_SREAL,
             ARG_MODRM_PTR,
             ARG_MODRM_WORD,
             ARG_MODRM_SINT,
             ARG_MODRM_EREAL,
             ARG_MODRM_DREAL,
             ARG_MODRM_WINT,
             ARG_MODRM_LINT,
             ARG_MODRM_BCD,
             ARG_MODRM_FPTR,
             ARG_MODRM:
              if options.mode32 then begin
                if byte(newdsm.data[newdsm.modrm]) and $c7=5 then begin
                  // straight disp32
                  dta:=@mcode[newdsm.modrm+1];
                  j.s:=options.dseg; j.o:=pd(@dta[0])^;
                  xrefs.addxref(j,newdsm.addr,0);
                end
              end;
            end; {case}
            result:=newdsm; exit;
          end;
        end; //if
        inc(instnum);
      end;  //while
    end; //if
    inc(tablenum);
  end; //while
except
  messagebox(0,'1','2',0);
end
end;

// arglength                                                             *
// - a function which returns the increase in length of an instruction   *
//   due to its argtype, used by the decodeinst engine in calculating    *
//   the instruction length                                              *
function tdisasm.arglength(a:argtype; modrmbyte,sibbyte:char; flgs:dword; omode32:boolean):byte;
var rm:byte;
begin
  result:=0;
  case a of
   ARG_IMM:
    begin
     if flgs and FLAGS_8BIT<>0 then begin result:=1; exit; end;
     if not omode32 then result:=2 else result:=4;
    end;
   ARG_NONEBYTE:   result:=1;
   ARG_RELIMM,
   ARG_MEMLOC:     if options.mode16 then result:=2 else result:=4;
   ARG_RELIMM8,
   ARG_SIMM8,
   ARG_IMM8,
   ARG_IMM8_IND:   result:=1;
   ARG_IMM32:      result:=4;
   ARG_IMM16_A,
   ARG_IMM16,
   ARG_MEMLOC16:   result:=2;
   ARG_FADDR:      if options.mode16 then result:=4 else result:=6;
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
   ARG_MODRM_SINT,
   ARG_MODRM_EREAL,
   ARG_MODRM_DREAL,
   ARG_MODRM_WINT,
   ARG_MODRM_LINT,
   ARG_MODRM_BCD,
   ARG_MODRM_FPTR,
   ARG_MODRM:
    begin
      result:=1;
      rm:=(byte(modrmbyte) and $c0) shr 6;
      case rm of
       0:
         if options.mode32 then begin
           if (byte(modrmbyte) and $07)=5 then result:=5; // disp32
           if (byte(modrmbyte) and $07)=4 then begin
             if (byte(sibbyte) and $07)=5 then result:=6
             else result:=2; //sib byte - need to check if r=5 also.
           end;
         end else if (byte(modrmbyte) and $07)=6 then result:=3;
       1:
         begin
           if options.mode32 then begin
             if (byte(modrmbyte) and $07)=4 then begin
               result:=3; exit;//sib byte
             end;
           end;
           result:=2; // disp8
         end;
       2:
         if options.mode32 then begin
           if (byte(modrmbyte) and $07)=4 then result:=6 //sib byte
           else result:=5; // disp32
         end else result:=3; // disp16
       3:result:=1;
      end;
    end;
  end;
end;

{************************************************************************
* compare function                                                      *
* - the compare function for the list of disassembled instructions.     *
* - the disassembled instructions are kept in order using location, and *
*   type where type indicates instruction, comment, segheader line, etc *
*   as these are kept in the database of disassembled instructions. The *
*   window that the user sees into the disassembly is simply a view of  *
*   this database with one line per record.                             *
************************************************************************}
function tdisasm.compare(a,b:listitem):integer;
var i,j:pdsmitem;
begin
  i:=pdsmitem(a); j:=pdsmitem(b);
  result:=-1;
  if eq(i.addr,j.addr) then begin
    if i.typ=j.typ then begin
      result:=0; exit;
    end else if i.typ>j.typ then begin
      result:=1; exit;
    end; exit;
  end;
  if gr(i.addr,j.addr) then result:=1;
end;

{************************************************************************
* deletion function                                                     *
* - in deleting the database we delete any comments that may be         *
*   attached, overrides the standard list item delete function          *
************************************************************************}
//deletion function for list
procedure tdisasm.delfunc(d:listitem);
var i:pdsmitem;
begin
  i:=pdsmitem(d);
 // bugfix by Mark Ogden - added dsmnameloc
  if (i.typ<>dsmcode)and(i.typ<>dsmnameloc) then
    if i.tptr<>nil then freemem(i.tptr);
  freemem(i);
end;

{************************************************************************
* undefineline                                                          *
* - this simply deletes any code item in the disassembly database, for  *
*   the users current line in the database/window                       *
************************************************************************}
procedure tdisasm.undefineline;
var
  tblock:pdsmitem;
  outhere:lptr;
begin
  tblock:=dio.findcurrentline;
  if tblock=nil then exit;
  outhere:=tblock.addr;
  tblock:=nextiter_code(tblock);
  if tblock=nil then exit;
  if eq(outhere,tblock.addr) then begin
    delfrom(listitem(tblock));
    dio.updatewindow;
  end;
end;

{************************************************************************
* undefinelines                                                         *
* - undefines the next 10 lines of code, or until a non-disassembled    *
*   item is found                                                       *
************************************************************************}
procedure tdisasm.undefinelines;
var
  tblock:pdsmitem;
  outhere:lptr;
  i:integer;
begin
  tblock:=dio.findcurrentline;
  if tblock=nil then exit;
  outhere:=tblock.addr;
  for i:=0 to 9 do begin
    tblock:=nextiter_code(tblock);
    if tblock<>nil then begin
      if eq(outhere,tblock.addr) then begin
        inc(outhere.o,tblock.length);
        delfrom(listitem(tblock));
        tblock:=pdsmitem(nextiterator);
      end else break;
    end;
  end;
  dio.updatewindow;
end;

{************************************************************************
* undefinelines_long                                                    *
* - here we continue undefining any code items in the database from the *
*   users line until we come to a location which is not code, or some   *
*   other kind of item in the database, like a comment, name, or xref   *
************************************************************************}
procedure tdisasm.undefinelines_long;
var
  tblock:pdsmitem;
  outhere:lptr;
begin
  tblock:=dio.findcurrentline;
  if tblock=nil then exit;
  outhere:=tblock.addr;
  tblock:=nextiter_code(tblock);
  while tblock<>nil do begin
    if tblock.length=0 then break;
    if eq(outhere,tblock.addr) then begin
      inc(outhere.o,tblock.length);
      delfrom(listitem(tblock));
      tblock:=pdsmitem(nextiterator);
    end else break;
  end;
  dio.updatewindow;
end;

{************************************************************************
* undefineblock                                                         *
* - a block undefine using a selected block of code, we simply undefine *
*   any code items found between the start and end points of the block  *
************************************************************************}
procedure tdisasm.undefineblock(ufrom,uto:lptr);
var
  tblock:pdsmitem;
  outhere:lptr;
begin
  tblock:=dsmfindaddrtype(ufrom,dsmcode);
  if tblock=nil then exit;
  outhere:=tblock.addr;
  while tblock<>nil do begin
    if gr(tblock.addr,uto) then break;
    if (tblock.typ=dsmcode)and greq(tblock.addr,ufrom) then begin
      delfrom(listitem(tblock));
    end;
    tblock:=pdsmitem(nextiterator);
  end;
  dio.updatewindow;
end;

{************************************************************************
* discomment                                                            *
* - this adds a comment to the disassembly database. It is used to add  *
*   different types of comments (like segheaders and user entered       *
*   comments)                                                           *
************************************************************************}
procedure tdisasm.discomment(loc:lptr; typ:dsmitemtype; comment:pchar);
var newdsm:pdsmitem;
begin
  getmem(newdsm,sizeof(tdsmitem));
  initnewdsm(newdsm,loc,typ);
  newdsm.tptr:=comment;
  newdsm.length:=0;
  newdsm.data:=comment;
  addto(listitem(newdsm));
  dio.updatewindowifinrange(loc);
end;

{************************************************************************
* disautocomment                                                        *
* - this is a second function to add a comment to the disassembly       *
*   database, but only if there is no comment already there. This is    *
*   used to add disassembler autocomments. This is currently only used  *
*   in resource disassembly, but could easily be used to add standard   *
*   comments for particular instructions or for API calls, or for DOS   *
*   INTs.                                                               *
************************************************************************}
procedure tdisasm.disautocomment(loc:lptr; typ:dsmitemtype; comment:pchar);
var
  newdsm,fdsm:pdsmitem;
begin
  fdsm:=dsmfindaddrtype(loc,typ);
  if fdsm<>nil then if eq(fdsm.addr,loc) and (fdsm.typ=typ) then begin
    freemem(comment); exit;
  end;
  getmem(newdsm,sizeof(tdsmitem));
  initnewdsm(newdsm,loc,typ);
  newdsm.tptr:=comment;
  newdsm.length:=0;
  newdsm.data:=comment;
  addto(listitem(newdsm));
  dio.updatewindowifinrange(loc);
end;

{************************************************************************
* delcomment                                                            *
* - this is used to delete comments from the database. Typically it is  *
*   called when the user enters a comment for a location. We delete the *
*   old one and then add the new one later.                             *
************************************************************************}
procedure tdisasm.delcomment(loc:lptr; typ:dsmitemtype);
var fdsm:pdsmitem;
begin
  fdsm:=dsmfindaddrtype(loc,typ);
  if fdsm<>nil then if eq(fdsm.addr,loc)and(fdsm.typ=typ) then begin
    delfrom(listitem(fdsm));
    dio.updatewindowifinrange(loc);
  end;
end;

{************************************************************************
* interpretmod                                                          *
* - this is used by the jumptable detection routines in order to        *
*   examine a modrm/sib encoding for information                        *
* - it returns information about offsets and indexes and the registers  *
*   in use, and any multiplier                                          *
************************************************************************}
function tdisasm.interpretmod(data:pchar; toffs:pd; indexreg,indexreg2,indexamount:pchar; numjumps:pd):boolean;
var
  rm,modrm,sib:byte;
begin
  result:=FALSE;
  rm:=(byte(data[0]) and $c0) shr 6;
  modrm:=byte(data[0]) and $07;
  case rm of
   0:
    begin
     if options.mode32 then begin
       if modrm=5 then begin   // disp32 only.
         toffs^:=pd(@data[1])^;
         numjumps^:=1;
       end else if modrm=4 then begin        // case 4=sib
         sib:=byte(data[1]);
         if (sib and $07=5) then toffs^:=pd(@data[2])^  // disp32
         else exit; // no disp
         if ((sib shr 3) and $07)=4 then numjumps^:=1  // no scaled index reg
         else begin
           byte(indexreg^):=(sib shr 3) and $07;
           case sib shr 6 of
            0: indexamount^:=#1;
            1: indexamount^:=#2;
            2: indexamount^:=#4;
            3: indexamount^:=#8;
           end;
         end;
        end else exit; // no disp
      end else begin// 16-bit mode
        if modrm=6 then begin // disp16 only
          toffs^:=pd(@data[1])^;
          numjumps^:=1;
        end else exit; // no disp
      end;
    end;
   1: exit; // all disp8 offsets - don't follow
   2: if options.mode32 then begin
        if modrm=4 then begin        // case 4=sib
          sib:=byte(data[1]);
          toffs^:=pd(@data[2])^;
          byte(indexreg2^):=sib and $07;
          if ((sib shr 3) and $07)=4 then // no scaled index reg
          else begin
            byte(indexreg^):=(sib shr 3) and $07;
            case sib shr 6 of
             0: indexamount^:=#1;
             1: indexamount^:=#2;
             2: indexamount^:=#4;
             3: indexamount^:=#8;
            end;
          end;
        end else begin
          toffs^:=pd(@data[1])^;
          byte(indexreg2^):=byte(data[0]) and $07;
        end;
      end else begin // 16bit mode
        toffs^:=pw(@data[1])^;
        byte(indexreg^):=byte(data[0]) and $07; // NB double index reg eg bx+si
      end;
    3: exit;
     // case 3 - no jump table offset present. indirect jump.
  end;
  result:=TRUE;
end;

{************************************************************************
* disjumptable                                                          *
* - this was written some ago as a quick hack for decoding jump tables  *
* - it tries to obtain information on the table itself, and looks for   *
*   an indication of the number of items in the table by examining      *
*   prior instructions, although it is quite unintelligent in some      *
*   ways.                                                               *
* - it also looks for indextables which are used in complex jumptables  *
*   to decode an initial case number for the jumptable.                 *
* - although good for some compilers the output from some modern        *
*   compilers does not fare well in the analysis.                       *
************************************************************************}
procedure tdisasm.disjumptable(loc:lptr);
var
  investigate:pdsmitem;
  dblock,idblock:pdsegitem;
  data:pchar;
  pbyte:byte;       // prefix byte
  t,it,indx,xr:lptr;
  i,numjumps,inumjumps:integer;
  indexreg,indexamount,indexreg2:byte;
  iindexreg,iindexamount,iindexreg2:byte;
  tablename:pchar;
  tablenum:string;
  itable:boolean;
begin
  pbyte:=0;
  numjumps:=0;
  indexreg:=0;
  indexreg2:=0;
  indexamount:=0;
  inumjumps:=0;
  iindexreg:=0;
  iindexreg2:=0;
  iindexamount:=0;
  investigate:=dsmfindaddrtype(loc,dsmcode);
  if investigate=nil then exit;
  // check that inst is still there/ correct type of jump
  // adjust for any segment overrides added since
  if (loc.o-investigate.addr.o)<4 then loc.o:=investigate.addr.o;
  if (investigate.addr.o<>loc.o)or(investigate.typ<>dsmcode) then exit;
  if pasminstdata(investigate.tptr).arg1<>ARG_MODRM then exit;
  if (investigate.flags and (FLAGS_JMP or FLAGS_CALL or FLAGS_CJMP))=0 then exit;
  data:=investigate.data+investigate.modrm;
  if not interpretmod(data,@t.o,@indexreg,@indexreg2,@indexamount,@numjumps) then exit;
  // find target - jump table, need to use default ds:/ check for cs: override
  if investigate.flags and FLAGS_SEGPREFIX<>0 then begin
    pbyte:=byte(investigate.data[0]);
    if (pbyte=$66)or(pbyte=$67) then pbyte:=byte(investigate.data[1]);
    if (pbyte=$66)or(pbyte=$67) then pbyte:=byte(investigate.data[2]);
  end;
  t.s:=options.dseg;
  if pbyte=$2e then t.s:=loc.s;
  dblock:=dta.findseg(t);      // find segment item.
  if dblock=nil then exit;
  // look at previous instructions for number of entries
  itable:=FALSE;
  if numjumps=0 then begin
    i:=0;
    while (i>=0)and(i<10) do begin
      investigate:=pdsmitem(lastiterator);
      if investigate=nil then break;                                      // no previous insts
      if (investigate.addr.s<>loc.s)or(investigate.addr.o+50<loc.o) then break; // too far back
      if investigate.typ<>dsmcode then dec(i)                               // skip non-code
      else
        if((strcomp(pasminstdata(investigate.tptr).nam,'mov'  )=0) or
           (strcomp(pasminstdata(investigate.tptr).nam,'movzx')=0))
          and((pasminstdata(investigate.tptr).arg1=ARG_MODRM)
          or(pasminstdata(investigate.tptr).arg1=ARG_MODRM8))
        then begin
          if not itable then
          if interpretmod(investigate.data+investigate.modrm,@it.o,@iindexreg,@iindexreg2,@iindexamount,@inumjumps)
          then begin
            itable:=TRUE;
            indx.o:=investigate.addr.o;
          end;
        end else
          if((strcomp(pasminstdata(investigate.tptr).nam,'mov')=0)
           or(strcomp(pasminstdata(investigate.tptr).nam,'movzx')=0))
           and((pasminstdata(investigate.tptr).arg2=ARG_MODRM)
           or(pasminstdata(investigate.tptr).arg2=ARG_MODRM8))
          then begin
            if not itable then
            if interpretmod(investigate.data+investigate.modrm,@it.o,@iindexreg,@iindexreg2,@iindexamount,@inumjumps)
            then begin
              itable:=TRUE;
              indx.o:=investigate.addr.o;
            end;
          end else
            if investigate.data[0]=#$3b then begin    // cmp inst
              if options.mode32 then numjumps:=pd(@investigate.data[1])^+1
              else numjumps:=pw(@investigate.data[1])^+1;
              break;
            end else
              if investigate.data[0]=#$3d then begin    // cmp inst
                if options.mode32 then numjumps:=pd(@investigate.data[1])^+1
                else numjumps:=pw(@investigate.data[1])^+1;
                break;
              end else
                if (investigate.data[0]=#$83)and(investigate.data[1]>=#$c0) then begin // cmp reg,imm8
                  numjumps:=byte(investigate.data[2])+1;
                  break;
                end;
       inc(i);
     end;
  end;
  if itable then begin
    it.s:=t.s;
    idblock:=dta.findseg(it);
    if idblock=nil then exit;
    inumjumps:=numjumps;
    if (inumjumps<2)or(inumjumps>$100) then exit;
    numjumps:=0;
    for i:=0 to inumjumps-1 do begin
      if it.o+i>dblock.addr.o+dblock.size then exit;
///2016
      if byte(dblock.data[(it.o-dblock.addr.o)+i]) > numjumps then
         numjumps:=byte(dblock.data[(it.o-dblock.addr.o)+i]);
    end;
    inc(numjumps);
  end;
  // add code disassemblies to scheduler
  // name it
  if (numjumps=0)or(numjumps>$100) then exit;
  getmem(tablename,20);
  if numjumps>1 then begin
    inc(jtables);
    fmtstr(tablenum,'%d',[jtables]);
    strcopy(tablename,'jumptable_');
  end else begin
    inc(irefs);
    fmtstr(tablenum,'%d',[irefs]);
    strcopy(tablename,'indirectref_');
  end;
  strcat(tablename,pchar(tablenum));
  // imports and exports added to this list - build 17
  if (not nam.isname(t))and(not expt.isname(t))and(not import.isname(t)) then begin
    scheduler.addtask(namecurloc,priority_nameloc,t,0,tablename);
  end;
  xrefs.addxref(t,loc,0);
  if itable then begin
    getmem(tablename,20);
    inc(itables);
    fmtstr(tablenum,'%d',[itables]);
    strcopy(tablename,'indextable_');
    strcat(tablename,pchar(tablenum));
    if not nam.isname(it) then begin
      scheduler.addtask(namecurloc,priority_nameloc,it,0,tablename);
    end;
    indx.s:=loc.s;
    xrefs.addxref(it,indx,0);
  end;
  // disassemble data
  // disassemble code
  if indexamount=0 then if options.mode32 then indexamount:=4 else indexamount:=2;
  for i:=0 to numjumps-1 do begin
    if t.o+i*indexamount>dblock.addr.o+dblock.size then exit;
    if options.mode32 then begin
      xr.s:=loc.s;
      xr.o:=pd(@dblock.data[(t.o-dblock.addr.o)+i*indexamount])^; //???
      scheduler.addtask(dis_datadsoffword,priority_data,t,i*indexamount,nil);
      scheduler.addtask(dis_code,priority_definitecode,xr,0,nil);
      xrefs.addxref(xr,t,i*indexamount);
    end else begin
      xr.s:=loc.s;
      xr.o:=pw(@dblock.data[(t.o-dblock.addr.o)+i*indexamount])^; //???
      scheduler.addtask(dis_dataword,priority_data,t,i*indexamount,nil);
      scheduler.addtask(dis_code,priority_definitecode,xr,0,nil);
      xrefs.addxref(xr,t,i*indexamount);
    end;
  end;
end;

{************************************************************************
* disxref                                                               *
* - this puts an xref line into the disassembly database for a given    *
*   loc, but only if one is not already present.                        *
* - rewritten Borg 2.22 so that new is only called when necessary       *
************************************************************************}
procedure tdisasm.disxref(loc:lptr);
var
  i:integer;
  locname:pchar;
  newdsm,chk:pdsmitem;
begin
  chk:=dsmfindaddrtype(loc,dsmxref);
  if chk<>nil then begin
    if (chk.typ=dsmxref)and eq(chk.addr,loc) then exit;
    if (chk.length<>0)and(chk.addr.s=loc.s)and(dsmitem_contains_loc(chk,loc))
    then exit;
  end;
  getmem(newdsm,sizeof(tdsmitem));
  initnewdsm(newdsm,loc,dsmxref);
  newdsm.tptr:=nil;
  newdsm.length:=0;
  newdsm.data:=nil;
  addto(listitem(newdsm));
  if not((expt.isname(loc))or(import.isname(loc))or(nam.isname(loc))) then begin
    getmem(locname,20);
    strfmt(locname,'loc_%8.8x',[loc.o]);
    scheduler.addtask(namecurloc,priority_nameloc,loc,0,locname);
  end;
  dio.updatewindowifinrange(loc);
end;

{************************************************************************
* getlength                                                             *
* - an external interface routine which just returns the given          *
*   locations disassembled code length. It is used by the search engine *
* - default return value of 1 means 'db'                                *
************************************************************************}
function tdisasm.getlength(loc:lptr):integer;
var fnd:pdsmitem;
begin
  result:=1;
  fnd:=dsmfindaddrtype(loc,dsmcode);
  if fnd=nil then exit;
  if neq(fnd.addr,loc)or(fnd.typ<>dsmcode) then exit;
  result:=fnd.length;
end;

procedure tdisasm.addcomment(loc:lptr; x:dword; comment:pchar);
var nm:pchar;
begin
  inc(loc.o,x);
  getmem(nm,strlen(comment)+1);
  strcopy(nm,comment);
  disautocomment(loc,dsmcomment,nm);
end;

function tdisasm.disname_or_ordinal(loc:lptr; comment_ctrl:boolean):integer;
var
  dblock:pdsegitem;
  maxlen,idnum:dword;
begin
  result:=0;
  dblock:=dta.findseg(loc);
  if dblock=nil then exit;
  maxlen:=dblock.size-(loc.o-dblock.addr.o);
  if maxlen<2 then exit;
  idnum:=pw(dblock.data+(loc.o-dblock.addr.o))^;
  if idnum=$ffff then begin // ordinal follows
    disdataword(loc,0);
    idnum:=pwa(dblock.data+(loc.o-dblock.addr.o))^[1];
    disdataword(loc,2);
    // ctrl class -> add description for class
    if comment_ctrl then begin
      case idnum of
       $0080: addcomment(loc,2,'[Button]');
       $0081: addcomment(loc,2,'[Edit]');
       $0082: addcomment(loc,2,'[Static]');
       $0083: addcomment(loc,2,'[List Box]');
       $0084: addcomment(loc,2,'[Scroll Bar]');
       $0085: addcomment(loc,2,'[Combo Box]');
      end;
    end;
    result:=4; exit;
  end;
  disdataucstring(loc);
  result:=getlength(loc);
end;

// not using basename at the moment
procedure tdisasm.disdialog(loc:lptr; basename:pchar);
var
  cloc:lptr;
  ilen:integer;
  numctrls:integer;
  tester:tdsmitem;
  findit:pdsmitem;
  exd:boolean;
  dblock:pdsegitem;
  maxlen,idnum,hdrstyle:dword;
  // ho hum, things are never simple
  // - after adding the dialog format i found that some dialogs were just completely
  // different - the so called dialogex dialogs, and after much hunting around i found
  // some details on microsofts site (wow). so then i hacked the code up to do it....
  // dialog header
begin
  exd:=FALSE;
  dblock:=dta.findseg(loc);
  if dblock=nil then exit;
  maxlen:=dblock.size-(loc.o-dblock.addr.o);
  if maxlen<4 then exit;
  idnum:=pda(dblock.data+(loc.o-dblock.addr.o))^[0];
  if idnum=$ffff0001 then exd:=TRUE; // whoah, dialogex found
  (* basic struct is as follows:
  struct dialogboxheader
  { unsigned long style,extendedstyle;
    unsigned short numberofitems;
    unsigned short x,y;
    unsigned short cx,cy;
  };*)
  if exd then begin
    addcomment(loc,0,'Signature+Version');
    disdatadword(loc,0);
    addcomment(loc,4,'HelpID');
    disdatadword(loc,4);
    loc.o:=loc.o+8;
  end;
  if exd then addcomment(loc,0,'Extended Style')
  else addcomment(loc,0,'Style');
  disdatadword(loc,0);
  if exd then addcomment(loc,4,'Style')
  else addcomment(loc,4,'Extended Style');
  disdatadword(loc,4);
  addcomment(loc,8,'Number of Items');
  disdataword(loc,8);
  addcomment(loc,10,'x');
  disdataword(loc,10);
  addcomment(loc,12,'y');
  disdataword(loc,12);
  addcomment(loc,14,'cx');
  disdataword(loc,14);
  addcomment(loc,16,'cy');
  disdataword(loc,16);
  cloc:=loc; inc(cloc.o,18);
  addcomment(cloc,0,'Menu name/ordinal');
  ilen:=disname_or_ordinal(cloc,FALSE);
  inc(cloc.o,ilen);
  addcomment(cloc,0,'Class name/ordinal');
  ilen:=disname_or_ordinal(cloc,FALSE);
  inc(cloc.o,ilen);
  addcomment(cloc,0,'Caption');
  disdataucstring(cloc);
  inc(cloc.o,getlength(cloc));
  tester.addr.o:=loc.o+4*ord(exd); //???
  tester.typ:=dsmcode;
  findit:=dsmfindaddrtype(tester.addr,dsmcode);
  hdrstyle:=0;
  if findit<>nil then begin
    if (findit.addr.o=loc.o+4*byte(exd)) and (findit.typ=dsmcode) then
      hdrstyle:=pda(findit.data)^[0];
  end;
  // i noticed a reference to DS_SHELLFONT on msdn, but what is that ????????
  if hdrstyle and DS_SETFONT<>0 then begin  // if ds_setfont then 2 more items...in theory
    addcomment(cloc,0,'font pointsize');
    disdataword(cloc,0);
    inc(cloc.o,2);
    if exd then begin // more options with exd
      addcomment(cloc,0,'weight');
      disdataword(cloc,0);
      inc(cloc.o,2);
      addcomment(cloc,0,'italic');
      inc(cloc.o);
      addcomment(cloc,0,'charset');
      inc(cloc.o);
    end;
    addcomment(cloc,0,'font');
    disdataucstring(cloc);
    inc(cloc.o,getlength(cloc));
  end;
  // now do controls
  tester.addr.o:=loc.o+8;
  tester.typ:=dsmcode;
  findit:=dsmfindaddrtype(tester.addr,dsmcode);
  numctrls:=0;
  if findit<>nil then begin
    if (findit.addr.o=loc.o+8)and(findit.typ=dsmcode) then
      numctrls:=pwa(findit.data)^[0];
  end;
  (*struct ctrlheader
  { unsigned long style,extendedstyle;
    unsigned short x,y;
    unsigned short cx,cy;
    unsigned short wid;
  };*)
  while numctrls<>0 do begin
    if cloc.o and $03<>0 then cloc.o:=(cloc.o or $03)+1;
    if exd then begin
      addcomment(cloc,0,'HelpID');
      disdatadword(cloc,0);
      inc(cloc.o,4);
    end;
    if exd then addcomment(cloc,0,'Extended Style')
    else addcomment(cloc,0,'Style');
    disdatadword(cloc,0);
    if exd then addcomment(cloc,4,'Style')
    else addcomment(cloc,4,'Extended Style');
    disdatadword(cloc,4);
    addcomment(cloc,8,'x');
    disdataword(cloc,8);
    addcomment(cloc,10,'y');
    disdataword(cloc,10);
    addcomment(cloc,12,'cx');
    disdataword(cloc,12);
    addcomment(cloc,14,'cy');
    disdataword(cloc,14);
    addcomment(cloc,16,'wid');
    disdataword(cloc,16);
    inc(cloc.o,18);
    if exd then if cloc.o and $03<>0 then cloc.o:=(cloc.o or $03)+1;
    addcomment(cloc,0,'Class id');
    ilen:=disname_or_ordinal(cloc,TRUE);
    inc(cloc.o,ilen);
    addcomment(cloc,0,'Text');
    ilen:=disname_or_ordinal(cloc,FALSE);
    inc(cloc.o,ilen);
    addcomment(cloc,0,'Extra Stuff');
    disdataword(cloc,0);
    findit:=dsmfindaddrtype(cloc,dsmcode);
    if findit<>nil then begin
      if eq(findit.addr,cloc) and (findit.typ=dsmcode) then
        inc(cloc.o,pwa(findit.data)^[0]);
    end;
    inc(cloc.o,2);
    dec(numctrls);
  end;
end;

procedure tdisasm.disstringtable(loc:lptr; basename:pchar);
var
  i:integer;
  cloc:lptr;
  callit:array[0..40] of char;
  idnum:dword;
  ipt:integer;
  lastdsm:pdsmitem;
begin
  ipt:=0; idnum:=0;
  if basename<>nil then begin
    while (basename[ipt]<>#0) and (basename[ipt]<>':') do inc(ipt);
    if basename[ipt]=':' then begin
      inc(ipt);
      while basename[ipt]<>#0 do begin
        case basename[ipt] of
         'A'..'F': idnum:=idnum*16+(byte(basename[ipt])-byte('A'))+10;
         'a'..'f': idnum:=idnum*16+(byte(basename[ipt])-byte('a'))+10;
         '0'..'9': idnum:=idnum*16+(byte(basename[ipt])-byte('0'));
         'h','H' : break;
        end; inc(ipt);
      end;
    end;
  end;
  cloc:=loc;
  for i:=0 to 15 do begin  // 16 strings in a stringtable, of type unicode_pascal.
    disdataupstring(cloc);
    if idnum<>0 then begin
      strlfmt(@callit,40,'String_ID_%x',[(idnum-1)*16+i]);
      nam.addname(cloc,callit);
    end;
    lastdsm:=dsmfindaddrtype(cloc,dsmcode);
    if lastdsm=nil then break;
    if (lastdsm.typ<>dsmcode)or neq(lastdsm.addr,cloc) then break;
    inc(cloc.o,lastdsm.length);
  end;
end;

procedure tdisasm.disdatasingle(loc:lptr);
begin
  disdata(loc,@_asm_fp[0],4,over_null);
end;

procedure tdisasm.disdatadouble(loc:lptr);
begin
  disdata(loc,@_asm_fp[1],8,over_null);
end;

procedure tdisasm.disdatalongdouble(loc:lptr);
begin
  disdata(loc,@_asm_fp[2],10,over_null);
end;

initialization
  dsm:=tdisasm.create;
finalization
  dsm.free;
end.


