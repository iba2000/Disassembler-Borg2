unit exeload;
interface
uses classes,sysutils,windows,common,menus,gname,savefile,datas,
     relocs,xref,schedule,proctab;
{************************************************************************
* Contains the executable file load routines and setting up of the      *
* disassembly for the files..                                           *
************************************************************************}
const
  fmt4:pchar='%4.4x';
  fmt8:pchar='%8.8x';
  PE_EXE  =1;
  MZ_EXE  =2;
  OS2_EXE =3;
  COM_EXE =5;
  NE_EXE  =6;
  SYS_EXE =7;
  LE_EXE  =8;
  BIN_EXE =9;

type
  pmzheader=^tmzheader;
  tmzheader=packed record
    sig:word;
    numbytes,numpages:word;
    numrelocs,headersize:word;
    minpara,maxpara:word;
    initialss,initialsp:word;
    csum:word;
    csip:dword;
    relocoffs:word;
    ovlnum:word;
  end;

  pneheader=^tneheader;
  tneheader=packed record
    sig:word;
    linkerver:word;
    entryoffs,entrylen:word;
    filecrc:dword;
    contentflags:word;
    dsnum:word;
    heapsize,stacksize:word;
    csip,sssp:dword;
    numsegs,nummodules:word;
    nonresnamesize:word;
    offs_segments,offs_resources,offs_resnames,offs_module,offs_imports:word;
    nonresnametable:dword;
    movableentries:word;
    shiftcount:word;
    numresources:word;
    targetos,os_info:byte;
    fastloadoffs,fastloadlen:word;
    mincodeswapareasize,winver:word;
  end;

  pnesegtable=^tnesegtable;
  tnesegtable=packed record
    sectoroffs:word;
    seglength:word;
    segflags:word;
    minalloc:word;
  end;
  pnesegtablearr=^tnesegtablearr;
  tnesegtablearr=array[0..100] of tnesegtable;


  pnesegtablereloc=^tnesegtablereloc;
  tnesegtablereloc=packed record
    reloctype,relocsort:byte;
    segm_offs:word;
    indx,indexoffs:word;
  end;
  pnesegtablerelocarr=^tnesegtablerelocarr;
  tnesegtablerelocarr=array[0..100] of tnesegtablereloc;

  ppeheader=^tpeheader;
  tpeheader=packed record
    sigbytes:dword;
    cputype,objects:word;
    timedatestamp:dword;
    reserveda:array[0..1] of dword;
    nt_hdr_size,flags:word; //?
    reserved:word; //?
    lmajor,lminor:byte;
    reserved1:array[0..2] of dword;
    entrypoint_rva:dword;
    reserved2:array[0..1] of dword;
    image_base:dword;
    objectalign:dword;
    filealign:dword;
    osmajor,osminor:word;
    usermajor,userminor:word;
    subsysmajor,subsysminor:word;
    reserved3:dword;
    imagesize:dword;
    headersize:dword;
    filechecksum:dword;
    subsystem,dllflags:word;
    stackreserve,stackcommit:dword;
    heapreserve,heapcommit:dword;
    reserved4:dword;
    numintitems:dword;
    exporttable_rva,export_datasize:dword;
    importtable_rva,import_datasize:dword;
    resourcetable_rva,resource_datasize:dword;
    exceptiontable_rva,exception_datasize:dword;
    securitytable_rva,security_datasize:dword;
    fixuptable_rva,fixup_datasize:dword;
    debugtable_rva,debug_directory:dword;
    imagedesc_rva,imagedesc_datasize:dword;
    machspecific_rva,machspecific_datasize:dword;
    tls_rva,tls_datasize:dword;
  end;

  tpeobjdata=packed record
    nam:array[0..7] of char;
    virt_size,rva:dword;
    phys_size,phys_offset:dword;
    reserved:array[0..2] of dword;
    obj_flags:dword;
  end;
  ppeobjdata=^tpeobjdataa;
  tpeobjdataa=array[0..100] of tpeobjdata;

  tpeimportdirentry=packed record
    originalthunkrva:dword;
    timedatestamp:dword;
    forwarder:dword;
    namerva:dword;
    firstthunkrva:dword;
  end;
  ppeimportdirentry=^tpeimportdirentrya;
  tpeimportdirentrya=array[0..100] of tpeimportdirentry;

  ppeexportdirentry=^tpeexportdirentry;
  tpeexportdirentry=packed record
    characteristics:dword;
    timedatestamp:dword;
    majver,minver:word;
    namerva:dword;
    base:dword;
    numfunctions:dword;
    numnames:dword;
    funcaddrrva,nameaddrrva,ordsaddrrva:dword;
  end;

  pperestable=^tperestable;
  tperestable=packed record
    flags:dword;
    timedatestamp:dword;
    majver,minver:word;
    numnames,numids:word;
  end;

  ppeleafnode=^tpeleafnode;
  tpeleafnode=packed record
    datarva:dword;
    size:dword;
    codepage:dword;
    reserved:dword;
  end;

  pperestableentry=^tperestableentry;
  tperestableentry=packed record
    id:dword;
    offset:dword;
  end;

  pperelocheader=^tperelocheader;
  tperelocheader=packed record
    rva:dword;
    len:dword;
  end;

//loads file and sets up objects using data.cpp
type
  tfileloader=class
    exetype:integer;
    efile:dword;
    fbuff:pchar;
  private
    rawdata:pchar;
    pdatarva:dword;
    peh:ppeheader;
  public
    constructor create;
    destructor destroy;override;
    function getexetype:integer;
    procedure setexetype(etype:integer);
    function fileoffset(loc:lptr):dword;
    procedure patchfile(file_offs,num:dword; dat:pchar);
    procedure reloadfile(file_offs,num:dword; dat:pchar);
    procedure readcomfile(fsize:dword);
    procedure readsysfile(fsize:dword);
    procedure readpefile(offs:dword);
    procedure readmzfile(fsize:dword);
    procedure readlefile;
    procedure readnefile(offs:dword);
    procedure reados2file;
    procedure readbinfile(fsize:dword);
    procedure patchoep;
  private
    procedure subdirsummary(data,impname:pchar; image_base:dword; rtype:dword);
    procedure leaf2summary(data,nam:pchar; image_base:dword; rtype:dword);
    procedure leafnodesummary(data,resname:pchar; image_base:dword; rtype:dword);
  end;

var
  floader:tfileloader;

implementation
uses disasm,disio,decrypt;

constructor tfileloader.create;
begin
  inherited create;
  efile:=dword(INVALID_HANDLE_VALUE);
  exetype:=0;
  fbuff:=nil;
end;

