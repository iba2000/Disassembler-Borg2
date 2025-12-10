unit database;
interface
uses windows,sysutils,commdlg,classes,common,savefile,menus,datas,disasm,
     gname,relocs,xref,decrypt,exeload,schedule,disio,proctab;

procedure savedb;
procedure loaddb;
function savemessbox(hdwnd:hwnd; msg,wParam,lParam:longint):longint;stdcall;
function loadmessbox(hdwnd,msg,wParam,lParam:dword):dword;stdcall;

var
  Thread:procedure;
  Changemenus:procedure;

implementation

{************************************************************************
* savemessbox                                                           *
* - A small dialog box which contains the message 'saving' to be shown  *
*   as a database file is saved                                         *
************************************************************************}
function savemessbox(hdwnd:hwnd; msg,wParam,lParam:longint):longint;
begin
  result:=0;
  case msg of
   WM_INITDIALOG: CenterWindow(hdwnd);
  end;
end;

{************************************************************************
* loadmessbox                                                           *
* - A small dialog box which contains the message 'loading' to be shown *
*   as a database file is loaded                                        *
************************************************************************}
function loadmessbox(hdwnd,msg,wParam,lParam:dword):dword;
begin
  result:=0;
  case msg of
   WM_INITDIALOG: CenterWindow(hdwnd);
  end;
end;

{************************************************************************
* savedecryptitems                                                      *
* - this saves the list of decryptors to the database                   *
************************************************************************}
function savedecryptitems(sf:tsavefile):boolean;
var ndecs:dword;
begin
  result:=false;
  ndecs:=decrypter.numlistitems;
  decrypter.resetiterator;
  if not sf.swrite(@ndecs,sizeof(dword)) then exit;
  while ndecs<>0 do begin
    if not decrypter.write_item(sf) then exit;
    dec(ndecs);
  end;
  result:=true;
end;

{************************************************************************
* loaddecryptitems                                                      *
* - here we reload the list of decryptors                               *
************************************************************************}
function loaddecryptitems(sf:tsavefile):boolean;
var num,ndecs:integer;
begin
  result:=false;
  if not sf.sread(@ndecs,sizeof(dword),num) then exit;
  while ndecs<>0 do begin
    if not decrypter.read_item(sf) then exit;
    dec(ndecs);
  end;
  result:=true;
end;

{************************************************************************
* retstacksavedb                                                        *
* - Borg keeps track of the stack even through saves. It simply saves   *
*   the full stack                                                      *
************************************************************************}
function retstacksavedb(sf:tsavefile; filebuff:pchar):boolean;
begin
  result:=false;
  if not sf.swrite(@dio.retstack.stacktop,sizeof(integer)) then exit;
  if not sf.swrite(@dio.retstack.callstack,6*CALLSTACKSIZE) then exit;
  result:=true;
end;

{************************************************************************
* retstackloaddb                                                        *
* - reloads the stack from the saved database file                      *
************************************************************************}
function retstackloaddb(sf:tsavefile; filebuff:pchar):boolean;
var num:integer;
begin
  result:=false;
  if not sf.sread(@dio.retstack.stacktop,sizeof(integer),num) then exit;
  if not sf.sread(@dio.retstack.callstack,6*CALLSTACKSIZE,num) then exit;
  result:=true;
end;

{************************************************************************
* dissavedb                                                             *
* - this routine saves the entire disassembly database to the database  *
*   save file. It converts instruction pointers into instruction uids   *
*   and converts data pointers into offsets for saving                  *
************************************************************************}
function dissavedb(sf:tsavefile; filebuff:pchar):boolean;
var
  i,ndsms:dword;
  structsave:tdsmitemsave;
  currdsm:pdsmitem;
begin
  result:=false;
  ndsms:=dsm.numlistitems;
  dsm.resetiterator;
//writeln(log,'pos=',inttohex(numwriten,8));
//writeln(log,'disasm=',ndsms);
  if not sf.swrite(@ndsms,sizeof(dword)) then exit;
  while ndsms<>0 do begin
    currdsm:=pdsmitem(dsm.nextiterator);
    structsave.addr:=currdsm.addr;
    structsave.typ :=currdsm.typ;
    structsave.length:=currdsm.length;
    structsave.modrm:=currdsm.modrm;
    structsave.mode32:=currdsm.mode32;
    structsave.overrid:=currdsm.overrid;
    structsave.flags:=currdsm.flags;
    structsave.displayflags:=currdsm.displayflags;
    if structsave.typ=dsmxref then begin
      structsave.fileoffset:=0;  // nil ptrs
      structsave.tptroffset:=0;
    end else if structsave.typ=dsmcode then begin
      structsave.fileoffset:=currdsm.data-filebuff;
      structsave.tptroffset:=pasminstdata(currdsm.tptr).uniq;
    end else begin
      structsave.fileoffset:=strlen(currdsm.data)+1; // strlen
      structsave.tptroffset:=0; // points to str as well
    end;
