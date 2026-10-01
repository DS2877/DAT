// Headless 3D preview of the exported island.
//
//   lune run scripts/export-map.luau build.rbxl map.json
//   node scripts/preview/render.mjs map.json out_dir [view ...]
//
// Renders player-eye and overview shots with three.js in headless Chromium
// (software WebGL). It mimics Roblox where it matters for layout review:
// Ball parts use the smallest size axis, cylinders run along X, SpecialMesh
// spheres stretch to the part, billboards face the camera and are hidden by
// geometry, surface text is drawn on part faces. Lighting is approximate.
//
// Needs: npm install (in this folder) and Chromium (PLAYWRIGHT_BROWSERS_PATH
// or CHROMIUM_PATH).

import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright-core";

const here = path.dirname(fileURLToPath(import.meta.url));
const [mapPath = "map.json", outDir = "out", ...viewArgs] = process.argv.slice(2);
const W = 1300;
const H = 600;

const map = JSON.parse(fs.readFileSync(mapPath, "utf8"));
const L = map.layout;
const spawn = L.spawn;
const beachY = L.beachHeight;
const plateauY = L.plateauHeight;
const highY = L.highlandHeight ?? plateauY;

// Camera presets: position, target. Roblox default camera FOV is 70.
const VIEWS = {
	spawn: { pos: [spawn.x, beachY + 12, spawn.z + 16], target: [spawn.x, beachY + 4, spawn.z - 60] },
	baseEast: { pos: [spawn.x - 55, beachY + 45, spawn.z + 10], target: [spawn.x + 20, beachY, spawn.z - 15] },
	baseAir: { pos: [spawn.x, beachY + 70, spawn.z + 70], target: [spawn.x, beachY, spawn.z - 20] },
	beach: { pos: [spawn.x + 40, beachY + 14, L.base.minZ - 20], target: [spawn.x - 20, beachY + 6, L.beachNorthZ] },
	island: { pos: [0, 260, spawn.z + 260], target: [0, 20, L.volcanoSouthZ * 0.6] },
	jungle: {
		pos: [L.gates.Jungle.x, plateauY + 12, L.gates.Jungle.z - 40],
		target: [L.gates.Jungle.x - 40, plateauY + 6, (L.beachNorthZ + L.volcanoSouthZ) / 2 - 40],
	},
	ruins: {
		pos: [L.gates.Ruins.x, plateauY + 12, L.gates.Ruins.z - 40],
		target: [L.gates.Ruins.x + 30, plateauY + 8, (L.beachNorthZ + L.volcanoSouthZ) / 2 - 40],
	},
	volcano: {
		pos: [L.gates.Volcano.x, highY + 14, L.gates.Volcano.z - 40],
		target: [L.volcano.x, highY + 40, L.volcano.z],
	},
	signFromBase: { pos: [7, beachY + 9, 100], target: [7, beachY + 7, 72] },
	signFromNorth: { pos: [-10, beachY + 9, 46], target: [7, beachY + 7, 72] },
	rebirth: { pos: [-84, beachY + 10, 150], target: [-84, beachY + 2, 176] },
	rebirthSign: { pos: [-53, beachY + 6, 190], target: [-74, beachY + 4, 180] },
	tikiSign: { pos: [-86, beachY + 8, 222], target: [-112, beachY + 4, 226] },
	vipSign: { pos: [55, beachY + 8, 196], target: [84, beachY + 3, 180] },
	tiki: { pos: [-112, beachY + 12, 204], target: [-118, beachY + 3, 232] },
	infoBoard: { pos: [14, beachY + 9, 214], target: [40, beachY + 7, 214] },
	megaClock: { pos: [-26, beachY + 18, 104], target: [-26, beachY + 16, 134] },
	portal: { pos: [52, beachY + 14, 126], target: [80, beachY + 12, 90] },
	megaSites: { pos: [-90, beachY + 44, 186], target: [-90, beachY + 2, 112] },
	megaSiteClose: { pos: [-57, beachY + 14, 140], target: [-30, beachY + 4, 110] },
	portalSide: { pos: [130, beachY + 30, 70], target: [80, beachY + 10, 92] },
	megaClockSide: { pos: [4, beachY + 14, 150], target: [-26, beachY + 14, 134] },
	vipCarpet: { pos: [62, beachY + 26, 222], target: [74, beachY, 180] },
	vipSite: {
		pos: [L.vipSite.x - 10, beachY + 22, L.vipSite.z - 34],
		target: [L.vipSite.x, beachY + 2, L.vipSite.z],
	},
	top: { pos: [0, 900, (map.bounds.minZ + map.bounds.maxZ) / 2 + 1], target: [0, 0, (map.bounds.minZ + map.bounds.maxZ) / 2], fov: 50 },
};
const views = viewArgs.length > 0 ? viewArgs : ["spawn", "baseEast", "baseAir", "beach", "jungle", "ruins", "volcano", "island"];

