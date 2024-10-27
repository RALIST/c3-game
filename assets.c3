module assets;
import std::io;
import std::collections::list;

struct Asset {
    String filename;
    usz offset;
    usz width;
    usz height;
    usz size;
}

def Assets = List(<Asset>);
extern fn char *stbi_load(ZString filename, int *x, int *y, int *comp, int req_comp);

