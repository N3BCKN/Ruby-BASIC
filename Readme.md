# Ruby BASIC

A classic BASIC interpreter written in Ruby, based on 1975 Altair BASIC written by Paul Allen and Bill Gates for Altair 8800 machine.
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

**User-defined functions:**
```basic
10 DEF FN SQ(X) = X * X
20 DEF FN AVG(A, B) = (A + B) / 2
30 INPUT "Enter number: "; N
40 PRINT "Square:"; FN SQ(N)
50 PRINT "Average with 10:"; FN AVG(N, 10)
```

**Working with arrays:**
```basic
10 DIM NUMS(10)
20 FOR I = 0 TO 9
30 LET NUMS(I) = I * I
40 NEXT I
50 FOR I = 0 TO 9
60 PRINT "Square of "; I; " is "; NUMS(I)
70 NEXT I
```
**DATA and READ statements:**
```basic
10 DATA "Alice", 25, "Bob", 30, "Charlie", 35
20 FOR I = 1 TO 3
30 READ NAME$, AGE
40 PRINT NAME$; " is "; AGE; " years old"
50 NEXT I
```

**Random number guessing game:**
```basic
10 LET SECRET = INT(RND * 100) + 1
20 LET TRIES = 0
30 PRINT "Guess a number between 1 and 100"
40 INPUT "Your guess: "; GUESS
50 LET TRIES = TRIES + 1
60 IF GUESS = SECRET THEN GOTO 100
70 IF GUESS < SECRET THEN PRINT "Too low!"
80 IF GUESS > SECRET THEN PRINT "Too high!"
90 GOTO 40
100 PRINT "Congratulations! You got it in "; TRIES; " tries!"
```

**Mathematical calculations:**
```basic
10 INPUT "Enter angle in degrees: "; DEG
20 LET RAD = DEG * 3.14159 / 180
30 PRINT "Sine:"; SIN(RAD)
40 PRINT "Cosine:"; COS(RAD)
50 PRINT "Tangent:"; TAN(RAD)
60 PRINT "Square root of angle:"; SQR(ABS(DEG))
```

**Simple menu system:**
```basic
10 PRINT "Calculator Menu"
20 PRINT "1. Add"
30 PRINT "2. Subtract"  
40 PRINT "3. Multiply"
50 PRINT "4. Divide"
60 INPUT "Choose option: "; CHOICE
70 INPUT "Enter first number: "; A
80 INPUT "Enter second number: "; B
90 IF CHOICE = 1 THEN PRINT "Result: "; A + B
100 IF CHOICE = 2 THEN PRINT "Result: "; A - B
110 IF CHOICE = 3 THEN PRINT "Result: "; A * B
120 IF CHOICE = 4 THEN PRINT "Result: "; A / B
130 IF CHOICE < 1 OR CHOICE > 4 THEN PRINT "Invalid choice!"
```

**Formatted output with TAB:**
```basic
10 PRINT "Name"; TAB(20); "Age"; TAB(30); "Score"
20 PRINT "----"; TAB(20); "---"; TAB(30); "-----"
30 DATA "John", 25, 95, "Andrew", 30, 87, "Rose", 35, 92
40 FOR I = 1 TO 3
50 READ NAME$, AGE, SCORE
60 PRINT NAME$; TAB(20); AGE; TAB(30); SCORE
70 NEXT I
> RUN
Name                Age       Score
----                ---       -----
John                25        95
Andrew              30        87
Rose                35        92
```
