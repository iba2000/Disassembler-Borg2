unit schedule;
interface
uses windows,common,gname,mainwind,range;
{************************************************************************
* Main task scheduler for Borg. This class is central to the workings   *
* of the secondary thread, and to the calls which are passed back and   *
* forth to the secondary thread. When Borg decides it is going to do    *
* something it is added to a list of things to do, along with a         *
* priority for doing it. Like updating the main window is more          *
* important than naming a location. The scheduler then manages the      *
* queue of items to be processed, and calls each in turn. The queue can *
* be temporarily stopped for low priority items (lower than userrequest *
* priority), this is to enable many of the primary thread dialog boxes  *
* to work whilst maintaining window updates and changes                 *
* Accessing the task list should be covered by critical sections, since *
* either thread can access the list. The other place that critical      *
* sections are heavily used is in the display of the main window, and   *
* the buffer generation for the main window.                            *
************************************************************************}
type
  tasktype=(
    tasktype_null,dis_code,dis_dataword,dis_datadword,dis_datastring,nameloc,
    windowupdate,scrolling,user_makecode,user_undefineline,user_undefinelines,
    user_jumpto,user_jumptoarg2,user_jumptoaddr,user_makedword,user_makeword,
    user_makestring,user_pascalstring,dis_datapstring,namecurloc,
    dis_segheader,user_jumpback,dis_jumptable,user_ucstring,user_upstring,
    user_dosstring,user_generalstring,dis_dataucstring,dis_dataupstring,
    dis_datadosstring,dis_datageneralstring,dis_xref,dis_import,dis_ordimport,
    dis_export,dis_ordexport,hscroll,user_argoverdec,user_argoverhex,
    user_argoverchar,dis_argoverdec,dis_argoverhex,dis_argoverchar,quitborg,
    user_argoveroffsetdseg,dis_argoveroffsetdseg,dis_datadsoffword,seek_code,
    vthumbposition,hthumbposition,dis_exportcode,user_undefinelines_long,
    user_argnegate,user_marktopblock,user_markbottomblock,user_undefineblock,
    dis_stringtable,user_makesingle,user_makedouble,user_makelongdouble,
    user_argsingle,dis_dialog,user_addcomment,user_delcomment,
    user_repeatxrefview,user_repeatnameview,user_delxref);
  priority=(
    priority_null,priority_quit,priority_window,priority_userrequest,
    priority_import,priority_export,priority_xref,priority_continuation,
    priority_nameloc,priority_segheader,priority_definitecode,priority_data,
    priority_possiblecode,priority_aggressivesearch);

  ptaskitem=^ttaskitem;
  ttaskitem=record
    ttype:tasktype;
    p:priority;
    addr:lptr;
    comment:pchar;
    tnum:dword;
  end;

  tschedule=class(tslist)
  private
    threadpause:boolean;   // volatile
    threadstopped:boolean; // volatile
  public
    constructor create;
    function compare(a,b:listitem):integer;override;
    procedure delfunc(d:listitem);override;
    procedure addtask(ttype:tasktype; p:priority; loc:lptr; x:dword; comment:pchar);
    function process:boolean;
    function  sizelist:dword;
    procedure stopthread;
    procedure continuethread;
  end;

var
  scheduler:tschedule;

implementation
uses disasm,disio,datas,xref;

//compare function for list - uses priority to sort list
function tschedule.compare(a,b:listitem):integer;
var i,j:ptaskitem;
begin
  i:=ptaskitem(a); j:=ptaskitem(b);
  if i.p=j.p then begin
    if i.tnum=j.tnum then begin
      result:=0; exit;
    end;
    if i.tnum>j.tnum then begin
      result:=1; exit;
    end; result:=-1; exit;
  end;
  if i.p>j.p then begin
    result:=1; exit;
  end; result:= -1;
end;

procedure tschedule.delfunc(d:listitem);
var i:ptaskitem;
begin
  i:=ptaskitem(d);
  if i.comment<>nil then freemem(i.comment);
  dispose(i);
end;

constructor tschedule.create;
begin
  inherited create;
  threadpause:=false;
  threadstopped:=true;
end;

