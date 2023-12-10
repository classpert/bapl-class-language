--
-- Idea: The 'Machine' consist of 
--
--   1. A Stack represented by an instance of 'Stack' (see <root>/elements/containers/stack.lua)
--   2. Some Memory reporesented by an array (e.g table with integer indices).
--   3. PC (program counter) register, a variable holding the current instruction to be decoded.
--   4. Logic to decode instructions and manipulate Stack, Memory and the PC.
--
--
require 'elements/containers/stack'
require 'elements/containers/binary_tree'


Machine = {}
Machine.__index = Machine
Machine.OPCODES = {}
Machine.OPCODES.PUSH = 1 -- Push the value at memory[PC + 1] to the stack.
Machine.OPCODES.ADD  = 2 -- Pop 2 elements TOS(0), TOS(1) and push the sum to TOS(0).
Machine.OPCODES.SUB  = 3 -- Pop 2 elements TOS(0), TOS(1) and push the difference TOS(1) - TOS(0) to TOS(0)
Machine.OPCODES.MULT = 4 -- Pop 2 elements TOS(0), TOS(1) and push the product to TOS(0)
Machine.OPCODES.DIV  = 5 -- Pop 2 elements TOS(0), TOS(1) and push the quote TOS(1) / TOS(0) to TOS(0)
Machine.OPCODES.REM  = 6 -- Pop 2 elements TOS(0), TOS(1) and push the reminder TOS(1) % TOS(0) to TOS(0)
Machine.OPCODES.EXP  = 7 -- Pop 2 elements TOS(0), TOS(1) and push the exponent TOS(1) ^ TOS(0) to TOS(0)

-- Create a 'Machine' and load the program in 'memory'.
function Machine:new (memory)
    local machine = { PC_ = 1, memory_ = memory, stack_ = Stack:new() }
    setmetatable(machine, Machine)
    return machine
end

-- Return the TOS
function Machine:tos ()
    return self.stack_:peek()
end

-- Return the PC
function Machine:PC ()
    return self.PC_
end

-- Loads a program and set PC to 1 (e.g start of program).
function Machine:load (memory)
    self.memory_ = memory
    self.PC_ = 1
    self.stack_ = Stack:new()
end

-- Step the machine 1 instruction. I.e
--
-- 1. Read the opcode at PC
-- 2. Push / pop data from stack.
-- 3. Do arithmetics.
-- 4. Push / pop data to the stack.
--
function Machine:step ()
    local op = self.memory_[self.PC_]
    
    if op == Machine.OPCODES.PUSH then
        self.stack_:push(self.memory_[self.PC_ + 1])
        self.PC_ = self.PC_ + 2
    elseif op == Machine.OPCODES.ADD then
        local tos_0 = self.stack_:pop()
        local tos_1 = self.stack_:pop()
        self.stack_:push(tos_1 + tos_0)
        self.PC_ = self.PC_ + 1
    elseif op == Machine.OPCODES.SUB then
        local tos_0 = self.stack_:pop()
        local tos_1 = self.stack_:pop()
        self.stack_:push(tos_1 - tos_0)
        self.PC_ = self.PC_ + 1
    elseif op == Machine.OPCODES.MULT then
        local tos_0 = self.stack_:pop()
        local tos_1 = self.stack_:pop()
        self.stack_:push(tos_1 * tos_0)
        self.PC_ = self.PC_ + 1
    elseif op == Machine.OPCODES.DIV then
        local tos_0 = self.stack_:pop()
        local tos_1 = self.stack_:pop()
        self.stack_:push(tos_1 / tos_0)
        self.PC_ = self.PC_ + 1
    elseif op == Machine.OPCODES.REM then
        local tos_0 = self.stack_:pop()
        local tos_1 = self.stack_:pop()
        self.stack_:push(tos_1 % tos_0)
        self.PC_ = self.PC_ + 1
    elseif op == Machine.OPCODES.EXP then
        local tos_0 = self.stack_:pop()
        local tos_1 = self.stack_:pop()
        self.stack_:push(tos_1 ^ tos_0)
        self.PC_ = self.PC_ + 1
    else
        error ("Unknown instruction!")
    end
end

function Machine:isStopped ()
    return self.PC_ > #self.memory_
end

-- Run the machine until we reach the end of Memory
function Machine:run ()
    if self:isStopped() then
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

