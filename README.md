
A repository containing various tools for Hexcasting (https://modrinth.com/mod/hex-casting).
Currently just a WIP FORTH-inspired compiler.

To use:
 - Copy contents into a Computercraft computer
 - Place a focal port from Ducky's Peripherals (https://modrinth.com/mod/ducky-periphs) next to the computer
 - Run ```.Build [filename]``` (see /HexPrograms for a list)

--- HexForth (.xth) language syntax ---

Emit a number iota.  Currently you can't emit number patterns, this may be added later.
```1 //Emits the number 1```

Emit a string iota:
```
.str abc //Emits the string 'abc'
.str "Hello, world!" //Emits the string "Hello, world!"
```

Emit a pattern iota:
```.pattern [direction] [angles] //Emits "Mind's Reflection"```

Emit a vector iota:
```.vector 1 2 3 //Emits the vector [1, 2, 3]``` 

Emit a boolean iota:
```.bool true //Emits true```

Define a word.  The first token after the colon sets the name of the word.  Nested words are not supported.
```
: get-caster .pattern north_east qaq ; //Create a word named 'get-caster' that emits Mind's Reflection

: entity-position .pattern east aa ; //Create a word named 'entity-position' that emits Compass' Purification

: get-caster-position get-caster entity-position ; //Create a word that combines other words
```

Create a list iota.  Any words within the list are expanded in place.
```
{ 1 2 3 } //List of numbers
{ 1 { 2 3 } } //Nested list
{ .str "List!" } //Directives work inside lists
{ get-caster entity-position } //List of words
{ \get-caster \entity-position } //List of escaped words, looks like { \{ ... } \{ ... } }
: create-list { 1 2 3 } ; //Lists may be defined inside words
```

Emit the contents of a word.
```
get-caster entity-height //Push the caster's height onto the stack
```

Import another source file.  File must be within one of the directories passed to Compiler.new().  By default files under /HexLibs and /HexPrograms are available.
```.import hex.xth ```

Define a parameter.  The user will be prompted to enter a value.  Currently only strings and numbers are supported.
```
.param strength "Enter explosion strength" //Pauses compilation and asks the user for input
```
Emit a parameter:
```$strength```

Comments:
```
//Line comment
/*
Block comment
*/
```

Emitted iotas can be escaped with consideration by placing a backslash before the word:
```
\100 //Emits consideration and then the number 100
\.bool true //Emits consideration and then a true iota
\ .bool true //Equivalent to above
\{ 1 2 3 } //Emits consideration and then a list
```
Escaping a word emits both a consideration and the contents of the word as a list:
```
: word .pattern east www ;
\word //Equivalent to { .pattern east www }
```
Example spell found in /HexPrograms/test-sneak.xth (requires More Iotas addon for strings)
```
.include hex.xth
.include common-words.xth

get-caster entity-height \1.7 ?lt \{ \.str "Sneaking" reveal } \{ \.str "Not sneaking" reveal } ? eval
```
More to come eventually.
