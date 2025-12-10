unit user_dlg;
interface
uses windows,sysutils,common,schedule,gname,disio,range,xref,datas,
     disasm,exeload,menus;
{************************************************************************
* - the functions here are viewers for various lists within Borg, for   *
*   example exports,imports and xrefs Dialog box viewers, along with    *
*   any calling functions which stop/start the secondary thread.        *
* - Extracted from various classes v2.22                                *
* - All routines in here when entered from outside should stop the      *
*   secondary thread and restart it on exit.                            *
************************************************************************}

procedure exportsviewer;
procedure importsviewer;
procedure namesviewer;
procedure namelocation;
procedure blockview;
procedure xrefsviewer;
procedure segviewer;
procedure getcomment;
procedure changeoep;
procedure jumpto;

var
  nme:pchar;

implementation

{************************************************************************
* exportsbox                                                            *
* - this is the exports viewer dialog box. It is simpler than the names *
*   class dialog box, featuring only a jump to option. As for the names *
*   class a request is added to the scheduler for any jump and the      *
*   dialog box exits. the main code is for filling the initial list box *
*   and for displaying a new address when the selection is changed      *
************************************************************************}
function exportsbox(hdwnd:HWND; msg,wParam,lParam:dword):dword;stdcall;
const
  nseg :string='';
  noffs:string='';
  t:pgnameitem=nil;
var
  i:dword;
begin
  result:=0;
  case msg of
   WM_COMMAND:
    begin
      case wParam of
       IDC_OKBUTTON:
         begin
           EndDialog(hdwnd,0); result:=1; exit;
         end;
        IDC_JUMPTOBUTTON:
         begin
           scheduler.addtask(user_jumptoaddr,priority_userrequest,t.addr,0,nil);
           EndDialog(hdwnd,0); result:=1; exit;
         end;
      end;
      case HIWORD(wParam) of
       LBN_SELCHANGE:
        begin
          i:=SendDlgItemMessage(hdwnd,IDC_EXPORTSLISTBOX,LB_GETCURSEL,0,0)+1;
          expt.resetiterator;
          t:=nil;
          while i>0 do begin
            t:=pgnameitem(expt.nextiterator); dec(i);
          end;
          fmtstr(nseg,'0x%4.4x',[t.addr.s]);
          fmtstr(noffs,'0x%8.8x',[t.addr.o]);
          SendDlgItemMessage(hdwnd,EXPORTS_TEXTSTART,WM_SETTEXT,0,dword(pchar(nseg)));
          SendDlgItemMessage(hdwnd,EXPORTS_TEXTEND,WM_SETTEXT,0,dword(pchar(noffs)));
          result:=1;
        end;
      end;
    end;
   WM_INITDIALOG:
    begin
      CenterWindow(hdwnd);
      expt.resetiterator;
      t:=nil;
      for i:=0 to expt.numlistitems-1 do begin
        t:=pgnameitem(expt.nextiterator);
        SendDlgItemMessage(hdwnd,IDC_EXPORTSLISTBOX,LB_ADDSTRING,0,dword(@t.nam^));
      end;
      SendDlgItemMessage(hdwnd,IDC_EXPORTSLISTBOX,LB_SETCURSEL,0,0);
      expt.resetiterator;
      t:=pgnameitem(expt.nextiterator);
      fmtstr(nseg,'0x%4.4x',[t.addr.s]);
      fmtstr(noffs,'0x%8.8x',[t.addr.o]);
      SendDlgItemMessage(hdwnd,EXPORTS_TEXTSTART,WM_SETTEXT,0,dword(pchar(nseg)));
      SendDlgItemMessage(hdwnd,EXPORTS_TEXTEND,WM_SETTEXT,0,dword(pchar(noffs)));
      SetFocus(GetDlgItem(hdwnd,IDC_OKBUTTON));
    end;
  end;
end;

