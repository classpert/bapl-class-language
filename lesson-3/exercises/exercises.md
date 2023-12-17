# Exercises Week 3

## Initial Note
For each exercise `<cwd>/exercises_<sequence>.lua` you'll find a correspond `<cwd>/components_<sequence>` directory
holding the current state of the stack machine and compiler for the machine. Test relevant for the problem set can be
found in `<cwd>/exercise_<sequence>.lua`. 

To run a exercise set follow these instructions:

```
cd <repo-root>
sequence=<sequence>  # E.g "01" or "04"
LUA_PATH="lesson-3/exercises/?.lua;lesson-3/exercises/components_${sequence}/?.lua;;" lua lesson-3/exercises/exercises_${sequence}.lua
```

## Exercise 01: Rules for identifiers
I define an identifier to be anything that starts with an alpha or underscore character and contain one or more
repetitions of an alphanumerical or underscore character. These are the relevant excerpts from
`<cwd>/components_02/compiler.lua`:

```lua
-- Identifiers and variables
local function variableNode(variable)
    return Tree:new({tag = "variable", value = variable})
end
local underscore = lpeg.P"_"
local alpha = lpeg.R("AZ", "az")
local alphanum = alpha + digit
local identifier_prefix = alpha + underscore
local identifier_postfix = alphanum + underscore
local identifier = lpeg.C(identifier_prefix * identifier_postfix^0) * space
local variable = identifier / variableNode

-- ...

local primary = lpeg.V"primary"
local exponent = lpeg.V"exponent"
local negation = lpeg.V"negation"
local term = lpeg.V"term"
local addend = lpeg.V"addend"
local expression = lpeg.V"expression"

local g = lpeg.P{
    "expression",
    primary = numeral + variable + OP * expression * CP,
    exponent = space * lpeg.Ct((primary * opE)^0 * primary) / processOpR,
    negation = space * lpeg.Ct(opN^0 * exponent) / processUnaryOp,
    term = space * lpeg.Cf(negation * lpeg.Cg(opM * negation)^0, processOpL),
    addend = space * lpeg.Cf(term * lpeg.Cg(opA * term)^0, processOpL),
    expression = space * lpeg.Cf(addend * lpeg.Cg(opC * addend)^0, processOpL), 
}
g = g * -1

```

## Exercise 02: Empty statement
These are the relevant excerpts from `<cwd>/components_02/compiler.lua`:

```lua
local primary    = lpeg.V"primary"
local exponent   = lpeg.V"exponent"
local negation   = lpeg.V"negation"
local term       = lpeg.V"term"
local addend     = lpeg.V"addend"
local expression = lpeg.V"expression"

-- Expression grammar
local grammar_expression = lpeg.P{
    "expression",
    primary    = numeral + variable + OP * expression * CP,
    exponent   = space * lpeg.Ct((primary * opE)^0 * primary) / processOpR,
    negation   = space * lpeg.Ct(opN^0 * exponent) / processUnaryOp,
    term       = space * lpeg.Cf(negation * lpeg.Cg(opM * negation)^0, processOpL),
    addend     = space * lpeg.Cf(term * lpeg.Cg(opA * term)^0, processOpL),
    expression = space * lpeg.Cf(addend * lpeg.Cg(opC * addend)^0, processOpL), 
}

-- ...
local function assignmentNode(identifier, expression)
    if expression then
        return Tree:new({tag = "assignment", identifier = identifier, expression = expression})
    else
        return Tree:new({tag = "empty_statement"})
    end
end

local function sequenceNode(head, tail)
    if tail == nil then -- only a singular assignment
        return head
    else
        return Tree:new({tag = "sequence"}, head, tail)
    end
end


local statement = lpeg.V"statement"
local sequence  = lpeg.V"sequence"
local block     = lpeg.V"block"
-- Statement grammar
local grammar = lpeg.P{
    "sequence",
    sequence   = statement * (SC * sequence)^-1 / sequenceNode,
    block      = space * OB * sequence * SC^-1 * CB,
    statement  = space * block + (identifier * opAssign * expression)^-1 / assignmentNode,
    expression = space * grammar_expression,
}
grammar = grammar * -1

```
### Note
I split the grammar into two; one containing the expression grammar and one containing the _sequence_ grammar.


## Exercise 03: Print statement
I started by adding a reserved `@` print statement to the grammar as follows:

```lua
local function printNode(expression)
    return Tree:new({tag = "print", expression = expression})
end

local statement = lpeg.V"statement"
local sequence  = lpeg.V"sequence"
local block     = lpeg.V"block"
-- Statement grammar
local grammar = lpeg.P{
    "sequence",
    sequence   = statement * (SC * sequence)^-1 / sequenceNode,
    block      = space * OB * sequence * SC^-1 * CB,
    statement  = space * block 
                 + space * (ret * expression) / returnNode
                 + space * (prnt * expression) / printNode
                 + space * (identifier * opAssign * expression)^-1 / assignmentNode,
    expression = space * grammar_expression,
}
grammar = grammar * -1

```
And code generation for the statement:
```lua
    elseif node.tag == "print" then
        if node.expression ~= nil then
            codeGenExp(node.expression, env, memory)
        end
        table.insert(memory, Machine.OPCODES.PRINT)
    else
```

In the virtual stack machine I added a branch to process print statements:
```lua
    elseif op == Machine.OPCODES.PRINT then
        self.io_:write(self.stack_:peek())
        self.pc_ = self.pc_ + 1
```

### Note
The `Machine` class now also accepts a IO object during construction (defaults to io.stdout).

## Exercise 04: Undefined variables
My code generating functions takes and `env` environment variable as input containing information about assignments
(currently only global assignments). If we attempt to use a variable in an `expression` w/o it being set in the `env`
table I raise and error. The relevant code snippet can be found here:

```lua

local function codeGenExp(ast, env, code) 
    -- ... 
    elseif node.tag == "variable" then
        -- check that the variable has been defined
        assert(env[node.identifier] ~= nil, make_error(ERROR_CODES.UNDEFINED_VARIABLE, {identifier = node.identifier}))

        table.insert(code, Machine.OPCODES.LOAD)
        -- Insert a sentinel value. We will update this with an pointer to the storage 
        -- of the variable during the program generation phase.
        table.insert(code, 0xdeadc0de)
        envAddRef(env, node.identifier, #code) -- Add a reference to identifier location
    -- ...
end

```
