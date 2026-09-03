// Driver for MotoGo (Flutter web build), used to launch + screenshot the
// app from a script instead of a human clicking through it.
//
// MotoGo（Flutter Web版）を操作するドライバー。人手ではなくスクリプトから
// 起動・操作・スクリーンショットを行う。
//
// Flutter web renders the whole UI to a single <canvas> (CanvasKit
// renderer) — there is no DOM tree of buttons/inputs to select by text or
// role, so this driver clicks by pixel coordinate against a fixed
// 480x900 viewport. If the UI layout changes, the coordinates below need
// updating (take a screenshot first, measure, then adjust).
//
// Flutter webはUI全体を1枚の<canvas>に描画する（CanvasKitレンダラー）ため、
// テキストやroleで選択できるDOM要素が無い。480x900の固定ビューポートに対する
// ピクセル座標でクリックする方式を取っている。UIレイアウトが変わったら、
// 下記の座標も更新が必要（まずスクリーンショットを撮って位置を測ってから直す）。
//
// Usage:
//   node driver.mjs <command> [args...]
//
// Commands:
//   serve                              Start the static server for build/web (blocks).
//   screenshot <url> <outPath>         Load a URL, wait for the canvas to paint, screenshot.
//   click <url> <x> <y> <outPath>      Load a URL, click at (x,y), screenshot the result.
//
// See SKILL.md for the full end-to-end sequence (build -> serve -> drive).

import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
// .claude/skills/run-msmototaxi/driver.mjs -> project root is 3 levels up.
const projectRoot = path.resolve(__dirname, '../../..');
const webRoot = path.join(projectRoot, 'build', 'web');

const MIME = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.css': 'text/css',
};

function serve(port = 8765) {
  if (!fs.existsSync(webRoot)) {
    console.error(
      `${webRoot} not found. Run "flutter build web -t lib/main_passenger.dart" first.`,
    );
    process.exit(1);
  }
  const server = http.createServer((req, res) => {
    const reqPath = decodeURIComponent(req.url.split('?')[0]);
    const filePath = path.join(webRoot, reqPath === '/' ? 'index.html' : reqPath);
    fs.readFile(filePath, (err, data) => {
      if (err) {
        res.writeHead(404);
        res.end('not found');
        return;
      }
      res.writeHead(200, {
        'Content-Type': MIME[path.extname(filePath)] || 'application/octet-stream',
      });
      res.end(data);
    });
  });
  server.listen(port, () => console.log(`Serving ${webRoot} on http://localhost:${port}`));
}

async function withPage(fn) {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 480, height: 900 } });
  page.on('pageerror', (err) => console.log('[pageerror]', err.message));
  try {
    await fn(page);
  } finally {
    await browser.close();
  }
}

async function loadAndWait(page, url) {
  await page.goto(url, { waitUntil: 'networkidle' });
  // Flutter web has no reliable "app ready" DOM event to hook from the
  // outside; a fixed settle delay after networkidle has been reliable here.
  // Flutter webは外部から検知できる「アプリ起動完了」イベントが無いため、
  // networkidle後の固定待機が実用上安定している。
  await page.waitForTimeout(3000);
}

async function screenshot(url, outPath) {
  await withPage(async (page) => {
    await loadAndWait(page, url);
    await page.screenshot({ path: outPath });
    console.log('Saved screenshot to', outPath);
  });
}

async function click(url, x, y, outPath) {
  await withPage(async (page) => {
    await loadAndWait(page, url);
    await page.mouse.click(Number(x), Number(y));
    await page.waitForTimeout(1500);
    await page.screenshot({ path: outPath });
    console.log('Saved screenshot to', outPath);
  });
}

const [, , cmd, ...args] = process.argv;

switch (cmd) {
  case 'serve':
    serve(Number(args[0]) || 8765);
    break;
  case 'screenshot':
    await screenshot(args[0], args[1]);
    break;
  case 'click':
    await click(args[0], args[1], args[2], args[3]);
    break;
  default:
    console.error('Usage: node driver.mjs <serve|screenshot|click> [args...]');
    process.exit(1);
}
