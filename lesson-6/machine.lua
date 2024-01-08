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
local errors = require 'errors'

local ERROR_CODES = errors.ERROR_CODES
local make_error  = errors.make_error

Machine = {}
Machine.__index = Machine
Machine.OPCODES = {}
Machine.OPCODES.VARIANT_BIT = 56 -- start position of the instruction variant.
-- Note: Instructions are 64bit wide. The OPCODES below encode the instruction variant. A variant is 8 bits wide. In the
-- remaining 56 can pack payloads.
Machine.OPCODES.PUSH      = 0x10 -- Push the value at memory[pc + 1] to the stack.
Machine.OPCODES.LOAD      = 0x11 -- Push the value at memory[memory[pc + 1]] to the stack.
Machine.OPCODES.STORE     = 0x12 -- Pop TOS and store at memory[memory[pc + 1]].
Machine.OPCODES.EXCH      = 0x13 -- Pop 2 elements TOS(0), TOS(1) and pushes TOS(0) and then TOS(1)
Machine.OPCODES.POP       = 0x14 -- Pop 1 element TOS(0) from the stack.
Machine.OPCODES.DUP       = 0x15 -- Push a copy of TOS(0) onto the stack.
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
Machine.OPCODES.NEG       = 0x30 -- Pop 1 element TOS(0) and push the negation -TOS(0) to the stack.
Machine.OPCODES.NOT       = 0x31 -- Pop 1 element TOS(0) and push the logical negation !TOS(0) to the stack.
Machine.OPCODES.DEC       = 0x32 -- Pop 1 element TOS(0) and push TOS(0) - 1
Machine.OPCODES.INC       = 0x33 -- Pop 1 element TOS(0) and push TOS(0) + 1
Machine.OPCODES.RETURN    = 0xA0 -- Exit current function. Note: for now it exits the VM run function.
Machine.OPCODES.JMP       = 0xA1 -- Jump unconditionally and absolutely pc <- memory[pc + 1]
-- TODO(peter): Make the branch instruction more compact. We can use the bitfields after the "variant"
-- field to encode whether or not it should pop and element of the stack.
Machine.OPCODES.B         = 0xA2 -- Jump unconditionally and relatively pc <- (menory[pc] & 0xffffffff - 0x7fffffff).
Machine.OPCODES.BZ        = 0xA3 -- Pop 1 element TOS(0) and jump (branch) relative pc <- (memory[pc] & 0xffffffff - 0x7fffffff) if TOS(0) is 0
Machine.OPCODES.BNZ       = 0xA4 -- Pop 1 element TOS(0) and jump (branch) relative pc <- (memory[pc] & 0xffffffff - 0x7fffffff) if TOS(0) is not 0
Machine.OPCODES.BZP       = 0xA5 -- If TOS(0) == 0 branch relative pc <- (memory[pc] & 0xffffffff - 0x7fffffff) and do not pop an element, 
                                 -- otherwise pc <- pc + 1 and pop 1 element of the stack.
Machine.OPCODES.BNZP      = 0xA6 -- If TOS(0) != 0 branch relative pc <- (memory[pc] & 0xffffffff - 0x7fffffff) and do not pop an element, 
                                 -- otherwise pc <- pc + 1 and pop 1 element of the stack.
Machine.OPCODES.NEWARR    = 0xB0 -- Pop 1 element TOS(0), create array storage of size TOS(0) and push address to stack.
Machine.OPCODES.GETARR    = 0xB1 -- Pop 2 elements TOS(0), TOS(1) from the stack and push the contents of array (TOS(1)) at index (TOS(0)) 
Machine.OPCODES.SETARR    = 0xB2 -- Pop 3 elements TOS(0), TOS(1), TOS(2) from the stack, set array (TOS(2)) at index (TOS(1)) to TOS(0).
Machine.OPCODES.SETARRP   = 0xB3 -- Pop 1 element TOS(0) from the stack, set array (TOS(2)) at index (TOS(1)) to TOS(0).
Machine.OPCODES.HALT      = 0xF0 -- Halt the machine,
Machine.OPCODES.PRINT     = 0xF1 -- Pop TOS and Print TOS via io channel.
function toBool (a)
    return (a ~= 0)
end

function fromBool (a)
    return a and 1 or 0
end

