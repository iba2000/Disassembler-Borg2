unit datas;
interface
uses sysutils,windows,common,gname,proctab,schedule,menu,savefile;
{************************************************************************
* - this is the set of functions which looks after segments/sections    *
* blocks of code or data can be added to the database, where they are   *
* kept and ordered and can be interrogated. functions should be segment *
* level functions in here. the possibleentrycode function was put here  *
* on this basis rather than being a disasm function as it simply        *
* looks for likely entry code and adds scheduler items                  *
*                                                                       *
* NB segment address with segment=0 is treated as a special return      *
* value, and segments should not be created with this value             *
************************************************************************}
type
  segtype=(code0,code16,code32,data16,data32,uninitdata,debugdata,resourcedata);

//essentially the data-mapping to the file.
//divides file into code/data segments or objects
//each set of data is then referenced through these sorted headers
  pdsegitem=^tdsegitem;
  tdsegitem=packed record
    addr:lptr;
    size:dword;
    data:pchar;
    typ:segtype;
    nam:pchar;
  end;

  pdsegitemsave=^tdsegitemsave;
  tdsegitemsave=packed record
    addr:lptr;
    size:dword;
    fileoffset:dword;
    typ:segtype;
    isnam:booln;
  end;

  tdataseg=class(tslist)
  public
    constructor create;
    procedure addseg(loc:lptr;size:dword;dataptr:pchar; t:segtype;nam:pchar);
    function findseg(loc:lptr):pdsegitem;
    function beyondseg(loc:lptr):boolean;
    procedure nextseg(var loc:lptr);
    procedure lastseg(var loc:lptr);
    function datagetpos(loc:lptr):dword;
    function getlocpos(pos:dword):lptr;
    procedure possibleentrycode(loc:lptr);
    procedure segheader(loc:lptr);
    function write_item(sf:tsavefile; filebuff:pchar):boolean;
    function read_item(sf:tsavefile; filebuff:pchar):boolean;
    function compare(a,b:listitem):integer;override;
    procedure delfunc(d:listitem);override;
  private
    function insegloc(ds:pdsegitem; loc:lptr):boolean;
  end;

var
  dta:tdataseg;
  total_data_size :dword;
  current_data_pos:dword;

implementation
uses disasm;

// constructor function                                                  *
// - we set up the deletion and compare functions for the data segment   *
//   list - see list.cpp                                                 *
// - we reset the global variables used to track data size and position  *
constructor tdataseg.create;
begin
  inherited create;
  total_data_size :=0;
  current_data_pos:=0;
end;

function tdataseg.compare(a,b:listitem):integer;
begin
  if eq(pdsegitem(a).addr,pdsegitem(b).addr) then begin result:=0; exit; end;
  if gr(pdsegitem(a).addr,pdsegitem(b).addr) then begin result:=1; exit; end;
  result:=-1;
end;

procedure tdataseg.delfunc(d:listitem);
begin
  if pdsegitem(d).nam<> nil then dispose(pdsegitem(d).nam);
  if pdsegitem(d).typ=uninitdata then dispose(pdsegitem(d).data);
  dispose(pdsegitem(d));
end;

function tdataseg.insegloc(ds:pdsegitem; loc:lptr):boolean;
begin
  result:=false;
  if ds=nil then exit;
  if between(loc,ds.addr,ds.addr,ds.size-1) then result:=true;
end;

// addseg                                                                *
// this adds a segment to the list of segments. It is called on loading  *
// the file, and segments should be setup before any analysis - here a   *
// segment is just a block of data of a single attribute, which will be  *
// referenced later. It could be a true segment, or just a PE section,   *
// or even just a single resource. Segments should not overlap           *
// the function checks for any overlaps, adds a task to the scheduler    *
// for a segment header comment block, keeps track of total data size    *
procedure tdataseg.addseg(loc:lptr;size:dword;dataptr:pchar;t:segtype;nam:pchar);
var
  addit:pdsegitem;
  chker:pdsegitem;
  tmpnum,tsize:dword;
  warning:string;