{************************************************************************
* exportsviewer                                                         *
* - stops the thread and displays the exports viewer dialog.            *
************************************************************************}
procedure exportsviewer;
begin
  scheduler.stopthread;
  if expt.numlistitems=0 then
    MessageBox(0,'There are no exports in the list','Borg Message',MB_OK)
  else
    DialogBox(Inst,MAKEINTRESOURCE(Exports_Viewer),mainwindow,@exportsbox);
  scheduler.continuethread;
end;

{************************************************************************
* importsbox                                                            *
* - this is the imports viewer dialog box, it is similar to the exports *
*   and names dialog, although simpler since there is only an ok button *
*   Most of the code is for filling the list box and displaying info    *
*   when an item is selected                                            *
************************************************************************}
function importsbox(hdwnd:HWND; msg,wParam,lParam:dword):dword;stdcall;
const
  nseg:string='';
  noff:string='';
  t:pgnameitem=nil;
var
  i:dword;
begin
  result:=0;
  case msg of
   WM_COMMAND:
     begin
       case wParam of
        IDC_OKBUTTON:
          begin
             EndDialog(hdwnd,0); result:=1; exit;
           end;
        end;
        case HIWORD(wParam) of
          LBN_SELCHANGE:
            begin
              i:=SendDlgItemMessage(hdwnd,IDC_IMPORTSLISTBOX,LB_GETCURSEL,0,0)+1;
              import.resetiterator;
              t:=nil;
              while i>0 do begin
                t:=pgnameitem(import.nextiterator); dec(i);
              end;
              fmtstr(nseg,'0x%4.4x',[t.addr.s]);
              fmtstr(noff,'0x%8.8x',[t.addr.o]);
              SendDlgItemMessage(hdwnd,IMPORTS_TEXTSTART,WM_SETTEXT,0,dword(pchar(nseg)));
              SendDlgItemMessage(hdwnd,IMPORTS_TEXTEND,WM_SETTEXT,0,dword(pchar(noff)));
              result:=1;
            end;
         end;
       end;
    WM_INITDIALOG:
      begin
        import.resetiterator;
        t:=nil;
        for i:=0 to import.numlistitems-1 do begin
          t:=pgnameitem(import.nextiterator);
          SendDlgItemMessage(hdwnd,IDC_IMPORTSLISTBOX,LB_ADDSTRING,0,dword(@t.nam^));
        end;
        SendDlgItemMessage(hdwnd,IDC_IMPORTSLISTBOX,LB_SETCURSEL,0,0);
        import.resetiterator;
        t:=pgnameitem(import.nextiterator);
        fmtstr(nseg,'0x%4.4x',[t.addr.s]);
        fmtstr(noff,'0x%8.8x',[t.addr.o]);
        SendDlgItemMessage(hdwnd,IMPORTS_TEXTSTART,WM_SETTEXT,0,dword(pchar(nseg)));
        SendDlgItemMessage(hdwnd,IMPORTS_TEXTEND,WM_SETTEXT,0,dword(pchar(noff)));
        SetFocus(GetDlgItem(hdwnd,IDC_OKBUTTON));
      end;
  end;
end;

{************************************************************************
* importsviewer                                                         *
* - stops the thread and displays the imports viewer dialog.            *
************************************************************************}
procedure importsviewer;
begin
  scheduler.stopthread;
  if import.numlistitems=0 then
    MessageBox(0,'There are no imports in the list','Borg Message',MB_OK)
  else
    DialogBox(Inst,MAKEINTRESOURCE(Imports_Viewer),mainwindow,@importsbox);
  scheduler.continuethread;
end;

