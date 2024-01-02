--
-- Note: This compiler builds on the interpreter in lession-1/interpeter.lua
--

local lpeg = require "lpeg"
local pt = (require "inspect").inspect

require "elements/containers/tree"
require "machine"

local ERROR_CODES = {
    -- syntax errors
    SYNTAX             = 0xE101,
    -- semantical errors
    UNDEFINED_VARIABLE = 0xE201,
    UNEXPECTED_TAG     = 0xE202,
}
local ERROR_MESSAGES = {
    [ERROR_CODES.SYNTAX]             = "Syntax Error",
    [ERROR_CODES.UNDEFINED_VARIABLE] = "Undefined variable",
    [ERROR_CODES.UNEXPECTED_TAG]     = "Unexpected tag",
}

local binop_code_lookup = {
    ['+']  = Machine.OPCODES.ADD,
    ['-']  = Machine.OPCODES.SUB,
    ['*']  = Machine.OPCODES.MULT,
    ['/']  = Machine.OPCODES.DIV,
    ['%']  = Machine.OPCODES.REM,
    ['^']  = Machine.OPCODES.EXP,
    ['=='] = Machine.OPCODES.EQ,
    ['!='] = Machine.OPCODES.NEQ,
    ['<']  = Machine.OPCODES.LT,
    ['<='] = Machine.OPCODES.LE,
    ['>']  = Machine.OPCODES.GT,
    ['>='] = Machine.OPCODES.GE,
}

local unaryop_code_lookup = {
    ['-'] = Machine.OPCODES.NEG,
    ['!'] = Machine.OPCODES.NOT,
}

local function make_error(code, payload)
    return {
        code = code,
        message = ERROR_MESSAGES[code],
        payload = payload
    }
end


--
-- Helper functions for the parser
--


-- Expression parser functions

-- Use fold capture to process left associative parts of the grammar into an AST.
-- Inspired by examples in "Mastering LPeg". 
local function processOpL (a, op, b)
    local opcode = binop_code_lookup[op]
    assert(opcode, make_error(ERROR_CODES.SYNTAX, {operator = op}))

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
        assert(opcode, make_error(ERROR_CODES.SYNTAX, {operator = op}))

        local right = processOpR(lst)
        local node = {tag = "binary_operator", value = opcode}

        return Tree:new(node, left, right)
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
        local opcode = unaryop_code_lookup[op]
        assert(opcode, make_error(ERROR_CODES.SYNTAX, {operator = op}))

        local right = processUnaryOp(lst)
        local node = {tag = "unary_operator", value = opcode}

        return Tree:new(node, right)
    end
end


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

-- Debug 
local function D(message)
    return lpeg.P(function (s, p) 
        print (string.format("%s (%d): %s", message, p, s))
        return true 
    end)
end

--
-- PEG patterns and grammar for our language
-- 
local space = lpeg.V"space"


-- Tokens
local function T(t)
    return t * space
end

-- Position match time capture.
local max_pos_ = 0
local function parsingPos (_, pos)
    max_pos_ = math.max(max_pos_, pos)
    return true
end


local lb      = lpeg.P("\n")
local notlb   = lpeg.P(1) - lb
-- local space = lpeg.P(parsingPos) * (lpeg.S(" \n\t") + comment)^0
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

-- Numerals
local sign = lpeg.S("-+")
local digit = lpeg.R("09")
local positive_integer = digit^1
local integer = sign^-1 * positive_integer

local hex_digit = lpeg.R("09") + lpeg.R("af") + lpeg.R("AF")
local hex_integer = sign^-1 * "0" * lpeg.S("xX") * hex_digit^1

local numeral_wo_e = (hex_integer
                      + (integer * "." * positive_integer) 
                      + (sign^-1 * "." * positive_integer)
                      + (integer * ".")
                      + integer)
local numeral = ((numeral_wo_e * (lpeg.S("eE") * integer)^-1) / tonumber / node("number", "value")) * space

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

