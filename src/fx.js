// Renderizador, pós-processamento, partículas, rastros, feixes, luzes e detritos.
import * as THREE from 'three';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/examples/jsm/postprocessing/OutputPass.js';
import { softDot, smokeTex } from './geo.js';

export class Engine {
  constructor(canvas) {
    const r = this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
    r.toneMapping = THREE.ACESFilmicToneMapping; r.toneMappingExposure = 1.0;
    r.shadowMap.enabled = true; r.shadowMap.type = THREE.PCFSoftShadowMap;
    this.pmrem = new THREE.PMREMGenerator(r);
    this.scene = new THREE.Scene(); this.camera = new THREE.PerspectiveCamera(60, 1, 0.5, 2000);
    this.composer = new EffectComposer(r);
    this.rp = new RenderPass(this.scene, this.camera);
    this.bloom = new UnrealBloomPass(new THREE.Vector2(256, 256), 0.55, 0.5, 0.92);
    this.composer.addPass(this.rp); this.composer.addPass(this.bloom); this.composer.addPass(new OutputPass());
    this.quality = 2; this.resize();
    addEventListener('resize', () => this.resize());
  }
  setQuality(q) { this.quality = q; this.renderer.shadowMap.enabled = q > 0; this.bloom.enabled = q > 0; this.resize(); this.scene.traverse(o => { if (o.material) o.material.needsUpdate = true; }); }
  resize() {
    const w = innerWidth, h = innerHeight, pr = Math.min(devicePixelRatio || 1, [1, 1.25, 1.75][this.quality]);
    this.renderer.setPixelRatio(pr); this.renderer.setSize(w, h, false);
    this.composer.setPixelRatio(pr); this.composer.setSize(w, h);
    this.camera.aspect = w / h; this.camera.updateProjectionMatrix();
  }
  use(scene, camera) { this.scene = scene; this.camera = camera; this.rp.scene = scene; this.rp.camera = camera; camera.aspect = innerWidth / innerHeight; camera.updateProjectionMatrix(); }
  render() { if (this.bloom.enabled) this.composer.render(); else this.renderer.render(this.scene, this.camera); }
}

const PVS = `
attribute float size; attribute vec4 col; varying vec4 vCol; uniform float scale; uniform float maxPx;
void main(){ vCol = col; vec4 mv = modelViewMatrix * vec4(position,1.0); float px = size * scale / max(0.1,-mv.z); vCol.a *= clamp(maxPx * 1.6 / max(px, 1.0), 0.0, 1.0); gl_PointSize = min(px, maxPx); if (-mv.z < 2.5) gl_PointSize = 0.0; gl_Position = projectionMatrix * mv; }`;
const PFS = `
uniform sampler2D map; varying vec4 vCol;
void main(){ vec4 t = texture2D(map, gl_PointCoord); gl_FragColor = vec4(vCol.rgb, vCol.a * t.a); if (gl_FragColor.a < 0.004) discard; }`;

