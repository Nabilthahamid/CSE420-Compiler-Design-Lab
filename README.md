# CSE420 Compiler Design Lab

Coursework for **CSE420: Compiler Design**, implemented with Flex, Yacc/Bison,
and C++. The repository develops a small C-like language processor in stages,
from lexical and syntax analysis to semantic checking and intermediate-code
generation.

## Student Information

- Student ID: `22301651`
- Course: CSE420 Compiler Design

## Repository Structure

| Directory | Description |
| --- | --- |
| `Task1/` | Flex scanner and Yacc/Bison parser for lexical and syntax analysis |
| `Task2/` | Parser integration with scoped symbol-table management |
| `Task3/` | Syntax and semantic analysis with type and declaration checks |
| `Lab 4/` | AST construction and three-address intermediate-code generation |

Each task contains its Flex source (`22301651.l`), grammar
(`22301651.y`), supporting C++ headers, a build script, and sample input or
output files where applicable.

## Features

- Tokenization of keywords, identifiers, constants, operators, and punctuation
- Parsing of a C-like grammar with declarations, functions, expressions, and
  control-flow statements
- Nested scope and symbol-table management
- Semantic checks for declarations, arrays, functions, arguments, and types
- Abstract syntax tree construction
- Three-address code generation
- Detailed log and error reports

## Requirements

Install the following tools in Linux, WSL, or another Bash-compatible
environment:

- `g++` with C++17 support
- Flex
- Bison or a compatible `yacc`
- Bash

For Ubuntu or WSL:

```bash
sudo apt update
sudo apt install build-essential flex bison
```

## Build and Run

Run a task from the directory containing its source files. For example:

```bash
cd Task3
chmod +x script.sh
./script.sh input.c
```

To build Lab 4 directly with the files in this repository:

```bash
cd "Lab 4/22301651"
yacc -d -y --debug --verbose 22301651.y
g++ -std=c++17 -w -c -o y.o y.tab.c
flex 22301651.l
g++ -std=c++17 -fpermissive -w -c -o l.o lex.yy.c
g++ y.o l.o -o two_pass_compiler
./two_pass_compiler input1.c
```

Lab 4 writes its parser trace to `log.txt`, diagnostics to `error.txt`, and
generated three-address code to `code.txt`.

## Notes

Generated parser/scanner sources, object files, executables, archives, and
temporary verification directories are intentionally excluded from version
control. They can be reproduced from the checked-in source files and scripts.

