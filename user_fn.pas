unit user_fn;
interface
uses windows,sysutils,commdlg,common,menu,schedule,range,decrypt;
{************************************************************************
* - the functions here are various user dialogs and directly callable   *
*   routines, these are all primary thread routines                     *
* - Extracted from various classes v2.22                                *
************************************************************************}

function Choosecolour(cr:COLORREF):COLORREF;
procedure decrypterdialog;
function shutbox(hdwnd:HWND; msg,wParam,lParam:dword):dword;stdcall;


implementation

{************************************************************************
* global variables                                                      *
* - save state of decryption dialog, etc.....                           *
************************************************************************}
const
  lastdec   :dectype=decxor;
  lastditem :ditemtype=decbyte;
  patchexe  :boolean=false;
  lastvalue :array[0..20] of char=#0;
  last_seg  :array[0..20] of char=#0;
  lastoffset:array[0..20] of char=#0;

{************************************************************************
* shutbox                                                               *
* - this is a shutdown warning box if Borg is having difficulty         *
*   quitting. It just puts up a 'shutting down' message for a couple of *
*   seconds                                                             *
************************************************************************}
function shutbox(hdwnd:HWND; msg,wParam,lParam:dword):dword;
begin
  result:=0;
end;

{************************************************************************
* choosecolour                                                          *
* - a small dialog box for colour choice (standard dialog) when setting *
*   background or text colours                                          *
************************************************************************}
function Choosecolour(cr:COLORREF):COLORREF;
var
  cc:tCHOOSECOLOR;
  crCustColors:array[0..15] of COLORREF;
begin
  cc.lStructSize:=sizeof(tCHOOSECOLOR);
  cc.hwndOwner:=mainwindow;
  cc.hInstance:=0;
  cc.rgbResult:=cr;
  cc.lpCustColors:=@crCustColors;
  cc.Flags:=CC_RGBINIT or CC_FULLOPEN;
  cc.lCustData:=0;
  cc.lpfnHook:=nil;
  cc.lpTemplateName:=nil;
  if ChooseColor(cc) then result:=cc.rgbResult else result:=cr;
end;

{************************************************************************
* decbox                                                                *
* - the decryptor dialog, it only allows patching if the file is not    *
*   readonly, and adds the decryptor to the list and calls the process  *
*   and patch functions.                                                *
************************************************************************}
function decbox(hdwnd:HWND; msg,wParam,lParam:dword):dword;stdcall;
var
  dec_id:dword;
  d_val:dword;
  d_adr:lptr;
