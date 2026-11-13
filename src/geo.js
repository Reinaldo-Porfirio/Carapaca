// Primitivas de modelagem procedural, texturas geradas em canvas e materiais.
import * as THREE from 'three';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import { mulberry } from './stats.js';

const _m = new THREE.Matrix4(), _q = new THREE.Quaternion(), _e = new THREE.Euler(), _p = new THREE.Vector3(), _s = new THREE.Vector3();

function clean(g) {
  if (g.index) g = g.toNonIndexed();
  for (const k of Object.keys(g.attributes)) if (k !== 'position' && k !== 'normal' && k !== 'uv') g.deleteAttribute(k);
  if (!g.attributes.normal) g.computeVertexNormals();
  if (!g.attributes.uv) g.setAttribute('uv', new THREE.BufferAttribute(new Float32Array(g.attributes.position.count * 2), 2));
  return g;
}

// caixa chanfrada
export function bx(w, h, d, b = 0.05) {
  b = Math.min(b, w * 0.45, h * 0.45, d * 0.45);
  const s = new THREE.Shape();
  const x = w / 2 - b, y = h / 2 - b;
  s.moveTo(-x, -y); s.lineTo(x, -y); s.lineTo(x, y); s.lineTo(-x, y); s.closePath();
  const g = new THREE.ExtrudeGeometry(s, { depth: d - 2 * b, bevelEnabled: true, bevelThickness: b, bevelSize: b, bevelSegments: 1, steps: 1 });
  g.translate(0, 0, -(d - 2 * b) / 2);
  return clean(g);
}
// prisma: perfil 2D extrudado. axis 'x': pts=(z,y) extrusão em X · 'z': pts=(x,y) extrusão em Z · 'y': pts=(x,z) extrusão em Y
export function prism(pts, depth, b = 0.04, axis = 'x') {
  const s = new THREE.Shape();
  pts.forEach((p, i) => i ? s.lineTo(p[0], p[1]) : s.moveTo(p[0], p[1]));
  s.closePath();
  const dd = Math.max(0.01, depth - 2 * b);
  const g = new THREE.ExtrudeGeometry(s, { depth: dd, bevelEnabled: b > 0, bevelThickness: b, bevelSize: b, bevelOffset: -b, bevelSegments: 1, steps: 1 });
  g.translate(0, 0, -dd / 2);
  if (axis === 'x') g.rotateY(-Math.PI / 2);
  else if (axis === 'y') g.rotateX(Math.PI / 2);
  return clean(g);
}
export const cyl = (rt, rb, h, seg = 14, open = false) => clean(new THREE.CylinderGeometry(rt, rb, h, seg, 1, open));
export const cylX = (r, h, seg = 14) => { const g = new THREE.CylinderGeometry(r, r, h, seg); g.rotateZ(Math.PI / 2); return clean(g); };
export const cylZ = (rt, rb, h, seg = 14) => { const g = new THREE.CylinderGeometry(rt, rb, h, seg); g.rotateX(Math.PI / 2); return clean(g); }; // rt em +Z
export const sph = (r, ws = 14, hs = 10, ...a) => clean(new THREE.SphereGeometry(r, ws, hs, ...a));
export const ico = (r, d = 0) => { const g = clean(new THREE.IcosahedronGeometry(r, d)); g.computeVertexNormals(); return g; };
export const tor = (R, r, rs = 8, ts = 20, arc = Math.PI * 2) => clean(new THREE.TorusGeometry(R, r, rs, ts, arc));
export const cone = (r, h, seg = 12) => clean(new THREE.ConeGeometry(r, h, seg));
export function lathe(pts, seg = 16) { return clean(new THREE.LatheGeometry(pts.map(p => new THREE.Vector2(p[0], p[1])), seg)); }
export function plane(w, h, uv) { // uv = [u0,v0,u1,v1]
  const g = new THREE.PlaneGeometry(w, h);
  if (uv) { const a = g.attributes.uv; a.setXY(0, uv[0], uv[3]); a.setXY(1, uv[2], uv[3]); a.setXY(2, uv[0], uv[1]); a.setXY(3, uv[2], uv[1]); }
  return clean(g);
}

