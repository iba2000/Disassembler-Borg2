unit savefile;
interface
uses windows,common;
// File I/O for saving to and reading from database files only.          *
// Added in version 2.11. Compression is implemented based on rle, but   *
// it is nibble based (2*nibbles=byte) rather than byte based. I decided *
// on this after closer examination of the database files. It results in *
// around a 30% reduction to the database file size.                     *
const
  RBUFF_MAXLEN =4096;
  rle_code     =$0f;
  numwriten:integer=0;

type
  tsavefile=class
    compr:boolean;
  private
    sfile:dword;
    rbufflen:long;
    rbuffptr:dword;
    rbuff:array[0..RBUFF_MAXLEN+1] of char;
    rbhigh:boolean;
    rlemode:boolean;
    rlestart:boolean;
    rlecount:byte;
    rlebyte:byte;
  private
    function getnibble(var n:byte):boolean;
    function getrlenibble(var n:byte):boolean;
    function putnibble(n:byte):boolean;
    function flushnibble:boolean;
    function putrlenibble(n:byte):boolean;
    function flushrlenibble:boolean;
  public
    constructor create;
    destructor destroy;override;
    function sopen(lpFileName:pchar; dwDesiredAccess,dwShareMode,
      dwCreationDistribution,dwFlagsAndAttributes:dword):boolean;
    procedure sclose;
    function sread(lpBuffer:pchar;nNumberOfBytesToRead:integer; var lpNumberOfBytesRead:integer):boolean;
    function swrite(lpBuffer:pchar; nNumberOfBytesToWrite:integer):boolean;
    function flushfilewrite:boolean;
  end;

implementation

constructor tsavefile.create;
begin
  inherited create;
  sfile:=dword(INVALID_HANDLE_VALUE);
  rbufflen:=0;
  rbuffptr:=0;
  rbhigh:=TRUE;
  rlecount:=0;
  rlemode:=FALSE;
  rlestart:=TRUE;
  compr:=usecompression;
  numwriten:=0;
end;

destructor tsavefile.destroy;
begin
  sclose;
  inherited destroy;
end;

// sopen                                                                 *
// - opens the database file and returns TRUE on success                 *
function tsavefile.sopen(lpFileName:pchar; dwDesiredAccess,dwShareMode,
  dwCreationDistribution,dwFlagsAndAttributes:dword):boolean;
begin
  result:=false;
  sfile:=CreateFile(lpFileName,dwDesiredAccess,dwShareMode,nil,
        dwCreationDistribution,dwFlagsAndAttributes,0);
  if sfile=INVALID_HANDLE_VALUE then begin
    MessageBox(mainwindow,'File open failed ?',lpFileName,MB_OK or MB_ICONEXCLAMATION);
    exit;
  end;
  if SysfileIsDevice_(sfile)<>FILE_TYPE_DISK then begin
    MessageBox(mainwindow,'File open failed ?',lpFileName,MB_OK or MB_ICONEXCLAMATION);
    sclose;
    exit;
  end;
  result:=TRUE;
end;

// sclose                                                                *
// - closes the database file if still open                              *
procedure tsavefile.sclose;
begin
  if sfile<>INVALID_HANDLE_VALUE then CloseHandle(sfile);
end;

// getnibble                                                             *
// - This function sets n to the next nibble from the file, it uses      *
//   buffering and reads from the file as required                       *
function tsavefile.getnibble(var n:byte):boolean;
var rval:boolean;
begin
  result:=true;
  if rbuffptr<rbufflen then begin
    if rbhigh then begin
      n:=byte(rbuff[rbuffptr]) shr 4;
      rbhigh:=FALSE;
      exit;
    end;
    n:=byte(rbuff[rbuffptr]) and $0f;
    rbhigh:=TRUE;
    inc(rbuffptr);
    exit;
  end else begin
    rval:=ReadFile(sfile,rbuff,RBUFF_MAXLEN,rbufflen,nil);
    rbhigh:=TRUE;
    rbuffptr:=0;
    if rval and(rbufflen<>0) then begin result:=getnibble(n); exit; end;
    result:=FALSE;
  end;
end;

// getrlenibble                                                          *
// - this function sets n to the next nibble from the file, taking into  *
//   account rle encoding. So this returns the next uncompressed nibble  *
// - rle encoding is:                                                    *
//   rle_code count nibble                                               *
//   count is number-1 (so it can encode from 2 to 16 nibbles)           *
//   or rle_code 0 signifies a nibble equal to rle_code                  *
// - note that rle_code is a constant specified in the savefile.h which  *
//   indicates an rle encoding, and is currently 0x0f. Do not set this   *
//   constant to 0 as this would be inefficient....                      *
function tsavefile.getrlenibble(var n:byte):boolean;
begin
  result:=true;
  if rlemode then begin
    dec(rlecount);
    if rlecount=0 then rlemode:=FALSE;
    n:=rlebyte;
    exit;
  end;
  if not getnibble(rlebyte) then begin result:=FALSE; exit; end;
  if rlebyte=rle_code then begin
    if not getnibble(rlebyte) then begin result:=FALSE; exit; end;
    if rlebyte<>0 then begin
      rlecount:=rlebyte;
      rlemode:=TRUE;
      if not getnibble(rlebyte) then begin result:=FALSE; exit; end;
      n:=rlebyte;
      exit;
    end;
    n:=rle_code;
    exit;
  end;
  n:=rlebyte;
