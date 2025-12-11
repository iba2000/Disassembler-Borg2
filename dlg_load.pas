//v2.28
unit dlg_load;
interface
uses windows,sysutils,commdlg,common,menu,exeload,proctab,help,disasm;
{************************************************************************
* Contains the dialog routines for the load file dialogboxes            *
************************************************************************}

function newfile:boolean;

var
  Thread:procedure;
  Changemenus:procedure;

implementation

{************************************************************************
* moreoptions                                                           *
* - advanced loading options                                            *
************************************************************************}
function moreoptions(hdwnd:hwnd; msg,wParam,lParam:longint):longint;stdcall;
const brush:HBRUSH=0;
begin
  result:=0;
  case msg of
   WM_COMMAND:
    case wParam of
     IDOK:
      begin
        options.codedetect:=0;
        if IsDlgButtonChecked(hdwnd,advanced_pushbp)    <>0 then options.codedetect:=options.codedetect or CD_PUSHBP;
        if IsDlgButtonChecked(hdwnd,advanced_aggressive)<>0 then options.codedetect:=options.codedetect or CD_AGGRESSIVE;
        if IsDlgButtonChecked(hdwnd,advanced_enter)     <>0 then options.codedetect:=options.codedetect or CD_ENTER;
        if IsDlgButtonChecked(hdwnd,advanced_movbx)     <>0 then options.codedetect:=options.codedetect or CD_MOVBX;
        if IsDlgButtonChecked(hdwnd,advanced_moveax)    <>0 then options.codedetect:=options.codedetect or CD_MOVEAX;
        if IsDlgButtonChecked(hdwnd,advanced_eaxfromesp)<>0 then options.codedetect:=options.codedetect or CD_EAXFROMESP;
        EndDialog(hdwnd,0);
        result:=1; exit;
      end;
     end;
   WM_INITDIALOG:
    begin
      brush:=CreateSolidBrush(GetSysColor(COLOR_BTNFACE));
      CheckDlgButton(hdwnd,advanced_pushbp,options.codedetect and CD_PUSHBP);
      CheckDlgButton(hdwnd,advanced_aggressive,options.codedetect and CD_AGGRESSIVE);
      CheckDlgButton(hdwnd,advanced_enter,options.codedetect and CD_ENTER);
      CheckDlgButton(hdwnd,advanced_movbx,options.codedetect and CD_MOVBX);
      CheckDlgButton(hdwnd,advanced_moveax,options.codedetect and CD_MOVEAX);
      CheckDlgButton(hdwnd,advanced_eaxfromesp,options.codedetect and CD_EAXFROMESP);
      exit;
    end;
   WM_DESTROY:
    begin
      DeleteObject(brush); exit;
    end;
   WM_CTLCOLORSTATIC,
   WM_CTLCOLORBTN,
   WM_CTLCOLORDLG,
   WM_SYSCOLORCHANGE:
    begin
      SetBkColor(HDC(wParam),GetSysColor(COLOR_BTNFACE));
      result:=brush; exit;
    end;
  end;
end;


{************************************************************************
* checktypebox                                                          *
* - after a file has been chosen to load and before the file is loaded  *
*   this is displayed for the user to set options for analysis, file    *
*   type, etc.                                                          *
************************************************************************}
function checktypebox(hdwnd:hwnd; msg,wParam,lParam:longint):longint;stdcall;
const brush:HBRUSH=0;
var
  segtext :array[0..200] of char;
  offstext:array[0..200] of char;
  i,exetype:integer;
