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
-- Exercise 2
--

-- Matches sums of numbers:
--
-- Examples: 123, 2.0 + 23.2, 22.3 + .1 + 0.1
local sum = whitespace_wrapped(number) * (plus * whitespace_wrapped(number))^0

--
-- Tests
--
TestNumbers = {} 
    function TestNumbers:testNumber()
        -- Check integers
        lu.assertEquals(number:match("1"), 2)
        lu.assertEquals(number:match("-12"), 4)
        lu.assertEquals(number:match("99934", 6))
        lu.assertEquals(number:match("00003", 6))

        -- Check decimal notation
        lu.assertEquals(number:match("123.0", 6))
        lu.assertEquals(number:match(".0012", 6))
        lu.assertEquals(number:match("12.", 4))
        lu.assertEquals(number:match("-12.33", 7))
        lu.assertEquals(number:match("-.33", 5))

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
        -- Check only one addend
        lu.assertEquals(sum:match("125"), 4)
        lu.assertEquals(sum:match(" -12. "), 7)
        lu.assertEquals(sum:match(" -1.3 "), 7)
        
        -- Check two addends
        lu.assertEquals(sum:match("324+343.0"), 10)
        lu.assertEquals(sum:match("343+ 343."), 10)
        lu.assertEquals(sum:match(" 43.0 +  1."), 12);

        -- Check three and more addends.
        lu.assertEquals(sum:match(" 33.0 + -4 + .34 ", 18))
        lu.assertEquals(sum:match(" 1 + 3 + 2 +4+5+5", 18))
        lu.assertEquals(sum:match("-232+-5+-6+-.53"), 16)

        -- Check deranged cases.
        lu.assertIsNil(sum:match("+"))
        lu.assertIsNil(sum:match("   "))
        lu.assertIsNil(sum:match("  +  "))
        lu.assertIsNil(sum:match("  +  +  "))
        lu.assertIsNil(sum:match("  +3434"))
        -- Matches ' 1234 '
        lu.assertEquals(sum:match(" 1234 +"), 7)
        -- Matches ' 1234 + 0.34'
        lu.assertEquals(sum:match(" 1234 + 0.34+"), 13)
    end

os.exit(lu.LuaUnit:run())

