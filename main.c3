import std::io;
import std::math;
import assets;

$exec("./packer");

const SYMBOLS = int[*]{0,1,2,3,4,5,6,7,8,9,10};
const REEL = int[*]{0,1,2,3,4,5,6,7,8,9,10,1,4,5,6,7,8,3,4,2,2,5,3,2,2,2,1,0,0,4,3,4,1,1,1,1,1,1,1,1,1,1,1,1,1};
const COLUMNS = 5;
const ROWS = 5;
const GRID = COLUMNS * ROWS;
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

struct Win {
    int symbol;
    int[] indexes;
    int payout;
}

struct Outcome {
    Screen screen;
    int win;
    Win[] wins;
    int wins_len;
}

Outcome outcome;

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

fn void generate_screen(Random random) {
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

    outcome.screen = *screen;
}

const PAYTABLE = int[<4>][]{
    {10, 50, 200, 3000},
    {10, 50, 200, 3000},
    {10, 50, 200, 3000},
    {10, 50, 200, 3000},
    {10, 50, 200, 3000},
    {10, 50, 200, 3000},
    {10, 50, 200, 3000},
    {10, 50, 200, 3000},
    {10, 50, 200, 3000},
    {10, 50, 200, 3000},
    {10, 50, 200, 3000},
};
const WINLINES = int[][]{
    {1, 1, 1, 1, 1},
    {0, 0, 0, 0, 0},
    {2, 2, 2, 2, 2},
    {3, 3, 3, 3, 3},
    {4, 4, 4, 4, 4},
    {0, 1, 2, 1, 0},
    {2, 1, 0, 1, 2},
};

fn void check_win() {
    foreach(symbol: SYMBOLS) {
        foreach(int index, line: WINLINES) {
            int len;
            int[] indexes = mem::new_array(int, 5);

            for(int i = 0; i < line.len; i++) {
                int x = i;
                int y = line[i];
                int position = y*COLUMNS+x;
                if(outcome.screen[position].sym == symbol) {
                    indexes[len] = position;
                    len++;
                } else {
                   break;
                }
            }

            if (len >= 2) {
                outcome.wins[outcome.wins_len] = {.symbol = symbol, .indexes = indexes, .payout = PAYTABLE[symbol][len-2]};
                outcome.win += PAYTABLE[symbol][len-2];
                outcome.wins_len++;
            }
        
        }
    }
}

extern fn void render_win(int, int, int, int);
extern fn void render_spin_button(int, int, int, int);
extern fn void render_window(Color*);
extern fn void render_balance(int, int, int);

fn void reset_outcome() {
    if (&outcome.wins != null) {
        mem::free(outcome.wins);
        foreach(win: outcome.wins) {
            mem::free(win.indexes);
        }
    }

    outcome.screen = {};
    outcome.win = 0;
    outcome.wins = mem::new_array(Win, SYMBOLS.len);
    outcome.wins_len = 0;
}


int balance;

fn void render(int dt) @extern("render") @wasm @if(env::WASM_NOLIBC) {
    window.pixels = mem::calloc(Color.sizeof*window.width*window.height);
    defer mem::free(window.pixels);

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
        bool won_symbol = false;
        foreach(win: outcome.wins) {
            if (win.payout > 0 && win.symbol == symbol.sym) {
                for(int pos = 0; pos < win.indexes.len; pos++) {
                    if (win.indexes[pos] == i) {
                        won_symbol = true;
                    }
                }
            }
        }
        for(int x = 0; x < symbol.image.size.x; x++) {
            for (int y = 0; y < symbol.image.size.y; y++) {
                int destP = (symbol.currentPosition.y + y) * window.width + symbol.currentPosition.x + x;
                int srcP = y*symbol.image.size.x+x;
                window.pixels[destP] = pixels[srcP];

                if(won_symbol && pixels[srcP].a < 255) {
                    window.pixels[destP] = {255, 165, 0, 255};
                }
            }
        }
    }
    
    render_window(window.pixels);

    foreach(int i, win: outcome.wins) {
        if (win.payout > 0) {
            render_win(win.symbol, win.payout, 100, 150 + (i*30));
        }
    }
   
    render_balance(balance, 100, 100);
}

extern fn int seed() @extern("seed");
fn void spin() @extern("spin") @wasm @if(env::WASM_NOLIBC) {
    reset_outcome();
    if (balance != 0) {
        balance--;
    }

    if (state != PLAYING) {
        Lcg32Random rand;
        random::seed(&&rand, seed());
        generate_screen(&&rand);
        check_win();
        state = PLAYING;
    }

    balance += outcome.win;
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
    reset_outcome();
    state = READY;
}

fn int main() @if(!env::WASM_NOLIBC) {
    Color* frame_pixels = (Color*)&frame[0];
    io::printn(*frame_pixels);
    
    return 0;
}