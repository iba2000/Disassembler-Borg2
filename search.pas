unit search;
interface
uses sysutils,windows,common,menus,schedule,datas,disasm,disio;
{
  >* These are the functions which handle searching. I still have more     *
  >* work to do on searching (particularly regarding strings - unicode,    *
  >* etc), but the basic functionality is there. Other ideas for the       *
  >* future include wildcard searching. (Byte wildcard searching would be  *
  >* nice :))                                                              *
}
type
  search_type=(search_0,SEARCH_STR_,SEARCH_HEX_,SEARCH_DEC_,SEARCH_BYTES_);

const
  MAX_SEARCHLEN=200;
  oldsearchtext:array[0..MAX_SEARCHLEN] of char='';
  lastsearchtype:search_type=SEARCH_STR_;
  lastfromstart:boolean=FALSE;

  procedure searchmore;
  procedure searchengine;

implementation

{************************************************************************
* parsestring                                                           *
* - parses a string into from the input text into the search array      *
************************************************************************}
function parsestring(match,srchtext:pchar):integer;
begin
  strcopy(match,srchtext);
  result:=strlen(srchtext);
end;

{************************************************************************
* parsehex                                                              *
* - parses a string for a hex value and puts it in the search array     *
************************************************************************}
function parsehex(match,srchtext:pchar):integer;
var
  matchlen:integer;
  mtch:dword;
begin
  strfmt(srchtext,'%x',[mtch]);
  if mtch<256 then begin
    matchlen:=1;
    match[0]:=chr(mtch);
  end else if mtch<65536 then begin
    matchlen:=2;
    match[0]:=chr(mtch);
    match[1]:=chr(mtch div $100);
  end else begin
    matchlen:=4;
    match[0]:=chr(mtch);
    match[1]:=chr(mtch div $100);
    match[2]:=chr(mtch div $10000);
    match[3]:=chr(mtch div $1000000);
  end;
  result:=matchlen;
end;

{************************************************************************
* parsedecimal                                                          *
* - parses a string for a decimal value and puts it in the search array *
************************************************************************}
function parsedec(match,srchtext:pchar):integer;
var
  matchlen:integer;
  mtch:dword;
begin
  strfmt(srchtext,'%d',[mtch]);
  if mtch<256 then begin
    matchlen:=1;
    match[0]:=chr(mtch);
  end else if mtch<65536 then begin
    matchlen:=2;
    match[0]:=chr(mtch);
    match[1]:=chr(mtch div $100);
  end else begin
    matchlen:=4;
    match[0]:=chr(mtch);
    match[1]:=chr(mtch div $100);
    match[2]:=chr(mtch div $10000);
    match[3]:=chr(mtch div $1000000);
  end;
  result:=matchlen;
end;

{************************************************************************
* parsebytes                                                            *
* - parses a string for a series of bytes and puts them in the search   *
*   array                                                               *
************************************************************************}
function parsebytes(match,srchtext:pchar):integer;
var
  matchlen,i:integer;
  tmpbyte:byte;
begin
  matchlen:=strlen(srchtext) div 2;
  for i:=0 to matchlen-1 do begin
    if srchtext[i*2]>='a' then
      tmpbyte:=byte(srchtext[i*2])-byte('a')+10
    else
      tmpbyte:=byte(srchtext[i*2])-byte('0');
    if srchtext[i*2+1]>='a' then
      tmpbyte:=tmpbyte*16+(byte(srchtext[i*2+1])-byte('a')+10)
    else
      tmpbyte:=tmpbyte*16+byte(srchtext[i*2+1])-byte('0');
    match[i]:=chr(tmpbyte);
  end;
  result:=matchlen;
end;

// searchingbox                                                          *
// - this is simply a small dialog box with only the text message        *
//   'searching' which is displayed while the search takes place. Note   *
//   that while a search is being done we are in the primary thread and  *
//   that the secondary thread is stopped, so nothing else happens       *
//   within Borg at all.                                                 *
function searchingbox(hdwnd,msg,wParam,lParam:dword):dword;stdcall;
begin
  result:=0;
  case msg of
   WM_INITDIALOG:
    begin
      CenterWindow(hdwnd);
      exit;
    end;
  end;
end;

{************************************************************************
* dosearch                                                              *
* - main search routine ripped from other routines in previous versions *
************************************************************************}
procedure dosearch(hdwnd:HWND; searchtype:search_type; fromstart:boolean; s_seg:lptr);
var
  found:boolean;
  matchlen,i:integer;
  sbox:HWND;
  srchseg:pdsegitem;
  match:array[0..MAX_SEARCHLEN] of char;
  segmtch:pchar;
