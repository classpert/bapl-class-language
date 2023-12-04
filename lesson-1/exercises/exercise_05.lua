local lpeg = require "lpeg"
local lu = require "luaunit"

local dot = lpeg.P(".")
local sign = lpeg.S("-+")
local whitespace = lpeg.S(" \t")^0 -- TODO(peter): More whitespaces...

-- NOTE: Allow for whitespaces after operator based on information
--       in lecture "Summations".
local plus = lpeg.P("+") *  whitespace

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
local number = ((integer * dot * positive_integer) 
               + (sign^-1 * dot * positive_integer)
               + (integer * dot)
               + integer) * whitespace

--
-- Exercise 4
--
-- Matches sums of numbers and captures, captures numbers and the position of the addition operator. Only 
-- valid expressions are matched (i.e the whole string must match).
--
local sum = whitespace * lpeg.C(number) * (lpeg.Cp() * plus * lpeg.C(number))^0 * -lpeg.P(1)


-- 
-- Tests
--

TestNumbers = {}
    function TestNumbers:testNumber()
        -- Check integers
        lu.assertEquals(number:match("1"), 2)
        lu.assertEquals(number:match("-12"), 4)
        lu.assertEquals(number:match("+12"), 4)
        lu.assertEquals(number:match("99934", 6))
        lu.assertEquals(number:match("00003", 6))
        lu.assertEquals(number:match("00003", 6))
        lu.assertEquals(number:match("00003  ", 6))

        -- Check decimal notation
        lu.assertEquals(number:match("123.0", 6))
        lu.assertEquals(number:match(".0012", 6))
        lu.assertEquals(number:match("12.", 4))
        lu.assertEquals(number:match("+12.33", 7))
        lu.assertEquals(number:match("-12.33", 7))
        lu.assertEquals(number:match("-.33", 5))
        lu.assertEquals(number:match("+.33", 5))

        -- Check deranged cases
        lu.assertNil(number:match("-"))
        lu.assertNil(number:match("."))
        lu.assertNil(number:match("-."))
        lu.assertNil(number:match(".-"))
        lu.assertNil(number:match("--23434"))
        lu.assertNil(number:match("..3433"))
        -- Matches '34.'
        lu.assertEquals(number:match("34.."), 4)
        -- Matches '33.'
        lu.assertEquals(number:match("33.-34"), 4)
        -- Matches '33.125'
        lu.assertEquals(number:match("33.125.123"), 7)

    end

TestExpression = {}
    function TestExpression:testSum()
        local pack = table.pack
        lu.assertEquals(pack(sum:match("125")),    {"125", n=1})
        lu.assertEquals(pack(sum:match(" -12. ")), {"-12. ", n=1})
        lu.assertEquals(pack(sum:match(" -1.3 ")), {"-1.3 ", n=1})
        
        -- Check two addends
        lu.assertEquals(pack(sum:match("324+343.0")),   {"324", 4, "343.0", n=3})
        lu.assertEquals(pack(sum:match("343 +343.")),   {"343 ", 5, "343.", n=3})
        lu.assertEquals(pack(sum:match(" 43.0 +  1.")), {"43.0 ", 7, "1.", n=3})
        lu.assertEquals(pack(sum:match(" +45 + +50.0")), {"+45 ", 6, "+50.0", n=3})

        -- Check three and more addends.
        lu.assertEquals(pack(sum:match(" 33.0 + -4 + .34 ")), {"33.0 ", 7, "-4 ", 12, ".34 ", n=5})
        lu.assertEquals(pack(sum:match(" 1 + 3 + 2 +4+5+5")), {"1 ", 4, "3 ", 8, "2 ", 12, "4", 14, "5", 16, "5", n=11})
        lu.assertEquals(pack(sum:match("-232+-5+-6+-.53")),   {"-232", 5, "-5", 8, "-6", 11, "-.53", n=7})
        lu.assertEquals(pack(sum:match("+34++33++32")), {"+34", 4, "+33", 8, "+32", n=5})
        -- Check deranged cases.
        lu.assertIsNil(sum:match("+"))
        lu.assertIsNil(sum:match("   "))
        lu.assertIsNil(sum:match("  +  "))
        lu.assertIsNil(sum:match("  +  +  "))
        lu.assertIsNil(sum:match(" 1234 +"))
        lu.assertEquals(sum:match(" 1234 + 0.34+"))
    end

os.exit(lu.LuaUnit:run())

