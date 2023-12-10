--
-- Exercise 06: Floating point numbers.
--

-- NOTE: I'll extend on the machine and compiler code from Exercise 05. To keep components separate
--       between exercies I've placed them under `<cwd>/components_<exercise_index>`. Extended parts
--       are highlighted with comments referencing this exercise.


--  
-- <root>/elements/containers/stack.lua                     <- implementation of a stack
-- <root>/elements/containers/binary_tree.lua               <- implementation of a binary tree
-- <root>/lesson-2/exercies/components_06/machine.lua       <- implementation of our stack machine (very simple).
--

-- NOTE: Look here for updates related to Exercise 06 B. We've had floating point support without E notation since
-- lession 1 so I regard part A satisfied.
-- <root>/lesson-2/exercies/components_06/compiler.lua      <- compiler that generates code for the machine from arithmetic
--                                                             expressions. Based on interpreter from lesson1.
--

-- Loads Stack Machine implementation.
require "components_06/machine"
-- Loads compiler that compiles arithmetic expressions to machine code
local compiler = require "components_06/compiler"
local lu = require "luaunit"


-- Make sure we are not regressing due to modifications.
TestMachine = {}
    function TestMachine:testExpressions()
        local machine = Machine:new()
        machine:setTrace(true) -- print trace of execution to stdout
        local function eval(str)
            local program = compiler.compile(str)
            machine:load(program)
            machine:run()
            return machine:tos()
        end

        -- Make sure there is no regression for numerals
        lu.assertEquals(eval("(1 + 3.1) * (3.0 - -2.2)^2 % 25.5"), (1 + 3.1) * (3.0 - -2.2)^2 % 25.5)
        lu.assertEquals(eval("10 + 0xff ^ (0.3 + 0x02)"), 10 + 0xff ^ (0.3 + 0x02))
        lu.assertEquals(eval("2 + -(2 * -3.1)^2"), 2 + -(2 * -3.1)^2)
        lu.assertEquals(eval("18 % 3 == 0 > 1"), ((18 % 3 == 0) and 1 or 0) > 1 and 1 or 0)
        lu.assertEquals(eval("(-8.0 < 10.0) + 10.1"), (-8.0 < 10.0 and 1 or 0) + 10.1)

        -- E-notation floats
        lu.assertEquals(eval(".5e3"), .5e3)
        lu.assertEquals(eval("22.5e-3"), 22.5e-3)
        lu.assertEquals(eval("1.235e10"), 1.235e10)

        -- E-notation in expressions.
        lu.assertEquals(eval("(1 + 1.3e-3) * (3.0 - -1.3e-3)^2 % 1.1e2"), (1 + 1.3e-3) * (3.0 - -1.3e-3)^2 % 1.1e2)
    end

os.exit(lu.LuaUnit:run())

