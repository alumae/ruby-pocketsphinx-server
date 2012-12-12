#! /bin/bash

. `dirname $0`/settings.sh

grep TRANSITION | cut -f 5 -d " " | sort | uniq | LC_ALL=en_US.ISO-8859-155555 $ET_G2P
