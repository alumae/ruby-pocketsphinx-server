#! /bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

$DIR/log2apps-txt.sh $1 | head -20 > tmp/apps.txt

gnuplot <<EOF
set term pngcairo size 800,600

set style line 1 lc rgb '#8b1a0e' pt 1 ps 1 lt 1 lw 2 # --- red
set style line 2 lc rgb '#5e9c36' pt 6 ps 1 lt 1 lw 2 # --- green

set style line 11 lc rgb '#808080' lt 1
set border 3 back ls 11
set tics nomirror

set style line 12 lc rgb '#808080' lt 0 lw 1
set grid back ls 12


set style data histogram
set xtic rotate by -45 scale 0
set output '$2'
plot 'tmp/apps.txt' using 1:xticlabels(2) ti "Requests per app"
EOF
