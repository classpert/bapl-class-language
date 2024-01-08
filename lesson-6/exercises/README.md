# Exercises Week 6

## Initial Note
For each exercise `<cwd>/exercises_<sequence>.lua` you'll find a correspond `<cwd>/components_<sequence>` directory
holding the current state of the stack machine and compiler for the machine. Test relevant for the problem set can be
found in `<cwd>/exercise_<sequence>.lua`. 

To run a exercise set follow these instructions:

```
cd <repo-root>
sequence=<sequence>  # E.g "01" or "05"
LUA_PATH="lesson-6/exercises/?.lua;lesson-6/exercises/components_${sequence}/?.lua;;" lua lesson-5/exercises/exercises_${sequence}.lua
```

## Exercise 01: Loops in Arrays
> In languages like Lua, we can create an array and set it as the value of its first element:
```lua
a = {}
a[1] = a
```
> After that, `a[1][1]...[1]` is equal to `a[1]`, for any number of indexations.
> Can you do the same in other languages?

Yes. Dynamically typed languages that can store references to other objects (e.g tables / lists) can achieve this:

*Javascript*
```javascript
a = {}
a[1] = a
console.log(a == a[1](
// Prints 'true'
```

*Python*
```python
a = {}
a[0] = a
print(a[0] == a)
# Prints 'True'
```

> If not, why not?
Even with strict typing it might be possible to achieve something akin to what we see above as long as the language
support references and union-types. E.g something like this (very contrieved example):
*Ocaml*
```ocaml
type 'a t = Object of 'a | Array of ('a t) ref array
let rec (a : int t) = Array ([| ref a |])
(* returns an object with a cycle ... *)
```

However it requires us to define a new (weired) type so it's no longer uses the built in `array` type.


## Exercise 02: Adding checks of "index out of range" to the interpreter.
To support arrays in the virtual stack machine I added three instructions `NEWARR`, `GETARR` and `SETARR`. 

The `NEWARR` instruction pops the size of the array from the stack and pushes an array-object, represented as an Lua
table, to the stack. The table has a metadata field `size` that represents the size of the "allocated" storage.

`GETARR` and `SETARR` uses this metadata to check that inidices are within bounds:


```lua
    elseif op_variant == Machine.OPCODES.GETARR then
        local tos_0 = self.stack_:pop() -- index
        local tos_1 = self.stack_:pop() -- array
        assert(type(tos_1) == "table", make_error(ERROR_CODES.TYPE_MISMATCH, {message = "Expected array"}))
        assert(1 <= tos_0 and tos_0 <= tos_1.size, make_error(ERROR_CODES.INDEX_OUT_OF_RANGE, {message = "Index out of range"}))

        self.stack_:push(tos_1[tos_0])
        self.pc_ = self.pc_ + 1
    elseif op_variant == Machine.OPCODES.SETARR then
        local tos_0 = self.stack_:pop() -- value
        local tos_1 = self.stack_:pop() -- index
        local tos_2 = self.stack_:pop() -- array
        assert(type(tos_2) == "table", make_error(ERROR_CODES.TYPE_MISMATCH, {message = "Expected array"}))
        assert(1 <= tos_1 and tos_1 <= tos_2.size, make_error(ERROR_CODES.INDEX_OUT_OF_RANGE, {message = "Index out of range"}))

        tos_2[tos_1] = tos_0

        self.pc_ = self.pc_ + 1
```

Please see tests in `lesson-6/exercises_02.lua` for relevant tests.

## Exercise 03: Garbage Collection
> Remember that garbage collection in our language is based on the garbage collection of Lua. The garbage collector of
> Lua doesn't know about our language; it only collects what is garbage for Lua. How does that impact our
> implementation? 

*Memory leaks*
If we are careless and - for instance - don't null out unused values in the tables that make up our interpret/vm
implementation we might end up with a ever growing memory footprint. Consider for instance the following example:

Our interpret implements the "stack" as a table `stack` and an index `tos` pointing to the TOS. Operating on the stack
means altering `tos` and/or writing elements to `stack[tos]`:

