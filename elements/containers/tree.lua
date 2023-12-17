Tree = {}
Tree.__index = Tree
-- Constructs a tree.
--
-- Note: A leaf node is constructed by calling Tree:new (node).
function Tree:new (node, ...)
    local children = {...}
    local tree = {node_ = node, children_ = children}
    setmetatable(tree, Tree)
    return tree
end

function Tree:isLeaf ()
    return #self.children_ == 0
end

function Tree:child (n)
    return self.children_[n]
end

function Tree:children ()
    return self.children_
end

function Tree:node ()
    return self.node_
end


return Tree
