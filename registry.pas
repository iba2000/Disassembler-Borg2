unit registry;
interface
uses windows,sysutils,common;
{************************************************************************
* - functions for saving and loading Borgs settings in the registry     *
************************************************************************}

procedure load_reg_entries;
procedure save_reg_entries;

implementation
const
  reg_borg:pchar='Software\Borg';

{************************************************************************
* load_reg_entries                                                      *
* - Loads Borgs saved settings from the registry :)                     *
* - these are just colours, fonts, version, directory and window status *
* - settings are then restored                                          *
************************************************************************}
procedure load_reg_entries;
var
  regkey:HKEY;
  disposition:dword;
  rver,dsize:dword;
  cl:COLORREF;
  fs:fontselection;
  cdir:array[0..MAX_PATH] of char;
begin
  if RegCreateKeyEx(HKEY_CURRENT_USER,reg_borg,0,'',REG_OPTION_NON_VOLATILE,
    KEY_ALL_ACCESS,nil,regkey,@disposition)<>ERROR_SUCCESS then exit;
  if disposition=REG_CREATED_NEW_KEY then begin
    RegCloseKey(regkey); exit;
  end;
  dsize:=sizeof(rver);
  rver:=0;
  RegQueryValueEx(regkey,'Version',nil,nil,@rver,@dsize);
  cdir[0]:=#0;
  dsize:=MAX_PATH;
  RegQueryValueEx(regkey,'Curdir',nil,nil,@cdir,@dsize);
  if cdir[0]<>#0 then SetCurrentDirectory(cdir);
  dsize:=sizeof(options.winmax);
  RegQueryValueEx(regkey,'Winmax',nil,nil,@options.winmax,@dsize);
  if options.winmax then PostMessage(mainwindow,WM_MAXITOUT,0,0);
  dsize:=sizeof(cl);
  if RegQueryValueEx(regkey,'BackgroundColor',nil,nil,@cl,@dsize)=ERROR_SUCCESS
  then options.bgcolor:=cl;
  if RegQueryValueEx(regkey,'HighlightColor',nil,nil,@cl,@dsize)=ERROR_SUCCESS
  then options.highcolor:=cl;
  if RegQueryValueEx(regkey,'TextColor',nil,nil,@cl,@dsize)=ERROR_SUCCESS
  then options.textcolor:=cl;
  if RegQueryValueEx(regkey,'Font',nil,nil,@fs,@dsize)=ERROR_SUCCESS
  then options.font:=dword(fs);
  RegCloseKey(regkey);
  if rver<>BORG_VER then begin
    RegCloseKey(regkey);
    RegDeleteKey(HKEY_CURRENT_USER,reg_borg);
    save_reg_entries;
  end;
end;

{************************************************************************
* save_reg_entries                                                      *
* - Saves Borgs settings to the registry :)                             *
* - these are just colours, fonts, version, directory and window status *
************************************************************************}
procedure save_reg_entries;
var
  regkey:HKEY;
  disposition:DWORD;
  rver,dsize:dword;
  cdir:array[0..MAX_PATH] of char;
begin
  if RegCreateKeyEx(HKEY_CURRENT_USER,reg_borg,0,'',REG_OPTION_NON_VOLATILE,
    KEY_ALL_ACCESS,nil,regkey,@disposition)<>ERROR_SUCCESS then exit;
  dsize:=sizeof(rver);
  rver:=BORG_VER;
  RegSetValueEx(regkey,'Version',0,REG_DWORD,@rver,dsize);
  GetCurrentDirectory(MAX_PATH,cdir);
  dsize:=strlen(cdir)+1;
  RegSetValueEx(regkey,'Curdir',0,REG_SZ,@cdir,dsize);
  dsize:=sizeof(options.winmax);
  RegSetValueEx(regkey,'Winmax',0,REG_DWORD,@options.winmax,dsize);
  dsize:=sizeof(COLORREF);
  RegSetValueEx(regkey,'BackgroundColor',0,REG_DWORD,@options.bgcolor,dsize);
  RegSetValueEx(regkey,'HighlightColor',0,REG_DWORD,@options.highcolor,dsize);
  RegSetValueEx(regkey,'TextColor',0,REG_DWORD,@options.textcolor,dsize);
  RegSetValueEx(regkey,'Font',0,REG_DWORD,@options.font,sizeof(fontselection));
  RegCloseKey(regkey);
end;

begin
end.