destructor tfileloader.destroy;
begin
  if fbuff<>nil then dispose(fbuff);
  CloseHandle(efile);
end;

function tfileloader.getexetype;
begin
  result:=exetype;
end;

procedure tfileloader.setexetype(etype:integer);
begin
  exetype:=etype;
end;

{************************************************************************
* fileoffset                                                            *
* - function which returns the offset in a file of a given location,    *
*   this is to enable file patching given a location to patch           *
* - added in Borg v2.19                                                 *
************************************************************************}
function tfileloader.fileoffset(loc:lptr):dword;
var ds:pdsegitem;
begin
  result:=0;
  ds:=dta.findseg(loc);
  if ds=nil then exit;
  result:=(loc.o-ds.addr.o)+(ds.data-fbuff);
end;

{************************************************************************
* patchfile                                                             *
* - writes to the currently open file (does not check it is opened with *
*   write access), given the number of bytes, data, and file offset to  *
*   write to.                                                           *
* - added in Borg v2.19                                                 *
************************************************************************}
procedure tfileloader.patchfile(file_offs,num:dword; dat:pchar);
var written:long;
begin
  if efile=INVALID_HANDLE_VALUE then begin
    MessageBox(0,'File I/O Error - Invalid Handle for writing','Borg Message',MB_OK);
    exit;
  end;
  SetFilePointer(efile,file_offs,nil,FILE_BEGIN);
  WriteFile(efile,dat,num,written,nil);
end;

{************************************************************************
* patchoep                                                              *
* - writes to the currently open file (does not check it is opened with *
*   write access), given the new oep for the file is in options.oep     *
* - added in Borg v2.28                                                 *
************************************************************************}
procedure tfileloader.patchoep;
begin
  if exetype<>PE_EXE then exit;
  peh.entrypoint_rva:=options.oep.o-peh.image_base;
  patchfile(@peh.entrypoint_rva-fbuff,4,@peh.entrypoint_rva);
end;

{************************************************************************
* reloadfile                                                            *
* - reads part of a file back in, given the file offset, number of      *
*   bytes and data buffer to read it in to. Used in the decryptor when  *
*   reloading a database file.                                          *
************************************************************************}
procedure tfileloader.reloadfile(file_offs,num:dword; dat:pchar);
var rd:long;
begin
  if efile=INVALID_HANDLE_VALUE then begin
    MessageBox(0,'File I/O Error - Invalid Handle for reading','Borg Message',MB_OK);
    exit;
  end;
  SetFilePointer(efile,file_offs,nil,FILE_BEGIN);
  ReadFile(efile,dat,num,rd,nil);
end;


{************************************************************************
* readcomfile                                                           *
* - one of the simpler exe format loading routines, we just need to     *
*   load the file and disassemble from the start with an offset of      *
*   0x100                                                               *
************************************************************************}
procedure tfileloader.readcomfile(fsize:dword);
begin
  options.loadaddr.o:=$100;
  options.dseg:=options.loadaddr.s;
  dta.addseg(options.loadaddr,fsize,fbuff,code16,nil);
  dta.possibleentrycode(options.loadaddr);
  options.mode16:=TRUE;
  options.mode32:=FALSE;
  dio.setcuraddr(options.loadaddr);
  scheduler.addtask(dis_code,priority_definitecode,options.loadaddr,0,nil);
  scheduler.addtask(nameloc,priority_nameloc,options.loadaddr,0,'start');
  scheduler.addtask(windowupdate,priority_window,nlptr,0,nil);
end;

{************************************************************************
* readsysfile                                                           *
* - very similar to the com file format, but the start offset is 0x00   *
* - detailed sys format below: (since so few documents seem to give the *
*   information correctly)                                              *
*                                                                       *
* Device Header                                                         *
*                                                                       *
* The device header is an extension to what is described in the MS-PRM. *
*                                                                       *
* DevHdr DD -1 ; Ptr to next driver in file or -1 if last driver        *
* DW ? ; Device attributes                                              *
* DW ? ; Device strategy entry point                                    *
* DW ? ; Device interrupt entry point                                   *
* DB 8 dup (?) ; Character device name field                            *
* DW 0 ; Reserved                                                       *
* DB 0 ; Drive letter                                                   *
* DB ? ; Number of units                                                *
*                                                                       *
* A device driver requires a device header at the beginning of the      *
* file.                                                                 *
*                                                                       *
* POINTER TO NEXT DEVICE HEADER FIELD                                   *
*                                                                       *
* The device header field is a pointer to the device header of the next *
* device driver. It is a doubleword field that is set by DOS at the     *
* time the device driver is loaded. The first word is an offset and the *
* second word is the segment. If you are loading only one device        *
* driver, set the device header field to -1 before loading the device.  *
* If you are loading more than one device driver, set the first word of *
* the device driver header to the offset of the next device driver's    *
* header. Set the device driver header field of the last device driver  *
* to -1.                                                                *
*                                                                       *
* ATTRIBUTE FIELD                                                       *
*                                                                       *
* The attribute field is a word field that describes the attributes of  *
* the device driver to the system. The attributes are:                  *
*                                                                       *
* word bits (decimal)                                                   *
*  15   1   character device                                            *
*       0   block device                                                *
*  14   1   supports IOCTL                                              *
*       0   doesn't support IOCTL                                       *
*  13   1   non-IBM format (block only)                                 *
*       0   IBM format                                                  *
*  12       not documented - unknown                                    *
*  11   1   supports removeable media                                   *
*       0   doesn't support removeable media                            *
*  10       reserved for DOS                                            *
*    through                                                            *
*   4       reserved for DOS                                            *
*   3   1   current block device                                        *
*       0   not current block device                                    *
*   2   1   current NUL device                                          *
*       0   not current NUL device                                      *
*   1   1   current standard output device                              *
*       0   not current standard output device                          *
*                                                                       *
* BIT 15 is the device type bit. Use it to tell the system the that     *
* driver is a block or character device.                                *
*                                                                       *
* BIT 14 is the IOCTL bit. It is used for both character and block      *
* devices. Use it to tell DOS whether the device driver can handle      *
* control strings through the IOCTL function call 44h.                  *
* If a device driver cannot process control strings, it should set bit  *
* 14 to 0. This way DOS can return an error is an attempt is made       *
* through the IOCTL function call to send or receive control strings to *
* the device. If a device can process control strings, it should set    *
* bit 14 to 1. This way, DOS makes calls to the IOCTL input and output  *
* device function to send and receive IOCTL strings.                    *
* The IOCTL functions allow data to be sent to and from the device      *
* without actually doing a normal read or write. In this way, the       *
* device driver can use the data for its own use, (for example, setting *
* a baud rate or stop bits, changing form lengths, etc.) It is up to    *
* the device to interpret the information that is passed to it, but the *
* information must not be treated as a normal I/O request.              *
*                                                                       *
* BIT 13 is the non-IBM format bit. It is used for block devices only.  *
* It affects the operation of the Get BPB (BIOS parameter block) device *
* call.                                                                 *
*                                                                       *
* BIT 11 is the open/close removeable media bit. Use it to tell DOS if  *
* the device driver can handle removeable media. (DOS 3.x only)         *
*                                                                       *
* BIT 3 is the clock device bit. It is used for character devices only. *
* Use it to tell DOS if your character device driver is the new CLOCK$  *
* device.                                                               *
*                                                                       *
* BIT 2 is the NUL attribute bit. It is used for character devices      *
* only. Use it to tell DOS if your character device driver is a NUL     *
* device. Although there is a NUL device attribute bit, you cannot      *
* reassign the NUL device. This is an attribute that exists for DOS so  *
* that DOS can tell if the NUL device is being used.                    *
*                                                                       *
* BIT 0 are the standard input and output bits. They are used for       *
* character & devices only. Use these bits to tell DOS if your          *
* character device                                                      *
*                                                                       *
* BIT 1 driver is the new standard input device or standard output      *
* device.                                                               *
*                                                                       *
* POINTER TO STRATEGY AND INTERRUPT ROUTINES                            *
*                                                                       *
* These two fields are pointers to the entry points of the strategy and *
* input routines. They are word values, so they must be in the same     *
* segment as the device header.                                         *
*                                                                       *
* NAME/UNIT FIELD                                                       *
*                                                                       *
* This is an 8-byte field that contains the name of a character device  *
* or the unit of a block device. For the character names, the name is   *
* left-justified and the space is filled to 8 bytes. For block devices, *
* the number of units can be placed in the first byte. This is optional *
* because DOS fills in this location with the value returned by the     *
* driver's INIT code.                                                   *
************************************************************************}
procedure tfileloader.readsysfile(fsize:dword);
var
  t:lptr;
  done:boolean;
  devhdr,devlength:word;
