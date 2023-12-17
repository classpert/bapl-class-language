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

local hex_digit = lpeg.R("09") + lpeg.R("af") + lpeg.R("AF")
local hex_integer = sign^-1 * "0" * lpeg.S("xX") * hex_digit^1

local numeral_wo_e = (hex_integer
                      + (integer * dot * positive_integer) 
                      + (sign^-1 * dot * positive_integer)
                      + (integer * dot)
                      + integer)
local numeral = ((numeral_wo_e * (lpeg.S("eE") * integer)^-1) / toNumberNode) * space

-- Operators
local opC = lpeg.C(lpeg.P"!=" + "==" + "<=" + ">=" + "<" + ">") * space
local opA = lpeg.C(lpeg.S"+-") * space
local opM = lpeg.C(lpeg.S"*/%") * space
local opE = lpeg.C(lpeg.P"^") * space

local opN = lpeg.C(lpeg.P"-") * space

-- Brackets
local OP = "(" * space
local CP = ")" * space

--
-- The following two functions builds the AST.
--

-- Use fold capture to process left associative parts of the grammar into an AST.
-- Inspired by examples in "Mastering LPeg". 
local function processOpL (a, op, b)
    local node = {tag = "binary_operator", value = op}
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
        local node = {tag = "binary_operator", value = op}

        return BinaryTree:new(node, left, right)
    end
end


-- Note for the case of negation there are some optimizations to be made here. For example
-- --<expression> = <expression>. But perhaps this should be done in the CG phase?
local function processUnaryOp (lst)
    if #lst == 1 then
        return lst[1]
    else
        -- Note: order important!
        local op = table.remove(lst, 1)
        local right = processUnaryOp(lst)
        local node = {tag = "unary_operator", value = op}

        return BinaryTree:new(node, nil, right)
    end
end

local primary = lpeg.V"primary"
local exponent = lpeg.V"exponent"
local negation = lpeg.V"negation"
local term = lpeg.V"term"
local addend = lpeg.V"addend"
local expression = lpeg.V"expression"

local g = lpeg.P{
    "expression",
    primary = numeral + OP * expression * CP,
    exponent = space * lpeg.Ct((primary * opE)^0 * primary) / processOpR,
    negation = space * lpeg.Ct(opN^0 * exponent) / processUnaryOp,
    term = space * lpeg.Cf(negation * lpeg.Cg(opM * negation)^0, processOpL),
    addend = space * lpeg.Cf(term * lpeg.Cg(opA * term)^0, processOpL),
    expression = space * lpeg.Cf(addend * lpeg.Cg(opC * addend)^0, processOpL), 
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
        ['=='] = Machine.OPCODES.EQ,
        ['!='] = Machine.OPCODES.NEQ,
        ['<'] = Machine.OPCODES.LT,
        ['<='] = Machine.OPCODES.LE,
        ['>'] = Machine.OPCODES.GT,
        ['>='] = Machine.OPCODES.GE,
    }
    local unaryop_code_lookup = {
        ['-'] = Machine.OPCODES.NEG,
    }
    for item in ast:traverse(BinaryTree.POSTORDER) do
        if item.tag == "number" then
            table.insert(memory, Machine.OPCODES.PUSH)
            table.insert(memory, item.value)
        elseif item.tag == "binary_operator" then
            local binop_code = binop_code_lookup[item.value]
            if binop_code == nil then
                error("Unknown operation!")
            end
           table.insert(memory, binop_code)
       elseif item.tag == "unary_operator" then
            local unaryop_code = unaryop_code_lookup[item.value]
            if unaryop_code == nil then
                error("Unknown operation!")
            end
           table.insert(memory, unaryop_code)
       else
           error("Unknown tag!")
       end
    end

    return memory
end


return {compile = compile, debug = {g = g}}