-- Operators
local opC = lpeg.C(lpeg.P"!=" + "==" + "<=" + ">=" + "<" + ">") * space
local opA = lpeg.C(lpeg.S"+-") * space
local opM = lpeg.C(lpeg.S"*/%") * space
local opE = lpeg.C(lpeg.P"^") * space

local opN = lpeg.C(lpeg.S"-!") * space

local opAssign = lpeg.P"=" * space


local primary      = lpeg.V"primary"
local exponent     = lpeg.V"exponent"
local negation     = lpeg.V"negation"
local logical      = lpeg.V"logical"
local term         = lpeg.V"term"
local addend       = lpeg.V"addend"
local expression   = lpeg.V"expression"

-- Expression grammar
local grammar_expression = lpeg.P{
    "expression",
    primary     = numeral + variable + T"(" * expression * T")",
    exponent    = space * lpeg.Ct((primary * opE)^0 * primary) / processOpR,
    negation    = space * lpeg.Ct(opN^0 * exponent) / processUnaryOp,
    term        = space * lpeg.Cf(negation * lpeg.Cg(opM * negation)^0, processOpL),
    addend      = space * lpeg.Cf(term * lpeg.Cg(opA * term)^0, processOpL),
    expression  = space * lpeg.Cf(addend * lpeg.Cg(opC * addend)^0, processOpL), 
    space       = grammar_space,
}


local statement = lpeg.V"statement"
local sequence  = lpeg.V"sequence"
local block     = lpeg.V"block"
-- Statement grammar
local grammar = lpeg.P{
    "sequence",
    sequence   = statement * (T";" * sequence)^-1 / node("sequence"),
    block      = space * T"{" * sequence * T";"^-1 * T"}",
    statement  = space * block 
                 + space * (R("if") * expression * block) / node("if_", "condition", "block")
                 + space * (R("return") * expression) / node("return", "expression")
                 + space * (R("@") * expression) / node("print", "expression")
                 + space * (identifier * opAssign * expression)^-1 / node("assignment", "identifier", "expression"),
    expression = space * grammar_expression,
    space      = grammar_space,
}
grammar = grammar * -1



-- 
-- Compiler
--

local Compiler = {}
Compiler.__index = Compiler

function Compiler:new ()
    local compiler = {env_ = {}, code_ = {}}
    setmetatable(compiler, Compiler)
    return compiler
end


function Compiler:envAddRef(id, ref)
    local refinfo = self.env_[id] or {at = {}}
    table.insert(refinfo.at, ref)
    self.env_[id] = refinfo
end


function Compiler:constantFold (ast)
    if ast:isLeaf() then
        return ast
    end
    
    local children = {}
    for _, child in pairs(ast:children()) do
        table.insert(children, self:constantFold(child))
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

