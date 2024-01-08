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

        -- Array operations.
        lu.assertEquals(eval("x = new [10]; return x;"), {size=10}) 
        lu.assertEquals(eval("x = new [10]; x[1] = 10; x[2] = -10; return x[1];"), 10) 
        lu.assertEquals(eval("x = new [2 * 2 + 1]; i = 1; x[2*i + 2] = -10; return x[4];"), -10) 
        lu.assertEquals(eval("x = new[2]; x[1] = 3; x[2] = 4; y = x[1]^2 + x[2]^2; return y;"), 25) 

        status, data = pcall(eval, "x = new [10]; x[12] = 5")
        lu.assertFalse(status)
        lu.assertEquals(data.code, errors.ERROR_CODES.INDEX_OUT_OF_RANGE)
        
        status, data = pcall(eval, "x = new [10]; x[-1] = 5")
        lu.assertFalse(status)
        lu.assertEquals(data.code, errors.ERROR_CODES.INDEX_OUT_OF_RANGE)


    end

os.exit(lu.LuaUnit:run())