begin
  result:=0;
  case msg of
   WM_INITDIALOG:
    begin
      brush:=CreateSolidBrush(GetSysColor(COLOR_BTNFACE));
      exetype:=floader.getexetype;
      options.loadaddr.s:=$1000;
      options.loadaddr.o:=$00;
      case exetype of
       NE_EXE:
        begin
          SetDlgItemText(hdwnd,IDC_DEFAULTBUTTON,'NE Executable');
          CheckDlgButton(hdwnd,IDC_DEFAULTBUTTON,1);
          options.processor:=PROC_80486; options.mode16:=TRUE;
        end;
       COM_EXE:
        begin
          SetDlgItemText(hdwnd,IDC_DEFAULTBUTTON,'COM File');
          CheckDlgButton(hdwnd,IDC_DEFAULTBUTTON,1);
          options.processor:=PROC_80386; options.mode16:=TRUE;
          options.loadaddr.o:=$100;
        end;
       SYS_EXE:
        begin
          SetDlgItemText(hdwnd,IDC_DEFAULTBUTTON,'SYS File');
          CheckDlgButton(hdwnd,IDC_DEFAULTBUTTON,1);
          options.processor:=PROC_80386; options.mode16:=TRUE;
          options.loadaddr.o:=$00;
        end;
       PE_EXE:
        begin
          SetDlgItemText(hdwnd,IDC_DEFAULTBUTTON,'PE Executable');
          CheckDlgButton(hdwnd,IDC_DEFAULTBUTTON,1);
          options.processor:=PROC_PENTIUM; options.mode16:=FALSE;
        end;
       OS2_EXE:
        begin
          SetDlgItemText(hdwnd,IDC_DEFAULTBUTTON,'OS2 Executable');
          CheckDlgButton(hdwnd,IDC_DEFAULTBUTTON,1);
          options.processor:=PROC_PENTIUM; options.mode16:=FALSE;
        end;
       LE_EXE:
        begin
          SetDlgItemText(hdwnd,IDC_DEFAULTBUTTON,'LE Executable');
          CheckDlgButton(hdwnd,IDC_DEFAULTBUTTON,1);
          options.processor:=PROC_80486; options.mode16:=FALSE;
        end;
       MZ_EXE:
        begin
          SetDlgItemText(hdwnd,IDC_DEFAULTBUTTON,'COM File');
          CheckDlgButton(hdwnd,IDC_DOSBUTTON,1);
          options.processor:=PROC_80386; options.mode16:=TRUE;
        end;
       else  // BIN_EXE:
        SetDlgItemText(hdwnd,IDC_DEFAULTBUTTON,'COM File');
        CheckDlgButton(hdwnd,IDC_BINBUTTON,1);
        options.processor:=PROC_8086; options.mode16:=TRUE;
      end;
      options.mode32:=not options.mode16;
      CheckDlgButton(hdwnd,load_debug,ord(options.loaddebug));
      CheckDlgButton(hdwnd,demangle_names,ord(options.demangle));
      CheckDlgButton(hdwnd,IDC_16DASM,ord(options.mode16));
      CheckDlgButton(hdwnd,IDC_32DASM,ord(options.mode32));
      CheckDlgButton(hdwnd,IDC_LOADDATA,ord(options.loaddata));
      CheckDlgButton(hdwnd,IDC_LOADRESOURCES,ord(options.loadresources));
      i:=0;
      while procnames[i].num<>0 do begin
        SendDlgItemMessage(hdwnd,IDC_LISTBOX1,LB_ADDSTRING,0,dword(@procnames[i].nam^));
        if options.processor=procnames[i].num then
          SendDlgItemMessage(hdwnd,IDC_LISTBOX1,LB_SETCURSEL,i,0);
        inc(i);
      end;
      strlfmt(@segtext,200,fmt4,[options.loadaddr.s]);
      strlfmt(@offstext,200,fmt8,[options.loadaddr.o]);
      SendDlgItemMessage(hdwnd,IDC_SEGEDIT,WM_SETTEXT,0,dword(@segtext));
      SendDlgItemMessage(hdwnd,IDC_OFFSEDIT,WM_SETTEXT,0,dword(@offstext));
      result:=1; exit;
    end;
   WM_DESTROY:
    begin
      DeleteObject(brush); exit;
    end;
   WM_CTLCOLORSTATIC,
   WM_CTLCOLORDLG,
   WM_CTLCOLORBTN,
   WM_SYSCOLORCHANGE:
    begin
      SetBkColor(HDC(wParam),GetSysColor(COLOR_BTNFACE));
      result:=brush; exit;
    end;
   WM_COMMAND:
    begin
      case LOWORD(wParam) of
       IDOK:
        begin
          if IsDlgButtonChecked(hdwnd,IDC_DEFAULTBUTTON)=0 then begin
            if IsDlgButtonChecked(hdwnd,IDC_DOSBUTTON)<>0 then floader.setexetype(MZ_EXE)
            else floader.setexetype(BIN_EXE);
          end else
            if (exetype=BIN_EXE)or(exetype=MZ_EXE) then floader.setexetype(COM_EXE);
          options.processor:=procnames[SendDlgItemMessage(hdwnd,IDC_LISTBOX1,LB_GETCURSEL,0,0)].num;
          EndDialog(hdwnd,0);
          result:=1; exit;
        end;
       IDC_SEGEDIT:
        begin
          if HIWORD(wParam)=EN_CHANGE then begin
            fillchar(segtext,sizeof(segtext),0);
            SendDlgItemMessage(hdwnd,IDC_SEGEDIT,WM_GETTEXT,18,dword(@segtext));
            options.loadaddr.s:=strtoint('$'+strpas(segtext));
          end;
          result:=1; exit;
        end;
       IDC_OFFSEDIT:
        begin
          if HIWORD(wParam)=EN_CHANGE then begin
            fillchar(offstext,sizeof(offstext),0);
            SendDlgItemMessage(hdwnd,IDC_OFFSEDIT,WM_GETTEXT,18,dword(@offstext));
            options.loadaddr.o:=strtoint('$'+strpas(offstext));
          end;
          result:=1; exit;
        end;
       IDC_HELPBUTTON1:
        begin
          DialogBox(Inst,MAKEINTRESOURCE(HELPDIALOG_1),hdwnd,@helpbox1);
          result:=1; exit;
        end;
       more_options:
        begin
          DialogBox(Inst,MAKEINTRESOURCE(Advanced_Options),hdwnd,@moreoptions);
          result:=1; exit;
        end;
       load_debug:
        begin
          options.loaddebug:=not options.loaddebug;
          CheckDlgButton(hdwnd,load_debug,ord(options.loaddebug));
          result:=1; exit;
        end;
       demangle_names:
        begin
          options.demangle:=not options.demangle;
          CheckDlgButton(hdwnd,demangle_names,ord(options.demangle));
          result:=1; exit;
        end;
       IDC_16DASM:
        begin
          options.mode16:=not options.mode16;
          CheckDlgButton(hdwnd,IDC_16DASM,ord(options.mode16));
          result:=1; exit;
        end;
       IDC_32DASM:
        begin
          options.mode32:=not options.mode32;
          CheckDlgButton(hdwnd,IDC_32DASM,ord(options.mode32));
          result:=1; exit;
        end;
       IDC_LOADDATA:
        begin
          options.loaddata:=not options.loaddata;
          CheckDlgButton(hdwnd,IDC_LOADDATA,ord(options.loaddata));
          result:=1; exit;
        end;
       IDC_LOADRESOURCES:
        begin
          options.loadresources:=not options.loadresources;
          CheckDlgButton(hdwnd,IDC_LOADRESOURCES,ord(options.loadresources));
          result:=1; exit;
        end;
      end;
    end;
  end;
