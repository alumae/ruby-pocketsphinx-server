#! /bin/bash

grep "^I, \[.*INFO.*User agent" $1 | perl -npe 's/^I, \[(\d\d\d\d-\d\d-\d\dT\d\d):\d\d.*/\1:00/g' | sort | uniq -c | awk '{print($2,$1)}' > tmp/data.txt



gnuplot <<EOF
set term png
set output '$2'
set xdata time
set timefmt "%Y-%m-%dT%H:%M"
set format x "%m-%d\n%H:%M"
plot "tmp/data.txt" using 1:2 with boxes ti "Requests per hour"
EOF