function Compiler:codeGenExp(ast) 
    local ast = self:constantFold(ast)
    for _, sub in pairs(ast:children()) do
        self:codeGenExp(sub)
    end
    
    local node = ast:node()

    if node.tag == "number" then
        table.insert(self.code_, Machine.OPCODES.make(Machine.OPCODES.PUSH))
        table.insert(self.code_, node.value)
    elseif node.tag == "binary_operator" then
        local op = Machine.OPCODES.make(node.value)
        table.insert(self.code_, op)
    elseif node.tag == "unary_operator" then
        local op = Machine.OPCODES.make(node.value)
        table.insert(self.code_, op)
    elseif node.tag == "variable" then
        -- check that the variable has been defined
        assert(self.env_[node.identifier] ~= nil, make_error(ERROR_CODES.UNDEFINED_VARIABLE, {identifier = node.identifier}))

        table.insert(self.code_, Machine.OPCODES.make(Machine.OPCODES.LOAD))
        -- Insert a sentinel value. We will update this with an pointer to the storage 
        -- of the variable during the program generation phase.
        table.insert(self.code_, 0xdeadc0de)
        self:envAddRef(node.identifier, #self.code_) -- Add a reference to identifier location
    else
        error(make_error(ERROR_CODES.UNEXPECTED_TAG, {tag = node.tag}))
    end
end

function Compiler:codeGenSeq(ast)
    node = ast:node()
    
    if node.tag == "assignment" then
        local identifier = node.identifier
        local expression = node.expression
        if identifier ~= nil and expression ~= nil then
            -- Generate code that evaluates the expression and puts the result
            -- on TOS.
            self:codeGenExp(expression)
            -- Insert store instruction (pops TOS and writes to code[code[pc + 1]])
            table.insert(self.code_, Machine.OPCODES.make(Machine.OPCODES.STORE))
            -- Insert a sentinel value. We will update this with an pointer to the storage 
            -- of the variable during the program generation phase.
            table.insert(self.code_, 0xdeadc0de)
            self:envAddRef(identifier, #self.code_)
        else
            -- Ignore empty statement
        end
    elseif node.tag == "sequence" then
        for _, sub in pairs(ast:children()) do
            self:codeGenSeq(sub)
        end
    elseif node.tag == "if_" then
        local condition = node.condition
        local block     = node.block

        -- Generate the instructions for the condition.
        self:codeGenExp(condition)

        -- We will place a branch instruction here that jumps to the end of the block in 
        -- case the condition evaluates to false (0). Since we don't know the size of the
        -- block yet we just put a sentinel in place and store the address.
        table.insert(self.code_, 0xdeadc0de) -- We will place the branch instruction here.
        local bz_location = #self.code_

        -- Generate the code for the block.
        self:codeGenSeq(block)

        -- create a jump instruction to the end of the block (e.g #self.code_ + 1) and store
        -- in self.code_[bz_location].
        self.code_[bz_location] = Machine.OPCODES.make(Machine.OPCODES.BZ, #self.code_ + 1 - bz_location + 0x7fffffff)

    elseif node.tag == "return" then
        if node.expression ~= nil then
            self:codeGenExp(node.expression)
        end
        table.insert(self.code_, Machine.OPCODES.make(Machine.OPCODES.RETURN))
    elseif node.tag == "print" then
        if node.expression ~= nil then
            self:codeGenExp(node.expression)
        end
        table.insert(self.code_, Machine.OPCODES.make(Machine.OPCODES.PRINT))
    else
        error(make_error(ERROR_CODES.UNEXPECTED_TAG, {tag = node.tag}))
    end
end

function Compiler:genProgramImage()
    -- Insert the 'HALT' instruction at the end of the code block. This will ensure
    -- that the machine halts and don't continue execution past this point.
    table.insert(self.code_, Machine.OPCODES.make(Machine.OPCODES.HALT))
    
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
    table.insert(program_image, Machine.OPCODES.make(Machine.OPCODES.JMP))
    -- Sentinel. We will update this once we created storage for global variables.
    table.insert(program_image, 0xdeadC0de)

    -- Create storage for variables and update the reference in the code.
    for _, refinfo in pairs(self.env_) do
        -- Default all storage cells to 0
        table.insert(program_image, 0)

        -- Update the reference in the code block.
        refinfo.address = #program_image
        for _, loc in pairs(refinfo.at) do
            self.code_[loc] = refinfo.address
        end
    end
    
    -- JMP address
    program_image[2] = #program_image + 1
    
    -- Relocate the code block to the end of the variable storage.
    table.move(self.code_, 1, #self.code_, #program_image + 1, program_image)

    return program_image
end

function Compiler:syntaxErrorPayload(input, pos)
    local upto    = string.sub(input, 0, pos)
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
function Compiler:parse (input)
    -- reset the max pos counter.
    max_pos_ = 0
    local ast = grammar:match(input)
    assert(ast ~= nil, make_error(ERROR_CODES.SYNTAX, self:syntaxErrorPayload(input, max_pos_))) 
    return ast
end


function Compiler:compile (input)
    local ast = self:parse(input)
    self:codeGenSeq(ast)
    return self:genProgramImage()
end

--
-- The compiler that translates the AST into machine instructions.
--
local function compile (str)
    local compiler = Compiler:new()
    return compiler:compile(str)
end


return {compile = compile, debug = {grammar = grammar, Compiler = Compiler}, ERRORS = ERROR_CODES}
