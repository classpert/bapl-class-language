# Exercises Week 5

## Initial Note
For each exercise `<cwd>/exercises_<sequence>.lua` you'll find a correspond `<cwd>/components_<sequence>` directory
holding the current state of the stack machine and compiler for the machine. Test relevant for the problem set can be
found in `<cwd>/exercise_<sequence>.lua`. 

To run a exercise set follow these instructions:

```
cd <repo-root>
sequence=<sequence>  # E.g "01" or "05"
LUA_PATH="lesson-5/exercises/?.lua;lesson-5/exercises/components_${sequence}/?.lua;;" lua lesson-5/exercises/exercises_${sequence}.lua
```

## Exercise 01: 'not' Operator
To implement the logical not operator I started out by adding a new unary operator `!` to the grammar with the same
priority as the additive inverse `-`. This follows the implementation the `C` styled `!` (and `-`). The only relevant
change in the compiler is:

```lua
local opN = lpeg.C(lpeg.S"-!") * space
```

In the virtual machine part I added a new operation `NOT` that pops `TOS(0)` and pushes `0` if `TOS(0) != 0` and `1`
otherwise.

The relevant diff against the most recent `machine.lua` implementation:
```diff
--- lesson-4/machine.lua	2023-12-25 20:06:34.924204132 +0100
+++ lesson-5/exercises/components_01/machine.lua	2023-12-31 10:57:38.326676573 +0100
@@ -27,27 +27,38 @@
 Machine.OPCODES.LE        = 0x29 -- Pop 2 elements TOS(0), TOS(1) and push the comparsion TOS(1) <= TOS(0) to TOS(0)
 Machine.OPCODES.GT        = 0x2a -- Pop 2 elements TOS(0), TOS(1) and push the comparsion TOS(1) > TOS(0) to TOS(0)
 Machine.OPCODES.GE        = 0x2b -- Pop 2 elements TOS(0), TOS(1) and push the comparsion TOS(1) >= TOS(0) to TOS(0)
-Machine.OPCODES.NEG       = 0x30 -- Pop1 element TOS(0) and push the negation -TOS(1) to the stack.
+Machine.OPCODES.NEG       = 0x30 -- Pop 1 element TOS(0) and push the negation -TOS(0) to the stack.
+Machine.OPCODES.NOT       = 0x31 -- Pop 1 element TOS(0) and push the logical negation !TOS(0) to the stack.
 Machine.OPCODES.RETURN    = 0xA0 -- Exit current function. Note: for now it exits the VM run function.
 Machine.OPCODES.JMP       = 0xA1 -- Jump unconditionally, pc <- memory[pc + 1]
 Machine.OPCODES.HALT      = 0xF0 -- Halt the machine,
 Machine.OPCODES.PRINT     = 0xF1 -- Print TOS via io channel. Leaves stack unchanged.
+
+function toBool (a)
+    return (a ~= 0)
+end
+
+function fromBool (a)
+    return a and 1 or 0
+end
+
 Machine.OPCODES.BINOP_LOOKUP = {
-    [Machine.OPCODES.ADD] = function (a, b) return a + b end,
-    [Machine.OPCODES.SUB] = function (a, b) return a - b end,
+    [Machine.OPCODES.ADD]  = function (a, b) return a + b end,
+    [Machine.OPCODES.SUB]  = function (a, b) return a - b end,
     [Machine.OPCODES.MULT] = function (a, b) return a * b end,
-    [Machine.OPCODES.DIV] = function (a, b) return a / b end,
-    [Machine.OPCODES.REM] = function (a, b) return a % b end,
-    [Machine.OPCODES.EXP] = function (a, b) return a ^ b end,
-    [Machine.OPCODES.EQ] = function (a, b) return a == b and 1 or 0 end,
-    [Machine.OPCODES.NEQ] = function (a, b) return a ~= b and 1 or 0 end,
-    [Machine.OPCODES.LT] = function (a, b) return a < b and 1 or 0 end,
-    [Machine.OPCODES.LE] = function (a, b) return a <= b and 1 or 0 end,
-    [Machine.OPCODES.GT] = function (a, b) return a > b and 1 or 0 end,
-    [Machine.OPCODES.GE] = function (a, b) return a >= b and 1 or 0 end,
+    [Machine.OPCODES.DIV]  = function (a, b) return a / b end,
+    [Machine.OPCODES.REM]  = function (a, b) return a % b end,
+    [Machine.OPCODES.EXP]  = function (a, b) return a ^ b end,
+    [Machine.OPCODES.EQ]   = function (a, b) return fromBool(a == b) end,
+    [Machine.OPCODES.NEQ]  = function (a, b) return fromBool(a ~= b) end,
+    [Machine.OPCODES.LT]   = function (a, b) return fromBool(a < b) end,
+    [Machine.OPCODES.LE]   = function (a, b) return fromBool(a <= b) end,
+    [Machine.OPCODES.GT]   = function (a, b) return fromBool(a > b) end,
+    [Machine.OPCODES.GE]   = function (a, b) return fromBool(a >= b) end,
 }
 Machine.OPCODES.UNARYOP_LOOKUP = {
     [Machine.OPCODES.NEG] = function (a) return -a end,
+    [Machine.OPCODES.NOT] = function (a) return fromBool(not(toBool(a))) end,
 }
 Machine.OPCODES.NAME_LOOKUP = {
     [Machine.OPCODES.PUSH]      = "PUSH",
@@ -66,6 +77,7 @@
     [Machine.OPCODES.GT]        = "GT",
     [Machine.OPCODES.GE]        = "GE",
     [Machine.OPCODES.NEG]       = "NEG",
+    [Machine.OPCODES.NOT]       = "NOT",
     [Machine.OPCODES.RETURN]    = "RETURN",
     [Machine.OPCODES.JMP]       = "JMP",
     [Machine.OPCODES.HALT]      = "HALT",
```

