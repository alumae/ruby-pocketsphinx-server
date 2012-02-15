#! /bin/bash

egrep "^I, \[.*INFO.*User agent.* \(RecognizerIntentActivity.*; ([^;]+\/[^;]+\/[^;]+); " $1 | 
perl -npe 's/.*User agent.* \(RecognizerIntentActivity.*; ([^;]+\/[^;]+\/[^;]+);.*/\1/' | 
sort | uniq -c | sort -nr -k1