//with structsave do write(log,format(' %4.4x:%8.8x %8.8x %3d',[addr.s,addr.o,tptroffset,word(typ)]));
//with structsave do write(log,format(' %3d %2.2x %2d',[length,modrm,integer(mode32)]));
//with structsave do write(log,format(' %8.8x %2.2x %8.8x %2.2x',[fileoffset,byte(overrid),dword(flags),displayflags]));
//writeln(log);
    structsave.mode32:=fixbool(structsave.mode32);
    if not sf.swrite(@structsave,sizeof(tdsmitemsave)) then exit;
    if (structsave.typ<>dsmxref)and(structsave.typ<>dsmcode) then begin
      if not sf.swrite(currdsm.tptr,structsave.fileoffset) then exit;
    end;
    dec(ndsms);
  end;
  // need to save callstack and some other stuff too.
//writeln(log,'pos=',inttohex(numwriten,8));
//writeln(log,'curraddr=',format('%4.4x:%8.8x',[dio.curraddr.s,dio.curraddr.o]));
//writeln(log,'subitem =',byte(dio.subitem));
//writeln(log,'itables =',dsm.itables);
//writeln(log,'jtables =',dsm.jtables);
//writeln(log,'irefs   =',dsm.irefs);
  if not sf.swrite(@dio.curraddr,sizeof(lptr)) then exit;
  i:=dword(dio.subitem);
  if not sf.swrite(@i,4) then exit;
  if not sf.swrite(@dsm.itables,4) then exit;
  if not sf.swrite(@dsm.jtables,4) then exit;
  if not sf.swrite(@dsm.irefs,4)   then exit;
//writeln(log,'pos=',inttohex(numwriten,8));
  result:=retstacksavedb(sf,filebuff);
end;

{************************************************************************
* disloaddb                                                             *
* - this routine loads the entire disassembly database from the save    *
*   file It converts instruction uids into the instruction pointers and *
*   converts offsets back into pointers. We have to search the assembly *
*   instructions for the uids in order to find the correct instruction. *
************************************************************************}
function disloaddb(sf:tsavefile; filebuff:pchar):boolean;
var
  ndsms,num:integer;
  structsave:tdsmitemsave;
  currdsm:pdsmitem;
  asminstctr:integer;
  findasm:pasminstdataarr;
begin
  result:=false;
  if not sf.sread(@ndsms,sizeof(integer),num) then exit;
//writeln(log,'pos=',inttohex(numwriten,8));
//writeln(log,'disasm=',ndsms);
  while ndsms<>0 do begin
    currdsm:=new(pdsmitem);
    if not sf.sread(@structsave,sizeof(tdsmitemsave),num) then exit;
