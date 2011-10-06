#! /usr/bin/env python

import sys

from math import exp

if __name__ == '__main__':
  #HACK: currently all weights are set to 1. Seems to make the recognition more robust
  
  arcs = []
  for l in sys.stdin:
    ss = l.split()
    if len(ss) == 5:
      arcs.append((int(ss[0]), int(ss[1]), ss[2], 1))
    elif len(ss) == 4:
      arcs.append((int(ss[0]), int(ss[1]), ss[2], 1))
    elif len(ss) == 2:
      arcs.append((int(ss[0]), -1, "", 1))
    elif len(ss) == 1:
      arcs.append((int(ss[0]), -1, "", 1))
    else:
      print >>sys.stderr, "WARNING: strange FSG line: ", l
  
  max_state = max([a[1] for a in arcs])
  
  final_state_id = max_state + 1
  
  
  print "FSG_BEGIN <test>"
  print "NUM_STATES", max_state + 2
  print "START_STATE 0"
  print "FINAL_STATE", final_state_id
  
  for a in arcs:
    print "TRANSITION", a[0], a[1] == -1 and final_state_id or a[1], "%7.5f" % min(1.0, a[3]), a[2]

  print "FSG_END"
