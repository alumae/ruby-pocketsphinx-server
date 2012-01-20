#! /bin/bash

grep "^I, \[.*INFO.*User agent" $1 | perl -npe 's/.* (\S+)\)/\1/' | sort | uniq -c | sort -nr
