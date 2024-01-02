--
-- Exercise 01: 'not' operator.
--

--  
-- <root>/elements/containers/stack.lua                     <- implementation of a stack
-- <root>/elements/containers/tree.lua                      <- implementation of a tree
-- <root>/lesson-5/exercies/components_01/machine.lua       <- implementation of our stack machine (very simple).
-- <root>/lesson-5/exercies/components_01/compiler.lua      <- compiler that generates code for the machine from arithmetic
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
        local status = true
        local payload = {}
        -- Regression
        lu.assertEquals(eval("x = 2.3; y = 4.3 + -2.0^(2 - 3.3); z = x^2 + y^2; return z; z = 20"), 2.3^2 + (4.3 + -2.0^(2 - 3.3))^2) 
        lu.assertEquals(eval_print("z = 10; @ z; @ z^2"), {"10\n", "100.0\n"})
        lu.assertError(eval, "z = x + y; @ z") 

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

        lu.assertEquals(eval("x = 3; # x value ###\ny = 4; # y-value not z = 4; \nreturn x + y;"), 7) 
        lu.assertEquals(
            eval("m #{ mass #} = 3.0; v #{ velocity #} = 2.4;  W #{ kinetical energy #} = m * v^2 / 2.0; return W;"),  
            8.64) 
        lu.assertEquals(
            eval("m #{\n# mass\n #} = 3.0; v #{ velocity\n # m/s \n #} = 2.4; W = m * v^2 / 2.0; return W;"),
            8.64)
        lu.assertEquals(
            eval("m #} ## mass\n  = 3.0; v #{ velocity\n # m/s \n #} = 2.4; W = m * v^2 / 2.0; return W;"),
            8.64)
        lu.assertEquals(
            eval("m #{ #{ \n# #{ mass\n #} = 3.0; v #{ velocity\n # m/s \n #} = 2.4; W = m * v^2 / 2.0; return W;"),
            8.64)
        lu.assertEquals(
            eval("{\nW = 8.64;\n#{ block } {} {comments nested in a block\n # W = 9.0;  #} }; return W;"),
            8.64)

        status, data = pcall(compiler.compile, "x = 3; #{ Some unfinished commment\n y = x + 3; return y")
        lu.assertFalse(status)
        lu.assertEquals(data.payload.row, 1)
        lu.assertEquals(data.payload.col, 8)
        print(data.payload.message)

        status, data = pcall(compiler.compile, "return = 3; y = return + 3; return return")
        lu.assertFalse(status)
        lu.assertEquals(data.payload.row, 1)
        lu.assertEquals(data.payload.col, 8)
        print(data.payload.message)

        -- Test logical negation.
        lu.assertEquals(eval("x = ! 10; return x;"), 0)
        lu.assertEquals(eval("x = !! 10; return x;"), 1)
        lu.assertEquals(eval("x = 10; return ! -x;"), 0)
        lu.assertEquals(eval("x = 0; return ! x;"), 1)
        lu.assertEquals(eval("x = 1; y = 10; return ! x > y"), 0)
        lu.assertEquals(eval("return ! 1 + 11 < 12"), 1)
        lu.assertEquals(eval("return ! (1 + 11 < 12)"), 1)
        lu.assertEquals(eval("x = 1; y = 11; z = 12; return ! x + y < z"), 1)
        lu.assertEquals(eval("x = 1; y = 11; z = 12; return ! (x + y < z)"), 1)
        lu.assertEquals(eval("x = 1; y = 1; return ! x < y"), 1)
        lu.assertEquals(eval("x = 1; y = 1; return  x < !y"), 0)
        lu.assertEquals(eval("x = 1; y = 1; return ! (x < y)"), 1)
        lu.assertEquals(eval("x = 1; return -!-!-x"), -1)


    end

os.exit(lu.LuaUnit:run())

