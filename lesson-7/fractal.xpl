
function range(start, stop, step)
{
    current = start;
    return lambda ()
    {
        should_stop = 0;
        if (start >= stop and step < 0)
        {
            should_stop = current < stop;
        }
        else
        {
            should_stop = current > stop;
        }

        if (should_stop)
        {
            return null;
        }
        else
        {
            temp = current;
            current = current + step;
            return temp;
        }
    };
}

function decimal_width(n)
{
    if (n == 0)
    {
        return 1;
    }

    counter = 0;
    while (n > 0)
    {
        n = (n - (n % 10)) / 10;
        counter = counter + 1;
    }

    return counter;
}

digits = {
    0x30, 0x31, 0x32, 0x33, 0x34,
    0x35, 0x36, 0x37, 0x38, 0x39
};

function digit_to_ascii(d)
{
    return digits[d + 1];
}

function integer_to_ascii(x)
{
    width = decimal_width(x);
    str   = new[width];
    for i in range(width, 1, -1)
    {
        rem = x % 10;
        str[i] = digit_to_ascii(rem);
        x = (x - rem) / 10;    
    }
    return str;
}


function write_pbm(img)
{
    height  = len(img);
    width   = len(img[1]);

    # write header
    # P5\n
    write(stdout, {0x50, 0x35, 0x0a});
    # <width><space>
    write(stdout, integer_to_ascii(width));
    write(stdout, 0x20);
    # <height>\n
    write(stdout, integer_to_ascii(height));
    write(stdout, 0x0a);
    # <maxval>\n
    write(stdout, integer_to_ascii(255));
    write(stdout, 0x0a);

    for row in range(1, height, 1)
    {
        write(stdout, img[row]);
    }
}

function norm2(z)
{
    return z[1]*z[1] + z[2]*z[2];
}

function mandelbrot_score(c)
{
    max_iterations = 255;
    iteration = 0;
    z = {0.0, 0.0};
    while (iteration < max_iterations and norm2(z) < 4)
    {
        re_temp = z[1] * z[1] - z[2] * z[2] + c[1];
        z[2] = 2 * z[1] * z[2] + c[2];
        z[1] = re_temp;
        iteration = iteration + 1;
    }

    return iteration;
}


function mandelbrot()
{
    height = 480;
    width  = 640;
    
    re_range = {-2.00, 0.47};
    im_range = {-0.92625, 0.92625};

    img = new[height][width];
    
    for row in range(1, height, 1)
    {
        write(stderr, integer_to_ascii(row));
        write(stderr, 0x0d);
        for col in range(1, width, 1)
        {
            re = re_range[1] + (re_range[2] - re_range[1]) * ((col - 1) / width);
            im = im_range[1] + (im_range[2] - im_range[1]) * ((row - 1) / height);
            img[row][col] = mandelbrot_score({re, im});
        }
    }

    return img;
}

function main()
{
    img = mandelbrot();
    write_pbm(img);
}


main()
