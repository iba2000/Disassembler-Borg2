unit common;
interface
uses classes,sysutils,windows,commdlg,menu;

//remove comment on line below for debug mode.
//{$DEFINE DEBUG}
// warning - debug files can get big quickly. I only use them for
// hard to find bugs.
procedure DebugMessage(szFormat:pchar; a:array of const);
procedure CenterWindow(hdwnd:HWND);
procedure demangle(var nme:pchar);
procedure getfiletoload(fname:pchar);
procedure getfiletosave(fname:pchar);
procedure init_ofn(var ofn:tOPENFILENAME);

// keep enums at byte size!
type
  booln=boolean; //to easy change between byte/dword
  long=dword;
  dword=cardinal;
  pfloat =^single;
  pdouble=^double;
  ptr=pointer;
  pd=^dword;
  pw=^word;
  pda=^tda;
  pwa=^twa;
  tda=array[0..1] of dword;
  twa=array[0..1] of word;

function CreateStatusWindow(Style:Longint; lpszText:PChar; hwndParent:HWND; wID:UINT):HWND; stdcall;

const
  BORG_VER       = 228;
  program_name:pchar='Borg Disassembler';
  CCS_BOTTOM     = $00000003;
  CALLSTACKSIZE  = 100;
  BYTEPOS        = 14;
  ASMPOS         = 31;
  ARGPOS         = 38;
  COMMENTPOS     = 50;
  COMMENT_MAXLEN = 100;

  wm_User     = $0400;
  SB_SETTEXT  = WM_USER+1;
  WM_MAXITOUT = WM_USER+100;
  WM_REPEATNAMEVIEW =WM_USER+101;
  WM_REPEATXREFVIEW =WM_USER+102;
  WM_CREATE           = $0001;
  WM_DESTROY          = $0002;
  WM_SIZE             = $0005;
  WM_SETTEXT          = $000C;
  WM_GETTEXT          = $000D;
  WM_PAINT            = $000F;
  WM_CLOSE            = $0010;
  WM_SYSCOLORCHANGE   = $0015;
  BM_GETCHECK         = $00F0;
  BM_SETCHECK         = $00F1;
  WM_INITDIALOG       = $0110;
  WM_COMMAND          = $0111;
  WM_CTLCOLORBTN      = $0135;
  WM_CTLCOLORDLG      = $0136;
  WM_CTLCOLORSTATIC   = $0138;
  WM_KEYDOWN          = $0100;
  WM_CHAR             = $0102;
  WM_HSCROLL          = $0114;
  WM_VSCROLL          = $0115;
  LB_DELETESTRING     = $0182;
  WM_LBUTTONDOWN      = $0201;
  WM_RBUTTONDOWN      = $0204;
  EN_CHANGE           = $0300;
  LBN_SELCHANGE       = 1;
  LB_ADDSTRING        = $0180;
  LB_GETCURSEL        = $0188;
  LB_SETCURSEL        = $0186;

  CD_PUSHBP      = 1;
  CD_ENTER       = 2;
  CD_MOVBX       = 4;
  CD_AGGRESSIVE  = 8;
  CD_EAXFROMESP  = 16;
  CD_MOVEAX      = 32;
  VERTSCROLLRANGE= 16000;

  function fixbool(b:bool):bool;
  procedure ProcessMessages_;
  function LoCase(ch:Char):Char;
  function SysFileIsDevice_(Handle:dword):dword;
  function ofsp(o:dword):pointer;
  function isprint(c:char):boolean;
  procedure cleanstring(str:pchar);
  procedure InitCommonControls;
  procedure StatusMessage(msg:pchar);

