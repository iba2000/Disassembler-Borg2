uses
  sysutils,windows,commdlg,common,menus,schedule,mainwind,
  exeload,disio,datas,gname,xref,proctab,search,range,decrypt,
  database,user_dlg,dlg_load,help,user_fn,registry;
{$R dasm.res}
{************************************************************************
*                         Borg Disassembler                             *
*                              v2.28                                    *
*                            by Cronos                                  *
* Contributors:                                                         *
* Thanks to Mark Ogden for many bugfixes and mods for assembly under    *
* VC++, in its early stages (v2 beta builds). Also changes from         *
* wvsprintf to wsprintf to allow compilation under VC++.                *
* Thanks to Eugen Polukhin for some interesting alternate code and      *
* ideas around v2.11 and feedback on fonts, etc.                        *
* Thanks to Pawe3 Kunio for a lot of coding ideas and advice re C++     *
* usage around v2.22                                                    *
* Thanks to Howard Chu for some coding additions on default names, and  *
* more block functions                                                  *
************************************************************************}

{************************************************************************
* - this whole file is a declaration and global routine dumping area    *
* - it includes winmain and the main message callback routine, along    *
*   with initialisation code and the registry read/write code, odd      *
*   dialog boxes and helper functions for the main routines. The whole  *
*   file is a bit of a mish-mash of stuff which hasnt found its way     *
*   elsewhere.                                                          *
* - a lot of the code in here has grown, and i mean grown from the      *
*   ground up, and at some point it will require reorganisation, or     *
*   maybe that point was long ago....                                   *
************************************************************************}
var
  cxChar,cyChar:integer;
  mainwndsize,StatusWindowSize:trect;
  rmenu:hmenu;
const
  charinputenabled:boolean=FALSE;


// TestThread                                                            *
// - this is used on exit to wait for the secondary thread to finish.    *
// - I try every possible way of getting the thread to exit normally     *
//   before we eventually kill it in the mainwindow, WM_DESTROY handler  *
function TestThread:boolean;
var
  sbox:HWND;
  ttest:boolean;
begin
  sbox:=CreateDialog(Inst,MAKEINTRESOURCE(Borg_Shutdown),mainwindow,@shutbox);
  if InThread then SetThreadPriority(ThreadHandle,THREAD_PRIORITY_TIME_CRITICAL);
  Sleep(2000);
  DestroyWindow(sbox);
  Sleep(5000);
//  EnterCriticalSection(cs); build 221
  ttest:=InThread;
//  LeaveCriticalSection(cs); build 221
  result:=ttest;
end;

// Thread                                                                *
// - this is the secondary thread interface. It just keeps calling the   *
//   scheduler to process any items in the queue, until such time as the *
//   main thread wants to quit.                                          *
procedure Thread(pvoid:pointer);stdcall;
begin
  repeat
    if scheduler.process then if not KillThread then StatusMessage('Processing Completed');
    Sleep(1);
  until KillThread;
  InThread:=false;
  ExitThread(0);
end;

procedure optionsinit;
begin
  options.loaddebug:=TRUE;
  options.mode16:=FALSE;
  options.mode32:=FALSE;
  options.loaddata:=TRUE;
  options.loadresources:=FALSE;
  options.cfa:=TRUE;
  options.demangle:=TRUE;
  options.processor:=PROC_PENTIUM;
  options.codedetect:=CD_PUSHBP or CD_EAXFROMESP or CD_MOVEAX;
  options.bgcolor:=GetSysColor(COLOR_APPWORKSPACE);
  options.highcolor:=RGB(0,255,0);
  options.textcolor:=0;
  options.font:=ansifont;
  options.readonly:=false;
  options.winmax:=false;
end;