// Nó de construção: acumula geometrias por material e funde no final
export class N {
  constructor(name = '') { this.g = new THREE.Group(); this.g.name = name; this.b = {}; this.kids = []; }
  put(mat, geo, p = [0, 0, 0], r = [0, 0, 0], s = 1) {
    _e.set(r[0], r[1], r[2]); _q.setFromEuler(_e); _p.set(p[0], p[1], p[2]);
    if (typeof s === 'number') _s.set(s, s, s); else _s.set(s[0], s[1], s[2]);
    _m.compose(_p, _q, _s); geo.applyMatrix4(_m);
    (this.b[mat] || (this.b[mat] = [])).push(geo);
    return this;
  }
  child(name, p = [0, 0, 0], r = [0, 0, 0]) {
    const n = new N(name); n.g.position.set(p[0], p[1], p[2]); n.g.rotation.set(r[0], r[1], r[2]);
    this.g.add(n.g); this.kids.push(n); return n;
  }
  attach(n, p, r) { if (p) n.g.position.set(p[0], p[1], p[2]); if (r) n.g.rotation.set(r[0], r[1], r[2]); this.g.add(n.g); this.kids.push(n); return n; }
  mount(name, p = [0, 0, 0], r = [0, 0, 0]) {
    const o = new THREE.Object3D(); o.name = name; o.position.set(p[0], p[1], p[2]); o.rotation.set(r[0], r[1], r[2]); this.g.add(o);
    (this.m || (this.m = {}))[name] = o; return o;
  }
  bake(mats, uvs) {
    for (const [k, list] of Object.entries(this.b)) {
      const g = list.length > 1 ? mergeGeometries(list, false) : list[0];
      list.forEach(x => { if (x !== g) x.dispose(); });
      if (k !== 'dc') boxUV(g, (uvs && uvs[k]) || (k === 'hz' ? 0.45 : k === 't' ? 0.5 : 0.17));
      const mesh = new THREE.Mesh(g, mats[k] || mats.c);
      mesh.castShadow = k !== 'g' && k !== 'dc'; mesh.receiveShadow = k !== 'g';
      mesh.userData.mk = k;
      this.g.add(mesh);
    }
    this.b = {};
    for (const c of this.kids) c.bake(mats, uvs);
    return this.g;
  }
}

// projeção UV por eixo dominante da normal (densidade de texel uniforme em todas as peças)
function boxUV(g, sc) {
  const p = g.attributes.position, n = g.attributes.normal, uv = g.attributes.uv;
  for (let i = 0; i < p.count; i++) {
    const ax = Math.abs(n.getX(i)), ay = Math.abs(n.getY(i)), az = Math.abs(n.getZ(i));
    const x = p.getX(i), y = p.getY(i), z = p.getZ(i);
    if (ax >= ay && ax >= az) uv.setXY(i, z * sc, y * sc);
    else if (ay >= az) uv.setXY(i, x * sc, z * sc);
    else uv.setXY(i, x * sc, y * sc);
  }
  uv.needsUpdate = true;
}

// ─────────── detalhes reutilizáveis ───────────
export function vent(n, mat, p, w, h, count, tilt = 0.5, axis = 'z') {
  const st = h / count;
  for (let i = 0; i < count; i++) {
    const y = p[1] - h / 2 + st * (i + 0.5);
    if (axis === 'z') n.put(mat, bx(w, st * 0.45, 0.14, 0.01), [p[0], y, p[2]], [tilt, 0, 0]);
    else n.put(mat, bx(0.14, st * 0.45, w, 0.01), [p[0], y, p[2]], [0, 0, tilt]);
  }
}
export function bolts(n, mat, pts, r = 0.05, axis = 'z') {
  for (const p of pts) {
    const g = axis === 'z' ? cylZ(r, r, 0.08, 6) : axis === 'x' ? cylX(r, 0.08, 6) : cyl(r, r, 0.08, 6);
    n.put(mat, g, p);
  }
}
// cilindro entre dois pontos (pistões, tubos)
export function rod(n, mat, a, b, r = 0.06, seg = 8) {
  const A = new THREE.Vector3(...a), B = new THREE.Vector3(...b);
  const len = A.distanceTo(B); const g = cyl(r, r, len, seg);
  const q = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), B.clone().sub(A).normalize());
  const m = new THREE.Matrix4().compose(A.clone().add(B).multiplyScalar(0.5), q, new THREE.Vector3(1, 1, 1));
  g.applyMatrix4(m);
  (n.b[mat] || (n.b[mat] = [])).push(g);
}
export function piston(n, a, b, r = 0.09) {
  const A = new THREE.Vector3(...a), B = new THREE.Vector3(...b), M = A.clone().lerp(B, 0.55);
  rod(n, 'c', a, M.toArray(), r * 1.5); rod(n, 'd', M.toArray(), b, r);
}

