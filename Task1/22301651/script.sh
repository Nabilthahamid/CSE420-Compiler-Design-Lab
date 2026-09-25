#!/bin/bash
set -e

yacc -d -y --debug --verbose 22301651.y
echo 'Generated the parser source and header files'

g++ -std=c++17 -w -c -o y.o y.tab.c
echo 'Generated the parser object file'

flex 22301651.l
echo 'Generated the scanner source file'

g++ -std=c++17 -fpermissive -w -c -o l.o lex.yy.c
echo 'Generated the scanner object file'

g++ y.o l.o -o 22301651_parser.exe
echo 'Build complete; running input.txt'

./22301651_parser.exe input.txt
