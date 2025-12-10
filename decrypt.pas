unit decrypt;
interface
uses windows,common,gname,savefile,datas,disasm,disio,exeload,range,
     schedule,menus;
{************************************************************************
* This class adds some simple block decryption/encryption with file     *
* patching to Borg. By storing decryptors in blocks it is possible to   *
* reconstruct the file when it is saved to database and reloaded, even  *
* if some patches were applied to the file and some were not.           *
* Added in Borg 2.19                                                    *
* NB Any future general file patching will need to be included in this  *
* class and saved in a similar way. This opens up the way to decrypting *
* patching and reencrypting within Borg :)                              *
* Current decryptors are fairly simple, but when used in combination    *
* they are very powerful. The Xadd is a bit obscure, but could be       *
* simply modified as needed, and recompiled for some powerful routines. *
************************************************************************}
type
// decrypt types supported - add, sub, mul, xor
  dectype  =(decnull,decadd,decsub,decmul,decrot,decxor,decxadd);
// decrypt lengths - byte,word,dword,array
  ditemtype=(null,decbyte,decword,decdword,decarray);

// decrypters are held in an array - this array is saved when a database is saved
// and the list is reapplied on loading the file.
  pdeclist=^tdeclist;
  tdeclist=packed record
    dec_start:lptr;
    dec_end:lptr;
    typ:dectype;
    dlength:ditemtype;
    value:dword;
    arrayaddr:lptr;
    patch:booln;
    uid:dword;
  end;

  tdecrypt=class(tslist)
    nextitemnum:dword;
    loading_db:boolean;
  public
    constructor create;
    function add_decrypted(dstart,dend:lptr; t:dectype; ditem:ditemtype; val:dword; adr:lptr; patchedexe:boolean):dword;
    procedure process_dec(dec_id:dword);
    procedure process_reload(dec_id:dword);
    procedure exepatch(dec_id:dword);
    function write_item(sf:tsavefile):boolean;
    function read_item(sf:tsavefile):boolean;
    function compare(a,b:listitem):integer;override;
  end;

var
  decrypter:tdecrypt;

implementation

const
  loading_db:boolean=false;

// - resets a few global variables
constructor tdecrypt.create;
begin
  nextitemnum:=1;
  loading_db:=false;
end;

function tdecrypt.compare(a,b:listitem):integer;
var i,j:pdeclist;
begin
  i:=pdeclist(a); j:=pdeclist(b);
  result:=-1;
  if i.uid=j.uid then result:=0 else
  if i.uid>j.uid then result:=1;
end;

// add_decrypted                                                         *
// - just adds another item to the decrypt list                          *
// - the decrypt list is simply a list of blocks and how they were       *
//   changed and whether the exe was patched                             *
// - the list is just to enable reconstruction of the state of the file  *
//   on saving and loading databases with decryptors which may or may    *
//   not have been saved to the exe file                                 *
function tdecrypt.add_decrypted(dstart,dend:lptr; t:dectype; ditem:ditemtype; val:dword; adr:lptr; patchedexe:boolean):dword;
var ndec:pdeclist;
begin
  ndec:=new(pdeclist);
  ndec.dec_start:=dstart;
  ndec.dec_end:=dend;
  ndec.typ:=t;
  ndec.dlength:=ditem;
  ndec.value:=val;
  ndec.arrayaddr:=adr;
  ndec.patch:=patchedexe;
  ndec.uid:=nextitemnum;
  inc(nextitemnum);
  addto(listitem(ndec));
  result:=ndec.uid;
end;

// process_dec                                                           *
// - this processes a decryptor given the uid, actually applying it to   *
//   the file in memory. If a block contains any disassembly then this   *
//   is also deleted.                                                    *
procedure tdecrypt.process_dec(dec_id:dword);
var
  fnd:tdeclist;
  patch:pdeclist;
  pseg,aseg:pdsegitem;
  cpos:lptr;
  plen,ctr:integer;
  doitval,lval,tval:dword;
