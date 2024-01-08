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


        -- Test array print.
        lu.assertEquals(eval_print("x = new [3]; @ x"), {"{,,}\n"})
        lu.assertEquals(eval_print("x = new [3]; x[2] = 2; @ x"), {"{,2,}\n"})
        lu.assertEquals(eval_print("x = new [3]; x[1] = 3; x[2] = 2; @ x"), {"{3,2,}\n"})
        lu.assertEquals(eval_print("x = new [3]; x[1] = 3; x[2] = 2; x[3] = 1; @ x"), {"{3,2,1}\n"})
        lu.assertEquals(eval_print("x = new [3]; x[1] = new [3]; x[2] = 0; x[3] = 0; @ x"), {"{{,,},0,0}\n"})

    end
os.exit(lu.LuaUnit:run())