begin
  options.loadaddr.o:=0;
  options.dseg:=options.loadaddr.s;
  dta.addseg(options.loadaddr,fsize,fbuff,code16,nil);
  dta.possibleentrycode(options.loadaddr);
  options.mode16:=true;
  options.mode32:=false;
  dio.setcuraddr(options.loadaddr);
  done:=false;
  devhdr:=0;
  while not done do begin
    t.s:=options.loadaddr.s; t.o:=devhdr;
    scheduler.addtask(dis_dataword,priority_data,t,0 ,nil);
    scheduler.addtask(dis_dataword,priority_data,t,2 ,nil);
    scheduler.addtask(dis_dataword,priority_data,t,4 ,nil);
    scheduler.addtask(dis_dataword,priority_data,t,6 ,nil);
    scheduler.addtask(dis_dataword,priority_data,t,8 ,nil);
    scheduler.addtask(dis_dataword,priority_data,t,18,nil);
    if (pw(@fbuff[3])^<>0)and(pw(@fbuff[3])^<fsize) then begin
      t.s:=options.loadaddr.s; t.o:=pw(@fbuff[devhdr+3])^+devhdr;
      if t.o<>0 then begin
        scheduler.addtask(dis_code,priority_definitecode,t,0,nil);
        scheduler.addtask(nameloc,priority_nameloc,t,0,'strategy');
      end;
    end;
    if (pw(@fbuff[4])^<>0)and(pw(@fbuff[4])^<fsize) then begin
      t.s:=options.loadaddr.s; t.o:=pw(@fbuff[devhdr+4])^;
      if t.o<>0 then begin
        scheduler.addtask(dis_code,priority_definitecode,t,0,nil);
        scheduler.addtask(nameloc,priority_nameloc,t,0,'interrupt');
      end;
    end;
    scheduler.addtask(windowupdate,priority_window,nlptr,0,nil);
    devlength:=pw(@fbuff[devhdr])^;
    if (devlength=$ffff)or(devlength=0)or(devhdr+devlength>fsize-10) then
      done:=true;
    inc(devhdr,devlength);
  end;
end;

{************************************************************************
* readpefile                                                            *
* - the main file loader in Borg is for PE files. The routines here are *
*   fairly complete, and lack only proper analysis of debug sections.   *
* - needs rewriting for clarity at some point in the future, as it has  *
*   sprawled out to 360 lines now.                                      *
* - some further resource tree analysis is done in other routines which *
*   follow                                                              *
************************************************************************}
procedure tfileloader.readpefile(offs:dword);
var
  pdata:ppeobjdata;
  pestart,impname,expname:pchar;
  chktable:pchar;
  lef,leo,len,start_addr:lptr;
  fnaddr,nnaddr:pda;
  onaddr,rdata:pwa;
  numsymbols,numitems,numrelocs:dword;
  impbuff:array[0..99] of char;
  inum:string;
  newimpname:pchar;
  sseg,t:lptr;
  j:dword;
  i,k,k1,clen:integer;
  impdir:ppeimportdirentry;
  uinit:pchar;
  expdir:ppeexportdirentry;
  per:pperelocheader;
  thunkrva,impaddr,impaddr2,numtmp:dword;
  imphint:pda;
  peobjdone:boolean;
  resdir:pperestable;
  rentry:pperestableentry;