Machine.OPCODES.BINOP_LOOKUP = {
    [Machine.OPCODES.ADD]  = function (a, b) return a + b end,
    [Machine.OPCODES.SUB]  = function (a, b) return a - b end,
    [Machine.OPCODES.MULT] = function (a, b) return a * b end,
    [Machine.OPCODES.DIV]  = function (a, b) return a / b end,
    [Machine.OPCODES.REM]  = function (a, b) return a % b end,
    [Machine.OPCODES.EXP]  = function (a, b) return a ^ b end,
    [Machine.OPCODES.EQ]   = function (a, b) return fromBool(a == b) end,
    [Machine.OPCODES.NEQ]  = function (a, b) return fromBool(a ~= b) end,
    [Machine.OPCODES.LT]   = function (a, b) return fromBool(a < b) end,
    [Machine.OPCODES.LE]   = function (a, b) return fromBool(a <= b) end,
    [Machine.OPCODES.GT]   = function (a, b) return fromBool(a > b) end,
    [Machine.OPCODES.GE]   = function (a, b) return fromBool(a >= b) end,
}
Machine.OPCODES.UNARYOP_LOOKUP = {
    [Machine.OPCODES.NEG] = function (a) return -a end,
    [Machine.OPCODES.NOT] = function (a) return fromBool(not(toBool(a))) end,
}
Machine.OPCODES.NAME_LOOKUP = {
    [Machine.OPCODES.PUSH]      = "PUSH",
    [Machine.OPCODES.LOAD]      = "LOAD",
    [Machine.OPCODES.STORE]     = "STORE",
    [Machine.OPCODES.EXCH]      = "EXCH",
    [Machine.OPCODES.POP]       = "POP",
    [Machine.OPCODES.DUP]       = "DUP",
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
    [Machine.OPCODES.NOT]       = "NOT",
    [Machine.OPCODES.DEC]       = "DEC",
    [Machine.OPCODES.INC]       = "INC",
    [Machine.OPCODES.RETURN]    = "RETURN",
    [Machine.OPCODES.JMP]       = "JMP",
    [Machine.OPCODES.B]         = "B",
    [Machine.OPCODES.BZ]        = "BZ",
    [Machine.OPCODES.BNZ]       = "BNZ",
    [Machine.OPCODES.BZP]       = "BZP",
    [Machine.OPCODES.BNZP]      = "BNZP",
    [Machine.OPCODES.NEWARR]    = "NEWARR",
    [Machine.OPCODES.GETARR]    = "GETARR",
    [Machine.OPCODES.SETARR]    = "SETARR",
    [Machine.OPCODES.SETARRP]   = "SETARRP",
    [Machine.OPCODES.HALT]      = "HALT",
    [Machine.OPCODES.PRINT]     = "PRINT",
}

Machine.OPCODES.make = function (variant, payload)
    local opcode = variant << Machine.OPCODES.VARIANT_BIT
    if payload ~= nil then
        opcode = opcode | payload
    end

    return opcode
end

local utils = {}

function utils.printStep(pc, op, operand, tos, stacksize)
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
    
    stacksize = stacksize and tostring(stacksize) or ""

    print(string.format("%08x: %-9s %10s %21s %10s", pc, op_name, operand_string, tos_string, stacksize))
end

function utils.printHeader()
    local hdr = string.format("%-9s %-9s %10s %21s %10s", "Address", "Operation", "Operand", "TOS", "Stack Size")
    print(hdr)
    print(string.rep('-', string.len(hdr) + 1))
end


