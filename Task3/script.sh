#!/bin/bash

set -e

input_file="${1:-input.c}"

yacc -d -y --debug --verbose 22301651.y
echo 'Generated the parser C file as well the header file'
g++ -w -c -o y.o y.tab.c
echo 'Generated the parser object file'
flex 22301651.l
echo 'Generated the scanner C file'
g++ -fpermissive -w -c -o l.o lex.yy.c
# if the above command doesn't work try g++ -fpermissive -w -c -o l.o lex.yy.c
echo 'Generated the scanner object file'
g++ -o 22301651.out y.o l.o
echo 'All ready, running'
./22301651.out "$input_file"
echo 'logfile'
cat 22301651_log.txt
echo 'error file'
cat 22301651_error.txt