//with structsave do write(log,format(' %4.4x:%8.8x %8.8x %3d',[addr.s,addr.o,tptroffset,word(typ)]));
//with structsave do write(log,format(' %3d %2.2x %2d',[length,modrm,integer(mode32)]));
//with structsave do write(log,format(' %8.8x %2.2x %8.8x %2.2x',[fileoffset,byte(overrid),dword(flags),displayflags]));
//writeln(log);
    currdsm.addr        :=structsave.addr;
    currdsm.typ         :=dsmitemtype(structsave.typ);
    currdsm.length      :=structsave.length;
    currdsm.modrm       :=structsave.modrm;
    currdsm.mode32      :=structsave.mode32;
    currdsm.overrid     :=byteoverride(structsave.overrid);
    currdsm.flags       :=structsave.flags;
    currdsm.displayflags:=structsave.displayflags;
    if structsave.typ=dsmxref then begin
      currdsm.data:=nil; currdsm.tptr:=nil;
    end else if structsave.typ=dsmcode then begin
      currdsm.data:=structsave.fileoffset+filebuff;
      // now reset the tptr = asminstdata ptr (need to find it from the uniqueid)
      asminstctr:=0;
      findasm:=@reconstruct[asminstctr]^;
      while (findasm^[0].uniq div 1000)<>(structsave.tptroffset div 1000) do begin
        inc(asminstctr);
        findasm:=@reconstruct[asminstctr]^;
        if findasm=nil then exit;
      end;
      asminstctr:=0;
      while findasm^[asminstctr].uniq<>structsave.tptroffset do begin
        inc(asminstctr);
        if (findasm^[asminstctr].instbyte=0)and(findasm^[asminstctr].cpu=0)
        then exit;
      end;
      currdsm.tptr:=@findasm^[asminstctr]; //???
    end else begin
      getmem(currdsm.data,structsave.fileoffset);
      currdsm.tptr:=currdsm.data;
    end;
    if (structsave.typ<>dsmxref)and(structsave.typ<>dsmcode) then begin
      if not sf.sread(currdsm.tptr,structsave.fileoffset,num) then exit;
    end;
    dsm.addto(listitem(currdsm));
    dec(ndsms);
  end;
  // need to save callstack and some other stuff too.
  if not sf.sread(@dio.curraddr,sizeof(lptr),num) then exit;
  if not sf.sread(@dio.subitem,sizeof(dsmitemtype),num) then exit;
  if not sf.sread(@dsm.itables,sizeof(integer),num) then exit;
  if not sf.sread(@dsm.jtables,sizeof(integer),num) then exit;
  if not sf.sread(@dsm.irefs,sizeof(integer),num) then exit;
//writeln(log,'pos=',inttohex(numwriten,8));
//writeln(log,'curraddr=',format('%4.4x:%8.8x',[dio.curraddr.s,dio.curraddr.o]));
//writeln(log,'subitem =',byte(dio.subitem));
//writeln(log,'itables =',dsm.itables);
//writeln(log,'jtables =',dsm.jtables);
//writeln(log,'irefs   =',dsm.irefs);
  dsm.dissettable;
  dio.setcuraddr(dio.curraddr);
//writeln(log,'pos=',inttohex(numwriten,8));
  result:=retstackloaddb(sf,filebuff);
end;

{************************************************************************
* saverelocitems                                                        *
* - this saves the relocs list to the database file.                    *
* - we can simply save the number of items followed by each item        *
************************************************************************}
function saverelocitems(sf:tsavefile):boolean;
var nrels:dword;
begin
  result:=false;
  nrels:=reloc.numlistitems;
  reloc.resetiterator;
  // save number of reloc items
//writeln(log,'pos=',inttohex(numwriten,8));
//writeln(log,'relocs=',nrels);
  if not sf.swrite(@nrels,sizeof(dword)) then exit;
  while nrels<>0 do begin
    if not reloc.write_item(sf) then exit else dec(nrels);
//with currrel^ do writeln(log,format(' %4.4x:%8.8x %d',[addr.s,addr.o,word(typ)]));
  end;
  result:=true;
end;

{************************************************************************
* loadrelocitems                                                        *
* - this reloads the list of relocs from the database file and          *
*   constructs the list again                                           *
************************************************************************}
function loadrelocitems(sf:tsavefile):boolean;
var nrels,num:integer;
begin
  result:=false;
  // get number of items
  if not sf.sread(@nrels,sizeof(integer),num) then exit;
  while nrels<>0 do begin
    if not reloc.read_item(sf) then exit else dec(nrels);
  end;
  result:=true;
end;

{************************************************************************
* gnamesavedb                                                           *
* - saves all the names in the list to the database file being saved.   *
*   this is in a one-pass compatible loading format. ie number of items *
*   followed by each item, and for strings the length of the string     *
*   followed by the string.                                             *
************************************************************************}
function gnamesavedb(gn:tgname; sf:tsavefile):boolean;
var
  nexps,nlen:dword;
  currexp:pgnameitem;
begin
  result:=false;
  nexps:=gn.numlistitems;
  gn.resetiterator;
//writeln(log,'pos=',inttohex(numwriten,8));
//writeln(log,'names/imp/exp=',nexps);
  if not sf.swrite(@nexps,sizeof(dword)) then exit;
  while nexps<>0 do begin
    currexp:=pgnameitem(gn.nextiterator);
//writeln(log,format(' %4.4x:%8.8x %2d %s',[currexp.addr.s,currexp.addr.o,strlen(currexp.nam)+1,currexp.nam]));
    if not sf.swrite(@currexp.addr,sizeof(lptr)) then exit;
    nlen:=strlen(currexp.nam)+1;
    if not sf.swrite(@nlen,sizeof(dword)) then exit;
    if not sf.swrite(currexp.nam,nlen) then exit else dec(nexps);
  end;
  result:=true;
