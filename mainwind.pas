unit mainwind;
interface
uses sysutils,windows,common;
{************************************************************************
* This is one of a few files which contain some old code, a lot of      *
* hacks, a lot of hastily stuffed lines and variables, etc, and is in   *
* in need of an overhaul. Its also why I left commenting it until the   *
* last four files (disasm,fileload,dasm and this one!). Whilst making   *
* these comments I have taken a small opportunity to tidy it a little.  *
* This file controls output to the main window. It keeps a small buffer *
* of disassembled lines, and it uses this buffer to repaint the main    *
* window when WM_PAINT requests are received.                           *
* Whenever the disassembly is changed or the user scrolls there is a    *
* windowupdate request sent to the scheduler with a high priority.      *
* When the windowupdate is processed it is passed to the windowupdate   *
* or scroller function in disio. disio will regenerate the buffer as    *
* required and then invalidate the main window so that a repaint is     *
* done.                                                                 *
* The functions here include basic formatted output to the buffer as    *
* well as the window repaints. Repaints will not be done while the      *
* buffer is being updated, but will wait for the buffer update to       *
* finish and then do the repaint.                                       *
* The functions also use extensive critical sections which ensure that  *
* we do not start clearing the buffer during a window update, etc       *
************************************************************************}

var
  nScreenRows:dword;
  usersel:dword;  // user selection. (line number).
  rrr,cyc:dword; //integer
  userselonscreen:boolean;

  procedure horizscroll(amount:integer);
  procedure horizscrollto(place:integer);
  procedure StatusMessageNItems(nolistitems:dword);
  procedure DoneBuff;
  procedure ClearBuff;
  procedure PrintBuff(szFormat:pchar; const args:array of const);
  procedure LastPrintBuff(szFormat:pchar; const args:array of const);
  procedure LastPrintBuffEpos(xpos:dword);
  procedure LastPrintBuffLongHexValue(num:dword);
  procedure LastPrintBuffHexValue(num:byte);
  procedure DoPaint(Wnd:HWND; cxChar,cyChar:integer);
  procedure PaintBackg(Wnd:HWND);

implementation

// This file controls the output to the main window. It works like this:
//   a small buffer of output lines is kept.
//   this is used to repaint the screen when needed.
//   the main thread can update this buffer by calling the various routines.
//   if the user moves in the window then a schedule message is sent to repaint,
//   and this is processed as soon as possible.

var
  hpos:integer;
  sbuff:shortstring;

procedure StatusMessageNItems(nolistitems:dword);
begin
  sbuff:='Items to Process :'+inttostr(nolistitems)+#0;
  StatusMessage(@sbuff[1]);
end;

// horizscroll                                                           *
// - hpos keeps track of the horizontal scroll which determines where    *
//   from each buffer line we start printing the output                  *
procedure horizscroll(amount:integer);
begin
  EnterCriticalSection(cs);
  inc(hpos,amount);
  if hpos<0 then hpos:=0;  // max-size checked in dopaint.
  LeaveCriticalSection(cs);
  InvalidateRect(mainwindow,nil,TRUE);
end;

// horizscrollto                                                         *
// - this is used when the horizontal scrollbar control is dragged and   *
//   dropped to change the hpos offset to the new place (maximum         *
//   horizontal size is fixed in Borg)                                   *
procedure horizscrollto(place:integer);
begin
  EnterCriticalSection(cs);
  hpos:=place;
  LeaveCriticalSection(cs);
  InvalidateRect(mainwindow,nil,TRUE);
end;

// ClearBuff                                                             *
// - This should be called before each reworking of the buffer. It       *
//   clears the buffer and stops any repainting from taking place.       *
// - It also resets the line pointer to the start of the buffer.         *
procedure ClearBuff;
var
  i:integer;
  p:pchar;
begin
  EnterCriticalSection(cs);
  p:=@MainBuff;
  for i:=0 to buffer_lines-1 do begin
    p^:=#0; inc(p,max_length);
  end;
  lastline:=0;
  bufferready:=FALSE;
  LeaveCriticalSection(cs);
end;