end;

{************************************************************************
* loadexefile                                                           *
* - checks file header info, identifies the possible types of files,    *
*   gets the users file loading options and calls the specific exe      *
*   format loading routines.                                            *
************************************************************************}
function loadexefile(fname:pchar):boolean;
var
  mzhead :array[0..2] of char;
  exthead:array[0..2] of char;
  pe_offset:dword;
  num:long;
  fsize:dword;
begin
  result:=false;
  if floader.efile<>INVALID_HANDLE_VALUE then exit;
  // just grab the file size first
  floader.efile:=CreateFile(fname,GENERIC_READ,1,nil,OPEN_EXISTING,0,0);
  fsize:=GetFileSize(floader.efile,nil);
  CloseHandle(floader.efile);
  if fsize=0 then begin
    MessageBox(mainwindow,'File appears to be of zero length ?','Borg Message',MB_OK); exit;
  end;
  floader.efile:=CreateFile(fname,GENERIC_READ or GENERIC_WRITE,1,nil,OPEN_EXISTING,0,0);
  if floader.efile=INVALID_HANDLE_VALUE then exit;
  if SysfileIsDevice_(floader.efile)<>FILE_TYPE_DISK  then exit;
  floader.exetype:=BIN_EXE;
  if ReadFile(floader.efile,mzhead,2,num,nil) then begin
    if (num=2) and (((mzhead[0]='M')and(mzhead[1]='Z')) or ((mzhead[0]='Z')and(mzhead[1]='M'))) then begin
      SetFilePointer(floader.efile,$3c,nil,FILE_BEGIN);
      if ReadFile(floader.efile,pe_offset,4,num,nil) then
        SetFilePointer(floader.efile,pe_offset,nil,FILE_BEGIN);
      if ReadFile(floader.efile,exthead,2,num,nil) then begin
        if      pw(@exthead[0])^=$4550 then floader.exetype:=PE_EXE
        else if pw(@exthead[0])^=$454e then floader.exetype:=NE_EXE
        else if pw(@exthead[0])^=$454c then floader.exetype:=LE_EXE
        else if pw(@exthead[0])^=$584c then floader.exetype:=OS2_EXE
        else floader.exetype:=MZ_EXE;
      end;
    end else begin
      if strlen(fname)>3 then begin
        if lstrcmpi(fname+strlen(fname)-3,'com')=0 then begin
          SetFilePointer(floader.efile,0,nil,FILE_BEGIN);
          floader.exetype:=COM_EXE;
        end else if lstrcmpi(fname+strlen(fname)-3,'sys')=0 then begin
          SetFilePointer(floader.efile,0,nil,FILE_BEGIN);
          floader.exetype:=SYS_EXE;
        end;
      end;
    end;
  end;
  getmem(floader.fbuff,fsize);
  SetFilePointer(floader.efile,0,nil,FILE_BEGIN);
  ReadFile(floader.efile,floader.fbuff^,fsize,num,nil);
  DialogBox(Inst,MAKEINTRESOURCE(D_checktype),mainwindow,@checktypebox);
  if options.loadaddr.s=0 then begin
    options.loadaddr.s:=$1000;
    MessageBox(mainwindow,'Sorry - Can''''t use a zero segment base.\nSegment Base has been set to 0x1000'
     ,'Borg Message',MB_OK);
  end;
  dsm.dissettable;
  case floader.exetype of
   BIN_EXE:     floader.readbinfile(fsize);
   PE_EXE:      floader.readpefile(pe_offset);
   MZ_EXE:      floader.readmzfile(fsize);
   OS2_EXE:
    begin
      floader.reados2file;
      CloseHandle(floader.efile);
      floader.efile:=dword(INVALID_HANDLE_VALUE);
      floader.exetype:=0;
      exit; // at the moment;
    end;
   COM_EXE:    floader.readcomfile(fsize);
   SYS_EXE:    floader.readsysfile(fsize);
   LE_EXE:
    begin
      floader.readlefile;
      CloseHandle(floader.efile);
      floader.efile:=dword(INVALID_HANDLE_VALUE);
      floader.exetype:=0;
      exit; // at the moment;
    end;
   NE_EXE:     floader.readnefile(pe_offset);
   else
     CloseHandle(floader.efile);
     floader.efile:=dword(INVALID_HANDLE_VALUE);
     floader.exetype:=0;
     exit;
  end;
  result:=true;
end;

{************************************************************************
* newfile                                                               *
* - handles selecting a new file and its messages, using the standard   *
*   routine GetOpenFileName                                             *
* - starts up the secondary thread when the file is loaded              *
************************************************************************}
function newfile:boolean;
begin
  // factor of 2 added for nt unicode
  getfiletoload(current_exe_name);
  if current_exe_name[0]<>#0 then begin
    if loadexefile(current_exe_name) then begin
      StatusMessage('File Opened'); strcat(@winname,' : ');
      strcat(@winname,current_exe_name);
      SetWindowText(mainwindow,@winname);
      InThread:=true;
      ThreadHandle:=CreateThread(nil,0,@Thread,nil,0,ThreadId);
      Changemenus;
    end else MessageBox(mainwindow,'File open failed ?',program_name,MB_OK or MB_ICONEXCLAMATION);
  end;
  result:=false;
end;


begin
end.

