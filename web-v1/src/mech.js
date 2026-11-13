// Entidade de combate: movimento, energia, travamento, dano por partes, status, utilitários e animação.
import * as THREE from 'three';
import { buildMech, poseLegs, buildHookHead } from './builder.js';
import { computeStats, weaponDefs, clamp, lerp, partsOf } from './stats.js';
import { Weapon } from './weapons.js';
import { sfxPlay } from './audio.js';

const V = () => new THREE.Vector3();
const _a = V(), _b = V(), _c = V(), _d = V(), UP = new THREE.Vector3(0, 1, 0);
export const PARTS5 = ['head', 'core', 'armR', 'armL', 'legs'];
export const PART_PT = { head: 'Cabeça', core: 'Tronco', armR: 'Braço D', armL: 'Braço E', legs: 'Pernas' };
const angDiff = (a, b) => { let d = a - b; while (d > Math.PI) d -= Math.PI * 2; while (d < -Math.PI) d += Math.PI * 2; return d; };

export class Mech {
  constructor(world, build, o = {}) {
    this.world = world; this.build = build; this.team = o.team ?? 1; this.isPlayer = !!o.player; this.name = o.name || build.name || 'CARCAÇA'; this.call = o.call || '';
    this.scale = o.scale || 1; this.hpMul = o.hpMul || 1;
    const st = this.stats = computeStats(build); this.P = partsOf(build);
    this.model = buildMech(build); this.model.root.scale.setScalar(this.scale);
    world.scene.add(this.model.root);
    this.pos = V(); this.vel = V(); this.yaw = 0; this.pitch = 0; this.legYaw = 0;
    this.grounded = true; this.airT = 0; this.alive = true; this.deadT = 0;
    this.perk = { k: 1, e: 1 + st.eb, x: 1, rof: 1, imp: 1, en: 1, qb: 1, salvage: 0, stab: 1, missile: 0, direct: 0, shock: 0, burn: 0, speed: 1, ammo: 1 };
    const wm = world.mods;
    this.stMax = this.st = st.structure * this.hpMul;
    this.parts = {};
    for (const k of PARTS5) { const a = st.partArmor[k] * (this.team !== 0 && wm.hardened ? 1.4 : 1) * (this.hpMul > 1 ? 1 + (this.hpMul - 1) * 0.6 : 1); this.parts[k] = { a, max: a, integ: a * 0.6, state: 0, smokeT: 0 }; }
    this.enMax = this.en = st.enCap; this.enWait = 0; this.enLock = false;
    this.qbT = 0; this.qbFx = 0; this.abOn = false; this.ascending = false; this.anchorT = 0;
    this.impact = 0; this.impactT = 9; this.staggerT = 0; this.staggerImm = 0;
    this.status = { heat: { v: 0, t: 0, idle: 9 }, shock: { v: 0, t: 0, idle: 9 }, corr: { v: 0, t: 0, idle: 9 } };
    this.kits = this.isPlayer && wm.norepair ? 0 : (o.kits ?? st.kits); this.kitCd = 0;
    this.input = { mx: 0, mz: 0, jump: false, jumpP: false, qb: false, ab: false, fire: { handR: false, handL: false, backR: false, backL: false, shoulder: false }, util: false, repair: false, yaw: 0, aimDir: new THREE.Vector3(0, 0, 1), aimPoint: V(), aimFree: true };
    this.target = null; this.lockProg = 0; this.hardLock = false; this.trk = { p: V(), v: V(), ok: false }; this.aimErr = V(); this.aimErrT = 0; this.aimSkill = 1;
    this.melee = null; this.hook = null; this.barrier = { t: 0, hp: 0, max: 1 }; this.cloakT = 0; this.shieldW = null; this.shieldT = 0;
    this.utilCd = 0; this.utilCharges = this.P.util && this.P.util.charges || 0;
    this.phase = 0; this.recoil = { R: 0, L: 0 }; this.fireT = { handR: 9, handL: 9, backR: 9, backL: 9 }; this.lastHitT = 9; this.lastDmgFrom = null; this.dmgTaken = 0; this.dmgDealt = 0;
    this.weapons = {};
    const wd = weaponDefs(build);
    for (const k of ['handR', 'handL', 'backR', 'backL', 'shoulder']) if (wd[k]) this.weapons[k] = new Weapon(this, wd[k], k);
    this.height = this.model.height * this.scale; this.radius = this.model.radius * this.scale; this.aimY = this.model.aimY * this.scale;
    this.isTank = st.isTank; this.legType = st.legType;
    this.cable = null; this.shieldMesh = null; this.barrierMesh = null;
    this.stepSide = 0; this.thrT = 0;
  }
  get staggered() { return this.staggerT > 0; }
  get cloaked() { return this.cloakT > 0; }
  get weight() { return this.stats.weight * this.scale; }
  center(out = _a) { return out.set(this.pos.x, this.pos.y + this.aimY, this.pos.z); }
  partPos(part, out = V()) { const z = this.model.hz.find(h => h.part === part); out.copy(z.o).multiplyScalar(this.scale).applyAxisAngle(UP, this.yaw).add(this.pos); return out; }
  muzzle(slot, out = V(), idx = 0) { let m = this.model.mz[slot]; if (Array.isArray(m)) m = m[idx % m.length]; if (m) m.getWorldPosition(out); else this.center(out); return out; }

  // ───── modificadores derivados do estado das partes ─────
  get lockRange() { const h = this.parts.head.state; return this.stats.lockRange * (h === 2 ? 0.3 : h === 1 ? 0.55 : 1) * (this.world.mods.emstorm ? 0.5 : 1); }
  get lockTimeMul() { return this.stats.lockTime * (this.parts.head.state ? 1.8 : 1); }
  get speedMul() { const l = this.parts.legs.state; return (l === 2 ? 0.45 : l === 1 ? 0.72 : 1) * (this.cloaked ? 1.35 : 1) * this.perk.speed; }
  armState(slot) { return slot === 'handR' ? this.parts.armR.state : slot === 'handL' ? this.parts.armL.state : 0; }

