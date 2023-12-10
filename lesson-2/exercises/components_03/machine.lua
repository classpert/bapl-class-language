--
-- Idea: The 'Machine' consist of 
--
--   1. A Stack represented by an instance of 'Stack' (see <root>/elements/containers/stack.lua)
--   2. Some Memory reporesented by an array (e.g table with integer indices).
--   3. pc (program counter) register, a variable holding the current instruction to be decoded.
--   4. Logic to decode instructions and manipulate Stack, Memory and the pc.
--
--
require 'elements/containers/stack'
require 'elements/containers/binary_tree'


Machine = {}
Machine.__index = Machine
Machine.OPCODES = {}
Machine.OPCODES.PUSH = 1 -- Push the value at memory[pc + 1] to the stack.
Machine.OPCODES.ADD  = 2 -- Pop 2 elements TOS(0), TOS(1) and push the sum to TOS(0).
Machine.OPCODES.SUB  = 3 -- Pop 2 elements TOS(0), TOS(1) and push the difference TOS(1) - TOS(0) to TOS(0)
Machine.OPCODES.MULT = 4 -- Pop 2 elements TOS(0), TOS(1) and push the product to TOS(0)
Machine.OPCODES.DIV  = 5 -- Pop 2 elements TOS(0), TOS(1) and push the quote TOS(1) / TOS(0) to TOS(0)
Machine.OPCODES.REM  = 6 -- Pop 2 elements TOS(0), TOS(1) and push the reminder TOS(1) % TOS(0) to TOS(0)
Machine.OPCODES.EXP  = 7 -- Pop 2 elements TOS(0), TOS(1) and push the exponent TOS(1) ^ TOS(0) to TOS(0)
Machine.OPCODES.BINOP_LOOKUP = {
    [Machine.OPCODES.ADD] = function (a, b) return a + b end,
    [Machine.OPCODES.SUB] = function (a, b) return a - b end,
    [Machine.OPCODES.MULT] = function (a, b) return a * b end,
    [Machine.OPCODES.DIV] = function (a, b) return a / b end,
    [Machine.OPCODES.REM] = function (a, b) return a % b end,
    [Machine.OPCODES.EXP] = function (a, b) return a ^ b end,
}
Machine.OPCODES.NAME_LOOKUP = {
    [Machine.OPCODES.PUSH] = "PUSH",
    [Machine.OPCODES.ADD] = "ADD",
    [Machine.OPCODES.SUB] = "SUB",
    [Machine.OPCODES.MULT] = "MULT",
    [Machine.OPCODES.DIV] = "DIV",
    [Machine.OPCODES.REM] = "REM",
    [Machine.OPCODES.EXP] = "EXP",
}


-- Create a 'Machine' and load the program in 'memory'.
function Machine:new (memory)
    local machine = { pc_ = 1, memory_ = memory, stack_ = Stack:new(), trace_ = false}
    setmetatable(machine, Machine)
    return machine
end

-- Return the TOS
function Machine:tos ()
    return self.stack_:peek()
end

-- Return the pc
function Machine:pc ()
    return self.pc_
end

-- BEGIN CHANGES FOR EXERCISE 03 B
-- Set trace of execution.
function Machine:setTrace (trace)
    self.trace_ = trace
end
-- END CHANGES FOR EXERCISE 03 B

-- Loads a program and set pc to 1 (e.g start of program).
function Machine:load (memory)
    self.memory_ = memory
    self.pc_ = 1
    self.stack_ = Stack:new()
end

-- BEGIN CHANGES FOR EXERCISE 03 B
local function printStep(pc, op_name, operand)
    operand = operand or ""
    print(string.format("%08x: %-5s %s", pc, op_name, operand))
end

-- Step the machine 1 instruction. I.e
--
-- 1. Read the opcode at pc
-- 2. Push / pop data from stack.
-- 3. Do arithmetics.
-- 4. Push / pop data to the stack.
function Machine:step ()
    local op = self.memory_[self.pc_]

    local binop_fn = Machine.OPCODES.BINOP_LOOKUP[op]
    local op_name = Machine.OPCODES.NAME_LOOKUP[op]
    local pc = self.pc_
    local operand = nil
    if op == Machine.OPCODES.PUSH then
        operand = self.memory_[self.pc_ + 1]
        self.stack_:push(operand)
        self.pc_ = self.pc_ + 2
    elseif binop_fn ~= nil then
        local tos_0 = self.stack_:pop()
        local tos_1 = self.stack_:pop()
        self.stack_:push(binop_fn(tos_1, tos_0))
        self.pc_ = self.pc_ + 1
    else
        error ("Unknown instruction!")
    end

    if self.trace_ then
        printStep(pc, op_name, operand)
    end
end
-- END CHANGES FOR EXERCISE 03 B


function Machine:isStopped ()
    return self.pc_ > #self.memory_
end

-- Run the machine until we reach the end of Memory
function Machine:run ()
    if self:isStopped() then
        if self.trace_ then
            print("\n")
        end
        return
    else
        self:step()
        self:run()
    end
end

-- Iterator to step through the instructions and yield tos.
function Machine:iterator ()
    local m = self
    local function iterator_internal (machine)
        if self:isStopped() then
            return
        else
            coroutine.yield(machine:tos())
            machine:step()
        end
   end

   return coroutine.wrap(function () iterator_internal (m) end)
end

