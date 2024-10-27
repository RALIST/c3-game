import std::io;
import std::math;
import assets;

const SYMBOLS = int[*]{0,1,2,3,4,5,6,7,8,9,10};
const REEL = int[*]{0,1,2,3,4,5,6,7,8,9,10};
const COLUMNS = 5;
const ROWS = 5;
const GRID = COLUMNS * ROWS;
const SCREEN_WIDTH = 600;
const SCREEN_HEIGHT = 600;
const PADDING = 5;
const MAX_VELOCITY = 15;
const SYMBOL_POOL_CAPACITY = 20;

def Screen = Symbol[GRID];
def Color = char[<4>];
def Vector2 = int[<2>];

enum State {
    READY,
    PLAYING,
}

State state;

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

$exec("./packer");

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

        symbol.position.x = colIndex * (SCREEN_WIDTH / COLUMNS + PADDING);
        symbol.position.y = rowIndex * (SCREEN_HEIGHT / ROWS + PADDING);

        symbol.velocity = {0, MAX_VELOCITY - colIndex};
        symbol.currentPosition = {symbol.position.x, symbol.position.y - 2 * SCREEN_HEIGHT};
        screen[0][i] = symbol;
    }

    return *screen;
}

fn int check_win(Screen) {
    return 199;
}

extern fn void render_symbol(Vector2, Vector2, int, Color*);

fn void render(int dt) @extern("render") @wasm @if(env::WASM_NOLIBC) {
    foreach(int i, &symbol: outcome.screen) {
        if (symbol.currentPosition.y < symbol.position.y) {
            symbol.currentPosition.y += symbol.velocity.y;
        } else {
            symbol.currentPosition.y = symbol.position.y;
            state = READY;
        }

        render_symbol(symbol.currentPosition, symbol.image.size, symbol.sym, symbol.image.pixels);
    }
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

fn void init() @extern("init") @wasm @if(env::WASM_NOLIBC) {
    for(int i=0;i<SYMBOLS.len;i++) {
        int sym = SYMBOLS[i];

        Asset asset = assets[i%9];
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
    for(int i=0; i < assets.len; i++) {
        io::printfn("Asset: %d", assets[i].size);
    }
    
    return 0;
}