  update(dt) {
    const w = this.world, I = this.input, S = this.stats, A = w.arena;
    if (!this.alive) { this.updateDead(dt); return; }
    // ── temporizadores e status ──
    this.qbT -= dt; this.qbFx -= dt; this.kitCd -= dt; this.utilCd -= dt; this.lastHitT += dt; this.impactT += dt; this.anchorT -= dt; this.staggerImm -= dt;
    if (this.staggerT > 0) { this.staggerT -= dt; if (this.staggerT <= 0) { this.impact = 0; } }
    else if (this.impactT > 2.2) this.impact = Math.max(0, this.impact - this.stabMax * 0.35 * dt);
    for (const k of ['heat', 'shock', 'corr']) { const s = this.status[k]; s.idle += dt; if (s.t > 0) s.t -= dt; else if (s.idle > 2) s.v = Math.max(0, s.v - 10 * dt); }
    if (this.status.heat.t > 0) { this.damageRaw(52 * dt, null); if (Math.random() < dt * 14) w.fx.thrust(this.center(_a).add(_b.set((Math.random() - 0.5) * 4, (Math.random() - 0.5) * 5, (Math.random() - 0.5) * 4)), UP, '#ff7a20', 2.2, 6); }
    if (this.status.corr.t > 0 && Math.random() < dt * 8) w.fx.puff(this.center(_a), 1, 2.4, '#7aa838', 0.35, 2.5, 1, 1);
    if (this.cloakT > 0) { this.cloakT -= dt; if (this.cloakT <= 0) this.setCloak(false); }
    if (this.barrier.t > 0) { this.barrier.t -= dt; if (this.barrier.t <= 0) this.dropBarrier(false); }
    const hz = this.grounded ? A.inHazard(this.pos.x, this.pos.z) : null;
    if (hz === 'heat') { this.addStatus('heat', 48 * dt); this.damageRaw(24 * dt, null); }
    if (w.mods.acid && this.vel.lengthSq() < 30 && A.groundAt(this.pos.x, this.pos.z, 1e9, 0) <= this.pos.y + 1) this.addStatus('corr', 9 * dt);
    const stg = this.staggered;
    if (!this.alive) return;

    // ── reparo ──
    if (I.repair && this.kits > 0 && this.kitCd <= 0 && !stg && this.st < this.stMax) {
      this.kits--; this.kitCd = 1.6; this.st = Math.min(this.stMax, this.st + this.stMax * 0.38);
      if (S.kitArmor) for (const k of PARTS5) { const p = this.parts[k]; if (p.state < 2) { p.a = Math.min(p.max, p.a + p.max * S.kitArmor); if (p.state === 1 && p.a > 0) p.state = 0; } }
      this.status.heat.t = 0; this.status.corr.t = 0;
      sfxPlay('repair', this.pos); w.fx.ring(_a.copy(this.pos).setY(this.pos.y + 1), '#7dffb0', this.radius * 3.5, 0.6);
      for (let i = 0; i < 16; i++) w.fx.thrust(this.center(_a).add(_b.set((Math.random() - 0.5) * 6, (Math.random() - 0.5) * 8, (Math.random() - 0.5) * 6)), UP, '#7dffb0', 1.6, 8);
      if (this.isPlayer) w.emit({ type: 'note', text: 'REPARO APLICADO' });
    }

    // ── orientação ──
    const turn = (this.isTank ? 4.5 : 8) * (stg ? 0 : 1);
    if (!this.melee) this.yaw += clamp(angDiff(I.yaw, this.yaw), -turn * dt, turn * dt);

    // ── movimento ──
    const g = 30 * A.grav, sp = S.boostSpeed * this.speedMul;
    const sy = Math.sin(this.yaw), cy = Math.cos(this.yaw);
    let wx = 0, wz = 0;
    const canMove = !stg && this.anchorT <= 0 && !this.melee && !(this.hook && this.hook.phase === 'pull');
    if (canMove) { const fy = Math.sin(I.yaw), fc = Math.cos(I.yaw); wx = fy * I.mz - fc * I.mx; wz = fc * I.mz + fy * I.mx; const l = Math.hypot(wx, wz); if (l > 1) { wx /= l; wz /= l; } }
    const wishLen = Math.hypot(wx, wz);
    const canEn = !this.enLock && this.en > 0;
    // impulso rápido
    if (I.qb && this.qbT <= 0 && canMove && canEn && this.parts.legs.state < 2) {
      let dx = wx, dz = wz; if (wishLen < 0.1) { dx = Math.sin(this.yaw); dz = Math.cos(this.yaw); } else { dx /= wishLen; dz /= wishLen; }
      const q = S.qbSpeed * this.speedMul; this.vel.x = dx * q; this.vel.z = dz * q; if (!this.grounded && this.vel.y < 0) this.vel.y *= 0.3;
      this.spend(S.qbCost * this.perk.qb * (this.parts.legs.state ? 1.3 : 1)); this.qbT = S.qbReload * (this.perk.qb < 1 ? 0.8 : 1); this.qbFx = 0.28; this.qbDir = _d.set(dx, 0, dz).clone();
      this.abOn = false; sfxPlay('qb', this.pos, this.isPlayer ? 1 : 0.7);
      w.fx.dust(_a.copy(this.pos).setY(this.pos.y + 0.5), this.grounded ? 8 : 0, 4, A.dust);
      for (let i = 0; i < 14; i++) w.fx.thrust(this.center(_a).add(_b.set((Math.random() - 0.5) * 3, (Math.random() - 0.5) * 3 - 1, (Math.random() - 0.5) * 3)), _c.set(-dx, 0.05, -dz), this.model.flameCol, 3, 40 + Math.random() * 40);
      w.fx.light(this.center(_a), this.model.flameCol, 40, 0.2);
      if (this.isPlayer) w.fx.addShake(0.12);
    }
    // sobreimpulso
    if (I.ab && canMove) { if (this.abOn) this.abOn = false; else if (canEn && this.en > this.enMax * 0.2) { this.abOn = true; sfxPlay('qb', this.pos, 0.8); } }
    if (this.abOn) {
      if (!canEn || stg || I.mz < -0.5 || this.melee) this.abOn = false;
      else { this.spend(430 * dt, true); _a.copy(I.aimDir); if (this.grounded && _a.y < 0.1) { _a.y = 0.1; } _a.normalize().multiplyScalar(S.abSpeed * this.speedMul); this.vel.x = lerp(this.vel.x, _a.x, Math.min(1, 5 * dt)); this.vel.y = lerp(this.vel.y, _a.y, Math.min(1, 5 * dt)); this.vel.z = lerp(this.vel.z, _a.z, Math.min(1, 5 * dt)); this.grounded = false; }
    }
    // gancho puxando
    if (this.hook) this.updateHook(dt);
    const pulling = this.hook && this.hook.phase === 'pull';
    if (!this.abOn && !pulling && !(this.melee && this.melee.phase === 'lunge')) {
      const hv = Math.hypot(this.vel.x, this.vel.z);
      const tx = wx * sp, tz = wz * sp;
      if (hv > sp * 1.05) { const d = Math.max(0, 1 - 3.4 * dt); this.vel.x *= d; this.vel.z *= d; if (wishLen > 0.1) { this.vel.x += wx * 30 * dt; this.vel.z += wz * 30 * dt; } }
      else { const acc = (this.grounded ? 95 : 60) * (stg ? 0.4 : 1) * dt; const dx = tx - this.vel.x, dz = tz - this.vel.z, dl = Math.hypot(dx, dz); if (dl > acc) { this.vel.x += dx / dl * acc; this.vel.z += dz / dl * acc; } else { this.vel.x = tx; this.vel.z = tz; } }
      // salto e subida
      this.ascending = false;
      if (I.jumpP && this.grounded && canMove) { this.vel.y = S.jump * (this.parts.legs.state === 2 ? 0.5 : 1) * (A.grav < 1 ? 1.25 : 1); this.grounded = false; this.airT = 0; sfxPlay('jump', this.pos, 0.7); w.fx.dust(this.pos, 6, 4, A.dust); }
      else if (I.jump && !this.grounded && this.airT > 0.12 && canEn && canMove) {
        const cost = (this.legType === 'quad' ? 300 : 520); this.spend(cost * dt, true);
        const maxUp = 21 * S.upThrust; if (this.vel.y < maxUp) this.vel.y = Math.min(maxUp, this.vel.y + (g + 62 * S.upThrust) * dt); this.ascending = true;
      }
      this.vel.y -= g * dt; if (this.vel.y < -58) this.vel.y = -58;
      if (this.legType === 'quad' && !this.grounded && this.vel.y < -9 && I.jump && canEn) this.vel.y = -9;
    }
    // integração e colisão
    this.pos.addScaledVector(this.vel, dt);
    const r = this.radius;
    for (const o of A.obstacles) {
      if (!o.alive || this.pos.y >= o.max.y - 1.3 || this.pos.y + this.height * 0.8 <= o.min.y) continue;
      const cx = clamp(this.pos.x, o.min.x, o.max.x), cz = clamp(this.pos.z, o.min.z, o.max.z);
      let dx = this.pos.x - cx, dz = this.pos.z - cz; const d2 = dx * dx + dz * dz;
      if (d2 >= r * r) continue;
      if (d2 > 1e-6) { const d = Math.sqrt(d2); dx /= d; dz /= d; this.pos.x = cx + dx * r; this.pos.z = cz + dz * r; }
      else { const pl = this.pos.x - o.min.x, pr = o.max.x - this.pos.x, pb = this.pos.z - o.min.z, pf = o.max.z - this.pos.z, m = Math.min(pl, pr, pb, pf); if (m === pl) { this.pos.x = o.min.x - r; dx = -1; dz = 0; } else if (m === pr) { this.pos.x = o.max.x + r; dx = 1; dz = 0; } else if (m === pb) { this.pos.z = o.min.z - r; dx = 0; dz = -1; } else { this.pos.z = o.max.z + r; dx = 0; dz = 1; } }
      const vn = this.vel.x * dx + this.vel.z * dz; if (vn < 0) { this.vel.x -= dx * vn; this.vel.z -= dz * vn; } this.blocked = 0.25;
      if (pulling) this.endHook(true);
    }
    if (A.clampPos(this.pos, r)) { this.blocked = 0.25; if (pulling) this.endHook(true); }
    this.blocked = (this.blocked || 0) - dt;
    if (this.pos.y > A.ceiling) { this.pos.y = A.ceiling; if (this.vel.y > 0) this.vel.y = 0; }
    const gy = A.groundAt(this.pos.x, this.pos.z, this.pos.y, r * 0.55);
    if (this.pos.y <= gy && this.vel.y <= 0) {
      if (!this.grounded) { if (this.vel.y < -16) { sfxPlay('land', this.pos, 0.9); w.fx.dust(this.pos, 10, 5, A.dust); if (this.isPlayer) w.fx.addShake(0.2); } this.landT = 0.25; }
      this.pos.y = gy; this.vel.y = 0; this.grounded = true; this.airT = 0;
    } else if (this.pos.y > gy + 0.08) { this.grounded = false; this.airT += dt; }

    // ── energia ──
    this.enWait -= dt;
    if (this.enWait <= 0 && this.en < this.enMax) {
      let rate = S.enRech * this.perk.en * (w.mods.overclock ? 1.6 : 1) * (this.grounded ? 1 : 0.55) * (this.parts.core.state ? 0.6 : 1) * (this.status.heat.t > 0 ? 0.5 : 1) * (this.enLock ? 1.25 : 1);
      this.en = Math.min(this.enMax, this.en + rate * dt);
    }
    if (this.enLock && this.en >= this.enMax * 0.32) this.enLock = false;

    // ── mira ──
    this.updateAim(dt);
    // ── corpo a corpo ──
    if (this.melee) this.updateMelee(dt);
    // ── armas ──
    this.shieldW = null;
    for (const k in this.weapons) { this.fireT[k] += dt; this.weapons[k].update(dt, !stg && I.fire[k]); }
    if (this.shieldW) this.shieldT += dt; else this.shieldT = 0;
    // ── utilitário ──
    if (I.util && !stg) this.useUtil();
    // ── partes danificadas soltam fumaça ──
    for (const k of PARTS5) { const p = this.parts[k]; if (!p.state) continue; p.smokeT -= dt; if (p.smokeT <= 0) { p.smokeT = p.state === 2 ? 0.07 : 0.16; this.partPos(k, _a); w.fx.puff(_a, 1, 2.2, p.state === 2 ? '#141312' : '#3a3836', 0.5, 1, 4, 1.4); if (Math.random() < 0.25) w.fx.sparks(_a, 3, '#ffd28a', 10); } }
    this.updateModel(dt);
  }