begin
  addit:=new(pdsegitem);
  addit.addr.s:=loc.s; addit.addr.o:=loc.o;
  addit.size:=size;
  addit.data:=dataptr;
  addit.typ:=t;
  if nam<>nil then begin
    getmem(addit.nam,strlen(nam)+1);
    strcopy(addit.nam,nam);
  end else addit.nam:=nil;
  resetiterator;
  chker:=pdsegitem(nextiterator);
  while chker<>nil do begin
    if insegloc(addit,chker.addr) then begin
      //need to cut addit short.
      addit.size:=chker.addr.o-addit.addr.o;
      if addit.size=0 then begin
        tmpnum:=loc.s;
        Fmtstr(warning,'Warning : Unable to create segment %4x:%4x size :%4x',
         [tmpnum,loc.o,size]);
        MessageBox(mainwindow,pchar(warning),'Borg Warning',MB_ICONEXCLAMATION or MB_OK);
        exit;
      end else begin
        tmpnum:=loc.s;
        Fmtstr(warning,'Warning : Segment overlap %4x:%4x size :%4x reduced to size :%4x',
         [tmpnum,loc.o,size,addit.size]);
        MessageBox(mainwindow,pchar(warning),'Borg Warning',MB_ICONEXCLAMATION or MB_OK);
      end;
    end;
    if insegloc(chker,addit.addr) then begin
      //need to cut chkit short.
      tsize:=chker.size;
      chker.size:=addit.addr.o-chker.addr.o;
      if chker.size=0 then begin
        tmpnum:=chker.addr.s;
        fmtstr(warning,'Warning : Unable to create segment %4x:%4x size :%4x',
         [tmpnum,chker.addr.o,tsize]);
        MessageBox(mainwindow,pchar(warning),'Borg Warning',MB_ICONEXCLAMATION or MB_OK);
        delfrom(listitem(chker));
        resetiterator;
      end else begin
        tmpnum:=chker.addr.s;
        fmtstr(warning,'Warning : Segment overlap %4x:%4x size :%4x reduced to size :%4x',
         [tmpnum,chker.addr.o,tsize,chker.size]);
        MessageBox(mainwindow,pchar(warning),'Borg Warning',MB_ICONEXCLAMATION or MB_OK);
      end;
    end;
    chker:=pdsegitem(nextiterator);
  end;
  addto(listitem(addit));
  scheduler.addtask(dis_segheader,priority_segheader,loc,0,nil);
  inc(total_data_size,size);
end;

{************************************************************************
* findseg                                                               *
* - the segment locator takes a loc and searches for the segment        *
*   containing the loc. If its found then it returns a pointer to the   *
*   dsegitem. Note the iterator is changed, and will be left pointing   *
*   to the next segment.                                                *
************************************************************************}
function tdataseg.findseg(loc:lptr):pdsegitem;
var
  t1:tdsegitem;
  findd:pdsegitem;
begin
  result:=nil;
  t1.addr.s:=loc.s;
  t1.addr.o:=0;
  findd:=pdsegitem(findnext(listitem(@t1)));
  findd:=pdsegitem(nextiterator);
  while findd<>nil do begin
    if insegloc(findd,loc) then begin result:=findd; exit; end;
    findd:=pdsegitem(nextiterator);
  end;
end;

// datagetpos                                                            *
// - this simply calculates how far along the total data a loc is, which *
//   is used for the vertical scroll bar to determine how far down it    *
//   should be.                                                          *
function tdataseg.datagetpos(loc:lptr):dword;
var
  findd:pdsegitem;
  ctr:dword;
begin
  resetiterator;
  findd:=pdsegitem(nextiterator);
  ctr:=0;
  while findd<>nil do begin
    if insegloc(findd,loc) then begin
      inc(ctr,(loc.o-findd.addr.o)); break;
    end;
    inc(ctr,findd.size);
    findd:=pdsegitem(nextiterator);
  end;
  result:=ctr;
end;

// getlocpos                                                             *
// - for a data position this returns the loc, treating all segments as  *
//   continous. It is the opposite function to datagetpos. It is used    *
//   when the vertical scroll bar is dragged to a position and stopped,  *
//   in order to calculate the new loc.                                  *
function tdataseg.getlocpos(pos:dword):lptr;
var
  findd:pdsegitem;
  ctr:lptr;
begin
   resetiterator;
   findd:=pdsegitem(nextiterator);
   ctr:=findd.addr;
   while findd<>nil do begin
     if pos<findd.size then begin
        ctr.o:=findd.addr.o+pos; break;
     end;
     dec(pos,findd.size);
     ctr:=findd.addr;
     if findd.size<>0 then inc(ctr.o,(findd.size-1)); // last byte in seg in case we dont find the addr
     findd:=pdsegitem(nextiterator);
   end;
   result:=ctr;
end;

// beyondseg                                                             *
// - returns a BOOL value indicating whether the loc is outside a        *
//   segment. Used a lot to determine if we have moved outside a data    *
//   area. If two segments have the same segm value and are contiguous   *
//   then it will return false, not true                                 *
function tdataseg.beyondseg(loc:lptr):boolean;
var
  findd:pdsegitem;
begin
  resetiterator;
  findd:=pdsegitem(nextiterator);
  while findd<>nil do begin
    if insegloc(findd,loc) then begin result:=FALSE; exit; end;
    findd:=pdsegitem(nextiterator);
  end;
  result:=TRUE;
end;

