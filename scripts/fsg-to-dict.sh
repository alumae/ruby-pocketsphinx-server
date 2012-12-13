#! /bin/bash

. `dirname $0`/settings.sh

grep TRANSITION | cut -f 5 -d " " | sort | uniq | $ET_G2P
