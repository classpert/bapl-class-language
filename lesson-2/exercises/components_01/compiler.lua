--
-- Note: This compiler builds on the interpreter in lession-1/interpeter.lua
--

require "elements/containers/binary_tree"
require "machine"
local lpeg = require "lpeg"

--
-- PEG patterns and grammar for our language
-- 
local space = lpeg.S(" \n\t")^0

-- Numerals
local dot = lpeg.P(".")
local sign = lpeg.S("-+")
local digit = lpeg.R("09")
local positive_integer = digit^1
local integer = sign^-1 * positive_integer
local numeral = (((integer * dot * positive_integer) 
                   + (sign^-1 * dot * positive_integer)
                   + (integer * dot)
                   + integer) / tonumber) * space


-- Operators
local opA = lpeg.C(lpeg.S"+-") * space
local opM = lpeg.C(lpeg.S"*/%") * space
local opE = lpeg.C(lpeg.P"^") * space


-- Brackets
local OP = "(" * space
local CP = ")" * space


--
-- Helper function that wraps a numbers in a tree leaf node, but leave other arguments alone.
--
function maybeWrap (fragment)
    if type(fragment) == "number" then
        local node = {tag = "number", value = fragment}
        return BinaryTree:new(node) -- Create a leaf node.
    else
        return fragment                                       -- Assume we already have a node.
    end
end

--
-- The following two functions builds the AST.
--

-- Use fold capture to process left associative parts of the grammar into an AST.
-- Inspired by examples in "Mastering LPeg". 
local function processOpL (a, op, b)
    local node = {tag = "operator", value = op}
    local left = maybeWrap(a)
    local right = maybeWrap(b)
    return BinaryTree:new(node, left, right)
end


-- Use table capture to deal with the right associative parts of the grammar.
-- Note: For exponent I couldn't figure out how to do a right fold using the Cf/Cg combo.
local function processOpR (lst)
    if #lst == 1 then
        return maybeWrap(lst[1])
    else
        -- Note: order important!
        local left = maybeWrap(table.remove(lst, 1))
        local op = table.remove(lst, 1)
        local right = maybeWrap(processOpR(lst))
        local node = {tag = "operator", value = op}

        return BinaryTree:new(node, left, right)
    end
end

local primary = lpeg.V"primary"
local exponent = lpeg.V"exponent"
local term = lpeg.V"term"
local expression = lpeg.V"expression"

local g = lpeg.P{
    "expression",
    primary = numeral + OP * expression * CP,
    exponent = space * lpeg.Ct((primary * opE)^0 * primary) / processOpR,
    term = space * lpeg.Cf(exponent * lpeg.Cg(opM * exponent)^0, processOpL),
    expression = space * lpeg.Cf(term * lpeg.Cg(opA * term)^0, processOpL),
}
g = g * -1


--
-- The compiler that translates the AST into machine instructions.
--
local function compile (str)
    local ast = g:match(str)
    local memory = {}
    for item in ast:traverse(BinaryTree.POSTORDER) do
       if item.tag == "number" then
           table.insert(memory, Machine.OPCODES.PUSH)
           table.insert(memory, item.value)
       elseif item.tag == "operator" and item.value == "+" then
           table.insert(memory, Machine.OPCODES.ADD)
       elseif item.tag == "operator" and item.value == "-" then
           table.insert(memory, Machine.OPCODES.SUB)
       elseif item.tag == "operator" and item.value == "*" then
           table.insert(memory, Machine.OPCODES.MULT)
       elseif item.tag == "operator" and item.value == "/" then
           table.insert(memory, Machine.OPCODES.DIV)
       elseif item.tag == "operator" and item.value == "%" then
           table.insert(memory, Machine.OPCODES.REM)
       elseif item.tag == "operator" and item.value == "^" then
           table.insert(memory, Machine.OPCODES.EXP)
       else
           error("Bad node!")
       end
    end

    return memory
end


return {compile = compile, debug = {g = g}}