end;

// putnibble                                                             *
// - The opposite function to getnibble, it writes one nibble to the     *
//   file using buffering                                                *
function tsavefile.putnibble(n:byte):boolean;
var
  rval:boolean;
  num:long;
begin
  result:=TRUE;
  if rbuffptr<RBUFF_MAXLEN then begin
    if rbhigh then begin
      byte(rbuff[rbuffptr]):=(n and $0f) shl 4;
      rbhigh:=FALSE;
      inc(rbufflen);
      exit;
    end;
    inc(rbuff[rbuffptr],n and $0f);
    rbhigh:=TRUE;
    inc(rbuffptr);
  end else begin
    rval:=WriteFile(sfile,rbuff,RBUFF_MAXLEN,num,nil);
    rbhigh:=TRUE;
    rbuffptr:=0;
    rbufflen:=0;
    if rval then begin result:=putnibble(n); exit; end;
    result:=FALSE;
  end;
end;

// flushnibble                                                           *
// - A necessity of buffered writing, this flushes the remainder of the  *
//   buffer, writing it out to file                                      *
function tsavefile.flushnibble:boolean;
var num:long;
begin
  if rbufflen<>0 then result:=WriteFile(sfile,rbuff,rbufflen,num,nil)
  else result:=TRUE;
end;

// putrlenibble                                                          *
// - This is the opposite function to getrlenibble. It writes nibbles to *
//   file whilst performing the compression. The rle encoding happens    *
//   here and when nibbles are ready to be written the putnibble         *
//   function is called                                                  *
function tsavefile.putrlenibble(n:byte):boolean;
begin
  result:=FALSE;
  if rlestart then begin
    rlestart:=FALSE;
    rlebyte:=n;
    result:=TRUE; exit;
  end;
  if rlemode then begin
    if (rlebyte=n)and(rlecount<$0f) then begin
      inc(rlecount);
      result:=TRUE; exit;
    end;
    if not putnibble(rle_code) then exit;
    if not putnibble(rlecount) then exit;
    if not putnibble(rlebyte)  then exit;
    rlemode:=FALSE;
    rlebyte:=n;
    result:=TRUE; exit;
  end;
  if rlebyte=n then begin
    rlemode:=TRUE;
    rlecount:=1;
    result:=TRUE; exit;
  end;
  if not putnibble(rlebyte) then exit;
  if rlebyte=rle_code then if not putnibble(0) then exit;
  rlebyte:=n;
  result:=TRUE;
end;

// flushrlenibble                                                        *
// - This flushes any partial rle at the end of a file and forces it to  *
//   the putnibble function                                              *
function tsavefile.flushrlenibble:boolean;
begin
  result:=false;
  if rlemode then begin
    if not putnibble(rle_code) then exit;
    if not putnibble(rlecount) then exit;
    if not putnibble(rlebyte)  then exit;
  end else begin
    if not putnibble(rlebyte) then exit;
    if rlebyte=rle_code then if not putnibble(0) then exit;
  end;
  result:=TRUE;
end;

// flushfilewrite                                                        *
// - The function to flush writing which should be called at the end of  *
//   the save. It flushes any partial encoding and then flushes the      *
//   buffered write                                                      *
function tsavefile.flushfilewrite:boolean;
begin
  if not compr then begin result:=true; exit end;
  if not flushrlenibble then result:=FALSE else result:=flushnibble;
end;

// sread                                                                 *
// - This is the external call for reading from a file. Its a similar    *
//   format to ReadFile, and uses the rle compression routines           *
function tsavefile.sread(lpBuffer:pchar; nNumberOfBytesToRead:integer; var lpNumberOfBytesRead:integer):boolean;
var
  n:byte;
  num:long;
begin
  result:=false;
  lpNumberOfBytesRead:=0;
  if not compr then begin
    result:=ReadFile(sfile,lpBuffer^,nNumberOfBytesToRead,num,nil);
    lpNumberOfBytesRead:=num; exit;
  end;
  for num:=0 to nNumberOfBytesToRead-1 do begin
    if not getrlenibble(n) then exit;
    byte(lpBuffer[num]):=n shl 4;
    if not getrlenibble(n) then exit;
    inc(lpBuffer[num],n);
    inc(lpNumberOfBytesRead);
  end;
  result:=TRUE;
end;

// swrite                                                                *
// - This is the external call for writing to a file. Its a similar      *
//   format to WriteFile, and uses the rle compression routines          *
function tsavefile.swrite(lpBuffer:pchar; nNumberOfBytesToWrite:integer):boolean;
var num:long;
begin
  result:=false;
  if not compr then begin
    result:=WriteFile(sfile,lpBuffer^,nNumberOfBytesToWrite,num,nil);
    inc(numwriten,num); exit;
  end;
  for num:=0 to nNumberOfBytesToWrite-1 do begin
    if not putrlenibble(byte(lpBuffer[num]) shr 4)  then exit;
    if not putrlenibble(byte(lpBuffer[num]) and $0f)then exit;
  end;
  result:=TRUE;
end;

begin
end.

