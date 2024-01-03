# factorial of 9
n = 9;
r = 1;
while n > 0 
{
    r = r * n;
    n = n - 1;
};
@ r;

# square root of 5
x = 5;
r = 5 / 2;
e = 0.000000000001;
while r != 0 and (x / r - r) * (x / r - r) > e
{
    #{
    # Print the progression of the sqrt algo.
    #}
    @ r;
    r = (x / r + r) / 2;
}
@ r;

# Some if-statement tests.
n = 5;
m = 0;
while n > 0 or m
{
    if n == 3
    {
        @ 10;
    }
    elseif n == 2
    {
        @ 9;
    }
    elseif n == 1
    {
        @ 8;
    }
    else
    {
        @ n;
    }
    n = n - 1;

    if n == 0
    {
        m = 1;
    }

    if n < -2
    {
        m = 0;
    }
};


# Test break statement
n = 9;
while n > 0
{
    @ n;
    if n == 6
    {
        # break out of outer loop
        break;
    }

    m = n;
    while m > 0
    {
        if m < 5
        {
            # break out of inner loop.
            break; 
        };
        @ m;
        m = m - 1;
    }

    n = n - 1;
}
