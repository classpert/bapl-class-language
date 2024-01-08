-- Loads Stack Machine implementation.
require "machine"
-- Loads compiler that compiles arithmetic expressions to machine code
local compiler = require "compiler"
local lu = require "luaunit"
local errors = require "errors"

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
        local data = {}


        -- Test array new
        lu.assertEquals(eval("x = new [2]; x[2] = new [2]; x[2][2] = 5; @ x; return x[2][2];"), 5)
        lu.assertEquals(eval("x = new [2][3]; x[2][2] = 5; @ x; return x[2][2];"), 5)
        lu.assertEquals(eval("x = new [2][3][4]; x[2][2][3] = 5; @ x; return x[2][2][3];"), 5)
        lu.assertEquals(eval("n = 2; m = 5; x = new [n*2][m]; @ x; x[n][m - 1] = 33; return x[n][m - 1] / 3"), 11)

    end
os.exit(lu.LuaUnit:run())