// ─────────── texturas ───────────
const TEX = {};
function canvas(w, h) { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; }
function tex(c, srgb = false, rep = true) {
  const t = new THREE.CanvasTexture(c);
  if (rep) t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.anisotropy = 8; if (srgb) t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

function panelLayout(rng, S) {
  const rects = [];
  const split = (x, y, w, h, d) => {
    const min = 150;
    if (d > 4 || (w < min * 2 && h < min * 2) || (d > 1 && rng.chance(0.22))) { rects.push([x, y, w, h]); return; }
    if ((w > h && w >= min * 2) || h < min * 2) { const c = Math.round(rng.range(0.35, 0.65) * w); split(x, y, c, h, d + 1); split(x + c, y, w - c, h, d + 1); }
    else { const c = Math.round(rng.range(0.35, 0.65) * h); split(x, y, w, c, d + 1); split(x, y + c, w, h - c, d + 1); }
  };
  split(0, 0, S, S, 0);
  return rects;
}

function surfaceTextures(wearLevel) {
  const key = 'surf' + wearLevel;
  if (TEX[key]) return TEX[key];
  const S = 1024, rng = mulberry(1337);
  const rects = panelLayout(rng, S);
  const cc = canvas(S, S), cb = canvas(S, S), cr = canvas(S, S);
  const C = cc.getContext('2d'), Bm = cb.getContext('2d'), R = cr.getContext('2d');
  const W = wearLevel; // 0..1
  C.fillStyle = '#ffffff'; C.fillRect(0, 0, S, S);
  Bm.fillStyle = '#808080'; Bm.fillRect(0, 0, S, S);
  R.fillStyle = `rgb(${150 + W * 30},${150 + W * 30},${150 + W * 30})`; R.fillRect(0, 0, S, S);
  // variação de tom por painel
  for (const [x, y, w, h] of rects) {
    const v = Math.floor(rng.range(240, 255));
    C.fillStyle = `rgb(${v},${v},${v})`; C.fillRect(x, y, w, h);
    const rv = Math.floor(rng.range(120, 190)); R.fillStyle = `rgba(${rv},${rv},${rv},0.5)`; R.fillRect(x, y, w, h);
  }
  // manchas largas de sujeira
  for (let i = 0; i < 60 + W * 120; i++) {
    const x = rng() * S, y = rng() * S, r = rng.range(30, 140);
    const g = C.createRadialGradient(x, y, 0, x, y, r);
    g.addColorStop(0, `rgba(60,48,38,${0.03 + W * 0.07})`); g.addColorStop(1, 'rgba(60,48,38,0)');
    C.fillStyle = g; C.fillRect(x - r, y - r, r * 2, r * 2);
    const g2 = R.createRadialGradient(x, y, 0, x, y, r);
    g2.addColorStop(0, `rgba(235,235,235,${0.1 + W * 0.2})`); g2.addColorStop(1, 'rgba(235,235,235,0)');
    R.fillStyle = g2; R.fillRect(x - r, y - r, r * 2, r * 2);
  }
  // escorridos verticais
  for (let i = 0; i < 120 + W * 260; i++) {
    const x = rng() * S, y = rng() * S, len = rng.range(40, 260), w = rng.range(1, 5);
    const g = C.createLinearGradient(0, y, 0, y + len);
    g.addColorStop(0, `rgba(40,30,24,${0.05 + W * 0.13})`); g.addColorStop(1, 'rgba(40,30,24,0)');
    C.fillStyle = g; C.fillRect(x, y, w, len);
  }
  // linhas de painel
  for (const [x, y, w, h] of rects) {
    C.strokeStyle = 'rgba(18,16,14,0.5)'; C.lineWidth = 1.5; C.strokeRect(x + 1, y + 1, w - 2, h - 2);
    Bm.strokeStyle = '#1c1c1c'; Bm.lineWidth = 4; Bm.strokeRect(x + 1, y + 1, w - 2, h - 2);
    Bm.strokeStyle = '#9a9a9a'; Bm.lineWidth = 1; Bm.strokeRect(x + 5, y + 5, w - 10, h - 10);
    R.strokeStyle = 'rgba(240,240,240,0.9)'; R.lineWidth = 3; R.strokeRect(x + 1, y + 1, w - 2, h - 2);
    // rebites
    if (rng.chance(0.55)) {
      const step = rng.pick([28, 36, 48]);
      for (let px = x + 12; px < x + w - 8; px += step) for (const py of [y + 12, y + h - 12]) {
        Bm.fillStyle = '#d8d8d8'; Bm.beginPath(); Bm.arc(px, py, 3.2, 0, 7); Bm.fill();
        C.fillStyle = 'rgba(20,18,16,0.35)'; C.beginPath(); C.arc(px, py + 1, 3.6, 0, 7); C.fill();
      }
    }
    // tampa de inspeção
    if (w > 130 && h > 130 && rng.chance(0.35)) {
      const hw = rng.range(40, 70), hh = rng.range(30, 60), hx = x + rng.range(20, w - hw - 20), hy = y + rng.range(20, h - hh - 20);
      C.strokeStyle = 'rgba(18,16,14,0.5)'; C.lineWidth = 1.5; C.strokeRect(hx, hy, hw, hh);
      Bm.strokeStyle = '#303030'; Bm.lineWidth = 3; Bm.strokeRect(hx, hy, hw, hh);
      for (const [bxx, byy] of [[hx + 5, hy + 5], [hx + hw - 5, hy + 5], [hx + 5, hy + hh - 5], [hx + hw - 5, hy + hh - 5]]) { Bm.fillStyle = '#404040'; Bm.beginPath(); Bm.arc(bxx, byy, 2.5, 0, 7); Bm.fill(); }
    }
    // lascas de tinta junto às bordas
    const chips = Math.floor((w + h) / 40 * W * 2.2);
    for (let i = 0; i < chips; i++) {
      const edge = rng.int(0, 3), t = rng();
      const px = edge < 2 ? x + t * w : (edge === 2 ? x + rng.range(2, 9) : x + w - rng.range(2, 9));
      const py = edge < 2 ? (edge === 0 ? y + rng.range(2, 9) : y + h - rng.range(2, 9)) : y + t * h;
      const n = rng.int(2, 6);
      for (let k = 0; k < n; k++) {
        const r = rng.range(1, 4.5), ox = rng.range(-6, 6), oy = rng.range(-6, 6);
        C.fillStyle = `rgba(52,50,50,${rng.range(0.5, 0.95)})`; C.beginPath(); C.arc(px + ox, py + oy, r, 0, 7); C.fill();
        R.fillStyle = 'rgba(70,70,70,0.9)'; R.beginPath(); R.arc(px + ox, py + oy, r, 0, 7); R.fill();
        Bm.fillStyle = 'rgba(96,96,96,0.8)'; Bm.beginPath(); Bm.arc(px + ox, py + oy, r, 0, 7); Bm.fill();
      }
    }
  }
  // arranhões
  for (let i = 0; i < 90 + W * 260; i++) {
    const x = rng() * S, y = rng() * S, a = rng.range(0, Math.PI), l = rng.range(8, 70);
    C.strokeStyle = `rgba(${rng.chance(0.5) ? '30,28,26' : '250,250,250'},${rng.range(0.1, 0.35)})`; C.lineWidth = rng.range(0.5, 1.4);
    C.beginPath(); C.moveTo(x, y); C.lineTo(x + Math.cos(a) * l, y + Math.sin(a) * l); C.stroke();
    R.strokeStyle = 'rgba(80,80,80,0.6)'; R.lineWidth = 1; R.beginPath(); R.moveTo(x, y); R.lineTo(x + Math.cos(a) * l, y + Math.sin(a) * l); R.stroke();
  }
  // grão fino
  const id = C.getImageData(0, 0, S, S), d = id.data, ib = Bm.getImageData(0, 0, S, S), db = ib.data;
  for (let i = 0; i < d.length; i += 4) {
    const n = (rng() - 0.5) * 14; d[i] += n; d[i + 1] += n; d[i + 2] += n;
    const n2 = (rng() - 0.5) * 10; db[i] += n2; db[i + 1] += n2; db[i + 2] += n2;
  }
  C.putImageData(id, 0, 0); Bm.putImageData(ib, 0, 0);
  return (TEX[key] = { map: tex(cc, true), bump: tex(cb), rough: tex(cr) });
}

function hazardTex() {
  if (TEX.hz) return TEX.hz;
  const S = 256, c = canvas(S, S), x = c.getContext('2d');
  x.fillStyle = '#d9a514'; x.fillRect(0, 0, S, S);
  x.fillStyle = '#17161a';
  for (let i = -S; i < S * 2; i += 64) { x.beginPath(); x.moveTo(i, 0); x.lineTo(i + 32, 0); x.lineTo(i + 32 - S, S); x.lineTo(i - S, S); x.fill(); }
  const rng = mulberry(9);
  for (let i = 0; i < 500; i++) { x.fillStyle = `rgba(40,34,28,${rng.range(0.1, 0.5)})`; x.beginPath(); x.arc(rng() * S, rng() * S, rng.range(0.5, 4), 0, 7); x.fill(); }
  return (TEX.hz = tex(c, true));
}
function trackTex() {
  if (TEX.tr) return TEX.tr;
  const S = 128, c = canvas(S, S), x = c.getContext('2d');
  x.fillStyle = '#1b1b1d'; x.fillRect(0, 0, S, S);
  for (let i = 0; i < S; i += 32) { x.fillStyle = '#2f2f33'; x.fillRect(0, i + 4, S, 18); x.fillStyle = '#0c0c0d'; x.fillRect(0, i + 24, S, 6); x.fillStyle = '#3d3b38'; x.fillRect(20, i + 6, 22, 14); x.fillRect(86, i + 6, 22, 14); }
  const cb = canvas(S, S), xb = cb.getContext('2d');
  xb.fillStyle = '#404040'; xb.fillRect(0, 0, S, S);
  for (let i = 0; i < S; i += 32) { xb.fillStyle = '#d0d0d0'; xb.fillRect(0, i + 4, S, 18); xb.fillStyle = '#000'; xb.fillRect(0, i + 24, S, 6); }
  return (TEX.tr = { map: tex(c, true), bump: tex(cb) });
}

// atlas de decalques: retorna uv por nome
const DEC = {};
function decalTex() {
  if (TEX.dc) return TEX.dc;
  const S = 1024, c = canvas(S, S), x = c.getContext('2d');
  x.clearRect(0, 0, S, S);
  const put = (name, px, py, w, h, draw) => {
    x.save(); x.translate(px, py); x.beginPath(); x.rect(0, 0, w, h); x.clip(); draw(w, h); x.restore();
    DEC[name] = [px / S, 1 - (py + h) / S, (px + w) / S, 1 - py / S];
  };
  x.fillStyle = '#fff'; x.strokeStyle = '#fff'; x.textBaseline = 'middle'; x.textAlign = 'center';
  const stencil = '700 96px "Saira Condensed","Barlow Condensed","Arial Narrow",Impact,sans-serif';
  for (let i = 0; i < 10; i++) put('n' + i, (i % 5) * 96, Math.floor(i / 5) * 128, 96, 128, (w, h) => { x.font = stencil.replace('96px', '118px'); x.fillText(String(i), w / 2, h / 2 + 6); x.clearRect(0, h / 2 - 3, w, 5); });
  const logos = { QF: ['QF', 'QUARESMA & FILHOS'], HB: ['H·B', 'HALDANE-BRÄCK'], TSK: ['燕', 'TSUBAME KŌKI'], MRS: ['MRS', 'MERIDIANO S.A.'], NLE: ['NLE', 'NORDLYS ENERGI'] };
  Object.entries(logos).forEach(([k, [big, small]], i) => put('mk' + k, 480 + (i % 2) * 272, Math.floor(i / 2) * 110, 256, 100, (w, h) => {
    x.lineWidth = 5; x.strokeRect(4, 4, w - 8, h - 8);
    x.font = stencil.replace('96px', '62px'); x.fillText(big, 62, h / 2 + 2);
    x.fillRect(118, 16, 4, h - 32);
    x.font = '600 19px "Saira Condensed","Arial Narrow",sans-serif'; x.textAlign = 'left'; x.fillText(small, 132, h / 2 - 10);
    x.font = '500 13px "IBM Plex Mono",monospace'; x.fillText('LOTE ' + (4100 + i * 173) + '-B', 132, h / 2 + 14); x.textAlign = 'center';
  }));
  put('warn', 0, 270, 256, 120, (w, h) => {
    x.lineWidth = 6; x.beginPath(); x.moveTo(50, 16); x.lineTo(90, 96); x.lineTo(10, 96); x.closePath(); x.stroke();
    x.font = '700 54px sans-serif'; x.fillText('!', 50, 66);
    x.font = '700 30px "Saira Condensed","Arial Narrow",sans-serif'; x.textAlign = 'left'; x.fillText('PERIGO', 106, 36);
    x.font = '500 17px "Saira Condensed","Arial Narrow",sans-serif'; x.fillText('ALTA TENSÃO · 6,6 kV', 106, 66); x.fillText('NÃO ABRIR EM CARGA', 106, 88); x.textAlign = 'center';
  });
  put('step', 0, 400, 256, 60, (w, h) => { x.lineWidth = 4; x.strokeRect(3, 3, w - 6, h - 6); x.font = '700 34px "Saira Condensed","Arial Narrow",sans-serif'; x.fillText('NÃO PISE', w / 2, h / 2 + 2); });
  put('arrow', 270, 270, 120, 120, (w, h) => { for (let i = 0; i < 3; i++) { x.beginPath(); x.moveTo(20, 24 + i * 30); x.lineTo(60, 4 + i * 30); x.lineTo(100, 24 + i * 30); x.lineTo(100, 40 + i * 30); x.lineTo(60, 20 + i * 30); x.lineTo(20, 40 + i * 30); x.fill(); } });
  put('bar', 0, 470, 256, 56, (w, h) => { const r = mulberry(4); let px = 6; while (px < 150) { const bw = r.int(1, 5); x.fillRect(px, 6, bw, h - 12); px += bw + r.int(1, 4); } x.font = '500 15px "IBM Plex Mono",monospace'; x.textAlign = 'left'; x.fillText('CF-0' + 7731, 160, 18); x.fillText('REV. 4', 160, 38); x.textAlign = 'center'; });
  put('lift', 270, 400, 150, 60, (w, h) => { x.font = '600 20px "Saira Condensed","Arial Narrow",sans-serif'; x.fillText('PONTO DE IÇAMENTO', w / 2, 16); x.lineWidth = 3; x.beginPath(); x.arc(w / 2, 42, 11, 0, 7); x.stroke(); x.beginPath(); x.moveTo(w / 2, 26); x.lineTo(w / 2, 58); x.moveTo(w / 2 - 16, 42); x.lineTo(w / 2 + 16, 42); x.stroke(); });
  put('band', 0, 540, 512, 40, (w, h) => { x.fillRect(0, 6, w, 28); });
  put('tick', 0, 590, 256, 40, (w, h) => { for (let i = 0; i < 20; i++) x.fillRect(6 + i * 12.4, i % 5 === 0 ? 4 : 14, 3, i % 5 === 0 ? 32 : 18); });
  // desgaste: fura a tinta do decalque
  const rng = mulberry(77); x.globalCompositeOperation = 'destination-out';
  for (let i = 0; i < 2600; i++) { x.fillStyle = `rgba(0,0,0,${rng.range(0.2, 0.9)})`; x.beginPath(); x.arc(rng() * S, rng() * 640, rng.range(0.5, 3.2), 0, 7); x.fill(); }
  x.globalCompositeOperation = 'source-over';
  const t = tex(c, true, false);
  return (TEX.dc = t);
}
export function decalUV(name) { decalTex(); return DEC[name]; }
// aplica decalque num nó (plano levemente afastado da superfície)
export function decal(n, name, p, r, w, h) { n.put('dc', plane(w, h, decalUV(name)), p, r); }

const lum = (hex) => { const c = new THREE.Color(hex); return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b; };

export function makeMats(paint = {}) {
  const wear = paint.wear ?? 0.5;
  const T = surfaceTextures(wear > 0.62 ? 1 : wear > 0.3 ? 0.55 : 0.2);
  const std = (color, metal, rough, bump = 0.9) => new THREE.MeshStandardMaterial({ color, metalness: metal, roughness: rough, map: T.map, bumpMap: T.bump, bumpScale: bump, roughnessMap: T.rough, envMapIntensity: 1.0 });
  const glowC = new THREE.Color(paint.glow || '#ff9a3c');
  const tr = trackTex();
  const m = {
    a: std(paint.a || '#8a8f86', 0.5, 0.72),
    b: std(paint.b || '#c9541e', 0.45, 0.7),
    c: std(paint.c || '#2b2e30', 0.75, 0.62, 0.6),
    d: new THREE.MeshStandardMaterial({ color: '#a9adb0', metalness: 1.0, roughness: 0.3, roughnessMap: T.rough, envMapIntensity: 1.2 }),
    k: new THREE.MeshStandardMaterial({ color: '#0e0f10', metalness: 0.3, roughness: 0.85 }),
    w: new THREE.MeshStandardMaterial({ color: '#06090c', metalness: 1.0, roughness: 0.08, envMapIntensity: 1.6 }),
    cer: new THREE.MeshStandardMaterial({ color: '#e9e6dc', metalness: 0.05, roughness: 0.25, bumpMap: T.bump, bumpScale: 0.5 }),
    g: new THREE.MeshBasicMaterial({ color: glowC.clone().multiplyScalar(2.6), toneMapped: false }),
    hz: new THREE.MeshStandardMaterial({ map: hazardTex(), metalness: 0.4, roughness: 0.7, bumpMap: T.bump, bumpScale: 0.5 }),
    t: new THREE.MeshStandardMaterial({ map: tr.map.clone(), bumpMap: tr.bump, bumpScale: 3, metalness: 0.7, roughness: 0.75 }),
    dc: new THREE.MeshStandardMaterial({ map: decalTex(), transparent: true, alphaTest: 0.35, color: lum(paint.a || '#888') > 0.35 ? '#1a1b1d' : '#e8e4d8', metalness: 0.2, roughness: 0.8, polygonOffset: true, polygonOffsetFactor: -4, polygonOffsetUnits: -4, depthWrite: false }),
  };
  m.t.map.needsUpdate = true;
  m.glowColor = glowC;
  m.dispose = () => { for (const k of ['a', 'b', 'c', 'd', 'k', 'w', 'cer', 'g', 'hz', 't', 'dc']) m[k].dispose(); m.t.map.dispose(); };
  return m;
}

// textura circular suave para partículas / brilhos
export function softDot() {
  if (TEX.dot) return TEX.dot;
  const c = canvas(64, 64), x = c.getContext('2d'), g = x.createRadialGradient(32, 32, 0, 32, 32, 32);
  g.addColorStop(0, 'rgba(255,255,255,1)'); g.addColorStop(0.3, 'rgba(255,255,255,0.55)'); g.addColorStop(1, 'rgba(255,255,255,0)');
  x.fillStyle = g; x.fillRect(0, 0, 64, 64);
  return (TEX.dot = tex(c, false, false));
}
export function smokeTex() {
  if (TEX.smoke) return TEX.smoke;
  const c = canvas(128, 128), x = c.getContext('2d'), rng = mulberry(3);
  for (let i = 0; i < 26; i++) {
    const px = 64 + rng.range(-26, 26), py = 64 + rng.range(-26, 26), r = rng.range(14, 36);
    const g = x.createRadialGradient(px, py, 0, px, py, r);
    g.addColorStop(0, 'rgba(255,255,255,0.22)'); g.addColorStop(1, 'rgba(255,255,255,0)');
    x.fillStyle = g; x.fillRect(0, 0, 128, 128);
  }
  return (TEX.smoke = tex(c, false, false));
}
export { canvas as mkCanvas, tex as mkTex, surfaceTextures, hazardTex };
