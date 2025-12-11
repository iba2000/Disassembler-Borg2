unit help;
interface
uses windows,shellapi,sysutils,common,menu;

function helpshortcuts(hdwnd,msg,wParam,lParam:dword):dword;stdcall;
function habox(hdwnd:HWND; msg,wParam,lParam:dword):dword;stdcall;
function helpbox1(hdwnd:hwnd; msg,wParam,lParam:longint):longint;stdcall;

implementation

{************************************************************************
* helpshortcuts                                                         *
* - the shortcuts help dialog box                                       *
* - simply a text summary of the shortcut keys in Borg                  *
************************************************************************}
function helpshortcuts(hdwnd,msg,wParam,lParam:dword):dword;
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
       SetFocus(GetDlgItem(hdwnd,IDOK));
     end;
  end;
end;

{************************************************************************
* habox                                                                 *
* - actually the 'Help -> About' dialog box                             *
************************************************************************}
function habox(hdwnd:HWND; msg,wParam,lParam:dword):dword;
begin
  result:=0;
  case msg of
   WM_COMMAND:
    case wParam of
     idc_email:
      begin
        ShellExecute(0,'open','mailto:cronos@ntlworld.com',nil,nil,SW_SHOWNORMAL);
        result:=1;
      end;
     idc_website:
      begin
        ShellExecute(0,'open','http://www.cronos.cc/',nil,nil,SW_SHOWNORMAL);
        result:=1;
      end;
     IDC_BUTTON1: EndDialog(hdwnd,0);
    end;
   WM_INITDIALOG:
    begin
      CenterWindow(hdwnd);
      SetFocus(GetDlgItem(hdwnd,IDC_BUTTON1));
    end;
  end;
end;

{************************************************************************
* helpbox1                                                              *
* - this is a file_open_options help box which gives a few helping      *
*   hints on the options available.                                     *
************************************************************************}
function helpbox1(hdwnd:hwnd; msg,wParam,lParam:longint):longint;
begin
  result:=0;
  case msg of
   WM_COMMAND:
    case wParam of
     IDOK: begin EndDialog(hdwnd,0); result:=1; end;
    end;
   WM_INITDIALOG: CenterWindow(hdwnd);
  end;
end;

begin
end.

