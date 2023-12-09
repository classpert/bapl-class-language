--
-- Exercise 02: Hexadecimal numbers.
--

-- NOTE: I'll extend on the machine and compiler code from Exercise 01. To keep components separate
--       between exercies I've placed them under `<cwd>/components_<exercise_index>`. Extended parts
--       are highlighted with comments referencing this exercise.


--  
-- <root>/elements/containers/stack.lua                     <- implementation of a stack
-- <root>/elements/containers/binary_tree.lua               <- implementation of a binary tree
-- <root>/lesson-2/exercies/components_02/machine.lua       <- implementation of our stack machine (very simple).
--

-- NOTE: Look for changes in this file as solutions for this exercise.
-- <root>/lesson-2/exercies/components_02/compiler.lua      <- compiler that generates code for the machine from arithmetic
--                                                    expressions. Based on interpreter from lesson1.
--

-- Loads Stack Machine implementation.
require "components_02/machine"
-- Loads compiler that compiles arithmetic expressions to machine code
local compiler = require "components_02/compiler"
local lu = require "luaunit"


TestMachine = {}
    function TestMachine:testExpressions()
        local machine = Machine:new()
        local function eval(str)
            local program = compiler.compile(str)
            machine:load(program)
            machine:run()
            return machine:tos()
        end

        -- Make sure there is no regression for numerals
        lu.assertEquals(eval("(1 + 3.1) * (3.0 - -2.2)^2 % 25.5"), (1 + 3.1) * (3.0 - -2.2)^2 % 25.5)

        -- Test hexadecimal numbers 
        lu.assertEquals(eval("0x00"), 0x00)
        lu.assertEquals(eval("0xf04a"), 0xf04a)
        lu.assertEquals(eval("0Xf04a"), 0Xf04a)
        lu.assertEquals(eval("0XF04A"), 0XF04A)
        lu.assertEquals(eval("-0xF04A"), -0xF04A)
        lu.assertEquals(eval("+0xF04A"), 0xF04A)


        -- Test arithmetics with hexadecimal numbers
        lu.assertEquals(eval("0x0a + 0xff ^ (0x01 + 0x02)"), 0x0a + 0xff ^ (0x01 + 0x02))
        -- Test arithmetics with mixed numerals,
        lu.assertEquals(eval("10 + 0xff ^ (0.3 + 0x02)"), 10 + 0xff ^ (0.3 + 0x02))

    end

os.exit(lu.LuaUnit:run())