begin
  fnd.uid:=dec_id;
  patch:=pdeclist(find(listitem(@fnd)));
  if patch=nil then exit;
  if patch.uid<>dec_id then exit;
  pseg:=dta.findseg(patch.dec_start);
  if pseg=nil then exit;
  ctr:=0;
  case patch.dlength of
   decbyte:  plen:=1;
   decword:  plen:=2;
   decdword: plen:=4;
   decarray:
    begin
      plen:=1;
      aseg:=dta.findseg(patch.arrayaddr);
      if aseg=nil then exit;
      ctr:=patch.arrayaddr.o-aseg.addr.o;
    end;
   else plen:=1;
  end;
  cpos:=patch.dec_start;
  lval:=patch.value;
  while leeq(cpos,patch.dec_end) do begin
    // check within seg, and move to the next seg if we arent
    while cpos.o>pseg.addr.o+(pseg.size-plen) do begin
      dta.nextseg(cpos);
      if cpos.s=0 then break;
      if gr(cpos,patch.dec_end) then break;
      pseg:=dta.findseg(cpos);
    end;
    if cpos.s=0 then break;
    if gr(cpos,patch.dec_end) then break;
    case plen of
     1: doitval:=byte(pseg.data[cpos.o-pseg.addr.o]);
     2: doitval:=pw(pseg.data[cpos.o-pseg.addr.o])^;
     4: doitval:=pd(pseg.data[cpos.o-pseg.addr.o])^;
    end;
    if patch.dlength=decarray then begin
      if ctr+plen>aseg.size then break;
      case plen of
       1: patch.value:=byte(aseg.data[ctr]);
       2: patch.value:=pw(aseg.data[ctr])^;
       4: patch.value:=pd(aseg.data[ctr])^;
      end;
    end;
    case patch.typ of
     decxor: doitval:=doitval xor patch.value;
     decmul: doitval:=doitval * patch.value;
     decadd: doitval:=doitval + patch.value;
     decsub: doitval:=doitval - patch.value;
     decxadd:
      begin
        tval:=doitval;
        doitval:=lval;
        lval:=tval;
        doitval:=doitval+lval;
       end;
     decrot:
        case plen of
         1: doitval:=doitval shl (patch.value and $07) + (doitval shr (8 -(patch.value and $07)));
         2: doitval:=doitval shl (patch.value and $0f) + (doitval shr (16-(patch.value and $0f)));
         4: doitval:=doitval shl (patch.value and $1f) + (doitval shr (32-(patch.value and $1f)));
        end;
    end;
    case plen of
     1: byte(pseg.data[cpos.o-pseg.addr.o]):=byte(doitval);
     2: pw(pseg.data[cpos.o-pseg.addr.o])^:=word(doitval);
     4: pd(pseg.data[cpos.o-pseg.addr.o])^:=doitval;
    end;
    inc(cpos.o,plen);
    inc(ctr,plen);
  end;
  if not loading_db then dsm.undefineblock(patch.dec_start,patch.dec_end);
  dio.updatewindowifwithinrange(patch.dec_start,patch.dec_end);
end;

// exepatch                                                              *
// - given a uid this steps through a decryptor and writes the patch to  *
//   the exe file.                                                       *
procedure tdecrypt.exepatch(dec_id:dword);
var
  fnd:tdeclist;
  patch:pdeclist;
  pseg:pdsegitem;
  cpos:lptr;
  plen:integer;
  doitval:dword;
begin
  fnd.uid:=dec_id;
  patch:=pdeclist(find(listitem(@fnd)));
  if patch=nil then exit;
  if patch.uid<>dec_id then exit;
  pseg:=dta.findseg(patch.dec_start);
  case patch.dlength of
   decbyte:  plen:=1;
   decword:  plen:=2;
   decdword: plen:=4;
   decarray: plen:=1;
   else      plen:=1;
  end;
  cpos:=patch.dec_start;
  while leeq(cpos,patch.dec_end) do begin
    // check within seg, and move to the next seg if we arent
    while cpos.o>pseg.addr.o+(pseg.size-plen) do begin
      dta.nextseg(cpos);
      if cpos.s=0 then break;
      if gr(cpos,patch.dec_end) then break;
      pseg:=dta.findseg(cpos);
    end;
    if cpos.s=0 then break;
    if gr(cpos,patch.dec_end) then break;
    doitval:=floader.fileoffset(cpos);
    // write patch
    case plen of
     1:   floader.patchfile(doitval,1,pseg.data+(cpos.o-pseg.addr.o));
     2:   floader.patchfile(doitval,2,pseg.data+(cpos.o-pseg.addr.o));
     4:   floader.patchfile(doitval,4,pseg.data+(cpos.o-pseg.addr.o));
     else floader.patchfile(doitval,1,pseg.data+(cpos.o-pseg.addr.o));
    end;
    inc(cpos.o,plen);
  end;
