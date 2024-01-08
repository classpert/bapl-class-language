width = 10;
height = 10;
cell = 3;

image = new [width][height][cell];

@ image;

w = 1;
while w <= width
{
    h = 1;
    while h <= height
    {
        # Note: cell is a reference to an array!
        cell = image[w][h];
        cell[1] = w;
        cell[2] = h;
        cell[3] = (w + h) / 2;

        h = h + 1;
    }

    w = w + 1;
}

@ image;

n = 10;
m = 7 * 7;
i = 8;
while n > 0
{
    switch n*n
    {
        case 100:
        {
            @ -1;
            # no fall through;
            break;
        }
        case 81:
        {
            @ -2;
            # fall through!
        }
        case i * i:
        {
            @ -3;
            break;
        }
        case m:
        {
            @ -4;
            break;
        }
        default:
        {
            @ -5;
        }
    }
    @ 0;
    @ n;
    if n < 3
    {
        break;
    }
    n = n - 1;
}

x = {1, 2, 3, 4};
@ x;

x = {1, {2, 3}, 4, width, height};
@ x;
