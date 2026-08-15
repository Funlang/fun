// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

var SizeOfPtr = 4;

class Stack()
  var list = new [];
  var curr = -1;

  fun push(o)
    curr += 1;
    list[curr] = o;
  end fun;

  var pop     = fun peek( 0,      true);
  var pull    = keep -> peek(-1*curr, not keep); // for queue
  var count   = -> curr + 1;
  var isEmpty = -> curr < 0;

  // prev: 0 (default), -1, -2, ...
  fun peek(prev, isPop)
    result = nil;
    prev += curr; //? '[' & prev & ']';
    if prev >= 0 then
      result = list[prev];
      if isPop then
        #* loop move one
        for i = prev to curr do
          list[i] = list[i+1];
        end do; #
        # * delete [prev] and move more
        list[prev] = nil;
        if prev < curr then
          var p = list.@count('ptr') + prev * SizeOfPtr;
          (p + SizeOfPtr).move(p, (curr - prev) * SizeOfPtr);
        end if;
        list.@count(-1); # // resize -1
        curr -= 1;
      end if;
    end if;
  end fun;
end class;
