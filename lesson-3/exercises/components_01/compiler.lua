--
-- Note: This compiler builds on the interpreter in lession-1/interpeter.lua
--

require "elements/containers/tree"
require "machine"

local lpeg = require "lpeg"
local pt = (require "inspect").inspect
--
-- PEG patterns and grammar for our language
-- 
local space = lpeg.S(" \n\t")^0


-- Numerals
local function numberNode (number)
    return Tree:new({tag = "number", value = tonumber(number)})
end

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
local numeral = ((numeral_wo_e * (lpeg.S("eE") * integer)^-1) / numberNode) * space

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

-- Use fold capture to process left associative parts of the grammar into an AST.
-- Inspired by examples in "Mastering LPeg". 
local function processOpL (a, op, b)
    local opcode = binop_code_lookup[op]
    assert(opcode)

    local node = {tag = "binary_operator", value = opcode}
    local left = a
    local right = b
    return Tree:new(node, left, right)
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
        
        local opcode = binop_code_lookup[op]
        assert(opcode)

        local right = processOpR(lst)
        local node = {tag = "binary_operator", value = opcode}

        return Tree:new(node, left, right)
    end
end


local unaryop_code_lookup = {
    ['-'] = Machine.OPCODES.NEG,
}
-- Note for the case of negation there are some optimizations to be made here. For example
-- --<expression> = <expression>. But perhaps this should be done in the CG phase?
local function processUnaryOp (lst)
    if #lst == 1 then
        return lst[1]
    else
        -- Note: order important!
        local op = table.remove(lst, 1)
        local opcode = unaryop_code_lookup[op]
        assert(opcode)

        local right = processUnaryOp(lst)
        local node = {tag = "unary_operator", value = opcode}

        return Tree:new(node, right)
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
    primary = numeral + variable + OP * expression * CP,
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
    local memory = {}
    local env = {} -- Global environment

    local function codeGen (ast)
        for _, sub in pairs(ast:children()) do
            codeGen (sub)
        end
        
        local node = ast:node()

        if node.tag == "number" then
            table.insert(memory, Machine.OPCODES.PUSH)
            table.insert(memory, node.value)
        elseif node.tag == "binary_operator" then
            table.insert(memory, node.value)
        elseif node.tag == "unary_operator" then
            table.insert(memory, node.value)
        elseif node.tag == "variable" then
            -- TODO: verify that variable exist in _some_ environment.
            -- For now we do the following:
            --    1. Add a key to the "global" environment table
            --    2. Save address information of next memory location in env
            --    3. Store a dummy address in the next memory location. We will
            --       update it once we calculated the storage size of env.
            table.insert(memory, Machine.OPCODES.LOAD)
            table.insert(memory, 0xbaadbeef)
            env[node.value] = {
                at = #memory -- address to LOAD operand
            }
        else
            error("Unknown tag: " .. node.tag)
        end
        
    end

    local function reserveVariableStorage()
        -- insert a HALT instruction at the end of the program.
        table.insert(memory, Machine.OPCODES.HALT)

        -- allocate variable storage.
        for _, varinfo in pairs(env) do
            table.insert(memory, 0)
            memory[varinfo.at] = #memory
            varinfo.address = #memory
        end
    end


    local ast = g:match(str)
    codeGen(ast)
    reserveVariableStorage()
    -- This is a little bit of a hack, but we need it for now to be able to set
    -- variables.
    memory.debuginfo = env 

    return memory
end


return {compile = compile, debug = {g = g}}
