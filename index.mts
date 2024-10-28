interface Wasm {
    wasm: WebAssembly.WebAssemblyInstantiatedSource
    memory: WebAssembly.Memory,
    _initialize: () => void;
    init: (width: number, height: number) => void;
    render: (dt: number) => void;
    spin: () => void;
}

class Game {
    canvasCtx: CanvasRenderingContext2D
    wasm: Wasm
    prevTs: number

    constructor(canvas: CanvasRenderingContext2D, wasm: Wasm) {
        this.canvasCtx = canvas
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
        init: wasm.instance.exports.init as (width: number, height: number) => void,
    }
}

async function render_window(ptr: number) {
    const width = window.innerWidth;
    const height = window.innerHeight;
    const bytes = new Uint8ClampedArray(game.wasm.memory.buffer, ptr, width * height * 4)
    const data = new ImageData(bytes, width, height);
    const bmp = await createImageBitmap(data);
    game.canvasCtx.imageSmoothingEnabled = true;
    game.canvasCtx.drawImage(bmp, 0, 0);
}

async function init() {
    const wasm = initWasm(await WebAssembly.instantiateStreaming(fetch('main.wasm'), {
        "env": {
            seed: () => performance.now(),
            render_window,
            log: console.log
        }
    }))

    wasm._initialize();
    wasm.memory.grow(100);
    const app = document.getElementById("app") as HTMLCanvasElement;
    const ctx = app.getContext("2d", { alpha: false });
    if (!ctx) {
        throw new Error("Ctx not found");
    }

    app.width = window.innerWidth
    app.height = window.innerHeight

    game = new Game(ctx, wasm)

    const button = document.getElementById("spin");
    button?.addEventListener("click", () => {
        game.wasm.spin()
    })

    document.addEventListener("keydown", (event) => {
        if (event.key == " " || event.code == "Space" || event.keyCode == 32) {
            game.wasm.spin()
            event.preventDefault();
        }
    })

    game.wasm.memory.grow(100)
    game.wasm.init(window.innerWidth, window.innerHeight);
    game.wasm.spin()
    window.requestAnimationFrame(draw)
}

function draw(ts: number) {
    const dt = (ts - game.prevTs) * 0.001 // ms
    game.prevTs = ts
    game.canvasCtx.clearRect(0, 0, window.innerWidth, window.innerHeight)
    game.wasm.render(dt)
    window.requestAnimationFrame(draw)
}

init();