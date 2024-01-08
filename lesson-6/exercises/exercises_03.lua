-- Loads Stack Machine implementation.
require "machine"
-- Loads compiler that compiles arithmetic expressions to machine code
local compiler = require "compiler"
local lu = require "luaunit"
local errors = require "errors"

-- Make sure we are not regressing due to modifications.
TestMachine = {}
    function TestMachine:testExpressions()
        local machine = Machine:new()
        local gc_size_before = nil
        local gc_size_after  = nil
        local program        = nil
        machine:setTrace(false)

        -- GC measurment
        program = compiler.compile("n = 1; x = new [100000]; while n <= 100000 { x[n] = n * 2;  n = n + 1}; return x[50000];")
        machine:load(program)

        collectgarbage("collect")
        gc_size_before = collectgarbage("count")
        print("Allocated before: ", gc_size_before, "kB")
        machine:run()
        lu.assertEquals(machine:tos(), 100000)

        collectgarbage("collect")
        gc_size_after = collectgarbage("count")
        print("Allocated after:  ", gc_size_after, "kB")
        lu.assertNotAlmostEquals(gc_size_before/gc_size_after, 1, 0.8)


        program = compiler.compile("n = 1; x = new [100000]; while n <= 100000 { x[n] = n * 2;  n = n + 1}; x = 10; return x;")
        machine:load(program)

        collectgarbage("collect")
        gc_size_before = collectgarbage("count")
        print("Allocated before: ", gc_size_before, "kB")
        machine:run()
        lu.assertEquals(machine:tos(), 10)

        collectgarbage("collect")
        gc_size_after = collectgarbage("count")
        print("Allocated after:  ", gc_size_after, "kB")
        lu.assertAlmostEquals(gc_size_before/gc_size_after, 1, 0.2)
    end
os.exit(lu.LuaUnit:run())

