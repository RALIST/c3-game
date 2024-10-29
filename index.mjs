class Game {
    canvasCtx;
    wasm;
    prevTs;
    constructor(canvas, wasm) {
        this.canvasCtx = canvas;
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
async function render_window(ptr) {
    const width = window.innerWidth;
    const height = window.innerHeight;
    const bytes = new Uint8ClampedArray(game.wasm.memory.buffer, ptr, width * height * 4);
    const data = new ImageData(bytes, width, height);
    const bmp = await createImageBitmap(data);
    game.canvasCtx.drawImage(bmp, 0, 0);
}
function render_win(symbol, amount, x, y) {
    game.canvasCtx.fillStyle = "white";
    game.canvasCtx.font = "32px serif";
    game.canvasCtx.fillText(`SYMBOL: ${symbol} WIN: ${amount}`, x, y);
}
function render_balance(amount, x, y) {
    game.canvasCtx.fillStyle = "white";
    game.canvasCtx.font = "32px serif";
    game.canvasCtx.fillText(`BALANCE: ${amount}`, x, y);
}
async function init() {
    const wasm = initWasm(await WebAssembly.instantiateStreaming(fetch('main.wasm'), {
        "env": {
            seed: () => performance.now(),
            render_window,
            render_win,
            render_balance
        }
    }));
    wasm._initialize();
    wasm.memory.grow(100);
    const app = document.getElementById("app");
    const ctx = app.getContext("2d", { alpha: false });
    if (!ctx) {
        throw new Error("Ctx not found");
    }
    app.width = window.innerWidth;
    app.height = window.innerHeight;
    game = new Game(ctx, wasm);
    const button = document.getElementById("spin");
    button?.addEventListener("click", () => {
        game.wasm.spin();
    });
    document.addEventListener("keydown", (event) => {
        if (event.key == " " || event.code == "Space" || event.keyCode == 32) {
            game.wasm.spin();
            event.preventDefault();
        }
    });
    game.wasm.memory.grow(100);
    game.wasm.init(window.innerWidth, window.innerHeight);
    game.wasm.spin();
    window.requestAnimationFrame(draw);
}
let frames = 0;
let op = 0.01;
function draw(ts) {
    const dt = (ts - game.prevTs) * 0.001; // ms
    game.prevTs = ts;
    game.canvasCtx.clearRect(0, 0, window.innerWidth, window.innerHeight);
    game.wasm.render(dt);
    game.canvasCtx.fillStyle = `rgba(255, 255, 255, ${frames})`;
    frames += op;
    if (frames > 1 || frames <= 0) {
        op = -op;
    }
    game.canvasCtx.font = "32px serif";
    game.canvasCtx.fillText("Press SPACE to spin", window.innerWidth / 3, window.innerHeight / 5);
    window.requestAnimationFrame(draw);
}
init();
export {};
