// Arenas procedurais: cinco temas, obstáculos e disposição sorteados por semente.
import * as THREE from 'three';
import { N, bx, cyl, prism, cone, mkCanvas, mkTex, surfaceTextures, hazardTex, softDot } from './geo.js';
import { ARENAS } from './data.js';
import { mulberry } from './stats.js';

const PI = Math.PI;
const TC = {};
function gtex(key, S, paint, srgb = true) { if (!TC[key]) { const c = mkCanvas(S, S); paint(c.getContext('2d'), S, mulberry(key.length * 71 + 3)); TC[key] = mkTex(c, srgb); } return TC[key]; }
const speck = (x, S, rng, n, col, r0, r1, a0, a1) => { for (let i = 0; i < n; i++) { x.fillStyle = `rgba(${col},${rng.range(a0, a1)})`; x.beginPath(); x.arc(rng() * S, rng() * S, rng.range(r0, r1), 0, 7); x.fill(); } };
const blot = (x, S, rng, n, col, r0, r1, a) => { for (let i = 0; i < n; i++) { const px = rng() * S, py = rng() * S, r = rng.range(r0, r1), g = x.createRadialGradient(px, py, 0, px, py, r); g.addColorStop(0, `rgba(${col},${a})`); g.addColorStop(1, `rgba(${col},0)`); x.fillStyle = g; x.fillRect(px - r, py - r, r * 2, r * 2); } };
const crack = (x, S, rng, n, col, w) => { for (let i = 0; i < n; i++) { let px = rng() * S, py = rng() * S, a = rng() * 7; x.strokeStyle = col; x.lineWidth = w * rng.range(0.5, 1.5); x.beginPath(); x.moveTo(px, py); for (let k = 0; k < rng.int(4, 14); k++) { a += rng.range(-0.7, 0.7); px += Math.cos(a) * rng.range(8, 28); py += Math.sin(a) * rng.range(8, 28); x.lineTo(px, py); } x.stroke(); } };

const GROUND = {
  steel: () => gtex('steel-deck', 1024, (x, S, r) => {
    x.fillStyle = '#4b4e52'; x.fillRect(0, 0, S, S);
    for (let i = 0; i < 4; i++) for (let j = 0; j < 4; j++) { const v = r.int(-10, 10); x.fillStyle = `rgb(${72 + v},${75 + v},${80 + v})`; x.fillRect(i * 256 + 3, j * 256 + 3, 250, 250); for (let k = 0; k < 8; k++) { x.fillStyle = '#2c2e31'; x.beginPath(); x.arc(i * 256 + 20 + k * 31, j * 256 + 16, 4, 0, 7); x.arc(i * 256 + 20 + k * 31, j * 256 + 240, 4, 0, 7); x.fill(); } }
    blot(x, S, r, 50, '20,18,16', 40, 160, 0.22); speck(x, S, r, 1600, '25,22,20', 0.5, 3, 0.1, 0.5); crack(x, S, r, 26, 'rgba(150,150,150,0.25)', 1.2);
    blot(x, S, r, 14, '110,60,30', 20, 70, 0.2);
  }),
  concrete: () => gtex('concrete-wet', 1024, (x, S, r) => {
    x.fillStyle = '#5c5e60'; x.fillRect(0, 0, S, S);
    for (let i = 0; i < 2; i++) for (let j = 0; j < 2; j++) { const v = r.int(-8, 8); x.fillStyle = `rgb(${92 + v},${94 + v},${96 + v})`; x.fillRect(i * 512 + 4, j * 512 + 4, 504, 504); }
    blot(x, S, r, 90, '30,32,36', 40, 200, 0.2); blot(x, S, r, 30, '140,140,138', 30, 120, 0.12);
    speck(x, S, r, 3000, '30,30,30', 0.5, 2.5, 0.08, 0.4); crack(x, S, r, 40, 'rgba(25,25,26,0.55)', 1.6);
    x.strokeStyle = 'rgba(20,20,20,0.3)'; for (let i = 0; i < 9; i++) { x.lineWidth = r.range(8, 16); x.beginPath(); const y = r() * S; x.moveTo(0, y); x.bezierCurveTo(S * 0.3, y + r.range(-90, 90), S * 0.6, y + r.range(-90, 90), S, y + r.range(-60, 60)); x.stroke(); }
  }),
  salt: () => gtex('salt-flat', 1024, (x, S, r) => {
    x.fillStyle = '#d9d2c4'; x.fillRect(0, 0, S, S);
    blot(x, S, r, 60, '190,170,140', 60, 220, 0.16); blot(x, S, r, 40, '255,252,244', 40, 160, 0.25);
    // polígonos de dessecação
    const pts = []; const G = 9; for (let i = 0; i <= G; i++) for (let j = 0; j <= G; j++) pts.push([(i + (i % G ? r.range(-0.35, 0.35) : 0)) * S / G, (j + (j % G ? r.range(-0.35, 0.35) : 0)) * S / G]);
    x.strokeStyle = 'rgba(120,100,78,0.55)'; x.lineWidth = 2.2;
    for (let i = 0; i < G; i++) for (let j = 0; j < G; j++) { const a = pts[i * (G + 1) + j], b = pts[(i + 1) * (G + 1) + j], c = pts[i * (G + 1) + j + 1]; x.beginPath(); x.moveTo(a[0], a[1]); x.lineTo(b[0], b[1]); x.moveTo(a[0], a[1]); x.lineTo(c[0], c[1]); x.stroke(); }
    speck(x, S, r, 2500, '120,105,85', 0.5, 2, 0.08, 0.3);
  }),
  scoria: () => gtex('scoria-floor', 1024, (x, S, r) => {
    x.fillStyle = '#2b2725'; x.fillRect(0, 0, S, S);
    blot(x, S, r, 120, '10,9,9', 30, 160, 0.4); blot(x, S, r, 50, '74,60,52', 30, 120, 0.25);
    speck(x, S, r, 5000, '90,78,70', 0.5, 2.6, 0.1, 0.5); crack(x, S, r, 50, 'rgba(8,7,7,0.7)', 2);
    for (let i = 0; i < 4; i++) { x.fillStyle = 'rgba(70,66,60,0.6)'; x.fillRect(0, i * 256, S, 3); x.fillRect(i * 256, 0, 3, S); }
  }),
  snow: () => gtex('snow-pack', 1024, (x, S, r) => {
    x.fillStyle = '#dfe6ec'; x.fillRect(0, 0, S, S);
    blot(x, S, r, 80, '150,175,205', 50, 220, 0.2); blot(x, S, r, 60, '255,255,255', 40, 180, 0.4);
    speck(x, S, r, 1800, '170,190,210', 0.5, 2.2, 0.1, 0.4);
    x.strokeStyle = 'rgba(120,140,165,0.3)'; for (let i = 0; i < 6; i++) { x.lineWidth = 14; const y = r() * S; x.beginPath(); x.moveTo(0, y); x.bezierCurveTo(S * 0.3, y + r.range(-120, 120), S * 0.7, y + r.range(-120, 120), S, y); x.stroke(); }
  }),
};
const corrugated = () => gtex('corrugated', 256, (x, S) => { for (let i = 0; i < S; i += 16) { const g = x.createLinearGradient(i, 0, i + 16, 0); g.addColorStop(0, '#606060'); g.addColorStop(0.5, '#f0f0f0'); g.addColorStop(1, '#606060'); x.fillStyle = g; x.fillRect(i, 0, 16, S); } }, false);
const rockTex = () => gtex('rock-strata', 512, (x, S, r) => { x.fillStyle = '#fff'; x.fillRect(0, 0, S, S); for (let y = 0; y < S; y += r.int(6, 26)) { const v = r.int(150, 250); x.fillStyle = `rgb(${v},${v - 6},${v - 14})`; x.fillRect(0, y, S, 26); } blot(x, S, r, 60, '60,50,40', 20, 90, 0.2); crack(x, S, r, 30, 'rgba(40,32,26,0.5)', 1.6); speck(x, S, r, 1500, '50,40,34', 0.5, 2.5, 0.1, 0.4); });
const windowsTex = () => gtex('crowd-lights', 256, (x, S, r) => { x.fillStyle = '#000'; x.fillRect(0, 0, S, S); for (let i = 0; i < 900; i++) { const c = r.pick(['255,220,170', '255,255,255', '170,210,255', '255,120,80']); x.fillStyle = `rgba(${c},${r.range(0.2, 1)})`; x.fillRect(r.int(0, S), r.int(0, S), 2, 2); } });