end;

{************************************************************************
* process_reload                                                        *
* - given a uid this steps through a patch and re-reads the bytes in    *
*   that would have been changed. This is used in file reconstruction   *
************************************************************************}
procedure tdecrypt.process_reload(dec_id:dword);
var
  fnd:tdeclist;
  patch:pdeclist;
  pseg:pdsegitem;
  cpos:lptr;
  plen:integer;
  doitval:dword;
begin
  fnd.uid:=dec_id;
  patch:=pdeclist(find(listitem(@fnd)));
  if patch=nil then exit;
  if patch.uid<>dec_id then exit;
  pseg:=dta.findseg(patch.dec_start);
  case patch.dlength of
   decbyte:  plen:=1;
   decword:  plen:=2;
   decdword: plen:=4;
   decarray: plen:=1;
   else      plen:=1;
  end;
  cpos:=patch.dec_start;
  while leeq(cpos,patch.dec_end) do begin
    // check within seg, and move to the next seg if we arent
    while cpos.o>pseg.addr.o+(pseg.size-plen) do begin
      dta.nextseg(cpos);
      if cpos.s=0 then break;
      if gr(cpos,patch.dec_end) then break;
      pseg:=dta.findseg(cpos);
    end;
    if cpos.s=0 then break;
    if gr(cpos,patch.dec_end) then break;
    doitval:=floader.fileoffset(cpos);
    // write patch
    case plen of
     1:   floader.reloadfile(doitval,1,pseg.data+(cpos.o-pseg.addr.o));
     2:   floader.reloadfile(doitval,2,pseg.data+(cpos.o-pseg.addr.o));
     4:   floader.reloadfile(doitval,4,pseg.data+(cpos.o-pseg.addr.o));
     else floader.reloadfile(doitval,1,pseg.data+(cpos.o-pseg.addr.o));
    end;
    inc(cpos.o,plen);
  end;
end;

{************************************************************************
* write_item                                                            *
* - writes a decrypt item to the savefile specified                     *
*   uses the current item, and moves the iterator on                    *
************************************************************************}
function tdecrypt.write_item(sf:tsavefile):boolean;
var currdec:pdeclist;
begin
  result:=false;
  currdec:=pdeclist(nextiterator);
  if not sf.swrite(@currdec^,sizeof(tdeclist)) then exit;
  result:=true;
end;

{************************************************************************
* read_item                                                             *
* - read a decrypt item from the savefile specified                     *
*   adds it to the list and restores any patch                          *
*   If we find a decryptor which was saved to disk then we              *
*   reload that block from the exe file. In this way after all of the   *
*   decryptors have been loaded we have synchronised the file in memory *
*   to the file on disk, plus any further patches made but not written  *
*   to disk. [Any byte in the file was synchronised to the file at the  *
*   time of the last patch which was written to file. Subsequent        *
*   patches have been made to memory only, and are just redone. So the  *
*   loaded file is in the same state as when the database was saved]    *
************************************************************************}
function tdecrypt.read_item(sf:tsavefile):boolean;
var
  num:integer;
  currdec:pdeclist;
begin
  result:=false;
  currdec:=new(pdeclist);
  if not sf.sread(@currdec^,sizeof(tdeclist),num) then exit;
  addto(listitem(currdec));
  nextitemnum:=currdec.uid+1;
  loading_db:=true;
  if not currdec.patch then process_dec(currdec.uid)
  else process_reload(currdec.uid);
  loading_db:=false;
  result:=true;
end;

initialization
  decrypter:=tdecrypt.create;
finalization
  decrypter.free;
end.