{************************************************************************
* getnamebox                                                            *
* - this is a small dialog for the input of name for a location. the    *
*   name is stored (pointer) in the global variable nme for the caller  *
*   to process                                                          *
************************************************************************}
function getnamebox(hdwnd:HWND; msg,wParam,lParam:dword):dword;stdcall;
var drect:trect;
begin
  result:=0;
  case msg of
   WM_COMMAND:
    case wParam of
     IDOK:
      begin
        EndDialog(hdwnd,0);
        getmem(nme,GNAME_MAXLEN+1);
        SendDlgItemMessage(hdwnd,IDC_NAMEEDIT,WM_GETTEXT,GNAME_MAXLEN,dword(@nme^));
        result:=1; exit;
      end;
     IDCANCEL:
      begin
        EndDialog(hdwnd,0);
        nme:=nil;
        result:=1; exit;
      end;
    end;
   WM_INITDIALOG:
    begin
      CenterWindow(hdwnd);
      SetFocus(GetDlgItem(hdwnd,IDC_NAMEEDIT));
    end;
  end;
end;


{************************************************************************
* namelocation                                                          *
* - this calls the user dialog for a name to be entered for the current *
*   location, and names it                                              *
************************************************************************}
procedure namelocation;
var loc:lptr;
begin
  scheduler.stopthread;
  nme:=nil;
  DialogBox(Inst,MAKEINTRESOURCE(Get_Name),mainwindow,@getnamebox);
  if nme<>nil then begin
    dio.findcurrentaddr(loc);
    scheduler.addtask(namecurloc,priority_userrequest,loc,0,nme);
  end;
  scheduler.continuethread;
end;

{************************************************************************
* namesbox                                                              *
* - the dialog box for the names list.                                  *
* - the list is a simple location order of names, which is the same as  *
*   the underlying list class ordering                                  *
************************************************************************}
function namesbox(hdwnd:HWND; msg,wParam,lParam:dword):dword;stdcall;
const
  nseg :string='';
  noffs:string='';
  a:array[0..200] of char=#0;
  b:array[0..200] of char=#0;
  t:pgnameitem=nil;
var
  i:dword;
begin
  result:=0;
  case msg of
   WM_COMMAND:
    begin
      case wParam of
       IDC_OKBUTTON:
        begin
          EndDialog(hdwnd,0); result:=1; exit;
        end;
       IDC_JUMPTOBUTTON:
        begin
          scheduler.addtask(user_jumptoaddr,priority_userrequest,t.addr,0,nil);
          EndDialog(hdwnd,0); result:=1; exit;
        end;
       NAMES_DELETE:
        begin
          nam.delname(t.addr);
          EndDialog(hdwnd,0); result:=1; exit;
        end;
       NAMES_RENAME:
        begin
          nme:=nil;
          DialogBox(Inst,MAKEINTRESOURCE(Get_Name),hdwnd,@getnamebox);
          if nme<>nil then
            scheduler.addtask(namecurloc,priority_userrequest,t.addr,0,nme);
          scheduler.addtask(user_repeatnameview,priority_userrequest,nlptr,0,nil);
          EndDialog(hdwnd,0); result:=1; exit;
        end;
      end;
      case HIWORD(wParam) of
       LBN_SELCHANGE:
        begin
          i:=SendDlgItemMessage(hdwnd,IDC_NAMESLISTBOX,LB_GETCURSEL,0,0)+1;
          nam.resetiterator;
          t:=nil;
          while i>0 do begin
            t:=pgnameitem(nam.nextiterator); dec(i);
          end;
          fmtstr(nseg,'0x%4.4x',[t.addr.s]);
          fmtstr(noffs,'0x%8.8x',[t.addr.o]);
          strpcopy(a,nseg); strpcopy(b,noffs);
          SendDlgItemMessage(hdwnd,NAMES_TEXTSTART,WM_SETTEXT,0,dword(@b));
          SendDlgItemMessage(hdwnd,NAMES_TEXTEND,WM_SETTEXT,0,dword(@b));
          result:=1;
        end;
      end;
    end;
   WM_INITDIALOG:
    begin
      CenterWindow(hdwnd);
      nam.resetiterator;
      t:=nil;
      for i:=0 to nam.numlistitems-1 do begin
        t:=pgnameitem(nam.nextiterator);
        SendDlgItemMessage(hdwnd,IDC_NAMESLISTBOX,LB_ADDSTRING,0,dword(t.nam));
      end;
      SendDlgItemMessage(hdwnd,IDC_NAMESLISTBOX,LB_SETCURSEL,0,0);
      nam.resetiterator;
      t:=pgnameitem(nam.nextiterator);
      fmtstr(nseg,'0x%4.4x',[t.addr.s]);
      fmtstr(noffs,'0x%8.8x',[t.addr.o]);
      strpcopy(a,nseg); strpcopy(b,noffs);
      SendDlgItemMessage(hdwnd,NAMES_TEXTSTART,WM_SETTEXT,0,dword(@a));
      SendDlgItemMessage(hdwnd,NAMES_TEXTEND,WM_SETTEXT,0,dword(@b));
      SetFocus(GetDlgItem(hdwnd,IDC_OKBUTTON));
    end;
  end;