function utils.printArray(array)
    local parts = {}
    for i = 1,array.size do
        local e = array[i]
        if type(e) == "nil" then
            table.insert(parts, "")
        elseif type(e) == "number" then
            table.insert(parts, tostring(e))
        elseif type(e) == "table" then
            table.insert(parts, utils.printArray(e))
        else
            table.insert(parts, e)
        end
    end
    return "{" .. table.concat(parts, ",") .. "}"
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
    local op_variant = op >> Machine.OPCODES.VARIANT_BIT

    local binop_fn = Machine.OPCODES.BINOP_LOOKUP[op_variant]
    local unaryop_fn = Machine.OPCODES.UNARYOP_LOOKUP[op_variant]

    -- Values used for optional trace step
    local pc = self.pc_
    local operand = nil

    if op_variant == Machine.OPCODES.HALT then
        -- Do nothing!
    elseif op_variant == Machine.OPCODES.RETURN then
        -- For now do nothing.
    elseif op_variant == Machine.OPCODES.JMP then
        operand = self.memory_[self.pc_ + 1]
        self.pc_ = operand
    elseif op_variant == Machine.OPCODES.B then
        operand = (op & 0xffffffff) - 0x7fffffff
        self.pc_ = self.pc_ + operand
    elseif op_variant == Machine.OPCODES.BZ then
        operand = (op & 0xffffffff) - 0x7fffffff
        local tos_0 = self.stack_:pop()
        if tos_0 == 0 then
            self.pc_ = self.pc_ + operand
        else
            self.pc_ = self.pc_ + 1
        end
    elseif op_variant == Machine.OPCODES.BNZ then
        operand = (op & 0xffffffff) - 0x7fffffff
        local tos_0 = self.stack_:pop()
        if tos_0 ~= 0 then
            self.pc_ = self.pc_ + operand
        else
            self.pc_ = self.pc_ + 1
        end
    elseif op_variant == Machine.OPCODES.BZP then
        operand = (op & 0xffffffff) - 0x7fffffff
        local tos_0 = self.stack_:peek()
        if tos_0 == 0 then
            self.pc_ = self.pc_ + operand
        else
            self.stack_:pop()
            self.pc_ = self.pc_ + 1
        end
    elseif op_variant == Machine.OPCODES.BNZP then
        operand = (op & 0xffffffff) - 0x7fffffff
        local tos_0 = self.stack_:peek()
        if tos_0 ~= 0 then
            self.pc_ = self.pc_ + operand
        else
            self.stack_:pop()
            self.pc_ = self.pc_ + 1
        end
    elseif op_variant == Machine.OPCODES.PUSH then
        operand = self.memory_[self.pc_ + 1]
        self.stack_:push(operand)
        self.pc_ = self.pc_ + 2
    elseif op_variant == Machine.OPCODES.LOAD then
        operand = self.memory_[self.pc_ + 1]
        self.stack_:push(self.memory_[operand])
        self.pc_ = self.pc_ + 2
    elseif op_variant == Machine.OPCODES.STORE then
        operand = self.memory_[self.pc_ + 1]
        self.memory_[operand] = self.stack_:pop()
        self.pc_ = self.pc_ + 2
    elseif op_variant == Machine.OPCODES.EXCH then
        local tos_0 = self.stack_:pop()
        local tos_1 = self.stack_:pop()
        self.stack_:push(tos_0)
        self.stack_:push(tos_1)
        self.pc_ = self.pc_ + 1
    elseif op_variant == Machine.OPCODES.POP then
        self.stack_:pop()
        self.pc_ = self.pc_ + 1
    elseif op_variant == Machine.OPCODES.DUP then
        local tos_0 = self.stack_:peek()
        self.stack_:push(tos_0)
        self.pc_ = self.pc_ + 1
    elseif op_variant == Machine.OPCODES.NEWARR then
        local tos_0 = self.stack_:pop()
        self.stack_:push({size = tos_0})
        self.pc_ = self.pc_ + 1
    elseif op_variant == Machine.OPCODES.GETARR then
        local tos_0 = self.stack_:pop() -- index
        local tos_1 = self.stack_:pop() -- array
        assert(type(tos_1) == "table", make_error(ERROR_CODES.TYPE_MISMATCH, {message = "Expected array"}))
        assert(1 <= tos_0 and tos_0 <= tos_1.size, make_error(ERROR_CODES.INDEX_OUT_OF_RANGE, {message = "Index out of range"}))

        self.stack_:push(tos_1[tos_0])
        self.pc_ = self.pc_ + 1
    elseif op_variant == Machine.OPCODES.SETARR then
        local tos_0 = self.stack_:pop() -- value
        local tos_1 = self.stack_:pop() -- index
        local tos_2 = self.stack_:pop() -- array
        assert(type(tos_2) == "table", make_error(ERROR_CODES.TYPE_MISMATCH, {message = "Expected array"}))
        assert(1 <= tos_1 and tos_1 <= tos_2.size, make_error(ERROR_CODES.INDEX_OUT_OF_RANGE, {message = "Index out of range"}))

        tos_2[tos_1] = tos_0

        self.pc_ = self.pc_ + 1
    elseif op_variant == Machine.OPCODES.SETARRP then
        local tos_0 = self.stack_:pop()  -- value
        local tos_1 = self.stack_:peek() -- index
        local tos_2 = self.stack_:peek(1) -- array
        assert(type(tos_2) == "table", make_error(ERROR_CODES.TYPE_MISMATCH, {message = "Expected array"}))
        assert(1 <= tos_1 and tos_1 <= tos_2.size, make_error(ERROR_CODES.INDEX_OUT_OF_RANGE, {message = "Index out of range"}))

        tos_2[tos_1] = tos_0

        self.pc_ = self.pc_ + 1
    elseif op_variant == Machine.OPCODES.PRINT then
        local tos_0 = self.stack_:pop()
        local out   = ""
        if type(tos_0) == "number" then
            out = tostring(tos_0)
        elseif type(tos_0) == "table" then
            out = utils.printArray(tos_0)
        else
            out = tos_0
        end
        
        self.io_:write(out .. "\n")
        self.pc_ = self.pc_ + 1
    elseif op_variant == Machine.OPCODES.DEC then
        local tos_0 = self.stack_:pop()
        self.stack_:push(tos_0 - 1) 
        self.pc_ = self.pc_ + 1
    elseif op_variant == Machine.OPCODES.INC then
        local tos_0 = self.stack_:pop()
        self.stack_:push(tos_0 + 1) 
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
        utils.printStep(pc, op_variant, operand, self:tos(), #self.stack_)
    end
end


function Machine:isHalted ()
    local op = self.memory_[self.pc_]
    local op_variant = op and op >> Machine.OPCODES.VARIANT_BIT or 0
    if self.pc_ > #self.memory_ then
        return true
    elseif op_variant == Machine.OPCODES.HALT then
        return true
    elseif op_variant == Machine.OPCODES.RETURN then
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