  spend(v, cont = false) { this.en -= v; this.enWait = Math.max(this.enWait, this.stats.enDelay * (cont ? 0.6 : 1)); if (this.en <= 0) { this.en = 0; if (!this.enLock) { this.enLock = true; this.enWait = this.stats.enDelay * 1.8; this.abOn = false; if (this.isPlayer) { this.world.emit({ type: 'alert', text: 'EN ESGOTADA' }); sfxPlay('warn'); } } } }
  get stabMax() { return this.stats.stab * this.perk.stab * (this.hpMul > 1 ? 1.3 : 1); }

  // ───── travamento e solução de tiro ─────
  updateAim(dt) {
    const w = this.world, I = this.input;
    const shocked = this.status.shock.t > 0;
    let t = this.target;
    if (t && (!t.alive || t.cloaked || shocked)) t = null;
    const c = this.center(_a).clone();
    if (this.isPlayer) {
      const range = this.lockRange;
      // mantém alvo travado; senão escolhe o mais próximo do centro da mira
      const valid = (m) => m.alive && !m.cloaked && m.team !== this.team && m.center(_b).distanceTo(c) < range && w.arena.los(c, m.center(_b));
      if (t && !(this.hardLock && valid(t))) t = null;
      if (!t && !shocked) {
        let best = this.parts.head.state === 2 ? 0.09 : 0.17, bm = null;
        for (const m of w.mechs) { if (m === this || !valid(m)) continue; _c.copy(m.center(_b)).sub(I.aimOrigin || c).normalize(); const ang = Math.acos(clamp(_c.dot(I.aimDir), -1, 1)); if (ang < best) { best = ang; bm = m; } }
        t = bm; if (this.hardLock && !t) this.hardLock = false;
      }
    } else if (t) {
      if (t.center(_b).distanceTo(c) > this.lockRange * 1.25 || !w.arena.los(c, _b)) t = null;
    }
    if (t !== this.target) { this.lockProg = 0; this.trk.ok = false; if (t && this.isPlayer) sfxPlay('lock'); }
    this.target = t;
    if (t) {
      this.lockProg += dt;
      const tp = t.center(_b), dist = tp.distanceTo(c), F = this.stats.fcs;
      const acc = dist < 110 ? F.near : dist < 220 ? lerp(F.near, F.mid, (dist - 110) / 110) : dist < 330 ? lerp(F.mid, F.far, (dist - 220) / 110) : F.far;
      const k = 9 * this.stats.track * acc * this.aimSkill * (this.armState('handR') && this.armState('handL') ? 0.6 : 1);
      if (!this.trk.ok) { this.trk.p.copy(tp); this.trk.v.copy(t.vel); this.trk.ok = true; }
      this.trk.p.addScaledVector(this.trk.v, dt); const f = 1 - Math.exp(-k * dt); this.trk.p.lerp(tp, f); this.trk.v.lerp(t.vel, 1 - Math.exp(-k * 0.55 * dt));
      // erro de mira lento (IA menos habilidosa erra mais)
      this.aimErrT -= dt; if (this.aimErrT <= 0) { this.aimErrT = 0.5 + Math.random() * 0.6; const e = (1 - this.aimSkill) * dist * 0.035 + (shocked ? dist * 0.08 : 0); this.aimErr.set((Math.random() - 0.5) * e, (Math.random() - 0.5) * e * 0.6, (Math.random() - 0.5) * e); }
      I.aimPoint.copy(this.trk.p).add(this.aimErr);
      _c.copy(I.aimPoint).sub(c); this.pitch = Math.atan2(_c.y, Math.hypot(_c.x, _c.z));
    } else {
      this.lockProg = 0; this.trk.ok = false;
      if (!this.isPlayer) I.aimPoint.copy(c).addScaledVector(_c.set(Math.sin(this.yaw), 0, Math.cos(this.yaw)), 100);
      _c.copy(I.aimPoint).sub(c); this.pitch = clamp(Math.atan2(_c.y, Math.hypot(_c.x, _c.z)), -1.2, 1.2);
    }
  }
  // ponto de mira com predição para um projétil de velocidade spd
  aimFor(from, spd, out, grav = 0) {
    const t = this.target;
    if (!t || !this.trk.ok) return out.copy(this.input.aimPoint);
    out.copy(this.trk.p).add(this.aimErr);
    if (spd > 0) { let tt = out.distanceTo(from) / spd; tt = Math.min(tt, 2.5); out.addScaledVector(this.trk.v, tt); const d2 = out.distanceTo(from) / spd; out.copy(this.trk.p).add(this.aimErr).addScaledVector(this.trk.v, Math.min(d2, 2.5)); if (grav) out.y += 0.5 * grav * d2 * d2; }
    const gy = this.world.arena.groundAt(out.x, out.z, 1e9, 0); if (out.y < 1.5) out.y = Math.max(out.y, 1.5);
    return out;
  }

