# Exercises Week 2

## Exercise 01: Arithmetic Expressions
Please find the solutions to Part A and B below. I went a little overboard with this exercies implementing a simple stack
machine and compiler for it (please see section "Extra").

### Part A
Please find a manual execution of the stack machine program in part A of the exercise below. The left column contains
the instruction to be executed and the right column the state of the stack after execution.

```
Instruction                 Stack
------------                ------
push 4                      |  4 |   <-- TOS
                            
push 2                      |  2 |   <-- TOS
                            |  4 |

push 24                     | 24 |   <-- TOS
                            |  2 |
                            |  4 |

push 21                     | 21 |   <-- TOS
                            | 24 |
                            |  2 |
                            |  4 |

sub                         |  3 |   <-- TOS
                            |  2 |
                            |  4 |


mult                        |  6 |   <-- TOS
                            |  4 | 

add                         | 10 |   <-- TOS

```

The result of executing the program (left on the top of the stack) is `10`.

### Part B
We can recreate the expression by executing the same program as in the previous exercise but instead of replacing the
TOS with the evaluated expression we put the symbolical equivalent there instead (e.g `(24 - 21)` vs `3`).

```
Instruction                 Stack
------------                ------
push 4                      |  4 |   <-- TOS
                            
push 2                      |  2 |   <-- TOS
                            |  4 |

push 24                     | 24 |   <-- TOS
                            |  2 |
                            |  4 |

push 21                     | 21 |   <-- TOS
                            | 24 |
                            |  2 |
                            |  4 |

sub                         | (24 - 21) |   <-- TOS
                            |         2 |
                            |         4 |


mult                        | 2 * (24 - 21) |   <-- TOS
                            |             4 | 

add                         | 4 + 2 * (24 - 21) |   <-- TOS

```

In binary tree form this is equivalent to the expression:

```
      '+'
     /   \ 
    4    '*'
         / \
        2  '-'
           / \
          24 21 
```


### Extra
With the overview of the compiler frontend / backend and stack machine in activity 2 "Overview of the compiler and stack
machine". I was inspiried to try to implement a simple stack-machine based on my current understanding. 

The model of the machine is an object consisting of

1. A stack represented by an instance of `Stack` (see `<root>/elements/containers/stack.lua`).
2. An array of memory, represented by an array (e.g table with integer indices), containing instructions and data.
3. A `PC` (program counter) register that keeps track of the location of the next instruction in memory.
4. Logic to fetch and decode instructions that manipulate the stack, memory and PC.

The implementation can be found in `<root>/lesson-2/exercises/components_01/machine.lua`.

The "compiler" (`<root>/lesson-2/exercises/components_01/compiler.lua`) is built on-top of the grammar we built in
lesson-1. I've updated the grammar to generate a `BinaryTree` (see `<root>/elements/containers/BinaryTree`) from the
match function.

There is also new function `compile` that takes a string as input, generates and AST using the grammar (frontend part)
and does code generation (backend part) by a postorder traversal of the `BinaryTree`. The output is an array containing
opcodes and program data.

The file `<root>/lesson-2/exercises/exercise_01.lua` loads the compiler and stack machine components and then runs a few
`luaunit` tests that evaluats varios expressions.

## Exercise 02: Hexadecimal numbers

### Note
This exercise builds on-top of the last exercise. I've copied the `machine.lua` and `compiler.lua` to the folder
`<root>/lesson-2/exercies/components_02/` and then added updates there. This way it's easier to follow along on the
updates. One can simply `diff` two implementations to see the updates done w.r.t the current exercies.  I'll follow this
pattern going forward.

As usual tests for the exercies can be found in `<root>/lession-2/exercies/exercie_02.lua`.

### Extending the grammar to accept hexadecimal numbers.
I added `hex_digit` and `hex_integer` patterns as can be seen below and modified the numeral pattern accordingly.