end;

{************************************************************************
* gnameloaddb                                                           *
* - loads the names from the database file and reconstructs the names   *
*   list                                                                *
************************************************************************}
function gnameloaddb(gn:tgname; sf:tsavefile):boolean;
var
  nexps,num,nlen:integer;
  currexp:pgnameitem;
begin
  result:=false;
  if not sf.sread(@nexps,sizeof(integer),num) then exit;
  while nexps<>0 do begin
    currexp:=new(pgnameitem);
    if not sf.sread(@currexp.addr,sizeof(lptr),num) then exit;
    if not sf.sread(@nlen,sizeof(dword),num) then exit;
    getmem(currexp.nam,nlen);
    if not sf.sread(currexp.nam,nlen,num) then exit;
    gn.addto(listitem(currexp));
    dec(nexps);
  end;
  result:=true;
end;

{************************************************************************
* savedatasegitems                                                      *
* - we save the data segment data structures to the database file.      *
************************************************************************}
function savedatasegitems(sf:tsavefile; filebuff:pchar):boolean;
var nsegs,nlen:dword;
begin
  result:=false;
  nsegs:=dta.numlistitems;
  dta.resetiterator;
//writeln(log,'pos=',inttohex(numwriten,8));
//writeln(log,'segs=',nsegs);
  if not sf.swrite(@nsegs,sizeof(dword)) then exit;
  while nsegs<>0 do begin
    if not dta.write_item(sf,filebuff) then exit else dec(nsegs);
  end;
  result:=true;
end;

{************************************************************************
* loaddatasegitems                                                      *
* - loads the data segment data structures in                           *
************************************************************************}
function loaddatasegitems(sf:tsavefile; filebuff:pchar):boolean;
var num,nsegs:integer;
begin
  result:=false;
  if not sf.sread(@nsegs,sizeof(integer),num) then exit;
//writeln(log,'pos=',inttohex(numwriten,8));
//writeln(log,'segs=',nsegs);
  while nsegs<>0 do begin
    if not dta.read_item(sf,filebuff) then exit else dec(nsegs);
  end;
  result:=true;
end;

{************************************************************************
* xrefsavedb                                                            *
* save xref list to database file, simply writes the list item out      *
* consisting of loc and ref_by, ie two addresses                        *
************************************************************************}
function xrefsavedb(sf:tsavefile):boolean;
var
  nxrefs:dword;
  currxref:pxrefitem;
begin
  result:=false;
  nxrefs:=xrefs.numlistitems;
  xrefs.resetiterator;
//writeln(log,'pos=',inttohex(numwriten,8));
//writeln(log,'xrefs-',nxrefs);
  if not sf.swrite(@nxrefs,sizeof(dword)) then exit;
  while nxrefs<>0 do begin
    currxref:=pxrefitem(xrefs.nextiterator);
//with currxref^ do writeln(log,format(' %4.4x:%8.8x  %4.4x:%8.8x',[addr.s,addr.o,refby.s,refby.o]));
    if not sf.swrite(@currxref^,sizeof(txrefitem)) then exit else dec(nxrefs);
  end;
  result:=true;
end;

{************************************************************************
* xrefloaddb                                                            *
* load xref list to database file, simply reads the list item in        *
* consisting of loc and ref_by, ie two addresses                        *
* and adds it to the new list                                           *
************************************************************************}
function xrefloaddb(sf:tsavefile):boolean;
var
  nxrefs,num:integer;
  currxref:pxrefitem;
begin
  result:=false;
  if not sf.sread(@nxrefs,sizeof(integer),num) then exit;
//writeln(log,'pos=',inttohex(numwriten,8));
//writeln(log,'xrefs-',nxrefs);
  while nxrefs<>0 do begin
    currxref:=new(pxrefitem);
    if not sf.sread(@currxref^,sizeof(txrefitem),num) then exit;
//with currxref^ do writeln(log,format(' %4.4x:%8.8x  %4.4x:%8.8x',[addr.s,addr.o,refby.s,refby.o]));
    xrefs.addto(listitem(currxref));
    dec(nxrefs);
  end;
  result:=true;
end;

{************************************************************************
* savedbcoord                                                           *
* - coordinates saving of the databases when save as database file is   *
*   chosen in Borg                                                      *
************************************************************************}
procedure savedbcoord(fname,exename:pchar);
var
  sf:tsavefile;
  flen:dword;
  bver:dword;
  sbox:HWND;
