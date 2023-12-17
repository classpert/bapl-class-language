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
Machine.OPCODES.PUSH      = 0x10 -- Push the value at memory[pc + 1] to the stack.
Machine.OPCODES.LOAD      = 0x11 -- Push the value at memory[memory[pc + 1]] to the stack.
Machine.OPCODES.STORE     = 0x12 -- Pop TOS and store at memory[memory[pc + 1]].
Machine.OPCODES.ADD       = 0x20 -- Pop 2 elements TOS(0), TOS(1) and push the sum to TOS(0).
Machine.OPCODES.SUB       = 0x21 -- Pop 2 elements TOS(0), TOS(1) and push the difference TOS(1) - TOS(0) to TOS(0)
Machine.OPCODES.MULT      = 0x22 -- Pop 2 elements TOS(0), TOS(1) and push the product to TOS(0)
Machine.OPCODES.DIV       = 0x23 -- Pop 2 elements TOS(0), TOS(1) and push the quote TOS(1) / TOS(0) to TOS(0)
Machine.OPCODES.REM       = 0x24 -- Pop 2 elements TOS(0), TOS(1) and push the reminder TOS(1) % TOS(0) to TOS(0)
Machine.OPCODES.EXP       = 0x25 -- Pop 2 elements TOS(0), TOS(1) and push the exponent TOS(1) ^ TOS(0) to TOS(0)
Machine.OPCODES.EQ        = 0x26 -- Pop 2 elements TOS(0), TOS(1) and push the comparsion TOS(1) == TOS(0) to TOS(0)
Machine.OPCODES.NEQ       = 0x27 -- Pop 2 elements TOS(0), TOS(1) and push the comparsion TOS(1) != TOS(0) to TOS(0)
Machine.OPCODES.LT        = 0x28 -- Pop 2 elements TOS(0), TOS(1) and push the comparsion TOS(1) < TOS(0) to TOS(0)
Machine.OPCODES.LE        = 0x29 -- Pop 2 elements TOS(0), TOS(1) and push the comparsion TOS(1) <= TOS(0) to TOS(0)
Machine.OPCODES.GT        = 0x2a -- Pop 2 elements TOS(0), TOS(1) and push the comparsion TOS(1) > TOS(0) to TOS(0)
Machine.OPCODES.GE        = 0x2b -- Pop 2 elements TOS(0), TOS(1) and push the comparsion TOS(1) >= TOS(0) to TOS(0)
Machine.OPCODES.NEG       = 0x30 -- Pop1 element TOS(0) and push the negation -TOS(1) to the stack.
Machine.OPCODES.RETURN    = 0xA0 -- Exit current function. Note: for now it exits the VM run function.
Machine.OPCODES.JMP       = 0xA1 -- Jump unconditionally, pc <- memory[pc + 1]
Machine.OPCODES.HALT      = 0xF0 -- Halt the machine,
Machine.OPCODES.PRINT     = 0xF1 -- Print TOS via io channel. Leaves stack unchanged.
Machine.OPCODES.BINOP_LOOKUP = {
    [Machine.OPCODES.ADD] = function (a, b) return a + b end,
    [Machine.OPCODES.SUB] = function (a, b) return a - b end,
    [Machine.OPCODES.MULT] = function (a, b) return a * b end,
    [Machine.OPCODES.DIV] = function (a, b) return a / b end,
    [Machine.OPCODES.REM] = function (a, b) return a % b end,
    [Machine.OPCODES.EXP] = function (a, b) return a ^ b end,
    [Machine.OPCODES.EQ] = function (a, b) return a == b and 1 or 0 end,
    [Machine.OPCODES.NEQ] = function (a, b) return a ~= b and 1 or 0 end,
    [Machine.OPCODES.LT] = function (a, b) return a < b and 1 or 0 end,
    [Machine.OPCODES.LE] = function (a, b) return a <= b and 1 or 0 end,
    [Machine.OPCODES.GT] = function (a, b) return a > b and 1 or 0 end,
    [Machine.OPCODES.GE] = function (a, b) return a >= b and 1 or 0 end,
}
Machine.OPCODES.UNARYOP_LOOKUP = {
    [Machine.OPCODES.NEG] = function (a) return -a end,
}
Machine.OPCODES.NAME_LOOKUP = {
    [Machine.OPCODES.PUSH]      = "PUSH",
    [Machine.OPCODES.LOAD]      = "LOAD",
    [Machine.OPCODES.STORE]     = "STORE",
    [Machine.OPCODES.ADD]       = "ADD",
    [Machine.OPCODES.SUB]       = "SUB",
    [Machine.OPCODES.MULT]      = "MULT",
    [Machine.OPCODES.DIV]       = "DIV",
    [Machine.OPCODES.REM]       = "REM",
    [Machine.OPCODES.EXP]       = "EXP",
    [Machine.OPCODES.EQ]        = "EQ",
    [Machine.OPCODES.NEQ]       = "NEQ",
    [Machine.OPCODES.LT]        = "LT",
    [Machine.OPCODES.LE]        = "LE",
    [Machine.OPCODES.GT]        = "GT",
    [Machine.OPCODES.GE]        = "GE",
    [Machine.OPCODES.NEG]       = "NEG",
    [Machine.OPCODES.RETURN]    = "RETURN",
    [Machine.OPCODES.JMP]       = "JMP",
    [Machine.OPCODES.HALT]      = "HALT",
    [Machine.OPCODES.PRINT]     = "PRINT",
}

