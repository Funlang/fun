// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

########################################
# lib-type
########################################
#   built-in (8)
########################################
#     a.toStr(index) # index: default 0, for array; -2: Unicode
#     a.toNum(ptr)   #1-int, 2-float, 3-double, -1:ptr
#     a.toTime()
#     a.toByte(pos)  # default 0
#     a.toChar()
#     a.fromByte(pos, byte)
########################################
#     a.eq(b)        # strict equal
#     a.type()       # 0:nil 3:int 5:real 6:currency
#                      7:time 8:str 11:bool -1:other
########################################
