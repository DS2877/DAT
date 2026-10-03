// Renders the HUD / menu snapshots from scripts/ui-snapshot.luau to PNGs, at
// a phone-sized screen, using a small re-implementation of Roblox GUI
// layout (UDim2 sizing, anchor points, UIListLayout, UIGridLayout, padding,
// UIScale, size constraints, automatic size, scaled text, corners, strokes,
// gradients). Approximate, but faithful enough to judge spacing and style.
//
//   node scripts/preview/render-ui.mjs ui.json out_dir [width height]
//
// Fonts: put LuckiestGuy.woff2 and FredokaOne.woff2 in scripts/preview/fonts
// (Google Fonts) for the real look; otherwise a fallback font is used.

import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright-core";

const here = path.dirname(fileURLToPath(import.meta.url));
const [uiPath = "ui.json", outDir = "out", w = "844", h = "390"] = process.argv.slice(2);
const W = Number(w);
const H = Number(h);
const fontDir = process.env.FONT_DIR || path.join(here, "fonts");

const page = `<!doctype html><html><head><meta charset="utf-8"><style>
@font-face { font-family: 'Luckiest Guy'; src: url(/fonts/LuckiestGuy.woff2); }
@font-face { font-family: 'Fredoka One'; src: url(/fonts/FredokaOne.woff2); }
html, body { margin: 0; width: ${W}px; height: ${H}px; overflow: hidden; }
body { background: linear-gradient(180deg, #8fd3f4 0%, #bfe6f7 45%, #e9d4a0 46%, #f0dca8 100%); }
.n { position: absolute; box-sizing: border-box; }
.t { position: absolute; inset: 0; display: flex; white-space: pre; line-height: 1; }
.t.wrap { white-space: pre-wrap; word-break: keep-all; overflow-wrap: normal; }
</style></head><body><div id="screen" style="position:absolute;inset:0"></div>
<script>
const W = ${W}, H = ${H};
const MOD = new Set(["UICorner","UIStroke","UIGradient","UIPadding","UIListLayout","UIGridLayout","UIScale","UISizeConstraint","UITextSizeConstraint"]);
const FONTS = { LuckiestGuy: "'Luckiest Guy', 'Arial Black', sans-serif", FredokaOne: "'Fredoka One', 'Arial Rounded MT Bold', sans-serif" };
const arr = (x) => (Array.isArray(x) ? x : []);
const rgb = (c, a = 1) => c ? "rgba(" + Math.round(c[0]*255) + "," + Math.round(c[1]*255) + "," + Math.round(c[2]*255) + "," + a + ")" : "transparent";
const measurer = document.createElement("canvas").getContext("2d");
function fontCss(node, size) { return size + "px " + (FONTS[node.font] || "sans-serif"); }
function textWidth(node, text, size) { measurer.font = fontCss(node, size); return measurer.measureText(text).width; }
function wrapLines(node, text, size, maxW) {
	const out = [];
	for (const para of String(text).split("\\n")) {
		const words = para.split(" ");
		let line = "";
		for (const word of words) {
			const test = line ? line + " " + word : word;
			if (textWidth(node, test, size) <= maxW || !line) line = test;
			else { out.push(line); line = word; }
		}
		out.push(line);
	}
	return out;
}
function fits(node, size, bw, bh, wrap) {
	const lh = (node.lineHeight || 1) * size * 1.05;
	if (!wrap) return textWidth(node, node.text, size) <= bw + 0.5 && lh <= bh + 0.5 && !String(node.text).includes("\\n") || (String(node.text).split("\\n").every(l => textWidth(node, l, size) <= bw) && String(node.text).split("\\n").length * lh <= bh);
	const lines = wrapLines(node, node.text, size, bw);
	return lines.every(l => textWidth(node, l, size) <= bw + 0.5) && lines.length * lh <= bh + 0.5;
}
function scaledSize(node, bw, bh) {
	let lo = 1, hi = 100;
	const wrap = node.wrapped || node.textScaled;
	while (hi - lo > 0.5) { const mid = (lo + hi) / 2; if (fits(node, mid, bw, bh, wrap)) lo = mid; else hi = mid; }
	return lo;
}
const mods = (n) => { const m = {}; for (const c of arr(n.children)) if (MOD.has(c.class)) m[c.class] = c; return m; };
const kids = (n) => arr(n.children).filter(c => !MOD.has(c.class) && c.visible !== false);
const ud = (u, total) => u ? u[0] * total + u[1] : 0;

// Size of a node given its parent's content size (before layout positioning).
function sizeOf(n, pw, ph) {
	const m = mods(n);
	let w = ud([n.size[0], n.size[1]], pw), h = ud([n.size[2], n.size[3]], ph);
	const c = m.UISizeConstraint;
	if (c) {
		if (c.maxSize) { w = Math.min(w, c.maxSize[0]); h = Math.min(h, c.maxSize[1]); }
		if (c.minSize) { w = Math.max(w, c.minSize[0]); h = Math.max(h, c.minSize[1]); }
	}
	if ((n.autoSize === "Y" || n.autoSize === "XY") && (m.UIListLayout || m.UIGridLayout)) {
		const [cx, cy, cw, ch] = contentBox(n, w, h);
		const ext = layoutChildren(n, cx, cy, cw, ch).extent;
		h = Math.max(h, ext + cy + (h - ch - cy));
	}
	if (n.autoSize && n.autoSize !== "None" && n.text !== undefined) {
		const pad = m.UIPadding ? m.UIPadding.padding : null;
		const px = pad ? ud(pad[1], w) + ud(pad[3], w) : 0;
		const size = n.textScaled ? h * 0.8 : n.textSize;
		if (n.autoSize === "X" || n.autoSize === "XY") w = Math.max(w, textWidth(n, n.text, size) + px + 2);
	}
	return [Math.max(0, w), Math.max(0, h)];
}

function contentBox(n, w, h) {
	const m = mods(n);
	if (!m.UIPadding) return [0, 0, w, h];
	const [t, r, b, l] = m.UIPadding.padding;
	const top = ud(t, h), right = ud(r, w), bottom = ud(b, h), left = ud(l, w);
	return [left, top, w - left - right, h - top - bottom];
}

// Positions of children: [{node, x, y, w, h}] in the parent's coordinates.
function layoutChildren(n, cx, cy, cw, ch) {
	const m = mods(n);
	const list = kids(n);
	const out = [];
	if (m.UIListLayout) {
		const L = m.UIListLayout;
		const horizontal = L.direction === "Horizontal";
		const sorted = list.slice().sort((a, b) => (a.order || 0) - (b.order || 0));
		const gap = ud(L.padding, horizontal ? cw : ch);
		const sizes = sorted.map(c => sizeOf(c, cw, ch));
		let total = 0;
		sizes.forEach((s, i) => total += (horizontal ? s[0] : s[1]) + (i > 0 ? gap : 0));
		let cursor = 0;
		const mainLen = horizontal ? cw : ch;
		const align = horizontal ? L.hAlign : L.vAlign;
		if (align === "Center") cursor = (mainLen - total) / 2;
		else if (align === "Right" || align === "Bottom") cursor = mainLen - total;
		sorted.forEach((c, i) => {
			const [sw, sh] = sizes[i];
			let x, y;
			if (horizontal) {
				x = cursor; cursor += sw + gap;
				y = L.vAlign === "Center" ? (ch - sh) / 2 : L.vAlign === "Bottom" ? ch - sh : 0;
			} else {
				y = cursor; cursor += sh + gap;
				x = L.hAlign === "Center" ? (cw - sw) / 2 : L.hAlign === "Right" ? cw - sw : 0;
			}
			out.push({ node: c, x: cx + x, y: cy + y, w: sw, h: sh });
		});
		return { out, extent: total };
	}
	if (m.UIGridLayout) {
		const G = m.UIGridLayout;
		const cellW = ud([G.cellSize[0], G.cellSize[1]], cw), cellH = ud([G.cellSize[2], G.cellSize[3]], ch);
		const padX = ud([G.cellPadding[0], G.cellPadding[1]], cw), padY = ud([G.cellPadding[2], G.cellPadding[3]], ch);
		const perRow = Math.max(1, Math.floor((cw + padX) / (cellW + padX)));
		const sorted = list.slice().sort((a, b) => (a.order || 0) - (b.order || 0));
		const rowW = Math.min(perRow, sorted.length) * (cellW + padX) - padX;
		const startX = G.hAlign === "Center" ? (cw - rowW) / 2 : G.hAlign === "Right" ? cw - rowW : 0;
		sorted.forEach((c, i) => {
			const col = i % perRow, row = Math.floor(i / perRow);
			out.push({ node: c, x: cx + startX + col * (cellW + padX), y: cy + row * (cellH + padY), w: cellW, h: cellH });
		});
		const rows = Math.ceil(sorted.length / perRow);
		return { out, extent: rows * (cellH + padY) - padY };
	}
	for (const c of list) {
		const [sw, sh] = sizeOf(c, cw, ch);
		const a = c.anchor || [0, 0];
		const x = ud([c.position[0], c.position[1]], cw) - a[0] * sw;
		const y = ud([c.position[2], c.position[3]], ch) - a[1] * sh;
		out.push({ node: c, x: cx + x, y: cy + y, w: sw, h: sh });
	}
	return { out, extent: 0 };
}

function gradientCss(g) {
	const stops = arr(g.keys).map(k => rgb([k[1], k[2], k[3]]) + " " + (k[0] * 100) + "%").join(",");
	return "linear-gradient(" + ((g.rotation || 0) + 90) + "deg," + stops + ")";
}

function draw(n, parentEl, x, y, w, h) {
	const m = mods(n);
	// Automatic Y size for layout containers.
	let el = document.createElement("div");
	el.className = "n";
	el.dataset.name = n.name;
	const [cx, cy, cw, ch] = contentBox(n, w, h);
	let res = layoutChildren(n, cx, cy, cw, ch);
	if (n.autoSize === "Y" || n.autoSize === "XY") {
		if (res.extent > 0) { h = Math.max(h, res.extent + cy + (h - ch - cy)); }
	}
	el.style.left = x + "px"; el.style.top = y + "px"; el.style.width = w + "px"; el.style.height = h + "px";
	el.style.zIndex = n.z || 1;
	if (n.rotation) el.style.transform = "rotate(" + n.rotation + "deg)";
	const bgA = 1 - (n.bgT ?? 0);
	if (bgA > 0.001 && n.bg) {
		if (m.UIGradient) {
			el.style.background = gradientCss(m.UIGradient) + "," + rgb(n.bg, bgA);
			el.style.backgroundBlendMode = "multiply";
		} else el.style.background = rgb(n.bg, bgA);
	}
	if (m.UICorner) {
		const r = m.UICorner.radius;
		el.style.borderRadius = (r[0] > 0 ? Math.min(w, h) * r[0] : r[1]) + "px";
	}
	const strokes = arr(n.children).filter(c => c.class === "UIStroke");
	const textNode = n.text !== undefined && n.text !== "";
	for (const s of strokes) {
		const a = 1 - (s.transparency || 0);
		const borderMode = s.mode === "Border" || !textNode;
		if (borderMode && (bgA > 0.001 || s.mode === "Border")) {
			el.style.boxShadow = "0 0 0 " + s.thickness + "px " + rgb(s.color, a);
		}
	}
	if (n.clips) el.style.overflow = "hidden";
	if (m.UIScale && m.UIScale.scale !== 1) {
		const a = n.anchor || [0, 0];
		el.style.transformOrigin = (a[0] * 100) + "% " + (a[1] * 100) + "%";
		el.style.transform = (el.style.transform || "") + " scale(" + m.UIScale.scale + ")";
	}
	if (n.class === "ViewportFrame") {
		const dot = document.createElement("div");
		dot.className = "n";
		const d = Math.min(w, h) * 0.55;
		dot.style.left = (w - d) / 2 + "px"; dot.style.top = (h - d) / 2 + "px";
		dot.style.width = d + "px"; dot.style.height = d * 0.8 + "px";
		dot.style.borderRadius = "45%";
		const ic = n.imageColor || [1, 1, 1];
		dot.style.background = ic[0] > 0.5 ? "radial-gradient(circle at 35% 30%, #fff6c8, #d9a441)" : rgb(ic);
		el.appendChild(dot);
	}
	if (textNode) {
		const t = document.createElement("div");
		t.className = "t" + (n.wrapped || n.textScaled ? " wrap" : "");
		t.style.left = cx + "px"; t.style.top = cy + "px"; t.style.width = cw + "px"; t.style.height = ch + "px";
		t.style.inset = "auto";
		let size = n.textScaled ? scaledSize(n, cw, ch) : n.textSize || 14;
		if (m.UITextSizeConstraint && m.UITextSizeConstraint.maxTextSize) size = Math.min(size, m.UITextSizeConstraint.maxTextSize);
		t.style.font = fontCss(n, size);
		t.style.lineHeight = String((n.lineHeight || 1) * 1.05);
		let tc = n.textColor || [0, 0, 0];
		if (m.UIGradient) { // gradients tint text too
			const k = m.UIGradient.keys; const mid = k[Math.floor(k.length / 2)] || k[0];
			tc = [tc[0] * (k[0][1] + mid[1]) / 2, tc[1] * (k[0][2] + mid[2]) / 2, tc[2] * (k[0][3] + mid[3]) / 2];
		}
		t.style.color = rgb(tc, 1 - (n.textT || 0));
		t.style.justifyContent = n.xAlign === "Left" ? "flex-start" : n.xAlign === "Right" ? "flex-end" : "center";
		t.style.alignItems = n.yAlign === "Top" ? "flex-start" : n.yAlign === "Bottom" ? "flex-end" : "center";
		t.style.textAlign = n.xAlign === "Left" ? "left" : n.xAlign === "Right" ? "right" : "center";
		const ts = strokes.find(s => s.mode !== "Border");
		if (ts) {
			t.style.webkitTextStroke = (ts.thickness * 2) + "px " + rgb(ts.color, 1 - (ts.transparency || 0));
			t.style.paintOrder = "stroke fill";
		}
		const span = document.createElement("span");
		span.textContent = n.text;
		t.appendChild(span);
		el.appendChild(t);
	}
	parentEl.appendChild(el);
	if (n.autoSize === "Y" || n.autoSize === "XY") res = layoutChildren(n, cx, cy, cw, h - cy - (h - ch - cy));
	for (const r of res.out) draw(r.node, el, r.x, r.y, r.w, r.h);
	if (n.scrollY) el.scrollTop = n.scrollY;
}

window.loadFonts = async () => {
	await document.fonts.load("20px 'Luckiest Guy'");
	await document.fonts.load("20px 'Fredoka One'");
	return true;
};
window.renderScene = (gui) => {
	const screen = document.getElementById("screen");
	screen.innerHTML = "";
	const root = arr(gui.children).find(c => c.name === "Root");
	const scale = Math.min(1.2, Math.max(0.54, H / 720)); // matches HudController.applyScale
	root.size = [1 / scale, 0, 1 / scale, 0];
	const ui = arr(root.children).find(c => c.class === "UIScale");
	if (ui) ui.scale = scale;
	root.anchor = [0, 0];
	draw(root, screen, 0, 0, W / scale, H / scale);
	return true;
};
window.ready = true;
</script></body></html>`;