procedure changemenus;
var Menu:HMENU;
begin
  Menu:=GetMenu(mainwindow);
  EnableMenuItem(Menu,file_open,MF_GRAYED);
  EnableMenuItem(Menu,file_save,MF_ENABLED);
  EnableMenuItem(Menu,save_asm,MF_ENABLED);
  EnableMenuItem(Menu,view_segment,MF_ENABLED);
  EnableMenuItem(Menu,view_names,MF_ENABLED);
  EnableMenuItem(Menu,view_xrefs,MF_ENABLED);
  EnableMenuItem(Menu,view_imports,MF_ENABLED);
  EnableMenuItem(Menu,view_exports,MF_ENABLED);
  EnableMenuItem(Menu,make_code,MF_ENABLED);
  EnableMenuItem(Menu,undefine_line,MF_ENABLED);
  EnableMenuItem(Menu,undefine_lines,MF_ENABLED);
  EnableMenuItem(Menu,undefine_lines_long,MF_ENABLED);
  EnableMenuItem(Menu,line_jumpto,MF_ENABLED);
  EnableMenuItem(Menu,line_jumptoarg2,MF_ENABLED);
  EnableMenuItem(Menu,make_dword,MF_ENABLED);
  EnableMenuItem(Menu,make_word,MF_ENABLED);
  EnableMenuItem(Menu,make_string,MF_ENABLED);
  EnableMenuItem(Menu,pascal_string,MF_ENABLED);
  EnableMenuItem(Menu,uc_string,MF_ENABLED);
  EnableMenuItem(Menu,up_string,MF_ENABLED);
  EnableMenuItem(Menu,dos_string,MF_ENABLED);
  EnableMenuItem(Menu,general_string,MF_ENABLED);
  EnableMenuItem(Menu,Name_Location,MF_ENABLED);
  EnableMenuItem(Menu,Jump_Back,MF_ENABLED);
  EnableMenuItem(Menu,argover_dec,MF_ENABLED);
  EnableMenuItem(Menu,argover_hex,MF_ENABLED);
  EnableMenuItem(Menu,argover_char,MF_ENABLED);
  EnableMenuItem(Menu,argnegate,MF_ENABLED);
  EnableMenuItem(Menu,offset_dseg,MF_ENABLED);
  EnableMenuItem(Menu,main_search,MF_ENABLED);
  EnableMenuItem(Menu,save_database,MF_ENABLED);
  EnableMenuItem(Menu,load_database,MF_GRAYED);
  EnableMenuItem(Menu,get_comment,MF_ENABLED);
  EnableMenuItem(rmenu,make_code,MF_ENABLED);
  EnableMenuItem(rmenu,get_comment,MF_ENABLED);
  EnableMenuItem(rmenu,undefine_line,MF_ENABLED);
  EnableMenuItem(rmenu,undefine_lines,MF_ENABLED);
  EnableMenuItem(rmenu,undefine_lines_long,MF_ENABLED);
  EnableMenuItem(rmenu,line_jumpto,MF_ENABLED);
  EnableMenuItem(rmenu,line_jumptoarg2,MF_ENABLED);
  EnableMenuItem(rmenu,make_dword,MF_ENABLED);
  EnableMenuItem(rmenu,make_word,MF_ENABLED);
  EnableMenuItem(rmenu,make_string,MF_ENABLED);
  EnableMenuItem(rmenu,pascal_string,MF_ENABLED);
  EnableMenuItem(rmenu,uc_string,MF_ENABLED);
  EnableMenuItem(rmenu,up_string,MF_ENABLED);
  EnableMenuItem(rmenu,dos_string,MF_ENABLED);
  EnableMenuItem(rmenu,general_string,MF_ENABLED);
  EnableMenuItem(rmenu,Name_Location,MF_ENABLED);
  EnableMenuItem(rmenu,view_xrefs,MF_ENABLED);
  EnableMenuItem(rmenu,argover_dec,MF_ENABLED);
  EnableMenuItem(rmenu,argover_hex,MF_ENABLED);
  EnableMenuItem(rmenu,argover_char,MF_ENABLED);
  EnableMenuItem(rmenu,argnegate,MF_ENABLED);
  EnableMenuItem(rmenu,offset_dseg,MF_ENABLED);
  EnableMenuItem(Menu,block_top,MF_ENABLED);
  EnableMenuItem(Menu,block_bottom,MF_ENABLED);
  EnableMenuItem(Menu,block_view,MF_ENABLED);
  EnableMenuItem(Menu,block_saveasm,MF_ENABLED);
  EnableMenuItem(Menu,block_savetext,MF_ENABLED);
  EnableMenuItem(Menu,block_undefine,MF_ENABLED);
  EnableMenuItem(Menu,float_single,MF_ENABLED);
  EnableMenuItem(Menu,float_double,MF_ENABLED);
  EnableMenuItem(Menu,float_longdouble,MF_ENABLED);
  EnableMenuItem(Menu,arg_single,MF_ENABLED);
  EnableMenuItem(Menu,search_again,MF_ENABLED);
  EnableMenuItem(Menu,cm_decrypt,MF_ENABLED);
  EnableMenuItem(rmenu,cm_decrypt,MF_ENABLED);
  EnableMenuItem(rmenu,arg_single,MF_ENABLED);
  EnableMenuItem(rmenu,float_single,MF_ENABLED);
  EnableMenuItem(rmenu,float_double,MF_ENABLED);
  EnableMenuItem(rmenu,float_longdouble,MF_ENABLED);
  EnableMenuItem(rmenu,block_top,MF_ENABLED);
  EnableMenuItem(rmenu,block_bottom,MF_ENABLED);
  charinputenabled:=true;