begin
  result:=0;
  case msg of
   WM_COMMAND:
    case wParam of
     IDOK:
      begin
        if SendDlgItemMessage(hdwnd,idc_xor,BM_GETCHECK,0,0)<>0 then lastdec:=decxor else
        if SendDlgItemMessage(hdwnd,idc_mul,BM_GETCHECK,0,0)<>0 then lastdec:=decmul;
        if SendDlgItemMessage(hdwnd,idc_add,BM_GETCHECK,0,0)<>0 then lastdec:=decadd else
        if SendDlgItemMessage(hdwnd,idc_sub,BM_GETCHECK,0,0)<>0 then lastdec:=decsub else
        if SendDlgItemMessage(hdwnd,idc_rot,BM_GETCHECK,0,0)<>0 then lastdec:=decrot else
        if SendDlgItemMessage(hdwnd,idc_xadd,BM_GETCHECK,0,0)<>0 then lastdec:=decxadd
        else lastdec:=decnull;
        if SendDlgItemMessage(hdwnd,idc_byte,BM_GETCHECK,0,0)<>0 then lastditem:=decbyte else
        if SendDlgItemMessage(hdwnd,idc_word,BM_GETCHECK,0,0)<>0 then lastditem:=decword else
        if SendDlgItemMessage(hdwnd,idc_dword,BM_GETCHECK,0,0)<>0 then lastditem:=decdword else
        if SendDlgItemMessage(hdwnd,idc_array,BM_GETCHECK,0,0)<>0 then lastditem:=decarray
        else lastditem:=decbyte;
        SendDlgItemMessage(hdwnd,idc_value,WM_GETTEXT,18,dword(@lastvalue));
        SendDlgItemMessage(hdwnd,idc_arrayseg,WM_GETTEXT,18,dword(@last_seg));
        SendDlgItemMessage(hdwnd,idc_arrayoffset,WM_GETTEXT,18,dword(@lastoffset));
        if IsDlgButtonChecked(hdwnd,idc_applytoexe)<>0 then patchexe:=TRUE
        else patchexe:=FALSE;
{$IFDEF VIRTUALPASCAL}
        wvsprintf(lastvalue,'%lx',d_val);
        wvsprintf(last_seg,'%lx',d_adr.s);
        wvsprintf(lastoffset,'%lx',d_adr.o);
{$ELSE}
        wvsprintf(lastvalue,'%lx',@d_val);
        wvsprintf(last_seg,'%lx',@d_adr.s);
        wvsprintf(lastoffset,'%lx',@d_adr.o);
{$ENDIF}
        patchexe:=false;
        MessageBox(mainwindow,'File opened readonly - unable to patch','Borg Message',MB_OK);
        dec_id:=decrypter.add_decrypted(blk.top,blk.bottom,lastdec,lastditem,d_val,d_adr,patchexe);
        decrypter.process_dec(dec_id);
        if patchexe then decrypter.exepatch(dec_id);
        EndDialog(hdwnd,0);
        result:=1;
      end;
     IDCANCEL: begin EndDialog(hdwnd,0); result:=1; exit; end;
    end;
   WM_INITDIALOG:
    begin
      CenterWindow(hdwnd);
      case lastdec of
       decxor: SendDlgItemMessage(hdwnd,idc_xor,BM_SETCHECK,1,0);
       decmul: SendDlgItemMessage(hdwnd,idc_mul,BM_SETCHECK,1,0);
       decadd: SendDlgItemMessage(hdwnd,idc_add,BM_SETCHECK,1,0);
       decsub: SendDlgItemMessage(hdwnd,idc_sub,BM_SETCHECK,1,0);
       decrot: SendDlgItemMessage(hdwnd,idc_rot,BM_SETCHECK,1,0);
       decxadd:SendDlgItemMessage(hdwnd,idc_xadd,BM_SETCHECK,1,0);
       else    SendDlgItemMessage(hdwnd,idc_xor,BM_SETCHECK,1,0);
      end;
      case lastditem of
       decbyte: SendDlgItemMessage(hdwnd,idc_byte,BM_SETCHECK,1,0);
       decword: SendDlgItemMessage(hdwnd,idc_word,BM_SETCHECK,1,0);
       decdword:SendDlgItemMessage(hdwnd,idc_dword,BM_SETCHECK,1,0);
       decarray:SendDlgItemMessage(hdwnd,idc_array,BM_SETCHECK,1,0);
       else     SendDlgItemMessage(hdwnd,idc_byte,BM_SETCHECK,1,0);
      end;
      SendDlgItemMessage(hdwnd,idc_value,WM_SETTEXT,0,dword(@lastvalue));
      SendDlgItemMessage(hdwnd,idc_arrayseg,WM_SETTEXT,0,dword(@last_seg));
      SendDlgItemMessage(hdwnd,idc_arrayoffset,WM_SETTEXT,0,dword(@lastoffset));
      CheckDlgButton(hdwnd,idc_applytoexe,dword(patchexe));
      SetFocus(GetDlgItem(hdwnd,idc_value));
    end;
  end;
end;

{************************************************************************
* decrypterdialog                                                         *
* - we stop the thread whilst displaying the decryptor dialog and doing *
*   the patch                                                           *
************************************************************************}
procedure decrypterdialog;
begin
  scheduler.stopthread;
  if not blk.checkblock then exit;
  DialogBox(Inst,MAKEINTRESOURCE(Decrypt_Dialog),mainwindow,@decbox);
  scheduler.continuethread;
end;

begin
end.

