
debug = {10}

fun generator init 
{
    start_value = init
    return fun ()
    {
        temp = start_value
        start_value = start_value + 1
        @ (debug[1] + start_value)
        return temp 
    }
}


g0 = generator 20

debug[1] = 15

g1 = generator 30

debug[1] = 20


@ g0 3 # prints 30 and then 20
@ g1 3 # prints 45 and then 30

#{ 
    Functions are objects (stored in a table) the table contains 

    A. storage for all 
        
        1. captured variables, 
        2. local variables

    B. code that operates on the storage.

    When we invoke `fun <identifier> <params> <block>` what actually happens is the following.
    A closure (storage) of all referenced parameters is created and added to the function-block-template.
    The function-block is then put on the stack.


    `fun <identifier> <params> <block>` is syntactic sugar for `<identifier> = fun <params> <block>`


    Tricky part: code generation.

    1. We need to scan the fun-node for free-parameters.
    2. Create a new code block and generate instructions for the code inside the <block>
    3. Issue instructions to push fun-block to stack (the fun-block will contain storage for free-params and locals).
    4. Issue instructions to push free-parameters onto stack (copy-by value).
    6. Issue CLOSURE instruction


    Note 1: Function Blocks / Closure blocks {tag = "closure", storage = storage, code = code}. "storage" is just an array and can be
    manipulated as such!

    Note 2: The start of a function should contain code to store stack variables into local variables for the formal
    params.

    Note 3: To find free params we can generate code for the function-block and disable the check for non-existing
    variables. Instead we record the "non-existing" variable as a free parameter. Then we check existance outside the
    code generation for the function. 

    Note 4: Perhaps we can relax the variable required to be defined condition and just create a variable containing 0
    or perhaps a `None` value.

#}
