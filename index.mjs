class Game {
    canvas;
    wasm;
    prevTs;
    constructor(canvas, wasm) {
        this.canvas = canvas;
        this.wasm = wasm;
        this.prevTs = 0;
    }
}
let game;
function initWasm(wasm) {
    return {
        wasm,
        memory: wasm.instance.exports.memory,
        _initialize: wasm.instance.exports._initialize,
        render: wasm.instance.exports.render,
        spin: wasm.instance.exports.spin,
        init: wasm.instance.exports.init,
    };
}
// extern
function render_symbol(x, y, width, height, sym, r, g, b, a) {
    game.canvas.fillStyle = `rgba(${r},${g},${b},${a})`;
    game.canvas.fillRect(x, y, width, height);
    game.canvas.fillStyle = "orange";
    game.canvas.font = "48px serif";
    game.canvas.fillText(sym.toString(), x + width / 2, y + height / 2);
}
async function init() {
    const wasm = initWasm(await WebAssembly.instantiateStreaming(fetch('main.wasm'), {
        "env": {
            seed: () => performance.now(),
            render_symbol
        }
    }));
    wasm._initialize();
    const app = document.getElementById("app");
    const ctx = app.getContext("2d");
    if (!ctx) {
        throw new Error("Ctx not found");
    }
    game = new Game(ctx, wasm);
    const button = document.getElementById("spin");
    button?.addEventListener("click", () => {
        game.wasm.spin();
    });
    game.wasm.memory.grow(30);
    game.wasm.init();
    // game.wasm.render(1)
    window.requestAnimationFrame(draw);
}
function draw(ts) {
    const dt = (ts - game.prevTs) * 0.001; // ms
    game.prevTs = ts;
    game.canvas.clearRect(0, 0, 600, 600);
    game.wasm.render(dt);
    window.requestAnimationFrame(draw);
}
init();
export {};