function skyDome(o) {
  const mat = new THREE.ShaderMaterial({
    side: THREE.BackSide, depthWrite: false, fog: false,
    uniforms: { top: { value: new THREE.Color(o.top) }, hor: { value: new THREE.Color(o.hor) }, bot: { value: new THREE.Color(o.bot || o.hor) }, sunDir: { value: o.sunDir.clone().normalize() }, sunCol: { value: new THREE.Color(o.sunCol) }, sunPow: { value: o.sunPow || 200 }, glow: { value: o.glow ?? 0.5 }, aurora: { value: o.aurora || 0 }, stars: { value: o.stars || 0 }, time: { value: 0 } },
    vertexShader: 'varying vec3 vD; void main(){ vD = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }',
    fragmentShader: `varying vec3 vD; uniform vec3 top,hor,bot,sunDir,sunCol; uniform float sunPow,glow,aurora,stars,time;
      float h(vec3 p){ return fract(sin(dot(p, vec3(127.1,311.7,74.7)))*43758.5453); }
      void main(){ vec3 d = normalize(vD); float y = d.y; vec3 c = y > 0.0 ? mix(hor, top, pow(y, 0.45)) : mix(hor, bot, pow(-y, 0.3));
        float s = max(0.0, dot(d, sunDir)); c += sunCol * (pow(s, sunPow) * 3.0 + pow(s, 8.0) * glow);
        if (stars > 0.0 && y > 0.0) { vec3 q = floor(d * 220.0); float st = step(0.9975, h(q)); c += st * stars * y * (0.5 + 0.5 * h(q + 1.0)); }
        if (aurora > 0.0 && y > 0.05) { float a = sin(d.x * 5.0 + sin(d.z * 3.0 + time * 0.12) * 2.0) * 0.5 + 0.5; float band = smoothstep(0.12, 0.3, y) * smoothstep(0.75, 0.3, y); c += vec3(0.1, 0.9, 0.55) * pow(a, 3.0) * band * aurora + vec3(0.5, 0.2, 0.8) * pow(1.0 - a, 6.0) * band * aurora * 0.4; }
        gl_FragColor = vec4(c, 1.0); }`,
  });
  return new THREE.Mesh(new THREE.SphereGeometry(1500, 32, 20), mat);
}

