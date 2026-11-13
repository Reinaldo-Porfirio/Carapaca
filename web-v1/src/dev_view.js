import * as THREE from 'three';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';
import { buildMech, buildPartPreview } from './builder.js';
import { RIVALS, STARTER_BUILD, PARTS } from './data.js';
const q = new URLSearchParams(location.search);
const r = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
r.setSize(innerWidth, innerHeight); r.toneMapping = THREE.ACESFilmicToneMapping; r.shadowMap.enabled = true; r.shadowMap.type = THREE.PCFSoftShadowMap;
document.body.appendChild(r.domElement);
const sc = new THREE.Scene(); sc.background = new THREE.Color('#3a3d42');
sc.environment = new THREE.PMREMGenerator(r).fromScene(new RoomEnvironment(), 0.04).texture; sc.environmentIntensity = 0.7;
const sun = new THREE.DirectionalLight('#fff4e0', 2.6); sun.position.set(20, 40, 30); sun.castShadow = true; sun.shadow.mapSize.set(4096, 4096);
Object.assign(sun.shadow.camera, { left: -60, right: 60, top: 40, bottom: -40, far: 200 }); sun.shadow.bias = -0.0005; sc.add(sun);
const fl = new THREE.Mesh(new THREE.PlaneGeometry(400, 400), new THREE.MeshStandardMaterial({ color: '#55585c', roughness: 0.9 })); fl.rotation.x = -Math.PI / 2; fl.receiveShadow = true; sc.add(fl);
const cam = new THREE.PerspectiveCamera(30, innerWidth / innerHeight, 0.5, 500);
const mode = q.get('m') || 'mechs', from = +(q.get('from') || 0), n = +(q.get('n') || 6), ang = +(q.get('a') || 0.6);
window.ERR = [];
if (mode === 'mechs') {
  const list = [{ build: STARTER_BUILD }, ...RIVALS].slice(from, from + n);
  list.forEach((rv, i) => { try { const m = buildMech(rv.build); m.root.position.x = (i - (list.length - 1) / 2) * 11; m.root.rotation.y = ang; sc.add(m.root); } catch (e) { window.ERR.push(String(e.stack)); } });
  cam.position.set(0, 9, 10 + list.length * 7.2); cam.lookAt(0, 4.6, 0);
} else {
  const cat = q.get('cat'); const list = PARTS.filter(p => p.slot === cat).slice(from, from + n);
  const cols = Math.ceil(Math.sqrt(list.length * 1.8));
  list.forEach((p, i) => { try { const m = buildPartPreview(p.id, STARTER_BUILD.paint); const b = new THREE.Box3().setFromObject(m.root); const c = b.getCenter(new THREE.Vector3()), s = b.getSize(new THREE.Vector3()); const k = 6 / Math.max(s.x, s.y, s.z);
    const g = new THREE.Group(); m.root.position.sub(c); g.add(m.root); g.scale.setScalar(k); g.position.set((i % cols - (cols - 1) / 2) * 9, 4, -Math.floor(i / cols) * 10); g.rotation.y = ang; sc.add(g); } catch (e) { window.ERR.push(p.id + ' ' + String(e.stack)); } });
  cam.position.set(0, 16, 46); cam.lookAt(0, 3, -6);
}
r.render(sc, cam); window.DONE = true;
