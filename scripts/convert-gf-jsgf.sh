#! /bin/bash

recode utf8..latin1 $1
sed -i "s/ UTF-8;/;/" $1
sed -i "s/^public //" $1
sed -i "s/^<MAIN>/public <MAIN>/" $1