const page = `<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;background:#000}</style></head>
<body><script type="importmap">{"imports":{"three":"/three.module.js","three/addons/":"/addons/"}}</script>
<script type="module">
import * as THREE from "three";
import { mergeGeometries } from "three/addons/utils/BufferGeometryUtils.js";
const map = await (await fetch("/map.json")).json();
const W = ${W}, H = ${H};
const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
renderer.setSize(W, H);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
const lt = map.lighting || {};
renderer.toneMappingExposure = 1.0 * Math.pow(2, lt.exposure || 0);
document.body.appendChild(renderer.domElement);
const scene = new THREE.Scene();
const sky = new THREE.Color(lt.atmosphere ? "#" + lt.atmosphere.color : "#a8d8ff");
scene.background = sky;
const density = lt.atmosphere ? lt.atmosphere.density : 0.2;
scene.fog = new THREE.Fog(sky, 250, 250 + 1400 * (1 - density));

const amb = new THREE.Color(lt.outdoorAmbient ? "#" + lt.outdoorAmbient : "#8a8a8a");
scene.add(new THREE.HemisphereLight(0xcfe8ff, amb, 1.1));
const sun = new THREE.DirectionalLight(0xfff2dd, 2.6 * ((lt.brightness || 2) / 2.5));
const hour = ((lt.clockTime ?? 14) - 12) * 15 * Math.PI / 180;
const lat = (lt.latitude ?? 41) * Math.PI / 180;
const elev = Math.asin(Math.cos(lat) * Math.cos(hour) * 0.92 + 0.08);
sun.position.set(-Math.sin(hour) * Math.cos(elev) * 600, Math.sin(elev) * 600, Math.cos(hour) * Math.cos(elev) * 300 + 150);
sun.castShadow = true;
sun.shadow.mapSize.set(4096, 4096);
sun.shadow.bias = -0.0004;
scene.add(sun);
scene.add(sun.target);

// Terrain.
const TERRAIN = {
	Sand: "#F0D9A4", Grass: "#60BA48", LeafyGrass: "#3A963E", Sandstone: "#D6B27A", Basalt: "#3A3436",
	CrackedLava: "#FF6E1E", Rock: "#8C847C", Slate: "#706C70", Ground: "#7A5A3C", Mud: "#5A4632",
	Water: "#1CC4D0", Air: "#145A8C", Limestone: "#D8CFB8", Pavement: "#9A9A9A", Asphalt: "#555", Snow: "#fff",
	Cobblestone: "#8A8478", Salt: "#eee", Ice: "#bde", Glacier: "#bde", WoodPlanks: "#8B5A2B", Concrete: "#999",
};
for (const [k, v] of Object.entries(map.terrainColors || {})) TERRAIN[k] = "#" + v;
{
	const { cols, rows, step, bounds } = map;
	const pos = new Float32Array(cols * rows * 3);
	const col = new Float32Array(cols * rows * 3);
	const c = new THREE.Color();
	for (let r = 0; r < rows; r++) for (let q = 0; q < cols; q++) {
		const i = r * cols + q;
		const mat = map.palette[map.materials[i] - 1];
		const h = mat === "Water" ? map.floors[i] : map.heights[i];
		pos.set([bounds.minX + q * step, h, bounds.minZ + r * step], i * 3);
		c.set(TERRAIN[mat === "Water" ? (map.world === "Frost" ? "Snow" : "Sand") : mat] || "#ff00ff");
		const n = (Math.sin(q * 12.9898 + r * 78.233) * 43758.5453) % 1;
		c.offsetHSL(0, 0, n * 0.035);
		if (mat === "Water") c.multiplyScalar(Math.max(0.35, 1 + h / 30));
		col.set([c.r, c.g, c.b], i * 3);
	}
	const idx = [];
	for (let r = 0; r < rows - 1; r++) for (let q = 0; q < cols - 1; q++) {
		const a = r * cols + q, b = a + 1, d = a + cols, e = d + 1;
		idx.push(a, d, b, b, d, e);
	}
	const g = new THREE.BufferGeometry();
	g.setAttribute("position", new THREE.BufferAttribute(pos, 3));
	g.setAttribute("color", new THREE.BufferAttribute(col, 3));
	g.setIndex(idx);
	g.computeVertexNormals();
	const m = new THREE.Mesh(g, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.95 }));
	m.receiveShadow = true; m.castShadow = true;
	scene.add(m);
	const water = new THREE.Mesh(
		new THREE.PlaneGeometry(6000, 6000),
		new THREE.MeshStandardMaterial({ color: map.waterColor ? "#" + map.waterColor : "#1CC4D0", transparent: true, opacity: 0.62, roughness: 0.15, metalness: 0.1 })
	);
	water.rotation.x = -Math.PI / 2; water.position.y = 0;
	water.receiveShadow = true;
	scene.add(water);
	const seabed = new THREE.Mesh(new THREE.PlaneGeometry(6000, 6000), new THREE.MeshStandardMaterial({ color: "#8d7d58" }));
	seabed.rotation.x = -Math.PI / 2; seabed.position.y = -34;
	scene.add(seabed);
}

// Parts, merged per material class.
function wedge(sx, sy, sz) {
	const g = new THREE.BufferGeometry();
	const x = sx / 2, y = sy / 2, z = sz / 2;
	// Roblox wedge: high edge at the back (+Z), slope faces front-up.
	const v = [
		[-x, -y, -z], [x, -y, -z], [-x, -y, z], [x, -y, z], [-x, y, z], [x, y, z],
	];
	const tris = [
		[0, 2, 1], [1, 2, 3], // bottom
		[2, 4, 3], [3, 4, 5], // back
		[0, 1, 4], [1, 5, 4], // slope
		[0, 4, 2], [1, 3, 5], // sides
	];
	const p = [];
	for (const t of tris) for (const k of t) p.push(...v[k]);
	g.setAttribute("position", new THREE.Float32BufferAttribute(p, 3));
	g.computeVertexNormals();
	return g;
}
function geometryFor(p) {
	let sx = p.sx, sy = p.sy, sz = p.sz;
	let off = [0, 0, 0];
	if (p.mesh) {
		const s = p.mesh.scale;
		off = p.mesh.offset;
		if (p.mesh.type === "Sphere") return [new THREE.SphereGeometry(0.5, 16, 12).scale(sx * s[0], sy * s[1], sz * s[2]), off];
		if (p.mesh.type === "Cylinder") return [new THREE.CylinderGeometry(0.5, 0.5, 1, 16).scale(sx * s[0], sy * s[1], sz * s[2]), off];
		if (p.mesh.type === "Wedge") return [wedge(sx * s[0], sy * s[1], sz * s[2]), off];
		sx *= s[0]; sy *= s[1]; sz *= s[2];
	}
	if (p.cls === "WedgePart") return [wedge(sx, sy, sz), off];
	if (p.shape === "Ball") { const d = Math.min(sx, sy, sz); return [new THREE.SphereGeometry(d / 2, 16, 12), off]; }
	if (p.shape === "Cylinder") {
		const d = Math.min(sy, sz);
		return [new THREE.CylinderGeometry(d / 2, d / 2, sx, 18).rotateZ(Math.PI / 2), off];
	}
	return [new THREE.BoxGeometry(sx, sy, sz), off];
}
function matrixFor(p, off) {
	const r = new THREE.Vector3(...p.right), u = new THREE.Vector3(...p.up);
	const b = new THREE.Vector3().crossVectors(r, u);
	const m = new THREE.Matrix4().makeBasis(r, u, b);
	const o = new THREE.Vector3(...off).applyMatrix4(m);
	m.setPosition(p.x + o.x, p.y + o.y, p.z + o.z);
	return m;
}
const groups = { solid: [], neon: [], glass: [] };
const partGeo = [];
for (const p of map.parts) {
	const [g0, off] = geometryFor(p);
	const g = g0.index ? g0.toNonIndexed() : g0;
	g.applyMatrix4(matrixFor(p, off));
	const c = new THREE.Color("#" + p.color);
	const n = g.attributes.position.count;
	const colors = new Float32Array(n * 3);
	for (let i = 0; i < n; i++) colors.set([c.r, c.g, c.b], i * 3);
	g.setAttribute("color", new THREE.BufferAttribute(colors, 3));
	if (g.attributes.uv) g.deleteAttribute("uv");
	const kind = p.mat === "Neon" ? "neon" : (p.t > 0.05 || p.mat === "Glass" || p.mat === "ForceField") ? "glass" : "solid";
	groups[kind].push(g);
	partGeo.push(p);
}
const mats = {
	solid: new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.8, metalness: 0.02 }),
	neon: new THREE.MeshBasicMaterial({ vertexColors: true }),
	glass: new THREE.MeshStandardMaterial({ vertexColors: true, transparent: true, opacity: 0.45, roughness: 0.2, depthWrite: false }),
};
for (const [k, list] of Object.entries(groups)) {
	if (list.length === 0) continue;
	for (let i = 0; i < list.length; i += 4000) {
		const merged = mergeGeometries(list.slice(i, i + 4000));
		const mesh = new THREE.Mesh(merged, mats[k]);
		mesh.castShadow = k === "solid"; mesh.receiveShadow = k !== "neon";
		scene.add(mesh);
	}
}

// Text helpers.
function textCanvas(lines, wPx, hPx, bg) {
	const cv = document.createElement("canvas");
	cv.width = wPx; cv.height = hPx;
	const ctx = cv.getContext("2d");
	if (bg) { ctx.fillStyle = bg; ctx.fillRect(0, 0, wPx, hPx); }
	let y = 0;
	for (const ln of lines) {
		const h = hPx * ln.frac;
		let size = h * 0.9;
		ctx.font = "900 " + size + "px sans-serif";
		const tw = ctx.measureText(ln.text).width;
		if (tw > wPx * 0.98) size *= (wPx * 0.98) / tw;
		ctx.font = "900 " + size + "px sans-serif";
		ctx.textAlign = "center"; ctx.textBaseline = "middle";
		ctx.lineWidth = Math.max(2, size * 0.12); ctx.strokeStyle = "#28190a";
		ctx.strokeText(ln.text, wPx / 2, y + h / 2);
		ctx.fillStyle = ln.color; ctx.fillText(ln.text, wPx / 2, y + h / 2);
		y += h;
	}
	const t = new THREE.CanvasTexture(cv);
	t.colorSpace = THREE.SRGBColorSpace;
	return t;
}
const labelSprites = [];
for (const l of map.labels) {
	const lines = l.sub ? [{ text: l.title, color: "#" + l.color, frac: 0.62 }, { text: l.sub, color: "#ffffff", frac: 0.38 }]
		: [{ text: l.title, color: "#" + l.color, frac: 1 }];
	const tex = textCanvas(lines, 512, Math.round(512 * l.h / l.w), null);
	const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, depthTest: !l.top, transparent: true, fog: false }));
	s.scale.set(l.w, l.h, 1);
	s.position.set(l.x, l.y, l.z);
	scene.add(s);
	labelSprites.push(s);
}
// [normal, text right, text up] per face, as seen by someone facing that face.
const FACES = {
	Front: [[0, 0, -1], [-1, 0, 0], [0, 1, 0]], Back: [[0, 0, 1], [1, 0, 0], [0, 1, 0]],
	Right: [[1, 0, 0], [0, 0, -1], [0, 1, 0]], Left: [[-1, 0, 0], [0, 0, 1], [0, 1, 0]],
	Top: [[0, 1, 0], [1, 0, 0], [0, 0, -1]], Bottom: [[0, -1, 0], [1, 0, 0], [0, 0, 1]],
};
for (const s of map.signs) {
	const p = map.parts[s.part - 1];
	if (!p) continue;
	const [n, ax, ay] = FACES[s.face] || FACES.Front;
	const dims = [p.sx, p.sy, p.sz];
	const w = Math.abs(ax[0]) * dims[0] + Math.abs(ax[1]) * dims[1] + Math.abs(ax[2]) * dims[2];
	const h = Math.abs(ay[0]) * dims[0] + Math.abs(ay[1]) * dims[1] + Math.abs(ay[2]) * dims[2];
	const d = Math.abs(n[0]) * dims[0] + Math.abs(n[1]) * dims[1] + Math.abs(n[2]) * dims[2];
	const tex = textCanvas([{ text: s.text, color: "#" + s.color, frac: 1 }], 512, Math.max(16, Math.round(512 * h / w)), s.bg ? "#" + s.bg : null);
	const plane = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial({ map: tex, transparent: true }));
	const m = matrixFor(p, [0, 0, 0]);
	const local = new THREE.Matrix4().makeBasis(new THREE.Vector3(...ax), new THREE.Vector3(...ay), new THREE.Vector3(...n));
	local.setPosition(n[0] * (d / 2 + 0.03), n[1] * (d / 2 + 0.03), n[2] * (d / 2 + 0.03));
	plane.applyMatrix4(m.multiply(local));
	scene.add(plane);
}
// Effects: fire / smoke puffs as soft sprites.
function blob(color, alpha) {
	const cv = document.createElement("canvas"); cv.width = cv.height = 64;
	const ctx = cv.getContext("2d");
	const g = ctx.createRadialGradient(32, 32, 0, 32, 32, 32);
	g.addColorStop(0, color); g.addColorStop(1, "rgba(0,0,0,0)");
	ctx.globalAlpha = alpha; ctx.fillStyle = g; ctx.fillRect(0, 0, 64, 64);
	return new THREE.CanvasTexture(cv);
}
const fireTex = blob("#ffb040", 1), smokeTex = blob("#cccccc", 0.6);
for (const e of map.effects) {
	if (e.kind === "Fire" || e.kind === "Smoke") {
		const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: e.kind === "Fire" ? fireTex : smokeTex, transparent: true, depthWrite: false }));
		const size = Math.min(40, e.size * (e.kind === "Fire" ? 1 : 2));
		s.scale.set(size, size * 1.4, 1);
		s.position.set(e.x, e.y + size * 0.6, e.z);
		scene.add(s);
	}
}
// A character for scale at the spawn (about 5 studs tall).
{
	const L = map.layout;
	const deck = L.beachHeight + (L.base.deckHeight || 1.4);
	const mk = (w, h, d, color, x, y, z) => { const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), new THREE.MeshStandardMaterial({ color })); m.position.set(x, y, z); m.castShadow = true; scene.add(m); };
	const cx = L.spawn.x, cz = L.spawn.z;
	mk(2, 2, 1, "#2a6fd6", cx, deck + 3, cz); mk(1.2, 1.2, 1.2, "#f5cd30", cx, deck + 4.6, cz);
	mk(1, 2, 1, "#2a2a2a", cx - 0.5, deck + 1, cz); mk(1, 2, 1, "#2a2a2a", cx + 0.5, deck + 1, cz);
	mk(1, 2, 1, "#f5cd30", cx - 1.5, deck + 3, cz); mk(1, 2, 1, "#f5cd30", cx + 1.5, deck + 3, cz);
}
window.renderView = (pos, target, fov) => {
	const cam = new THREE.PerspectiveCamera(fov || 70, W / H, 0.5, 5000);
	cam.position.set(...pos); cam.lookAt(...target);
	sun.target.position.set(target[0], 0, target[2]);
	const extent = Math.max(150, Math.min(700, Math.hypot(pos[0] - target[0], pos[2] - target[2]) * 1.6));
	sun.shadow.camera.left = -extent; sun.shadow.camera.right = extent;
	sun.shadow.camera.top = extent; sun.shadow.camera.bottom = -extent;
	sun.shadow.camera.near = 1; sun.shadow.camera.far = 2500;
	sun.position.copy(sun.target.position).add(new THREE.Vector3(-Math.sin(hour) * Math.cos(elev), Math.sin(elev), Math.cos(hour) * Math.cos(elev) * 0.5 + 0.25).multiplyScalar(900));
	sun.shadow.camera.updateProjectionMatrix();
	for (const s of labelSprites) s.visible = s.position.distanceTo(cam.position) < 400;
	renderer.render(scene, cam);
	return renderer.domElement.toDataURL("image/png");
};
window.ready = true;
</script></body></html>`;

