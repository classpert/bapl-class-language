Stack = {}
Stack.__index = Stack

function Stack:new ()
    local stack = {n_=0; data_={}}
    setmetatable(stack, Stack)
    return stack
end

function Stack:push (e)
    table.insert(self.data_, e)
    self.n_ = self.n_ + 1
    return self
end

function Stack:pop ()
    if (self.n_ < 1) then
        return nil
    end
    local e = table.remove(self.data_)
    self.n_ = self.n_ - 1
    return e
end

function Stack:peek (offset)
    local offset = offset or 0
    return self.data_[self.n_ - offset]
end

function Stack:__len ()
    return self.n_
end

function Stack:__tostring ()
    if self.n_ == 0 then
        return "{}"
    elseif self.n_ == 1 then
        return "{" .. self.data_[1] .. "}"
    else
        local parts = {}
        for i = (self.n_ - 1), 1, -1 do
            table.insert(parts, self.data_[i])
        end
        return "{" .. self.data_[self.n_] .. "| " .. table.concat(parts, ", ") .. "}"
    end
end



return Stack
