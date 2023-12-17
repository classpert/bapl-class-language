--
-- Exercise 02: Empty statement
--

--  
-- <root>/elements/containers/stack.lua                     <- implementation of a stack
-- <root>/elements/containers/tree.lua                      <- implementation of a tree
-- <root>/lesson-3/exercies/components_02/machine.lua       <- implementation of our stack machine (very simple).
-- <root>/lesson-3/exercies/components_02/compiler.lua      <- compiler that generates code for the machine from arithmetic
--                                                             expressions. Based on interpreter from lesson1.
--

-- Loads Stack Machine implementation.
require "components_02/machine"
-- Loads compiler that compiles arithmetic expressions to machine code
local compiler = require "components_02/compiler"
local lu = require "luaunit"


-- Make sure we are not regressing due to modifications.
TestMachine = {}
    function TestMachine:testExpressions()
        local machine = Machine:new()
        machine:setTrace(true) -- print trace of execution to stdout
        local function eval(str, env, v_test)
            local program = compiler.compile(str)
            local env = env or {}
            local di = program.debuginfo
            for key, info in pairs(di) do
                if env[key] then
                    address = info.address
                    program[address] = env[key]
                end
            end

            machine:load(program)
            machine:run()

            
            return program[di[v_test].address]
        end

        -- Test statement
        lu.assertEquals(eval("z = x^0.23 + 3.1*y", {x = 10, y = 3}, "z"), 10^0.23 + 3.1*3) 

        -- Test sequence
        lu.assertEquals(eval("x = 10; y = 3; z = x^0.23 + 3.1*y", {}, "z"), 10^0.23 + 3.1*3)
        lu.assertEquals(eval("   {x = 10;} ; y = 3; z = x^0.23 + 3.1*y", {}, "z"), 10^0.23 + 3.1*3)
        lu.assertEquals(eval("   {x = 10;} ;; y = 3; z = x^0.23 + 3.1*y", {}, "z"), 10^0.23 + 3.1*3)
        lu.assertEquals(eval("   {}; {x = 10;} ;; y = 3; z = x^0.23 + 3.1*y", {}, "z"), 10^0.23 + 3.1*3)
        lu.assertEquals(eval("   {{}}; {x = 10;} ;; x=13;;; y = 3; z = x^0.23 + 3.1*y", {}, "z"), 13^0.23 + 3.1*3)

    end

os.exit(lu.LuaUnit:run())

