#!/usr/bin/env lua

require 'machine'
local compiler = require 'compiler'

local machine = Machine:new()
local trace = false
local input = io.stdin




-- Helpers

-- Evaluate a string representing an expression in our language. 
--
--
-- Note: For now we just compile an expression, run it through the virtual machine and return the the TOS. In future
--       implementations we'll make this more elaborate.
local function eval (str)
    status, data = pcall(compiler.compile, str)
    if not status then
        io.stderr:write(data.payload.message)
        return nil
    end
    machine:load(data)
    machine:setTrace(trace)
    machine:run()
    return machine:tos()
end



-- Read, Evaluate, Print, Loop
local function repl ()
    count = 0
    while true do
        -- print prompt
        io.stdout:write(string.format("%d > ", count))
        io.stdout:flush()

        local line = input:read("l")
        if line then
            local result = eval(line)
            result = result ~= nil and result or "nil"
            io.stdout:write(result, "\n")
        else
            break
        end
        count = count + 1
    end
end

local function execute ()
    local text = input:read("a")
    eval(text)
end

-- Parse command line arguments.
function parseArgs (arg)
    local pos = 1
    local result = {
        trace = false,
        input = io.stdin,
    }
    while pos <= #arg do
        if arg[pos] == "-t" or arg[pos] == "--trace" then
            result.trace = true
        elseif arg[pos] == "-l" or arg[pos] == "--load" then
            if (pos + 1 <= #arg) then
                result.input = assert(io.open(arg[pos + 1], "r"))
                pos = pos + 1
            else
                io.stderr:write("Expected filename after option -l!", "\n")
            end
        end
        pos = pos + 1
    end

    return result
end


-----------------------------------------------------------------

local result = parseArgs(arg)
trace = result.trace
input = result.input

if input == io.stdin then
    -- drop into line-by-line evaluating repl()
    repl()
else
    -- execute the program in file.
    execute()
end