end;

{************************************************************************
* namesviewer                                                           *
* - this controls the display of the names viewer dialog box. names are *
*   viewed in the dialog box in location order.                         *
************************************************************************}
procedure namesviewer;
begin
  scheduler.stopthread;
  if nam.numlistitems=0 then
    MessageBox(mainwindow,'There are no names in the list','Borg Message',MB_OK)
  else
    DialogBox(Inst,MAKEINTRESOURCE(Names_Viewer),mainwindow,@namesbox);
  scheduler.continuethread;
end;

{************************************************************************
* blockbox                                                              *
* - this is the dialog which just shows the extents of the current      *
*   block                                                               *
************************************************************************}
function blockbox(hdwnd,msg,wParam,lParam:dword):dword;stdcall;
const
  fmt:pchar='%4.4x:%8.8xh';
  s1:array[0..30] of char=#0;
  s2:array[0..30] of char=#0;
  s3:array[0..40] of char=#0;
begin
  result:=0;
  case msg of
   WM_COMMAND:
    case wParam of
     IDOK: begin EndDialog(hdwnd,0); result:=1; end;
    end;
   WM_INITDIALOG:
    begin
      CenterWindow(hdwnd);
      strlfmt(s1,30,fmt,[blk.top.s,blk.top.o]);
      strlfmt(s2,30,fmt,[blk.bottom.s,blk.bottom.o]);
      SendDlgItemMessage(hdwnd,Text_Top,WM_SETTEXT,0,dword(@s1));
      SendDlgItemMessage(hdwnd,Text_Bottom,WM_SETTEXT,0,dword(@s2));
      if eq(blk.top,nlptr) then strcopy(s3,'Top not set')
      else if eq(blk.bottom,nlptr) then strcopy(s3,'Bottom not set')
      else if gr(blk.top,blk.bottom) then strcopy(s3,'Range is empty')
      else strcopy(s3,'Range set');
      SendDlgItemMessage(hdwnd,Text_Status,WM_SETTEXT,0,dword(@s3));
    end;
  end;
end;

{************************************************************************
* blockview                                                             *
* - this stops the secondary thread and puts up the dialog box for      *
*   viewing the extents of the block                                    *
************************************************************************}
procedure blockview;
begin
  scheduler.stopthread;
  DialogBox(Inst,MAKEINTRESOURCE(Block_Dialog),mainwindow,@blockbox);
  scheduler.continuethread;
end;

{************************************************************************
* dialog box controls and workings - most message processing is         *
* standardised across Borg (colorchanges, etc)                          *
************************************************************************}
function xrefsbox(hdwnd,msg,wParam,lParam:dword):dword;stdcall;
const
  nseg :string='';
  noffs:string='';
  vt:pxrefitem=nil;
  currsel:pxrefitem=nil;
  xtmp:txrefitem=();
  numberofitems:integer=0;
var
  st:dword;
  i:dword;