```
op      stack         tos
---     -----         ---
N/A     {}            0
PUSH 1  {1}           1
PUSH 2  {1, 2}        2
PUSH 3  {1, 2, 3}     3
POP     {1, 2, 3}     2
POP     {1, 2, 3}     1
```
Notice that we _haven't_ told Lua that elements 2, 3 in the example above are no longer of interests to us and the
storage for these should be cleaned up (note: instead of integer the values on the stack could be large tables...).

> Could we change anything to make it more "garbage-collection" friendly?
For one thing we could overwrite unused items in the tables that make up our vm/interpreter with null values to tell Lua
that we should / can free up memory on next garbage collection cycle.

Also if we want to control the gc cycles explicitly we could inject a Lua `collectgarbage()` call for instance after we
executed a `STORE` instruction (or perhaps after every _n_:th store instruction). Since then we know that we have
invalidated data.

Please see tests for this exercise for some interesting result related to the point above.

## Exercise 04: Printing Arrays
I modified the print instruction as follows:

```lua
    elseif op_variant == Machine.OPCODES.PRINT then
        local tos_0 = self.stack_:pop()
        local out   = ""
        if type(tos_0) == "number" then
            out = tostring(tos_0)
        elseif type(tos_0) == "table" then
            out = utils.printArray(tos_0)
        else
            out = tos_0
        end
        
        self.io_:write(out .. "\n")
        self.pc_ = self.pc_ + 1

```

Where the `utils.printArray` function has the following definition:

```lua
function utils.printArray(array)
    local parts = {}
    for i = 1,array.size do
        local e = array[i]
        if type(e) == "nil" then
            table.insert(parts, "")
        elseif type(e) == "number" then
            table.insert(parts, tostring(e))
        elseif type(e) == "table" then
            table.insert(parts, utils.printArray(e))
        else
            table.insert(parts, e)
        end
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

```

E.g for a non-filled array of size 3 we'll get an output as `{,,}`, if we set the second element to `5` the printout
would be `{,5,}`. Please see tests for more examples.

## Exercise 05: Multidimensional Arrays
The grammar part of the multidimensional array follow along the implementation in the lectures (adopted of course for my
particular implementation). Relevant grammar snippets:

```lua

local function processNew(lst, index)
    local index = index or 1
    local size = lst[index]
    if #lst == index then
        return Tree:new({tag = "new", size = size})
    else
        return Tree:new({tag = "new", size = size, rest = processNew(lst, index + 1)})
    end
end
-- ...

local grammar = lpeg.P{
    "program",
    program     = space * sequence,
    primary     = lpeg.Ct(R"new" * (T"[" * expression * T"]")^1) /  processNew
                + numeral 
                + T"(" * expression * T")"
                + lhs,
-- ...
    lhs         = lpeg.Ct(variable * (T"[" * expression * T"]")^0) / processIndex
                + variable,
-- ... 
```

To actually generate the code that instanciate the array I added a few new instructions `DUP`, `DEC`, `SETARRP` and
`POP` (see `lession-6/exercises/components_06/machine.lua` for their definitions). Then I added the following function
to the compiler:

```
function Compiler:codeGenNew(ast)
    local node = ast:node()

    local size = node.size
    local rest = node.rest
    self:codeGenExp(size)
    table.insert(self.code_, OPCODES.make(OPCODES.NEWARR)) 
    if rest then
        self:codeGenExp(size)
        table.insert(self.code_, OPCODES.make(OPCODES.DUP))
        table.insert(self.code_, 0xdeadc0de) -- We will place the branch instruction here.
        local bz_location = #self.code_
        self:codeGenNew(rest)  
        table.insert(self.code_, OPCODES.make(OPCODES.SETARRP))  
        table.insert(self.code_, OPCODES.make(OPCODES.DEC))
        table.insert(self.code_, OPCODES.make(OPCODES.DUP))
        table.insert(self.code_, self:branchRelative(OPCODES.B, bz_location - self:nextCodeLoc()))
        self.code_[bz_location] = self:branchRelative(OPCODES.BZ, self:nextCodeLoc() - bz_location)
        table.insert(self.code_, OPCODES.make(OPCODES.POP))
    end
end

```
That generates the code that fills the tables, inner most first and then working itself upwards. Please see
`lesson-6/exercises/exercises_05.lua` for tests.
