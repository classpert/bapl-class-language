local inspect = require "inspect"
local lpeg = require "lpeg"
local lu = require "luaunit"

local dot = lpeg.P(".")
local sign = lpeg.S("-+")
local whitespace = lpeg.S(" \t")^0 -- TODO(peter): More whitespaces...

-- NOTE: Allow for whitespaces after operator based on information
--       in lecture "Summations".
local opPrio0 = lpeg.C(lpeg.S("+-")) *  whitespace
local opPrio1 = lpeg.C(lpeg.S("*/%")) * whitespace
local opPrio2 = lpeg.C(lpeg.S("^")) * whitespace

-- Matches any singular digit.
local digit = lpeg.R("09")


-- Matches any positive integer.
local positive_integer = digit^1

-- Matches integers
local integer = sign^-1 * positive_integer


-- Matches any float expression
-- NOTE1: The order is important here due to short-circuit.
-- NOTE2: I adapted the convetion to allow whitespaces after integer expression
--        based on the information in the lexture "Summations"
-- NOTE3: This version of numbers admits '+' prefix.
local number = (((integer * dot * positive_integer) 
               + (sign^-1 * dot * positive_integer)
               + (integer * dot)
               + integer) / tonumber) * whitespace

-- Function to build a primitive AST (of sorts). Leaf nodes are
-- represented as numbers and other nodes as tables encoding a tree.
local function build_ast(lst)
    -- print(inspect.inspect(lst))
    if #lst == 1 then
        -- Leaf nodes are just numbers
        return lst[1]
    elseif #lst >= 3 and lst[2] ~= '^' then
        -- Assume input is on the form <operand> op <operand> op ...
        -- and left associateive
        local ast = {}
        ast.node = lst[#lst - 1]
        ast.right = lst[#lst]

        ast.left = build_ast(table.move(lst, 1, #lst - 2, 1, {}))
        return ast
    elseif #lst >= 3 and lst[2] == '^' then
        -- Assume input is on the form <operand> op <operand> op ...
        -- and right associateive
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
--
-- Exercise 4
--
-- Matches expressions consisting of operator '+', '-', '%', '*', '/' and '^'. 
--
-- NOTE: This version is not able to parse recursive expressions such as "18 + 3^(34+343*3)".
local exponent = whitespace * lpeg.Ct(number * (opPrio2 * number)^0) / build_ast
local term = whitespace * lpeg.Ct(exponent * (opPrio1 * exponent)^0) / build_ast
local sum = whitespace * lpeg.Ct(term * (opPrio0 * term)^0) / build_ast * -lpeg.P(1)

TestExpression = {}
    function TestExpression:testSum()
        lu.assertEquals(eval_ast(sum:match("-0.343")), -0.343)
        lu.assertEquals(eval_ast(sum:match("108 + 332 % 100")), 108 + 332 % 100)
        lu.assertEquals(eval_ast(sum:match("45 + 64 * 3^3 / 10")), 45 + 64 * 3^3 / 10)
        lu.assertEquals(eval_ast(sum:match("3 + 3 + 3 + 3")), 3 + 3 + 3 + 3)
        lu.assertEquals(eval_ast(sum:match("2^2^2^2 + 30.3")), 2^2^2^2 + 30.3)
        lu.assertEquals(eval_ast(sum:match("10/10/10/10/10 + 33")), 10/10/10/10/10 + 33)
        lu.assertEquals(eval_ast(sum:match("10/10/10/10/10 + 33")), 10/10/10/10/10 + 33)
        lu.assertEquals(eval_ast(sum:match("10-10-10-10-10 + 33")), 10-10-10-10-10 + 33)
    end

os.exit(lu.LuaUnit:run())


