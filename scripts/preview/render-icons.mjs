// Renders the store icons (512x512 PNG, one per pass / product) into
// store/icons/<icon>.png, from the catalog JSON of scripts/store-catalog.luau.
// Everything important stays inside the center circle (Roblox crops
// product icons to a circle).
//
//   lune run scripts/store-catalog.luau catalog.json
//   FONT_DIR=... node scripts/preview/render-icons.mjs catalog.json store/icons

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright-core";

const here = path.dirname(fileURLToPath(import.meta.url));
const [catalogPath = "catalog.json", outDir = "store/icons"] = process.argv.slice(2);
const fontDir = process.env.FONT_DIR || path.join(here, "fonts");
const catalog = JSON.parse(fs.readFileSync(catalogPath, "utf8"));

// Per icon: background colors (inner, outer) and an optional badge.
const STYLE = {
	AutoDig: { colors: ["#FFE27A", "#F29B1D"], badge: "AUTO" },
	TreasureRadar: { colors: ["#9EF0FF", "#1E8FD6"], badge: "RADAR" },
	BigBag: { colors: ["#FFC48A", "#D9661A"], badge: "+50%" },
	AutoSell: { colors: ["#A8F5A0", "#25A244"], badge: "AUTO" },
	FastDig: { colors: ["#FFF59A", "#E6A800"], badge: "2x" },
	CashX2: { colors: ["#B6F7A8", "#1F9E46"], badge: "2x" },
	VIP: { colors: ["#FFE680", "#B8860B"], badge: "VIP" },
	Luck2x: { colors: ["#B8FFB0", "#2E9E3A"], badge: "2x" },
	StarterPack: { colors: ["#FFB3E1", "#D6338A"], badge: "STARTER" },
	CashSmall: { colors: ["#C9F7B8", "#3BA55C"] },
	CashMedium: { colors: ["#B2F0A0", "#2C8F4B"] },
	CashLarge: { colors: ["#A6E6FF", "#2B6FD6"] },
	BoostCash: { colors: ["#B6F7A8", "#1F9E46"], badge: "15 MIN" },
	BoostDig: { colors: ["#FFF59A", "#E6A800"], badge: "15 MIN" },
	ServerBoost: { colors: ["#E2B6FF", "#7B2FD6"], badge: "SERVER" },
	InstantDeepDig: { colors: ["#FFB27A", "#C73A12"], badge: "INSTANT" },
	SkinPirate: { colors: ["#D9B98C", "#5B3A22"] },
	SkinIce: { colors: ["#DDFBFF", "#4CB8E0"] },
	SkinLava: { colors: ["#FFB27A", "#B3260B"] },
};

// Cash packs show a stack that grows.
const EMOJI_OVERRIDE = { CashSmall: "💵", CashMedium: "💰", CashLarge: "💎" };

function iconHtml(entry) {
	const style = STYLE[entry.icon] || { colors: ["#FFFFFF", "#999999"] };
	const [inner, outer] = style.colors;
	const emoji = EMOJI_OVERRIDE[entry.icon] || entry.emoji;
	const badge = style.badge
		? `<div class="badge">${style.badge}</div>`
		: "";
	return `<!doctype html><html><head><meta charset="utf-8"><style>
@font-face { font-family: 'Luckiest Guy'; src: url(data:font/woff2;base64,${luckiest}); }
html, body { margin: 0; width: 512px; height: 512px; overflow: hidden; background: transparent; }
.bg { position: absolute; inset: 0; background: radial-gradient(circle at 50% 42%, ${inner} 0%, ${outer} 72%); }
.rays { position: absolute; inset: 0; background: repeating-conic-gradient(from 0deg at 50% 46%, rgba(255,255,255,0.16) 0deg 10deg, rgba(255,255,255,0) 10deg 20deg);
	-webkit-mask-image: radial-gradient(circle at 50% 46%, black 30%, transparent 70%); }
.ring { position: absolute; left: 26px; top: 26px; width: 460px; height: 460px; border-radius: 50%;
	box-shadow: inset 0 0 0 10px rgba(255,255,255,0.55); }
.emoji { position: absolute; left: 0; right: 0; top: ${style.badge ? 78 : 100}px; text-align: center;
	font-family: 'Noto Color Emoji'; font-size: ${style.badge ? 250 : 280}px; line-height: 1;
	filter: drop-shadow(0 10px 0 rgba(0,0,0,0.22)); }
.badge { position: absolute; left: 50%; transform: translateX(-50%) rotate(-4deg); top: 352px;
	padding: 10px 26px 2px; border-radius: 22px; background: #FFF7E4; border: 7px solid #2D1C0C;
	font-family: 'Luckiest Guy'; font-size: 62px; color: #2D1C0C; white-space: nowrap; }
</style></head><body><div class="bg"></div><div class="rays"></div><div class="ring"></div>
<div class="emoji">${emoji}</div>${badge}</body></html>`;
}

const luckiest = fs.existsSync(path.join(fontDir, "LuckiestGuy.woff2"))
	? fs.readFileSync(path.join(fontDir, "LuckiestGuy.woff2")).toString("base64")
	: "";

fs.mkdirSync(outDir, { recursive: true });
const browser = await chromium.launch({
	executablePath: process.env.CHROMIUM || "/opt/pw-browsers/chromium",
});
const tab = await browser.newPage({ viewport: { width: 512, height: 512 }, deviceScaleFactor: 1 });
const done = new Set();
for (const entry of catalog) {
	if (done.has(entry.icon)) continue;
	done.add(entry.icon);
	await tab.setContent(iconHtml(entry));
	await tab.evaluate(() => document.fonts.ready);
	const file = path.join(outDir, entry.icon + ".png");
	await tab.screenshot({ path: file, omitBackground: false });
	console.log("wrote " + file);
}
await browser.close();