  // ───── dano ─────
  addStatus(k, v) {
    const s = this.status[k]; if (s.t > 0 || !this.alive) return;
    const res = k === 'heat' ? this.stats.heatRes : k === 'shock' ? this.stats.shockRes : 0;
    s.v += v * (1 - res); s.idle = 0;
    if (s.v >= 100) { s.v = 0; s.t = k === 'heat' ? 6 : k === 'shock' ? 3.6 : 9; const txt = { heat: 'SUPERAQUECIMENTO', shock: 'FCS EM CURTO', corr: 'BLINDAGEM CORROÍDA' }[k];
      this.world.emit({ type: 'status', mech: this, k, text: txt }); sfxPlay(k === 'shock' ? 'emp' : 'warn', this.pos, 0.8);
      if (k === 'shock') { this.target = null; this.hardLock = false; this.world.fx.sparks(this.center(_a), 30, '#9fe8ff', 30); } }
  }
  damageRaw(v, owner) { if (!this.alive) return; this.st -= v; if (this.st <= 0) this.die(owner); }
  // h: {dmg, dt, imp, part, from, owner, st, point, armorMul, vsShield}
  takeHit(h) {
    if (!this.alive) return 0;
    const w = this.world, own = h.owner;
    let dmg = h.dmg * (h.melee ? 1 : 1.35) * (w.mods.glass ? 1.35 : 1), imp = h.imp || 0;
    if (own && own.alive !== undefined) { dmg *= own.perk[h.dt] || 1; imp *= own.perk.imp; }
    const pt = h.point || this.center(_a);
    if (this.barrier.t > 0) {
      this.barrier.hp -= dmg * (h.vsShield || 1); w.fx.sparks(pt, 5, '#8fd8ff', 16); sfxPlay('shieldhit', pt, 0.7);
      if (this.barrierMesh) this.barrierMesh.material.opacity = 0.75;
      if (this.barrier.hp <= 0) this.dropBarrier(true);
      if (own && own.isPlayer) w.emit({ type: 'hit', shield: true });
      return 0;
    }
    let mul = 1;
    if (this.shieldW && h.from) {
      _c.copy(h.from).sub(this.pos); const ang = Math.abs(angDiff(Math.atan2(_c.x, _c.z), this.yaw));
      if (ang < 1.25) { const d = this.shieldW.def; let b = this.shieldT < 0.3 ? d.parry : d.block; if (h.vsShield) b *= 0.45; mul *= 1 - b; imp *= 1 - b; this.spend(dmg * 0.25, true); w.fx.sparks(pt, 6, '#8fd8ff', 18); sfxPlay('shieldhit', pt, 0.7); if (this.shieldT < 0.3 && this.isPlayer) w.emit({ type: 'note', text: 'APARADO' }); }
    }
    const i = h.dt === 'k' ? 0 : h.dt === 'e' ? 1 : 2, part = h.part || 'core';
    const def = this.stats.def[part][i] - (this.status.corr.t > 0 ? 16 : 0);
    mul *= clamp(1 - def / 100, 0.3, 1.3);
    const stag = this.staggered;
    if (stag) mul *= 1.4 + (own && own.perk ? own.perk.direct : 0);
    dmg *= mul;
    const P = this.parts[part]; let sd;
    if (P.a > 0) { P.a -= dmg * (h.armorMul || 1); sd = dmg * 0.5; if (P.a <= 0) { P.a = 0; this.breach(part); } }
    else { sd = dmg * (part === 'core' ? 1.3 : 1.15); if (part !== 'core' && P.state < 2) { P.integ -= dmg; if (P.integ <= 0) this.destroyPart(part); } }
    this.st -= sd; this.dmgTaken += sd; this.lastHitT = 0; this.lastDmgFrom = own || null;
    if (own && own.dmgDealt !== undefined) own.dmgDealt += sd;
    if (!stag && this.staggerImm <= 0 && imp > 0) {
      this.impact += imp * (this.grounded && (this.legType === 'tank' || this.legType === 'quad') ? 0.82 : 1) * (this.anchorT > 0 ? 0.6 : 1); this.impactT = 0;
      if (this.impact >= this.stabMax) this.stagger(own);
    }
    if (h.st) { for (const k in h.st) this.addStatus(k, h.st[k]); }
    if (own && own.perk) { if (own.perk.shock) this.addStatus('shock', dmg * 0.03 * own.perk.shock); if (own.perk.burn) this.addStatus('heat', dmg * 0.04 * own.perk.burn); }
    if (w.mods.heat && h.dt === 'e') this.addStatus('heat', dmg * 0.05);
    if (this.isPlayer) { w.emit({ type: 'dmg', from: h.from, amt: sd }); sfxPlay('hitself', null, clamp(sd / 300, 0.3, 1)); w.fx.addShake(clamp(sd / 900, 0.04, 0.5)); }
    else if (own && own.isPlayer) w.emit({ type: 'hit', crit: stag, part, amt: sd, pos: pt });
    if (!h.quiet) sfxPlay('hit', pt, 0.8);
    if (this.st <= 0) this.die(own);
    return sd;
  }
  breach(part) {
    const P = this.parts[part]; if (P.state > 0) return; P.state = 1;
    const w = this.world, p = this.partPos(part, _b);
    w.fx.sparks(p, 26, '#ffd28a', 26); w.fx.spawnDebris(p, 6, this.build.paint.b || '#777', 18, 0.7 * this.scale); w.fx.puff(p, 5, 3, '#2a2826', 0.6, 3, 3, 1.4); w.fx.light(p, '#ffb060', 50, 0.25);
    sfxPlay('break', p, 1);
    if (this.staggerImm <= 0 && !this.staggered) { this.impact += this.stabMax * 0.25; if (this.impact >= this.stabMax) this.stagger(null); }
    w.emit({ type: 'breach', mech: this, part });
  }
  destroyPart(part) {
    const P = this.parts[part]; if (P.state === 2) return; P.state = 2; P.integ = 0;
    const w = this.world, p = this.partPos(part, _b);
    w.fx.explosion(p, 4 * this.scale, '#ffb060'); w.fx.spawnDebris(p, 10, this.build.paint.a || '#777', 26, 0.9 * this.scale); sfxPlay('explosion', p, 1);
    if (part === 'head') this.model.head.visible = false;
    if (part === 'armR') this.model.arm.R.el.visible = false;
    if (part === 'armL') this.model.arm.L.el.visible = false;
    if (part === 'head') this.hardLock = false;
    this.damageRaw(this.stMax * 0.04, null);
    w.emit({ type: 'destroy', mech: this, part });
  }
  restoreParts() {
    for (const k of PARTS5) { const p = this.parts[k]; p.a = p.max; p.integ = p.max * 0.6; p.state = 0; }
    this.model.head.visible = true; this.model.arm.R.el.visible = true; this.model.arm.L.el.visible = true;
  }
  stagger(by) {
    this.staggerT = 1.75; this.staggerImm = 1.75 + 2.4; this.impact = this.stabMax; this.abOn = false; this.melee = null; if (this.hook) this.endHook(false);
    for (const k in this.weapons) this.weapons[k].interrupt();
    const w = this.world; sfxPlay('stagger', this.pos, 1); w.fx.sparks(this.center(_a), 34, '#ffe9a0', 34); w.fx.ring(_b.copy(this.pos).setY(this.pos.y + this.aimY), '#ffd070', this.radius * 4, 0.4);
    w.emit({ type: 'stagger', mech: this, by });
  }
  die(by) {
    if (!this.alive) return; this.alive = false; this.st = 0; this.deadT = 0; this.abOn = false; this.melee = null; if (this.hook) this.endHook(false); this.dropBarrier(false);
    for (const k in this.weapons) this.weapons[k].interrupt();
    if (by && by.alive && by.perk && by.perk.salvage) by.st = Math.min(by.stMax, by.st + by.stMax * 0.06 * by.perk.salvage);
    this.world.emit({ type: 'kill', mech: this, by });
  }
  updateDead(dt) {
    const w = this.world; this.deadT += dt;
    if (this.model.root.visible) {
      this.vel.y -= 30 * dt; this.vel.x *= 0.97; this.vel.z *= 0.97; this.pos.addScaledVector(this.vel, dt); const gy = w.arena.groundAt(this.pos.x, this.pos.z, this.pos.y, 1); if (this.pos.y < gy) { this.pos.y = gy; this.vel.set(0, 0, 0); }
      this.model.root.position.copy(this.pos); this.model.body.rotation.x = Math.min(0.5, this.deadT * 0.6); this.model.body.rotation.z = Math.sin(this.deadT * 30) * 0.03;
      if (Math.random() < dt * 9) { const p = this.center(_a).add(_b.set((Math.random() - 0.5) * 5, (Math.random() - 0.5) * 6, (Math.random() - 0.5) * 5)); w.fx.explosion(p, 3 + Math.random() * 3, '#ffb060'); sfxPlay('explosion', p, 0.7); }
      for (const f of this.model.flames) f.m.visible = false;
      if (this.deadT > 1.3) {
        const c = this.center(_a); w.fx.explosion(c, 15 * this.scale, '#ffc070', true); w.fx.spawnDebris(c, 30, this.build.paint.a || '#777', 38, 1.2 * this.scale); w.fx.spawnDebris(c, 14, this.build.paint.b || '#555', 30, 0.9 * this.scale);
        sfxPlay('bigexplosion', c, 1.2); w.fx.addShake(clamp(60 / (10 + c.distanceTo(w.camPos)), 0.1, 0.9)); w.fx.mark(this.pos, 12);
        this.model.root.visible = false; if (this.cable) this.cable.visible = false;
      }
    }
  }

