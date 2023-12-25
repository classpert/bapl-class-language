# Exercises Week 4

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

## Exercise 01: Error messages with line numbers.
Following the suggestions in the preceding lectures I attached a match-time capture to the space lpeg-pattern

```lua
-- Position match time capture.
local max_pos_ = 0
local function parsingPos (_, pos)
    max_pos_ = math.max(max_pos_, pos)
    return true
end


--
-- PEG patterns and grammar for our language
-- 
--local space = lpeg.S(" \n\t")^0
local space = lpeg.P(parsingPos) * lpeg.S(" \n\t")^0
--local space = lpeg.S(" \n\t")^0 * lpeg.P(parsingPos)

```
to the grammar. The `max_pos_` variable is part of the `parsingPos` closure and is updated each time a space is parsed.
I put the match-time capture at the start of the space pattern.


In the `parse` function called from the compiler I assert if the `grammar:match` method returns `nil`. The assert
payload contains the row (e.g line number) and column of the error location as well as a nice error message.

```lua
local function syntaxErrorPayload(input, pos)
    local upto    = string.sub(input, 0, pos)
    local lb      = lpeg.P("\n")
    local notlb   = lpeg.P(1) - lb
    local split   = lpeg.Ct((lpeg.C(notlb^0) * lb + lpeg.C(notlb^1))^0)
    local lines   = split:match(upto)
    local line    = lines[#lines] or ""
    local row     = #lines
    local col     = #line

    message = "Syntax error at line " .. row .. " character " .. col .. ". Right about here\n\n"
              .. line .. "\n" .. string.rep(" ", #line - 2) .. "^^^"

    return {
        row     = row,
        col     = col,
        line    = line,
        message = message,
    }
end

--
-- Parser takes input string and returns an AST.
--
function parse (input)
    -- reset the max pos counter.
    max_pos_ = 0
    local ast = grammar:match(input)
    assert(ast ~= nil, make_error(ERROR_CODES.SYNTAX, syntaxErrorPayload(input, max_pos_))) 
    return ast
end

```

## Exercise 02: Block comments.
I followed the suggestion in the lectures replacing the `space` pattern with a `space` non-terminal. Then I created a
"mini-grammar" for spaces and comments as follows:

```
local lb      = lpeg.P("\n")
local notlb   = lpeg.P(1) - lb
local space         = lpeg.V"space"
local comment       = lpeg.V"comment"
local line_rest_0   = lpeg.V"line_rest_0" 
local line_rest_1   = lpeg.V"line_rest_1" 
local block_rest    = lpeg.V"block_rest"
local grammar_space = lpeg.P{
    "space",
    comment       = '#{' * block_rest + '#' * line_rest_0,
    block_rest    = '#}' + lpeg.P(1) * block_rest,
    line_rest_0   = (lpeg.P(1) - '{') * line_rest_1 + lpeg.P(-1),
    line_rest_1   = notlb * line_rest_1 + lb + lpeg.P(-1),
    space         = lpeg.P(parsingPos) * (lpeg.S(" \n\t") + comment)^0,

}

```
This mini grammar is then used in the grammar for expressions and sequences:

```lua
local grammar_expression = lpeg.P{
    "expression",
    primary    = numeral + variable + OP * expression * CP,
    exponent   = space * lpeg.Ct((primary * opE)^0 * primary) / processOpR,
    negation   = space * lpeg.Ct(opN^0 * exponent) / processUnaryOp,
    term       = space * lpeg.Cf(negation * lpeg.Cg(opM * negation)^0, processOpL),
    addend     = space * lpeg.Cf(term * lpeg.Cg(opA * term)^0, processOpL),
    expression = space * lpeg.Cf(addend * lpeg.Cg(opC * addend)^0, processOpL), 
    space      = grammar_space,
}
```

```lua
local grammar = lpeg.P{
    "sequence",
    sequence   = statement * (SC * sequence)^-1 / sequenceNode,
    block      = space * OB * sequence * SC^-1 * CB,
    statement  = space * block 
                 + space * (ret * expression) / returnNode
                 + space * (prnt * expression) / printNode
                 + space * (identifier * opAssign * expression)^-1 / assignmentNode,
    expression = space * grammar_expression,
    space      = grammar_space,
}
```

This implementation handles line-comments nested with-in block comments and requires a block comment to be closed.
Please see test cases in `lesson-4/exercises/exercises_04.lua` for coverage.


## Exercise 03: Alternative for reserved words.
I used two match-time captures `ID_START` and `ID_END` to keep track of identifer start end end positions. When the function
associated to `ID_END` triggers I check if the identifier has a key in the table `reserved`. IF so I reject the
identifer otherwise it's accepted:

```lua
-- Reserved words, identifiers and variables
local underscore = lpeg.P"_"
local alpha = lpeg.R("AZ", "az")
local alphanum = alpha + digit

local reserved = { 
    ["@"]      = true, 
    ["if"]     = true, 
    ["then"]   = true, 
    ["while"]  = true, 
    ["for"]    = true, 
    ["do"]     = true, 
    ["end"]    = true, 
    ["fun"]    = true,
    ["return"] = true,
}

local function R(t)
    return t * -alphanum * space
end

local id_start = nil
local function identifierStart(_, p)
   id_start = p 
   return true;
end

local function identifierEnd(s, p)
    local id = string.sub(s, id_start, p - 1)
    local is_reserved = reserved[id] or false
    return not is_reserved
end

local ID_START = lpeg.P(identifierStart)
local ID_END = lpeg.P(identifierEnd)

local function variableNode(variable)
    return Tree:new({tag = "variable", identifier = variable})
end

local identifier_prefix = alpha + underscore
local identifier_postfix = alphanum + underscore
local identifier = lpeg.C(ID_START * identifier_prefix * identifier_postfix^0 * ID_END) * space
local variable = identifier / variableNode
```

Please see test cases in `lesson-4/exercises/exercises_04.lua` for coverage.


### Note
I took the opportunity the clean up the compiler along OO-lines.
