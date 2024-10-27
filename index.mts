interface Wasm {
    wasm: WebAssembly.WebAssemblyInstantiatedSource
    memory: WebAssembly.Memory,
    _initialize: () => void;
    init: () => void;
    render: (dt: number) => void;
    spin: () => void;
}

class Game {
    canvas: CanvasRenderingContext2D
    wasm: Wasm
    prevTs: number

    constructor(canvas: CanvasRenderingContext2D, wasm: Wasm) {
        this.canvas = canvas
        this.wasm = wasm
        this.prevTs = 0
    }
}

let game: Game;

function initWasm(wasm: WebAssembly.WebAssemblyInstantiatedSource): Wasm {
    return {
        wasm,
        memory: wasm.instance.exports.memory as WebAssembly.Memory,
        _initialize: wasm.instance.exports._initialize as () => void,
        render: wasm.instance.exports.render as (dt: number) => void,
        spin: wasm.instance.exports.spin as () => void,
        init: wasm.instance.exports.init as () => void,
    }
}

// extern
function render_symbol(x: number, y: number, width: number, height: number, sym: number, imagePtr: number) {
    // game.canvas.fillRect(x, y, width, height)

    const bytes = new Uint8ClampedArray(game.wasm.memory.buffer, imagePtr, width * height * 4)
    const data = new ImageData(bytes, width, height);
    game.canvas.putImageData(data, x, y)
}

async function init() {
    const wasm = initWasm(await WebAssembly.instantiateStreaming(fetch('main.wasm'), {
        "env": {
            seed: () => performance.now(),
            render_symbol
        }
    }))

    wasm._initialize();
    wasm.memory.grow(100);
    const app = document.getElementById("app") as HTMLCanvasElement;
    const ctx = app.getContext("2d");
    if (!ctx) {
        throw new Error("Ctx not found");
    }

    game = new Game(ctx, wasm)

    const button = document.getElementById("spin");
    button?.addEventListener("click", () => {
        game.wasm.spin()
    })

    game.wasm.memory.grow(30)
    game.wasm.init();
    game.wasm.spin()
    window.requestAnimationFrame(draw)
}

function draw(ts: number) {
    const dt = (ts - game.prevTs) * 0.001 // ms
    game.prevTs = ts
    game.canvas.clearRect(0, 0, 600, 600)
    game.wasm.render(dt)
    window.requestAnimationFrame(draw)
}

init();