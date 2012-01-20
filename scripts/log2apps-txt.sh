#! /bin/bash

egrep "^I, \[.*INFO.*User agent.* \(RecognizerIntentActivity.*\)" $1 | perl -npe 's/.* (\S+)\)/\1/' | sort | uniq -c | sort -nr