type
  dsmitemtype =(dsmnull,dsmsegheader,dsm2,dsm3,dsm4,dsmxref,dsmcomment,dsmnameloc,dsmcode);
  byteoverride=(over_null,over_decimal,over_char,over_dsoffset,over_single);
  segtype     =(codenull,code16,code32,data16,data32,uninitdata,debugdata,resourcedata);

  plptr=^lptr;
  lptr=packed record
    s:dword;
    o:dword;
  end;

  fontselection=(nul,ansifont,systemfont,courierfont,courierfont10,courierfont12);

  tglobaloptions=packed record // 9*1+1+14+3*4
    loaddebug    :booln;
    mode16       :booln;
    mode32       :booln;
    loaddata     :booln;
    loadresources:booln;
    demangle     :booln;
    cfa          :booln;
    processor    :dword;
    _fill1       :byte;
    loadaddr     :lptr;
    oep          :lptr;
    dseg         :word;
    codedetect   :word;
    bgcolor      :COLORREF;
    textcolor    :COLORREF;
    highcolor    :COLORREF;
    font         :dword; //2016 fontselection;
    readonly     :booln;
    winmax       :booln;
    _fill2       :word;
  end;

  pdsmitem=^tdsmitem;
  tdsmitem=packed record
    addr:lptr;
    tptr:pointer;                   // string pointer for comment
    flags:dword;
    data:pchar;                     // data ptr
    length:word;
    typ:dsmitemtype;
    modrm:byte;                     // length, offset to  modrm byte
    mode32:booln;
    overrid:byteoverride;
    displayflags:byte;
  end;

  pdsmitemsave=^tdsmitemsave;
  tdsmitemsave=packed record
    addr:lptr;
    tptroffset:dword;
    typ:dsmitemtype;
    length:word;
    modrm:byte;
    mode32:booln;
    fileoffset:dword;
    overrid:byteoverride;
    flags:dword;
    displayflags:byte;
  end;

const
  UseCompression:boolean=true;
  nlptr:lptr=(s:0;o:0);
  cf:HFONT=0;
  lastline:dword=0;

const
  buffer_lines   =60;
  max_length     =200;
  max_stringprint=max_length-60;

var
  ThreadId    :long;
  threadhandle:dword;
  InThread    :boolean;
  KillThread  :boolean;
  BufferReady :boolean;

var
  current_exe_name:array[0..MAX_PATH*2] of char;
  log:textfile;
  Inst:dword;
  mainwindow:hwnd;
  hwndStatusBar:dword;
  mainwnd:trect;
  Options:tglobaloptions;
  cs:TRTLCriticalSection;
  winname:array[0..300] of char;
  szFile :array[0..260] of char;
  MainBuff:array[0..buffer_lines*max_length+1000] of char;

  function between(loc,lwb,upb:lptr; o:integer):boolean;
  function add_(l1:plptr; offs2:dword):dword;
  function sub_(l1:plptr; offs2:dword):dword;
  function plus(l1:plptr; offs2:dword):dword;
  function minus(l1:plptr; offs2:dword):dword;
  function eq(l1,loc2:lptr):boolean;
  function neq(l1,loc2:lptr):boolean;
  function leeq(l1,loc2:lptr):boolean;
  function greq(l1,loc2:lptr):boolean;
  function le(l1,loc2:lptr):boolean;
  function gr(l1,loc2:lptr):boolean;

const
  hdr:pchar=';             Created by Borg Disassembler'#13#10+
            ';                   written by Cronos';

implementation

