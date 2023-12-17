--
-- Exercise 01: Rules for identifiers
--

--  
-- <root>/elements/containers/stack.lua                     <- implementation of a stack
-- <root>/elements/containers/tree.lua                      <- implementation of a tree
-- <root>/lesson-3/exercies/components_01/machine.lua       <- implementation of our stack machine (very simple).
-- <root>/lesson-3/exercies/components_01/compiler.lua      <- compiler that generates code for the machine from arithmetic
--                                                             expressions. Based on interpreter from lesson1.
--

-- Loads Stack Machine implementation.
require "components_01/machine"
-- Loads compiler that compiles arithmetic expressions to machine code
local compiler = require "components_01/compiler"
local lu = require "luaunit"


-- Make sure we are not regressing due to modifications.
TestMachine = {}
    function TestMachine:testExpressions()
        local machine = Machine:new()
        machine:setTrace(true) -- print trace of execution to stdout
        local function eval(str, env)
            local program = compiler.compile(str)
            local env = env or {}
            for key, info in pairs(program.debuginfo) do
               address = info.address
               program[address] = env[key]
            end

            machine:load(program)
            machine:run()
            return machine:tos()
        end

        -- Make sure there is no regression for numerals
        lu.assertEquals(eval("10 + 0xff ^ (0.3 + 0x02)"), 10 + 0xff ^ (0.3 + 0x02))
        lu.assertEquals(eval("18 % 3 == 0 > 1"), ((18 % 3 == 0) and 1 or 0) > 1 and 1 or 0)
        lu.assertEquals(eval("(-8.0 < 10.0) + 10.1"), (-8.0 < 10.0 and 1 or 0) + 10.1)
        lu.assertEquals(eval("2^3^0.5^2.2 + 3.1"), 2^3^0.5^2.2 + 3.1)
        lu.assertEquals(eval("10 - 11 - 12 - 13 + 3.1"), 10 - 11 - 12 - 13 + 3.1)
        lu.assertEquals(eval("(1 + 1.3e-3) * (3.0 - -1.3e-3)^2 % 1.1e2"), (1 + 1.3e-3) * (3.0 - -1.3e-3)^2 % 1.1e2)
        
        -- Test identifiers
        lu.assertEquals(eval("x", {x = 10}), 10) 
        lu.assertEquals(eval("x + 10", {x = 3.51}), 3.51 + 10) 
        lu.assertEquals(eval("x + y^2", {x = 3.51, y = -0.5}), 3.51 + (-0.5)^2) 
        lu.assertEquals(eval("_x + y_1^2", {_x = 3.51, y_1 = -0.5}), 3.51 + (-0.5)^2) 
        lu.assertEquals(eval("longidentifier", {longidentifier = 22}), 22) 
        lu.assertEquals(eval("__x - 2^y__", {__x = 1.1, y__ = 2.3}), 1.1 - 2^2.3)

    end

os.exit(lu.LuaUnit:run())