begin
  start_addr:=nlptr;
  options.dseg:=options.loadaddr.s;
  sseg.s:=options.loadaddr.s;
  sseg.o:=0;
  pestart:=@fbuff[offs];
  peh:=ppeheader(pestart);
  options.loadaddr.o:=peh.image_base;
  // bugfix ver 2.19
  // pdata:=ppeobjdata(pestart+sizeof(tpeheader)+(peh.numintitems-$0a)*8);
  pdata:=ppeobjdata(pestart+24+peh.nt_hdr_size);
  for i:=0 to peh.objects-1 do begin
    peobjdone:=FALSE;
    if (pdata^[i].rva=peh.exporttable_rva) or  // export info
      (peh.exporttable_rva>pdata^[i].rva)and(peh.exporttable_rva<pdata^[i].rva+pdata^[i].phys_size)
    then begin
      expdir:=ppeexportdirentry(@fbuff[pdata^[i].phys_offset+peh.exporttable_rva-pdata^[i].rva]);
      t.s:=options.loadaddr.s;
      t.o:=peh.image_base+peh.exporttable_rva;
      scheduler.addtask(dis_datadword,priority_data,t,0,nil);
      scheduler.addtask(dis_datadword,priority_data,t,4,nil);
      scheduler.addtask(dis_dataword,priority_data,t,8,nil);
      scheduler.addtask(dis_dataword,priority_data,t,10,nil);
      scheduler.addtask(dis_datadword,priority_data,t,12,nil);
      scheduler.addtask(dis_datadword,priority_data,t,16,nil);
      scheduler.addtask(dis_datadword,priority_data,t,20,nil);
      scheduler.addtask(dis_datadword,priority_data,t,24,nil);
      scheduler.addtask(dis_datadword,priority_data,t,28,nil);
      for k1:=0 to peh.objects-1 do begin
        if (expdir.namerva>=pdata^[k1].rva)and(expdir.namerva<pdata^[k1].rva+pdata^[k1].phys_size)
        then begin
          expname:=@fbuff[expdir.namerva-pdata^[k1].rva+pdata^[k1].phys_offset];
          break;
        end;
      end;
      t.o:=expdir.namerva+peh.image_base;
      scheduler.addtask(dis_datastring,priority_data,t,0,nil);
      numsymbols:=expdir.numfunctions;
      getmem(chktable,numsymbols);
      for j:=0 to numsymbols-1 do chktable[j]:=#0;
      if expdir.numnames<numsymbols then numsymbols:=expdir.numnames;
      for k:=0 to peh.objects-1 do begin
        if (expdir.nameaddrrva>=pdata^[k].rva)and(expdir.nameaddrrva<pdata^[k].rva+pdata^[k].phys_size)
        then begin
          nnaddr:=@fbuff[expdir.nameaddrrva-pdata^[k].rva+pdata^[k].phys_offset]; break;
        end;
      end;
      for k:=0 to peh.objects-1 do begin
        if (expdir.funcaddrrva>=pdata^[k].rva)and(expdir.funcaddrrva<pdata^[k].rva+pdata^[k].phys_size)
        then begin
          fnaddr:=@fbuff[expdir.funcaddrrva-pdata^[k].rva+pdata^[k].phys_offset]; break;
        end;
      end;
      for k:=0 to peh.objects-1 do begin
        if (expdir.ordsaddrrva>=pdata^[k].rva)and(expdir.ordsaddrrva<pdata^[k].rva+pdata^[k].phys_size)
        then begin
          onaddr:=@fbuff[expdir.ordsaddrrva-pdata^[k].rva+pdata^[k].phys_offset]; break;
        end;
      end;
      lef.s:=options.loadaddr.s; lef.o:=expdir.funcaddrrva+peh.image_base;
      leo.s:=options.loadaddr.s; leo.o:=expdir.ordsaddrrva+peh.image_base;
      len.s:=options.loadaddr.s; len.o:=expdir.nameaddrrva+peh.image_base;
      while numsymbols>0 do begin
        scheduler.addtask(dis_datadword,priority_data,lef,0,nil);
        scheduler.addtask(dis_dataword,priority_data,leo,0,nil);
        scheduler.addtask(dis_datadword,priority_data,len,0,nil);
        chktable[onaddr^[0]]:=#1;
{$R-}
        t.s:=options.loadaddr.s; t.o:=peh.image_base+fnaddr^[onaddr^[0]];
        scheduler.addtask(dis_export,priority_export,t,0,@fbuff[nnaddr^[0]+pdata^[k].phys_offset-pdata^[k].rva]);
        t.s:=options.loadaddr.s; t.o:=peh.image_base+nnaddr^[0];
        scheduler.addtask(dis_datastring,priority_data,t,0,nil);
        t.s:=options.loadaddr.s; t.o:=peh.image_base+fnaddr^[onaddr^[0]];
        scheduler.addtask(dis_exportcode,priority_definitecode,t,0,nil);
{$R+}
        dec(numsymbols);
        inc(dword(onaddr),2);  ///2016 3 to 2!
        inc(dword(nnaddr),4);
        inc(lef.o,4);
        inc(leo.o,2);
        inc(len.o,4);
      end;
      if expdir.numfunctions>expdir.numnames then begin
        for j:=0 to expdir.numfunctions-1 do begin
          if chktable[j]=#0 then begin
            numtmp:=j+expdir.base;
            fmtstr(inum,'%02.2d',[numtmp]);
            lstrcpyn(impbuff,expname,GNAME_MAXLEN-8);
            k:=0;
            while (impbuff[k]<>#0)and(k<GNAME_MAXLEN-8) do begin
              if impbuff[k]='.' then break;
              inc(k);
            end;
            strcopy(@impbuff[k],'::ord_');
            strpcopy(impbuff+strlen(impbuff),inum);
            getmem(newimpname,strlen(impbuff)+1);
            strcopy(newimpname,impbuff);
            if fnaddr^[j]<>0 then begin
              t.s:=options.loadaddr.s;
              t.o:=fnaddr^[j]+peh.image_base;
              scheduler.addtask(dis_ordexport,priority_export,t,0,newimpname);
              scheduler.addtask(dis_code,priority_definitecode,t,0,nil);
            end;
          end;
        end;
      end;
      freemem(chktable);
    end;
    if (pdata^[i].rva=peh.importtable_rva) or // import info
      ((peh.importtable_rva>pdata^[i].rva)and(peh.importtable_rva<pdata^[i].rva+pdata^[i].phys_size))
    then begin
      impdir:=@fbuff[pdata^[i].phys_offset+peh.importtable_rva-pdata^[i].rva];
      j:=0;
      while impdir^[j].firstthunkrva<>0 do begin
        t.s:=options.loadaddr.s;
        t.o:=peh.image_base+peh.importtable_rva+j*sizeof(tpeimportdirentry);
        scheduler.addtask(dis_datadword,priority_data,t,0,nil);
        scheduler.addtask(dis_datadword,priority_data,t,4,nil);
        scheduler.addtask(dis_datadword,priority_data,t,8,nil);
        scheduler.addtask(dis_datadword,priority_data,t,12,nil);
        scheduler.addtask(dis_datadword,priority_data,t,16,nil);
        for k1:=0 to peh.objects-1 do begin
          if (impdir^[j].namerva>=pdata^[k1].rva)and(impdir^[j].namerva<pdata^[k1].rva+pdata^[k1].phys_size)
          then begin
            impname:=@fbuff[impdir^[j].namerva-pdata^[k1].rva+pdata^[k1].phys_offset]; break;
          end;
        end;
        t.s:=options.loadaddr.s;
        t.o:=impdir^[j].namerva+peh.image_base;
        scheduler.addtask(dis_datastring,priority_data,t,0,nil);
        if impdir^[j].originalthunkrva=0 then thunkrva:=impdir^[j].firstthunkrva
        else thunkrva:=impdir^[j].originalthunkrva;
        for k:=0 to peh.objects-1 do begin
          if (thunkrva>=pdata^[k].rva)and(thunkrva<pdata^[k].rva+pdata^[k].phys_size) then begin
            imphint:=@fbuff[thunkrva-pdata^[k].rva+pdata^[k].phys_offset];
            break;
          end;
        end;
        impaddr:=impdir^[j].firstthunkrva+peh.image_base;
        impaddr2:=impdir^[j].originalthunkrva+peh.image_base;
        while imphint^[0]<>0 do begin
          if imphint^[0] and $80000000<>0 then begin
            numtmp:=imphint^[0] and $7fffffff;
            fmtstr(inum,'%02.2d',[numtmp]);
            strcopy(impbuff,impname);
            k:=0;
            while impbuff[k]<>#0 do begin
              if impbuff[k]='.' then break;
              inc(k);
            end;
            strcopy(@impbuff[k],'::ord_');
            strpcopy(impbuff+strlen(impbuff),inum);
            getmem(newimpname,strlen(impbuff)+1);
            strcopy(newimpname,impbuff);
            t.s:=options.loadaddr.s; t.o:=impaddr;
            scheduler.addtask(dis_ordimport,priority_import,t,0,newimpname);
          end else begin
            t.s:=options.loadaddr.s; t.o:=impaddr;
            scheduler.addtask(dis_import,priority_import,t,0,@fbuff[imphint^[0]+2+pdata^[k1].phys_offset-pdata^[k1].rva]);
          end;
          t.s:=options.loadaddr.s; t.o:=peh.image_base+imphint^[0];
          scheduler.addtask(dis_dataword,priority_data,t,0,nil);
          scheduler.addtask(dis_datastring,priority_data,t,2,nil);
          t.s:=options.loadaddr.s; t.o:=impaddr;
          scheduler.addtask(dis_datadword,priority_data,t,0,nil);
          t.s:=options.loadaddr.s; t.o:=impaddr2;
          scheduler.addtask(dis_datadword,priority_data,t,0,nil);
          inc(dword(imphint),4);
          inc(impaddr,4);
          inc(impaddr2,4);
        end;
        t.s:=options.loadaddr.s;
        t.o:=impaddr;
        scheduler.addtask(dis_datadword,priority_data,t,0,nil);
        t.s:=options.loadaddr.s;
        t.o:=impaddr2;
        scheduler.addtask(dis_datadword,priority_data,t,0,nil);
        inc(j);
      end;
      t.s:=options.loadaddr.s;
      t.o:=peh.image_base+peh.importtable_rva+j*sizeof(tpeimportdirentry);
      scheduler.addtask(dis_datadword,priority_data,t,0,nil);
      scheduler.addtask(dis_datadword,priority_data,t,4,nil);
      scheduler.addtask(dis_datadword,priority_data,t,8,nil);
      scheduler.addtask(dis_datadword,priority_data,t,12,nil);
      scheduler.addtask(dis_datadword,priority_data,t,16,nil);
    end;
    if pdata^[i].rva=peh.tls_rva then peobjdone:=TRUE; // tls info
    if (pdata^[i].rva=peh.resourcetable_rva) or // resource info
      ((peh.resourcetable_rva>pdata^[i].rva)and
       (peh.resourcetable_rva<pdata^[i].rva+pdata^[i].phys_size))
    then begin
      // RESOURCE_DATA;
      if (pdata^[i].phys_size<>0)and(options.loadresources) then begin
        resdir:=@fbuff[pdata^[i].phys_offset
          +peh.resourcetable_rva-pdata^[i].rva];
        pdatarva:=peh.resourcetable_rva;  // bugfix  build 14
        rawdata:=@resdir^;
        numitems:=resdir.numnames+resdir.numids;
        rentry:=@resdir^; inc(dword(rentry),sizeof(tperestable));
        while numitems<>0 do begin
          if rentry.id and $80000000<>0 then begin
            impname:=rawdata+(rentry.id and $7fffffff);
            clen:=pw(@impname[0])^;
            WideCharToMultiByte(CP_ACP,0,@impname[2],clen,impbuff,100,nil,nil);
            impbuff[clen]:=#0;
          end else begin case rentry.id of
           1:      strcopy(impbuff,'Cursor');
           2:      strcopy(impbuff,'Bitmap');
           3:      strcopy(impbuff,'Icon');
           4:      strcopy(impbuff,'Menu');
           5:      strcopy(impbuff,'Dialog');
           6:      strcopy(impbuff,'String Table');
           7:      strcopy(impbuff,'Font Directory');
           8:      strcopy(impbuff,'Font');
           9:      strcopy(impbuff,'Accelerators');
           10:     strcopy(impbuff,'Unformatted Resource Data');
           11:     strcopy(impbuff,'Message Table');
           12:     strcopy(impbuff,'Group Cursor');
           14:     strcopy(impbuff,'Group Icon');
           16:     strcopy(impbuff,'Version Information');
           $2002:  strcopy(impbuff,'New Bitmap');
           $2004:  strcopy(impbuff,'New Menu');
           $2005:  strcopy(impbuff,'New Dialog');
           else
                   strcopy(impbuff,'User Defined Id:');
                   numtmp:=rentry.id and $7fffffff;
                   fmtstr(inum,'%2.2x',[numtmp]);
                   strpcopy(impbuff+strlen(impbuff),inum);
          end;
          end;
          if rentry.offset and $80000000<>0 then begin
            subdirsummary(rawdata+((rentry.offset) and $7fffffff),impbuff,peh.image_base,rentry.id);
          end else begin
            leafnodesummary(rawdata+((rentry.offset) and $7fffffff),impbuff,peh.image_base,0);
          end;
          inc(rentry);
          dec(numitems);
         end;
       end;
       if pdata^[i].rva=peh.resourcetable_rva then peobjdone:=TRUE;
       end;
       if pdata^[i].rva=peh.fixuptable_rva then begin // fixup info
         per:=@fbuff[pdata^[i].phys_offset];
         while per.rva<>0 do begin
           rdata:=@per^; inc(dword(rdata),8);
           numrelocs:=(per.len-sizeof(tperelocheader)) div 2;
           while (numrelocs<>0)and ((rdata^[0])<>0) do begin
             t.s:=options.loadaddr.s;
             t.o:=(rdata^[0] and $0fff)+per.rva+peh.image_base;
             reloc.addreloc(t,0,RELOC_NONE);
             inc(dword(rdata),2);
             dec(numrelocs);
           end;
           inc(dword(per),per.len);
         end;
         peobjdone:=TRUE;
       end;
       if pdata^[i].rva=peh.debugtable_rva then begin // debug info
         // DEBUG_DATA;
         if (pdata^[i].phys_size<>0)and(options.loaddebug) then begin
           sseg.o:=pdata^[i].rva+peh.image_base;
           dta.addseg(sseg,pdata^[i].phys_size,@fbuff[pdata^[i].phys_offset],debugdata,nil);
         end;
         peobjdone:=TRUE;
       end;
       if (pdata^[i].obj_flags and $40<>0)and(not(pdata^[i].obj_flags and $20)<>0)and(not peobjdone)
       then begin
         // INIT_DATA;
         if (pdata^[i].phys_size<>0)and(options.loaddata) then begin
           sseg.o:=pdata^[i].rva+peh.image_base;
           dta.addseg(sseg,pdata^[i].phys_size,@fbuff[pdata^[i].phys_offset],data32,nil);
         end;
         if (pdata^[i].virt_size>pdata^[i].phys_size)and options.loaddata then begin
           sseg.o:=pdata^[i].rva+peh.image_base+pdata^[i].phys_size;
           getmem(uinit,pdata^[i].virt_size-pdata^[i].phys_size);
           for j:=0 to pdata^[i].virt_size-pdata^[i].phys_size-1 do uinit[j]:=#0;
           dta.addseg(sseg,pdata^[i].virt_size-pdata^[i].phys_size,uinit,uninitdata,nil);
         end
       end else if (pdata^[i].obj_flags and $80<>0)and(not peobjdone) then begin
         // UNINIT_DATA;
         if options.loaddata then begin
           sseg.o:=pdata^[i].rva+peh.image_base;
           getmem(uinit,pdata^[i].virt_size);
           for j:=0 to pdata^[i].virt_size-1 do uinit[j]:=#0;
           dta.addseg(sseg,pdata^[i].virt_size,uinit,uninitdata,nil);
         end;
       end else if not peobjdone then begin
         // CODE_DATA;
         if pdata^[i].phys_size<>0 then begin
           sseg.o:=pdata^[i].rva+peh.image_base;
           dta.addseg(sseg,pdata^[i].phys_size,@fbuff[pdata^[i].phys_offset],code32,nil);
           dta.possibleentrycode(sseg);
         end;
       end;
    // default start addr=first seg, in the case of no entry point
    // (eg some dll files). added version 2.20
    if start_addr.s=0 then begin
      start_addr.s:=options.loadaddr.s;
      start_addr.o:=pdata^[i].rva+peh.image_base;
      dio.setcuraddr(start_addr);
    end;
  end;
  start_addr.s:=options.loadaddr.s;
  start_addr.o:=peh.entrypoint_rva+peh.image_base;
  options.oep:=start_addr;
  dio.setcuraddr(start_addr);
  scheduler.addtask(dis_code,priority_definitecode,start_addr,0,nil);
  scheduler.addtask(nameloc,priority_nameloc,start_addr,0,'start');
  scheduler.addtask(windowupdate,priority_window,nlptr,0,nil);
end;

{************************************************************************
* readmzfile                                                            *
* - standard dos mz-executable file reader.                             *
* - fairly basic at the moment, as it is simply a load, and a better    *
*   analysis of d_seg is required (in fact Borg needs more work on      *
*   segmentation all round.                                             *
************************************************************************}
procedure tfileloader.readmzfile(fsize:dword);
var
  mzh:pmzheader;
  fs:dword;
  roffs:pchar;
  poffs:pchar;
  nrelocs,nr:word;
  ritem:pwa;
  rchange:pwa;
  rtable:pwa;
  sseg,tseg:lptr;  // current segment limits
  ip:lptr;
  saddr,taddr,ipaddr:dword;
begin
  options.loadaddr.o:=0;
  mzh:=@fbuff;
  fs:=(mzh.numpages-1)*512+mzh.numbytes;
  if fs>fsize then fs:=fsize;
  dec(fs,mzh.headersize*16);
  roffs:=fbuff+mzh.relocoffs;
  poffs:=fbuff+mzh.headersize*16;
  nrelocs:=mzh.numrelocs;
  if nrelocs<>0 then getmem(rtable,nrelocs*2);
  if nrelocs=0 then begin
    MessageBox(mainwindow,'Relocation table is empty\nThis file is probably packed'+
      #13'Borg will not be able to create the segments properly','Borg Warning',MB_OK or MB_ICONEXCLAMATION);
  end;
  while nrelocs<>0 do begin
    ritem:=@roffs[(mzh.numrelocs-nrelocs)*4];
    if ((ritem^[0]) or (ritem^[1]))<>0 then begin
      rchange:=@poffs[ritem^[0]+ritem^[1]*16];
      inc(rchange^[0],options.loadaddr.s);
      rtable^[mzh.numrelocs-nrelocs]:=rchange^[0];
    end else rtable^[mzh.numrelocs-nrelocs]:=options.loadaddr.s;
    dec(nrelocs);
  end;
//  qsort(rtable,mzh.numrelocs,2,mzcmp);
  sseg:=options.loadaddr;
  options.dseg:=options.loadaddr.s;   // need to look for better value for dseg later
  ip:=options.loadaddr;
  ipaddr:=((mzh.csip)+((mzh.csip div $10000)+options.loadaddr.s)*16+options.loadaddr.o) and $fffff;
  for nrelocs:=0 to mzh.numrelocs-1 do begin
    if rtable^[nrelocs]<>sseg.s then begin
      tseg.s:=rtable^[nrelocs]; //???
      tseg.o:=0;
      saddr:=sseg.s*16+sseg.o;
      taddr:=tseg.s*16+tseg.o;
      if (ipaddr>=saddr)and(ipaddr<taddr) then begin
        ip.s:=sseg.s;
        ip.o:=ipaddr-ip.s*16; //???
      end;
      if (saddr<taddr)and(sseg.s>=options.loadaddr.s) then begin
        dta.addseg(sseg,taddr-saddr,fbuff+mzh.headersize*16
         +(sseg.s-options.loadaddr.s)*16,code16,nil);
        dta.possibleentrycode(sseg);
        // go through the reloc items, check if any lie in the seg
        // if they do - add to reloc entries.
        for nr:=0 to mzh.numrelocs-1 do begin
          ritem:=@roffs[(mzh.numrelocs-nr)*4];
          if ((ritem^[0]) or (ritem^[1]))<>0 then begin
            rchange:=@poffs[ritem^[0]+ritem^[1]*16];
            if (dword(rchange^[0])>=
              dword(fbuff[mzh.headersize*16+(sseg.s-options.loadaddr.s)*16]))
              and(byte(rchange^[0])<dword(fbuff[mzh.headersize*16+(sseg.s-options.loadaddr.s)*16+taddr-saddr]))
            then begin
              reloc.addreloc(sseg,byte(rchange^[0])-
              (dword(fbuff[mzh.headersize*16+(sseg.s-options.loadaddr.s)*16])),RELOC_SEG);
            end;
          end;
        end;
        sseg.s:=tseg.s;
      end;
    end;
  end;
  if (sseg.s-options.loadaddr.s)*16<fs then begin
    saddr:=sseg.s*16+sseg.o;
    if ipaddr>=saddr then begin
      ip.s:=sseg.s;
      ip.o:=ipaddr-ip.s*16; //???
    end;
    dta.addseg(sseg,fs-(sseg.s-options.loadaddr.s)*16,
    fbuff+mzh.headersize*16+(sseg.s-options.loadaddr.s)*16,code16,nil);
    for nr:=0 to mzh.numrelocs-1 do begin
      ritem:=@roffs[(mzh.numrelocs-nr)*4];
      if ((ritem^[0])or(ritem^[1]))<>0 then begin
        rchange:=@poffs[ritem^[0]+ritem^[1]*16];
        if (rchange^[0]>=byte(fbuff[mzh.headersize*16+(sseg.s-options.loadaddr.s)*16]))
          and (rchange^[0]<byte(fbuff[mzh.headersize*16+fs]))
        then reloc.addreloc(sseg,rchange^[0]-
          byte(fbuff[mzh.headersize*16+(sseg.s-options.loadaddr.s)*16]),RELOC_SEG);
      end;
    end;
    dta.possibleentrycode(sseg);
  end;
  // need to search for dseg better value.
  options.mode16:=TRUE;
  options.mode32:=FALSE;
  dio.setcuraddr(ip);
  scheduler.addtask(dis_code,priority_definitecode,ip,0,nil);
  scheduler.addtask(nameloc,priority_nameloc,ip,0,'start');
  scheduler.addtask(windowupdate,priority_window,nlptr,0,nil);
  if mzh.numrelocs<>0 then freemem(rtable);
end;

procedure tfileloader.readlefile;
begin
end;

{************************************************************************
* readnefile                                                            *
* - NE = new executable = old windows 16-bit format.                    *
* - this is partially written but needs much more work on imports,      *
*   exports, etc                                                        *
************************************************************************}
procedure tfileloader.readnefile(offs:dword);
var
  neh:pneheader;
  nestart,importnames,modoffsets:pchar;
  nsegs:word;
  nesegt:pnesegtablearr;
  i,j,k:integer;
  sseg,iaddr,inum:lptr;
  slen,soffs:dword;
  numrelocs:word;
  stable:pwa;
  reloctable:pnesegtablerelocarr;
  iname:array[0..80] of char;
begin
  options.dseg:=options.loadaddr.s;
  sseg.s:=options.loadaddr.s;
  sseg.o:=0;
  nestart:=@fbuff[offs];
  neh:=pneheader(nestart);
  if neh.csip=0 then begin
    MessageBox(mainwindow,'No entry point to executable - assume that Executable'+
     'is a resource only\nUse a resource viewer','Borg Warning',MB_OK or MB_ICONEXCLAMATION);
    CloseHandle(efile);
    efile:=dword(INVALID_HANDLE_VALUE);
    exetype:=0;
    exit;
  end;
  nsegs:=neh.numsegs;
  getmem(stable,nsegs*2);
  nesegt:=@nestart[neh.offs_segments];
  importnames:=@nestart[neh.offs_imports];
  modoffsets :=@nestart[neh.offs_module];
  // add segments
  for i:=0 to nsegs-1 do begin
    slen:=nesegt^[i].seglength;
    if slen=0 then slen:=$10000;
    soffs:=nesegt^[i].sectoroffs;
    // added uninit data borg 2.20
    if soffs<>0 then begin
      if nesegt^[i].segflags and 1<>0 then begin
        dta.addseg(sseg,slen,@fbuff[soffs shl neh.shiftcount],data16,nil);
        options.dseg:=sseg.s;
      end else begin
        dta.addseg(sseg,slen,@fbuff[soffs shl neh.shiftcount],code16,nil);
        dta.possibleentrycode(sseg);
      end;
    end else dta.addseg(sseg,slen,nil,uninitdata,nil); // uninit data
    stable^[i]:=sseg.s;
    inc(sseg.s,word((slen+15) div 16));
    end;
    // relocate data
    // approach to imports:
    // - start with a new segment 0xffff, to be created later, size 0.
    // - for each import, if its an ordinal add it at the current addr in the import segment,
    // - and increase the size of the segment, name it = name+ordinal num
    // - otherwise name=importnames table name, check for if it is already an import
    // - and only add if necessary.
    // - finally create the segment at the end.
    iaddr.s:=$ffff;
    inum.s:=$ffff;
    iaddr.o:=0;
    for i:=0 to nsegs-1 do begin
      slen:=nesegt^[i].seglength;
      if slen=0 then slen:=$10000;
      soffs:=nesegt^[i].sectoroffs;
      if (nesegt^[i].segflags and 100<>0)and(soffs<>0) then begin
        // reloc data present
        numrelocs:=pw(@fbuff[(soffs shl neh.shiftcount)+slen])^;
        reloctable:=@fbuff[(soffs shl neh.shiftcount)+slen+2];
        for j:=0 to numrelocs-1 do begin
          case reloctable^[j].reloctype of
           0: ;    //low byte
           2:      //16bit selector
            if (reloctable^[j].relocsort=0)and(reloctable^[j].indx<$ff) then begin
              pw(fbuff[(soffs shl neh.shiftcount)+reloctable^[j].segm_offs])^:=stable^[reloctable^[j].indx-1];
            end;
           3:      //32bit pointer
            if (reloctable^[j].relocsort=0)and(reloctable^[j].indx<$ff) then begin
              pw(fbuff[(soffs shl neh.shiftcount)+reloctable^[j].segm_offs+2])^:=stable^[reloctable^[j].indx-1];
              pw(fbuff[(soffs shl neh.shiftcount)+reloctable^[j].segm_offs])^:=reloctable^[j].indexoffs;
            end else if reloctable^[j].relocsort=2 then begin // import by name
              for k:=0 to 78 do begin
                if importnames[reloctable^[j].indexoffs]=#0 then break;
                iname[k]:=importnames[reloctable^[j].indexoffs+1+k];
                iname[k+1]:=#0;
              end;
              inum.o:=import.getoffsfromname(iname);
              if inum.o=0 then begin
                inc(iaddr.o);
                import.addname(iaddr,iname);
                inum.o:=iaddr.o;
              end;
              PW(fbuff[(soffs shl neh.shiftcount)+reloctable^[j].segm_offs+2])^:=inum.s;
              PW(fbuff[(soffs shl neh.shiftcount)+reloctable^[j].segm_offs])^:=inum.o;
            end;
           5:      //16bit offset
            if (reloctable^[j].relocsort=0)and(reloctable^[j].indx<$ff) then begin
              pw(fbuff[(soffs shl neh.shiftcount)+reloctable^[j].segm_offs])^:=reloctable^[j].indexoffs;
            end;
          11:     //48bit pointer
            if (reloctable^[j].relocsort=0)and(reloctable^[j].indx<$ff) then begin
              pw(fbuff[(soffs shl neh.shiftcount)+reloctable^[j].segm_offs+4])^:=stable^[reloctable^[j].indx-1];
              pd(fbuff[(soffs shl neh.shiftcount)+reloctable^[j].segm_offs])^:=reloctable^[j].indexoffs;
            end;
          13:     //32bit offset
            if (reloctable^[j].relocsort=0)and(reloctable^[j].indx<$ff) then begin
              pd(fbuff[(soffs shl neh.shiftcount)+reloctable^[j].segm_offs])^:=reloctable^[j].indexoffs;
            end;
         end;
       end;
    end;
  end;
  inum.o:=0;
  if iaddr.o<>0 then dta.addseg(inum,iaddr.o+1,nil,uninitdata,'Import Segment <Borg>');
  // set up disassembly
  options.loadaddr.s:=stable^[(neh.csip shr 16)-1];
  options.loadaddr.o:=neh.csip and $ffff;
  dio.setcuraddr(options.loadaddr);
  scheduler.addtask(dis_code,priority_definitecode,options.loadaddr,0,nil);
  scheduler.addtask(nameloc,priority_nameloc,options.loadaddr,0,'start');
  scheduler.addtask(windowupdate,priority_window,nlptr,0,nil);
  freemem(stable);
end;

procedure tfileloader.reados2file;
begin
end;

{************************************************************************
* readbinfile                                                           *
* - reads a file as a flat binary file, so in effect we can load more   *
*   or less anything and do some analysis                               *
************************************************************************}
procedure tfileloader.readbinfile(fsize:dword);
begin
  options.mode32:= not options.mode16;
  options.dseg:=options.loadaddr.s;
  if options.mode32 then dta.addseg(options.loadaddr,fsize,fbuff,code32,nil)
  else dta.addseg(options.loadaddr,fsize,fbuff,code16,nil);
  dta.possibleentrycode(options.loadaddr);
  dio.setcuraddr(options.loadaddr);
  scheduler.addtask(dis_code,priority_definitecode,options.loadaddr,0,nil);
  scheduler.addtask(nameloc,priority_nameloc,options.loadaddr,0,'start');
  scheduler.addtask(windowupdate,priority_window,nlptr,0,nil);
end;

{************************************************************************
* subdirsummary                                                         *
* - this is part of the resource analysis for PE files. Resources are   *
*   held in a tree type format consisting of subdirs and leafnodes.     *
************************************************************************}
procedure tfileloader.subdirsummary(data,impname:pchar; image_base:dword; rtype:dword);
var
  resdir:pperestable;
  rentry:pperestableentry;
  nam:pchar;
  nbuff:array[0..100] of char;
  nbuff2:array[0..100] of char;
  inum:string;
  clen:integer;
  numtmp:dword;
  numitems:dword;
begin
  resdir:=@data^;
  numitems:=resdir.numnames+resdir.numids;
  rentry:=@resdir^; inc(dword(rentry),sizeof(tperestable));
  while numitems<>0 do begin
    if rentry.id and $80000000<>0 then begin
      nam:=rawdata+((rentry.id)and $7fffffff);
      clen:=pw(@nam[0])^;
      WideCharToMultiByte(CP_ACP,0,@nam[2],clen,nbuff,100,nil,nil);
      nbuff[clen]:=#0;
      if impname<>nil then begin
        strcopy(nbuff2,nbuff);
        strcopy(nbuff,impname);
        strcat(nbuff,' ');
        strcat(nbuff,nbuff2);
      end;
    end else begin
      numtmp:=rentry.id and $7fffffff;
      fmtstr(inum,'%2.2x',[numtmp]);
      strcopy(nbuff,impname);
      strcat(nbuff,' Id:');
      strpcopy(nbuff+strlen(nbuff),inum);
    end;
    if (rentry.offset and $80000000<>0)
    then leaf2summary(rawdata+((rentry.offset) and $7fffffff),nbuff,image_base,rtype)
    else leafnodesummary(rawdata+((rentry.offset) and $7fffffff),nbuff,image_base,rtype);
    inc(rentry);
    dec(numitems);
  end;
end;

{************************************************************************
* leaf2summary                                                          *
* - PE resource analysis of leaf nodes                                  *
************************************************************************}
procedure tfileloader.leaf2summary(data,nam:pchar; image_base:dword; rtype:dword);
var
  resdir:pperestable;
  rentry:pperestableentry;
  numitems:dword;
begin
  resdir:=@data^;
  numitems:=resdir.numnames+resdir.numids;
  rentry:=@resdir^; inc(dword(rentry),sizeof(tperestable));
  while numitems<>0 do begin
    leafnodesummary(rawdata+((rentry.offset) and $7fffffff),nam,image_base,rtype);
    inc(rentry);
    dec(numitems);
  end;
end;

{************************************************************************
* leafnodesummary                                                       *
* - analysis of a leaf node in a PE resource table                      *
* - detailed analysis of dialogs and string tables is done at the       *
*   moment                                                              *
************************************************************************}
procedure tfileloader.leafnodesummary(data,resname:pchar; image_base:dword; rtype:dword);
var
  leaf:ppeleafnode;
  t:lptr;
  rname:pchar;
begin
  leaf:=@data^;
  t.s:=options.loadaddr.s;
  t.o:=leaf.datarva+image_base;
  // bugfix to third arg - build 14
  dta.addseg(t,leaf.size,@rawdata[leaf.datarva-pdatarva],resourcedata,resname);
  case rtype of
   5: // dialog
    begin
      getmem(rname,strlen(resname)+1);
      strcopy(rname,resname);
      scheduler.addtask(dis_dialog,priority_data,t,0,resname);
    end;
   6: // stringtable
    begin
      getmem(rname,strlen(resname)+1);
      strcopy(rname,resname);
      scheduler.addtask(dis_stringtable,priority_data,t,0,resname);
    end;
  end;
end;

initialization
  floader:=tfileloader.create;
finalization
  floader.free;
end.