// nextseg                                                               *
// - this function takes a loc, and returns the next segment first loc   *
//   or a segm=0 if its not found                                        *
// mainly used in output and display routines                            *
procedure tdataseg.nextseg(var loc:lptr);
var findd:pdsegitem;
begin
  resetiterator;
  findd:=pdsegitem(nextiterator);
  while findd<>nil do begin
    if insegloc(findd,loc) then begin
      findd:=pdsegitem(nextiterator);
      if findd=nil then loc.s:=0 else loc:=findd.addr;
      exit;
    end;
    findd:=pdsegitem(nextiterator);
  end;
  loc.s:=0;
end;

// lastseg                                                               *
// - this function takes a loc, and returns the last segment last loc    *
//   or a segm=0 if its not found                                        *
// mainly used in output and display routines                            *
procedure tdataseg.lastseg(var loc:lptr);
var
  findd:pdsegitem;
  prevd:pdsegitem;
begin
  resetiterator;
  findd:=pdsegitem(nextiterator);
  prevd:=nil;
  while findd<>nil do begin
    if insegloc(findd,loc) then begin
      if prevd=nil then loc.s:=0
      else begin
        loc.o:=prevd.addr.o+prevd.size-1;
      end; exit;
    end;
    prevd:=findd;
    findd:=pdsegitem(nextiterator);
  end;
  loc.s:=0;
end;

// possibleentrycode                                                     *
// - this just scans a whole segment for possible routine entrycode, as  *
// defined by options, and adds scheduler items for proper analysis by   *
// disasm. currently all specific to the 80x86 processor                 *
procedure tdataseg.possibleentrycode(loc:lptr);
var
  t1:tdsegitem;
  findd:pdsegitem;
  length:dword;