end;

// setupfont                                                             *
// - handles the setting up of a font (like selecting the object for     *
//   window painting and setting checkmarks on the menu, etc)            *
procedure setupfont;
var
  dc:HDC;
  tm:tTEXTMETRIC;
  tmp_rect:tRECT;
  Menu:HMENU;
begin
  Menu:=GetMenu(mainwindow);
  dc:=GetDC(mainwindow);
  CheckMenuItem(Menu,font_ansi,MF_UNCHECKED);
  CheckMenuItem(Menu,font_system,MF_UNCHECKED);
  CheckMenuItem(Menu,font_courier,MF_UNCHECKED);
  CheckMenuItem(Menu,font_courier10,MF_UNCHECKED);
  CheckMenuItem(Menu,font_courier12,MF_UNCHECKED);
  case fontselection(options.font) of
   ansifont:
    begin
      SelectObject(dc,GetStockObject(ANSI_FIXED_FONT));
      CheckMenuItem(Menu,font_ansi,MF_CHECKED);
    end;
   systemfont:
    begin
      SelectObject(dc,GetStockObject(SYSTEM_FIXED_FONT));
      CheckMenuItem(Menu,font_system,MF_CHECKED);
    end;
   courierfont:
    begin
      if cf<>0 then DeleteObject(cf);
      cf:=CreateFont(-MulDiv(8, GetDeviceCaps(dc, LOGPIXELSY), 72),0,0,0,FW_LIGHT,0,0,0,0,0,0,0,0,'Courier New');
      if cf=0 then SelectObject(dc,GetStockObject(ANSI_FIXED_FONT))
      else SelectObject(dc,cf);
      CheckMenuItem(Menu,font_courier,MF_CHECKED);
    end;
   courierfont10:
    begin
      if cf<>0 then DeleteObject(cf);
      cf:=CreateFont(-MulDiv(10, GetDeviceCaps(dc, LOGPIXELSY), 72),0,0,0,FW_LIGHT,0,0,0,0,0,0,0,0,'Courier New');
      if cf=0 then SelectObject(dc,GetStockObject(ANSI_FIXED_FONT))
      else SelectObject(dc,cf);
      CheckMenuItem(Menu,font_courier10,MF_CHECKED);
    end;
   courierfont12:
    begin
      if cf<>0 then DeleteObject(cf);
      cf:=CreateFont(-MulDiv(12, GetDeviceCaps(dc, LOGPIXELSY), 72),0,0,0,FW_LIGHT,0,0,0,0,0,0,0,0,'Courier New');
      if cf=0 then SelectObject(dc,GetStockObject(ANSI_FIXED_FONT))
      else SelectObject(dc,cf);
      CheckMenuItem(Menu,font_courier12,MF_CHECKED);
    end;
   else
      SelectObject(dc,GetStockObject(ANSI_FIXED_FONT));
      CheckMenuItem(Menu,font_ansi,MF_CHECKED);
  end;
  GetTextMetrics(dc,tm);
  cxChar:=tm.tmAveCharWidth;
  cyChar:=tm.tmHeight+tm.tmExternalLeading;
  ReleaseDC(mainwindow,dc);
  GetClientRect(mainwindow,tmp_rect);
  InvalidateRect(mainwindow,@tmp_rect,TRUE);
  scheduler.addtask(windowupdate,priority_window,nlptr,0,nil);
