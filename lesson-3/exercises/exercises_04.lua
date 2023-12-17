--
-- Exercise 04: Undefined variables
--

--  
-- <root>/elements/containers/stack.lua                     <- implementation of a stack
-- <root>/elements/containers/tree.lua                      <- implementation of a tree
-- <root>/lesson-3/exercies/components_04/machine.lua       <- implementation of our stack machine (very simple).
-- <root>/lesson-3/exercies/components_04/compiler.lua      <- compiler that generates code for the machine from arithmetic
--                                                             expressions. Based on interpreter from lesson1.
--

-- Loads Stack Machine implementation.
require "components_04/machine"
-- Loads compiler that compiles arithmetic expressions to machine code
local compiler = require "components_04/compiler"
local lu = require "luaunit"


-- Make sure we are not regressing due to modifications.
TestMachine = {}
    function TestMachine:testExpressions()
        local TestIO = { prints = {}}
        function TestIO:write(...)
            io.stdout:write(... .. "\n")
            table.insert(self.prints, ...)
        end
     
        local machine = Machine:new(TestIO)
        machine:setTrace(true) -- print trace of execution to stdout
        local function eval(str)
            local program = compiler.compile(str)
            machine:load(program)
            machine:run()
            return machine:tos()
        end

        local function eval_print(str)
            local program = compiler.compile(str)
            TestIO.prints = {}
            machine:load(program)
            machine:run()
            return TestIO.prints 
        end
        -- Regression
        lu.assertEquals(eval("x = 2.3; y = 4.3; z = x^2 + y^2; return z; z = 20"), 2.3^2 + 4.3^2) 
        lu.assertEquals(eval_print("z = 10; @ z; @ z^2"), {10, 100})
        
        -- Using non assigned variables in statements is an error 
        lu.assertError(eval, "z = x + y; @ z") 

        status, e = pcall(eval, "z = x + y; @ z")
        lu.assertEquals(status, false)
        lu.assertEquals(e.code, compiler.ERRORS.UNDEFINED_VARIABLE)
    end

os.exit(lu.LuaUnit:run())

