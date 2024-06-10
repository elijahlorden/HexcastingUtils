<pre>
A repository containing various tools for Hexcasting (https://modrinth.com/mod/hex-casting).  Currently just a WIP FORTH-inspired compiler.

Copy contents into a Computercraft computer, place a focal port from Ducky's Peripherals (https://modrinth.com/mod/ducky-periphs) next to it, and run test.lua.  Edit the contents in test.xth to change the spell.

HexForth (.xth) language syntax

Emit a number iota.  Currently you can't emit number patterns, this may be added later.
[number] (ex. '1')

Emit a string iota:
.str [string] (ex. '.str a' or '.str "this is a string"')

Emit a pattern iota:
.pattern [direction] [angles] (ex. '.pattern north_east qaq')

Define a word.  The first token after the colon sets the name of the word.  Nested words are not supported.
: [wordname] ... ; (ex. ': get-caster .pattern north_east qaq ;')

Create a list iota.  Any words within the list are expanded in place.  Nested lists are supported.  Lists and nested lists can be defined inside words.
{ ... } (ex. '{ 1 2 3 }' or '{ word1 word2 word3 }' or '{ 1 2 { 3 4 5 } }')

Emit the contents of a word.
[string] (ex. 'wordname' or '"word name with whitespace"')

Import another source file.  File must be within one of the directories passed to Compiler.new()
.import [filename]

Define a parameter.  The user will be prompted to enter a value.  Currently only strings and numbers are supported.
.param [paramname] [prompt] (ex. '.param strength "Enter explosion strength"')

Emit a parameter:
$[paramname] (ex. '$strength')

Comments:

//Line comment

/* Block comment */

More to come eventually.

</pre>