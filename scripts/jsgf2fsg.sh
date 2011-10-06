#! /bin/sh

if [ $# -ne 2 ]
then
  echo "Usage: `basename $0` jsgf fsg"
  exit 1
fi

#sphinx_jsgf2fsg -jsgf $1 -fsg $2

sphinx_jsgf2fsg -jsgf $1 -fsm ${1%.*}.fsm  -symtab ${1%.*}.sym

fstcompile --arc_type=log --acceptor --isymbols=${1%.*}.sym --keep_isymbols ${1%.*}.fsm | \
	fstdeterminize | fstminimize | fstrmepsilon |  fstprint | \
	`dirname $0`/fsm2fsg.py > $2