const threeDir = path.join(here, "node_modules", "three");
const server = http.createServer((req, res) => {
	const url = decodeURIComponent(req.url.split("?")[0]);
	let file = null;
	let type = "text/javascript";
	if (url === "/") {
		res.writeHead(200, { "content-type": "text/html" });
		return res.end(page);
	} else if (url === "/map.json") {
		file = path.resolve(mapPath);
		type = "application/json";
	} else if (url === "/three.module.js" || url === "/three.core.js") {
		file = path.join(threeDir, "build", url.slice(1));
	} else if (url.startsWith("/addons/")) {
		file = path.join(threeDir, "examples", "jsm", url.slice("/addons/".length));
	}
	if (!file || !fs.existsSync(file)) {
		res.writeHead(404);
		return res.end();
	}
	res.writeHead(200, { "content-type": type });
	fs.createReadStream(file).pipe(res);
});
await new Promise((r) => server.listen(0, r));
const port = server.address().port;

const executablePath =
	process.env.CHROMIUM_PATH ||
	(fs.existsSync("/opt/pw-browsers/chromium-1194/chrome-linux/chrome")
		? "/opt/pw-browsers/chromium-1194/chrome-linux/chrome"
		: undefined);
const browser = await chromium.launch({
	executablePath,
	args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
});
const tab = await browser.newPage({ viewport: { width: W, height: H } });
tab.on("console", (m) => console.log("[page]", m.text()));
tab.on("pageerror", (e) => console.error("[page error]", e.message));
await tab.goto(`http://localhost:${port}/`);
await tab.waitForFunction(() => window.ready === true, null, { timeout: 300000 });
fs.mkdirSync(outDir, { recursive: true });
for (const name of views) {
	let v = VIEWS[name];
	if (!v && name.includes(",")) {
		// Custom: "x,y,z:tx,ty,tz[:fov]"
		const [a, b, f] = name.split(":");
		v = { pos: a.split(",").map(Number), target: b.split(",").map(Number), fov: f ? Number(f) : 70 };
	}
	if (!v) {
		console.error("unknown view", name);
		continue;
	}
	const data = await tab.evaluate(([p, t, f]) => window.renderView(p, t, f), [v.pos, v.target, v.fov]);
	const file = path.join(outDir, `${name.replace(/[^a-zA-Z0-9_-]/g, "_")}.png`);
	fs.writeFileSync(file, Buffer.from(data.split(",")[1], "base64"));
	console.log("wrote", file);
}
await browser.close();
server.close();
