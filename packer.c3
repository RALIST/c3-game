module packer;
import std::io;
import std::io::file;
import std::collections::list;
import assets;

extern fn char *stbi_load(ZString filename, int *x, int *y, int *comp, int req_comp);
extern fn char *stbir_resize_uint8_srgb(char *ipixels, int iw, int ih, int is, int opixels, int ow, int oh, int os, int en);

const String[] IMAGE_FILES = {
    "cherry.png"
};

const SYMBOL_WIDTH = 100;
const SYMBOL_HEIGHT = 100;

fn int main() {
    Assets assets;
    DString pack;

    foreach(filename: IMAGE_FILES) {
        int x, y;
        int comp = 4;
        char *pixels = stbi_load((ZString)filename, &x, &y, null, comp);
        char *resized_pixels = stbir_resize_uint8_srgb(pixels, x, y, 0,
                              0, SYMBOL_WIDTH, SYMBOL_HEIGHT, 0, 4);
        int size = SYMBOL_WIDTH*SYMBOL_HEIGHT*comp;
        usz offset = pack.len();
        assets.push({filename, offset, SYMBOL_WIDTH, SYMBOL_HEIGHT, size});
        pack.append_chars((String)resized_pixels[0..size-1]);
        if (pixels == null) {
            io::printf("ERROR: could not load file %s\n", filename);
            return 1;
        }
    }

    io::printfn("assets::Asset[] assets = {");
    foreach (asset: assets) {
        io::printfn("    {\"%s\", %d, %d, %d, %d},", asset.filename, asset.offset, asset.width, asset.height, asset.size);
    }
    io::printfn("};");

    String pack_view = pack.str_view();
    io::printf("char[*] pack = {");
    for (int i = 0; i < pack_view.len; ++i) {
        io::printf("%d,", pack_view[i]);
    }
    io::printfn("};");

    return 0;
}