```
diff -Naur lesson-2/exercises/components_01/compiler.lua lesson-2/exercises/components_02/compiler.lua
--- lesson-2/exercises/components_01/compiler.lua       2023-12-09 20:07:20.110563096 +0100
+++ lesson-2/exercises/components_02/compiler.lua       2023-12-10 00:34:58.864542134 +0100
@@ -17,11 +17,18 @@
 local digit = lpeg.R("09")
 local positive_integer = digit^1
 local integer = sign^-1 * positive_integer
-local numeral = (((integer * dot * positive_integer)
+
+-- START CHANGES FOR EXERCISE 02: HEXADECIMAL NUMBERS
+local hex_digit = lpeg.R("09") + lpeg.R("af") + lpeg.R("AF")
+local hex_integer = sign^-1 * "0" * lpeg.S("xX") * hex_digit^1
+
+local numeral = ((hex_integer
+                   + (integer * dot * positive_integer)
                    + (sign^-1 * dot * positive_integer)
                    + (integer * dot)
                    + integer) / tonumber) * space

+-- END CHANGES FOR EXERCISE 02: HEXADECIMAL NUMBERS

 -- Operators
 local opA = lpeg.C(lpeg.S"+-") * space

```

## Exercise 03: Adding Multiplication and Division

### Part A
The compiler and machine from exercise 01 already supports multiplication and division so I consider this exercise
already satisfied.

### Part B
I extended the `Machine` class with one method `Machine:setTrace (trace)` that accepts a boolean and allows toggling of
program tracing. The `Machine:step()` function now outputs a trace (if turned) on on the form

```
<address> <op_code_name> [<operand>]
```

### Note
The diff between the compiler and machine from previous exercies is pretty large due to me using lookup tables instead
of branching over Machine opcodes.


## Exercise 04: Adding More Operators - Part 1
This exercise is already satisfied by the implementation of the stack machine / compiler in exercise 01.

## Exercise 05: Adding More Operators - Part 2

### Part A
To add a unary negation (-) operator I extended the grammar as follows:

1. Add a new operator `local opN = lpeg.C(lpeg.P"-") * space` capture-pattern.
2. Extend the grammar wth a new non-terminal (variable) `local negation = lpeg.V"negation"`
3. Add the following line to the grammar pattern betweem the `exponent` and `term` expressions:
```
exponent = space * lpeg.Ct((primary * opE)^0 * primary) / processOpR,
negation = space * lpeg.Ct(opN^0 * exponent) / processUnaryOp, -- NEW!
term = space * lpeg.Cf(negation * lpeg.Cg(opM * negation)^0, processOpL),
```
Additionally I 

* split the node-tag for opertors into `unary_operator` and `binary_operator`,
* added functions to construct and AST-part from these subexpressions.
* added a new opcode to the `Machine` with an associated operation to negate the TOS (e.g pop, negate, push).


#### Note 1
I wanted the unary `-` to have lower priority than `^` so that `-2^3` is interpreted as `-(2^3)` and not `(-2)^3`.

#### Note 2
As a side effect of using `-` as a negation operator expression such as `3 + -2` actually compiles into
```
PUSH 3
PUSH 2
NEG
ADD
```
Evaluation-wise this is equivlant but less performant. 

#### Note 3
My grammar `g` allows for expression such as `---3`. Since I don't have a optimization strategy in the code generation
part of the compiler this will lead to programs such as
```
PUSH 3
NEG
NEG
NEG
```

### Part B
In a similar way to part A I extended the grammar by:

1. Adding a new operator `local opC = lpeg.C(lpeg.P"!=" + "==" + "<=" + ">=" + "<" + ">") * space` capture-pattern.
2. Extending the grammar with a new non-terminal (variable) `local addend = lpeg.V"addend"`
3. Addng the following line to the grammar pattern `addend = space * lpeg.Cf(term * lpeg.Cg(opA * term)^0, processOpL),` 
4. And modifying the last definition to use the new operator `opC`: `expression =  space * lpeg.Cf(addend * lpeg.Cg(opC * addend)^0, processOpL),`

The machine and compiler where updated accordingly to execute / generate instructions for the new operations.

### Note:
Please refer to the diffs 
```
diff -Naur lesson-2/exercises/components_03/compiler.lua lesson-2/exercises/components_05/compiler.lua
diff -Naur lesson-2/exercises/components_03/machine.lua lesson-2/exercises/components_05/machine.lua
```
for a full set of changes.


