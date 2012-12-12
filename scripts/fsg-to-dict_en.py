#! /usr/bin/python

import sys
import re

import os
from subprocess import Popen, PIPE, STDOUT
BASE_DICT="/usr/local/share/pocketsphinx/model/lm/en_US/cmu07a.dic"
G2P=os.path.dirname(sys.argv[0]) + "/en-g2p.sh"

words = {}
for l in open(BASE_DICT):
    ss = l.split()
    word = ss[0]
    word = re.sub(r"\(\d\)$", "", word) 
    try:
      prob = float(ss[1])
      pron = ss[2:]
    except ValueError:
      prob = 1
      pron = ss[1:]
    
    words.setdefault(word, []).append((pron, prob))

input_words = set()

for l in sys.stdin:
  if l.startswith("TRANSITION"):
    ss = l.split()
    if len(ss) == 5:
      input_words.add(ss[-1])
  
g2p_words = []
for w in input_words:
  if w.lower() in words:
    for (i, pron) in enumerate(words[w.lower()]):
      if i == 0:
        print w,
      else:
        print "%s(%d)" % (w, i+1),
      print " ".join(pron[0])
  else:
    g2p_words.append(w)
  
if len(g2p_words) > 0:
  proc = Popen(G2P,stdin=PIPE, stdout=PIPE, stderr=STDOUT )
  #stdout, stderr = proc.communicate()
  for w in g2p_words:
    print >>proc.stdin, w
  proc.stdin.close()
  
  #return_code = proc.wait()
  
  for l in proc.stdout:
    print l,
    
  
  
  
