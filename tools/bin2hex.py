#!/usr/bin/env python3

import sys

with open(sys.argv[1], "rb") as f:
    cnt = 3
    s = ["00"]*4
    while True:
        data = f.read(1)
        if not data:
            print(''.join(s))
            exit(0)
        s[cnt] = "{:02X}".format(data[0])
        if cnt == 0:
            print(''.join(s))
            s = ["00"]*4
            cnt = 4
        cnt -= 1

#import sys
#
#with open(sys.argv[1], "rb") as f:
#    binData = f.read()
#
#maxlimit = 1000000
#
#assert len(binData) < 4 * maxlimit
#
#for i in range(maxlimit):
#    if i < len(binData) // 4:
#        w = binData[4 * i : 4 * i + 4]
#        print("%02x%02x%02x%02x" % (w[3], w[2], w[1], w[0]))