begin
  sf:=tsavefile.create;
  sbox:=CreateDialog(Inst,MAKEINTRESOURCE(save_box),mainwindow,@savemessbox);
try
//assignfile(log,'out.log'); rewrite(log);
  // open file
  sf.sopen(fname,GENERIC_WRITE,1,CREATE_ALWAYS,0);
  // save header to identify as a database file
  sf.swrite('BORG',4);
  // save BORG_VERSION
  bver:=BORG_VER;
  sf.swrite(@bver,sizeof(bver));
  // save filename of exe file.
  flen:=strlen(exename)+1;
  sf.swrite(@flen,sizeof(dword));
  sf.swrite(exename,flen);
  // save options.
  options.loaddebug    :=fixbool(options.loaddebug);
  options.mode16       :=fixbool(options.mode16);
  options.mode32       :=fixbool(options.mode32);
  options.loaddata     :=fixbool(options.loaddata);
  options.loadresources:=fixbool(options.loadresources);
  options.demangle     :=fixbool(options.demangle);
  options.cfa          :=bool(options.cfa);
  sf.swrite(@options,sizeof(tglobaloptions));
  sf.swrite(@floader.exetype,sizeof(integer));
  if not savedatasegitems(sf,floader.fbuff) then begin  // save segment info
    MessageBox(mainwindow,'Segments:File write failed ?',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  if not gnamesavedb(import,sf) then begin     // save import info
    MessageBox(mainwindow,'Imports:File write failed ?',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  if not gnamesavedb(expt,sf) then begin       // save export info
    MessageBox(mainwindow,'Exports:File write failed ?',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  if not gnamesavedb(nam,sf) then begin        // save names
    MessageBox(mainwindow,'Names:File write failed ?',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  if not saverelocitems(sf) then begin      // save relocs
    MessageBox(mainwindow,'Relocs:File write failed ?',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  if not xrefsavedb(sf) then begin      // save xrefs
    MessageBox(mainwindow,'Xrefs:File write failed ?',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  if not dissavedb(sf,floader.fbuff) then begin  // save asm database
    MessageBox(mainwindow,'Database:File write failed ?',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  if not savedecryptitems(sf) then begin  // save decrypter list
    MessageBox(mainwindow,'Decryptors:File write failed ?',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  sf.flushfilewrite;
finally
  sf.free;
  DestroyWindow(sbox);
//closefile(log);
end;
end;

{************************************************************************
* loaddbcoord                                                           *
* - coordinates loading of the databases when load database file is     *
*   chosen in Borg                                                      *
************************************************************************}
function loaddbcoord(fname,exename:pchar):boolean;
var
  fstm:tfilestream;
  sf:tsavefile;
  tbuff:array[0..20] of char;
  bver,num,flen:integer;
  i:dword;
  lbox:HWND;
  compr:boolean;
begin
  result:=false;
  sf:=tsavefile.create;
  sf.compr:=true;
  with tfilestream.create(strpas(fname),fmShareDenyNone) do try
    read(tbuff,4); if (tbuff[2]='R') and (tbuff[3]='G') then sf.compr:=false;
  finally free;
  end;
try
//assignfile(log,'in.log'); rewrite(log);
  // open file
  lbox:=CreateDialog(Inst,MAKEINTRESOURCE(load_box),mainwindow,@loadmessbox);
  if not sf.sopen(fname,dword(GENERIC_READ),1,OPEN_EXISTING,0) then exit;
  // load header check its a database file
  tbuff[4]:=#0;
  if not sf.sread(tbuff,4,num) then begin
    MessageBox(mainwindow,'File read failed ?',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  if strcomp(tbuff,'BORG')<>0 then begin
    MessageBox(mainwindow,'Not A Borg Database File',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  // read BORG_VERSION
  if not sf.sread(@bver,sizeof(bver),num) then begin
    MessageBox(mainwindow,'File read failed ?',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  if bver<>BORG_VER then begin
    MessageBox(mainwindow,'Warning:diff version savefile [will attempt load]',fname,MB_OK or MB_ICONEXCLAMATION);
  end;
  // load filename of exe file.
  flen:=0;
  if not sf.sread(@flen,sizeof(dword),num) then begin
    MessageBox(mainwindow,'File read failed ?',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  if not sf.sread(exename,flen,num) then begin
    MessageBox(mainwindow,'File read failed ?',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  if not sf.sread(@options,sizeof(tglobaloptions),num) then begin // load options.
    MessageBox(mainwindow,'File read failed ?',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  if not sf.sread(@floader.exetype,sizeof(integer),num) then begin
    MessageBox(mainwindow,'File read failed ?',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  // load exe file.
  // - any errors from here on will now be fatal, and Borg will need to exit
  try
/// 2016    fstm:=nil; fstm:=tfilestream.create(strpas(exename),fmOpenReadWrite);
    fstm:=nil; fstm:=tfilestream.create(strpas(exename),fmOpenReadWrite or fmShareDenyNone);
    getmem(floader.fbuff,fstm.size);
    fstm.read(floader.fbuff^,fstm.size); fstm.free;
  except
    options.readonly:=true;
    MessageBox(mainwindow,'You need original "exe" file to load this db',exename,MB_OK);
{
    fstm:=nil; fstm:=tfilestream.create(strpas(fname),fmShareDenyNone);
    getmem(floader.fbuff,fstm.size); fstm.read(floader.fbuff^,fstm.size); fstm.free;
}
    fstm.free; exit;
  end;
  if not loaddatasegitems(sf,floader.fbuff) then begin // load segment info
    MessageBox(mainwindow,'Fatal Error'#13#10'Segments:File read failed ?',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  if not gnameloaddb(import,sf) then begin    // load import info
    MessageBox(mainwindow,'Fatal Error'#13#10'Imports:File read failed ?',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  if not gnameloaddb(expt,sf) then begin      // load export info
    MessageBox(mainwindow,'Fatal Error'#13#10'Exports:File read failed ?',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  if not gnameloaddb(nam,sf) then begin       // load names
    MessageBox(mainwindow,'Fatal Error'#13#10'Names:File read failed ?',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  if not loadrelocitems(sf) then begin     // load relocs
    MessageBox(mainwindow,'Fatal Error'#13#10'Relocs:File read failed ?',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  if not xrefloaddb(sf) then begin     // load xrefs
    MessageBox(mainwindow,'Fatal Error'#13#10'Xrefs:File read failed ?',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  if not disloaddb(sf,floader.fbuff) then begin // load asm database
    MessageBox(mainwindow,'Fatal Error'#13#10'Database:File read failed ?',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  if not reloc.relocfile then begin
    MessageBox(mainwindow,'Fatal Error'#13#10'Relocating File',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  if not loaddecryptitems(sf) then begin
    MessageBox(mainwindow,'Fatal Error'#13#10'Decryptors:File read failed ?',fname,MB_OK or MB_ICONEXCLAMATION); exit;
  end;
  result:=true;
finally
  sf.free;
  DestroyWindow(lbox);
//closefile(log);
end;
end;

{************************************************************************
* savedb                                                                *
* - the first place of call when save as database is selected.          *
* - asks the user to select a file before calling the fileloader savedb *
*   which is where the save to database is controlled from              *
************************************************************************}
procedure savedb;
var szFile:array[0..MAX_PATH*2] of char;
begin
  if scheduler.sizelist<>0 then begin
    MessageBox(mainwindow,'There are still items to process yet','Borg Warning',MB_OK or MB_ICONEXCLAMATION);
    exit;
  end;
  getfiletosave(szFile);
  if szFile[0]<>#0 then savedbcoord(szFile,current_exe_name);
end;

{************************************************************************
* loaddb                                                                *
* - the first place of call when load from database is selected.        *
* - asks the user to select a file before calling the fileloader loaddb *
*   which is where the load from database is controlled from            *
* - starts up the secondary thread when the file is loaded              *
************************************************************************}
procedure loaddb;
var szFile:array[0..MAX_PATH*2] of char;
begin
  getfiletoload(szFile);
  if szFile[0]<>#0 then begin
    if loaddbcoord(szFile,current_exe_name) then begin
      StatusMessage('File Opened'); strcat(@winname,' : ');
      strcat(@winname,current_exe_name);
      SetWindowText(mainwindow,@winname);
      InThread:=true;
      ThreadHandle:=CreateThread(nil,0,@Thread,nil,0,ThreadId);
      changemenus;
      scheduler.addtask(scrolling,priority_userrequest,nlptr,0,nil);
    end else MessageBox(mainwindow,'File open failed ?',program_name,MB_OK or MB_ICONEXCLAMATION);
  end;
end;

begin
end.