end;

// savefile_text                                                         *
// - this is the savefile as text dialog which asks the user to select   *
//   a file for the save. The filedump is then controlled by disio       *
// - this is for text or asm saves                                       *
function savefile_text(wnd:HWND; printaddrs,block:boolean):boolean;
var
  cbString,i:integer;
  chReplace:char;
  sbox:HWND;
  ofn:tOPENFILENAME;
  szDirName  :array[0..MAX_PATH*2] of char;
  szFilesave :array[0..260*2] of char;
  szFilter   :array[0..260] of char;
  szFileTitle:array[0..260*2] of char;
begin
  result:=false;
  if scheduler.sizelist<>0 then begin
    MessageBox(mainwindow,'There are still items to process yet','Borg Warning',MB_OK or MB_ICONEXCLAMATION);
    exit;
  end;
  GetCurrentDirectory(MAX_PATH,szDirName);
  szFilesave[0]:=#0;
  cbString:=LoadString(Inst,IDS_FILTERSAVE,szFilter,sizeof(szFilter));
  chReplace:=szFilter[cbString-1]; i:=0;
  while szFilter[i]<>#0 do begin
    if szFilter[i]=chReplace then szFilter[i]:=#0; inc(i);
  end;
  Init_ofn(ofn);
  ofn.hwndOwner:=wnd;
  ofn.lpstrFilter:=szFilter;
  ofn.nFilterIndex:=1;
  ofn.lpstrFile:=szFilesave;
  ofn.nMaxFile:=sizeof(szFilesave) div 2;
  ofn.lpstrFileTitle:=szFileTitle;
  ofn.nMaxFileTitle:=sizeof(szFileTitle) div 2;
  ofn.lpstrInitialDir:=szDirName;
  ofn.lpstrCustomFilter:=nil;
  ofn.lpstrTitle:='Borg Disassembler - Select File';
  ofn.Flags:=OFN_PATHMUSTEXIST or OFN_HIDEREADONLY or OFN_LONGNAMES or OFN_EXPLORER;
  if GetSaveFileName(ofn) then begin
    sbox:=CreateDialog(Inst,MAKEINTRESOURCE(save_box),mainwindow,@savemessbox);
    if block then dio.dumpblocktofile(ofn.lpstrFile,printaddrs)
    else dio.dumptofile(ofn.lpstrFile,printaddrs);
    DestroyWindow(sbox);
  end;
end;


function dasm(wnd,msg,wParam,lParam:longint):longint;stdcall;
var
  dc:HDC;
  tm:tTEXTMETRIC;
  point:tPOINT;
  scrll:lptr;
  killcount:integer;
  tmp_rect:tRECT;
