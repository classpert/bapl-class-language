--
-- Exercise 01: Error messages with  line numbers.
--

--  
-- <root>/elements/containers/stack.lua                     <- implementation of a stack
-- <root>/elements/containers/tree.lua                      <- implementation of a tree
-- <root>/lesson-4/exercies/components_04/machine.lua       <- implementation of our stack machine (very simple).
-- <root>/lesson-4/exercies/components_04/compiler.lua      <- compiler that generates code for the machine from arithmetic
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
        lu.assertEquals(eval("x = 2.3; y = 4.3 + -2.0^(2 - 3.3); z = x^2 + y^2; return z; z = 20"), 2.3^2 + (4.3 + -2.0^(2 - 3.3))^2) 
        lu.assertEquals(eval_print("z = 10; @ z; @ z^2"), {"10\n", "100.0\n"})
        lu.assertError(eval, "z = x + y; @ z") 

        status, data = pcall(compiler.compile, "?x = 10  y = 5   ;  \n _letter = 3 * ) \t\n\n\n")
        lu.assertFalse(status)
        lu.assertEquals(data.payload.row, 1)
        lu.assertEquals(data.payload.col, 1)
        print(data.payload.message)

        status, data = pcall(compiler.compile, "x = 10  y = 5   ;  \n _letter = 3 * ) \t\n\n\n")
        lu.assertFalse(status)
        lu.assertEquals(data.payload.row, 1)
        lu.assertEquals(data.payload.col, 7)
        print(data.payload.message)

        status, data = pcall(compiler.compile, "x = 10  ;;;y = 5   ;  \n\n_letter = 3 * ) \t\n\n\n")
        lu.assertFalse(status)
        lu.assertEquals(data.payload.row, 3)
        lu.assertEquals(data.payload.col, 15)
        print(data.payload.message)

        status, data = pcall(compiler.compile, "\n\nx = 1;\ny = 5;\n\n\na =  ")
        lu.assertFalse(status)
        lu.assertEquals(data.payload.row, 7)
        lu.assertEquals(data.payload.col, 5)
        print(data.payload.message)

        status, data = pcall(compiler.compile, "\n\nx = 1;\ny = 5;\n\n\na = 333ll")
        lu.assertFalse(status)
        lu.assertEquals(data.payload.row, 7)
        lu.assertEquals(data.payload.col, 8)
        print(data.payload.message)

    end

os.exit(lu.LuaUnit:run())