function strnicmp(a,b:pchar;n:integer):boolean;
var i:integer;
begin
  result:=true; if (a=nil) or (b=nil) then exit;
  for i:=0 to n-1 do begin
    if (a[i]=#0) or (b[i]=#0) then exit;
    if upcase(a[i])<>upcase(b[i]) then exit;
  end; result:=false;
end;

{************************************************************************
* between                                                               *
* - returns true if loc >= lwb and loc <= upb                           *
************************************************************************}
function between(loc,lwb,upb:lptr; o:integer):boolean;
var t:lptr;
begin
  t:=upb; inc(t.o,o);
  result:= greq(loc,lwb) and leeq(loc,t);
end;

function  add_(l1:plptr; offs2:dword):dword;
begin inc(l1.o,offs2); result:=l1.o; end;

function  sub_(l1:plptr; offs2:dword):dword;
begin dec(l1.o,offs2); result:=l1.o; end;

function  plus(l1:plptr; offs2:dword):dword;
begin result:=l1.o+offs2; end;

function  minus(l1:plptr; offs2:dword):dword;
begin result:=l1.o-offs2; end;

function eq(l1,loc2:lptr):boolean;
begin result:=(l1.s=loc2.s)and(l1.o=loc2.o); end;

function neq(l1,loc2:lptr):boolean;
begin result:=(l1.s<>loc2.s)or(l1.o<>loc2.o); end;

function leeq(l1,loc2:lptr):boolean;
begin if(l1.s<>loc2.s) then result:=(l1.s<=loc2.s) else result:=(l1.o<=loc2.o); end;

function greq(l1,loc2:lptr):boolean;
begin if(l1.s<>loc2.s) then result:=(l1.s>=loc2.s) else result:=(l1.o>=loc2.o); end;

function le(l1,loc2:lptr):boolean;
begin if(l1.s<>loc2.s) then result:=(l1.s<loc2.s) else result:=(l1.o<loc2.o); end;

function gr(l1,loc2:lptr):boolean;
begin if(l1.s<>loc2.s) then result:=(l1.s>loc2.s) else result:=(l1.o>loc2.o); end;


function isprint(c:char):boolean;
begin
  result:=c in['A'..'Z','a'..'z','0'..'9','+','-','=','_','!',
    '@','$','%','^','&','*','(',')','[',']','{','}','''',' ',
    '#','/','<','>','|','\','"','.',',',';',':','`','?','~'];
end;

function isalnum(c:char):boolean;
begin
  result:=c in['A'..'Z','a'..'z','0'..'9','_'];
end;

procedure cleanstring(str:pchar);
var i:integer;
begin
  for i:=0 to strlen(str)-1 do if not isalnum(str[i]) then str[i]:='_';
end;

function ofsp(o:dword):pointer;
begin
  result:=pointer(o);
end;

function CreateStatusWindow(Style:Longint; lpszText:PChar; hwndParent:HWND; wID:UINT):HWND;
 external 'comctl32.dll' name 'CreateStatusWindowA';

procedure InitCommonControls;
external 'comctl32.dll' name 'InitCommonControls';

function SysFileIsDevice_(Handle:dword):dword;
begin
  result := GetFileType(Handle);
{$IFDEF VIRTUALPASCAL}
  case result of
  0,1 : Result := 0; // File;
    2 : Result := 1; // Device
    3 : Result := 2; // Pipe
  end;
{$ENDIF}
end;

function LoCase(ch:Char):Char;
asm
        CMP     AL,'A'
        JB      @@exit
        CMP     AL,'Z'
        JA      @@exit
        add     AL,'a' - 'A'
@@exit:
end;

procedure ProcessMessages_;
var Msg :TMsg;
begin
  while PeekMessage(Msg,0,0,0,PM_REMOVE) do begin
    TranslateMessage(Msg); DispatchMessage(Msg);
    break;
  end;
end;

function fixbool(b:bool):bool;
begin
  dword(result):=dword(b) and 1;
end;

procedure DebugMessage(szFormat:pchar; a:array of const);
var
  DebugBuff:array[0..200] of char;
  efile:textfile;
begin
  strfmt(DebugBuff,szFormat,a);
  assignfile(efile,'c:\debug.txt'); {$I-}append(efile);{$I+}
  if ioresult<>0 then {$I-}rewrite(efile);{$I+}
  if ioresult<>0 then begin
    MessageBox(mainwindow,'Debug File Creation Failed','Borg Disassembler Alert',MB_OK); exit;
  end;
  writeln(efile,DebugBuff,strlen(DebugBuff));
  closefile(efile);
end;

{************************************************************************
* CenterWindow                                                          *
* - centers a window within its client area, used by Dialog functions   *
************************************************************************}
procedure CenterWindow(hdwnd:HWND);
var
  drect,prect:tRECT;
  parent:HWND;
begin
  parent:=GetParent(hdwnd);
  GetWindowRect(parent,prect);
  GetWindowRect(hdwnd,drect);
  MoveWindow(hdwnd,((prect.right+prect.left)-(drect.right-drect.left)) div 2,
   ((prect.bottom+prect.top)-(drect.bottom-drect.top)) div 2,drect.right-drect.left,
    drect.bottom-drect.top,true);
end;

{************************************************************************
* demangle                                                              *
* - this is a general string function. Name damangling is currently not *
*   very good, and I have some old Borland source code which could      *
*   improve this greatly......... just need to dig it out, rework it    *
*   for Borg, and put it in here now......                              *
************************************************************************}
procedure demangle(var nme:pchar);
var
  buff,buff2:array[0..255] of char;
  nam:pchar;
  namelen,i,j,k,atcount,bpoint:dword;
  brac,pointer,rpointer:boolean;
begin
  if not options.demangle then exit;
  atcount:=0; i:=0; j:=0; bpoint:=0; brac:=false;
  nam:=nme;
  while nam[i]<>#0 do begin
    if nam[i]='@' then begin
      inc(atcount);
      if atcount>1 then begin
        buff[j]:=':'; inc(j);
        buff[j]:=':'; inc(j);
      end;
    end else if (nam[i]='$')and(nam[i+1]='q')and(not brac) then begin
      brac:=true;
      bpoint:=j;
      buff[j]:='('; inc(j);
      inc(i,1);
    end else if (nam[i]='$')and(nam[i+1]='x')and(nam[i+2]='q')and(not brac) then begin
      brac:=true;
      bpoint:=j;
      buff[j]:='('; inc(j);
      inc(i,2);
    end else if not strnicmp(@nam[i],'$bctr',5) then begin
      k:=0;
      while (buff[k]<>':')and(k<20) do begin
        buff[j]:=buff[k]; inc(j);  inc(k);
      end;
      inc(i,4);
    end else if not strnicmp(@nam[i],'$bdtr',5) then begin
      k:=0;
      buff[j]:='~'; inc(j);
      while (buff[k]<>':')and(k<20) do begin
        buff[j]:=buff[k]; inc(j); inc(k);
      end;
      inc(i,4);
    end else if not strnicmp(@nam[i],'$bdla',5) then begin
      strcopy(@buff[j],'delete'); inc(j,6);
      inc(i,4);
    end else if not strnicmp(@nam[i],'$bnwa',5) then begin
      strcopy(@buff[j],'new'); inc(j,3);
      inc(i,4);
    end else if not strnicmp(@nam[i],'$bdele',6) then begin
      strcopy(@buff[j],'delete'); inc(j,6);
      inc(i,5);
    end else if not strnicmp(@nam[i],'$bnew',5) then begin
      strcopy(@buff[j],'new'); inc(j,5);
      inc(i,4);
    end else begin buff[j]:=nam[i]; inc(j); end;
    inc(i);
  end;
  if brac then begin buff[j]:=')'; inc(j); end;
  buff[j]:=#0;
  strcopy(buff2,buff);
  if brac then begin
    i:=0; j:=bpoint; k:=bpoint;
    pointer:=false; rpointer:=false;
    while buff[j]<>#0 do begin
      if (buff[j]='p')and(i=0) then begin
        pointer:=true; inc(j);
      end;
      if (buff[j]='r')and(i=0) then begin
        rpointer:=true; inc(j);
      end else if (buff[j]='i')and(i=0) then begin
        i:=1; strcopy(@buff2[k],'int'); inc(k,3); inc(j,1);
      end else if (buff[j]='c')and(i=0) then begin
        i:=1; strcopy(@buff2[k],'char'); inc(k,4); inc(j,1);
      end else if (buff[j]='v')and(i=0) then begin
        i:=1; strcopy(@buff2[k],'void'); inc(k,4); inc(j,1);
      end else if (buff[j]='l')and(i=0) then begin
        i:=1; strcopy(@buff2[k],'long'); inc(k,4); inc(j,1);
      end else if (buff[j]='u')and(buff[j+1]='i')and(i=0) then begin
        i:=1; strcopy(@buff2[k],'uint'); inc(k,4); inc(j,2);
      end else if (buff[j]=':')and(buff[j+1]=':')and(i=0) then begin
        strcopy(@buff2[k],'::'); inc(k,2); inc(j,2);
      end else if (buff[j]='t')and((buff[j+1]>='0')and(buff[j+1]<='9'))and(i=0) then begin
        buff2[k]:=buff[j]; inc(k); inc(j);
        buff2[k]:=buff[j]; inc(k); inc(j);
        i:=1;
      end else if ((buff[j]>='0')and(buff[j]<='9'))and(i=0) then begin
        i:=byte(buff[j])-byte('0');
        inc(j);
        if (buff[j]>='0')and(buff[j]<='9') then begin
          i:=i*10+byte(buff[j])-byte('0'); inc(j);
        end;
        inc(i);
      end else begin buff2[k]:=buff[j]; inc(k); inc(j); end;
      if i<>0 then begin
        dec(i);
        if i=0 then begin
          if (pointer)and(buff2[k-1]<>')')  then begin buff2[k]:='*'; inc(k) end;
          if (rpointer)and(buff2[k-1]<>')') then begin buff2[k]:='&'; inc(k) end;
          if (buff[j]<>')')and(buff2[k-1]<>')') then begin buff2[k]:=','; inc(k) end;
          pointer:=false;
          rpointer:=false;
        end;
      end;
    end;
    buff2[k]:=#0;
  end;
  namelen:=strlen(buff2);
  //BugFix Build 15 nme-> *nme.
  freemem(nme);
  getmem(nam,namelen+1);
  strcopy(nam,buff2);
  nme:=nam;
end;

procedure StatusMessage(msg:pchar);
begin
  PostMessage(hwndStatusBar,SB_SETTEXT,0,dword(@msg^));
end;

{************************************************************************
* init_ofn                                                              *
* - initialises the OPENFILENAME struct used in calls to common dialogs *
*   callers can then change options further as needed                   *
************************************************************************}
procedure init_ofn(var ofn:tOPENFILENAME);
const
  szDirName  :array[0..MAX_PATH*2] of char=#0;
  szFilesave :array[0..260*2] of char=#0;
  szFileTitle:array[0..260*2] of char=#0;
  szFilter   :array[0..260]   of char=#0;
var
  cbString,i:integer;
  chReplace:char;
begin
  fillchar(ofn,sizeof(tOPENFILENAME),0);
  GetCurrentDirectory(MAX_PATH,szDirName);
  szFilesave[0]:=#0;
  cbString:=LoadString(Inst,IDS_FILTERSTRING,szFilter,sizeof(szFilter));
  chReplace:=szFilter[cbString-1];
  for i:=0 to cbString-1 do if szFilter[i]=chReplace then szFilter[i]:=#0;
  ofn.lStructSize:=sizeof(tOPENFILENAME);
  ofn.hwndOwner:=mainwindow;
  ofn.lpstrFilter:=szFilter;
  ofn.nFilterIndex:=1;
  ofn.lpstrFile:=szFilesave;
  ofn.nMaxFile:=sizeof(szFilesave) div 2;
  ofn.lpstrFileTitle:=szFileTitle;
  ofn.nMaxFileTitle:=sizeof(szFileTitle) div 2;
  ofn.lpstrInitialDir:=szDirName;
  ofn.lpstrTitle:='Borg Disassembler - Select File';
  ofn.Flags:=OFN_PATHMUSTEXIST or OFN_HIDEREADONLY or OFN_LONGNAMES or OFN_EXPLORER;
end;

{************************************************************************
* getfiletoload                                                         *
* - obtains a filename for the file to be loaded                        *
*   used for new files to load, and load database file                  *
*   sets fname to the filename                                          *
************************************************************************}
procedure getfiletoload(fname:pchar);
var ofn:tOPENFILENAME;
begin
  init_ofn(ofn);
  ofn.Flags:=ofn.Flags or OFN_FILEMUSTEXIST;
  GetOpenFileName(ofn);
  strcopy(fname,ofn.lpstrFile);
end;

{************************************************************************
* getfiletosave                                                         *
* - obtains a filename for the file to be saved                         *
*   sets fname to the filename                                          *
************************************************************************}
procedure getfiletosave(fname:pchar);
var ofn:tOPENFILENAME;
begin
  init_ofn(ofn);
  GetSaveFileName(ofn);
  strcopy(fname,ofn.lpstrFile);
end;

begin
end.