begin
  result:=0;
  case msg of
   WM_COMMAND:
    begin
     case wParam of
      IDC_OKBUTTON:
       begin
         EndDialog(hdwnd,0); result:=1; exit;
       end;
      IDC_JUMPTOBUTTON:
       begin
         scheduler.addtask(user_jumptoaddr,priority_userrequest,currsel.refby,0,nil);
         EndDialog(hdwnd,0); result:=1; exit;
       end;
      XREFS_DELETE:
       begin
         scheduler.addtask(user_delxref,priority_userrequest,currsel.refby,0,nil);
         scheduler.addtask(windowupdate,priority_window,nlptr,0,nil);
         EndDialog(hdwnd,0); result:=1; exit;
       end;
     end;
     case HIWORD(wParam) of
      LBN_SELCHANGE:
       begin
         i:=SendDlgItemMessage(hdwnd,IDC_XREFSLISTBOX,LB_GETCURSEL,0,0)+1;
         xrefs.findnext(@xtmp);
         vt:=nil;
         while i>0 do begin
           vt:=pxrefitem(xrefs.nextiterator); dec(i)
         end;
         currsel:=vt;
         result:=1;
       end;
      end;
    end;
   WM_INITDIALOG:
    begin
      CenterWindow(hdwnd);
      dio.findcurrentaddr(xtmp.addr);
      xtmp.refby:=nlptr;
      xrefs.findnext(@xtmp);
      vt:=pxrefitem(xrefs.nextiterator);
      currsel:=vt;
      numberofitems:=0;
      if vt<>nil then begin
        while eq(vt.addr,xtmp.addr) do begin
          fmtstr(nseg,'0x%4x',[vt.refby.s]);
          fmtstr(noffs,'0x%4x',[vt.refby.o]);
          nseg:=nseg+':'+noffs;
          inc(numberofitems);
          SendDlgItemMessage(hdwnd,IDC_XREFSLISTBOX,LB_ADDSTRING,0,dword(pchar(nseg)));
          vt:=pxrefitem(xrefs.nextiterator);
          if vt=nil then break;
        end;
      end;
      SendDlgItemMessage(hdwnd,IDC_XREFSLISTBOX,LB_SETCURSEL,0,0);
      SetFocus(GetDlgItem(hdwnd,IDC_OKBUTTON));
    end;
  end;
end;

{************************************************************************
* the xrefs viewer - stops the thread and continues it after            *
* displaying the dialog box                                             *
************************************************************************}
procedure xrefsviewer;
var
  findit:pxrefitem;
  xtmp:txrefitem;
begin
  scheduler.stopthread;
  dio.findcurrentaddr(xtmp.addr);
  xtmp.refby:=nlptr;
  findit:=pxrefitem(xrefs.findnext(listitem(@xtmp)));
  if findit=nil then
    MessageBox(mainwindow,'Unable to find any xrefs for the location','Borg Message',MB_OK)
  else if neq(findit.addr,xtmp.addr) then
    MessageBox(mainwindow,'There are no xrefs for the current location in the list','Borg Message',MB_OK)
  else
    DialogBox(Inst,MAKEINTRESOURCE(Xrefs_Viewer),mainwindow,@xrefsbox);
  scheduler.continuethread;
end;

{************************************************************************
* segbox                                                                *
* - this is the segment viewer dialog box which shows the segments, and *
*   details of them as they are clicked on. It allows jumping to the    *
*   segments as well. Background analysis is halted when calling this   *
*   particularly because iterators are used, and they there is only one *
*   iterator for the segment list                                       *
************************************************************************}
function segbox(hdwnd:HWND; msg,wParam,lParam:longint):longint;stdcall;
type
  psegtarr=^tsegtarr;
  tsegtarr=array[0..1000] of pchar;
const
  t     :pdsegitem=nil;
  segt  :psegtarr=nil;
  sseg  :string='';
  sstart:string='';
  send  :string='';
  ssize :string='';
  stype :string='';
  a:array[0..300] of char=#0;
var
  i:integer;
