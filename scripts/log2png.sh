#! /bin/bash


grep "^I, \[.*INFO.*User agent" $1 | perl -npe 's/^I, \[(\d\d\d\d-\d\d-\d\d)T\d\d:\d\d.*/\1/g' | sort | uniq -c | awk '{print($2,$1)}' > tmp/data.txt

gnuplot <<EOF

set term pngcairo size 800,600

set style line 1 lc rgb '#8b1a0e' pt 1 ps 1 lt 1 lw 2 # --- red
set style line 2 lc rgb '#5e9c36' pt 6 ps 1 lt 1 lw 2 # --- green

set style line 11 lc rgb '#808080' lt 1
set border 3 back ls 11
set tics nomirror

set style line 12 lc rgb '#808080' lt 0 lw 1
set grid back ls 12
set output '$2'
set xdata time
set timefmt "%Y-%m-%d"
set format x "%Y-%m"
plot "tmp/data.txt" using 1:2 with impulses ti "Requests per day"
EOF


