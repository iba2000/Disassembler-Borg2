unit xref;
interface
uses sysutils,windows,common,gname,datas,schedule,savefile,mainwind,menus;

// class to maintain xref list - xref items consist simply of an address
// which is the location being referenced and a ref_by address which is
// where the reference is from. It is ordered by location and then by ref_by.
type
  pxrefitem=^txrefitem;
  txrefitem=packed record
    addr :lptr;
    refby:lptr;
  end;

  txref=class(tslist)
  public
    constructor create;
    procedure addxref(loc,ref_by:lptr;x:dword);
    procedure printfirst(loc:lptr);
    procedure delxref(loc,ref_by:lptr);
    procedure userdel(loc:lptr);
    function compare(a,b:listitem):integer;override;
  end;

var
  xrefs:txref;

implementation
uses disasm,disio;

// constructor - now empty
constructor txref.create;
begin
  inherited create;
end;

{************************************************************************
* basic function which adds an xref to the current list.                *
* - just need loc=location for which to create an xref                  *
* - and ref_by=where it is being referenced from                        *
* after the xref has been added we still need to add a line             *
* to the disassembly and so a task to do this is added using            *
* the scheduler.                                                        *
************************************************************************}
procedure txref.addxref(loc,ref_by:lptr;x:dword);
var
  i:integer;
  newxref,chk:pxrefitem;
  chkseg:pdsegitem;
begin
if ($102cd22 = loc.o) or ($102cb1f = loc.o) then
  i:=i;
  inc(ref_by.o,x);
  chkseg:=dta.findseg(loc);
  if chkseg=nil then exit;
  newxref:=new(pxrefitem);
  newxref.addr:=loc;
  newxref.refby:=ref_by;
  chk:=pxrefitem(find(listitem(newxref)));
  if chk<>nil then
    if compare(listitem(newxref),listitem(chk))=0 then begin
      dispose(newxref); exit;
    end;
  addto(listitem(newxref));
  scheduler.addtask(dis_xref,priority_xref,loc,0,nil);
end;

{************************************************************************
* compare function for list - uses address/referencing address          *
* to sort list                                                          *
************************************************************************}
function txref.compare(a,b:listitem):integer;
begin
  result:=-1;
  if le(pxrefitem(a).addr,pxrefitem(b).addr)   then exit else result:=1;
  if gr(pxrefitem(a).addr,pxrefitem(b).addr)   then exit else result:=-1;
  if le(pxrefitem(a).refby,pxrefitem(b).refby) then exit else result:=1;
  if gr(pxrefitem(a).refby,pxrefitem(b).refby) then exit else result:=0;
end;

{************************************************************************
* function to delete an xref from the list                              *
* after the xref has been deleted we check if we need to                *
* delete anything from the disassembly as well if there are             *
* no xrefs left for that loc                                            *
* does a window update if deleting one, but not the comment, which      *
* ensures that the number of xrefs is changed                           *
************************************************************************}
procedure txref.delxref(loc,ref_by:lptr);
var
  xtmp:txrefitem;
  xfind:pxrefitem;
begin
  xtmp.addr:=loc;
  xtmp.refby:=ref_by;
  xfind:=pxrefitem(find(listitem(@xtmp)));
  if xfind=nil then exit;
  if (xfind.addr.o=loc.o)and(xfind.refby.o=ref_by.o) then begin
    delfrom(listitem(xfind));
    xtmp.refby:=nlptr;
    xfind:=pxrefitem(findnext(listitem(@xtmp)));
    if xfind<>nil then if eq(xfind.addr,loc) then begin
      dio.updatewindowifinrange(loc); exit;
    end;
    dsm.delcomment(loc,dsmxref);
  end;
end;

// prints the first xref for a given loc
procedure txref.printfirst(loc:lptr);
var
  numents:dword;
  findit:txrefitem;
  chk:pxrefitem;
begin
  numents:=0;
  findit.addr:=loc;
  findit.refby:=nlptr;
  findnext(listitem(@findit));
  chk:=pxrefitem(nextiterator);
  if options.mode32
    then LastPrintBuff('%4.4x:%8.8x',[chk.refby.s,chk.refby.o])
    else LastPrintBuff('%4.4x:%8.8x',[chk.refby.s,chk.refby.o]);
  while chk<>nil do begin
    if neq(chk.addr,loc) then break;
    chk:=pxrefitem(nextiterator);
    inc(numents);
  end;
  LastPrintBuff(' Number : %d',[numents]);
end;

{************************************************************************
* userdel                                                               *
* - deletes an xref, using the users current line and the refby passed  *
*   from the scheduler, which is from the xref viewer dialog            *
************************************************************************}
procedure txref.userdel(loc:lptr);
var xcur:lptr;
begin
  dio.findcurrentaddr(xcur);
  delxref(xcur,loc);
end;

initialization
  xrefs:=txref.create;
finalization
  xrefs.free;
end.