begin
  result:=0;
  mainwindow:=wnd;
  case msg of
   WM_COMMAND:
    case LOWORD(wParam) of
     file_exit:          SendMessage(mainwindow,WM_CLOSE,0,0);
     file_save:          savefile_text(wnd,TRUE,false);
     block_saveasm:      savefile_text(wnd,FALSE,TRUE);
     block_savetext:     savefile_text(wnd,TRUE,TRUE);
     cm_decrypt:         decrypterdialog;
     get_comment:        getcomment;
     save_database:      savedb;
     load_database:      loaddb;
     save_asm:           savefile_text(wnd,FALSE,false);
     file_open:          newfile;
     view_segment:       segviewer;
     view_names:         namesviewer;
     view_imports:       importsviewer;
     view_exports:       exportsviewer;
     view_xrefs:         xrefsviewer;
     make_code:          scheduler.addtask(user_makecode,priority_userrequest,nlptr,0,nil);
     make_dword:         scheduler.addtask(user_makedword,priority_userrequest,nlptr,0,nil);
     float_single:       scheduler.addtask(user_makesingle,priority_userrequest,nlptr,0,nil);
     float_double:       scheduler.addtask(user_makedouble,priority_userrequest,nlptr,0,nil);
     float_longdouble:   scheduler.addtask(user_makelongdouble,priority_userrequest,nlptr,0,nil);
     arg_single:         scheduler.addtask(user_argsingle,priority_userrequest,nlptr,0,nil);
     make_word:          scheduler.addtask(user_makeword,priority_userrequest,nlptr,0,nil);
     make_string:        scheduler.addtask(user_makestring,priority_userrequest,nlptr,0,nil);
     pascal_string:      scheduler.addtask(user_pascalstring,priority_userrequest,nlptr,0,nil);
     uc_string:          scheduler.addtask(user_ucstring,priority_userrequest,nlptr,0,nil);
     up_string:          scheduler.addtask(user_upstring,priority_userrequest,nlptr,0,nil);
     dos_string:         scheduler.addtask(user_dosstring,priority_userrequest,nlptr,0,nil);
     general_string:     scheduler.addtask(user_generalstring,priority_userrequest,nlptr,0,nil);
     argover_dec:        scheduler.addtask(user_argoverdec,priority_userrequest,nlptr,0,nil);
     argover_hex:        scheduler.addtask(user_argoverhex,priority_userrequest,nlptr,0,nil);
     argnegate:          scheduler.addtask(user_argnegate,priority_userrequest,nlptr,0,nil);
     offset_dseg:        scheduler.addtask(user_argoveroffsetdseg,priority_userrequest,nlptr,0,nil);
     argover_char:       scheduler.addtask(user_argoverchar,priority_userrequest,nlptr,0,nil);
     undefine_line:      scheduler.addtask(user_undefineline,priority_userrequest,nlptr,0,nil);
     undefine_lines:     scheduler.addtask(user_undefinelines,priority_userrequest,nlptr,0,nil);
     undefine_lines_long:scheduler.addtask(user_undefinelines_long,priority_userrequest,nlptr,0,nil);
     line_jumpto:        scheduler.addtask(user_jumpto,priority_userrequest,nlptr,0,nil);
     line_jumptoarg2:    scheduler.addtask(user_jumptoarg2,priority_userrequest,nlptr,0,nil);
     block_undefine:     scheduler.addtask(user_undefineblock,priority_userrequest,nlptr,0,nil);
     block_view:         blockview;
     block_top:          scheduler.addtask(user_marktopblock,priority_userrequest,nlptr,0,nil);
     block_bottom:       scheduler.addtask(user_markbottomblock,priority_userrequest,nlptr,0,nil);
     Name_Location:      namelocation;
     help_short:         DialogBox(Inst,MAKEINTRESOURCE(help_shortcuts),wnd,@helpshortcuts);
     help_about:         DialogBox(Inst,MAKEINTRESOURCE(D_help_about),wnd,@habox);
     Jump_Back:          scheduler.addtask(user_jumpback,priority_userrequest,nlptr,0,nil);
     main_search:        searchengine;
     search_again:       searchmore;
     set_bg_color:
      begin
        options.bgcolor:=choosecolour(options.bgcolor);
        GetClientRect(mainwindow,tmp_rect);
        InvalidateRect(mainwindow,@tmp_rect,TRUE);
        scheduler.addtask(windowupdate,priority_window,nlptr,0,nil);
      end;
     set_high_color:
      begin
        options.highcolor:=choosecolour(options.highcolor);
        GetClientRect(mainwindow,tmp_rect);
        InvalidateRect(mainwindow,@tmp_rect,TRUE);
        scheduler.addtask(windowupdate,priority_window,nlptr,0,nil);
      end;
     set_text_color:
      begin
        options.textcolor:=choosecolour(options.textcolor);
        GetClientRect(mainwindow,tmp_rect);
        InvalidateRect(mainwindow,@tmp_rect,TRUE);
        scheduler.addtask(windowupdate,priority_window,nlptr,0,nil);
      end;
     font_system:    begin options.font:=systemfont; setupfont; end;
     font_courier:   begin options.font:=courierfont; setupfont; end;
     font_courier10: begin options.font:=courierfont10; setupfont; end;
     font_courier12: begin options.font:=courierfont12; setupfont; end;
     font_ansi:      begin options.font:=ansifont; setupfont; end;
     else result:=DefWindowProc(wnd,msg,wParam,lParam); exit;
    end;
   WM_CHAR:
    if charinputenabled then case chr(wParam) of
      'c': scheduler.addtask(user_makecode,priority_userrequest,nlptr,0,nil);
      'C': scheduler.addtask(user_argoverchar,priority_userrequest,nlptr,0,nil);
      'd': scheduler.addtask(user_makedword,priority_userrequest,nlptr,0,nil);
      'D': scheduler.addtask(user_argoverdec,priority_userrequest,nlptr,0,nil);
      'H': scheduler.addtask(user_argoverhex,priority_userrequest,nlptr,0,nil);
      '-': scheduler.addtask(user_argnegate,priority_userrequest,nlptr,0,nil);
      'n': namelocation;
      ';': getcomment;
      'o': scheduler.addtask(user_argoveroffsetdseg,priority_userrequest,nlptr,0,nil);
      'p': scheduler.addtask(user_pascalstring,priority_userrequest,nlptr,0,nil);
      's': scheduler.addtask(user_makestring,priority_userrequest,nlptr,0,nil);
      'u': scheduler.addtask(user_undefineline,priority_userrequest,nlptr,0,nil);
      'U': scheduler.addtask(user_undefinelines,priority_userrequest,nlptr,0,nil);
      'w': scheduler.addtask(user_makeword,priority_userrequest,nlptr,0,nil);
      't': scheduler.addtask(user_marktopblock,priority_userrequest,nlptr,0,nil);
      'b': scheduler.addtask(user_markbottomblock,priority_userrequest,nlptr,0,nil);
    end;
   WM_LBUTTONDOWN: dio.setpos(HIWORD(lParam));
   WM_RBUTTONDOWN:
    begin
      dio.setpos(HIWORD(lParam));
      point.x:=LOWORD(lParam);
      point.y:=HIWORD(lParam);
      ClientToScreen(mainwindow,point);
      TrackPopupMenu(rmenu,0,point.x,point.y,0,mainwindow,nil);
    end;
   WM_PAINT:
    if not KillThread then begin
      DoPaint(wnd,cxChar,cyChar)
    end else begin
      PaintBackg(wnd);
    end;
   WM_CLOSE:
    begin
      if (current_exe_name[0]<>#0) then if
       (MessageBox(mainwindow,'Are you sure that you want to exit Borg ?'#10+
         'Hit Yes To Exit'#10+'Hit No to Stay','Borg Disassembler',
        MB_ICONEXCLAMATION or MB_YESNO)=IDNO)
      then exit;
      scheduler.stopthread;
      scheduler.addtask(quitborg,priority_quit,nlptr,0,nil);
      KillThread:=true;
      if InThread then SetThreadPriority(ThreadHandle,THREAD_PRIORITY_TIME_CRITICAL);
      DestroyWindow(mainwindow);
      exit;
    end;
   WM_DESTROY:
    begin
      save_reg_entries;
      KillThread:=TRUE;
      killcount:=0;
      Sleep(0);
      SetPriorityClass(ThreadHandle,HIGH_PRIORITY_CLASS);
      if InThread then while TestThread do begin
        inc(killcount);
        if killcount>2 then begin
          // this is a nasty way of getting out.
          // sometimes the thread just will not exit nicely when its busy.
          if TerminateThread(ThreadHandle,1) then begin
            CloseHandle(ThreadHandle); break;
          end;
        end;
      end;
      DeleteCriticalSection(cs);
      PostQuitMessage(0);
    end;
   WM_SIZE:
    begin
      if wParam=SIZE_MAXIMIZED then options.winmax:=true
      else if wParam=SIZE_RESTORED then options.winmax:=false;
      mainwndsize.top:=0;
      mainwndsize.left:=0;
      mainwndsize.right:=LOWORD(lParam);
      mainwndsize.bottom:=HIWORD(lParam);
      GetWindowRect(hwndStatusBar,StatusWindowSize);
      GetWindowRect(mainwindow,mainwnd);
      MoveWindow(hwndStatusBar,0,mainwndsize.bottom-StatusWindowSize.bottom+StatusWindowSize.top,
      mainwndsize.right,StatusWindowSize.bottom-StatusWindowSize.top,TRUE);
    end;
   WM_VSCROLL:
    case LOWORD(wParam) of
     SB_TOP: ;
     SB_BOTTOM: ;
     SB_LINEUP:
      begin
        scrll.s:=0; scrll.o:=dword(-1);
        if InThread
        then scheduler.addtask(scrolling,priority_userrequest,scrll,0,nil);
      end;
     SB_LINEDOWN:
      begin
        scrll.s:=0; scrll.o:=1;
        if InThread
        then scheduler.addtask(scrolling,priority_userrequest,scrll,0,nil);
      end;
     SB_PAGEUP:
      begin
        scrll.s:=0; scrll.o:=-mainwndsize.bottom div cyChar+1;
        if InThread
        then scheduler.addtask(scrolling,priority_userrequest,scrll,0,nil);
      end;
     SB_PAGEDOWN:
      begin
        scrll.s:=0; scrll.o:=mainwndsize.bottom div cyChar-1;
        if InThread
        then scheduler.addtask(scrolling,priority_userrequest,scrll,0,nil);
      end;
     SB_THUMBPOSITION:
      begin
        scrll.s:=0; scrll.o:=HIWORD(wParam);
        if InThread
        then scheduler.addtask(vthumbposition,priority_userrequest,scrll,0,nil);
      end;
     end;
   WM_HSCROLL:
    case LOWORD(wParam) of
     SB_LINEUP:
      begin
        scrll.s:=0; scrll.o:=dword(-1);
        scheduler.addtask(hscroll,priority_userrequest,scrll,0,nil);
      end;
     SB_LINEDOWN:
      begin
        scrll.s:=0; scrll.o:=1;
        scheduler.addtask(hscroll,priority_userrequest,scrll,0,nil);
      end;
     SB_PAGEUP:
      begin
        scrll.s:=0; scrll.o:=dword(-8);
        scheduler.addtask(hscroll,priority_userrequest,scrll,0,nil);
      end;
     SB_PAGEDOWN:
      begin
        scrll.s:=0; scrll.o:=8;
        scheduler.addtask(hscroll,priority_userrequest,scrll,0,nil);
      end;
     SB_THUMBPOSITION:
      begin
        scrll.s:=0; scrll.o:=HIWORD(wParam);
        if InThread
        then scheduler.addtask(hthumbposition,priority_userrequest,scrll,0,nil);
      end;
    end;
    // maximises window, used when the reg is read in at the start to maximise
    // the main window after initialisation of it
   WM_REPEATNAMEVIEW: namesviewer;
   WM_REPEATXREFVIEW: xrefsviewer;
   WM_MAXITOUT:  ShowWindow(mainwindow,SW_MAXIMIZE);
   WM_CREATE:
    begin
      optionsinit;
      dc:=GetDC(wnd);
      SelectObject(dc,GetStockObject(ANSI_FIXED_FONT));
      GetTextMetrics(dc,tm);
      cxChar:=tm.tmAveCharWidth;
      cyChar:=tm.tmHeight+tm.tmExternalLeading;
      ReleaseDC(wnd,dc);
      InitializeCriticalSection(cs);
      hwndStatusBar:=CreateStatusWindow(WS_CHILD or WS_VISIBLE or WS_CLIPSIBLINGS or CCS_BOTTOM,
       'No File Loaded',wnd,2);
      GetWindowRect(hwndStatusBar,StatusWindowSize);
      GetWindowRect(mainwindow,mainwnd);
      SetScrollRange(wnd,SB_VERT,0,VERTSCROLLRANGE,FALSE);
      SetScrollPos(wnd,SB_VERT,0,FALSE);
      KillThread:=FALSE;
      InThread:=FALSE;
      rmenu:=LoadMenu(Inst,MAKEINTRESOURCE(right_click_menu));
      rmenu:=GetSubMenu(rmenu,0);
      load_reg_entries;
      setupfont;
    end;
   WM_KEYDOWN:
    if charinputenabled then case wParam of
     VK_HOME:    SendMessage(wnd,WM_VSCROLL,SB_TOP,0);
     VK_PRIOR:   SendMessage(wnd,WM_VSCROLL,SB_PAGEUP,0);
     VK_NEXT:    SendMessage(wnd,WM_VSCROLL,SB_PAGEDOWN,0);
     VK_DOWN:    SendMessage(wnd,WM_VSCROLL,SB_LINEDOWN,0);
     VK_UP:      SendMessage(wnd,WM_VSCROLL,SB_LINEUP,0);
     VK_LEFT:    SendMessage(wnd,WM_HSCROLL,SB_PAGEUP,0);
     VK_RIGHT:   SendMessage(wnd,WM_HSCROLL,SB_PAGEDOWN,0);
     VK_RETURN:
      begin
        if GetKeyState(VK_SHIFT) and $8000<>0 then
          scheduler.addtask(user_jumptoarg2,priority_userrequest,nlptr,0,nil)
        else
          scheduler.addtask(user_jumpto,priority_userrequest,nlptr,0,nil);
      end;
     VK_ESCAPE:
      scheduler.addtask(user_jumpback,priority_userrequest,nlptr,0,nil);
     VK_F1:
      DialogBox(Inst,MAKEINTRESOURCE(help_shortcuts),wnd,@helpshortcuts);
     VK_F3: searchmore;
    end;
   else result:=DefWindowProc(wnd,msg,wParam,lParam);
  end;
end;

function WinMain(hThisInst,hPrevInst:HINST; lpszArgs:pchar; nWinMode:integer):integer;
var
  wnd:HWND;
  msg:tMSG;
  wcl:tWNDCLASSEX;
  cx,cy:integer;
begin
  InitCommonControls;
  cx:=GetSystemMetrics(SM_CXFULLSCREEN);
  cy:=GetSystemMetrics(SM_CYFULLSCREEN);
  fillchar(wcl,sizeof(wcl),0);
  wcl.hInstance:=hThisInst;
  wcl.lpszClassName:='Dasm';
  wcl.lpfnWndProc:=@dasm;
  wcl.style:=CS_DBLCLKS or CS_HREDRAW or CS_VREDRAW;
  wcl.cbSize:=sizeof(tWNDCLASSEX);
  wcl.hIcon:=LoadIcon(0,IDI_APPLICATION);
  wcl.hIconSm:=LoadIcon(0,IDI_WINLOGO);
  wcl.hCursor:=LoadCursor(0,IDC_ARROW);
  wcl.lpszMenuName:=MAKEINTRESOURCE(main_menu);
  wcl.cbClsExtra:=0;
  wcl.cbWndExtra:=0;
  wcl.hbrBackground:=0;
  Inst:=hThisInst;
  if RegisterClassEx(wcl)=0 then begin result:=0; exit; end;
  strlfmt(@winname,300,'Borg Disassembler v%0d.%2d',[BORG_VER div 100,BORG_VER mod 100]);
  wnd:=CreateWindow('Dasm',@winname,WS_OVERLAPPEDWINDOW,
    (cx div 2)-320,(cy div 2)-230,640,480,0,0,hThisInst,nil);
  mainwndsize.top:=0;
  mainwndsize.left:=0;
  mainwndsize.bottom:=cy-1;
  mainwndsize.right:=cx-1;
  ShowWindow(wnd,nWinMode);
  UpdateWindow(wnd);
  while GetMessage(msg,0,0,0) do begin
    TranslateMessage(msg);
    DispatchMessage(msg);
  end; result:=msg.wParam;
end;

begin
  @database.Changemenus:=@Changemenus;
  @dlg_load.Changemenus:=@Changemenus;
  @database.Thread:=@Thread;
  @dlg_load.Thread:=@Thread;
  UseCompression:=true;
  WinMain(hInstance,0,nil,1);
end.