begin
  if options.processor=PROC_Z80 then exit;
  t1.addr:=loc;
  findd:=pdsegitem(find(listitem(@t1)));
  if findd=nil then exit;
  length:=findd.size;
  loc.o:=findd.addr.o;
  if options.codedetect and CD_AGGRESSIVE<>0 then
    scheduler.addtask(seek_code,priority_aggressivesearch,loc,0,nil);
  while length<>0 do begin
    if (options.codedetect and CD_PUSHBP<>0)and(length>3) then begin
      if findd.data[loc.o-findd.addr.o]=#$55 then begin // push bp
        // two encodings of mov bp,sp
        if (findd.data[(loc.o-findd.addr.o)+1]=#$8b)and(findd.data[(loc.o-findd.addr.o)+2]=#$ec)
        then scheduler.addtask(dis_code,priority_possiblecode,loc,0,nil);
        if (findd.data[(loc.o-findd.addr.o)+1]=#$89)and(findd.data[(loc.o-findd.addr.o)+2]=#$e5)
        then scheduler.addtask(dis_code,priority_possiblecode,loc,0,nil);
      end;
    end;
    if (options.codedetect and CD_EAXFROMESP<>0)and(length>4) then begin
      if findd.data[loc.o-findd.addr.o]=#$55 then begin  // push bp
        if (findd.data[(loc.o-findd.addr.o)+1]=#$8b)
          and(findd.data[(loc.o-findd.addr.o)+2]=#$44)
          and(findd.data[(loc.o-findd.addr.o)+3]=#$24) // mov ax,[sp+xx]
        then scheduler.addtask(dis_code,priority_possiblecode,loc,0,nil);
       end;
    end;
    if (options.codedetect and CD_MOVEAX<>0)and(length>3) then begin
      if (findd.data[loc.o-findd.addr.o]=#$8b)
        and(findd.data[(loc.o-findd.addr.o)+1]=#$44)
        and(findd.data[(loc.o-findd.addr.o)+2]=#$24) // mov ax,[sp+xx]
      then scheduler.addtask(dis_code,priority_possiblecode,loc,0,nil);
    end;
    if (options.codedetect and CD_ENTER<>0)and(length>4) then begin
      if findd.data[loc.o-findd.addr.o]=#$c8 then begin // enter
        if(findd.data[(loc.o-findd.addr.o)+3]=#$00) // enter xx,00
        then scheduler.addtask(dis_code,priority_possiblecode,loc,0,nil);
       end;
    end;
    if (options.codedetect and CD_MOVBX<>0)and(length>2) then begin // mov bx,sp
      if (findd.data[loc.o-findd.addr.o]=#$8b)
        and(findd.data[(loc.o-findd.addr.o)+1]=#$dc)
      then scheduler.addtask(dis_code,priority_possiblecode,loc,0,nil);
    end;
    inc(loc.o);
    dec(length);
  end;
end;

// segheader                                                             *
// - here we add the segment header as a comment, to the disassembly     *
//  disasm adds the comment, we assemble the information here.           *
procedure tdataseg.segheader(loc:lptr);
var
  tmpc:pchar;
  tmpcs:string;
  t1:tdsegitem;
  findd:pdsegitem;
begin
  t1.addr:=loc;
  findd:=pdsegitem(find(listitem(@t1)));
  if findd=nil then exit;
  getmem(tmpc,80);
  strcopy(tmpc,'-----------------------------------------------------------------------');
  dsm.discomment(loc,dsmsegheader,tmpc);
  getmem(tmpc,80);
  fmtstr(tmpcs,'Segment : %2xh     Offset : %2xh     Size : %2xh',
   [loc.s,loc.o,findd.size]);
  strpcopy(tmpc,tmpcs);
  dsm.discomment(loc,succ(dsmsegheader),tmpc);
  getmem(tmpc,80);
  case findd.typ of
   code16:      strcopy(tmpc,'16-bit Code');
   code32:      strcopy(tmpc,'32-bit Code');
   data16:      strcopy(tmpc,'16-bit Data');
   data32:      strcopy(tmpc,'32-bit Data');
   uninitdata:  strcopy(tmpc,'Uninit Data');
   debugdata:   strcopy(tmpc,'Debug Data');
   resourcedata:
    begin
      strcopy(tmpc,'Resource Data ');
    end;
   else strcopy(tmpc,'Unknown');
  end;
  if findd.nam<>nil then begin
    strcat(tmpc,' : '); strmove(@tmpc[strlen(tmpc)],findd.nam,60);
  end;
  dsm.discomment(loc,succ(succ(dsmsegheader)),tmpc);
  getmem(tmpc,80);
  strcopy(tmpc,'-----------------------------------------------------------------------');
  dsm.discomment(loc,succ(succ(succ(dsmsegheader))),tmpc);
end;

{************************************************************************
* write_item                                                            *
* - writes a dataseg item to the savefile specified                     *
*   uses the current item, and moves the iterator on                    *
*   saving in borg is single pass and so stringlengths are saved before *
*   strings, etc. we use a similar structure item for the save          *
*   (dsegitem - dsegitemsave). As the data item is a pointer it is      *
*   converted into an offset for saving.                                *
************************************************************************}
function tdataseg.write_item(sf:tsavefile; filebuff:pchar):boolean;
var
  nlen:integer;
  structsave:tdsegitemsave;
  currseg:pdsegitem;
begin
  result:=false;
  currseg:=pdsegitem(nextiterator);
  structsave.addr:=currseg.addr;
  structsave.size:=currseg.size;
///2016
{$R-}
  structsave.fileoffset:=currseg.data-filebuff;
{$R+}
  structsave.typ:=currseg.typ;
  if currseg.nam<>nil then structsave.isnam:=true else structsave.isnam:=false;
  structsave.isnam:=fixbool(structsave.isnam);
//with structsave do write(log,format(' %4.4x:%8.8x %8.8x',[addr.s,addr.o,size]));
//with structsave do write(log,format(' %8.8x %d',[fileoffset,word(typ)]));
  if not sf.swrite(@structsave,sizeof(tdsegitemsave)) then exit;
  if structsave.isnam then begin
    nlen:=strlen(currseg.nam)+1;
//write(log,format(' %d nam=%s',[nlen,strpas(currseg.nam)]));
    if not sf.swrite(@nlen,sizeof(dword)) then exit;
    if not sf.swrite(currseg.nam,nlen) then exit;
  end;
//writeln(log);
  result:=true;
end;

{************************************************************************
* read_item                                                             *
* - reads a dataseg item from the savefile specified                    *
*   Note that addseg is not used here, since we have all the            *
*   information and just need to reconstruct the dsegitem. Hence we     *
*   also need to recalculate total_data_size in here. Also, for uninit  *
*   data segments we add a false data area.                             *
************************************************************************}
function tdataseg.read_item(sf:tsavefile; filebuff:pchar):boolean;
var
  num,nlen:integer;
  structsave:tdsegitemsave;
  currseg:pdsegitem;
begin
  result:=false;
  currseg:=new(pdsegitem);
  if not sf.sread(@structsave,sizeof(tdsegitemsave),num) then exit;
  currseg.addr:=structsave.addr;
  currseg.size:=structsave.size;
  currseg.data:=structsave.fileoffset+filebuff;
  currseg.typ :=structsave.typ;
  // total_data_size increased
  inc(total_data_size,currseg.size);
  if structsave.isnam then begin
    if not sf.sread(@nlen,sizeof(dword),num) then exit;
    getmem(currseg.nam,nlen+1);
    if not sf.sread(currseg.nam,nlen,num) then exit;
  end else currseg.nam:=nil; //??
  // uninitdata - add false data area
  if currseg.typ=uninitdata then begin
    getmem(currseg.data,currseg.size);
    for nlen:=0 to currseg.size-1 do currseg.data[nlen]:=#0;
  end;
  addto(listitem(currseg));
  result:=true;
end;

initialization
  dta:=tdataseg.create;
finalization
  dta.free;
end.