class Particles {
  constructor(scene, n, additive) {
    this.n = n; this.i = 0; this.live = 0;
    this.p = new Float32Array(n * 3); this.c = new Float32Array(n * 4); this.s = new Float32Array(n);
    this.v = new Float32Array(n * 3); this.life = new Float32Array(n); this.max = new Float32Array(n);
    this.s0 = new Float32Array(n); this.s1 = new Float32Array(n); this.c0 = new Float32Array(n * 4); this.drag = new Float32Array(n); this.grav = new Float32Array(n);
    const g = this.geo = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(this.p, 3).setUsage(THREE.DynamicDrawUsage));
    g.setAttribute('col', new THREE.BufferAttribute(this.c, 4).setUsage(THREE.DynamicDrawUsage));
    g.setAttribute('size', new THREE.BufferAttribute(this.s, 1).setUsage(THREE.DynamicDrawUsage));
    this.mat = new THREE.ShaderMaterial({ vertexShader: PVS, fragmentShader: PFS, uniforms: { map: { value: additive ? softDot() : smokeTex() }, scale: { value: 600 }, maxPx: { value: 220 } },
      transparent: true, depthWrite: false, blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending });
    this.pts = new THREE.Points(g, this.mat); this.pts.frustumCulled = false; this.pts.renderOrder = additive ? 11 : 10;
    scene.add(this.pts);
  }
  emit(x, y, z, vx, vy, vz, life, s0, s1, r, g, b, a, drag = 0, grav = 0) {
    const i = this.i; this.i = (i + 1) % this.n;
    this.p[i * 3] = x; this.p[i * 3 + 1] = y; this.p[i * 3 + 2] = z;
    this.v[i * 3] = vx; this.v[i * 3 + 1] = vy; this.v[i * 3 + 2] = vz;
    this.life[i] = life; this.max[i] = life; this.s0[i] = s0; this.s1[i] = s1;
    this.c0[i * 4] = r; this.c0[i * 4 + 1] = g; this.c0[i * 4 + 2] = b; this.c0[i * 4 + 3] = a; this.drag[i] = drag; this.grav[i] = grav;
  }
  update(dt) {
    const { n, p, v, life, max, s, s0, s1, c, c0, drag, grav } = this;
    for (let i = 0; i < n; i++) {
      if (life[i] <= 0) { if (s[i] !== 0) { s[i] = 0; c[i * 4 + 3] = 0; } continue; }
      life[i] -= dt; const t = 1 - Math.max(0, life[i]) / max[i], j = i * 3, d = Math.max(0, 1 - drag[i] * dt);
      v[j] *= d; v[j + 1] = v[j + 1] * d - grav[i] * dt; v[j + 2] *= d;
      p[j] += v[j] * dt; p[j + 1] += v[j + 1] * dt; p[j + 2] += v[j + 2] * dt;
      s[i] = s0[i] + (s1[i] - s0[i]) * t;
      const k = i * 4, fade = t < 0.1 ? t * 10 : 1 - (t - 0.1) / 0.9;
      c[k] = c0[k]; c[k + 1] = c0[k + 1]; c[k + 2] = c0[k + 2]; c[k + 3] = c0[k + 3] * fade;
    }
    this.geo.attributes.position.needsUpdate = true; this.geo.attributes.col.needsUpdate = true; this.geo.attributes.size.needsUpdate = true;
  }
}

const _c = new THREE.Color(), _v = new THREE.Vector3(), _v2 = new THREE.Vector3(), _m = new THREE.Matrix4(), _q = new THREE.Quaternion(), _s = new THREE.Vector3(), Z = new THREE.Vector3(0, 0, 1);
const rnd = (a = 1) => (Math.random() - 0.5) * 2 * a;

