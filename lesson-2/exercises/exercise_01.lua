--
-- Exercise 01: Arithmetic Expression
--


-- Part A.
--
--      Manual execution of stack machine program
--
--      Instruction                 Stack
--
--      push 4                      |  4 |   <-- TOS
--                                  
--      push 2                      |  2 |   <-- TOS
--                                  |  4 |
--
--      push 24                     | 24 |   <-- TOS
--                                  |  2 |
--                                  |  4 |
--
--      push 21                     | 21 |   <-- TOS
--                                  | 24 |
--                                  |  2 |
--                                  |  4 |
--      
--      sub                         |  3 |   <-- TOS
--                                  |  2 |
--                                  |  4 |
--
--
--      mult                        |  6 |   <-- TOS
--                                  |  4 | 
--
--      add                         | 10 |   <-- TOS
--



-- Part B.
--
-- The stack program above corresponds to the arithmetic expression:
--
-- 4 + 2 * (24 - 21) 
-- 
-- Or in binary tree representation:
--
--      '+'
--     /   \ 
--    4    '*'
--         / \
--        2  '-'
--           / \
--          24 21 



-- Extra: Let's try to build a very simple stack machine and execute the program above.
--  
-- <root>/elements/containers/stack.lua                     <- implementation of a stack
-- <root>/elements/containers/binary_tree.lua               <- implementation of a binary tree
-- <root>/lesson-2/exercies/components_01/machine.lua       <- implementation of our stack machine (very simple).
-- <root>/lesson-2/exercies/components_01/compiler.lua      <- compiler that generates code for the machine from arithmetic
--                                                    expressions. Based on interpreter from lesson1.
--
-- Loads 'bapl-class-language/lession-2/exercises/components_01/machine.lua'
require "components_01/machine"
-- Loads compiler that compiles arithmetic expressions to machine code
local compiler = require "components_01/compiler"
local lu = require "luaunit"

TestMachine = {}
    function TestMachine:testExpressions()
        local machine = Machine:new()
        local function eval(str)
            local program = compiler.compile(str)
            machine:load(program)
            machine:run()
            return machine:tos()
        end

        lu.assertEquals(eval("4 + 2 * (24 - 21)"), 10)

        lu.assertEquals(eval("-0.343"), -0.343)
        lu.assertEquals(eval("108 + 332 % 100"), 108 + 332 % 100)
        lu.assertEquals(eval("45 + 64 * 3^3 / 10"), 45 + 64 * 3^3 / 10)
        lu.assertEquals(eval("3 + 3 + 3 + 3"), 3 + 3 + 3 + 3)

        -- Test that ^ is left associative.
        lu.assertEquals(eval("2^2^2^2 + 30.3"), 2^2^2^2 + 30.3)

        -- Test that other operators are right associative.
        lu.assertEquals(eval("10/10/10/10/10 + 33"), 10/10/10/10/10 + 33)
        lu.assertEquals(eval("10*10*10*10*10 + 33"), 10*10*10*10*10 + 33)
        lu.assertEquals(eval("10-10-10-10-10 + 33"), 10-10-10-10-10 + 33)

        -- Test more complicated expressions.
        lu.assertEquals(eval("(1 + 3.1) * (3.0 - -2.2)^2 % 25.5"), (1 + 3.1) * (3.0 - -2.2)^2 % 25.5)

    end

os.exit(lu.LuaUnit:run())