function weather(o) { // partículas presas à câmera (neve, garoa, brasas, poeira)
  const n = o.n, g = new THREE.BufferGeometry(), p = new Float32Array(n * 3), s = new Float32Array(n);
  for (let i = 0; i < n; i++) { p[i * 3] = Math.random() * 160; p[i * 3 + 1] = Math.random() * 90; p[i * 3 + 2] = Math.random() * 160; s[i] = Math.random(); }
  g.setAttribute('position', new THREE.BufferAttribute(p, 3)); g.setAttribute('seed', new THREE.BufferAttribute(s, 1));
  const mat = new THREE.ShaderMaterial({ transparent: true, depthWrite: false, blending: o.add ? THREE.AdditiveBlending : THREE.NormalBlending,
    uniforms: { time: { value: 0 }, cam: { value: new THREE.Vector3() }, vel: { value: new THREE.Vector3(...o.vel) }, col: { value: new THREE.Color(o.col) }, size: { value: o.size }, alpha: { value: o.alpha }, map: { value: softDot() }, sway: { value: o.sway || 0 } },
    vertexShader: `attribute float seed; uniform float time,size,sway; uniform vec3 cam,vel; varying float vA;
      void main(){ vec3 p = position + vel * time * (0.6 + seed * 0.8); p.x += sin(time * (0.5 + seed) + seed * 40.0) * sway; p.z += cos(time * (0.4 + seed) + seed * 20.0) * sway;
        p = mod(p - cam + vec3(80.0, 30.0, 80.0), vec3(160.0, 90.0, 160.0)) + cam - vec3(80.0, 30.0, 80.0);
        vec4 mv = modelViewMatrix * vec4(p, 1.0); vA = smoothstep(90.0, 40.0, -mv.z); gl_PointSize = size * (0.5 + seed) * 300.0 / max(1.0, -mv.z); gl_Position = projectionMatrix * mv; }`,
    fragmentShader: 'uniform vec3 col; uniform float alpha; uniform sampler2D map; varying float vA; void main(){ float a = texture2D(map, gl_PointCoord).a * alpha * vA; if (a < 0.01) discard; gl_FragColor = vec4(col, a); }' });
  const pts = new THREE.Points(g, mat); pts.frustumCulled = false; pts.renderOrder = 12; return pts;
}

