#! /bin/sh

. `dirname $0`/settings.sh


tempfile=`mktemp`
tempfile2=`mktemp`
tempfile3=`mktemp`

cat > $tempfile

cat $tempfile | perl -C -ne 'BEGIN{use Text::Unidecode;} chomp; $x=unidecode($_); $x=uc($x); print "$_ $x\n"' | sort -k2  > $tempfile2

cut -f 2 -d " " $tempfile2 > $tempfile3

$PHONETISAURUS --model=$EN_FST --input=$tempfile3 --isfile --words | sort | join -1 2 -2 1 $tempfile2 - | perl -npe 's/\S+\s+(\S+)\s+\S+/\1 /'

rm $tempfile $temfile2 $tempfile3
