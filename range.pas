unit range;
interface
uses sysutils,windows,common,menus;

// This range class started out as just that - a range class for pairs   *
// of lptr's, but ended up as a class for defining a block more than a   *
// range. The block is set by the use in Borg, and then the block can be *
// undefined, exported as txt/asm, decrypted, etc. All of this was added *
// in Borg 2.15                                                          *
type
  trange=class
    top,bottom:lptr;
  public
    constructor create;
    function checkblock:boolean;
    procedure undefine;
    procedure settop;
    procedure setbottom;
  end;

var
  blk:trange;

implementation
uses disasm,disio,schedule;

// - sets the top and bottom of the range to the null pointer
constructor trange.create;
begin
  top:=nlptr;
  bottom:=nlptr;
end;

// checkblock                                                            *
// - This just checks that the top and bottom of the block have been set *
//   and returns true if they have, otherwise puts up a messagebox       *
function trange.checkblock:boolean;
begin
  result:=FALSE;
  if eq(top,nlptr) then begin
    MessageBox(mainwindow,'Set top of block first','Borg Disassembler',MB_OK);
    exit;
  end;
  if eq(bottom,nlptr) then begin
    MessageBox(mainwindow,'Set bottom of block first','Borg Disassembler',MB_OK);
    exit;
  end;
  if gr(top,bottom) then begin
    MessageBox(mainwindow,'Block empty ?','Borg Disassembler',MB_OK);
    exit;
  end;
  result:=TRUE;
end;

// undefine                                                              *
// - this undefines a block if the block has been set                    *
procedure trange.undefine;
begin
  if not checkblock then exit;
  dsm.undefineblock(top,bottom);
end;

// settop                                                                *
// - sets the top of the block to the current line                       *
procedure trange.settop;
begin
  dio.findcurrentaddr(top);
  MessageBox(mainwindow,'Top marked','Borg Disassembler',MB_OK);
end;

// setbottom                                                             *
// - sets the bottom of the block to the current line                    *
procedure trange.setbottom;
begin
  dio.findcurrentaddr(bottom);
  MessageBox(mainwindow,'Bottom marked','Borg Disassembler',MB_OK);
end;

initialization
  blk:=trange.create;
finalization
  blk.free;
end.