  // ───── corpo a corpo ─────
  startMelee(weapon, mult = 1) {
    const d = weapon.def; this.abOn = false;
    this.melee = { w: weapon, phase: 'lunge', t: 0, mult, hit: false, side: weapon.slot === 'handL' ? 'L' : 'R' };
    if (this.target) { const dist = this.target.pos.distanceTo(this.pos); if (dist > d.lunge * 1.6) this.melee.phase = 'swing'; }
    else this.melee.phase = 'swing';
    if (d.enc) this.spend(d.enc);
    sfxPlay('swing', this.pos, 0.9);
    const wn = this.model.wn[weapon.slot]; if (wn && wn.blade) wn.blade.visible = true;
  }
  updateMelee(dt) {
    const M = this.melee, d = M.w.def, w = this.world, t = this.target; M.t += dt;
    if (t && t.alive) { _c.copy(t.pos).sub(this.pos); this.yaw += clamp(angDiff(Math.atan2(_c.x, _c.z), this.yaw), -12 * dt, 12 * dt); }
    if (M.phase === 'lunge') {
      const dist = t ? Math.hypot(t.pos.x - this.pos.x, t.pos.z - this.pos.z) : 0, reach = d.reach * this.scale + (t ? t.radius : 0);
      if (!t || dist < reach * 0.8 || M.t > 0.5 || this.blocked > 0.2) { M.phase = 'swing'; M.t = 0; this.vel.multiplyScalar(0.35); }
      else { _c.copy(t.center(_a)).sub(this.center(_b)).normalize(); const sp = Math.max(70, d.lunge * 2.6); this.vel.set(_c.x * sp, _c.y * sp * 0.8, _c.z * sp); if (Math.random() < dt * 60) w.fx.thrust(this.center(_a), _b.copy(_c).negate(), this.model.flameCol, 3, 30); }
    } else if (M.phase === 'swing') {
      if (!M.hit && M.t > (d.thrust ? 0.1 : 0.13)) {
        M.hit = true; let any = false;
        const reach = d.reach * this.scale + this.radius;
        for (const m of w.mechs) {
          if (m.team === this.team || !m.alive) continue;
          _c.copy(m.pos).sub(this.pos); const dist = Math.hypot(_c.x, _c.z) - m.radius; if (dist > reach || Math.abs(m.pos.y - this.pos.y) > 12) continue;
          if (Math.abs(angDiff(Math.atan2(_c.x, _c.z), this.yaw)) > 1.15) continue;
          const part = Math.random() < 0.6 ? 'core' : Math.random() < 0.5 ? 'armR' : Math.random() < 0.5 ? 'armL' : 'head';
          const mm = this.stats.melee * M.mult * (this.armState(M.w.slot) ? 0.6 : 1);
          const pp = m.partPos(part, V());
          m.takeHit({ dmg: d.dmg * mm, dt: d.dt, imp: d.imp * M.mult, part, from: this.pos, owner: this, point: pp, quiet: true, melee: true });
          w.fx.sparks(pp, 40, d.dt === 'e' ? this.model.mats.glowColor.getStyle() : '#ffd28a', 34); w.fx.light(pp, '#fff0c0', 90, 0.2); any = true;
          _c.setY(0).normalize(); m.vel.addScaledVector(_c, 26 * clamp(this.weight / m.weight, 0.4, 1.6));
        }
        sfxPlay(any ? 'meleehit' : 'swing', this.pos, 1); if (any) w.fx.addShake(this.isPlayer ? 0.45 : 0.15);
        // arco visual
        const tip = this.model.wn[M.w.slot] && this.model.wn[M.w.slot].m && this.model.wn[M.w.slot].m.tip;
        if (tip) { tip.getWorldPosition(_a); w.fx.sparks(_a, 10, d.dt === 'e' ? this.model.mats.glowColor.getStyle() : '#ffc070', 18); }
      }
      if (M.t > 0.34) { M.phase = 'rec'; M.t = 0; }
    } else if (M.t > 0.3) { const wn = this.model.wn[M.w.slot]; if (wn && wn.blade) wn.blade.visible = false; this.melee = null; }
  }