// addtask                                                               *
// - this adds a task to the queue. This function has to be very careful *
//   as it can potentially be called by either thread at any time, and   *
//   so could be called from both threads at precisely the same time.    *
//   So there is a critical section for manipulating the queue of tasks. *
// - added tasktype tt and moved tnumt whilst commenting this function   *
//   Borg v2.21 for safety!                                              *
procedure tschedule.addtask(ttype:tasktype; p:priority; loc:lptr; x:dword; comment:pchar);
const tnumt:dword=0;
var
  tt:tasktype;
  titem:ptaskitem;
begin
  inc(loc.o,x);
  // limit window updates added to queue - called be called many times by disasm.
  if ttype=windowupdate then begin
    EnterCriticalSection(cs);
    titem:=ptaskitem(peekfirst);
    if titem<>nil then tt:=titem.ttype else tt:=tasktype_null;
    LeaveCriticalSection(cs);
    if tt=windowupdate then exit;
  end;
  titem:=new(ptaskitem);
  titem.ttype:=ttype;
  titem.p:=p;
  titem.addr.s:=loc.s; titem.addr.o:=loc.o;
  titem.comment:=comment;
  EnterCriticalSection(cs);
  titem.tnum:=tnumt;
  inc(tnumt);
  addto(listitem(titem));
  LeaveCriticalSection(cs);
end;

// - here we take the item at the front of the task queue and process it *
// - if the queue has been requested to hold then we only process high   *
//   priority items                                                      *
// - more thread safety code added v 2.21 during commenting and closer   *
//   examination                                                         *
function tschedule.process:boolean;
var
  task:ptaskitem;
  done:boolean;
  i,procdany:boolean;
  q:priority;
