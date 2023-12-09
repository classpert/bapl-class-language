local inspect = require "inspect"
local lpeg = require "lpeg"
local pt = require "pt"

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

-- Function to evaluate an AST as constructed above.
local function eval_ast(ast)
    local ops = {
        ['+'] = function (x, y) return (x + y) end,
        ['-'] = function (x, y) return (x - y) end,
        ['%'] = function (x, y) return (x % y) end,
        ['*'] = function (x, y) return (x * y) end,
        ['/'] = function (x, y) return (x / y) end,
        ['^'] = function (x, y) return (x ^ y) end
    }
    if type(ast) == "number" then
        return ast
    elseif type(ast) == "table" then
        return ops[ast.node](eval_ast(ast.left), eval_ast(ast.right))
    else
        inspect.inspect(ast)
        error("Bad expression")
    end
end

--
-- The following two functions builds the AST.
--


-- Use fold capture to process left associative parts of the grammar into an AST.
-- Inspired by examples in "Mastering LPeg". 
function processOpL (a, op, b)
    return {node = op, left = a, right = b}
end


-- Use table capture to deal with the right associative parts of the grammar.
-- Note: For exponent I couldn't figure out how to do a right fold using the Cf/Cg combo.
function processOpR (lst)
    if #lst == 1 then
        return lst[1]
    else
        left = table.remove(lst, 1)
        op = table.remove(lst, 1) 
        return {left = left, node = op, right = processOpR(lst)}
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

local function eval(string)
    return eval_ast(g:match(string))
end


return {eval=eval}