  // ───── utilitários ─────
  useUtil() {
    const u = this.P.util, w = this.world; if (!u || this.utilCd > 0 || u.act === 'passive') return;
    if (u.act === 'hook') {
      if (this.hook) return;
      const from = this.muzzle('util', V()), to = V();
      if (this.target) to.copy(this.target.center(_a)); else to.copy(this.input.aimPoint);
      const dir = to.sub(from).normalize();
      this.hook = { phase: 'out', p: from.clone(), dir, dist: 0, t: 0, mech: null, def: u };
      this.utilCd = u.cd; sfxPlay('hook', this.pos, 0.9);
      if (!this.cable) { this.cable = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.06, 1, 5).rotateX(Math.PI / 2).translate(0, 0, 0.5), new THREE.MeshStandardMaterial({ color: '#2a2a2c', metalness: 0.9, roughness: 0.4 })); this.hookHead = buildHookHead(this.model.mats, u.m.v); this.cable.frustumCulled = false; w.scene.add(this.cable, this.hookHead); }
      this.cable.visible = this.hookHead.visible = true; if (this.model.util && this.model.util.claw) this.model.util.claw.visible = false;
    } else if (u.act === 'barrier') {
      this.barrier.t = u.dur; this.barrier.hp = this.barrier.max = u.hp; this.utilCd = u.cd; sfxPlay('shield', this.pos, 1);
      if (!this.barrierMesh) { this.barrierMesh = new THREE.Mesh(new THREE.IcosahedronGeometry(1, 2), new THREE.MeshBasicMaterial({ color: new THREE.Color('#58c8ff').multiplyScalar(1.5), transparent: true, opacity: 0.3, blending: THREE.AdditiveBlending, depthWrite: false, wireframe: false, toneMapped: false, side: THREE.DoubleSide })); w.scene.add(this.barrierMesh); }
      this.barrierMesh.visible = true; this.barrierMesh.scale.setScalar(this.height * 0.75);
    } else if (u.act === 'cloak') { this.cloakT = u.dur; this.utilCd = u.cd; this.setCloak(true); sfxPlay('shield', this.pos, 0.8); }
    else if (u.act === 'burst') {
      if (this.utilCharges <= 0) return; this.utilCharges--; this.utilCd = 1.5;
      const c = this.center(V()); w.fx.orb(c, '#9fe0ff', u.rad, 0.45); w.fx.explosion(c, 10, '#9fe0ff', true); w.fx.addShake(0.6); sfxPlay('emp', c, 1.2); sfxPlay('bigexplosion', c, 0.8);
      for (const m of w.mechs) { if (m.team === this.team || !m.alive) continue; const d = m.center(_a).distanceTo(c); if (d < u.rad + m.radius) { const f = 1 - 0.5 * d / u.rad; m.takeHit({ dmg: u.dmg * f, dt: 'e', imp: u.imp * f, part: 'core', from: c, owner: this, vsShield: 4 }); _b.copy(m.pos).sub(this.pos).setY(0).normalize(); m.vel.addScaledVector(_b, 40); } }
      w.clearProjectilesNear(c, u.rad, this.team);
    }
  }
  setCloak(on) {
    const m = this.model.mats; for (const k of ['a', 'b', 'c', 'd', 'k', 'w', 'cer', 'hz', 't', 'dc']) { m[k].transparent = on || k === 'dc'; m[k].opacity = on ? 0.14 : 1; m[k].depthWrite = !on && k !== 'dc'; m[k].needsUpdate = true; }
    if (on) this.world.fx.puff(this.center(_a), 8, 4, '#9ab', 0.3, 4, 1, 0.8);
  }
  dropBarrier(broken) {
    if (this.barrier.t <= 0 && !broken) { if (this.barrierMesh) this.barrierMesh.visible = false; return; }
    this.barrier.t = 0; if (this.barrierMesh) this.barrierMesh.visible = false;
    if (broken) { const c = this.center(_a); this.world.fx.ring(c.clone(), '#58c8ff', this.height, 0.4); this.world.fx.sparks(c, 40, '#8fd8ff', 40); sfxPlay('break', c, 0.9); if (this.staggerImm <= 0) { this.impact += this.stabMax * 0.4; } }
  }
  updateHook(dt) {
    const H = this.hook, w = this.world, u = H.def; H.t += dt;
    if (H.phase === 'out') {
      const step = 300 * dt; const hit = {};
      let d = w.arena.ray(H.p, H.dir, step, hit); let mh = w.rayMechs(H.p, H.dir, Math.min(step, d), this.team, null);
      if (mh) { H.p.addScaledVector(H.dir, mh.t); H.mech = mh.mech; H.off = H.p.clone().sub(mh.mech.pos); H.phase = 'pull'; H.t = 0; sfxPlay('clank', H.p, 1); w.fx.sparks(H.p, 14, '#ffd28a', 16);
        if (u.harpoon) { mh.mech.takeHit({ dmg: u.dmg, dt: 'k', imp: u.imp, part: mh.part, from: this.pos, owner: this, point: H.p }); H.drag = mh.mech.weight < this.weight * 1.15; } }
      else if (d !== Infinity) { H.p.addScaledVector(H.dir, d); H.phase = 'pull'; H.t = 0; sfxPlay('clank', H.p, 1); w.fx.sparks(H.p, 14, '#ffd28a', 16); }
      else { H.p.addScaledVector(H.dir, step); H.dist += step; if (H.dist > u.rng || w.arena.clampPos(_a.copy(H.p), 0)) H.phase = 'back'; }
    } else if (H.phase === 'pull') {
      if (H.mech) { if (!H.mech.alive) { this.endHook(false); return; } H.p.copy(H.mech.pos).add(H.off); }
      const c = this.center(_a), to = _b.copy(H.p).sub(c), dist = to.length(); to.multiplyScalar(1 / Math.max(0.01, dist));
      if (H.drag && H.mech) { H.mech.vel.copy(to).multiplyScalar(-u.pull * 0.8); H.mech.grounded = false; this.vel.multiplyScalar(0.9); if (dist < this.radius + H.mech.radius + 6 || H.t > 1.4) { H.mech.vel.multiplyScalar(0.2); this.endHook(false); } }
      else { const sp = u.pull * (0.6 + Math.min(0.4, H.t * 1.5)); this.vel.copy(to).multiplyScalar(sp); this.grounded = false; if (dist < 9 + (H.mech ? H.mech.radius : 0) || H.t > 1.8 || this.staggered) this.endHook(true); }
    } else { H.p.lerp(this.muzzle('util', _a), Math.min(1, 14 * dt)); if (H.t > 0.25 && H.p.distanceTo(_a) < 4 || H.t > 1.2) { this.hook = null; this.cable.visible = this.hookHead.visible = false; if (this.model.util && this.model.util.claw) this.model.util.claw.visible = true; return; } }
    const m = this.muzzle('util', _a); this.cable.position.copy(m); this.cable.lookAt(H.p); this.cable.scale.set(1, 1, m.distanceTo(H.p)); this.hookHead.position.copy(H.p); this.hookHead.lookAt(_b.copy(H.p).add(H.dir));
  }
  endHook(keepMomentum) { if (!this.hook) return; if (this.hook.phase === 'pull' && keepMomentum) { this.vel.multiplyScalar(0.62); if (this.vel.y < 14) this.vel.y += 8; } this.hook.phase = 'back'; this.hook.t = 0; this.hook.mech = null; }

  // ───── animação do modelo ─────
  updateModel(dt) {
    const M = this.model, w = this.world, I = this.input, S = this.stats;
    M.root.position.copy(this.pos); M.root.rotation.y = this.yaw;
    const sy = Math.sin(this.yaw), cy = Math.cos(this.yaw);
    const lf = this.vel.x * sy + this.vel.z * cy, ls = this.vel.x * cy - this.vel.z * sy, hs = Math.hypot(this.vel.x, this.vel.z);
    const stg = this.staggered;
    const bx = stg ? 0.38 + Math.sin(w.time * 40) * 0.02 : clamp(lf * 0.0065, -0.3, 0.34) + (this.anchorT > 0 ? 0.12 : 0);
    M.body.rotation.x = lerp(M.body.rotation.x, bx, Math.min(1, 9 * dt)); M.body.rotation.z = lerp(M.body.rotation.z, clamp(ls * 0.0065, -0.3, 0.3), Math.min(1, 9 * dt));
    // pernas apontam para o movimento
    let ly = 0; if (hs > 3) { ly = angDiff(Math.atan2(this.vel.x, this.vel.z), this.yaw); if (Math.abs(ly) > Math.PI / 2) ly = angDiff(ly + Math.PI, 0); ly = clamp(ly, -1.1, 1.1); }
    this.legYaw = lerp(this.legYaw, ly, Math.min(1, (this.isTank ? 4 : 7) * dt)); M.legsG.rotation.y = this.legYaw; M.legsG.rotation.x = -M.body.rotation.x * 0.7; M.legsG.rotation.z = -M.body.rotation.z * 0.7;
    const walkSp = S.groundSpeed * 1.2, glide = hs > walkSp;
    if (this.grounded && hs > 1) { this.phase += Math.min(hs, walkSp * 1.2) * dt * 0.62; const sgn = Math.floor(this.phase / Math.PI); if (sgn !== this.stepSide && !glide && M.anim.type !== 'tank') { this.stepSide = sgn; sfxPlay('step', this.pos, this.isPlayer ? 0.55 : 0.4); } }
    const amp = !this.grounded ? 0 : glide ? 0.12 : clamp(hs / walkSp, 0, 1);
    const crouch = !this.grounded ? 0.5 : glide ? 0.55 : (this.landT > 0 ? 0.8 : this.anchorT > 0 ? 0.7 : 0);
    this.landT = (this.landT || 0) - dt;
    this.crouchS = lerp(this.crouchS || 0, crouch, Math.min(1, 10 * dt)); this.ampS = lerp(this.ampS || 0, amp, Math.min(1, 8 * dt));
    poseLegs(M, this.phase, this.ampS, this.crouchS);
    if (M.anim.type === 'tank') { M.mats.t.map.offset.y -= lf * dt * 0.16; M.body.position.y = this.grounded && hs > 2 ? Math.sin(w.time * 30) * 0.03 : 0; }
    // braços
    for (const [k, slot] of [['R', 'handR'], ['L', 'handL']]) {
      const A = M.arm[k]; this.recoil[k] = Math.max(0, this.recoil[k] - dt * 5);
      const active = this.fireT[slot] < 1.6 || !!this.target || this.isPlayer;
      let ex = active ? -this.pitch : 0.4, sx = 0, sz = 0, syw = 0;
      if (this.melee && this.melee.side === k) {
        const m = this.melee, d = m.w.def;
        if (d.thrust) { if (m.phase === 'lunge') { sx = 0.5; ex = -0.2; } else if (m.phase === 'swing') { sx = -0.7 * Math.min(1, m.t / 0.1); ex = 0.3; } const sp = M.wn[slot] && M.wn[slot].spike; if (sp) sp.position.z = m.phase === 'swing' ? 1.4 + Math.min(1, m.t / 0.08) * 1.6 : 1.4; }
        else if (m.phase === 'lunge') { sx = -1.5; ex = -0.5; syw = k === 'L' ? 0.5 : -0.5; }
        else if (m.phase === 'swing') { const t = Math.min(1, m.t / 0.22); sx = -1.5 + t * 2.0; ex = -0.5 + t * 0.7; syw = (k === 'L' ? 1 : -1) * (0.5 - t * 1.5); }
        else { sx = 0.5 - m.t; ex = 0.2; }
      }
      const wdef = this.weapons[slot] && this.weapons[slot].def;
      if (wdef && wdef.wt === 'shield' && this.shieldW === this.weapons[slot]) { ex = -0.3; syw = k === 'L' ? -0.7 : 0.7; }
      ex -= this.recoil[k] * 0.5; if (stg) { ex = 0.9; sx = 0.2; }
      A.el.rotation.x = lerp(A.el.rotation.x, ex, Math.min(1, 14 * dt)); A.sh.rotation.x = lerp(A.sh.rotation.x, sx, Math.min(1, 16 * dt)); A.sh.rotation.y = lerp(A.sh.rotation.y, syw, Math.min(1, 16 * dt));
    }
    // dorsais
    for (const slot of ['backR', 'backL']) { const n = M.wn[slot]; if (!n || !n.pv || n.fixed) continue; const act = this.fireT[slot] < 2.2 || I.fire[slot] || (this.weapons[slot] && this.weapons[slot].chg > 0); n.pv.rotation.x = lerp(n.pv.rotation.x, act ? -clamp(this.pitch, -0.5, 0.9) : -(n.stow || 0.22), Math.min(1, (act ? 10 : 3) * dt)); }
    for (const s of M.spin) { const wp = this.weapons[s.key]; s.g.rotation.z += (wp ? wp.spinV : 0) * 40 * dt; }
    for (const s of M.spinY) s.rotation.y += dt * 1.6;
    M.head.rotation.x = lerp(M.head.rotation.x, clamp(-this.pitch * 0.6, -0.5, 0.5), Math.min(1, 8 * dt));
    // chamas dos propulsores
    const moving = Math.hypot(I.mx, I.mz) > 0.1 && hs > 4, qb = this.qbFx > 0;
    const base = this.abOn ? 5.5 : qb ? 6.5 : moving ? 2.2 + Math.random() * 0.5 : this.ascending ? 2.6 : 0;
    for (const f of M.flames) {
      let L = f.up ? (this.ascending || (this.abOn) ? 3.2 + Math.random() : 0) : f.qb ? (qb && this.qbDir && (this.qbDir.x * cy - this.qbDir.z * sy) * f.qb < -0.2 ? 5 : 0) : base;
      if (stg) L = 0; f.L = lerp(f.L || 0, L, Math.min(1, 18 * dt));
      if (f.L > 0.08) { f.m.visible = true; f.m.scale.set(f.r * 1.5, f.r * 1.5, f.L * (0.9 + Math.random() * 0.2)); } else f.m.visible = false;
    }
    this.thrT -= dt;
    if (this.thrT <= 0 && (base > 0 || this.ascending)) { this.thrT = 0.035; const f = M.flames[Math.floor(Math.random() * M.flames.length)]; if (f && f.m.visible) { f.o.getWorldPosition(_a); f.o.getWorldDirection(_b).negate(); w.fx.thrust(_a, _b, M.flameCol, 2.2 * this.scale, 26 + base * 6); }
      if (this.grounded && hs > 14 && Math.random() < 0.5) w.fx.dust(_a.copy(this.pos).setY(this.pos.y + 0.4), 1, 3.5, w.arena.dust); }
    if (this.barrierMesh && this.barrierMesh.visible) { this.barrierMesh.position.copy(this.center(_a)); this.barrierMesh.rotation.y += dt * 0.6; this.barrierMesh.material.opacity = lerp(this.barrierMesh.material.opacity, 0.12 + 0.2 * this.barrier.hp / this.barrier.max, Math.min(1, 6 * dt)); }
  }
  // zonas de acerto em coordenadas de mundo: chama cb(part, centro, raio)
  dispose() { this.world.scene.remove(this.model.root); this.model.dispose(); for (const o of [this.cable, this.hookHead, this.barrierMesh]) if (o) { this.world.scene.remove(o); } for (const k in this.weapons) this.weapons[k].dispose(); }
}