begin
  done:=FALSE;
  procdany:=FALSE;
  threadstopped:=FALSE;
  repeat
    // our checks for pausing the threads must be thread safe
    // accessing the task list must be in a critical section
    EnterCriticalSection(cs);
    task:=ptaskitem(peekfirst);
    if task<>nil then q:=task.p else q:=priority_null;
    LeaveCriticalSection(cs);
    if q>priority_userrequest then begin
      while threadpause do begin
        threadstopped:=TRUE;
        EnterCriticalSection(cs);
        task:=ptaskitem(peekfirst);
        if task<>nil then q:=task.p else q:=priority_null;
        LeaveCriticalSection(cs);
        if q<priority_userrequest then break;
        Sleep(0);
      end;
    end;
    threadstopped:=FALSE;
    EnterCriticalSection(cs);
    task:=ptaskitem(processqueue);
    LeaveCriticalSection(cs);
    if task=nil then done:=TRUE
    else begin
      StatusMessageNItems(numlistitems);
      procdany:=TRUE;
      case task.ttype of
       dis_code:               dsm.disblock(task.addr);
       dis_exportcode:         dsm.disexportblock(task.addr);
       user_makecode:          dio.makecode;
       user_undefineline:      dsm.undefineline;
       user_undefinelines:     dsm.undefinelines;
       user_undefinelines_long:dsm.undefinelines_long;
       user_jumpback:          dio.jumpback;
       user_jumpto:            dio.jumpto(true);
       user_jumptoarg2:        dio.jumpto(false);
       user_jumptoaddr:
        begin
          dio.savecuraddr;
          dio.setcuraddr(task.addr);
        end;
       windowupdate:           dio.updatewindow;
       scrolling:              dio.scroller(task.addr.o);
       vthumbposition:         dio.vertsetpos(task.addr.o);
       hthumbposition:         horizscrollto(task.addr.o);
       hscroll:                horizscroll(task.addr.o);
       user_makedword:         dio.makedword;
       user_makesingle:        dio.makesingle;
       user_makedouble:        dio.makedouble;
       user_makelongdouble:    dio.makelongdouble;
       user_makeword:          dio.makeword;
       user_makestring:        dio.makestring;
       user_pascalstring:      dio.pascalstring;
       user_ucstring:          dio.ucstring;
       user_upstring:          dio.upstring;
       user_dosstring:         dio.dosstring;
       user_generalstring:     dio.generalstring;
       user_argoverdec:        dio.argoverdec;
       user_argoverhex:        dio.argoverhex;
       user_argoverchar:       dio.argoverchar;
       user_argoveroffsetdseg: dio.argoveroffsetdseg;
       user_argnegate:         dio.arg_negate;
       user_argsingle:         dio.argoversingle;
       user_delcomment:        dsm.delcomment(task.addr,dsmcomment);
       user_addcomment:        dsm.discomment(task.addr,dsmcomment,task.comment);
       user_delxref:           xrefs.userdel(task.addr);
       user_repeatxrefview:    PostMessage(mainwindow,WM_REPEATXREFVIEW,0,0);
       user_repeatnameview:    PostMessage(mainwindow,WM_REPEATNAMEVIEW,0,0);
       user_undefineblock:     blk.undefine;
       user_marktopblock:      blk.settop;
       user_markbottomblock:   blk.setbottom;
       dis_dataword:           dsm.disdataword(task.addr,0);
       dis_datadword:          dsm.disdatadword(task.addr,0);
       dis_datadsoffword:      dsm.disdatadsoffword(task.addr);
       dis_datastring:         dsm.disdatastring(task.addr);
       dis_datapstring:        dsm.disdatapstring(task.addr);
       dis_dataucstring:       dsm.disdataucstring(task.addr);
       dis_dataupstring:       dsm.disdataupstring(task.addr);
       dis_datadosstring:      dsm.disdatadosstring(task.addr);
       dis_datageneralstring:  dsm.disdatageneralstring(task.addr);
       dis_argoverdec:         dsm.disargoverdec(task.addr);
       dis_argoverhex:         dsm.disargoverhex(task.addr);
       dis_argoverchar:        dsm.disargoverchar(task.addr);
       dis_argoveroffsetdseg:  dsm.disargoveroffsetdseg(task.addr);
       dis_dialog:
        begin
          dsm.disdialog(task.addr,task.comment);
          freemem(task.comment);
        end;
       dis_stringtable:
        begin
          dsm.disstringtable(task.addr,task.comment);
          freemem(task.comment);
        end;
       nameloc:                nam.addname(task.addr,task.comment);
       dis_xref:               dsm.disxref(task.addr);
       namecurloc:
         begin
           nam.addname(task.addr,task.comment);
           dispose(task.comment);
         end;
       dis_segheader:          dta.segheader(task.addr);
       dis_jumptable:          dsm.disjumptable(task.addr);
       dis_ordimport:
        begin
          import.addname(task.addr,task.comment);
          dispose(task.comment);
        end;
       dis_import:             import.addname(task.addr,task.comment);
       dis_ordexport:
        begin
          expt.addname(task.addr,task.comment);
          dispose(task.comment);
        end;
       dis_export:
         expt.addname(task.addr,task.comment);
       seek_code:              dsm.codeseek(task.addr);
       quitborg:
         begin
           threadstopped:=true;
           result:=true; exit;
         end;
      end;
      dispose(task);
    end;
    if KillThread then begin result:=TRUE; exit; end;
  until done;
  threadstopped:=true;
  result:=procdany;
end;

// sizelist                                                              *
// - this simply returns number of tasks left to process                 *
function tschedule.sizelist:dword;
begin
  result:=numlistitems;
end;

// stopthread                                                            *
// - pausing and continuing the secondary thread has not been without    *
//   its headaches in early versions. Here I simply set threadpause and  *
//   wait until threadstopped is set to true. Having finally sorted out  *
//   most thread issues and critical sections, etc I have more or less   *
//   ended up with the simplest code back in here. Many problems have    *
//   been due to clashes of critical section code, and pausing at the    *
//   wrong time, or exitting and waiting for a thread to finish when it  *
//   was waiting for a critical section, etc. Anyway, hopefully these    *
//   issues are now resolved and this simple code will endure for a bit  *
// - further simplified whilst commenting and analysing, Borg v2.21      *
// - Note that threadpause and threadstopped are both declared as        *
//   volatile variables.                                                 *
procedure tschedule.stopthread;
begin
  threadpause:=TRUE;
  while not threadstopped do Sleep(0);
end;

// continuethread                                                        *
// - simply sets threadpause to false again                              *
//- we dont need to wait around for verification that it has continued  *
procedure tschedule.continuethread;
begin
  threadpause:=FALSE;
end;

initialization
  scheduler:=tschedule.create;
finalization
  scheduler.free;
end.

