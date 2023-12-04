
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

-- Simple AST builder (guessing here... :D)
local function build_ast(lst)
    -- print(pt.pt(lst))
    if #lst == 1 then
        -- Leaf nodes are just numbers
        return lst[1]
    elseif #lst >= 3 and lst[2] ~= '^' then
        -- Assume input is on the form <operand> op <operand> op ...
        -- and left associative
        local ast = {}
        ast.node = lst[#lst - 1]
        ast.right = lst[#lst]

        ast.left = build_ast(table.move(lst, 1, #lst - 2, 1, {}))
        return ast
    elseif #lst >= 3 and lst[2] == '^' then
        -- Assume input is on the form <operand> op <operand> op ...
        -- and right associative
        local ast = {}
        ast.node = lst[2]
        ast.left = lst[1]

        ast.right = build_ast(table.move(lst, 3, #lst, 1, {}))
        return ast
    else
       error("Bad expression") 
    end
end

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
        error("Bad expression")
    end
end


local primary = lpeg.V"primary"
local exponent = lpeg.V"exponent"
local term = lpeg.V"term"
local expression = lpeg.V"expression"

local g = lpeg.P{
    "expression",
    primary = numeral + OP * expression * CP,
    exponent = space * lpeg.Ct(primary * (opE * primary)^0) / build_ast,
    term = space * lpeg.Ct(exponent * (opM * exponent)^0) / build_ast,
    expression = space * lpeg.Ct(term * (opA * term)^0) / build_ast
}

g = g * -1

local function eval(string)
    return eval_ast(g:match(string))
end


return {eval=eval}
