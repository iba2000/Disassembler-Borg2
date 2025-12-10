unit stacks;
interface
uses windows,common,gname,savefile;

// This is a simple stack class for a stack of lptr's. It is used in     *
// keeping track of jump locations, so that when a jump is followed it   *
// can be reversed. The stack is of a set size, and when it becomes too  *
// large the bottom of the stack is lost. I did have some plans on using *
// this class in a front end unpacker-emulator but my plans have changed *
// and any unpacker-emulator will use a different method more akin to    *
// single step tracing.                                                  *
// The stack was added in Version 2.11                                   *

const CALLSTACKSIZE =100;

type
  tstack=class
    callstack:array[0..CALLSTACKSIZE-1] of lptr;
    stacktop:integer;
  public
    constructor create;
    procedure push(loc:lptr);
    function pop:lptr;
  end;

implementation

// - simply reset the top of the stack
constructor tstack.create;
begin
  inherited create;
  stacktop:=0;
end;

// push                                                                  *
// - places an item on top of the stack. If there is no room then we     *
//   lose an item from the bottom and move the others down               *
procedure tstack.push(loc:lptr);
var i:integer;
begin
  if stacktop=CALLSTACKSIZE then begin  // need to remove bottom item from stack
    for i:=0 to CALLSTACKSIZE-2 do begin
      callstack[i]:=callstack[i+1];
      dec(stacktop);
    end;
  end;
  callstack[stacktop]:=loc;
  inc(stacktop);
end;

// pop                                                                   *
// - gets an item from the top of the stack, or returns nlptr if the     *
//   stack is empty                                                      *
function tstack.pop:lptr;
begin
  result:=nlptr;
  if stacktop=0 then exit;
  dec(stacktop);
  result:=callstack[stacktop];
end;

begin
end.

