--
-- Note: This compiler builds on the interpreter in lession-1/interpeter.lua
--

require "elements/containers/tree"
require "machine"

local ERROR_CODES = {
    -- syntax errors
    PARSING         = 0xE101,
    PARSING_TOKEN   = 0xE102,
    -- semantical errors
    UNDEFINED_VARIABLE = 0xE201,
    UNEXPECTED_TAG     = 0xE202,
}
local ERROR_MESSAGES = {
    [ERROR_CODES.PARSING]            = "General parsing error",
    [ERROR_CODES.PARSING_TOKEN]      = "Unexpected token",
    [ERROR_CODES.UNDEFINED_VARIABLE] = "Undefined variable",
    [ERROR_CODES.UNEXPECTED_TAG]     = "Unexpected tag",
}

local function make_error(code, payload)
    return {
        code = code,
        message = ERROR_CODES[code],
        payload = payload
    }
end

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
    return Tree:new({tag = "variable", identifier = variable})
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

local opAssign = lpeg.P"=" * space

-- Grouping and sequencing tokens
local OP = "(" * space
local CP = ")" * space

local OB = "{" * space
local CB = "}" * space

local SC = ";" * space

-- Reserved words
local ret  = lpeg.P"return" * space
local prnt = lpeg.P"@" * space
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
    assert(opcode, make_error(ERROR_CODES.PARSING_TOKEN, {operator = op}))

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
        assert(opcode, make_error(ERROR_CODES.PARSING_TOKEN, {operator = op}))

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
        assert(opcode, make_error(ERROR_CODES.PARSING_TOKEN, {operator = op}))

        local right = processUnaryOp(lst)
        local node = {tag = "unary_operator", value = opcode}

        return Tree:new(node, right)
    end
end


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

local function returnNode(expression)
    return Tree:new({tag = "return", expression = expression})
end

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


local function envAddRef(env, id, ref)
    local refinfo = env[id] or {at = {}}
    table.insert(refinfo.at, ref)
    env[id] = refinfo
end


local function constantFold (ast)
    if ast:isLeaf() then
        return ast
    end
    
    local children = {}
    for _, child in pairs(ast:children()) do
        table.insert(children, constantFold(child))
    end

    local node = ast:node()
    if node.tag == "binary_operator" and children[1]:node().tag == "number" and children[2]:node().tag == "number" then
        op = Machine.OPCODES.BINOP_LOOKUP[node.value]
        left = children[1]:node().value
        right = children[2]:node().value
        return Tree:new({tag = "number", value = op(left, right)})
    elseif node.tag == "unary_operator" and children[1]:node().tag == "number" then
        op = Machine.OPCODES.UNARYOP_LOOKUP[node.value]
        operand = children[1]:node().value
        return Tree:new({tag = "number", value = op(operand)})
    else
        return Tree:new(node, table.unpack(children))
    end
end

local function codeGenExp(ast, env, code) 
    local ast = constantFold(ast)
    for _, sub in pairs(ast:children()) do
        codeGenExp (sub, env, code)
    end
    
    local node = ast:node()

    if node.tag == "number" then
        table.insert(code, Machine.OPCODES.PUSH)
        table.insert(code, node.value)
    elseif node.tag == "binary_operator" then
        table.insert(code, node.value)
    elseif node.tag == "unary_operator" then
        table.insert(code, node.value)
    elseif node.tag == "variable" then
        -- check that the variable has been defined
        assert(env[node.identifier] ~= nil, make_error(ERROR_CODES.UNDEFINED_VARIABLE, {identifier = node.identifier}))

        table.insert(code, Machine.OPCODES.LOAD)
        -- Insert a sentinel value. We will update this with an pointer to the storage 
        -- of the variable during the program generation phase.
        table.insert(code, 0xdeadc0de)
        envAddRef(env, node.identifier, #code) -- Add a reference to identifier location
    else
        error(make_error(ERROR_CODES.UNEXPECTED_TAG, {tag = node.tag}))
    end
end

local function codeGenSeq(ast, env, code)
    node = ast:node()
    
    if node.tag == "assignment" then
        local identifier = node.identifier
        local expression = node.expression
        -- Generate code that evaluates the expression and puts the result
        -- on TOS.
        codeGenExp(expression, env, code)
        -- Insert store instruction (pops TOS and writes to code[code[pc + 1]])
        table.insert(code, Machine.OPCODES.STORE)
        -- Insert a sentinel value. We will update this with an pointer to the storage 
        -- of the variable during the program generation phase.
        table.insert(code, 0xdeadc0de)
        envAddRef(env, identifier, #code)
    elseif node.tag == "empty_statement" then
        -- just ignore empty statements.
    elseif node.tag == "sequence" then
        for _, sub in pairs(ast:children()) do
            codeGenSeq(sub, env, code)
        end
    elseif node.tag == "return" then
        if node.expression ~= nil then
            codeGenExp(node.expression, env, code)
        end
        table.insert(code, Machine.OPCODES.RETURN)
    elseif node.tag == "print" then
        if node.expression ~= nil then
            codeGenExp(node.expression, env, code)
        end
        table.insert(code, Machine.OPCODES.PRINT)
    else
        error(make_error(ERROR_CODES.UNEXPECTED_TAG, {tag = node.tag}))
    end
end

local function genProgramImage (env, code)
    -- Insert the 'HALT' instruction at the end of the code block. This will ensure
    -- that the machine halts and don't continue execution past this point.
    table.insert(code, Machine.OPCODES.HALT)
    
    -- The Machine always start executing at memory location 0. We store the program image
    -- as follows:
    --
    --   Program Image 
    -- | JMP             |   0
    -- | <program start> |   1
    -- | <global var>    |   2
    -- | <global var>    |   3
    -- ...
    -- | <global var>    |   n
    -- | <first instr>   |   n + 1 (<program start>)
    -- ...
    -- | <last instr>    |   n + m
    -- | HALT            |   n + m + 1
    --
    program_image = {}
    table.insert(program_image, Machine.OPCODES.JMP)
    -- Sentinel. We will update this once we created storage for global variables.
    table.insert(program_image, 0xdeadC0de)

    -- Create storage for variables and update the reference in the code.
    for _, refinfo in pairs(env) do
        -- Default all storage cells to 0
        table.insert(program_image, 0)

        -- Update the reference in the code block.
        refinfo.address = #program_image
        for _, loc in pairs(refinfo.at) do
            code[loc] = refinfo.address
        end
    end
    
    -- JMP address
    program_image[2] = #program_image + 1
    
    -- Relocate the code block to the end of the variable storage.
    table.move(code, 1, #code, #program_image + 1, program_image)

    return program_image
end

--
-- The compiler that translates the AST into machine instructions.
--
local function compile (str)
    local ast = grammar:match(str)
    local code = {}
    local env = {} -- Global environment
    codeGenSeq(ast, env, code)
    local image = genProgramImage(env, code)
    return image
end


return {compile = compile, debug = {grammar = grammar}, ERRORS = ERROR_CODES}
