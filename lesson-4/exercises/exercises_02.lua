--
-- Exercise 02: Block comments
--

--  
-- <root>/elements/containers/stack.lua                     <- implementation of a stack
-- <root>/elements/containers/tree.lua                      <- implementation of a tree
-- <root>/lesson-4/exercies/components_02/machine.lua       <- implementation of our stack machine (very simple).
-- <root>/lesson-4/exercies/components_02/compiler.lua      <- compiler that generates code for the machine from arithmetic
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


        -- Line comments
        lu.assertEquals(eval("x = 3; # x value ###\ny = 4; # y-value not z = 4; \nreturn x + y;"), 7) 
        
        -- Block comment
        lu.assertEquals(
            eval("m #{ mass #} = 3.0; v #{ velocity #} = 2.4;  W #{ kinetical energy #} = m * v^2 / 2.0; return W;"),  
            8.64) 
        
        -- Block and line comment intermixed.
        lu.assertEquals(
            eval("m #{\n# mass\n #} = 3.0; v #{ velocity\n # m/s \n #} = 2.4; W = m * v^2 / 2.0; return W;"),
            8.64)

        -- Line comment starting with block-end is ok.
        lu.assertEquals(
            eval("m #} ## mass\n  = 3.0; v #{ velocity\n # m/s \n #} = 2.4; W = m * v^2 / 2.0; return W;"),
            8.64)

        -- Block comment containing multiple block starts.
        lu.assertEquals(
            eval("m #{ #{ \n# #{ mass\n #} = 3.0; v #{ velocity\n # m/s \n #} = 2.4; W = m * v^2 / 2.0; return W;"),
            8.64)

        -- Advanced comments
        lu.assertEquals(
            eval("{\nW = 8.64;\n#{ block } {} {comments nested in a block\n # W = 9.0;  #} }; return W;"),
            8.64)

        -- Unmatched block comment is an error.
        status, data = pcall(compiler.compile, "x = 3; #{ Some unfinished commment\n y = x + 3; return y")
        lu.assertFalse(status)
        print(data.payload.message)
        lu.assertEquals(data.payload.row, 1)
        lu.assertEquals(data.payload.col, 8)

    end

os.exit(lu.LuaUnit:run())

