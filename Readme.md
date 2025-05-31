# Ruby Altair BASIC

A classic BASIC interpreter written in Ruby, based on 1975 Altair BASIC written by a Paul Alan and Bill Gates for Altair 8800 machine.
With some features borrowed from later MS BASIC versions. 

## Requirements

- Ruby 2.5 or later

## Usage

```bash
ruby basic.rb
```

## Quick Start

Interpreter supports both immediate mode (REPL) commands and numbered program lines:

```basic
> PRINT "Hello, World!"
Hello, World!

> 10 FOR I = 1 TO 5
> 20 PRINT "Count: "; I
> 30 NEXT I
> RUN
Count: 1
Count: 2
Count: 3
Count: 4
Count: 5
```

## Basic Commands

- `RUN` - Execute program
- `LIST` - Display program lines
- `CLEAR` - Clear Screen
- `NEW` - Clear buffer
- `SAVE` - Save program to .bas file
- `LOAD` - Load program from .bas file
- `HELP` - Show available commands

## Features

- **Classic BASIC statements**: `PRINT`, `LET`, `IF/THEN/ELSE`, `FOR/NEXT`, `GOTO/GOSUB/RETURN`
- **Built-in functions**: Math (`SIN`, `COS`, `SQR`), String (`LEFT$`, `MID$`, `LEN`)
- **User-defined functions**: `DEF FN` with local parameters
- **Arrays**: Multi-dimensional arrays with `DIM`
- **Data handling**: `DATA`, `READ`, `RESTORE` statements
- **File I/O**: `INPUT` statement and program save/load
- **Comments**: `REM` statements (full-line and inline)

## Example Programs

**Fibonacci sequence:**
```basic
10 LET A = 0
15 LET B = 1
20 FOR I = 1 TO 10
30 PRINT A
40 LET C = A + B
45 LET A = B
50 LET B = C
60 NEXT I
```

**Simple usage of subroutines:**
```basic
10 LET N = 5
20 GOSUB 100  
30 PRINT N; "! ="; F
40 LET N = 7
50 GOSUB 100  
60 PRINT N; "! ="; F
70 END
100 LET F = 1
110 FOR I = 1 TO N
120 LET F = F * I
130 NEXT I
140 RETURN
```