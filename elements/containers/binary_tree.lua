BinaryTree = {}
BinaryTree.__index = BinaryTree
BinaryTree.INORDER = 1
BinaryTree.PREORDER = 2
BinaryTree.POSTORDER = 3

-- Constructs a tree.
--
-- Note: A leaf node is constructed by calling BinaryTree:new (node).
function BinaryTree:new (node, left, right)
    local tree = {node_ = node, left_ = left, right_ = right}
    setmetatable(tree, BinaryTree)
    return tree
end

function BinaryTree:isLeaf ()
    return self.left_ == nil and self.right_ == nil
end

function BinaryTree:left ()
    return self.left_
end

function BinaryTree:right ()
    return self.right_
end

function BinaryTree:node ()
    return self.node_
end

function BinaryTree:traverse(order)
    local order = order or BinaryTree.INORDER
    local t = self
    local function traverse_internal (tree)
        if tree == nil then
            return
        elseif tree:isLeaf() then
            coroutine.yield(tree:node())
        elseif order == BinaryTree.INORDER then
            traverse_internal(tree:left())
            coroutine.yield(tree:node())
            traverse_internal(tree:right())
        elseif order == BinaryTree.PREORDER then
            coroutine.yield(tree:node())
            traverse_internal(tree:left())
            traverse_internal(tree:right())
        elseif order == BinaryTree.POSTORDER then
            traverse_internal(tree:left())
            traverse_internal(tree:right())
            coroutine.yield(tree:node())
        end
    end
    return coroutine.wrap(function () traverse_internal (t) end)
end


return BinaryTree
