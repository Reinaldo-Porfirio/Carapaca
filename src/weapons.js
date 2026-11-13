// Lógica de armas: cadência, pente, recarga, calor, carga, travamento de mísseis e disparo.
import * as THREE from 'three';
import { sfxPlay } from './audio.js';
import { clamp } from './stats.js';

const _m = new THREE.Vector3(), _t = new THREE.Vector3(), _d = new THREE.Vector3(), _x = new THREE.Vector3(), _y = new THREE.Vector3(), UP = new THREE.Vector3(0, 1, 0);
const SND = { rifle: 'rifle', smg: 'smg', shotgun: 'shotgun', pistol: 'pistol', flamer: 'flame', glauncher: 'pistol', bazooka: 'heavy', pulsegun: 'pulse', sprayer: 'pistol', saw: 'saw', lrifle: 'laser', arcgun: 'arc', plasma: 'plasma', linear: 'rail', cannon: 'heavy', gatling: 'gatling', lcannon: 'biglaser', pmortar: 'plasma', railgun: 'rail', none: 'rifle' };
const COL = { k: '#ffd9a0', e: '#8fe6ff', x: '#ffb070' };

export class Weapon {
  constructor(mech, def, slot) {
    this.mech = mech; this.def = def; this.slot = slot;
    const scarce = mech.isPlayer && mech.world.mods.scarce ? 0.5 : 1;
    this.ammoMax = def.ammo ? Math.max(1, Math.round(def.ammo * mech.stats.ammoMul * scarce)) : Infinity;
    this.ammo = this.ammoMax; this.mag = def.mag ? Math.min(def.mag, this.ammo) : 0;
    this.cd = 0; this.rel = 0; this.heat = 0; this.over = false; this.chg = 0; this.held = false; this.spinV = 0; this.queue = []; this.sinceShot = 9; this.mzIdx = 0;
    this.charges = def.charges || 0; this.snd = def.wt === 'missile' ? 'missile' : (SND[def.m.k] || (def.wt === 'beam' ? 'laser' : 'rifle'));
    if (def.id === 'wa_laser') this.snd = 'pulse'; if (def.id === 'wa_autocannon') this.snd = 'pistol';
    this.col = def.dt === 'e' ? (def.fx === 'arc' ? '#bfe8ff' : mech.model.mats.glowColor.getStyle()) : COL[def.dt] || '#fff';
    this.disabled = false; this.noteT = 0;
  }
  refill(mul = 1) { if (this.def.ammo) { this.ammoMax = Math.round(this.ammoMax * mul); this.ammo = this.ammoMax; this.mag = this.def.mag ? Math.min(this.def.mag, this.ammo) : 0; this.rel = 0; } if (this.def.charges) this.charges = this.def.charges; }
  interrupt() { this.chg = 0; this.held = false; this.queue.length = 0; }
  dispose() { }
  get armOk() { const s = this.mech.armState(this.slot); return s < 2; }
  canFire() {
    const d = this.def, m = this.mech;
    if (!this.armOk || this.over || this.rel > 0) return false;
    if (d.ammo && this.ammo <= 0) return false;
    if (d.mag && this.mag <= 0) return false;
    if (d.enc && (m.enLock || m.en < d.enc * 0.4)) return false;
    if (d.heavy && (m.legType === 'biped' || m.legType === 'reverse') && !m.grounded) { if (m.isPlayer && this.noteT <= 0 && this.held) { this.noteT = 1.5; m.world.emit({ type: 'note', text: 'ARMA PESADA: ANCORE NO CHÃO' }); } return false; }
    return true;
  }
  update(dt, trig) {
    const d = this.def, m = this.mech, w = m.world;
    this.cd -= dt; this.sinceShot += dt; this.noteT -= dt;
    if (!this.armOk) { this.held = false; return; }
    // recarga e resfriamento
    if (this.rel > 0) { this.rel -= dt; if (this.rel <= 0) { this.mag = Math.min(d.mag, this.ammo); if (m.isPlayer) sfxPlay('equip', null, 0.5); } }
    if (d.ht) { if (this.sinceShot > 0.4) this.heat = Math.max(0, this.heat - d.cool * m.stats.cool * (w.mods.heat ? 0.6 : 1) * (this.over ? 1.4 : 1) * dt); if (this.over && this.heat <= 20) this.over = false; }
    // disparos enfileirados (rajadas / salvas)
    for (let i = this.queue.length - 1; i >= 0; i--) { const q = this.queue[i]; q.t -= dt; if (q.t <= 0) { this.queue.splice(i, 1); q.fn(); } }
    const edge = trig && !this.held, rel = !trig && this.held; this.held = trig;
    const armSt = m.armState(this.slot), rofMul = m.perk.rof * (armSt ? 0.7 : 1);
    switch (d.wt) {
      case 'proj': case 'beam': {
        if (d.spin) { this.spinV = clamp(this.spinV + (trig ? dt / d.spin : -dt * 1.5), 0, 1); if (this.spinV < 1) break; }
        if (d.chg) {
          if (trig && this.cd <= 0 && this.canFire()) { if (this.chg === 0) sfxPlay('charge', m.pos, m.isPlayer ? 0.6 : 0.4); this.chg += dt; m.fireT[this.slot] = 0;
            const k = Math.min(1, this.chg / d.chg.t); m.muzzle(this.slot, _m); w.fx.add.emit(_m.x, _m.y, _m.z, 0, 0, 0, 0.05, (0.6 + k * 2.0) * (d.big ? 1.7 : 1), 0.4, 1.5, 1.8, 2.2, 0.8); }
          else if (rel || (this.chg > 0 && !trig)) { const full = this.chg >= d.chg.t; if ((full || !d.chg.req) && this.cd <= 0 && this.canFire()) this.fire(full ? d.chg.mul : 1, full); this.chg = 0; }
          else if (!trig) this.chg = 0;
        } else if (trig && this.cd <= 0 && this.canFire()) {
          const n = d.burst || 1; this.fire(1, false);
          for (let i = 1; i < n; i++) this.queue.push({ t: i * 0.16, fn: () => { if (m.alive && !m.staggered) this.fire(1, false, true); } });
        }
        break;
      }
      case 'missile': {
        if (this.cd > 0 || this.ammo <= 0) break;
        const guided = d.mk2 === 'guided', need = d.lockT * m.lockTimeMul;
        const locked = m.target && m.lockProg >= need;
        if ((trig && (locked || guided)) || (edge && !m.target)) this.launch(locked ? m.target : null);
        break;
      }
      case 'cone': {
        if (trig && this.canFire()) { m.fireT[this.slot] = 0; this.coneFx(dt); if (this.cd <= 0) { this.cd = 1 / (d.rof * rofMul); this.coneTick(); if (d.mag) { this.mag--; this.ammo--; if (this.mag <= 0 && this.ammo > 0) this.rel = d.rel; } } }
        break;
      }
      case 'melee': {
        if (m.melee || this.cd > 0) { this.chg = 0; break; }
        if (d.enc && (m.enLock || m.en < d.enc * 0.5)) break;
        if (d.chg) { if (trig) { if (this.chg === 0) sfxPlay('charge', m.pos, 0.5); this.chg += dt; } else if (this.chg > 0) { const full = this.chg >= d.chg.t; this.cd = d.cd; m.startMelee(this, full ? d.chg.mul : 1); this.chg = 0; } }
        else if (edge) { this.cd = d.cd; m.startMelee(this, 1); }
        break;
      }
      case 'shield': { if (trig && !m.enLock && m.en > 50) { m.shieldW = this; m.spend(d.drain * dt, true); m.fireT[this.slot] = 0; if (edge) sfxPlay('shield', m.pos, 0.7); this.shieldFx(); } break; }
      case 'drone': { if (edge && this.cd <= 0 && m.target) { this.cd = d.rel; m.fireT[this.slot] = 0; for (let i = 0; i < d.n; i++) w.spawnDrone(m, m.target, d, m.muzzle(this.slot, new THREE.Vector3()), i); sfxPlay('missile', m.pos, 0.8); } break; }
      case 'active': {
        if (!edge || this.cd > 0) break;
        if (d.act === 'flare') { if (this.charges <= 0) break; this.charges--; this.cd = 1.2; if (this.charges <= 0) { this.cd = d.cd; this.charges = d.charges; } w.flare(m); sfxPlay('flare', m.pos, 1); }
        else if (d.act === 'emp') { this.cd = d.cd; w.emp(m, d); }
        break;
      }
    }
  }
  spreadDir(dir, deg) {
    const s = deg * Math.PI / 180; if (s <= 0) return dir;
    _x.crossVectors(dir, UP); if (_x.lengthSq() < 1e-4) _x.set(1, 0, 0); _x.normalize(); _y.crossVectors(_x, dir);
    const a = Math.random() * Math.PI * 2, r = Math.sqrt(Math.random()) * Math.tan(s);
    return dir.addScaledVector(_x, Math.cos(a) * r).addScaledVector(_y, Math.sin(a) * r).normalize();
  }
  fire(mult = 1, charged = false, inBurst = false) {
    const d = this.def, m = this.mech, w = m.world, A = w.arena;
    const armSt = m.armState(this.slot), rofMul = m.perk.rof * (armSt ? 0.7 : 1);
    if (!inBurst) { this.cd = 1 / (d.rof * rofMul); if (d.mag) { this.mag--; if (this.mag <= 0 && this.ammo > 1) this.rel = d.rel || this.cd; } if (d.ammo) this.ammo -= 1; if (d.mag && d.rel === 0) this.mag = Math.min(d.mag, this.ammo); }
    if (d.enc) m.spend(d.enc * (charged ? 1.6 : 1));
    if (d.ht) { this.heat += d.ht * (charged ? 1.8 : 1); if (this.heat >= 100) { this.over = true; this.heat = 100; if (m.isPlayer) { w.emit({ type: 'note', text: 'ARMA SUPERAQUECIDA' }); sfxPlay('warn'); } } }
    this.sinceShot = 0; m.fireT[this.slot] = 0;
    if (this.slot === 'handR') m.recoil.R = Math.min(1, m.recoil.R + 0.25 + d.dmg * mult / 1500); if (this.slot === 'handL') m.recoil.L = Math.min(1, m.recoil.L + 0.25 + d.dmg * mult / 1500);
    if (d.heavy && (m.legType === 'biped' || m.legType === 'reverse')) { m.anchorT = 0.6 * m.stats.anchorMul; m.vel.x *= 0.1; m.vel.z *= 0.1; }
    const mz = m.muzzle(this.slot, _m);
    const grav = d.grav ? 30 * d.grav * A.grav : 0, spd = d.spd || 0;
    const tp = m.aimFor(mz, d.wt === 'beam' ? 0 : spd * (d.rail && charged ? 1.8 : 1), _t, grav);
    _d.copy(tp).sub(mz); if (_d.lengthSq() < 9) _d.set(Math.sin(m.yaw), 0, Math.cos(m.yaw)); _d.normalize();
    const fwd = _x.set(Math.sin(m.yaw), 0, Math.cos(m.yaw)); if (_d.x * fwd.x + _d.z * fwd.z < 0.15) _d.copy(fwd).setY(Math.sin(m.pitch)).normalize();
    const base = _d.clone();
    const sprMul = (armSt ? 2.3 : 1) * (m.stats.armOver && this.slot.startsWith('hand') ? 1.6 : 1) * (m.status.shock.t > 0 ? 2.5 : 1) * (charged ? 0.4 : 1) * (!m.target && m.isPlayer ? 0.6 : 1);
    const dmg = d.dmg * mult, imp = d.imp * (charged ? Math.sqrt(mult) * 1.3 : 1);
    const big = d.heavy || d.dmg * mult > 600;
    sfxPlay(charged && d.wt === 'beam' ? 'biglaser' : this.snd, mz, m.isPlayer ? 1 : 0.8);
    if (d.wt === 'beam') {
      const dir = this.spreadDir(base.clone(), 0.25 * sprMul), range = d.rng * 1.25;
      const hit = w.hitscan(mz, dir, range, m.team);
      const end = _t.copy(mz).addScaledVector(dir, hit.t);
      const wd = (d.big ? 1.3 : d.cont ? 0.14 : 0.3) * (charged && !d.big ? 2.2 : 1);
      w.fx.beam(mz, end, this.col, wd, d.cont ? 0.09 : d.big ? 0.5 : 0.18); w.fx.beam(mz, end, '#ffffff', wd * 0.35, d.cont ? 0.07 : d.big ? 0.4 : 0.14);
      w.fx.light(mz, this.col, big || charged ? 80 : 26, 0.12);
      if (d.fx === 'arc') for (let i = 1; i < 6; i++) w.fx.sparks(_x.copy(mz).lerp(end, i / 6), 3, '#bfe8ff', 9);
      if (hit.mech) hit.mech.takeHit({ dmg, dt: d.dt, imp, part: hit.part, from: m.pos, owner: m, point: end, st: d.st });
      else if (hit.ob && hit.ob !== 'ground' && hit.ob.hp) w.damageObstacle(hit.ob, dmg, m);
      if (hit.t < range) { w.fx.sparks(end, d.cont ? 3 : 14, this.col, 20); if (d.big || charged) { w.fx.explosion(end, d.big ? 7 : 3.5, this.col); if (d.big) w.fx.addShake(0.3); } }
      return;
    }
    const n = d.pel || 1, pk = d.pk;
    for (let i = 0; i < n; i++) {
      const dir = this.spreadDir(base.clone(), d.spr * sprMul);
      const v = spd * (d.rail && charged ? 1.8 : 1);
      w.shoot({ owner: m, team: m.team, def: d, pos: mz.clone(), vel: dir.multiplyScalar(v), dmg, imp, dt: d.dt, pk, spl: d.spl || 0, st: d.st, grav, rng: d.rng * (charged ? 1.4 : 1),
        vis: pk === 'bullet' || pk === 'pulse' || pk === 'shell' ? 't' : pk === 'grenade' ? 'm' : 'p', w: pk === 'shell' ? 0.5 : d.rail ? (charged ? 0.5 : 0.26) : pk === 'pulse' ? 0.3 : pk === 'grenade' ? 1.2 : 0.16 + Math.min(0.2, d.dmg / 1200),
        trail: pk === 'shell' ? 7 : d.rail ? (charged ? 80 : 40) : pk === 'pulse' ? 5 : 16, col: this.col, vsShield: d.vsShield, charged });
    }
    w.fx.muzzle(mz, base, d.dt === 'e' ? this.col : '#ffd9a0', big ? 2.4 : d.pel ? 1.6 : 0.9 + Math.min(0.8, d.dmg / 400));
    if (big) { w.fx.puff(mz, 5, 3, '#555', 0.4, 4, 2, 1.2); if (m.isPlayer) w.fx.addShake(0.3); if (m.grounded) w.fx.dust(m.pos, 6, 5, A.dust); }
  }
  launch(target) {
    const d = this.def, m = this.mech, w = m.world;
    const n = d.n + (d.mk2 !== 'guided' && d.mk2 !== 'cluster' ? m.perk.missile : 0);
    this.cd = d.rel; m.fireT[this.slot] = 0; this.ammo = Math.max(0, this.ammo - n);
    for (let i = 0; i < n; i++) this.queue.push({ t: i * (d.mk2 === 'swarm' ? 0.045 : 0.09), fn: () => {
      if (!m.alive) return;
      const mz = m.muzzle(this.slot, new THREE.Vector3(), this.mzIdx++);
      const f = new THREE.Vector3(Math.sin(m.yaw) * Math.cos(m.pitch), Math.sin(m.pitch), Math.cos(m.yaw) * Math.cos(m.pitch));
      let v;
      if (d.mk2 === 'vertical') v = new THREE.Vector3(f.x * 0.25 + (Math.random() - 0.5) * 0.3, 1, f.z * 0.25 + (Math.random() - 0.5) * 0.3).normalize();
      else if (d.mk2 === 'cluster') v = new THREE.Vector3(f.x, 0.9, f.z).normalize();
      else if (d.mk2 === 'swarm') v = this.spreadDir(new THREE.Vector3(f.x, f.y + 0.45, f.z).normalize(), 24);
      else v = this.spreadDir(f.clone().setY(f.y + 0.08).normalize(), d.mk2 === 'guided' ? 0 : 7);
      w.shoot({ owner: m, team: m.team, def: d, pos: mz, vel: v.multiplyScalar(d.spd * 0.55), dmg: d.dmg, imp: d.imp, dt: d.dt, pk: 'missile', mk: d.mk2, spl: d.spl, target, turn: d.turn, spd: d.spd, vis: 'm', w: d.mk2 === 'guided' || d.mk2 === 'cluster' ? 1.7 : d.mk2 === 'swarm' || this.slot === 'shoulder' ? 0.6 : 1, life: 7, sub: d.sub, seed: Math.random() * 10 });
      sfxPlay('missile', mz, m.isPlayer ? 0.8 : 0.6); w.fx.puff(mz, 2, 2, '#888', 0.4, 2, 1, 0.8); w.fx.light(mz, '#ffb070', 20, 0.1);
    } });
  }
  coneTick() {
    const d = this.def, m = this.mech, w = m.world, mz = m.muzzle(this.slot, _m);
    const dir = _d.copy(m.input.aimPoint).sub(mz).normalize(); if (m.target) dir.copy(m.target.center(_t)).sub(mz).normalize();
    const fwd = _x.set(Math.sin(m.yaw), 0, Math.cos(m.yaw)); if (dir.x * fwd.x + dir.z * fwd.z < 0.2) dir.copy(fwd);
    sfxPlay(this.snd, mz, 0.7);
    const rng = d.rng * m.scale;
    for (const e of w.mechs) {
      if (e.team === m.team || !e.alive) continue;
      const c = e.center(_t), to = _y.copy(c).sub(mz), dist = to.length(); if (dist - e.radius > rng) continue;
      to.multiplyScalar(1 / dist); const ang = Math.acos(clamp(to.dot(dir), -1, 1)), lim = d.ang * Math.PI / 180 + Math.atan2(e.radius, dist);
      if (ang > lim || !w.arena.los(mz, c)) continue;
      const part = Math.random() < 0.55 ? 'core' : ['armR', 'armL', 'legs', 'head'][Math.floor(Math.random() * 4)];
      e.takeHit({ dmg: d.dmg, dt: d.dt, imp: d.imp, part, from: m.pos, owner: m, st: d.st, armorMul: d.armorMul, quiet: true, point: e.partPos(part, new THREE.Vector3()) });
      if (d.fx === 'saw') w.fx.sparks(e.partPos(part, _y), 8, '#ffd28a', 26);
    }
  }
  coneFx(dt) {
    const d = this.def, m = this.mech, w = m.world, mz = m.muzzle(this.slot, _m);
    const dir = _d.copy(m.input.aimPoint).sub(mz).normalize(); if (m.target) dir.copy(m.target.center(_t)).sub(mz).normalize();
    if (d.fx === 'flame') {
      for (let i = 0; i < 4; i++) { const s = 55 + Math.random() * 30; w.fx.add.emit(mz.x, mz.y, mz.z, dir.x * s + (Math.random() - 0.5) * 12, dir.y * s + (Math.random() - 0.5) * 12 + 3, dir.z * s + (Math.random() - 0.5) * 12, d.rng / 70 * (0.7 + Math.random() * 0.5), 1.5, 7, 2.6, 1.1 + Math.random() * 0.6, 0.25, 0.75, 0.8, -6); }
      if (Math.random() < 0.3) w.fx.smk.emit(mz.x + dir.x * d.rng * 0.7, mz.y + dir.y * d.rng * 0.7, mz.z + dir.z * d.rng * 0.7, dir.x * 8, 5, dir.z * 8, 1.2, 4, 10, 0.1, 0.1, 0.1, 0.4, 1, -1);
      w.fx.light(_t.copy(mz).addScaledVector(dir, 12), '#ff8a30', 50, 0.08);
    } else if (Math.random() < 0.5) { const tip = m.model.wn[this.slot] && m.model.wn[this.slot].m.tip; if (tip) { tip.getWorldPosition(_t); w.fx.sparks(_t, 2, '#ffd28a', 12); } }
  }
  shieldFx() {
    const m = this.mech, w = m.world; if (Math.random() > 0.6) return;
    const c = m.center(_m).addScaledVector(_d.set(Math.sin(m.yaw), 0, Math.cos(m.yaw)), m.radius + 1.5);
    _x.set(Math.cos(m.yaw), 0, -Math.sin(m.yaw)); const a = Math.random() * 6.28, r = 3.2 * m.scale;
    w.fx.add.emit(c.x + _x.x * Math.cos(a) * r, c.y + Math.sin(a) * r, c.z + _x.z * Math.cos(a) * r, 0, 0, 0, 0.18, 2.4, 0.6, 0.5, 1.5, 2.4, m.shieldT < 0.3 ? 1 : 0.5);
  }
  // estado para o HUD
  hud() {
    const d = this.def; let ring = 1, state = 'ok', txt = '';
    if (!this.armOk) { state = 'off'; ring = 0; txt = 'DESTRUÍDA'; }
    else if (d.wt === 'passive') { state = 'passive'; txt = 'PASSIVO'; }
    else if (this.over) { state = 'heat'; ring = 1 - this.heat / 100; txt = 'CALOR'; }
    else if (this.rel > 0) { state = 'reload'; ring = 1 - this.rel / (d.rel || 1); txt = 'RECARGA'; }
    else if (d.ammo && this.ammo <= 0) { state = 'empty'; ring = 0; txt = 'VAZIA'; }
    else if (this.chg > 0 && d.chg) { state = 'charge'; ring = Math.min(1, this.chg / d.chg.t); }
    else if (this.cd > 0.25) { const tot = d.wt === 'missile' || d.wt === 'drone' ? d.rel : d.cd || 1 / (d.rof || 1); state = 'cool'; ring = 1 - clamp(this.cd / tot, 0, 1); }
    else if (d.ht) { ring = 1 - this.heat / 100 * 0.999; state = this.heat > 70 ? 'warm' : 'ok'; }
    let ammo = d.wt === 'melee' || d.wt === 'shield' || (d.wt === 'cone' && !d.mag) ? '—' : d.wt === 'active' ? (d.charges ? String(this.charges) : '∞') : !d.ammo ? '∞' : d.mag > 1 ? `${this.mag}/${Math.max(0, this.ammo - this.mag)}` : String(this.ammo);
    let lock = 0; if (d.wt === 'missile' && d.lockT && this.mech.target) lock = clamp(this.mech.lockProg / (d.lockT * this.mech.lockTimeMul), 0, 1);
    return { ring, state, txt, ammo, lock };
  }
}