### Note: Regarding the priority
With the `C`-styled priority of the logical negation operator it's important to understand that statement

```
y = ! x + 1 > 0
```

is equivalent to

```
y = (!x) + 1 > 0
```
which incidentally is always true since `!x` is at least `0`. 


One has to use parenthesis to negate the whole comparison:

```
y = !(x + 1 > 0)
```

These cases are covered in the tests `lesson-5/exercises/exercises_01.lua`.

## Exercise 02: Rewriting the function 'node'
Using the following implementation of the `node` function I could eliminate _all_ other node-like function:

```
local function node(tag, ...)
    local labels = {...}
    return function (...)
        node = {tag = tag}
        local params = {...}
        for idx = 1, #labels do
            node[labels[idx]] = table.remove(params, 1)
        end
        if #params > 0 then
            return Tree:new(node, table.unpack(params))
        else
            return Tree:new(node)
        end
    end
end
```

### Note
I store the _AST_ in a tree structure with nodes and children. A `sequence` subtree, for instance, only stores a tag in
the tree node and "sub-sequences" as children.

### Note
For a complete diff of the compiler against the previous exercies see:
```
diff -Naur lesson-5/exercises/components_01/compiler.lua lesson-5/exercises/components_02/compiler.lua 
```


## Exercise 03: Relative jumps.
I went a slightly different route w.r.t to the branch-instructions. Instead of generating two entires in the code table
(e.g {`JMPZ`, `<offset>`}) I embedded the jump offset in the lower `32` bits of my branch instruction. 

From this exercise onwards all my virtual machine instructions are `64` bit long the upper `8` bits encodes a
instruction "variant" (e.g `BZ` branch zero) and the lower `56` bits contain a instruction specific payload (often
empty).

My branch instruction now takes this form:

```
64            56                            32                                          0
+--------------+-----------------------------+------------------------------------------+
| variant code |            0                |             offset + 0x7fffffff          |
+--------------+-----------------------------+------------------------------------------+

```

Of course this introduces a limitation w.r.t how far one can jump relative to the location of the branch instruction
(e.g `offset \in (-2147483648, 2147483648]`). 


Please see the diff 
```
diff -Naur lesson-5/exercises/components_02/compiler.lua lesson-5/exercises/components_03/compiler.lua 
```
for implementations details.

## Exercise 04: 'elseif'
For this exercise the code generation part is the same for the `if-else` implementation. The relevant changes are all in
the grammar:

```lua
local statement = lpeg.V"statement"
local sequence  = lpeg.V"sequence"
local block     = lpeg.V"block"
local ifstmt    = lpeg.V"ifstmt"
local ifrest    = lpeg.V"ifrest"
-- Statement grammar
local grammar = lpeg.P{
    "sequence",
    sequence   = statement * (T";" * sequence)^-1 / node("sequence"),
    block      = space * T"{" * sequence * T";"^-1 * T"}",
    ifstmt     = space * (R("if") * expression * block * (ifrest + R("else") * block)^-1) 
                         / node("if_", "condition", "ifblock", "elseblock"),
    ifrest     = space * (R("elseif") * expression * block * (ifrest + R("else") * block)^-1) 
                         / node("if_", "condition", "ifblock", "elseblock"),
    statement  = space * block 
                 + space * ifstmt
                 + space * (R("return") * expression) / node("return", "expression")
                 + space * (R("@") * expression) / node("print", "expression")
                 + space * (identifier * opAssign * expression)^-1 / node("assignment", "identifier", "expression"),
    expression = space * grammar_expression,
    space      = grammar_space,
}
grammar = grammar * -1

```

Note the introduction of `ifstmt` and `ifrest` non-terminals. `ifrest` is essentially the same as `ifstmt` but it cannot
be used alone as a statement. By this construction we get the desired nesting of `elseif` as `if`-statments inside a
block.

## Exercise 05: Logical operators.
I followed the suggested implementation method (although using my version of offset-embedded branching instructions).
Please refer to tests and diff for implementation details. 