begin
  sbox:=CreateDialog(Inst,MAKEINTRESOURCE(S_Box),hdwnd,@searchingbox);
  case searchtype of
   SEARCH_STR_:   matchlen:=parsestring(match,oldsearchtext);
   SEARCH_HEX_:   matchlen:=parsehex(match,oldsearchtext);
   SEARCH_DEC_:   matchlen:=parsedec(match,oldsearchtext);
   SEARCH_BYTES_: matchlen:=parsebytes(match,oldsearchtext);
   else
     MessageBox(hdwnd,'Internal Error:Search Unknown Option','Borg',MB_OK);
     exit;
  end;
  // string->data, for each seg do .....
  found:=false;
  if fromstart then begin
    dta.resetiterator;
    srchseg:=pdsegitem(dta.nextiterator);
  end else srchseg:=dta.findseg(s_seg);
  lastfromstart:=fromstart;
  while srchseg<>nil do begin
    s_seg.s:=srchseg.addr.s;
    if fromstart then s_seg:=srchseg.addr;
    fromstart:=false;
    if le(s_seg,srchseg.addr) then s_seg:=srchseg.addr;
    while s_seg.o<=srchseg.addr.o+srchseg.size-matchlen do begin
      segmtch:=srchseg.data+(s_seg.o-srchseg.addr.o);
      found:=true;
      for i:=0 to matchlen-1 do begin
        if segmtch[i]<>match[i] then begin
          found:=false; break;
        end;
      end;
      if found then break;
      inc(s_seg.o);
    end;
    if found then break;
    s_seg.o:=0;
    srchseg:=pdsegitem(dta.nextiterator);
  end;
  if found then scheduler.addtask(user_jumptoaddr,priority_userrequest,s_seg,0,nil);
  DestroyWindow(sbox);
end;

// searchbox                                                             *
// - this is the main search dialog box.                                 *
// - it performs the search when we press ok, and the state of controls  *
//   is saved to global variables                                        *
// - search function separated out v2.22                                 *
function searchbox(hdwnd,msg,wParam,lParam:dword):dword;stdcall;
var
  searchtype:search_type;
  s_seg:lptr;
  fromstart:boolean;  // added plus code, bug fix build 14
begin
  result:=0;
  case msg of
   WM_COMMAND:
    case wParam of
     IDOK:
      begin
        if SendDlgItemMessage(hdwnd,search_string,BM_GETCHECK,0,0)<>0 then
          searchtype:=SEARCH_STR_
        else if SendDlgItemMessage(hdwnd,search_hex,BM_GETCHECK,0,0)<>0 then
          searchtype:=SEARCH_HEX_
        else if SendDlgItemMessage(hdwnd,search_decimal,BM_GETCHECK,0,0)<>0 then
          searchtype:=SEARCH_DEC_
        else searchtype:=SEARCH_BYTES_;
        if SendDlgItemMessage(hdwnd,search_fromstart,BM_GETCHECK,0,0)<>0 then begin
          s_seg:=options.loadaddr;
          fromstart:=TRUE;
        end else begin
          dio.findcurrentaddr(s_seg);
          inc(s_seg.o,dsm.getlength(s_seg));
          fromstart:=FALSE;
        end;
        SendDlgItemMessage(hdwnd,search_edit,WM_GETTEXT,18,dword(@oldsearchtext));
        dosearch(hdwnd,searchtype,fromstart,s_seg);
        lastsearchtype:=searchtype;
        EndDialog(hdwnd,0);
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
      fromstart:=lastfromstart;
      searchtype:=lastsearchtype;
      if searchtype=SEARCH_STR_ then
        SendDlgItemMessage(hdwnd,search_string,BM_SETCHECK,1,0)
      else if searchtype=SEARCH_HEX_ then
        SendDlgItemMessage(hdwnd,search_hex,BM_SETCHECK,1,0)
      else if searchtype=SEARCH_DEC_ then
        SendDlgItemMessage(hdwnd,search_decimal,BM_SETCHECK,1,0)
      else
        SendDlgItemMessage(hdwnd,search_bytes,BM_SETCHECK,1,0);
      if fromstart then
        SendDlgItemMessage(hdwnd,search_fromstart,BM_SETCHECK,1,0)
      else
        SendDlgItemMessage(hdwnd,search_fromcurr,BM_SETCHECK,1,0);
      SendDlgItemMessage(hdwnd,search_edit,WM_SETTEXT,0,dword(@oldsearchtext));
      SetFocus(GetDlgItem(hdwnd,search_edit));
      exit;
     end;
  end;
end;


{************************************************************************
* searchmore                                                            *
* - Rewritten v2.22...... just calls the search function with search    *
*   again now.                                                          *
************************************************************************}
procedure searchmore;
var s_seg:lptr;
begin
  if strlen(oldsearchtext)=0 then begin searchengine; exit end;
  scheduler.stopthread;
  dio.findcurrentaddr(s_seg);
  inc(s_seg.o,dsm.getlength(s_seg));
  dosearch(mainwindow,lastsearchtype,false,s_seg);
  scheduler.continuethread;
end;

// searchengine                                                          *
// - simply stops the secondary thread, puts up the search dialog box,   *
//   and restarts the thread again at the end                            *
procedure searchengine;
begin
  scheduler.stopthread;
  DialogBox(Inst,MAKEINTRESOURCE(Search_Dialog),mainwindow,@searchbox);
  scheduler.continuethread;
end;


begin
end.

