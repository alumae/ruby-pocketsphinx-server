#! /bin/bash

grep TRANSITION | cut -f 5 -d " " | sort | uniq | ~/workspace/asr-utils/src/Util/est-l2p.py