local utils = {}

function utils.printStep(pc, op, operand, tos)
    local op_name = Machine.OPCODES.NAME_LOOKUP[op]
    local tos_string = ""
    if type(tos) == "number" then
        tos_string = string.format("%9.2f", tos)
    elseif type(tos) == "nil" then
        tos_string = string.format("%9s", " ")
    else
        tos_string = tostring(tos)
    end
  
    local operand_is_address = {
        [Machine.OPCODES.LOAD]  = true,
        [Machine.OPCODES.STORE] = true, 
        [Machine.OPCODES.JMP]   = true, 
    }

    local operand_string = ""
    if operand and operand_is_address[op] then
        operand_string = string.format("%08x", operand)
    elseif operand then
        operand_string = tostring(operand)
    end

    print(string.format("%08x: %-9s %9s %9s", pc, op_name, operand_string, tos_string))
end

function utils.printHeader()
    print(string.format("%-9s %-9s %9s %9s", "Address", "Operation", "Operand", "TOS"))
    print("----------------------------------------")
end




-- Create a 'Machine' and load the program in 'memory'.
function Machine:new (ios)
    local ios = ios or io.stdout
    local machine = { 
        pc_ = 1, 
        memory_ = {Machine.OPCODES.HALT}, 
        stack_ = Stack:new(), 
        trace_ = false,
        io_ = ios,
    }
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

-- Set trace of execution.
function Machine:setTrace (trace)
    self.trace_ = trace
end

-- Loads a program and set pc to 1 (e.g start of program).
function Machine:load (image)
    self.memory_ = image
    self.pc_ = 1
    self.stack_ = Stack:new()
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
    local unaryop_fn = Machine.OPCODES.UNARYOP_LOOKUP[op]

    -- Values used for optional trace step
    local pc = self.pc_
    local operand = nil

    if op == Machine.OPCODES.HALT then
        -- Do nothing!
    elseif op == Machine.OPCODES.RETURN then
        -- For now do nothing.
    elseif op == Machine.OPCODES.JMP then
        operand = self.memory_[self.pc_ + 1]
        self.pc_ = operand
    elseif op == Machine.OPCODES.PUSH then
        operand = self.memory_[self.pc_ + 1]
        self.stack_:push(operand)
        self.pc_ = self.pc_ + 2
    elseif op == Machine.OPCODES.LOAD then
        operand = self.memory_[self.pc_ + 1]
        self.stack_:push(self.memory_[operand])
        self.pc_ = self.pc_ + 2
    elseif op == Machine.OPCODES.STORE then
        operand = self.memory_[self.pc_ + 1]
        self.memory_[operand] = self.stack_:pop()
        self.pc_ = self.pc_ + 2
    elseif op == Machine.OPCODES.PRINT then
        self.io_:write(self.stack_:peek())
        self.pc_ = self.pc_ + 1
    elseif binop_fn ~= nil then
        local tos_0 = self.stack_:pop()
        local tos_1 = self.stack_:pop()
        self.stack_:push(binop_fn(tos_1, tos_0))
        self.pc_ = self.pc_ + 1
    elseif unaryop_fn ~= nil then
        local tos_0 = self.stack_:pop()
        self.stack_:push(unaryop_fn(tos_0))
        self.pc_ = self.pc_ + 1
    else
        error ("Unknown instruction!")
    end

    if self.trace_ then
        utils.printStep(pc, op, operand, self:tos())
    end
end


function Machine:isHalted ()
    if self.pc_ > #self.memory_ then
        return true
    elseif self.memory_[self.pc_] == Machine.OPCODES.HALT then
        return true
    elseif self.memory_[self.pc_] == Machine.OPCODES.RETURN then
        return true
    else
        return false
    end
end

-- Run the machine until we reach the end of Memory
function Machine:run ()
    -- Trace: start
    if self.trace_ then
        utils.printHeader()
    end

    while not self:isHalted() do
        self:step()
    end
    
    -- Trace: end
    if self.trace_ then
        print("")
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