export class FX {
  constructor(scene, quality = 2) {
    this.scene = scene; this.q = quality;
    this.add = new Particles(scene, quality > 1 ? 4000 : 2200, true);
    this.smk = new Particles(scene, quality > 1 ? 1400 : 700, false);
    // rastros de projétil (instanciados)
    const tg = new THREE.BoxGeometry(1, 1, 1); tg.translate(0, 0, -0.5);
    this.tr = new THREE.InstancedMesh(tg, new THREE.MeshBasicMaterial({ color: '#ffffff', blending: THREE.AdditiveBlending, transparent: true, depthWrite: false, toneMapped: false }), 500);
    this.tr.instanceMatrix.setUsage(THREE.DynamicDrawUsage); this.tr.frustumCulled = false; this.tr.count = 0;
    this.tr.setColorAt(0, _c.set('#fff')); scene.add(this.tr);
    const mg = new THREE.CylinderGeometry(0.16, 0.2, 1.6, 6); mg.rotateX(Math.PI / 2);
    this.ms = new THREE.InstancedMesh(mg, new THREE.MeshStandardMaterial({ color: '#c8c8c0', metalness: 0.6, roughness: 0.4 }), 200);
    this.ms.instanceMatrix.setUsage(THREE.DynamicDrawUsage); this.ms.frustumCulled = false; this.ms.count = 0; scene.add(this.ms);
    // feixes
    this.beams = [];
    const bg = new THREE.CylinderGeometry(1, 1, 1, 8, 1, true); bg.rotateX(Math.PI / 2); bg.translate(0, 0, 0.5);
    for (let i = 0; i < 16; i++) { const m = new THREE.Mesh(bg, new THREE.MeshBasicMaterial({ color: '#fff', blending: THREE.AdditiveBlending, transparent: true, depthWrite: false, toneMapped: false })); m.visible = false; m.frustumCulled = false; scene.add(m); this.beams.push({ m, life: 0, max: 1, w: 1 }); }
    // anéis de choque
    this.rings = [];
    const rg = new THREE.RingGeometry(0.86, 1, 40); rg.rotateX(-Math.PI / 2);
    for (let i = 0; i < 10; i++) { const m = new THREE.Mesh(rg, new THREE.MeshBasicMaterial({ color: '#fff', blending: THREE.AdditiveBlending, transparent: true, depthWrite: false, side: THREE.DoubleSide, toneMapped: false })); m.visible = false; scene.add(m); this.rings.push({ m, life: 0, max: 1, r: 1 }); }
    // esferas de pulso
    this.orbs = [];
    const og = new THREE.SphereGeometry(1, 24, 14);
    for (let i = 0; i < 4; i++) { const m = new THREE.Mesh(og, new THREE.MeshBasicMaterial({ color: '#fff', blending: THREE.AdditiveBlending, transparent: true, depthWrite: false, side: THREE.BackSide, toneMapped: false })); m.visible = false; scene.add(m); this.orbs.push({ m, life: 0, max: 1, r: 1 }); }
    // luzes dinâmicas (quantidade fixa: sem recompilar shaders)
    this.lights = [];
    for (let i = 0; i < (quality > 0 ? 4 : 2); i++) { const l = new THREE.PointLight('#fff', 0, 80, 1.6); scene.add(l); this.lights.push({ l, life: 0, max: 1, i0: 0 }); }
    // marcas no chão
    this.scorch = [];
    const sg = new THREE.PlaneGeometry(1, 1); sg.rotateX(-Math.PI / 2);
    const smat = new THREE.MeshBasicMaterial({ map: softDot(), color: '#000', transparent: true, opacity: 0.7, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -2 });
    for (let i = 0; i < 28; i++) { const m = new THREE.Mesh(sg, smat.clone()); m.visible = false; m.renderOrder = 1; scene.add(m); this.scorch.push({ m, life: 0 }); }
    this.si = 0;
    // detritos
    this.debris = [];
    const dg = new THREE.BoxGeometry(1, 1, 1);
    this.db = new THREE.InstancedMesh(dg, new THREE.MeshStandardMaterial({ color: '#77736c', metalness: 0.7, roughness: 0.55 }), 90);
    this.db.instanceMatrix.setUsage(THREE.DynamicDrawUsage); this.db.count = 0; this.db.castShadow = true; this.db.frustumCulled = false; this.db.setColorAt(0, _c.set('#fff')); scene.add(this.db);
    this.shake = 0; this.bulletList = []; this.missileList = [];
  }
  setViewport(h, fov) { const sc = h / (2 * Math.tan(fov * Math.PI / 360)); this.add.mat.uniforms.scale.value = sc; this.smk.mat.uniforms.scale.value = sc; const mp = Math.min(260, h * 0.3); this.add.mat.uniforms.maxPx.value = mp; this.smk.mat.uniforms.maxPx.value = mp; }

