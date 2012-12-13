#! /bin/bash

sed -i "s/^public //" $1
sed -i "s/^<MAIN>/public <MAIN>/" $1
