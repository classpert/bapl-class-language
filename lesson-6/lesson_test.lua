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
        local payload = {}
        -- Regression
        lu.assertEquals(eval("x = 2.3; y = 4.3 + -2.0^(2 - 3.3); z = x^2 + y^2; return z; z = 20"), 2.3^2 + (4.3 + -2.0^(2 - 3.3))^2)
        lu.assertEquals(eval_print("z = 10; @ z; @ z^2"), {"10\n", "100.0\n"})
        lu.assertError(eval, "z = x + y; @ z")

        status, data = pcall(compiler.compile, "x = 10  ;{};;{ ;;;};;y = 5   ;  \n\n_letter = 3 * ) \t\n\n\n")
        lu.assertFalse(status)
        lu.assertEquals(data.payload.row, 3)
        lu.assertEquals(data.payload.col, 14)
        print(data.payload.message)

        status, data = pcall(compiler.compile, "\n\nx = 1;\ny = 5;\n\n\na =  ")
        lu.assertFalse(status)
        lu.assertEquals(data.payload.row, 7)
        lu.assertEquals(data.payload.col, 4)
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
        lu.assertEquals(data.payload.col, 7)
        print(data.payload.message)

        status, data = pcall(compiler.compile, "return = 3; y = return + 3; return return")
        lu.assertFalse(status)
        lu.assertEquals(data.payload.row, 1)
        lu.assertEquals(data.payload.col, 7)
        print(data.payload.message)

        lu.assertEquals(eval("x = ! 10; return x;"), 0)
        lu.assertEquals(eval("x = 10; return ! -x;"), 0)
        lu.assertEquals(eval("x = 0; return ! x;"), 1)
        lu.assertEquals(eval("x = 1; y = 10; return ! x > y"), 0)
        lu.assertEquals(eval("x = 1; y = 11; z = 12; return ! x + y < z"), 1)
        lu.assertEquals(eval("x = 1; y = 11; z = 12; return ! (x + y < z)"), 1)
        lu.assertEquals(eval("x = 1; y = 1; return ! x < y"), 1)
        lu.assertEquals(eval("x = 1; y = 1; return  x < !y"), 0)
        lu.assertEquals(eval("x = 1; y = 1; return ! (x < y)"), 1)
        lu.assertEquals(eval("x = 1; return -!-!-x"), -1)

        lu.assertEquals(eval("x = 10; y = 3; if x - 2 == 8 { y = 2; }; return y"), 2)
        lu.assertEquals(eval("x = 10; y = 3; if x - 2 == 7 { y = 2; }; return y"), 3)
        lu.assertEquals(eval("x = 2.1e2; y = 3; if ! (y == 2) { y = x^y; }; return y"), 2.1e2^3)
        lu.assertEquals(eval("x = 2.1e2; y = 3; if (y == 2) { y = x^y; }; return y"), 3)
        lu.assertEquals(eval("x = 10; y = 0; if x == 10 { y = 1; } else { y = 2; }; return y"),  1)
        lu.assertEquals(eval("x = 10; y = 0; if ! (x == 10) { y = 1; } else { y = 2; }; return y"),  2)

        lu.assertEquals(eval("x = 10; y = 0; if x == 10 { y = 1; } elseif x == 9 { y = 2; } else { y = 3; }; return y"), 1)
        lu.assertEquals(eval("x = 9; y = 0; if x == 10 { y = 1; } elseif x == 9 { y = 2; } else { y = 3; }; return y"), 2)
        lu.assertEquals(eval("x = 8; y = 0; if x == 10 { y = 1; } elseif x == 9 { y = 2; } else { y = 3; }; return y"), 3)

        lu.assertEquals(eval("x = 8; y = 0; if x == 10 { y = 1; } elseif x == 9 { y = 2; }; return y"), 0)

        -- While
        lu.assertEquals(eval("x = 0; while x < 3 { @ x; x = x + 1; }; return x"), 3)
        lu.assertEquals(eval("x = 0; while 0 { @ x; x = x + 1; }; return x"), 0)
        lu.assertEquals(eval("n = 6; r = 1; while n > 0 { r = n * r; n = n - 1; }; return r"), 720)

        -- Logical expr (constant fold)
        lu.assertEquals(eval("x = 5 and 4; return x"), 4)
        lu.assertEquals(eval("x = 0 and 4; return x"), 0)
        lu.assertEquals(eval("x = 5 and 0; return x"), 0)
        lu.assertEquals(eval("x = 0 and 0; return x"), 0)
        lu.assertEquals(eval("x = 5 or 4; return x"), 5)
        lu.assertEquals(eval("x = 0 or 4; return x"), 4)
        lu.assertEquals(eval("x = 5 or 0; return x"), 5)
        lu.assertEquals(eval("x = 0 or 0; return x"), 0)
        lu.assertEquals(eval("x = 5 and 4 and 3; return x"), 3)
        lu.assertEquals(eval("x = 0 and 5 and 4; return x"), 0)
        lu.assertEquals(eval("x = 5 and 4 and 0; return x"), 0)
        lu.assertEquals(eval("x = 0 or 1 and 2; return x"), 2)
        lu.assertEquals(eval("x = 3 or 1 and 2; return x"), 3)
        lu.assertEquals(eval("x = 2 and (0 or 1); return x"), 1)
        lu.assertEquals(eval("x = 2 and (1 or 0); return x"), 1)

        -- Logical expr
        lu.assertEquals(eval("x = 5; y = 4; z = 3; f = 0; return x and y;"), 4)
        lu.assertEquals(eval("x = 5; y = 4; z = 3; f = 0; return f and x;"), 0)
        lu.assertEquals(eval("x = 5; y = 4; z = 3; f = 0; return x and f;"), 0)
        lu.assertEquals(eval("x = 5; y = 4; z = 3; f = 0; return f and f;"), 0)
        lu.assertEquals(eval("x = 5; y = 4; z = 3; f = 0; return x or y;"), 5)
        lu.assertEquals(eval("x = 5; y = 4; z = 3; f = 0; return f or x;"), 5)
        lu.assertEquals(eval("x = 5; y = 4; z = 3; f = 0; return x or f;"), 5)
        lu.assertEquals(eval("x = 5; y = 4; z = 3; f = 0; return f or f;"), 0)
        lu.assertEquals(eval("x = 5; y = 4; z = 3; f = 0; return x and y and z;"), 3)
        lu.assertEquals(eval("x = 5; y = 4; z = 3; f = 0; return f and x and y;"), 0)
        lu.assertEquals(eval("x = 5; y = 4; z = 3; f = 0; return x and y and f;"), 0)
        lu.assertEquals(eval("x = 5; y = 4; z = 3; f = 0; return f or x and y;"), 4)
        lu.assertEquals(eval("x = 5; y = 4; z = 3; f = 0; return x or y and z;"), 5)
        lu.assertEquals(eval("x = 5; y = 4; z = 3; f = 0; return x and (f or y);"), 4)
        lu.assertEquals(eval("x = 5; y = 4; z = 3; f = 0; return x and (y or f);"), 4)

        lu.assertEquals(eval("x = 10; y = 9; return x > y and y == 9;"), 1)
        lu.assertEquals(eval("x = 10; y = 9; return x < y and y == 9;"), 0)
        lu.assertEquals(eval("x = 10; y = 9; return x > y and y != 9;"), 0)
        lu.assertEquals(eval("x = 10; y = 9; return x < y and y != 9;"), 0)

        lu.assertEquals(eval("x = 10; y = 9; return x > y or y == 9;"), 1)
        lu.assertEquals(eval("x = 10; y = 9; return x < y or y == 9;"), 1)
        lu.assertEquals(eval("x = 10; y = 9; return x > y or y != 9;"), 1)
        lu.assertEquals(eval("x = 10; y = 9; return x < y or y != 9;"), 0)

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

        -- Test array print.
        lu.assertEquals(eval_print("x = new [3]; @ x"), {"{,,}\n"})
        lu.assertEquals(eval_print("x = new [3]; x[2] = 2; @ x"), {"{,2,}\n"})
        lu.assertEquals(eval_print("x = new [3]; x[1] = 3; x[2] = 2; @ x"), {"{3,2,}\n"})
        lu.assertEquals(eval_print("x = new [3]; x[1] = 3; x[2] = 2; x[3] = 1; @ x"), {"{3,2,1}\n"})
        lu.assertEquals(eval_print("x = new [3]; x[1] = new [3]; x[2] = 0; x[3] = 0; @ x"), {"{{,,},0,0}\n"})

        -- Multidimensional arrays
        lu.assertEquals(eval("x = new [2]; x[2] = new [2]; x[2][2] = 5; @ x; return x[2][2];"), 5)
        lu.assertEquals(eval("x = new [2][3]; x[2][2] = 5; @ x; return x[2][2];"), 5)
        lu.assertEquals(eval("x = new [2][3][4]; x[2][2][3] = 5; @ x; return x[2][2][3];"), 5)
        lu.assertEquals(eval("n = 2; m = 5; x = new [n*2][m]; @ x; x[n][m - 1] = 33; return x[n][m - 1] / 3"), 11)
        lu.assertEquals(eval("n = 2; m = 5; y = new [2]; y[2] = 4; x = new [y[2]][m]; @ x; x[n][m - 1] = 33; return x[n][m - 1] / 3"), 11)



        test_file = io.open("lesson-6/test.xpl", "r"):read("a")
        status, data = pcall(eval, test_file)
        lu.assertEquals(status, true)
    end

os.exit(lu.LuaUnit:run())