  light(pos, color, intensity, life) {
    let best = this.lights[0]; for (const L of this.lights) if (L.life < best.life) best = L;
    if (best.life > 0 && best.i0 > intensity * 2) return;
    best.l.position.copy(pos); best.l.color.set(color); best.i0 = intensity; best.life = best.max = life; best.l.intensity = intensity;
  }
  beam(a, b, color, width, life) {
    let B = this.beams.find(x => x.life <= 0) || this.beams[0];
    B.m.position.copy(a); B.m.lookAt(b); const len = a.distanceTo(b);
    B.m.scale.set(width, width, len); B.m.material.color.set(color).multiplyScalar(2.2); B.m.material.opacity = 1; B.m.visible = true; B.life = B.max = life; B.w = width; B.len = len;
    return B;
  }
  ring(pos, color, r, life) {
    const R = this.rings.find(x => x.life <= 0) || this.rings[0];
    R.m.position.copy(pos); R.m.material.color.set(color).multiplyScalar(1.6); R.m.visible = true; R.life = R.max = life; R.r = r; R.m.scale.setScalar(0.1);
  }
  orb(pos, color, r, life) {
    const O = this.orbs.find(x => x.life <= 0) || this.orbs[0];
    O.m.position.copy(pos); O.m.material.color.set(color).multiplyScalar(1.4); O.m.visible = true; O.life = O.max = life; O.r = r; O.m.scale.setScalar(0.1);
  }
  mark(pos, r) {
    const S = this.scorch[this.si]; this.si = (this.si + 1) % this.scorch.length;
    S.m.position.set(pos.x, pos.y + 0.06, pos.z); S.m.scale.set(r * 2, 1, r * 2); S.m.rotation.y = Math.random() * 6; S.m.visible = true; S.life = 30; S.m.material.opacity = 0.75;
  }
  sparks(p, n, color = '#ffc070', speed = 22, dir = null, size = 1) {
    _c.set(color); const A = this.add;
    for (let i = 0; i < n; i++) {
      let vx = rnd(speed), vy = rnd(speed) + speed * 0.3, vz = rnd(speed);
      if (dir) { vx += dir.x * speed; vy += dir.y * speed; vz += dir.z * speed; }
      A.emit(p.x, p.y, p.z, vx, vy, vz, 0.25 + Math.random() * 0.5, 0.5 * size, 0.1, _c.r * 2.5, _c.g * 2.5, _c.b * 2.5, 1, 1.5, 34);
    }
  }
  puff(p, n, size, color = '#444', a = 0.5, spread = 2, up = 2, life = 1.6) {
    _c.set(color);
    for (let i = 0; i < n; i++) this.smk.emit(p.x + rnd(spread * 0.3), p.y + rnd(spread * 0.3), p.z + rnd(spread * 0.3), rnd(spread), up + rnd(spread * 0.5), rnd(spread), life * (0.7 + Math.random() * 0.6), size * 0.5, size * (1.6 + Math.random()), _c.r, _c.g, _c.b, a * 0.62, 1.2, -0.4);
  }
  muzzle(p, dir, color = '#ffd9a0', size = 1) {
    _c.set(color); const A = this.add;
    A.emit(p.x, p.y, p.z, dir.x * 6, dir.y * 6, dir.z * 6, 0.05, 1.7 * size, 0.7 * size, _c.r * 3, _c.g * 3, _c.b * 3, 0.9);
    for (let i = 0; i < 3; i++) A.emit(p.x, p.y, p.z, dir.x * (30 + i * 22) + rnd(5), dir.y * (30 + i * 22) + rnd(5), dir.z * (30 + i * 22) + rnd(5), 0.05, 0.9 * size, 0.2, _c.r * 3, _c.g * 3, _c.b * 3, 0.8, 6);
    this.light(p, color, 18 * size, 0.06);
  }
  explosion(p, r, color = '#ffb060', big = false) {
    _c.set(color); const A = this.add, n = Math.min(60, Math.floor(10 + r * 3));
    A.emit(p.x, p.y, p.z, 0, 0, 0, 0.14, r * 2.0, r * 3.2, 3, 2.6, 2.0, 0.9);
    for (let i = 0; i < n; i++) {
      const sp = r * (2 + Math.random() * 4);
      _v.set(rnd(1), rnd(1) + 0.3, rnd(1)).normalize();
      A.emit(p.x, p.y, p.z, _v.x * sp, _v.y * sp, _v.z * sp, 0.3 + Math.random() * 0.5, r * 1.3, r * 0.4, _c.r * 2.4, _c.g * 2.0, _c.b * 1.6, 0.9, 3.2, 0);
    }
    this.sparks(p, Math.floor(n * 0.6), '#ffd28a', r * 4, null, 0.9);
    this.puff(p, Math.floor(6 + r * 0.6), r * 1.6, '#2c2a28', 0.55, r * 0.9, r * 0.5, 2.4);
    this.ring(_v.set(p.x, Math.max(0.3, p.y - r * 0.3), p.z), color, r * 1.6, 0.35);
    this.light(p, color, 60 + r * 14, 0.3 + r * 0.012);
    if (p.y < r * 0.8) this.mark(_v.set(p.x, 0, p.z), r * 0.9);
    if (big) { this.orb(p, color, r * 1.2, 0.3); }
  }
  thrust(p, dir, color, size, speed = 30) {
    _c.set(color);
    this.add.emit(p.x, p.y, p.z, dir.x * speed + rnd(2), dir.y * speed + rnd(2), dir.z * speed + rnd(2), 0.12 + Math.random() * 0.1, size * 1.6, size * 0.3, _c.r * 2, _c.g * 2, _c.b * 2, 0.8, 2);
  }
  dust(p, n, size = 3, color = '#8a8272') { this.puff(p, n, size, color, 0.28, size, 1, 1.4); }
  spawnDebris(p, n, color = '#77736c', speed = 20, size = 0.6) {
    for (let i = 0; i < n; i++) {
      if (this.debris.length >= 90) this.debris.shift();
      this.debris.push({ p: new THREE.Vector3(p.x + rnd(1), p.y + rnd(1), p.z + rnd(1)), v: new THREE.Vector3(rnd(speed), Math.random() * speed, rnd(speed)), r: new THREE.Euler(rnd(3), rnd(3), rnd(3)), w: new THREE.Vector3(rnd(8), rnd(8), rnd(8)),
        s: new THREE.Vector3(size * (0.4 + Math.random()), size * (0.2 + Math.random() * 0.6), size * (0.4 + Math.random() * 1.2)), life: 6 + Math.random() * 4, c: new THREE.Color(color).multiplyScalar(0.6 + Math.random() * 0.6) });
    }
  }
  update(dt, groundAt) {
    this.add.update(dt); this.smk.update(dt);
    for (const B of this.beams) if (B.life > 0) { B.life -= dt; const t = Math.max(0, B.life / B.max); B.m.scale.set(B.w * t, B.w * t, B.len); B.m.material.opacity = t; if (B.life <= 0) B.m.visible = false; }
    for (const R of this.rings) if (R.life > 0) { R.life -= dt; const t = 1 - Math.max(0, R.life / R.max); R.m.scale.setScalar(R.r * (0.15 + t)); R.m.material.opacity = (1 - t) * 0.9; if (R.life <= 0) R.m.visible = false; }
    for (const O of this.orbs) if (O.life > 0) { O.life -= dt; const t = 1 - Math.max(0, O.life / O.max); O.m.scale.setScalar(O.r * (0.2 + t * 0.9)); O.m.material.opacity = (1 - t) * 0.7; if (O.life <= 0) O.m.visible = false; }
    for (const L of this.lights) { if (L.life > 0) { L.life -= dt; L.l.intensity = L.i0 * Math.max(0, L.life / L.max); } else L.l.intensity = 0; }
    for (const S of this.scorch) if (S.life > 0) { S.life -= dt; if (S.life < 5) S.m.material.opacity = 0.75 * S.life / 5; if (S.life <= 0) S.m.visible = false; }
    // detritos
    let n = 0;
    for (let i = this.debris.length - 1; i >= 0; i--) {
      const d = this.debris[i]; d.life -= dt; if (d.life <= 0) { this.debris.splice(i, 1); continue; }
      d.v.y -= 30 * dt; d.p.addScaledVector(d.v, dt);
      const gy = (groundAt ? groundAt(d.p.x, d.p.z) : 0) + d.s.y * 0.5;
      if (d.p.y < gy) { d.p.y = gy; d.v.y *= -0.35; d.v.x *= 0.6; d.v.z *= 0.6; d.w.multiplyScalar(0.5); if (Math.abs(d.v.y) < 1) d.v.y = 0; }
      d.r.x += d.w.x * dt; d.r.y += d.w.y * dt; d.r.z += d.w.z * dt;
    }
    for (const d of this.debris) { _q.setFromEuler(d.r); _s.copy(d.s); if (d.life < 1) _s.multiplyScalar(d.life); _m.compose(d.p, _q, _s); this.db.setMatrixAt(n, _m); this.db.setColorAt(n, d.c); n++; }
    this.db.count = n; this.db.instanceMatrix.needsUpdate = true; if (this.db.instanceColor) this.db.instanceColor.needsUpdate = true;
    this.shake = Math.max(0, this.shake - dt * 2.2);
  }
  // desenha projéteis vivos (chamado pelo combate a cada quadro)
  drawProjectiles(list) {
    let nt = 0, nm = 0;
    for (const p of list) {
      if (p.vis === 't') {
        if (nt >= 500) continue;
        _v.copy(p.vel).normalize(); _q.setFromUnitVectors(Z, _v);
        const len = Math.min(p.trail, p.travel);
        _s.set(p.w, p.w, len); _m.compose(p.pos, _q, _s); this.tr.setMatrixAt(nt, _m); this.tr.setColorAt(nt, p.col); nt++;
      } else if (p.vis === 'm') {
        if (nm >= 200) continue;
        _v.copy(p.vel).normalize(); _q.setFromUnitVectors(Z, _v); _s.setScalar(p.w); _m.compose(p.pos, _q, _s); this.ms.setMatrixAt(nm, _m); nm++;
      }
    }
    this.tr.count = nt; this.tr.instanceMatrix.needsUpdate = true; if (this.tr.instanceColor) this.tr.instanceColor.needsUpdate = true;
    this.ms.count = nm; this.ms.instanceMatrix.needsUpdate = true;
  }
  addShake(a) { this.shake = Math.min(1.6, this.shake + a); }
}
