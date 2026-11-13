// Mundo de combate: projéteis, mísseis, explosões, drones, raios e colisão entre carcaças.
import * as THREE from 'three';
import { FX } from './fx.js';
import { buildDrone } from './builder.js';
import { sfxPlay } from './audio.js';
import { clamp } from './stats.js';

const _a = new THREE.Vector3(), _b = new THREE.Vector3(), _c = new THREE.Vector3(), _d = new THREE.Vector3(), _hit = {}, UP = new THREE.Vector3(0, 1, 0);

export class World {
  constructor(engine, arena, mods = {}) {
    this.engine = engine; this.arena = arena; this.mods = mods; this.scene = new THREE.Scene();
    this.scene.add(arena.group); this.scene.fog = arena.fog; this.scene.environment = arena.env; this.scene.environmentIntensity = arena.envIntensity;
    if (mods.lowgrav) arena.grav = 0.45;
    this.fx = new FX(this.scene, engine.quality);
    this.mechs = []; this.projs = []; this.drones = []; this.events = []; this.time = 0; this.camPos = new THREE.Vector3();
  }
  emit(e) { this.events.push(e); }
  add(m) { this.mechs.push(m); return m; }
  shoot(p) {
    p.travel = 0; p.life = p.life || 5; p.col = new THREE.Color(p.col || '#ffd9a0').multiplyScalar(p.pk === 'pulse' ? 2.4 : 2); p.trail = p.trail || 14; p.t = 0; p.smokeT = 0;
    this.projs.push(p); return p;
  }
  // raio contra zonas de acerto das carcaças inimigas
  rayMechs(o, d, max, team, skip) {
    let best = null, bt = max;
    for (const m of this.mechs) {
      if (!m.alive || m.team === team || m === skip) continue;
      const cx = m.pos.x - o.x, cy = m.pos.y + m.height * 0.5 - o.y, cz = m.pos.z - o.z, proj = cx * d.x + cy * d.y + cz * d.z;
      const R = m.height * 0.75 + 2; if (proj < -R || proj > bt + R) continue;
      const px = cx - d.x * proj, py = cy - d.y * proj, pz = cz - d.z * proj; if (px * px + py * py + pz * pz > R * R) continue;
      const s = Math.sin(m.yaw), c = Math.cos(m.yaw), sc = m.scale;
      for (const z of m.model.hz) {
        if (z.part !== 'legs' && z.part !== 'core' && m.parts[z.part].state === 2) continue;
        const ox = o.x - (m.pos.x + (z.o.x * c + z.o.z * s) * sc), oy = o.y - (m.pos.y + z.o.y * sc), oz = o.z - (m.pos.z + (-z.o.x * s + z.o.z * c) * sc), r = z.r * sc;
        const b = ox * d.x + oy * d.y + oz * d.z, cc = ox * ox + oy * oy + oz * oz - r * r, disc = b * b - cc; if (disc < 0) continue;
        let t = -b - Math.sqrt(disc); if (t < 0) { if (cc < 0) t = 0; else continue; }
        if (t < bt) { bt = t; best = { t, mech: m, part: z.part }; }
      }
    }
    return best;
  }
  hitscan(o, d, max, team) {
    const hit = {}; let t = this.arena.ray(o, d, max, hit); const mh = this.rayMechs(o, d, Math.min(max, t), team, null);
    if (mh) return { t: mh.t, mech: mh.mech, part: mh.part };
    return { t: Math.min(t, max), ob: t < max ? hit.ob : null };
  }
  damageObstacle(ob, dmg, owner) {
    if (!ob || !ob.hp || !ob.alive) return; ob.hp -= dmg;
    if (ob.hp <= 0) { ob.alive = false; if (ob.mesh) ob.mesh.visible = false; const c = _a.set((ob.min.x + ob.max.x) / 2, (ob.min.y + ob.max.y) / 2, (ob.min.z + ob.max.z) / 2).clone();
      if (ob.explosive) { this.explode(c, ob.explosive.r, ob.explosive.dmg, 'x', ob.explosive.imp, null, { heat: 60 }, -1, true); this.fx.spawnDebris(c, 16, '#d6d2c6', 40, 1.4); } }
  }
  explode(pos, r, dmg, dt, imp, owner, st, team, big = false, skip = null) {
    const fx = this.fx; fx.explosion(pos, r, dt === 'e' ? (owner ? owner.model.mats.glowColor.getStyle() : '#8fe6ff') : '#ffb060', big || r > 12);
    sfxPlay(r > 12 ? 'bigexplosion' : 'explosion', pos, clamp(r / 9, 0.5, 1.3));
    const dc = pos.distanceTo(this.camPos); fx.addShake(clamp(r * 3.5 / (12 + dc), 0, 0.8));
    for (const m of this.mechs) {
      if (!m.alive || m.team === team || m === skip) continue;
      let bd = 1e9, bp = 'core';
      for (const z of m.model.hz) { const d = m.partPos(z.part, _b).distanceTo(pos) - z.r * m.scale; if (d < bd) { bd = d; bp = z.part; } }
      if (bd > r) continue; if (!this.arena.los(pos.y < 1 ? _c.copy(pos).setY(1.5) : pos, m.center(_b))) continue;
      const f = 1 - 0.65 * Math.max(0, bd) / r;
      m.takeHit({ dmg: dmg * f, dt, imp: imp * f, part: bp, from: pos, owner, st, quiet: true });
      if (m.alive) { _b.copy(m.pos).sub(pos).setY(0).normalize(); m.vel.addScaledVector(_b, clamp(dmg * f / m.weight * 0.9, 0, 26)); }
    }
    for (const o of this.arena.obstacles) if (o.alive && o.hp) { const cx = (o.min.x + o.max.x) / 2, cz = (o.min.z + o.max.z) / 2; if (Math.hypot(cx - pos.x, cz - pos.z) < r + 5) this.damageObstacle(o, dmg, owner); }
  }
  clearProjectilesNear(c, r, team) { for (const p of this.projs) if (p.team !== team && p.pos.distanceTo(c) < r) { p.dead = true; this.fx.sparks(p.pos, 4, '#9fe0ff', 10); } }
  flare(m) {
    const c = m.center(_a).clone();
    for (let i = 0; i < 10; i++) { const a = Math.random() * 6.28; this.fx.add.emit(c.x, c.y + 3, c.z, Math.cos(a) * 26, 14 + Math.random() * 12, Math.sin(a) * 26, 1.6 + Math.random(), 5, 1.5, 3, 2.4, 1.4, 1, 1.2, 16); }
    this.fx.light(c, '#ffe0a0', 80, 0.5);
    for (const p of this.projs) if (p.pk === 'missile' && p.target === m && p.mk !== 'guided' && Math.random() < 0.8 && p.pos.distanceTo(c) < 160) { p.target = null; p.vel.y += 20; }
  }
  emp(m, d) {
    const c = m.center(_a).clone(); this.fx.orb(c, '#9fe8ff', d.rad, 0.5); this.fx.ring(c, '#9fe8ff', d.rad, 0.5); this.fx.sparks(c, 50, '#bfe8ff', 50); sfxPlay('emp', c, 1); this.fx.light(c, '#9fe8ff', 150, 0.4);
    for (const e of this.mechs) { if (e.team === m.team || !e.alive) continue; if (e.center(_b).distanceTo(c) < d.rad + e.radius) { e.takeHit({ dmg: d.dmg, dt: 'e', imp: 200, part: 'core', from: c, owner: m, vsShield: 5 }); e.addStatus('shock', d.shock); } }
    this.clearProjectilesNear(c, d.rad * 0.7, m.team);
  }
  spawnDrone(owner, target, def, pos, i) {
    const mesh = buildDrone(owner.model.mats); this.scene.add(mesh); mesh.position.copy(pos);
    this.drones.push({ owner, target, def, mesh, pos: pos.clone(), vel: new THREE.Vector3((Math.random() - 0.5) * 20, 30, (Math.random() - 0.5) * 20), life: def.life, cd: 0.8 + i * 0.25, ang: i * 2.1 + Math.random(), rad: 26 + i * 5, h: 11 + i * 3, dir: i % 2 ? 1 : -1 });
  }
  update(dt) {
    this.time += dt; const A = this.arena, fx = this.fx;
    for (const m of this.mechs) m.update(dt);
    // separação entre carcaças
    for (let i = 0; i < this.mechs.length; i++) for (let j = i + 1; j < this.mechs.length; j++) {
      const a = this.mechs[i], b = this.mechs[j]; if (!a.alive || !b.alive) continue;
      const dx = b.pos.x - a.pos.x, dz = b.pos.z - a.pos.z, d = Math.hypot(dx, dz), min = a.radius + b.radius;
      if (d >= min || Math.abs(a.pos.y - b.pos.y) > Math.max(a.height, b.height) * 0.8) continue;
      const nx = d > 0.01 ? dx / d : 1, nz = d > 0.01 ? dz / d : 0, push = (min - d), wa = b.weight / (a.weight + b.weight);
      a.pos.x -= nx * push * wa; a.pos.z -= nz * push * wa; b.pos.x += nx * push * (1 - wa); b.pos.z += nz * push * (1 - wa);
    }
    // projéteis
    const g0 = 30 * A.grav;
    for (let i = this.projs.length - 1; i >= 0; i--) {
      const p = this.projs[i]; p.t += dt; p.life -= dt;
      if (p.dead || p.life <= 0) { if (p.spl && !p.dead && p.pk !== 'missile') this.explode(p.pos, p.spl, p.dmg, p.dt, p.imp, p.owner, p.st, p.team); this.projs.splice(i, 1); continue; }
      if (p.pk === 'missile') this.steer(p, dt);
      if (p.grav) p.vel.y -= p.grav * dt;
      const sp = p.vel.length(), len = sp * dt; _d.copy(p.vel).multiplyScalar(1 / Math.max(1e-6, sp));
      let tA = A.ray(p.pos, _d, len, _hit); const ob = _hit.ob;
      const mh = this.rayMechs(p.pos, _d, Math.min(len, tA), p.team, null);
      // espoleta de proximidade
      let prox = false;
      if (!mh && p.spl && p.target && p.target.alive && p.pk === 'missile') { if (p.target.center(_a).distanceTo(p.pos) < 3.2 + p.target.radius * 0.6) prox = true; }
      if (p.sub && p.target && p.target.alive && p.t > 0.6 && p.target.center(_a).distanceTo(p.pos) < 60) { this.split(p); this.projs.splice(i, 1); continue; }
      if (mh || prox) {
        const pt = _a.copy(p.pos).addScaledVector(_d, mh ? mh.t : 0).clone();
        const fall = p.pk === 'missile' || p.spl ? 1 : (p.travel <= p.rng ? 1 : Math.max(0.35, 1 - (p.travel - p.rng) / (p.rng * 0.8)));
        if (mh) mh.mech.takeHit({ dmg: p.dmg * fall, dt: p.dt, imp: p.imp * (fall < 1 ? fall * 0.6 : 1), part: mh.part, from: p.owner ? p.owner.pos : p.pos, owner: p.owner, st: p.st, point: pt, vsShield: p.vsShield });
        if (p.spl) this.explode(pt, p.spl, p.dmg * 0.6, p.dt, p.imp * 0.5, p.owner, p.st, p.team, false, mh ? mh.mech : null);
        else { fx.sparks(pt, fall < 1 ? 3 : 7, fall < 1 ? '#aaa' : (p.dt === 'e' ? p.col.getStyle() : '#ffd28a'), 22, _b.copy(_d).negate().multiplyScalar(0.4)); if (p.dmg > 500) fx.explosion(pt, 3, '#ffd28a'); }
        this.projs.splice(i, 1); continue;
      }
      if (tA !== Infinity) {
        const pt = _a.copy(p.pos).addScaledVector(_d, tA).clone();
        if (p.spl) this.explode(pt, p.spl, p.dmg, p.dt, p.imp, p.owner, p.st, p.team);
        else { fx.sparks(pt, 5, '#ffd28a', 16, _b.copy(_d).negate().multiplyScalar(0.3)); if (ob === 'ground') { fx.dust(pt, 1, 2.5, A.dust); } if (ob && ob.hp) this.damageObstacle(ob, p.dmg, p.owner); if (Math.random() < 0.3) sfxPlay('hit', pt, 0.4); }
        this.projs.splice(i, 1); continue;
      }
      p.pos.addScaledVector(_d, len); p.travel += len;
      if ((p.pk !== 'missile' && !p.spl && p.travel > p.rng * 2.2) || Math.abs(p.pos.x) > A.size + 30 || Math.abs(p.pos.z) > A.size + 30 || p.pos.y > 400) { this.projs.splice(i, 1); continue; }
      // rastro visual
      if (p.pk === 'missile') { p.smokeT -= dt; if (p.smokeT <= 0) { p.smokeT = 0.03; const s = p.w; fx.smk.emit(p.pos.x, p.pos.y, p.pos.z, (Math.random() - 0.5) * 3, (Math.random() - 0.5) * 3, (Math.random() - 0.5) * 3, 0.9, 1.2 * s, 4 * s, 0.75, 0.75, 0.75, 0.35, 1, -1); fx.add.emit(p.pos.x - _d.x * 1.2, p.pos.y - _d.y * 1.2, p.pos.z - _d.z * 1.2, 0, 0, 0, 0.06, 3 * s, 1, 2.6, 1.5, 0.6, 1); } }
      else if (p.pk === 'plasma') { fx.add.emit(p.pos.x, p.pos.y, p.pos.z, 0, 0, 0, 0.07, 6, 3, p.col.r, p.col.g, p.col.b, 1); fx.add.emit(p.pos.x, p.pos.y, p.pos.z, (Math.random() - 0.5) * 8, (Math.random() - 0.5) * 8, (Math.random() - 0.5) * 8, 0.3, 2.5, 0.4, p.col.r, p.col.g, p.col.b, 0.7); }
      else if (p.pk === 'glob') { fx.add.emit(p.pos.x, p.pos.y, p.pos.z, 0, 0, 0, 0.07, 4, 2, 0.8, 2.2, 0.4, 1); fx.smk.emit(p.pos.x, p.pos.y, p.pos.z, 0, -2, 0, 0.5, 1.5, 3, 0.45, 0.65, 0.2, 0.5); }
      else if (p.pk === 'shell' || p.pk === 'grenade') { p.smokeT -= dt; if (p.smokeT <= 0) { p.smokeT = 0.03; fx.smk.emit(p.pos.x, p.pos.y, p.pos.z, 0, 0, 0, 0.6, 1, 3, 0.6, 0.6, 0.6, 0.3, 1, -1); } }
      else if (p.def && p.def.rail && p.charged) fx.add.emit(p.pos.x, p.pos.y, p.pos.z, 0, 0, 0, 0.35, 2, 0.3, p.col.r, p.col.g, p.col.b, 0.6);
    }
    // drones
    for (let i = this.drones.length - 1; i >= 0; i--) {
      const D = this.drones[i]; D.life -= dt; const t = D.target;
      if (D.life <= 0 || !t || !t.alive || !D.owner.alive) { fx.sparks(D.pos, 12, '#ffd28a', 14); fx.puff(D.pos, 3, 2, '#444', 0.5, 2, 1, 1); this.scene.remove(D.mesh); D.mesh.traverse(o => { if (o.geometry) o.geometry.dispose(); }); this.drones.splice(i, 1); continue; }
      D.ang += D.dir * dt * 1.1; const tc = t.center(_a);
      _b.set(tc.x + Math.cos(D.ang) * D.rad, Math.max(tc.y + D.h, A.groundAt(D.pos.x, D.pos.z, 1e9, 2) + 6), tc.z + Math.sin(D.ang) * D.rad).sub(D.pos);
      D.vel.addScaledVector(_b, 6 * dt).multiplyScalar(Math.max(0, 1 - 2.2 * dt)); D.pos.addScaledVector(D.vel, dt);
      D.mesh.position.copy(D.pos); D.mesh.lookAt(tc);
      D.cd -= dt;
      if (D.cd <= 0) { D.cd = 1 / D.def.rof; _c.copy(tc).sub(D.pos); const dist = _c.length(); _c.multiplyScalar(1 / dist); _c.x += (Math.random() - 0.5) * 0.06; _c.y += (Math.random() - 0.5) * 0.06; _c.normalize();
        const h = this.hitscan(D.pos, _c, dist + 20, D.owner.team); const end = _b.copy(D.pos).addScaledVector(_c, h.t);
        fx.beam(D.pos, end, D.owner.model.mats.glowColor.getStyle(), 0.14, 0.1); sfxPlay('pulse', D.pos, 0.5);
        if (h.mech) h.mech.takeHit({ dmg: D.def.dmg, dt: 'e', imp: D.def.imp, part: h.part, from: D.pos, owner: D.owner, point: end.clone() }); }
    }
    fx.drawProjectiles(this.projs);
    fx.update(dt, (x, z) => A.groundAt(x, z, 1e9, 0));
  }
  steer(p, dt) {
    const sp = p.vel.length(); let tgt = null;
    if (p.mk === 'guided') { if (p.owner && p.owner.alive) tgt = _a.copy(p.owner.input.aimPoint); }
    else if (p.target && p.target.alive && !p.target.cloaked) {
      const t = p.target; tgt = t.center(_a);
      if (p.mk === 'vertical') { if (p.t < 0.75) tgt = null; else tgt.y += t.height * 0.45; }
      if (tgt) { const d = tgt.distanceTo(p.pos); tgt.addScaledVector(t.vel, Math.min(0.7, d / Math.max(40, sp) * 0.6));
        if (p.mk === 'swarm' && d > 40) { tgt.x += Math.sin(p.t * 4 + p.seed) * 14; tgt.y += Math.cos(p.t * 3 + p.seed * 2) * 9 + 6; tgt.z += Math.cos(p.t * 4 + p.seed) * 14; }
        if (p.mk === 'direct' && d > 60) tgt.y += 5; }
    } else if (p.mk === 'vertical' && p.t > 0.9 && !p.lost) { p.lost = true; p.vel.y = -sp * 0.6; }
    const nsp = Math.min(p.spd * (p.mk === 'vertical' && p.t > 0.75 ? 1.6 : 1.25), sp + p.spd * 1.8 * dt);
    if (tgt) {
      _b.copy(tgt).sub(p.pos).normalize(); _c.copy(p.vel).multiplyScalar(1 / sp);
      const ang = Math.acos(clamp(_b.dot(_c), -1, 1)); let turn = p.turn * (p.mk === 'vertical' && p.t > 0.75 && p.t < 1.5 ? 2.2 : 1) * dt;
      if (p.target && p.target.stats.ecm) turn *= 1 - p.target.stats.ecm;
      if (ang > 1e-4) _c.lerp(_b, Math.min(1, turn / ang)).normalize();
      p.vel.copy(_c).multiplyScalar(nsp);
    } else p.vel.multiplyScalar(nsp / sp);
  }
  split(p) {
    this.fx.sparks(p.pos, 20, '#ffd28a', 20); this.fx.puff(p.pos, 5, 3, '#999', 0.4, 3, 1, 1); sfxPlay('missile', p.pos, 0.9);
    const base = p.vel.clone().normalize();
    for (let i = 0; i < p.sub; i++) {
      const v = base.clone(); v.x += (Math.random() - 0.5) * 0.5; v.y += (Math.random() - 0.5) * 0.3; v.z += (Math.random() - 0.5) * 0.5; v.normalize().multiplyScalar(p.spd * 1.1);
      this.shoot({ owner: p.owner, team: p.team, def: p.def, pos: p.pos.clone(), vel: v, dmg: p.dmg, imp: p.imp, dt: p.dt, pk: 'missile', mk: 'direct', spl: p.spl, target: p.target, turn: p.turn * 1.5, spd: p.spd * 1.3, vis: 'm', w: 0.6, life: 3.5, seed: Math.random() * 10 });
    }
  }
  dispose() {
    for (const m of this.mechs) m.dispose();
    for (const D of this.drones) { this.scene.remove(D.mesh); }
    this.scene.traverse(o => { if (o.isInstancedMesh || o.isPoints) { o.geometry.dispose(); if (o.material.dispose) o.material.dispose(); } });
    this.arena.dispose();
  }
}
