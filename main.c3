import std::io;
import std::math;
import assets;

$exec("./packer");

const SYMBOLS = int[*]{0,1,2,3,4,5,6,7,8,9,10};
const REEL = int[*]{0,1,2,3,4,5,6,7,8,9,10};
const COLUMNS = 5;
const ROWS = 5;
const GRID = COLUMNS * ROWS;
const SCREEN_WIDTH = 600;
const SCREEN_HEIGHT = 600;
const PADDING = 5;
const MAX_VELOCITY = 20;
const SYMBOL_POOL_CAPACITY = 20;

def Screen = Symbol[GRID];
def Color = char[<4>];
def Vector2 = int[<2>];

enum State {
    READY,
    PLAYING,
}

State state;

struct Window {
    int width, height;
    Color* pixels;
}

Window window;

struct Outcome {
    Screen screen;
    int win;
}

Outcome outcome = {
    .screen = {},
    .win = 0 
};

struct Image {
    Vector2 size;
    Color* pixels;
}

struct Symbol {
    Image image;
    Vector2 position;
    Vector2 currentPosition;
    Vector2 velocity;
    int sym;
    Color color;
}

struct SymbolPool {
    Symbol*[SYMBOLS.len] items;
}

SymbolPool symbol_pool;

fn void SymbolPool.put(&self, Symbol* symbol) {
    symbol.position = {};
    symbol.velocity = {};
    self.items[symbol.sym] = symbol;
}

fn Symbol* SymbolPool.get(&self, int sym) {
    return self.items[sym];
}

fn Screen generate_screen(Random random) {
    Screen* screen = mem::new_aligned(Screen);

    for (int i=0; i<GRID; i++) {
        int rand = random.next_short() % REEL.len;
        int sym = REEL[rand];

        Symbol symbol = *symbol_pool.get(sym);

        int colIndex = i % COLUMNS;
        int rowIndex = i / COLUMNS;
        int paddingX = window.width/100;
        int paddingY = window.height/100;
        symbol.position.x = colIndex * (window.width/ 3 / COLUMNS + paddingX) + window.width/3;
        symbol.position.y = rowIndex * (window.height / 2 / ROWS + paddingY) + window.height/4;

        symbol.velocity = {0, MAX_VELOCITY - colIndex};
        symbol.currentPosition = {symbol.position.x, 0};
        screen[0][i] = symbol;
    }

    return *screen;
}

fn int check_win(Screen) {
    return 199;
}

extern fn void render_symbol(Vector2, Vector2, int, Color*);
extern fn void render_win(int, int, int);
extern fn void render_spin_button(int, int, int, int);
extern fn void render_window(Color*);
extern fn void log(String);

char[] frame = $embed("assets/frame.png");

fn void render(int dt) @extern("render") @wasm @if(env::WASM_NOLIBC) {
    window.pixels = mem::calloc(Color.sizeof*window.width*window.height);
    defer mem::free(window.pixels);

    Color* frame_pixels = (Color*)&frame[0];
    for(int i = 0; i < frame_pixels.len; i++) {
        window.pixels[i] = frame_pixels[i];
    }

    foreach(int i, &symbol: outcome.screen) {
        if (symbol.currentPosition.y < symbol.position.y) {
            symbol.currentPosition.y += symbol.velocity.y;
        } else {
            symbol.currentPosition.y = symbol.position.y;
            state = READY;
        }

        if (symbol.currentPosition.y < window.height/4) {
            continue;
        }

        Color* pixels = symbol.image.pixels;
        for(int x = 0; x < symbol.image.size.x; x++) {
            for (int y = 0; y < symbol.image.size.y; y++) {
                int destP = (symbol.currentPosition.y + y) * window.width + symbol.currentPosition.x + x;
                int srcP = y*symbol.image.size.x+x;
                window.pixels[destP] = pixels[srcP];
            }
        }
    }
    
    render_window(window.pixels);

}

extern fn int seed() @extern("seed");
fn void spin() @extern("spin") @wasm @if(env::WASM_NOLIBC) {
    if (state != PLAYING) {
        Lcg32Random rand;
        random::seed(&&rand, seed());
        outcome.screen = generate_screen(&&rand);
        outcome.win = check_win(outcome.screen);
        state = PLAYING;
    }
}

fn void init(int width, int height) @extern("init") @wasm @if(env::WASM_NOLIBC) {
    window.width = width;
    window.height = height;

    for(int i=0;i<SYMBOLS.len;i++) {
        int sym = SYMBOLS[i];

        Asset asset = assets[i];
        Image image = {
            .size = {asset.width, asset.height},
            .pixels = (Color*)&pack[asset.offset]
        };

        Symbol* symbol = mem::new(Symbol);
        symbol.image = image;
        symbol.sym = i;

        symbol_pool.put(symbol);
    }

    state = READY;
}

fn int main() @if(!env::WASM_NOLIBC) {
    Color* frame_pixels = (Color*)&frame[0];
    io::printn(*frame_pixels);
    
    return 0;
}