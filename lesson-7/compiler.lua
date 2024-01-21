--
-- Note: This compiler builds on the interpreter in lession-1/interpeter.lua
--

local lpeg = require "lpeg"
local inspect = require "inspect"
local errors = require "errors"


local function remove_all_metatables(item, path)
    if path[#path] ~= inspect.METATABLE then return item end
end

local function pt(t)
    return inspect.inspect(t, {process = remove_all_metatables})
end


require "elements/containers/tree"
require "elements/containers/stack"
require "machine"

local ERROR_CODES = errors.ERROR_CODES
local make_error  = errors.make_error
local OPCODES     = Machine.OPCODES

local binop_code_lookup = {
    ['+']  = OPCODES.ADD,
    ['-']  = OPCODES.SUB,
    ['*']  = OPCODES.MULT,
    ['/']  = OPCODES.DIV,
    ['%']  = OPCODES.REM,
    ['^']  = OPCODES.EXP,
    ['=='] = OPCODES.EQ,
    ['!='] = OPCODES.NEQ,
    ['<']  = OPCODES.LT,
    ['<='] = OPCODES.LE,
    ['>']  = OPCODES.GT,
    ['>='] = OPCODES.GE,
}

local unaryop_code_lookup = {
    ['-'] = OPCODES.NEG,
    ['!'] = OPCODES.NOT,
}


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

local function processLogical(op)
    return function (left, right)
        return Tree:new({tag = "logical", operator = op, left = left, right = right})
    end
end

local function processIndex(lst)
    local tree = lst[1] -- variable 
    for i = 2, #lst do
        tree = Tree:new({tag = "indexed", array = tree, index = lst[i]})
    end
    return tree
end

local function processNew(lst, index)
    local index = index or 1
    local size = lst[index]
    if #lst == index then
        return Tree:new({tag = "new", size = size})
    else
        return Tree:new({tag = "new", size = size, rest = processNew(lst, index + 1)})
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
    ["@"]        = true, 
    ["if"]       = true, 
    ["then"]     = true, 
    ["else"]     = true,
    ["elseif"]   = true,
    ["while"]    = true, 
    ["for"]      = true, 
    ["do"]       = true, 
    ["end"]      = true, 
    ["break"]    = true, 
    ["lambda"]   = true,
    ["function"] = true,
    ["return"]   = true,
    ["and"]      = true,
    ["or"]       = true,
    ["switch"]   = true,
    ["case"]     = true,
    ["in"]       = true,
    ["null"]     = true,
    ["len"]      = true,
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

local identifier_prefix = alpha + underscore
local identifier_postfix = alphanum + underscore
local identifier = lpeg.C(ID_START * identifier_prefix * identifier_postfix^0 * ID_END) * space
local variable = identifier / node("variable", "identifier")

-- Operators
local opC = lpeg.C(lpeg.P"!=" + "==" + "<=" + ">=" + "<" + ">") * space
local opA = lpeg.C(lpeg.S"+-") * space
local opM = lpeg.C(lpeg.S"*/%") * space
local opE = lpeg.C(lpeg.P"^") * space

local opN = lpeg.C(lpeg.S"-!") * space

local opAssign = lpeg.P"=" * space

local lhs        = lpeg.V"lhs"  
local assignment = lpeg.V"assignment"
local primary    = lpeg.V"primary"
local exponent   = lpeg.V"exponent"
local negation   = lpeg.V"negation"
local logical    = lpeg.V"logical"
local comparison = lpeg.V"comparison"
local term       = lpeg.V"term"
local addend     = lpeg.V"addend"
local expression = lpeg.V"expression"
local statement  = lpeg.V"statement"
local sequence   = lpeg.V"sequence"
local block      = lpeg.V"block"
local ifstmt     = lpeg.V"ifstmt"
local ifrest     = lpeg.V"ifrest"
local switchstmt = lpeg.V"switchstmt"
local for1stmt   = lpeg.V"for1stmt"
local for2stmt   = lpeg.V"for2stmt"
local params     = lpeg.V"params"
local args       = lpeg.V"args"
-- Statement grammar
local grammar = lpeg.P{
    "program",
    program     = space * sequence,
    primary     = ((lhs + T"(" * expression * T")") * args) / node("call", "lambdaexpr", "params")
                + (R"lambda" * params * block) / node("lambda", "params", "block")
                + lpeg.Ct(R"new" * (T"[" * expression * T"]")^1) /  processNew
                + lpeg.Ct(T"{" * expression * (T"," * expression)^0 * T"}") / node("newconstr", "elements")
                + numeral 
                + R"null" / node("null", "_")
                + R"len" * (expression / node("len"))
                + T"(" * expression * T")"
                + lhs,
    exponent    = lpeg.Ct((primary * opE)^0 * primary) / processOpR,
    negation    = lpeg.Ct(opN^0 * exponent) / processUnaryOp,
    term        = lpeg.Cf(negation * lpeg.Cg(opM * negation)^0, processOpL),
    addend      = lpeg.Cf(term * lpeg.Cg(opA * term)^0, processOpL),
    comparison  = lpeg.Cf(addend * lpeg.Cg(opC * addend)^0, processOpL), 
    logical     = lpeg.Cf(comparison * lpeg.Cg(T("and") * comparison)^0, processLogical("and")),
    expression  = lpeg.Cf(logical * lpeg.Cg(T("or") * logical)^0,processLogical("or")),       
    lhs         = lpeg.Ct(variable * (T"[" * expression * T"]")^0) / processIndex
                + variable,
    params      = T"(" * T")" / node("params", "_")
                + (T"(" * identifier * (T"," * identifier)^0 * T")") / node("params"), 
    args        = T"(" * T")" / node("params", "_")
                + (T"(" * expression * (T"," * expression)^0 * T")") / node("params"), 
    sequence    = block * (sequence)^-1 / node("sequence")
                + statement * (T";" * sequence)^-1 / node("sequence"),
    ifstmt      = (R("if") * expression * block * (ifrest + R("else") * block)^-1) 
                  / node("if_", "condition", "ifblock", "elseblock"),
    ifrest      = (R("elseif") * expression * block * (ifrest + R("else") * block)^-1) 
                  / node("if_", "condition", "ifblock", "elseblock"),
    switchstmt  = (R"switch" * expression
                                    * T"{"
                                        * ((R"case" * expression * T":" * block) / node("case_", "expression", "block"))^0
                                        * ((R"default" * T":" * block) / node("default_", "block"))^-1
                                    * T"}") / node("switch_", "expression"),
    for1stmt    = (R"for" * ((assignment / node("assignment", "lhs", "expression"))^-1 / node("forinit")) * T";" 
                          * ((expression)^-1 / node("fortest")) * T";" 
                          * ((assignment / node("assignment", "lhs", "expression"))^-1 / node("forupdate"))
                          * block) / node("for1_"),
    for2stmt    = (R"for" * variable * R"in" * expression * block) / node("for2_"),
    block       = T"{" * sequence * T";"^-1 * T"}" / node("block")
                + (R("while") * expression * block) / node("while_", "condition", "whileblock")
                + (((R("function") * identifier * params * block) / node("function_", "identifier", "params", "block"))
                *  ((R("and") * identifier * params * block)^0 / node("function_", "identifier", "params", "block"))) / node("functions_")
                + ifstmt
                + switchstmt
                + for1stmt
                + for2stmt,
    assignment  = lhs * opAssign * expression,
    statement   = block 
                + (R("return") * expression) / node("return", "expression")
                + (R(":") * expression) / node("expr_as_statement", "expression") -- for side effects stack will be poped!
                + (R("@") * expression) / node("print", "expression")
                + (R("break")) / node("break_", "_")
                + (assignment)^-1 / node("assignment", "lhs", "expression"),
    space       = grammar_space,
}
grammar = grammar * -1



-- 
-- Compiler
--

local Compiler = {}
Compiler.__index = Compiler

function Compiler:new ()
    local compiler = {
        env_ = Tree:new({parent = nil, vars = {}, freevars = {}, localvars = {}}), 
        code_ = {}, 
        break_ctx_ = Stack:new(),
    }
    setmetatable(compiler, Compiler)
    return compiler
end


function Compiler:envFindIdUp(id, current_env)
    local current_env = current_env or self.env_:node()
    local vars        = current_env.vars
    if vars[id] then
        return vars
    elseif current_env.parent == nil then
        return nil
    else
        return Compiler:envFindIdUp(id, current_env.parent:node())
    end
end

function Compiler:envFindIdDown(id, current_env)
    local current_env = current_env or self.env_
    local vars        = current_env:node().vars
    if vars[id] then
        return vars
    elseif #current_env:children() == 0 then
        return nil
    else
        for _, c in ipairs(current_env:children()) do
            vars = self:envFindIdDown(id, c)
            if vars then
                return vars
            end
        end
    end
    return nil
end

function Compiler:envAddRef(id, ref)
    local vars = self:envFindIdUp(id) or self.env_:node().vars
    local refinfo = vars[id] or {at = {}}
    table.insert(refinfo.at, ref)
    vars[id] = refinfo
end

function Compiler:nextCodeLoc()
    return #self.code_ + 1
end

function Compiler:branchRelative(branch_instr, location)
    return OPCODES.make(branch_instr, location + 0x7fffffff)
end


function Compiler:genStore(id, mark)
    local mark = mark or true
    table.insert(self.code_, OPCODES.make(OPCODES.STORE))
    table.insert(self.code_, 0xdeadc0de)
    if mark and self:envFindIdUp(id) == nil then
        table.insert(self.env_:node().localvars, id)
    end
    self:envAddRef(id, #self.code_)
end

function Compiler:genLoad(id, mark)
    local mark = mark or true
    table.insert(self.code_, OPCODES.make(OPCODES.LOAD))
    table.insert(self.code_, 0xdeadc0de)
    if mark and self:envFindIdUp(id) == nil then
        table.insert(self.env_:node().freevars, id)
    end
    self:envAddRef(id, #self.code_)
end


function Compiler:constantFold (ast)
    if ast:isLeaf() and ast:node().tag ~= "logical" then
        return ast
    end
    
    local children = {}
    for _, child in ipairs(ast:children()) do
        table.insert(children, self:constantFold(child))
    end

    local node = ast:node()
    if node.tag == "binary_operator" and children[1]:node().tag == "number" and children[2]:node().tag == "number" then
        local op    = OPCODES.BINOP_LOOKUP[node.value]
        local left  = children[1]:node().value
        local right = children[2]:node().value
        return Tree:new({tag = "number", value = op(left, right)})
    elseif node.tag == "unary_operator" and children[1]:node().tag == "number" then
        local op      = OPCODES.UNARYOP_LOOKUP[node.value]
        local operand = children[1]:node().value
        return Tree:new({tag = "number", value = op(operand)})
    elseif node.tag == "logical" then
        local op    = node.operator
        local left  = self:constantFold(node.left)
        local right = self:constantFold(node.right)
        if left:node().tag == "number" then
            if left:node().value == 0 and op == "and" or left:node().value ~= 0 and op == "or" then
                return left
            else
               return right
            end
        else
            return Tree:new({tag = "logical", operator = op, left = left, right = right})
        end
    else
        return Tree:new(node, table.unpack(children))
    end
end

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


function Compiler:codeGenExp(ast) 
    local ast = self:constantFold(ast)
    local node = ast:node()

    for _, sub in ipairs(ast:children()) do
        self:codeGenExp(sub)
    end
    

    if node.tag == "number" then
        table.insert(self.code_, OPCODES.make(OPCODES.PUSH))
        table.insert(self.code_, node.value)
    elseif node.tag == "null" then
        table.insert(self.code_, OPCODES.make(OPCODES.PUSH))
        table.insert(self.code_, {tag = "null"})
    elseif node.tag == "binary_operator" then
        local op = OPCODES.make(node.value)
        table.insert(self.code_, op)
    elseif node.tag == "unary_operator" then
        local op = OPCODES.make(node.value)
        table.insert(self.code_, op)
    elseif node.tag == "variable" then
        -- Relax this condition now that we deal with lambdas / closures. Instead add it to the free list!
        -- check that the variable has been defined
        -- assert(self:envFindIdUp(node.identifier) ~= nil, make_error(ERROR_CODES.UNDEFINED_VARIABLE, {identifier = node.identifier}))
        self:genLoad(node.identifier)
    elseif node.tag == "logical" then
        local left     = node.left
        local right    = node.right
        local operator = node.operator
        -- generate code for the left subexpression
        self:codeGenExp(left)
        -- sentinel for branch instruction (short circuit).
        table.insert(self.code_, 0xdeadc0de)
        local b0_location = #self.code_
        
        -- generate code for the right subexpression, this will be skipped 
        -- if tos is 0 / non zero (depending on or/and).
        self:codeGenExp(right)
        if operator == "and" then
            self.code_[b0_location] = self:branchRelative(OPCODES.BZP, self:nextCodeLoc() - b0_location)
        else
            self.code_[b0_location] = self:branchRelative(OPCODES.BNZP, self:nextCodeLoc() - b0_location)
        end
    elseif node.tag == "indexed" then
        self:codeGenExp(node.array)
        self:codeGenExp(node.index)
        table.insert(self.code_, OPCODES.make(OPCODES.GETARR)) 
    elseif node.tag == "new" then
        self:codeGenNew(ast)
    elseif node.tag == "newconstr" then
        local elements = node.elements
        local size     = #elements
        table.insert(self.code_, OPCODES.make(OPCODES.PUSH))
        table.insert(self.code_, size)
        table.insert(self.code_, OPCODES.make(OPCODES.NEWARR)) 
        table.insert(self.code_, OPCODES.make(OPCODES.PUSH))
        table.insert(self.code_, 1)
        for _, e in ipairs(elements) do
            self:codeGenExp(e)
            table.insert(self.code_, OPCODES.make(OPCODES.SETARRP))  
            table.insert(self.code_, OPCODES.make(OPCODES.INC))
        end
        table.insert(self.code_, OPCODES.make(OPCODES.POP))
    elseif node.tag == "lambda" then
        self:codeGenLambda(ast)
    elseif node.tag == "call" then
        self:codeGenCall(ast)
    elseif node.tag == "len" then
        table.insert(self.code_, OPCODES.make(OPCODES.SIZEARR)) 
        table.insert(self.code_, OPCODES.make(OPCODES.EXCH)) 
        table.insert(self.code_, OPCODES.make(OPCODES.POP)) 
    else
        error(make_error(ERROR_CODES.UNEXPECTED_TAG, {tag = node.tag}))
    end
end

function Compiler:codeGenAssignment(ast)
    local node       = ast:node()
    local lhs        = node.lhs:node()
    local expression = node.expression

    if lhs.tag == "variable" then
        self:codeGenExp(expression)
        self:genStore(lhs.identifier)
    elseif lhs.tag == "indexed" then
        self:codeGenExp(lhs.array)
        self:codeGenExp(lhs.index)
        self:codeGenExp(expression)
        table.insert(self.code_, OPCODES.make(OPCODES.SETARR)) 
    end
end

function Compiler:enterBreakContext()
    -- create a new break context
    self.break_ctx_:push({})
end

function Compiler:exitBreakContext()
    -- Generate jump instructions for break statement for a given context.
    local ctx = self.break_ctx_:pop()
    for _, address in pairs(ctx) do
        self.code_[address] = self:branchRelative(OPCODES.B, self:nextCodeLoc() - address)
    end
end

function Compiler:codeGenBlock(ast)
    self.env_ = Tree:new({parent = self.env_, vars = {}, freevars = {}, localvars = {}})
    self:codeGenSeq(ast:children()[1])
    local parent_children = self.env_:node().parent:children()
    table.insert(parent_children, self.env_)
    self.env_ = self.env_:node().parent
end

function Compiler:codeGenForIterator(ast)
    local node     = ast:node()
    local variable = ast:children()[1]
    local iterator = ast:children()[2]
    local body     = ast:children()[3]
    

    table.insert(self.code_, OPCODES.make(OPCODES.PUSH))
    table.insert(self.code_, 0)
    self:genStore(variable:node().identifier)

    self:enterBreakContext()

    -- Generate code that leaves a closure at TOS of arity 0.
    self:codeGenExp(iterator)


    local loop_location = self:nextCodeLoc()
    -- Generate end-of-loop test.
    table.insert(self.code_, OPCODES.make(OPCODES.DUP))  -- duplicate closure
    table.insert(self.code_, OPCODES.make(OPCODES.PUSH)) -- push the arity 0
    table.insert(self.code_, 0)
    table.insert(self.code_, OPCODES.make(OPCODES.SWAP, 1)) -- put arity below closure 
    table.insert(self.code_, OPCODES.make(OPCODES.CALL))    -- call closure
    table.insert(self.code_, OPCODES.make(OPCODES.DUP))     -- duplicate value
    table.insert(self.code_, OPCODES.make(OPCODES.ISNULL))  -- test for null
    local eol_branch = self:nextCodeLoc()
    table.insert(self.code_, 0xdeadc0de) -- branch to end of block
    self:genStore(variable:node().identifier)

    -- Generate for-body.
    self:codeGenSeq(body)
    table.insert(self.code_, self:branchRelative(OPCODES.B, loop_location - self:nextCodeLoc()))
    self.code_[eol_branch] =  self:branchRelative(OPCODES.BNZ, self:nextCodeLoc() - eol_branch)

    self:exitBreakContext()
   

    -- Restore stack.
    table.insert(self.code_, OPCODES.make(OPCODES.POP)) -- pop null
    table.insert(self.code_, OPCODES.make(OPCODES.POP)) -- pop closure
end


function Compiler:codeGenSeq(ast)
    local node = ast:node()

    if node.tag == "assignment" then
        if node.expression then
            self:codeGenAssignment(ast)
        else
            -- skip empty assignment
        end
    elseif node.tag == "sequence" then
        for _, sub in ipairs(ast:children()) do
            self:codeGenSeq(sub)
        end
    elseif node.tag == "if_" then
        local condition = node.condition
        local ifblock   = node.ifblock
        local elseblock = node.elseblock
        -- Generate the instructions for the condition.
        self:codeGenExp(condition)

        -- We will place a branch instruction here that jumps to the end of the ifblock in 
        -- case the condition evaluates to false (0). Since we don't know the size of the
        -- block yet we just put a sentinel in place and store the address.
        table.insert(self.code_, 0xdeadc0de) -- We will place the branch instruction here.
        local bz_location = #self.code_

        -- Generate the code for the block.
        self:codeGenSeq(ifblock)
        local b_location = nil
        if elseblock ~= nil then
            -- insert a jump instruction to the end of the elseblock 
            table.insert(self.code_, 0xdeadc0de)
            b_location = #self.code_
        end
        -- create a jump instruction to the end of the block (e.g #self.code_ + 1) and store
        -- in self.code_[bz_location].
        self.code_[bz_location] = self:branchRelative(OPCODES.BZ, self:nextCodeLoc() - bz_location)


        if elseblock ~= nil then
            -- generate the code for the else branch and set the unconditional jump to the end of the else block for the
            -- if branch.
            self:codeGenSeq(elseblock)
            self.code_[b_location] = self:branchRelative(OPCODES.B, self:nextCodeLoc() - b_location)
        end
    elseif node.tag == "while_" then
        local condition  = node.condition
        local whileblock = node.whileblock
        
        -- Create a new "break context" where we save addresses to jump instruction for "break" statements.
        self:enterBreakContext()
        -- Save the location of the test condition code.
        local cond_location = #self.code_ + 1
        -- Generate the instructions for the condition.
        self:codeGenExp(condition)
        -- We will place a branch instruction here that jumps to the end of the whileblock in 
        -- case the condition evaluates to false (0). Since we don't know the size of the
        -- block yet we just put a sentinel in place and store the address.
        table.insert(self.code_, 0xdeadc0de) -- We will place the branch instruction here.
        local bz_location = #self.code_
        
        -- Generate the code for whileblock
        self:codeGenSeq(whileblock)
        -- insert a jump back to the condition evaluation.
        table.insert(self.code_, self:branchRelative(OPCODES.B, cond_location - self:nextCodeLoc()))
        -- insert conditional jump to end of whileblock.
        self.code_[bz_location] = self:branchRelative(OPCODES.BZ, self:nextCodeLoc() - bz_location)
        self:exitBreakContext()
    elseif node.tag == "break_" then
        assert(#self.break_ctx_ > 0, make_error(ERROR_CODES.NO_LOOP, {message = "Break without active Loop"}))
        local ctx = self.break_ctx_:peek()
        -- Sentinel for jump instruction.
        table.insert(self.code_, 0xdeadc0de)
        -- Save address in current loop context, we will fill this address with a branch instruction.
        table.insert(ctx, #self.code_)
    elseif node.tag == "switch_" then
        local node = ast:node()
        local block_jumps = {}
        self:enterBreakContext()

        if #ast:children() > 0 then
            self:codeGenExp(node.expression) -- result of switch expression at TOS
            
            -- Iterate over all case expression and generate test / jump to block instructions.
            -- Note: Keep switch test-expression result on the top of the stack between tests.
            for _, sub in ipairs(ast:children()) do
                local sub_node = sub:node()
                if sub_node.tag == "case_" then
                    table.insert(self.code_, OPCODES.make(OPCODES.DUP))
                    self:codeGenExp(sub_node.expression)
                    table.insert(self.code_, OPCODES.make(OPCODES.EQ))
                elseif sub_node.tag == "default_" then
                    -- No special code here
                end
                table.insert(self.code_, 0xdeadc0de) -- sentinel to be replaced with BNZ or B
                table.insert(block_jumps, #self.code_)
            end

            -- Generate code for blocks (one after another).
            for i, sub in ipairs(ast:children()) do
                local sub_node = sub:node()
                local block_jump = block_jumps[i]

                -- Fix jump instructions for the tests.
                if sub_node.tag == "case_" then
                    self.code_[block_jump] = self:branchRelative(OPCODES.BNZ, self:nextCodeLoc() - block_jump)
                elseif sub_node.tag == "default_" then
                    self.code_[block_jump] = self:branchRelative(OPCODES.B, self:nextCodeLoc() - block_jump)
                end

                -- Pop the test expression the restore the stack.
                table.insert(self.code_, OPCODES.make(OPCODES.POP))
                self:codeGenSeq(sub_node.block) 
            end
        end
            
        self:exitBreakContext()
    elseif node.tag == "for1_" then
        -- TODO(peter): figure out a nicer way to do this. 
        local forinit   = ast:children()[1]:children()[1]  -- init statement of the for loop, can be "" if non provided.
        local fortest   = ast:children()[2]:children()[1]  -- test expression, can be "" if non provided.
        local forupdate = ast:children()[3]:children()[1]  -- update statement, can be "" if non provided.
        local forbody   = ast:children()[4] -- the for body, always present.
        
        self:enterBreakContext()
        -- Generate code for the for initialization if present.
        if forinit ~= "" then
            self:codeGenSeq(forinit)
        end

        -- Save the location of the test expression / beginning of loop-block if no expression given.
        local loop_location = self:nextCodeLoc() 
        local maybe_finish_location = nil
        -- Generate code for the test
        if fortest ~= "" then
            self:codeGenExp(fortest)
            maybe_finish_location = self:nextCodeLoc() 
            table.insert(self.code_, 0xdeadc0de) -- sentinel to be replaced with BZ to end of body (and loop branch).
        end

        -- Generate code for the body
        self:codeGenSeq(forbody)

    
        -- Generate code for the update if existing.
        if forupdate ~= "" then
            self:codeGenSeq(forupdate)
        end

        -- Jump back to test/beginning of body.
        table.insert(self.code_, self:branchRelative(OPCODES.B, loop_location - self:nextCodeLoc()))
        if maybe_finish_location then
            self.code_[maybe_finish_location] =  self:branchRelative(OPCODES.BZ, self:nextCodeLoc() - maybe_finish_location)
        end

        self:exitBreakContext()
    elseif node.tag == "for2_" then
        self:codeGenForIterator(ast)
    elseif node.tag == "block" then
        self:codeGenBlock(ast)
    elseif node.tag == "return" then
        if node.expression ~= nil then
            self:codeGenExp(node.expression)
        else
            table.insert(self.code_, OPCODES.make(OPCODES.PUSH))
            table.insert(self.code_, 0)
        end
        table.insert(self.code_, OPCODES.make(OPCODES.RETURN))
    elseif node.tag == "print" then
        if node.expression ~= nil then
            self:codeGenExp(node.expression)
        end
        table.insert(self.code_, OPCODES.make(OPCODES.PRINT))
    elseif node.tag == "functions_" then
        self:codeGenFunctions(ast)
    elseif node.tag == "expr_as_statement" then
        self:codeGenExp(node.expression)
        table.insert(self.code_, OPCODES.make(OPCODES.POP)) -- pop value
    else
        error(make_error(ERROR_CODES.UNEXPECTED_TAG, {tag = node.tag}))
    end
end

function Compiler:codeGenCall(ast)
    local node       = ast:node()
    local lambdaexpr = node.lambdaexpr
    local params     = node.params:children()
  
    for i = #params, 1, -1 do
        local param = params[i]
        self:codeGenExp(param)
    end
    
    -- We put the number of parameters on the stack so we can
    -- check in runtime whether or not we are trying to call
    -- the lambda with incorrect number of variables.
    table.insert(self.code_, OPCODES.make(OPCODES.PUSH))
    table.insert(self.code_, #params)

    self:codeGenExp(lambdaexpr)
    
    table.insert(self.code_, OPCODES.make(OPCODES.CALL))
end


function Compiler:rewriteFunc(ast, func_block_id, identifiers, lhs_by)
    local node     = ast:node()
    local new_node = {}
    if node.tag == "assignment" and node.expression == nil then
        new_node = node
    elseif node.tag == "assignment" and node.lhs:node().tag == "variable" and identifiers[node.lhs:node().identifier] then
        local lhs_node = lhs_by[node.lhs:node().identifier]:node()
        new_node = {
            tag = "assignment",
            lhs = Tree:new({
                tag = "variable",
                identifier = lhs_node.array:node().identifier
            }),
            expression = node.expression
        }
    elseif node.tag == "variable" and identifiers[node.identifier] then
        local lhs_node = lhs_by[node.identifier]:node()
        new_node = lhs_node
    elseif node.tag == "function_" and node.identifier == func_block_id then
        new_node = node -- we don't recurse further into functions it will be handled recursively.
    else
        for k, v in pairs(node) do
            local new_v = v
            if type(v) == "table" and v.__type == "Tree" then
                new_v = self:rewriteFunc(v, func_block_id, identifiers, lhs_by)
            end
            new_node[k] = new_v
        end
    end
    

    local new_children = {}
    for _, c in ipairs(ast:children()) do
        if type(c) == "table" and c.__type == "Tree" then
            table.insert(new_children, self:rewriteFunc(c, func_block_id, identifiers, lhs_by))
        else
            table.insert(new_children, c)
        end
    end

    return Tree:new(new_node, table.unpack(new_children))
end

-- A func is just syntactic sugar around a lambda expression. We will start by transforming the current node into
-- a sequence and then generate code for that new sequence. The general idea is as follows.
--
-- 1. Create a "hidden" identifier (hidden in the sense that it cannot be generated by a user) derived from the function
--    identifier. "<function-name>" -> ".<funtion-name>". Note that this identifier is forbidden by the parser so it's
--    safe for us to use it.
--
-- 2. Create a new Sequence-node that contains creation of a 1 cell array this will hold a reference to our
--    lambda-closure: .<function-name> = {0}.
--
-- 3. Replace all variables with identifier  of <function-name> in the block with lhs .<function-name>[1].
--
-- 4. Create a new closure and assign it to the .<function-name>[1] cell. The close takes the modified block and params
--    as payload.
--
-- 5. Create a variable with identifier <function-name> and assign .<function-name>[1] to this variable.
--
function Compiler:codeGenFunctions(ast)
    local block_by        = {}
    local params_by      = {}
    local lhs_by         = {}
    local array_assgn_by = {}
    local func_assgn_by  = {}
    local ident_assgn_by = {}
    local identifiers    = {}
    for _, func in ipairs(ast:children()) do
        if func:node().identifier ~= "" then
            local node       = func:node()
            local identifier = node.identifier
            local params     = node.params
            block_by[identifier]  = node.block
            params_by[identifier] = node.params 
            lhs_by[identifier]    = Tree:new({
                tag   = "indexed",
                array = Tree:new({
                    tag = "variable",
                    identifier = "." .. identifier
                }),
                index = Tree:new({
                    tag = "number",
                    value = 1,
                }),
            })
            array_assgn_by[identifier] = Tree:new({
                tag = "assignment",
                lhs = Tree:new({
                    tag = "variable",
                    identifier = "." .. identifier
                }),
                expression = Tree:new({
                    tag = "new",
                    size = Tree:new({
                        tag = "number",
                        value = 1,
                    }),
                })
            })
            ident_assgn_by[identifier] = Tree:new({
                tag = "assignment",
                lhs = Tree:new({
                    tag = "variable",
                    identifier = identifier
                }),
                expression = lhs_by[identifier]
            })

            identifiers[identifier] = true
        end
    end

    for identifier, _ in pairs(identifiers) do
        block_by[identifier] = self:rewriteFunc(block_by[identifier], identifier, identifiers, lhs_by)
        func_assgn_by[identifier] = Tree:new({
            tag = "assignment",
            lhs = lhs_by[identifier], 
            expression = Tree:new({
                tag = "lambda",
                params = params_by[identifier],
                block  = block_by[identifier] 
            })
        })
    end
    
    for identifier, _ in pairs(identifiers) do
        self:codeGenSeq(array_assgn_by[identifier])
    end
    for identifier, _ in pairs(identifiers) do
        self:codeGenSeq(func_assgn_by[identifier])
    end
    for identifier, _ in pairs(identifiers) do
        self:codeGenSeq(ident_assgn_by[identifier])
    end
end

function Compiler:codeGenLambda(ast)
    local node       = ast:node()
    local params     = node.params:children()
    local block      = node.block
    -- Step 1: Generate code for closure.
    local env        = self.env_
    local env_lambda = Tree:new({parent = nil, vars = {}, freevars = {}, localvars = {}})
    self.env_        = env_lambda

    local code        = self.code_
    local code_lambda = {}
    self.code_        = code_lambda
  
    local break_ctx  = self.break_ctx_
    self.break_ctx_  = Stack:new()

    --- store params from signature (pushed to stack) into closure local storage.
    for _, param in ipairs(params) do
        self:genStore(param)
    end

    -- generate the code for the lambda block
    self:codeGenBlock(block)

    -- insert return instruction in case it does not exist in block.
    table.insert(self.code_, OPCODES.make(OPCODES.PUSH))
    table.insert(self.code_, 0)
    table.insert(self.code_, OPCODES.make(OPCODES.RETURN))

    local closure = self:genProgramImage()
    closure.arity = #params
    -- Step 2: generate code for creating side.
    -- restore state to current closure.
    self.env_      = env
    self.code_     = code
    self.break_ctx_ = break_ctx
    

    -- Push the partially formed closure or closure prototype onto the stack.
    table.insert(self.code_, OPCODES.make(OPCODES.PUSH))
    table.insert(self.code_, closure)
    -- Create an array on the stack that's the size of the local storage for the closure.
    table.insert(self.code_, OPCODES.make(OPCODES.PUSH))
    table.insert(self.code_, #closure.data)
    table.insert(self.code_, OPCODES.make(OPCODES.NEWARR))

    -- we now iterate over all variables in env_closure and issue STORE instructions 
    -- for the indices that contain free variables.
    -- Freelist for the current lambda.
    for id, loc in self:freevariables(env_lambda) do
        table.insert(self.code_, OPCODES.make(OPCODES.DUP))
        table.insert(self.code_, OPCODES.make(OPCODES.PUSH))
        table.insert(self.code_, loc)
        self:genLoad(id, false)
        table.insert(self.code_, OPCODES.make(OPCODES.SETARR))
    end

    table.insert(self.code_, OPCODES.make(OPCODES.CLOSURE))
end


function Compiler:genData(env, data)
    local data = data or {}
    local vars = env:node().vars
    for id, refinfo in pairs(vars) do
        table.insert(data, 0)
        
        -- Store a referene to the position in the data segment. We will use this when filling free variables for a
        -- closure.
        refinfo.data_loc = #data
        for _, loc in ipairs(refinfo.at) do
            self.code_[loc] = #data
        end
    end
    for _, c in ipairs(env:children()) do
        self:genData(c, data)
    end
    return data
end

-- This function generates freevariables indices and their storage location in the closure.
function Compiler:freevariables(env)
    local function aux (env)
        local freevars = env:node().freevars
        local vars     = env:node().vars
        for _, id in ipairs(env:node().freevars) do
            coroutine.yield (id, vars[id].data_loc) 
        end

        for _, c in ipairs(env:children()) do
            aux(c)
        end
    end

    return coroutine.wrap(function () aux (env) end)
end


function Compiler:genProgramImage(data)
    -- Insert the 'HALT' instruction at the end of the code block. This will ensure
    -- that the machine halts and don't continue execution past this point.
    table.insert(self.code_, OPCODES.make(OPCODES.HALT))
    
    data = data or {}
    self:genData(self.env_, data)

    return { tag = "closure", code = self.code_, data = data, arity = 0, id = -1}
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