export function buildArena(id, seed, engine, opts = {}) {
  const def = ARENAS[id], rng = mulberry(seed * 7919 + id.length * 131), R = def.size;
  const A = { id, def, size: R, group: new THREE.Group(), obstacles: [], hazards: [], ceiling: 130, lights: [], disp: [], dyn: [], circle: true, grav: 1, heat: 0 };
  const n = new N('arena');
  const ST = surfaceTextures(0.55);
  const M = (o) => { const m = new THREE.MeshStandardMaterial(o); A.disp.push(m); return m; };
  const mats = {
    con: M({ color: '#7a7b7c', roughness: 0.92, metalness: 0.05, map: ST.map, bumpMap: ST.bump, bumpScale: 1.2 }),
    dark: M({ color: '#2e3033', roughness: 0.8, metalness: 0.5, map: ST.map, bumpMap: ST.bump, bumpScale: 1 }),
    stl: M({ color: '#5a5f66', roughness: 0.55, metalness: 0.85, map: ST.map, bumpMap: ST.bump, roughnessMap: ST.rough }),
    rust: M({ color: '#6b4030', roughness: 0.9, metalness: 0.4, map: ST.map, bumpMap: ST.bump, bumpScale: 1.4 }),
    rock: M({ color: '#b79b7c', roughness: 0.96, metalness: 0, map: rockTex(), bumpMap: rockTex(), bumpScale: 2.4 }),
    ice: M({ color: '#a9d2e6', roughness: 0.12, metalness: 0.1, transparent: true, opacity: 0.86 }),
    white: M({ color: '#d8dcde', roughness: 0.6, metalness: 0.3, map: ST.map, bumpMap: ST.bump }),
    hz: M({ map: hazardTex(), roughness: 0.75, metalness: 0.3 }),
    win: new THREE.MeshBasicMaterial({ color: new THREE.Color('#ffd9a0').multiplyScalar(1.6), toneMapped: false }),
    lamp: new THREE.MeshBasicMaterial({ color: new THREE.Color('#ffffff').multiplyScalar(4), toneMapped: false }),
    red: new THREE.MeshBasicMaterial({ color: new THREE.Color('#ff3020').multiplyScalar(3), toneMapped: false }),
    lava: new THREE.MeshBasicMaterial({ color: new THREE.Color('#ff5a10').multiplyScalar(2.6), toneMapped: false }),
  };
  ['#8c3b2a', '#2f5d7c', '#3f6b4a', '#c79a2a', '#b9b6aa', '#55585c', '#7a4a6a'].forEach((c, i) => { mats['k' + i] = M({ color: c, roughness: 0.7, metalness: 0.5, bumpMap: corrugated(), bumpScale: 3, map: ST.map }); });
  const uvs = { con: 0.05, dark: 0.06, stl: 0.07, rust: 0.05, rock: 0.035, white: 0.08, hz: 0.12, k0: 0.4, k1: 0.4, k2: 0.4, k3: 0.4, k4: 0.4, k5: 0.4, k6: 0.4 };
  // caixa com colisão
  const box = (mat, x, z, w, h, d, y0 = 0, col = true, bev = 0.25) => {
    n.put(mat, bx(w, h, d, Math.min(bev, w * 0.2, h * 0.2, d * 0.2)), [x, y0 + h / 2, z]);
    if (col) A.obstacles.push({ min: new THREE.Vector3(x - w / 2, y0, z - d / 2), max: new THREE.Vector3(x + w / 2, y0 + h, z + d / 2), alive: true });
  };
  const freeAt = (x, z, r) => { // longe dos pontos de entrada e de outros obstáculos
    if (Math.hypot(x, z + R * 0.62) < 26 + r || Math.hypot(x, z - R * 0.62) < 26 + r || Math.hypot(x, z) < 14 + r) return false;
    for (const o of A.obstacles) { const cx = (o.min.x + o.max.x) / 2, cz = (o.min.z + o.max.z) / 2, rr = Math.max(o.max.x - o.min.x, o.max.z - o.min.z) / 2; if (Math.hypot(x - cx, z - cz) < rr + r + 7) return false; }
    return true;
  };
  const scatter = (count, rmin, rmax, r, fn) => { let made = 0; for (let t = 0; t < count * 30 && made < count; t++) { const a = rng() * PI * 2, d = rng.range(rmin, rmax), x = Math.cos(a) * d, z = Math.sin(a) * d; if (!freeAt(x, z, r)) continue; fn(x, z, made); made++; } };

  let sky, sunDir, sunCol = '#fff', sunI = 2.5, hemi = ['#8899aa', '#333', 0.6], fog = ['#888', 0.0016], gtexName = 'concrete', gcol = '#fff', groundRough = 0.9, groundMetal = 0.1, wx = null, exposure = 1;

  if (id === 'coliseu') {
    gtexName = 'steel'; groundRough = 0.5; groundMetal = 0.7;
    sunDir = new THREE.Vector3(-0.35, 1, -0.5); sunCol = '#e6ecff'; sunI = 3.0; hemi = ['#62749a', '#2a2620', 1.0]; fog = ['#0c1016', 0.0018];
    sky = skyDome({ top: '#05070d', hor: '#1c2638', bot: '#0a0d12', sunDir, sunCol: '#8fa8d8', sunPow: 400, glow: 0.12, stars: 1.2 });
    const segs = 28, len = 2 * PI * (R + 4) / segs + 1;
    for (let i = 0; i < segs; i++) {
      const a = i / segs * PI * 2, c = Math.cos(a), s = Math.sin(a), ry = -a + PI / 2;
      n.put('con', bx(len, 20, 8, 0.4), [c * (R + 4), 10, s * (R + 4)], [0, ry, 0]);
      n.put('hz', bx(len, 1.6, 8.3, 0.1), [c * (R + 4), 19.2, s * (R + 4)], [0, ry, 0]);
      for (let k = 0; k < 3; k++) { n.put('dark', bx(len + 1 + k, 12, 13, 0.3), [c * (R + 14 + k * 12), 24 + k * 11, s * (R + 14 + k * 12)], [0, ry, 0]); n.put('crowd', bx(len + k, 6.5, 0.4, 0.01), [c * (R + 7.6 + k * 12), 33.5 + k * 11, s * (R + 7.6 + k * 12)], [0, ry, 0]); }
      if (i % 2 === 0) n.put('lamp', bx(len * 0.6, 0.5, 0.4, 0.01), [c * (R + 0.4), 16.5, s * (R + 0.4)], [0, ry, 0]);
      if (i % 4 === 1) { n.put('dark', bx(3, 86, 3, 0.2), [c * (R + 52), 43, s * (R + 52)]); n.put('lamp', bx(18, 8, 1, 0.1), [c * (R + 50.4), 84, s * (R + 50.4)], [0, ry, 0]); n.put('dark', bx(20, 10, 2, 0.2), [c * (R + 51.6), 84, s * (R + 51.6)], [0, ry, 0]); }
    }
    mats.crowd = new THREE.MeshBasicMaterial({ map: windowsTex(), toneMapped: false, color: new THREE.Color(1.3, 1.3, 1.3) }); uvs.crowd = 0.03;
    const rot = rng() * PI;
    for (let i = 0; i < 4; i++) { const a = rot + i * PI / 2, x = Math.cos(a) * 50, z = Math.sin(a) * 50; box('con', x, z, 11, 28, 11, 0, true, 0.5); n.put('hz', bx(11.4, 2, 11.4, 0.1), [x, 3, z]); n.put('lamp', bx(11.2, 0.4, 11.2, 0.05), [x, 22, z]); }
    for (let i = 0; i < 8; i++) { const a = rot + PI / 8 + i * PI / 4, x = Math.cos(a) * 98, z = Math.sin(a) * 98; if (!freeAt(x, z, 8)) continue; if (i % 2) box('dark', x, z, 18, 7, 6); else box('dark', x, z, 6, 7, 18); n.put('hz', bx(i % 2 ? 18.3 : 6.3, 1, i % 2 ? 6.3 : 18.3, 0.05), [x, 6.4, z]); }
    for (let i = 0; i < 2; i++) { const a = rot + PI / 4 + i * PI, x = Math.cos(a) * 78, z = Math.sin(a) * 78; box('stl', x, z, 24, 8, 24, 0, true, 0.6); }
    scatter(rng.int(4, 7), 20, R - 25, 5, (x, z) => box('con', x, z, rng.range(5, 9), rng.range(4, 9), rng.range(5, 9)));
  } else if (id === 'doca') {
    A.circle = false; gtexName = 'concrete'; groundRough = 0.32; groundMetal = 0.25; gcol = '#9a9da0';
    sunDir = new THREE.Vector3(-0.7, 0.32, 0.4); sunCol = '#ffb27a'; sunI = 2.4; hemi = ['#6b7a90', '#2a2622', 0.75]; fog = ['#4a5058', 0.0036];
    sky = skyDome({ top: '#2c3644', hor: '#b9825e', bot: '#2a2c30', sunDir, sunCol: '#ffb070', sunPow: 300, glow: 0.9 });
    wx = weather({ n: 1400, vel: [-3, -52, 2], col: '#aab4c0', size: 0.5, alpha: 0.35 });
    const CW = 13, CH = 5.4, CD = 5.2;
    const stack = (x, z, alongX, h) => { for (let k = 0; k < h; k++) { const w = alongX ? CW : CD, d = alongX ? CD : CW; const m = 'k' + rng.int(0, 6); n.put(m, bx(w, CH - 0.1, d, 0.12), [x, k * CH + CH / 2, z]); n.put('dark', bx(alongX ? 0.3 : d * 0.9, CH * 0.8, alongX ? d * 0.9 : 0.3, 0.02), [x + (alongX ? w / 2 : 0), k * CH + CH / 2, z + (alongX ? 0 : d / 2)]); } const w = alongX ? CW : CD, d = alongX ? CD : CW; A.obstacles.push({ min: new THREE.Vector3(x - w / 2, 0, z - d / 2), max: new THREE.Vector3(x + w / 2, h * CH, z + d / 2), alive: true }); };
    for (let gx = -4; gx <= 4; gx++) for (let gz = -4; gz <= 4; gz++) {
      if (rng.chance(0.42)) continue;
      const x = gx * 34 + rng.range(-5, 5), z = gz * 34 + rng.range(-5, 5); if (!freeAt(x, z, 9) || Math.abs(x) > R - 14 || Math.abs(z) > R - 14) continue;
      const ax = rng.chance(0.5), h = rng.int(1, 3); stack(x, z, ax, h); if (rng.chance(0.4)) stack(x + (ax ? 0 : CD + 0.4), z + (ax ? CD + 0.4 : 0), ax, rng.int(1, h));
    }
    for (const cx of [-70, 75]) { // pórticos
      for (const [dx, dz] of [[-16, -24], [16, -24], [-16, 24], [16, 24]]) if (freeAt(cx + dx, dz, 3)) box('stl', cx + dx, dz, 4, 50, 4, 0, true, 0.3);
      n.put('stl', bx(40, 5, 6, 0.3), [cx, 52, -24]); n.put('stl', bx(40, 5, 6, 0.3), [cx, 52, 24]); n.put('hz', bx(8, 4, 64, 0.2), [cx, 57, 0]); n.put('k3', bx(9, 7, 9, 0.3), [cx + rng.range(-10, 10), 49, rng.range(-15, 15)]); n.put('lamp', bx(3, 0.5, 3, 0.05), [cx, 46.5, 0]);
    }
    for (let i = -5; i <= 5; i++) { for (const sgn of [-1, 1]) { const m = 'k' + rng.int(0, 6), h = rng.int(2, 4); n.put(m, bx(30, h * CH, 6, 0.2), [i * 32, h * CH / 2, sgn * (R + 4)]); n.put('k' + rng.int(0, 6), bx(6, h * CH, 30, 0.2), [sgn * (R + 4), h * CH / 2, i * 32]); } }
    scatter(10, 30, R - 15, 2, (x, z) => { n.put('dark', bx(0.6, 18, 0.6, 0.05), [x, 9, z]); n.put('lampw', bx(2.4, 0.5, 1.2, 0.05), [x, 18, z]); A.obstacles.push({ min: new THREE.Vector3(x - 0.5, 0, z - 0.5), max: new THREE.Vector3(x + 0.5, 18, z + 0.5), alive: true }); });
    mats.lampw = new THREE.MeshBasicMaterial({ color: new THREE.Color('#ffb060').multiplyScalar(4), toneMapped: false });
    n.put('dark', bx(120, 26, 30, 1), [-60, 13, R + 90]); n.put('white', bx(30, 20, 20, 0.5), [-90, 36, R + 90]); n.put('k0', bx(60, 10, 26, 0.3), [-40, 31, R + 90]);
  } else if (id === 'salar') {
    gtexName = 'salt'; groundRough = 0.85; groundMetal = 0;
    sunDir = new THREE.Vector3(0.75, 0.3, -0.45); sunCol = '#ffd2a0'; sunI = 3.4; hemi = ['#b9c8dc', '#8a7a66', 0.9]; fog = ['#d8c8b4', 0.0019]; exposure = 0.9;
    sky = skyDome({ top: '#4a78b0', hor: '#f0d2b0', bot: '#c9b9a0', sunDir, sunCol: '#fff0d0', sunPow: 500, glow: 1.0 });
    wx = weather({ n: 500, vel: [14, -0.5, 4], col: '#e8dcc8', size: 0.6, alpha: 0.25, sway: 2 });
    scatter(rng.int(9, 13), 26, R - 28, 14, (x, z) => { const w = rng.range(14, 30), d = rng.range(14, 30), h = rng.range(7, 18); box('rock', x, z, w, h, d, 0, true, 1.2); if (rng.chance(0.7)) box('rock', x + rng.range(-3, 3), z + rng.range(-3, 3), w * 0.62, rng.range(5, 12), d * 0.62, h, true, 1.0); });
    scatter(2, 40, R - 50, 24, (x, z, i) => { const ax = rng.chance(0.5); box('rust', x, z, ax ? 46 : 11, 9, ax ? 11 : 46, 0, true, 0.8); n.put('rust', bx(ax ? 10 : 9, 8, ax ? 9 : 10, 0.4), [x + (ax ? 12 : 0), 13, z + (ax ? 0 : 12)]); n.put('dark', cyl(1.4, 1.4, 9, 10), [x + (ax ? 12 : 0), 20, z + (ax ? 0 : 12)]); });
    scatter(8, 20, R - 20, 4, (x, z) => box('rock', x, z, rng.range(4, 7), rng.range(3, 6), rng.range(4, 7), 0, true, 0.8));
    for (let i = 0; i < 26; i++) { const a = i / 26 * PI * 2 + rng.range(-0.08, 0.08), d = R + rng.range(140, 320), h = rng.range(50, 130); n.put('rock', cone(h * rng.range(0.9, 1.5), h, 7), [Math.cos(a) * d, h / 2 - 4, Math.sin(a) * d], [0, rng() * 3, 0]); }
    for (let i = 0; i < 36; i++) { const a = i / 36 * PI * 2; n.put('dark', bx(0.5, 7, 0.5, 0.05), [Math.cos(a) * R, 3.5, Math.sin(a) * R]); n.put('red', bx(0.7, 0.7, 0.7, 0.1), [Math.cos(a) * R, 7.2, Math.sin(a) * R]); }
  } else if (id === 'fundicao') {
    A.circle = false; gtexName = 'scoria'; groundRough = 0.78; groundMetal = 0.3; A.heat = 1;
    sunDir = new THREE.Vector3(-0.3, 0.8, -0.4); sunCol = '#ff9a5a'; sunI = 1.7; hemi = ['#5a3020', '#1a0c08', 0.8]; fog = ['#2a120a', 0.0052]; exposure = 1.05;
    sky = skyDome({ top: '#0c0606', hor: '#5a2410', bot: '#1c0a06', sunDir, sunCol: '#ff7a30', sunPow: 60, glow: 0.5 });
    wx = weather({ n: 600, vel: [1.5, 9, 0.5], col: '#ff8a30', size: 0.5, alpha: 0.9, add: true, sway: 3 });
    // canais de escória (perigo: calor)
    const ch = [];
    const chan = (x0, z0, x1, z1) => { const w = Math.abs(x1 - x0), d = Math.abs(z1 - z0), cx = (x0 + x1) / 2, cz = (z0 + z1) / 2; n.put('lava', bx(w, 0.3, d, 0.02), [cx, 0.12, cz]); A.hazards.push({ type: 'heat', x0: Math.min(x0, x1), x1: Math.max(x0, x1), z0: Math.min(z0, z1), z1: Math.max(z0, z1) }); ch.push([cx, cz, w, d]);
      n.put('dark', bx(w + (w > d ? 0 : 2.4), 0.7, d + (w > d ? 2.4 : 0), 0.1), [cx, 0.05, cz]); };
    const o1 = rng.range(-50, -25), o2 = rng.range(25, 50);
    chan(-R, o1 - 5, R, o1 + 5); chan(o2 - 5, -R * 0.2, o2 + 5, R); chan(-o2 - 4, -R, -o2 + 4, o1 - 5);
    A.lights.push([0, 4, o1, '#ff5a10', 220, 160], [o2, 4, R * 0.4, '#ff5a10', 200, 150]);
    const inChan = (x, z, r) => ch.some(([cx, cz, w, d]) => Math.abs(x - cx) < w / 2 + r && Math.abs(z - cz) < d / 2 + r);
    scatter(4, 30, R - 30, 12, (x, z) => { if (inChan(x, z, 12)) return; box('dark', x, z, 17, 46, 17, 0, true, 0.8); for (let k = 0; k < 4; k++) n.put('lava', bx(k % 2 ? 17.3 : 5, 1.2, k % 2 ? 5 : 17.3, 0.05), [x, 8 + k * 8, z]); n.put('rust', cyl(5, 7, 14, 12), [x, 53, z]); n.put('lava', cyl(4.4, 4.4, 0.4, 12), [x, 60.1, z]); n.put('hz', bx(17.4, 2, 17.4, 0.1), [x, 2.5, z]); });
    scatter(3, 20, R - 30, 16, (x, z) => { if (inChan(x, z, 16)) return; const ax = rng.chance(0.5), w = ax ? 30 : 11, d = ax ? 11 : 30; box('stl', x, z, w, 1.6, d, 12, true, 0.2); n.put('hz', bx(w + 0.3, 0.5, d + 0.3, 0.05), [x, 13.2, z]); for (const sx of [-1, 1]) for (const sz of [-1, 1]) box('stl', x + sx * (w / 2 - 1.5), z + sz * (d / 2 - 1.5), 2, 12, 2, 0, true, 0.15); });
    scatter(7, 18, R - 16, 6, (x, z) => { if (inChan(x, z, 7)) return; if (rng.chance(0.5)) { box('rust', x, z, 9, 9, 9, 0, true, 1.2); n.put('lava', bx(7, 0.3, 7, 0.02), [x, 9.05, z]); } else box('con', x, z, rng.range(6, 12), rng.range(5, 8), rng.range(6, 12)); });
    for (let i = -3; i <= 3; i++) for (const sgn of [-1, 1]) { n.put('rust', bx(46, 60, 8, 0.4), [i * 46, 30, sgn * (R + 5)]); n.put('rust', bx(8, 60, 46, 0.4), [sgn * (R + 5), 30, i * 46]); n.put('win', bx(30, 3, 0.4, 0.02), [i * 46, 38, sgn * (R + 0.9)]); n.put('win', bx(0.4, 3, 30, 0.02), [sgn * (R + 0.9), 22, i * 46]); }
    for (let i = 0; i < 5; i++) { const a = rng() * 7, d = R + rng.range(40, 120); n.put('dark', cyl(5, 8, 150, 10), [Math.cos(a) * d, 75, Math.sin(a) * d]); n.put('lava', cyl(4.5, 4.5, 1, 10), [Math.cos(a) * d, 150.2, Math.sin(a) * d]); }
    uvs.rust = 0.03;
  } else { // boreal
    gtexName = 'snow'; groundRough = 0.7; groundMetal = 0;
    sunDir = new THREE.Vector3(-0.5, 0.42, -0.6); sunCol = '#b9d0ff'; sunI = 2.0; hemi = ['#5a78a8', '#3a4658', 1.0]; fog = ['#3a4c66', 0.0034];
    sky = skyDome({ top: '#060c1c', hor: '#3a5478', bot: '#2a3a50', sunDir, sunCol: '#cfe0ff', sunPow: 700, glow: 0.25, stars: 1.0, aurora: 0.55 });
    wx = weather({ n: 1800, vel: [-7, -9, 3], col: '#ffffff', size: 0.7, alpha: 0.75, sway: 1.5 });
    scatter(5, 26, R - 30, 12, (x, z) => { const ax = rng.chance(0.5), w = ax ? 19 : 9, d = ax ? 9 : 19; box('white', x, z, w, 6.5, d, 1.2, true, 0.5); for (const sx of [-1, 1]) for (const sz of [-1, 1]) n.put('dark', bx(1, 1.6, 1, 0.1), [x + sx * (w / 2 - 1), 0.7, z + sz * (d / 2 - 1)]); A.obstacles[A.obstacles.length - 1].min.y = 0; n.put('win', bx(ax ? 12 : 0.3, 1.2, ax ? 0.3 : 12, 0.02), [x + (ax ? 0 : w / 2), 5, z + (ax ? d / 2 : 0)]); n.put('red', bx(w + 0.2, 0.5, d + 0.2, 0.05), [x, 7.2, z]); A.lights.push([x, 6, z + (ax ? d / 2 + 3 : 0), '#ffd9a0', 60, 50]); });
    scatter(3, 30, R - 30, 4, (x, z) => { box('stl', x, z, 2.6, 56, 2.6, 0, true, 0.1); for (let k = 0; k < 5; k++) n.put('stl', bx(6 - k, 0.3, 0.3, 0.02), [x, 14 + k * 9, z]); n.put('red', bx(0.8, 0.8, 0.8, 0.1), [x, 56.6, z]); n.put('white', cyl(4, 0.6, 2, 14), [x + 2.6, 40, z], [0, 0, -1.1]); });
    scatter(6, 18, R - 20, 6, (x, z) => box('ice', x, z, rng.range(7, 12), rng.range(6, 11), rng.range(7, 12), 0, true, 1.4));
    // tanques de combustível destrutíveis
    const tg = new THREE.CylinderGeometry(5, 5, 9, 18), tm = M({ color: '#d6d2c6', roughness: 0.5, metalness: 0.6, map: ST.map, bumpMap: ST.bump }), bm = M({ color: '#b3261c', roughness: 0.6, metalness: 0.4 });
    scatter(rng.int(5, 7), 24, R - 26, 8, (x, z) => { const g = new THREE.Group(); const t = new THREE.Mesh(tg, tm); t.position.y = 5.6; t.castShadow = t.receiveShadow = true; const b = new THREE.Mesh(new THREE.CylinderGeometry(5.06, 5.06, 1.6, 18), bm); b.position.y = 7; const base = new THREE.Mesh(new THREE.CylinderGeometry(5.6, 5.8, 1.1, 18), mats.dark); base.position.y = 0.55; g.add(t, b, base); g.position.set(x, 0, z); A.group.add(g);
      A.obstacles.push({ min: new THREE.Vector3(x - 4.4, 0, z - 4.4), max: new THREE.Vector3(x + 4.4, 10.1, z + 4.4), alive: true, hp: 500, mesh: g, explosive: { r: 34, dmg: 1100, imp: 900 } }); });
    for (let i = 0; i < 44; i++) { const a = i / 44 * PI * 2, d = R + rng.range(6, 18), h = rng.range(6, 14); n.put('snowm', cone(h * 1.8, h, 6), [Math.cos(a) * d, h / 2 - 1, Math.sin(a) * d], [0, rng() * 3, 0]); if (i % 3 === 0) { n.put('dark', bx(0.4, 9, 0.4, 0.05), [Math.cos(a) * R, 4.5, Math.sin(a) * R]); n.put('red', bx(0.7, 0.7, 0.7, 0.1), [Math.cos(a) * R, 9.2, Math.sin(a) * R]); } }
    mats.snowm = M({ color: '#dfe8f0', roughness: 0.8 });
    for (let i = 0; i < 18; i++) { const a = i / 18 * PI * 2 + rng.range(-0.1, 0.1), d = R + rng.range(200, 420), h = rng.range(70, 170); n.put('snowm', cone(h * rng.range(0.8, 1.3), h, 6), [Math.cos(a) * d, h / 2 - 6, Math.sin(a) * d], [0, rng() * 3, 0]); }
  }

  A.group.add(n.bake(mats, uvs));
  // chão
  const gt = GROUND[gtexName](); const gsz = R * 2 + 900; const gm = M({ map: gt, color: gcol, roughness: groundRough, metalness: groundMetal, bumpMap: gt, bumpScale: 1.5 });
  const rep = gsz / 46; gt.repeat.set(rep, rep);
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(gsz, gsz), gm); ground.rotation.x = -PI / 2; ground.receiveShadow = true; A.group.add(ground);
  // marcações pintadas
  const lm = new THREE.MeshBasicMaterial({ color: id === 'boreal' ? '#b3261c' : id === 'salar' ? '#8a7a66' : '#c9a227', transparent: true, opacity: id === 'salar' ? 0.35 : 0.55, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -1 });
  const ringG = (r0, r1) => { const g = new THREE.RingGeometry(r0, r1, 64); g.rotateX(-PI / 2); const m = new THREE.Mesh(g, lm); m.position.y = 0.04; A.group.add(m); };
  ringG(11, 12); ringG(R * 0.5, R * 0.5 + 0.6); if (A.circle) ringG(R - 2.5, R - 1.5);
  for (const zz of [-R * 0.62, R * 0.62]) { const g = new THREE.RingGeometry(8, 8.7, 4); g.rotateX(-PI / 2); const m = new THREE.Mesh(g, lm); m.position.set(0, 0.04, zz); m.rotation.y = PI / 4; A.group.add(m); }
  // barreira do campo
  const fmat = new THREE.ShaderMaterial({ transparent: true, depthWrite: false, side: THREE.DoubleSide, blending: THREE.AdditiveBlending, uniforms: { time: { value: 0 }, col: { value: new THREE.Color(id === 'fundicao' ? '#ff6a20' : id === 'salar' ? '#ffc070' : '#5ab8ff') } },
    vertexShader: 'varying vec3 vP; void main(){ vP = position; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }',
    fragmentShader: 'varying vec3 vP; uniform float time; uniform vec3 col; void main(){ float h = vP.y / 26.0; float l = step(0.9, fract(vP.y * 0.5 - time * 0.5)); float near = smoothstep(150.0, 25.0, distance(vP, cameraPosition)); float a = (0.025 + l * 0.07) * smoothstep(1.0, 0.0, h) * near + smoothstep(0.06, 0.0, h) * 0.14; gl_FragColor = vec4(col * 1.4, a); }' });
  let fence;
  if (A.circle) fence = new THREE.Mesh(new THREE.CylinderGeometry(R, R, 26, 64, 1, true), fmat); else fence = new THREE.Mesh(new THREE.BoxGeometry(R * 2, 26, R * 2), fmat);
  fence.position.y = 13; if (id !== 'coliseu') A.group.add(fence);
  A.group.add(sky); if (wx) A.group.add(wx);
  // luz
  const sun = new THREE.DirectionalLight(sunCol, sunI); sun.castShadow = true; sun.shadow.mapSize.set(2048, 2048);
  Object.assign(sun.shadow.camera, { left: -90, right: 90, top: 90, bottom: -90, near: 10, far: 500 }); sun.shadow.bias = -0.0006; sun.shadow.normalBias = 0.06;
  A.group.add(sun, sun.target); A.sun = sun; A.sunDir = sunDir.clone().normalize();
  A.group.add(new THREE.HemisphereLight(hemi[0], hemi[1], hemi[2]));
  for (const [x, y, z, c, i, d] of A.lights.slice(0, 4)) { const l = new THREE.PointLight(c, i, d, 1.4); l.position.set(x, y, z); A.group.add(l); }
  A.fog = new THREE.FogExp2(fog[0], fog[1] * (opts.fog ? 3.2 : 1)); A.exposure = exposure;
  // mapa de ambiente a partir do céu
  const es = new THREE.Scene(); const sk2 = sky.clone(); es.add(sk2);
  const gp = new THREE.Mesh(new THREE.PlaneGeometry(4000, 4000), new THREE.MeshBasicMaterial({ color: new THREE.Color(hemi[1]).multiplyScalar(1.5) })); gp.rotation.x = -PI / 2; gp.position.y = -2; es.add(gp);
  const rt = engine.pmrem.fromScene(es, 0, 1, 3000); A.env = rt.texture; A.envRT = rt; gp.geometry.dispose(); gp.material.dispose();
  A.envIntensity = id === 'salar' ? 0.9 : id === 'coliseu' ? 1.3 : 1.1;

  A.spawnP = new THREE.Vector3(0, 0, -R * 0.62); A.spawnE = new THREE.Vector3(0, 0, R * 0.62);
  A.dust = { coliseu: '#55585c', doca: '#5a5c5e', salar: '#e0d6c4', fundicao: '#3a2a22', boreal: '#e6eef4' }[id];
  let t = 0;
  A.update = (dt, cam, focus) => {
    t += dt; sky.material.uniforms.time.value = t; fmat.uniforms.time.value = t; sky.position.copy(cam);
    if (wx) { wx.material.uniforms.time.value = t; wx.material.uniforms.cam.value.copy(cam); }
    sun.target.position.copy(focus); sun.position.copy(focus).addScaledVector(A.sunDir, 220);
  };
  // altura do chão/topo de obstáculo sob um ponto
  A.groundAt = (x, z, y = 1e9, r = 0) => { let g = 0; for (const o of A.obstacles) { if (!o.alive) continue; if (x > o.min.x - r && x < o.max.x + r && z > o.min.z - r && z < o.max.z + r && o.max.y <= y + 1.3 && o.max.y > g) g = o.max.y; } return g; };
  A.inHazard = (x, z) => { for (const h of A.hazards) if (x > h.x0 && x < h.x1 && z > h.z0 && z < h.z1) return h.type; return null; };
  // raio contra obstáculos + chão + limites. retorna distância (ou Infinity) e preenche hit
  A.ray = (o, d, max, hit) => {
    let best = max, ob = null;
    if (d.y < -1e-5) { const tg = -o.y / d.y; if (tg >= 0 && tg < best) { best = tg; ob = 'ground'; } }
    for (const b of A.obstacles) {
      if (!b.alive) continue;
      let t0 = 0, t1 = best, ok = true;
      for (const ax of ['x', 'y', 'z']) {
        const inv = 1 / (d[ax] || 1e-9); let a = (b.min[ax] - o[ax]) * inv, c = (b.max[ax] - o[ax]) * inv; if (a > c) { const q = a; a = c; c = q; }
        if (a > t0) t0 = a; if (c < t1) t1 = c; if (t0 > t1) { ok = false; break; }
      }
      if (ok && t0 < best) { best = t0; ob = b; }
    }
    if (hit) hit.ob = ob;
    return ob ? best : Infinity;
  };
  A.los = (a, b) => { const d = _d.copy(b).sub(a), len = d.length(); d.multiplyScalar(1 / len); return A.ray(a, d, len, null) === Infinity; };
  A.clampPos = (p, r) => {
    if (A.circle) { const d = Math.hypot(p.x, p.z), m = R - r - 1; if (d > m) { p.x *= m / d; p.z *= m / d; return true; } }
    else { const m = R - r - 1; let h = false; if (p.x > m) { p.x = m; h = true; } if (p.x < -m) { p.x = -m; h = true; } if (p.z > m) { p.z = m; h = true; } if (p.z < -m) { p.z = -m; h = true; } return h; }
    return false;
  };
  A.dispose = () => { A.group.traverse(o => { if (o.geometry) o.geometry.dispose(); }); A.disp.forEach(m => m.dispose()); rt.dispose(); if (wx) wx.material.dispose(); sky.material.dispose(); fmat.dispose(); };
  return A;
}
const _d = new THREE.Vector3();
