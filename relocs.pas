unit relocs;
interface
uses sysutils,windows,common,gname,datas,savefile;
{************************************************************************
* This class maintains a list of relocation items from the exe file.    *
* Borg keeps a list of any items which have been or should be relocated *
* when an executable is loaded. The class includes functions to         *
* maintain the list including loading and saving to a database file,    *
* and including relocating the image in memory when the database and    *
* the file are reloaded.                                                *
* The main reason for doing this is that during disassembly we can gain *
* additional information by knowing that a certain location is          *
* relocated on file load. For example with an instruction like          *
* mov eax,400000h, if the location containing 400000h is a relocation   *
* item then we know that 400000h is an offset, and so we can            *
* immediately rewrite it as mov eax, offset 400000h                     *
************************************************************************}
// relocation types, should be self explanatory. Most are not generally used by programs,
// mainly reloc_offs32 by the PE file format.
type
  reloctype =(reloc0,RELOC_NONE,RELOC_SEG,RELOC_OFFS16,RELOC_OFFS32,RELOC_SEGOFFS16,RELOC_SEGOFFS32);
// we will keep track of relocation addresses and the type.
  prelocitem=^trelocitem;
  trelocitem=packed record
    addr:lptr;
    typ :reloctype;
  end;

  trelocs=class(tslist)
    sizeofitem:integer;
  public
    constructor create;
    procedure addreloc(loc:lptr;x:dword; typ:reloctype);
    function isreloc(loc:lptr;x:dword):boolean;
    function relocfile:boolean;
    function newitem:prelocitem;
    function write_item(sf:tsavefile):boolean;
    function read_item(sf:tsavefile):boolean;
    function compare(a,b:listitem):integer;override;
  end;

var
  reloc:trelocs;

implementation

constructor trelocs.create;
begin
  inherited create;
  sizeofitem:=sizeof(trelocitem);
end;

// addreloc                                                              *
// - adds a reloc item to the list of relocs                             *
// - a reloc item consists of only a location which is in the reloc      *
//   table, and a type for the relocation                                *
procedure trelocs.addreloc(loc:lptr;x:dword; typ:reloctype);
var newname:prelocitem;
begin
  inc(loc.o,x);
  newname:=new(prelocitem);
  newname.addr:=loc;
  newname.typ :=typ;
  addto(listitem(newname));
{$ifdef DEBUG}
  DebugMessage('Added Reloc : %4.4x:%4.4x',[loc.s,loc.o]);
{$endif}
end;

// isreloc                                                               *
// - this is the function used throughout the disassembly engine to see  *
//   if somewhere was relocated. It returns true if the location is in   *
//   the table                                                           *
function trelocs.isreloc(loc:lptr;x:dword):boolean;
var
  checkit:trelocitem;
  findit:prelocitem;
begin
  result:=TRUE;
  inc(loc.o,x);
  checkit.addr:=loc;
  findit:=prelocitem(find(listitem(@checkit)));
  if findit<>nil then if eq(findit.addr,loc) then exit;
  result:=FALSE;
end;

{************************************************************************
* the compare function for the reloc items                              *
* - relocs are sorted by location                                       *
************************************************************************}
function trelocs.compare(a,b:listitem):integer;
var i,j:prelocitem;
begin
  i:=prelocitem(a); j:=prelocitem(b);
  result:=0;
  if eq(i.addr,j.addr) then exit else result:=1;
  if gr(i.addr,j.addr) then exit else result:=-1;
end;

// relocfile                                                             *
// - this should be called after loading a database file. It goes        *
//   through all of the relocs and relocates the file again since when   *
//   we load a database we simply load the file image and do not work    *
//   our way through the whole file format again.                        *
function trelocs.relocfile:boolean;
var
  ds:pdsegitem;
  ri:prelocitem;
begin
  resetiterator;
  ri:=prelocitem(nextiterator);
  while ri<>nil do begin
    // relocate item.
    ds:=dta.findseg(ri.addr);
    if ds<>nil then begin // changed in build 14, used to return FALSE if not found
      case reloctype(ri.typ) of
       RELOC_NONE: ;
       RELOC_SEG: inc(pw(@ds.data[ri.addr.o-ds.addr.o])^,options.loadaddr.s);
       RELOC_OFFS16: ;
       RELOC_OFFS32: ;
       RELOC_SEGOFFS16: ;
       RELOC_SEGOFFS32: ;
       else result:=FALSE; exit;
      end;
    end;
    ri:=prelocitem(nextiterator);
  end;
  result:=TRUE;
end;

{************************************************************************
* newitem                                                               *
* - returns a pointer to a new relocitem, only used by database load    *
************************************************************************}
function trelocs.newitem:prelocitem;
begin
  result:=new(prelocitem);
end;

{************************************************************************
* write_item                                                            *
* - writes a reloc item to the savefile specified                       *
*   uses the current item, and moves the iterator on                    *
************************************************************************}
function trelocs.write_item(sf:tsavefile):boolean;
var currdec:prelocitem;
begin
  result:=false;
  currdec:=prelocitem(nextiterator);
  if not sf.swrite(@currdec^,sizeof(trelocitem)) then exit;
  result:=true;
end;

{************************************************************************
* read_item                                                             *
* - reads a reloc item from the savefile specified                      *
************************************************************************}
function trelocs.read_item(sf:tsavefile):boolean;
var
  num:integer;
  currdec:prelocitem;
begin
  result:=false;
  currdec:=new(prelocitem);
  if not sf.sread(@currdec^,sizeof(trelocitem),num) then exit;
  addto(listitem(currdec));
  result:=true;
end;

initialization
  reloc:=trelocs.create;
finalization
  reloc.free;
end.

