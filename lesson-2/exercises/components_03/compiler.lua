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


local function toNumberNode (number)
    return BinaryTree:new({tag = "number", value = tonumber(number)})
end
-- Numerals
local dot = lpeg.P(".")
local sign = lpeg.S("-+")
local digit = lpeg.R("09")
local positive_integer = digit^1
local integer = sign^-1 * positive_integer

-- START CHANGES FOR EXERCISE 02: HEXADECIMAL NUMBERS
local hex_digit = lpeg.R("09") + lpeg.R("af") + lpeg.R("AF")
local hex_integer = sign^-1 * "0" * lpeg.S("xX") * hex_digit^1

local numeral = ((hex_integer
                   + (integer * dot * positive_integer) 
                   + (sign^-1 * dot * positive_integer)
                   + (integer * dot)
                   + integer) / toNumberNode) * space

-- END CHANGES FOR EXERCISE 02: HEXADECIMAL NUMBERS

-- Operators
local opA = lpeg.C(lpeg.S"+-") * space
local opM = lpeg.C(lpeg.S"*/%") * space
local opE = lpeg.C(lpeg.P"^") * space


-- Brackets
local OP = "(" * space
local CP = ")" * space

--
-- The following two functions builds the AST.
--

-- Use fold capture to process left associative parts of the grammar into an AST.
-- Inspired by examples in "Mastering LPeg". 
local function processOpL (a, op, b)
    local node = {tag = "operator", value = op}
    local left = a
    local right = b
    return BinaryTree:new(node, left, right)
end


-- Use table capture to deal with the right associative parts of the grammar.
-- Note: For exponent I couldn't figure out how to do a right fold using the Cf/Cg combo.
local function processOpR (lst)
    if #lst == 1 then
        return lst[1]
    else
        -- Note: order important!
        local left = table.remove(lst, 1)
        local op = table.remove(lst, 1)
        local right = processOpR(lst)
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
    local binop_code_lookup = {
        ['+'] = Machine.OPCODES.ADD,
        ['-'] = Machine.OPCODES.SUB,
        ['*'] = Machine.OPCODES.MULT,
        ['/'] = Machine.OPCODES.DIV,
        ['%'] = Machine.OPCODES.REM,
        ['^'] = Machine.OPCODES.EXP,
    }
    for item in ast:traverse(BinaryTree.POSTORDER) do
        if item.tag == "number" then
            table.insert(memory, Machine.OPCODES.PUSH)
            table.insert(memory, item.value)
        elseif item.tag == "operator" then
            binop_code = binop_code_lookup[item.value]
            if binop_code == nil then
                error("Unknown operation!")
            end
           table.insert(memory, binop_code)
       else
           error("Unknown tag!")
       end
    end

    return memory
end


return {compile = compile, debug = {g = g}}