begin
  result:=0;
  case msg of
   WM_COMMAND:
    begin
      case wParam of
       IDC_OKBUTTON:
        begin
          EndDialog(hdwnd,0); result:=1; exit;
        end;
       IDC_JUMPTOBUTTON:
        begin
          scheduler.addtask(user_jumptoaddr,priority_userrequest,t.addr,0,nil);
          EndDialog(hdwnd,0); result:=1; exit;
        end;
      end;
      case HIWORD(wParam) of
       LBN_SELCHANGE:
        begin
          i:=SendDlgItemMessage(hdwnd,IDC_SEGLISTBOX,LB_GETCURSEL,0,0)+1; //??
          dta.resetiterator;
          t:=nil;
          while i>0 do begin
            t:=pdsegitem(dta.nextiterator); dec(i);
          end;
          fmtstr(sstart,'0x%8.8x',[t.addr.o]);
          fmtstr(send,'0x%8.8x',[t.addr.o+t.size-1]);
          fmtstr(ssize,'0x%8.8x',[t.size]);
          case t.typ of
           code16:       stype:='16-bit Code';
           code32:       stype:='32-bit Code';
           data16:       stype:='16-bit Data';
           data32:       stype:='32-bit Data';
           uninitdata:   stype:='Uninit Data';
           debugdata:    stype:='Debug Data';
           resourcedata: stype:='Resource Data';
           else          stype:='Unknown';
          end;
          SendDlgItemMessage(hdwnd,SEG_TEXTSTART,WM_SETTEXT,0,dword(pchar(sstart)));
          SendDlgItemMessage(hdwnd,SEG_TEXTEND,WM_SETTEXT,0,dword(pchar(send)));
          SendDlgItemMessage(hdwnd,SEG_TEXTSIZE,WM_SETTEXT,0,dword(pchar(ssize)));
          SendDlgItemMessage(hdwnd,SEG_TEXTTYPE,WM_SETTEXT,0,dword(pchar(stype)));
          SendDlgItemMessage(hdwnd,IDC_SEGNAMETEXT,WM_SETTEXT,0,dword(@t.nam^));
          result:=1; exit;
        end;
      end;
    end;
   WM_INITDIALOG:
    begin
      CenterWindow(hdwnd);
      getmem(segt,4*dta.numlistitems+1);
      dta.resetiterator;
      for i:=0 to dta.numlistitems-1 do begin
        getmem(segt^[i],20); fillchar(segt^[i]^,20,0);
        t:=pdsegitem(dta.nextiterator);
        fmtstr(sseg,'0x%4.4x:0x%8.8x',[t.addr.s,t.addr.o]);
        strpcopy(segt^[i],sseg);
        SendDlgItemMessage(hdwnd,IDC_SEGLISTBOX,LB_ADDSTRING,0,dword(@segt^[i]^));
      end;
      SendDlgItemMessage(hdwnd,IDC_SEGLISTBOX,LB_SETCURSEL,0,0);
      dta.resetiterator;
      t:=pdsegitem(dta.nextiterator);
      fmtstr(sstart,'0x%8.8x',[t.addr.o]);
      fmtstr(send,'0x%8.8x',[t.addr.o+t.size-1]);
      fmtstr(ssize,'0x%8.8x',[t.size]);
      case t.typ of
       code16:      stype:='16-bit Code';
       code32:      stype:='32-bit Code';
       data16:      stype:='16-bit Data';
       data32:      stype:='32-bit Data';
       uninitdata:  stype:='Uninit Data';
       debugdata:   stype:='Debug Data';
       resourcedata:stype:='Resource Data';
       else         stype:='Unknown';
      end;
      SendDlgItemMessage(hdwnd,SEG_TEXTSTART,WM_SETTEXT,0,dword(pchar(sstart)));
      SendDlgItemMessage(hdwnd,SEG_TEXTEND,WM_SETTEXT,0,dword(pchar(send)));
      SendDlgItemMessage(hdwnd,SEG_TEXTSIZE,WM_SETTEXT,0,dword(pchar(ssize)));
      SendDlgItemMessage(hdwnd,SEG_TEXTTYPE,WM_SETTEXT,0,dword(pchar(stype)));
      SendDlgItemMessage(hdwnd,IDC_SEGNAMETEXT,WM_SETTEXT,0,dword(@t.nam^));
      SetFocus(GetDlgItem(hdwnd,IDC_OKBUTTON));
    end;
   WM_DESTROY:
    begin
      for i:=0 to dta.numlistitems-1 do begin
        SendDlgItemMessage(hdwnd,IDC_SEGLISTBOX,LB_DELETESTRING,dta.numlistitems-i-1,0);
        freemem(segt^[dta.numlistitems-i-1]);
      end;
      freemem(segt);
    end;
  end;