const server = http.createServer((req, res) => {
	const url = decodeURIComponent(req.url.split("?")[0]);
	if (url === "/") {
		res.writeHead(200, { "content-type": "text/html" });
		return res.end(page);
	}
	if (url.startsWith("/fonts/")) {
		const file = path.join(fontDir, path.basename(url));
		if (fs.existsSync(file)) {
			res.writeHead(200, { "content-type": "font/woff2" });
			return fs.createReadStream(file).pipe(res);
		}
	}
	res.writeHead(404);
	res.end();
});
await new Promise((r) => server.listen(0, r));
const executablePath =
	process.env.CHROMIUM_PATH ||
	(fs.existsSync("/opt/pw-browsers/chromium-1194/chrome-linux/chrome")
		? "/opt/pw-browsers/chromium-1194/chrome-linux/chrome"
		: undefined);
const browser = await chromium.launch({ executablePath });
const tab = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 2 });
tab.on("pageerror", (e) => console.error("[page error]", e.message));
await tab.goto(`http://localhost:${server.address().port}/`);
await tab.waitForFunction(() => window.ready === true);
await tab.evaluate(() => window.loadFonts());
const scenes = JSON.parse(fs.readFileSync(uiPath, "utf8"));
fs.mkdirSync(outDir, { recursive: true });
for (const [name, gui] of Object.entries(scenes)) {
	await tab.evaluate((g) => window.renderScene(g), gui);
	await tab.evaluate(() => document.fonts.ready);
	const file = path.join(outDir, `ui_${name}.png`);
	await tab.screenshot({ path: file });
	console.log("wrote", file);
}
await browser.close();
server.close();
