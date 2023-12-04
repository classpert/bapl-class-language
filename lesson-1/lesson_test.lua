it = require "interpreter"
lu = require "luaunit"


TestInterpreter = {}
    function TestInterpreter:testExpressions()
        -- Test simple expressions
        lu.assertEquals(it.eval("-0.343"), -0.343)
        lu.assertEquals(it.eval("108 + 332 % 100"), 108 + 332 % 100)
        lu.assertEquals(it.eval("45 + 64 * 3^3 / 10"), 45 + 64 * 3^3 / 10)
        lu.assertEquals(it.eval("3 + 3 + 3 + 3"), 3 + 3 + 3 + 3)
        
        -- Test that ^ is left associative.
        lu.assertEquals(it.eval("2^2^2^2 + 30.3"), 2^2^2^2 + 30.3)

        -- Test that other operators are right associative.
        lu.assertEquals(it.eval("10/10/10/10/10 + 33"), 10/10/10/10/10 + 33)
        lu.assertEquals(it.eval("10*10*10*10*10 + 33"), 10*10*10*10*10 + 33)
        lu.assertEquals(it.eval("10-10-10-10-10 + 33"), 10-10-10-10-10 + 33)

        -- Test more complicated expressions.
        lu.assertEquals(it.eval("(1 + 3.1) * (3.0 - -2.2)^2 % 25.5"), (1 + 3.1) * (3.0 - -2.2)^2 % 25.5) 
    end


os.exit(lu.LuaUnit:run())