end;

{************************************************************************
* segviewer                                                             *
* - stops the secondary thread, and calls the dialog box for viewing    *
*   the segments, then restarts the thread when the dialog box is done. *
************************************************************************}
procedure segviewer;
begin
  scheduler.stopthread;
  DialogBox(Inst,MAKEINTRESOURCE(Seg_Viewer),mainwindow,@segbox);
  scheduler.continuethread;
end;

{************************************************************************
* getoepbox                                                             *
* - this is the small dialog box for getting an address from the user.  *
* - it will change the program entry point to that address and patch    *
*   the program if necessary. The current viewing address is also       *
*   changed to the new address.                                         *
************************************************************************}
function getoepbox(hdwnd:HWND; msg,wParam,lParam:dword):dword;stdcall;
const
  loc:lptr=();
  newaddr:array[0..80] of char=#0;
var
  patchit:bool;
begin
  result:=0;
  case msg of
   WM_COMMAND:
    begin
      case wParam of
       IDOK:
        begin
          EndDialog(hdwnd,0);
          SendDlgItemMessage(hdwnd,IDC_OEPEDIT,WM_GETTEXT,80,dword(@newaddr));
          dio.findcurrentaddr(loc);
          if strlen(newaddr)>0 then begin
            loc.o:=strtoint('$'+newaddr);
            if dta.findseg(loc)<>nil then begin
              dio.savecuraddr;
              dio.setcuraddr(loc);
              scheduler.addtask(windowupdate,priority_window,nlptr,0,nil);
            end;
            // apply new start point
            scheduler.addtask(nameloc,priority_userrequest,options.oep,0,'');
            options.oep:=loc;
            scheduler.addtask(nameloc,priority_userrequest,options.oep,0,'start');
            if SendDlgItemMessage(hdwnd,IDC_PATCHOEP,BM_GETCHECK,0,0)<>0 then
              patchit:=true
            else
              patchit:=false;
            if options.readonly and patchit then begin
              MessageBox(hdwnd,'Program is opened read only, can''t patch it, sorry', 'Borg - Change OEP',MB_OK);
              patchit:=false;
            end;
            if patchit then // and patch executable
              floader.patchoep;
          end;
          result:=1; exit;
        end;
       IDCANCEL:
        begin
          EndDialog(hdwnd,0);
          result:=1; exit;
        end;
      end;
    end;
   WM_INITDIALOG:
    begin
      CenterWindow(hdwnd);
      SetFocus(GetDlgItem(hdwnd,IDC_OEPEDIT));
      if not options.readonly then
        SendDlgItemMessage(hdwnd,IDC_PATCHOEP,BM_SETCHECK,1,0);
    end;
  end;
end;

{************************************************************************
* changeoep                                                             *
* - stops the thread and gets an address from the user for the new oep  *
************************************************************************}
procedure changeoep;
begin
  if floader.exetype<>PE_EXE then begin
    MessageBox(mainwindow,'Can only change the oep for PE files','Borg',MB_OK); exit;
  end;
  scheduler.stopthread;
  DialogBox(Inst,MAKEINTRESOURCE(OEP_Editor),mainwindow,@getoepbox);
  scheduler.continuethread;
end;

{************************************************************************
* getjaddrbox                                                           *
* - this is the small dialog box for getting an address from the user.  *
* - it changes the current viewing location to that address.            *
************************************************************************}
function getjaddrbox(hdwnd:HWND; msg,wParam,lParam:dword):dword;stdcall;
const
  loc:lptr=();
  newaddr:array[0..80] of char=#0;
