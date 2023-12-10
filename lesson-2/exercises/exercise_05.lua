--
-- Exercise 05: Adding more Operators - Part 2
--

-- NOTE: I'll extend on the machine and compiler code from Exercise 03. To keep components separate
--       between exercies I've placed them under `<cwd>/components_<exercise_index>`. Extended parts
--       are highlighted with comments referencing this exercise.


--  
-- <root>/elements/containers/stack.lua                     <- implementation of a stack
-- <root>/elements/containers/binary_tree.lua               <- implementation of a binary tree

-- NOTE: Look here for updates related to Exercise 05.
-- <root>/lesson-2/exercies/components_05/machine.lua       <- implementation of our stack machine (very simple).
--

-- NOTE: Look here for updates related to Exercise 05.
-- <root>/lesson-2/exercies/components_05/compiler.lua      <- compiler that generates code for the machine from arithmetic
--                                                             expressions. Based on interpreter from lesson1.
--

-- Loads Stack Machine implementation.
require "components_05/machine"
-- Loads compiler that compiles arithmetic expressions to machine code
local compiler = require "components_05/compiler"
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

        -- Negation
        lu.assertEquals(eval("--2.34"), 2.34)
        lu.assertEquals(eval("---2.34"), -2.34)
        lu.assertEquals(eval("-2^3"), -2^3)
        lu.assertEquals(eval("2 + -(2 * -3.1)^2"), 2 + -(2 * -3.1)^2)

        -- Comparsion
        lu.assertEquals(eval("2 > -1.0"), 2 > -1.0 and 1 or 0)    
        lu.assertEquals(eval("2 < -1.0"), 2 < -1.0 and 1 or 0)    
        lu.assertEquals(eval("2 == -1.0"), 2 == -1.0 and 1 or 0)    
        lu.assertEquals(eval("2.1 >= -1.0"), 2.1 >= -1.0 and 1 or 0)    
        lu.assertEquals(eval("2.1 <= -1.0"), 2.1 <= -1.0 and 1 or 0)    
        lu.assertEquals(eval("2.1 != -1.0"), 2.1 ~= -1.0 and 1 or 0)
        lu.assertEquals(eval("18 % 3 == 0 > 1"), ((18 % 3 == 0) and 1 or 0) > 1 and 1 or 0)
        lu.assertEquals(eval("(-8.0 < 10.0) + 10.1"), (-8.0 < 10.0 and 1 or 0) + 10.1)
    end

os.exit(lu.LuaUnit:run())

