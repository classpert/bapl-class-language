local lpeg = require "lpeg"
local lu = require "luaunit"

local dot = lpeg.P(".")
local negation = lpeg.P("-")
local whitespace = lpeg.S(" \t") -- TODO(peter): More whitespaces...
local plus = lpeg.P("+")

function whitespace_wrapped(pattern)
    return whitespace^0 * pattern * whitespace^0
end

-- Matches any singular digit.
local digit = lpeg.R("09")


-- Matches any positive integer.
local positive_integer = digit^1

-- Matches integers
local integer = negation^-1 * positive_integer


-- Matches any float expression
-- NOTE: The order is important here due to short-circuit.
local number = (integer * dot * positive_integer) 
               + (negation^-1 * dot * positive_integer)
               + (integer * dot)
               + integer


--
-- Exercise 3
--

-- Matches sums of numbers, captures numbers and the position of the addition operator.
--
-- Examples: 123, 2.0 + 23.2, 22.3 + .1 + 0.1
local sum = whitespace_wrapped(lpeg.C(number)) * (lpeg.Cp() * plus * whitespace_wrapped(lpeg.C(number)))^0

TestExpression = {}
    function TestExpression:testSum2()
        local pack = table.pack
        lu.assertEquals(pack(sum:match("125")),    {"125", n=1})
        lu.assertEquals(pack(sum:match(" -12. ")), {"-12.", n=1})
        lu.assertEquals(pack(sum:match(" -1.3 ")), {"-1.3", n=1})
        
        -- Check two addends
        lu.assertEquals(pack(sum:match("324+343.0")),   {"324", 4, "343.0", n=3})
        lu.assertEquals(pack(sum:match("343+ 343.")),   {"343", 4, "343.", n=3})
        lu.assertEquals(pack(sum:match(" 43.0 +  1.")), {"43.0", 7, "1.", n=3});

        -- Check three and more addends.
        lu.assertEquals(pack(sum:match(" 33.0 + -4 + .34 ")), {"33.0", 7, "-4", 12, ".34", n=5})
        lu.assertEquals(pack(sum:match(" 1 + 3 + 2 +4+5+5")), {"1", 4, "3", 8, "2", 12, "4", 14, "5", 16, "5", n=11})
        lu.assertEquals(pack(sum:match("-232+-5+-6+-.53")),   {"-232", 5, "-5", 8, "-6", 11, "-.53", n=7})

        -- Check deranged cases.
        lu.assertIsNil(sum:match("+"))
        lu.assertIsNil(sum:match("   "))
        lu.assertIsNil(sum:match("  +  "))
        lu.assertIsNil(sum:match("  +  +  "))
        lu.assertIsNil(sum:match("  +3434"))
        -- Matches ' 1234 '
        lu.assertEquals(pack(sum:match(" 1234 +")), {"1234", n=1})
        -- Matches ' 1234 + 0.34'
        lu.assertEquals(pack(sum:match(" 1234 + 0.34+")), {"1234", 7, "0.34", n=3})
    end

os.exit(lu.LuaUnit:run())