begin
  result:=0;
  case msg of
   WM_COMMAND:
    begin
      case wParam of
       IDOK:
        begin
          EndDialog(hdwnd,0);
          SendDlgItemMessage(hdwnd,IDC_JADDREDIT,WM_GETTEXT,80,dword(@newaddr));
          dio.findcurrentaddr(loc);
          if strlen(newaddr)>0 then begin
            loc.o:=strtoint('$'+newaddr);
            if dta.findseg(loc)<>nil then begin
              dio.savecuraddr;
              dio.setcuraddr(loc);
              scheduler.addtask(windowupdate,priority_window,nlptr,0,nil);
            end;
          end;
          result:=1; exit;
        end;
       IDCANCEL:
        begin
          EndDialog(hdwnd,0);
          result:=1; exit;
        end;
      end;
    end;
   WM_INITDIALOG:
    begin
      CenterWindow(hdwnd);
      SetFocus(GetDlgItem(hdwnd,IDC_JADDREDIT));
    end;
  end;
end;

{************************************************************************
* jumpto                                                                *
* - stops the thread and gets an address from the user to be jumped to  *
************************************************************************}
procedure jumpto;
begin
  scheduler.stopthread;
  DialogBox(Inst,MAKEINTRESOURCE(Jaddr_Editor),mainwindow,@getjaddrbox);
  scheduler.continuethread;
end;


{************************************************************************
* getcommentbox                                                         *
* - this is the small dialog box for getting a comment from the user.   *
* - it determines the current address, and obtains a comment, adding it *
*   to the database, and deleting any previous comment.                 *
************************************************************************}
function getcommentbox(hdwnd:HWND; msg,wParam,lParam:dword):dword;stdcall;
const
  loc:lptr=();
var
  titem:tdsmitem;
  tblock:pdsmitem;
  newcomment:pchar;
begin
  result:=0;
  case msg of
   WM_COMMAND:
     case wParam of
      IDOK:
       begin
         EndDialog(hdwnd,0);
         getmem(newcomment,80);
         SendDlgItemMessage(hdwnd,IDC_COMMENTEDIT,WM_GETTEXT,80,dword(newcomment));
         scheduler.addtask(user_delcomment,priority_userrequest,loc,0,nil);
         if strlen(newcomment)<>0 then
           scheduler.addtask(user_addcomment,priority_userrequest,loc,0,newcomment);
         result:=1; exit;
       end;
      IDCANCEL:
       begin
         EndDialog(hdwnd,0); result:=1; exit;
       end;
    end;
   WM_INITDIALOG:
    begin
      CenterWindow(hdwnd);
      // need to get any initial comments and stuff into edit box.
      dio.findcurrentaddr(loc);
      titem.addr:=loc;
      titem.typ :=dsmnull;
      dsm.findnext(listitem(@titem));
      tblock:=pdsmitem(dsm.nextiterator);
      if tblock<>nil then while eq(tblock.addr,loc) do begin
        if tblock.typ=dsmcomment then begin
          SendDlgItemMessage(hdwnd,IDC_COMMENTEDIT,WM_SETTEXT,0,dword(tblock.tptr));
          break;
        end;
        tblock:=pdsmitem(dsm.nextiterator);
        if tblock=nil then break;
      end;
      SetFocus(GetDlgItem(hdwnd,IDC_COMMENTEDIT));
    end;
  end;
end;

{************************************************************************
* getcomment                                                            *
* - stops the thread and gets a comment from the user to be added to    *
*   the disassembly database, and posts a windowupdate request.         *
************************************************************************}
procedure getcomment;
begin
  scheduler.stopthread;
  DialogBox(Inst,MAKEINTRESOURCE(Comment_Editor),mainwindow,@getcommentbox);
  scheduler.continuethread;
end;

begin
end.

