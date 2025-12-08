unit gname;
interface
uses sysutils,windows,common,savefile,menus,mainwind;
const
  GNAME_MAXLEN =40;

type
  listitem =pchar;
  plistptr =^tlistptr;
  tlistptr =array[0..100000] of listitem;

  pgnameitem=^tgnameitem;
  tgnameitem=packed record
    addr:lptr;
    nam :pchar;
  end;

{************************************************************************
*                            list.cpp                                   *
* basic list class, use with inheritance.                               *
* - maintains a list class of pointers.                                 *
* - can add/insert items                                                *
* - can use binary search                                               *
* - will resize array upwards in 4k chunks.                             *
* - downsizing has not been added but will be carried out when a        *
* disassembly is saved and reloaded as a database.                      *
* this class is central to many other classes.                          *
*                                                                       *
* Note: there is only one listiter per list. Some functions reset or    *
* change listiter, like find, and so any derived classes must be        *
* careful not to try and move through a list whilst inadvertently using *
* these functions. (It is also why the secondary program thread must be *
* often stopped during user searches, and dialogs since otherwise the   *
* databases would be constantly changing.                               *
*                                                                       *
* Rewritten for Version 2.22 this is now a template class, all          *
* functions are below and are essentially compiled for each class       *
* which uses the list.                                                  *
* - still work to be done clearing it up though                         *
* - delfunc and delfrom basically call delete item and so delfunc       *
*   should be overridden if this is not wanted                          *
************************************************************************}

  tslist=class
    listptr:plistptr;
    listsize,maxsize,listiter:integer;
  public
    constructor create;
    destructor destroy;override;
    function compare(a,b:listitem):integer;virtual;
    procedure delfunc(d:listitem);virtual;
    procedure addto(l:listitem);
    procedure delfrom(l:listitem);
    function find(l:listitem):listitem;
    function findnext(l:listitem):listitem;
    procedure resetiterator;
    function nextiterator:listitem;
    function lastiterator:listitem;
    function processqueue:listitem;
    function peekfirst:listitem;
    function numlistitems:integer;
  end;

// generic name class                                                    *
// the basic gname class consists of a name and a location, and these    *
// are the basic management functions for the class. The class is        *
// inherited by names, exports and imports which are all treated very    *
// slightly differently. These are essentially the common routines       *
// The gname class itself inherits the list class for management of the  *
// array of named locations.                                             *
  tgname=class(tslist)
    repeater:boolean;
  public
    constructor create;
    procedure addname(loc:lptr;nm:pchar);
    function isname(loc:lptr):boolean;
    procedure printname(loc:lptr);
    procedure delname(loc:lptr);
    function getoffsfromname(nm:pchar):dword;
    function compare(a,b:listitem):integer;override;
    procedure delfunc(d:listitem);override;
 end;

var
  nam:tgname;
  import:tgname;
  expt:tgname;

implementation
uses datas,disasm,disio,schedule;

constructor tgname.create;
begin
  inherited create;
end;

// gname compare function                                                *
// - the compare function for ordering the list of names                 *
// - the names are kept in location order                                *
function tgname.compare(a,b:listitem):integer;
begin
  result:=0;
  if eq(pgnameitem(a).addr,pgnameitem(b).addr) then exit else result:=1;
  if gr(pgnameitem(a).addr,pgnameitem(b).addr) then exit else result:=-1;
end;

// - overrides the stnadard gnamefunc delete function
procedure tgname.delfunc(d:listitem);
begin
  freemem(pgnameitem(d).nam);
  dispose(pgnameitem(d));
end;

{************************************************************************
* addname                                                               *
* - this is to add a name to the list of names.                         *
* - if the address is not covered in our list of segments then we       *
*   ignore the request                                                  *
* - we check that it is ok to name the location before naming it. This  *
*   basically ensures that names cannot be added in the middle of a     *
*   disassembled instruction, etc. It should not affect imports/exports *
*   since these will be named prior to disassembly                      *
* - the name is copied and a new string created for it, so the calling  *
*   function must delete any memory created to hold the name            *
* - if the same location is named twice then the first name is deleted  *
* - the name is added to the disassembly so that it appears in the      *
*   listing.                                                            *
* - naming a location with "" results in any name being deleted         *
************************************************************************}
procedure tgname.addname(loc:lptr; nm:pchar);
var
  i:integer;
  newname,checkdup:pgnameitem;
begin
  // check for non-existant address added v2.20
if $102cd22 = loc.o then
  i:=i;
  if dta.findseg(loc)=nil then exit;
  if not dsm.oktoname(loc) then exit; // check not in the middle of an instruction.
  newname:=new(pgnameitem);
  getmem(newname.nam,strlen(nm)+1);
  strcopy(newname.nam,nm);
  demangle(newname.nam);
  newname.addr:=loc;
  checkdup:=pgnameitem(find(listitem(newname)));
  // just add it once.
  if checkdup<>nil then if eq(checkdup.addr,loc) then begin
    dispose(checkdup.nam);
    checkdup.nam:=newname.nam;
    dispose(newname);
    dsm.delcomment(loc,dsmnameloc);
    if strlen(checkdup.nam)<>0 then dsm.discomment(loc,dsmnameloc,checkdup.nam)
    else delfrom(listitem(checkdup));
    exit;
  end;
  if strlen(newname.nam)=0 then begin
    dispose(newname.nam); // bugfix by Mark Ogden
    dispose(newname);
    exit;
  end;
  addto(listitem(newname));
  dsm.discomment(loc,dsmnameloc,newname.nam);
end;

// isname                                                                *
// - returns TRUE if loc has a name                                      *
function tgname.isname(loc:lptr):boolean;
var
  checkit:tgnameitem;
  findit :pgnameitem;
begin
  result:=false;
  checkit.addr:=loc;
  findit:=pgnameitem(find(listitem(@checkit)));
  if findit<>nil then if eq(findit.addr,loc) then result:=true;
end;

// printname                                                             *
// - prints name to last buffer location in mainwindow buffering array   *
// - use with isname, for example:                                       *
//   if(name.isname(loc))name.printname(loc); etc                        *
procedure tgname.printname(loc:lptr);
var
  checkit:tgnameitem;
  findit :pgnameitem;
begin
  checkit.addr:=loc;
  findit:=pgnameitem(find(listitem(@checkit)));
  if findit<>nil then LastPrintBuff('%s',[findit.nam]);
end;

// delname                                                               *
// - used as a simple name deleter for a given location                  *
// - also deletes the name from the disassembly listing                  *
procedure tgname.delname(loc:lptr);
var
  dname   :tgnameitem;
  checkdup:pgnameitem;
begin
  dname.addr:=loc;
  checkdup:=pgnameitem(find(listitem(@dname)));
  if checkdup<>nil then if checkdup.addr.o=loc.o then delfrom(listitem(checkdup));
  dsm.delcomment(loc,dsmnameloc);
end;

{************************************************************************
* getoffsfromname                                                       *
* - this checks to see if a name is in the list, and if it is then it   *
*   returns the offset of its loc otherwise it returns 0. This function *
*   is used in generating the segment for imports in an NE file.        *
************************************************************************}
function tgname.getoffsfromname(nm:pchar):dword;
var t:pgnameitem;
begin
  resetiterator;
  t:=pgnameitem(nextiterator);
  while t<>nil do begin
    if strcomp(t.nam,nm)=0 then begin
      result:=t.addr.o;
    end;
    t:=pgnameitem(nextiterator);
  end;
  result:=0;
end;

// constructor function                                                  *
// - resets list, with small size list and no items.                     *
// - sets compare function and deletion function to NULL.                *
constructor tslist.create;
begin
  inherited create;
  getmem(listptr,4*1024);
  listiter:=0;
  listsize:=0;
  maxsize:=1024;
end;

// destructor function                                                   *
// - calls the deletion function for each item in the list               *
destructor tslist.destroy;
var i:integer;
begin
  for i:=0 to listsize-1 do delfunc(listptr^[i]);
  freemem(listptr);
end;

// sets the compare function                                             *
// - the compare function is used in ordering and searching the list     *
//   but it must be user defined, and so this routine should be called   *
//   as soon as possible to set up the compare function for each list    *
function tslist.compare(a,b:listitem):integer;
begin
  result:=-1;
  if a<b then exit else result:=1;
  if a>b then exit else result:=0;
end;

// sets the delete function                                              *
// - the delete function is called when deleting items from a list and   *
//   must be set by the user as soon as possible                         *
procedure tslist.delfunc(d:listitem);
begin
  freemem(d);
end;

// add an item to the list                                               *
// - this takes care of list size, resizing the list if more space is    *
//   needed. It inserts a new item, using the lists compare function to  *
//   order the list                                                      *
procedure tslist.addto(l:listitem);
var
  i:integer;
  nlist:plistptr;
begin
  if listsize=maxsize then begin
    // resize list
    inc(maxsize,1024);
    getmem(nlist,4*maxsize);
    for i:=0 to listsize-1 do nlist^[i]:=listptr^[i];
    freemem(listptr);
    listptr:=nlist;
  end;
  if find(l)=nil then begin
    // empty list
    listptr^[0]:=l;
    listsize:=1;
    exit;
  end else begin
    // use listiter set by find
    // ensure can add to end
    if compare(listptr^[listiter],l)=-1 then inc(listiter);
      // move array up
    for i:=listsize downto listiter+1 do listptr^[i]:=listptr^[i-1];
    listptr^[listiter]:=l;
    inc(listsize);
  end;
end;

// delete an item in the list                                            *
// - this just deletes one item from the list, and closes the gap        *
//   afterwards. It does not perform downsizing of the list              *
procedure tslist.delfrom(l:listitem);
var i:dword;
begin
  if listsize=0 then exit;
  if find(l)=nil then exit;
  if compare(listptr^[listiter],l)=0 then begin  // ensure equal
    delfunc(listptr^[listiter]);
    // move the rest down
    for i:=listiter to listsize-2 do listptr^[i]:=listptr^[i+1]; //??
    dec(listsize);
  end;
end;

// find an item in a list                                                *
// - this is used to find items, it performs a binary search using the   *
//   lists compare function. It returns a pointer to the nearest item    *
//   and sets the list iterator to that item.                            *
// The nearest item is:                                                  *
// - NULL if the list is empty                                           *
// - the first item if ptr< first item                                   *
// - the last item if ptr> last item                                     *
// - the first item such that ptr=item                                   *
// - the nth item if nth item<ptr and n+1th item> ptr                    *
function tslist.find(l:listitem):listitem;
var i,j,k:dword;
begin
  result:=nil;
  if listsize=0 then begin listiter:=0; exit end;
  // i moves from the front of the array and j from the back
  // until they are equal which is the returned item
  i:=0;
  j:=listsize-1;
  while i<>j do begin
    // k=middle item for binary search
    k:=(i+j) shr 1;
    case compare(listptr^[k],l) of
     -1:
       begin
         // listptr[k]->cmp < ptr->cmp
         if j-i=1 then begin // special case
           if i=k then begin
             if compare(listptr^[j],l)<>1 then i:=j else j:=i;
           end else i:=j;
         end else i:=k;   // move lower bound up
       end;
      0:
       begin
         // listptr[k]->cmp==ptr->cmp
         // only gets the first one of this type
         j:=k;
       end;
      1:       // listptr[k]->cmp > ptr->cmp
       begin
         if j-i=1 then begin  // special case
           if i=k then j:=k else j:=i;
         end else j:=k;   // move upper bound down
       end;
    end;
  end;
  listiter:=i;
  result:=listptr^[i];
end;

{************************************************************************
* findnext - finds an item in a list                                    *
* - this is used to find items, it performs a binary search using the   *
*   lists compare function. It returns a pointer to the nearest item    *
*   after the request and sets the list iterator to that item. In this  *
*   way it differs slightly from find.                                  *
* The nearest item is:                                                  *
* - NULL if the list is empty                                           *
* - the first item if ptr< first item                                   *
* - NULL if ptr> last item                                              *
* - the first item such that ptr=item                                   *
* - the n+1th item if nth item<ptr and n+1th item> ptr                  *
************************************************************************}
function tslist.findnext(l:listitem):listitem;
var i,j,k:dword;
begin
  result:=nil;
  if listsize=0 then begin listiter:=0; exit end;
  // i moves from the front of the array and j from the back
  // until they are equal which is the returned item
  i:=0;
  j:=listsize-1;
  // check if its beyond the bounds....
  if compare(listptr^[j],l)=-1 then exit;
  while i<>j do begin
    // k=middle item for binary search
    k:=(i+j) shr 1;
    case compare(listptr^[k],l) of
     -1:
       begin
         // listptr[k]->cmp < ptr->cmp
         if j-i=1 then begin // special case
           if i=k then i:=j else j:=i;
         end else i:=k;   // move lower bound up
       end;
      0: j:=k;
         // listptr[k]->cmp==ptr->cmp
         // only gets the first one of this type
      1: if j-i=1 then j:=i else j:=k; // special case
         // listptr[k]->cmp > ptr->cmp
         // move upper bound down
    end;
  end;
  listiter:=i;
  result:=listptr^[i];
end;

// reset list iterator to start of list                                  *
procedure tslist.resetiterator;
begin
  listiter:=0;
end;

// return next item in list using list iterator                          *
// - if listiter is beyond list then returns NULL                        *
// - otherwise returns listiter item, and then increases listiter        *
// NB after finding an item the next item returned by this function will *
//    be the same item                                                   *
function tslist.nextiterator:listitem;
begin
  if listiter>=listsize then begin
    listiter:=0; result:=nil;
  end else begin
    result:=listptr^[listiter]; inc(listiter);
  end;
end;

// return previous item in list using list iterator                      *
// - if listiter is at start of list then returns NULL                   *
// - otherwise decreases listiter and then returns the listitem          *
// NB after finding an item the next item returned by this function will *
//    be the previous item                                               *
function tslist.lastiterator:listitem;
begin
  result:=nil;
  if listiter=0 then exit;
  dec(listiter);
  result:=listptr^[listiter];
end;

// process queue function                                                *
// - this was written for the scheduler mainly. It is used to process    *
// the list as a queue. It returns the first item from the list and also *
// removes it from the list                                              *
function tslist.processqueue:listitem;
var
  i:integer;
  t:listitem;
begin
  result:=nil;
  if listsize=0 then exit;
  t:=listptr^[0];
  for i:=0 to listsize-2 do listptr^[i]:=listptr^[i+1]; //???
  dec(listsize);
  result:=t;
end;

// peekfirst                                                             *
// - returns the first item from the list, without removal               *
function tslist.peekfirst:listitem;
begin
  if listsize=0 then result:=nil
  else result:=listptr^[0];
end;

// numlistitems                                                          *
// - simply returns the number of items in the list                      *
function tslist.numlistitems:integer;
begin
  result:=listsize;
end;

initialization
  nam:=tgname.create;
  import:=tgname.create;
  expt:=tgname.create;
finalization
  nam.free;
  import.free;
  expt.free;
end.

