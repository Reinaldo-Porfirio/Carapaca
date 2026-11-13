// Hangar: cenário dos menus, garagem e vitrine da loja.
import * as THREE from 'three';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';
import { N, bx, cyl, mkCanvas, mkTex, surfaceTextures, hazardTex } from './geo.js';
import { buildMech, buildPartPreview } from './builder.js';
import { Input } from './input.js';

export class Hangar {
  constructor(engine) {
    this.engine = engine; const sc = this.scene = new THREE.Scene();
    sc.background = new THREE.Color('#0b0c0d'); sc.fog = new THREE.Fog('#0b0c0d', 60, 150);
    sc.environment = engine.pmrem.fromScene(new RoomEnvironment(), 0.04).texture; sc.environmentIntensity = 0.45;
    this.cam = new THREE.PerspectiveCamera(32, 1, 0.5, 400);
    const ST = surfaceTextures(0.55);
    const mats = { fl: new THREE.MeshStandardMaterial({ color: '#34363a', metalness: 0.5, roughness: 0.68, map: ST.map, bumpMap: ST.bump, roughnessMap: ST.rough }), wl: new THREE.MeshStandardMaterial({ color: '#232527', metalness: 0.6, roughness: 0.7, map: ST.map, bumpMap: ST.bump }),
      st: new THREE.MeshStandardMaterial({ color: '#4a4d50', metalness: 0.9, roughness: 0.45, map: ST.map }), hz: new THREE.MeshStandardMaterial({ map: hazardTex(), roughness: 0.7, metalness: 0.3 }),
      lamp: new THREE.MeshBasicMaterial({ color: new THREE.Color('#fff2dc').multiplyScalar(3), toneMapped: false }), amb: new THREE.MeshBasicMaterial({ color: new THREE.Color('#f2a22c').multiplyScalar(2.2), toneMapped: false }) };
    const n = new N('hangar');
    n.put('fl', bx(160, 1, 160, 0.05), [0, -0.5, 0]);
    n.put('st', cyl(9.5, 9.8, 0.5, 40), [0, 0.25, 0]); n.put('hz', cyl(10.4, 10.6, 0.3, 40), [0, 0.15, 0]);
    n.put('wl', bx(160, 60, 2, 0.05), [0, 30, -34]);
    for (let i = -5; i <= 5; i++) { n.put('st', bx(1.6, 60, 2.4, 0.1), [i * 14, 30, -32.5]); n.put('lamp', bx(0.4, 22, 0.3, 0.02), [i * 14 + 7, 20, -32.8]); }
    for (let k = 0; k < 4; k++) n.put('st', bx(160, 1.2, 2.6, 0.1), [0, 8 + k * 12, -32.4]);
    for (const s of [-1, 1]) { // pórtico de manutenção
      n.put('st', bx(2, 26, 2, 0.15), [s * 15, 13, -12]); n.put('st', bx(2, 26, 2, 0.15), [s * 15, 13, -22]); n.put('st', bx(2.4, 1.6, 14, 0.1), [s * 15, 24, -17]); n.put('hz', bx(2.6, 0.8, 14.2, 0.05), [s * 15, 12, -17]);
      n.put('st', bx(8, 1, 1.4, 0.1), [s * 11, 16, -12]); n.put('wl', bx(2.4, 2.4, 2.4, 0.2), [s * 7.6, 15.4, -12]); n.put('amb', bx(0.5, 0.5, 0.5, 0.05), [s * 15, 26.6, -12]);
      n.put('wl', bx(6, 5, 9, 0.2), [s * 26, 2.5, -22]); n.put('wl', bx(5, 3, 5, 0.2), [s * 25, 6.5, -23]); n.put('hz', bx(6.2, 0.6, 9.2, 0.05), [s * 26, 0.5, -22]);
    }
    n.put('st', bx(34, 1.6, 2, 0.1), [0, 27, -12]); n.put('lamp', bx(12, 0.3, 1.2, 0.02), [0, 25.9, -12]);
    sc.add(n.bake(mats, { fl: 0.06, wl: 0.05, st: 0.08, hz: 0.2 }));
    const key = new THREE.DirectionalLight('#fff0dc', 2.6); key.position.set(14, 30, 22); key.castShadow = true; key.shadow.mapSize.set(2048, 2048); Object.assign(key.shadow.camera, { left: -18, right: 18, top: 22, bottom: -6, near: 5, far: 90 }); key.shadow.bias = -0.0005; key.shadow.normalBias = 0.04; sc.add(key);
    const rim = new THREE.DirectionalLight('#f2a22c', 0.6); rim.position.set(-20, 12, -20); sc.add(rim);
    const fill = new THREE.DirectionalLight('#6f9ad8', 0.7); fill.position.set(-16, 8, 20); sc.add(fill);
    sc.add(new THREE.HemisphereLight('#8090a0', '#1a1612', 0.35));
    this.pivot = new THREE.Group(); sc.add(this.pivot);
    this.yaw = 0.6; this.pitch = 0.12; this.dist = 34; this.tDist = 34; this.focusY = 5.2; this.shift = 0; this.tShift = 0; this.auto = true; this.spin = 0.12; this.drag = false;
    this.model = null;
  }
  clear() { if (this.model) { this.pivot.remove(this.model.root); this.model.dispose(); this.model = null; } }
  showMech(build) { this.clear(); try { this.model = buildMech(build); } catch (e) { console.error(e); return; } this.pivot.add(this.model.root); this.model.root.position.set(0, 0.5, 0); this.model.root.scale.setScalar(1); this.focusY = this.model.height * 0.52 + 0.5; this.tDist = 31 + this.model.radius * 1.4; this.kind = 'mech'; }
  showPart(id, paint) {
    this.clear(); let m; try { m = buildPartPreview(id, paint); } catch (e) { console.error(e); return; }
    const b = new THREE.Box3().setFromObject(m.root), c = b.getCenter(new THREE.Vector3()), s = b.getSize(new THREE.Vector3()), k = 9 / Math.max(s.x, s.y, s.z, 0.5);
    const g = new THREE.Group(); m.root.position.copy(c).multiplyScalar(-1); g.add(m.root); g.scale.setScalar(k); g.position.y = 6.5; this.model = { root: g, dispose: m.dispose }; this.pivot.add(g); this.focusY = 6.5; this.tDist = 30; this.kind = 'part';
  }
  view(shift, dist) { this.tShift = shift; if (dist) this.tDist = dist; }
  update(dt) {
    if (Input.btn[0]) { this.yaw -= Input.mdx * 0.006; this.pitch = Math.max(-0.15, Math.min(0.9, this.pitch + Input.mdy * 0.004)); this.idle = 0; } else { this.idle = (this.idle || 0) + dt; if (this.idle > 2.5) { this.swing = (this.swing || 0) + dt; this.yaw += (0.45 + Math.sin(this.swing * 0.22) * 0.85 - this.yaw) * Math.min(1, dt * 0.8); } }
    this.yaw = Math.max(-2.2, Math.min(2.2, this.yaw));
    if (Input.wheel) this.tDist = Math.max(16, Math.min(60, this.tDist + Input.wheel * 3));
    this.dist += (this.tDist - this.dist) * Math.min(1, 5 * dt); this.shift += (this.tShift - this.shift) * Math.min(1, 5 * dt);
    const c = this.cam, cp = Math.cos(this.pitch);
    c.position.set(Math.sin(this.yaw) * cp * this.dist, this.focusY + Math.sin(this.pitch) * this.dist, Math.cos(this.yaw) * cp * this.dist); c.lookAt(0, this.focusY, 0);
    c.aspect = innerWidth / innerHeight; c.setViewOffset(innerWidth, innerHeight, -this.shift * innerWidth, 0, innerWidth, innerHeight);
    if (this.model && this.model.flames) for (const f of this.model.flames) f.m.visible = false;
  }
}