// DoneBuff                                                              *
// - This should be called after a reworking of the buffer. It reenables *
//   window repainting.                                                  *
procedure DoneBuff;
begin
  EnterCriticalSection(cs);
  bufferready:=TRUE;
  LeaveCriticalSection(cs);
end;

function isalnum(c:char):boolean;
begin
  result:=c in['A'..'Z','a'..'z','0'..'9',':',' ',';',''''];
end;

// PrintBuff                                                             *
// - This is the printf of the buffer and is similar to wvsprintf but    *
//   output is to the main buffer. Note that the line pointer is moved   *
//   on after a call, so we move to the next line automatically.         *
procedure PrintBuff(szFormat:pchar; const args:array of const);
var
  i:integer;
  p:pchar;
begin
  EnterCriticalSection(cs);
  if lastline<buffer_lines-1 then begin
    strlfmt(@MainBuff[lastline*max_length],max_length,szFormat,Args);
    p:=@mainbuff[lastline*max_length];
    for i:=0 to strlen(p) do begin
      p^:=locase(p^); inc(p);
    end;
    inc(lastline);
  end;
  MainBuff[buffer_lines*max_length]:=#0;
  LeaveCriticalSection(cs);
end;

// LastPrintBuffEpos                                                     *
// - Often we use PrintBuff followed by LastPrintBuff to construct a     *
//   line of output a piece at a time. This function provides basic      *
//   formatting by allowing us to set the cursor position on the last    *
//   line printed, by adding spaces until the position.                  *
procedure LastPrintBuffEpos(xpos:dword);
var
  i:dword;
  p:pchar;
begin
  EnterCriticalSection(cs);
  if lastline<>0 then begin
    p:=@Mainbuff[(lastline-1)*max_length];
    i:=strlen(p);
    while i<xpos do begin
      p[i]:=' '; p[i+1]:=#0; inc(i);
    end;
  end;
  LeaveCriticalSection(cs);
end;

{************************************************************************
* LastPrintBuffHexValue                                                 *
* - Same as LastPrintBuff, but prints num only, in hex. It prints a     *
*   leading zero where the leading char is alpha.                       *
************************************************************************}
procedure LastPrintBuffHexValue(num:byte);
var tstr:array[0..20] of char;
begin
  strfmt(tstr,'%2.2xh',[num]);
  if tstr[0] in['A'..'F'] then LastPrintBuff('0',['']);
  LastPrintBuff('%2.2xh',[num]);
end;

{************************************************************************
* LastPrintBuffHexValue                                                 *
* - Same as LastPrintBuff, but prints num only, in hex. It prints a     *
*   leading zero where the leading char is alpha.                       *
************************************************************************}
procedure LastPrintBuffLongHexValue(num:dword);
var tstr:array[0..20] of char;
begin
  strfmt(tstr,'%2.2xh',[num]);
  if tstr[0] in['A'..'F'] then LastPrintBuff('0',['']);
  LastPrintBuff('%2.2xh',[num]);
end;

// LastPrintBuff                                                         *
// - This is the same as PrintBuff except that instead of printing a new *
//   line it goes back to the last line and adds more to the end of it   *
// - So a set of calls tends to look like PrintBuff, LastPrintBuffEPos,  *
//   LastPrintBuff, LastPrintBuffEPos, LastPrintBuff, PrintBuff, etc     *
procedure LastPrintBuff(szFormat:pchar; const args:array of const);
var
  spos:dword;
  p:pchar;
  i:integer;
begin
  EnterCriticalSection(cs);
  if lastline<>0 then begin
    spos:=(lastline-1)*max_length;
    if strlen(@MainBuff[spos])<max_length then begin
      strlfmt(@MainBuff[spos+strlen(@MainBuff[spos])],max_length,szFormat,Args);
//      p:=@mainbuff[spos];
//      for i:=0 to strlen(p) do begin p^:=locase(p^); inc(p); end;
    end;
  end;
  MainBuff[buffer_lines*max_length]:=#0;
  LeaveCriticalSection(cs);
end;

{************************************************************************
* PaintBack                                                             *
* - This is the routine for painting when there is no file loaded. It   *
*   simply paints the background in our selected colour.                *
* - Yet another quick hack, from the above routine.... looks ok though  *
************************************************************************}
procedure PaintBackg(Wnd:HWND);
var
  DC:HDC;           // handle for the display device
  ps:tPAINTSTRUCT;  // holds PAINT information
  rRect:tRECT;
begin
  EnterCriticalSection(cs);
  fillchar(ps,sizeof(tPAINTSTRUCT),0);
  DC := BeginPaint(Wnd,ps);
  GetClientRect(Wnd,rRect);
  ShowScrollBar (Wnd, SB_VERT, TRUE);
  FillRect(DC, rRect,CreateSolidBrush(options.bgcolor));
  EndPaint(Wnd,ps);
  LeaveCriticalSection(cs);
end;

{************************************************************************
* DoPaint                                                               *
* - This is the main painting routine. If the program is quitting then  *
*   it returns (we dont want thread clashes due to critical sections    *
*   here and theres no point to repainting when we're exitting).        *
* - If the buffer is not ready then we wait, and go to sleep.           *
* - Otherwise the routine paints the screen from the buffer, using the  *
*   selected font and colours                                           *
************************************************************************}
procedure DoPaint(Wnd:HWND; cxChar,cyChar:integer);
var
  tmp:pchar;
  DC:HDC;             // handle for the display device
  ps:tPAINTSTRUCT;    // holds PAINT information
  nI:dword;
  rRect:tRECT;
  startpt,sn:integer;
  sl:array[0..300] of char;
begin
  tmp:=nil;
  cyc:=cyChar;
  while not bufferready do Sleep(0);  // wait if filling buffer
  if KillThread then exit;
  if lastline=0 then begin PaintBackg(Wnd); exit; end;
  EnterCriticalSection(cs);
  fillchar(ps,sizeof(tPAINTSTRUCT),0);
  DC := BeginPaint(Wnd,ps);
  case fontselection(options.font) of
   courierfont,
   courierfont10,
   courierfont12:
     if cf=0 then SelectObject(DC,GetStockObject(ANSI_FIXED_FONT))
     else SelectObject(DC,cf);
   ansifont:    SelectObject(DC,GetStockObject(ANSI_FIXED_FONT));
   systemfont:  SelectObject(DC,GetStockObject(SYSTEM_FIXED_FONT));
   else         SelectObject(DC,GetStockObject(ANSI_FIXED_FONT));
  end;
  GetClientRect(Wnd,rRect);
  if hpos>max_length-(rRect.right div cxChar) then hpos:=max_length-rRect.right div cxChar;
  if rrr<>rRect.right then begin
    rrr:=rRect.right;
    SetScrollRange(Wnd,SB_HORZ,0,max_length-(rRect.right div cxChar),TRUE);
  end;
  SetScrollPos(Wnd,SB_HORZ,hpos,TRUE);
  nScreenRows:=rRect.bottom div cyChar;
  ShowScrollBar(Wnd, SB_VERT, TRUE);
  ShowScrollBar(Wnd, SB_HORZ, max_length>(rRect.right/cxChar));
  startpt:=0;
  SetTextColor(DC,options.textcolor);
  for nI:=startpt to lastline-1 do begin
    if (userselonscreen)and(nI=usersel) then SetBkColor(DC,options.highcolor)
    else SetBkColor(DC,options.bgcolor);
    strcopy(sl,@MainBuff[nI*max_length]);
    sn:=strlen(sl);
    fillchar(sl[sn],max_length-sn,' '); sl[max_length]:=#0;
    TabbedTextOut(DC,2-hpos*cxChar,nI*cyChar,sl,max_length,0,tmp,2-hpos*cxChar);
  end;
  for nI:=lastline to nScreenRows do begin
    if (userselonscreen)and(nI=usersel) then SetBkColor(DC,options.highcolor)
    else SetBkColor(DC,options.bgcolor);
    fillchar(sl,max_length,' '); sl[max_length]:=#0;
    TabbedTextOut(DC,2-hpos*cxChar,nI*cyChar,sl,max_length,0,tmp,2-hpos*cxChar);
  end;
  EndPaint(Wnd,ps);
  LeaveCriticalSection(cs);
end;

begin
  hpos:=0;
  BufferReady:=true;
end.

