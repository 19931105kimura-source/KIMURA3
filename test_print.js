// test_textsize.js
// 実行方法: node test_textsize.js
// ※ サーバーと同じディレクトリに置いて実行してください

const { enqueuePrint } = require("./src/printer");

const PAPER_BYTES = 48;

// 横n倍時の論理幅
function rowBytes(wMul) {
  return Math.floor(PAPER_BYTES / wMul) - 1;
}

// 文字サイズコマンドを動的に生成
function cmdWidth(n)  { return Buffer.from([0x1b, 0x57, n]); } // ESC W n
function cmdHeight(n) { return Buffer.from([0x1b, 0x68, n]); } // ESC h n
const cmdWidthOff  = Buffer.from([0x1b, 0x57, 0x00]);
const cmdHeightOff = Buffer.from([0x1b, 0x68, 0x00]);
const emphasisOn   = Buffer.from([0x1b, 0x45, 0x01]);
const emphasisOff  = Buffer.from([0x1b, 0x45, 0x00]);
const LF           = Buffer.from([0x0a]);

// サイズ指定でテキストを出力するバッファを作る
function makeSizeLine(wMul, hMul, text) {
  const encoded = require("iconv-lite").encode(text, "cp932");
  return Buffer.concat([
    emphasisOn,
    cmdWidth(wMul - 1),
    cmdHeight(hMul - 1),
    encoded,
    LF,
    cmdWidthOff,
    cmdHeightOff,
    emphasisOff,
  ]);
}

// ラベル行（通常サイズ）
function makeLabel(text) {
  const iconv = require("iconv-lite");
  return Buffer.concat([
    iconv.encode(`--- ${text} ---\n`, "cp932"),
  ]);
}

// セパレータ
const SEP = Buffer.from("----------------------------------------\n", "ascii");

// 金額サンプル
const AMOUNT = "¥1,200,345";

const buffers = [];

buffers.push(SEP);
buffers.push(makeLabel("横1倍 縦1倍（通常）"));
buffers.push(makeSizeLine(1, 1, `合計  ${AMOUNT}`));
buffers.push(SEP);

buffers.push(makeLabel("横2倍 縦1倍"));
buffers.push(makeSizeLine(2, 1, `合計  ${AMOUNT}`));
buffers.push(SEP);

buffers.push(makeLabel("横1倍 縦2倍"));
buffers.push(makeSizeLine(1, 2, `合計  ${AMOUNT}`));
buffers.push(SEP);

buffers.push(makeLabel("横2倍 縦2倍（現在）"));
buffers.push(makeSizeLine(2, 2, `合計  ${AMOUNT}`));
buffers.push(SEP);

buffers.push(makeLabel("横2倍 縦3倍"));
buffers.push(makeSizeLine(2, 3, `合計  ${AMOUNT}`));
buffers.push(SEP);

buffers.push(makeLabel("横3倍 縦2倍"));
buffers.push(makeSizeLine(3, 2, `合計  ${AMOUNT}`));
buffers.push(SEP);

buffers.push(makeLabel("横3倍 縦3倍"));
buffers.push(makeSizeLine(3, 3, `合計  ${AMOUNT}`));
buffers.push(SEP);

buffers.push(makeLabel("横4倍 縦4倍（最大）"));
buffers.push(makeSizeLine(4, 4, `合計  ${AMOUNT}`));
buffers.push(SEP);

// 生バッファを直接送るためのセグメントとして渡す
const rawBuf = Buffer.concat(buffers);

// enqueuePrint は segments を受け取るので、
// rawバッファを text セグメントとして直接渡す抜け道を使う
const { buildRawPrintData } = require("./src/printer");
const net = require("net");

const host = process.env.PRINTER_HOST;
const port = Number(process.env.PRINTER_PORT || 9100);

if (!host) {
  console.error("PRINTER_HOST が設定されていません");
  console.error("例: export PRINTER_HOST=192.168.x.x");
  process.exit(1);
}

// init + rawBuf + feed + cut を直接送信
const { exec } = require("child_process");
const initBuf  = Buffer.from([0x1b, 0x40]);
const feedBuf  = Buffer.from([0x1b, 0x64, 0x03]);
const cutBuf   = Buffer.from([0x1d, 0x56, 0x01]);
const endLF    = Buffer.from([0x0a, 0x0a, 0x0a]);

const printData = Buffer.concat([initBuf, rawBuf, endLF, feedBuf, cutBuf]);

const socket = net.createConnection(port, host);

socket.on("connect", () => {
  console.log("プリンター接続OK、送信中...");
  socket.write(printData, () => {
    setTimeout(() => {
      socket.end();
      console.log("テスト印刷完了");
      process.exit(0);
    }, 300);
  });
});

socket.on("error", (err) => {
  console.error("接続エラー:", err.message);
  process.exit(1);
});