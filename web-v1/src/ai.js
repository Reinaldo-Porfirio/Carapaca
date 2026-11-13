// Pilotos controlados pelo jogo: posicionamento, esquiva, disciplina de tiro e uso de utilitários.
import * as THREE from 'three';
import { clamp } from './stats.js';

const _a = new THREE.Vector3(), _b = new THREE.Vector3(), _c = new THREE.Vector3(), _hit = {};

export class AI {
  constructor(mech, traits = {}) {
    this.m = mech; this.t = { agg: 0.5, skill: 0.5, air: 0.3, ...traits };
    const s = this.t.skill; mech.aimSkill = 0.3 + 0.7 * s;
    this.strafe = Math.random() < 0.5 ? 1 : -1; this.strafeT = 1 + Math.random() * 2; this.airT = 1 + Math.random() * 3; this.jumpHold = 0; this.burstT = 0; this.burstOn = true;
    this.react = 0; this.scanT = 0; this.dodgeT = 0; this.heavyT = 0; this.heavyOk = false; this.meleeT = 0; this.meleeOk = false; this.noLos = 0; this.ch = {}; this.avoidT = 0; this.evT = 2 + Math.random() * 3; this.qbQueued = 0; this.targetT = 0;
    mech.kits = Math.min(mech.kits, Math.floor(s * 2.4));
    // distância preferida a partir do armamento
    let pr = 0, n = 0, melee = false;
    for (const k of ['handR', 'handL']) { const w = mech.weapons[k]; if (!w) continue; const d = w.def; if (d.wt === 'melee') { melee = true; continue; } if (d.wt === 'shield') continue; pr += d.wt === 'cone' ? d.rng * 0.7 : d.pel ? d.rng * 0.55 : Math.min(200, d.rng * 0.5); n++; }
    this.pr = traits.keep || (n ? pr / n : melee ? 30 : 140); if (melee && traits.melee) this.pr = Math.min(this.pr, 45);
    this.pr = clamp(this.pr, 22, 260);
  }
  pickTarget(w) {
    let best = null, bd = 1e9;
    for (const e of w.mechs) { if (!e.alive || e.team === this.m.team) continue; let d = e.pos.distanceTo(this.m.pos); if (e.cloaked) d += 400; if (e === this.m.lastDmgFrom) d *= 0.6; if (d < bd) { bd = d; best = e; } }
    return best;
  }
  update(dt, w) {
    const m = this.m, I = m.input, T = this.t, s = T.skill;
    I.qb = false; I.ab = false; I.jumpP = false; I.util = false; I.repair = false;
    if (!m.alive) return;
    if (this.t.passive) { I.mx = I.mz = 0; I.jump = false; for (const k in I.fire) I.fire[k] = false; const pl = w.mechs[0]; if (pl) I.yaw = Math.atan2(pl.pos.x - m.pos.x, pl.pos.z - m.pos.z); return; }
    this.targetT -= dt; if (this.targetT <= 0 || !this.tgt || !this.tgt.alive) { this.targetT = 1.2; const nt = this.pickTarget(w); if (nt !== this.tgt) { this.tgt = nt; this.react = 0.7 - 0.5 * s; } }
    const t = this.tgt;
    for (const k in I.fire) if (!t) I.fire[k] = false;
    if (!t) { I.mx = 0; I.mz = 0; I.jump = false; return; }
    const c = m.center(_a).clone(), tc = t.center(_b).clone(), to = _c.copy(tc).sub(c), dist = to.length();
    const los = w.arena.los(c, tc);
    if (los) this.noLos = 0; else this.noLos += dt;
    I.yaw = Math.atan2(to.x, to.z);
    // travamento
    if (los && dist < m.lockRange && !t.cloaked && m.status.shock.t <= 0) { if (m.target !== t) { m.target = t; m.lockProg = 0; m.trk.ok = false; } } else if (m.target && (!los || t.cloaked)) m.target = null;
    this.react -= dt;
    const tStag = t.staggered;
    // ── movimento ──
    this.strafeT -= dt; if (this.strafeT <= 0 || m.blocked > 0.2) { this.strafe = -this.strafe; this.strafeT = 1.0 + Math.random() * 2.6; }
    let pr = this.pr; if (tStag && T.agg > 0.5) pr = Math.min(pr, 60);
    let mz = dist > pr * 1.2 ? 1 : dist < pr * 0.65 ? -1 : (dist - pr) / pr;
    let mx = this.strafe * (0.55 + 0.45 * s);
    if (this.noLos > 1.0) { mz = 1; mx *= 0.6; }
    if (m.st < m.stMax * 0.25 && T.agg < 0.6) mz = Math.min(mz, -0.4);
    // desvio de obstáculos
    this.avoidT -= dt;
    if (this.avoidT <= 0) {
      this.avoidT = 0.22; const fy = Math.sin(I.yaw), fc = Math.cos(I.yaw);
      _b.set(fy * mz - fc * mx, 0, fc * mz + fy * mx); if (_b.lengthSq() > 0.01) { _b.normalize(); const d = w.arena.ray(c, _b, 18, _hit);
        if (d !== Infinity && _hit.ob && _hit.ob !== 'ground') { const top = _hit.ob.max.y - m.pos.y; if (top < 18 && m.en > m.enMax * 0.4 && !m.enLock) this.jumpHold = Math.max(this.jumpHold, 0.4 + top * 0.06); else this.strafe = -this.strafe; } }
      if (m.grounded && w.arena.inHazard(m.pos.x, m.pos.z)) this.jumpHold = Math.max(this.jumpHold, 0.6);
    }
    // altitude
    this.airT -= dt;
    if (this.airT <= 0) { this.airT = 1.6 + Math.random() * 3.4; if (Math.random() < T.air && m.en > m.enMax * 0.55) this.jumpHold = 0.5 + Math.random() * 1.8 * T.air; if (this.noLos > 0.8) this.jumpHold = 1.2; }
    if (this.jumpHold > 0) { this.jumpHold -= dt; I.jump = true; if (m.grounded) I.jumpP = true; if (m.en < m.enMax * 0.15) this.jumpHold = 0; } else I.jump = false;
    I.mx = mx; I.mz = mz;
    // ── esquiva ──
    this.scanT -= dt; this.dodgeT -= dt;
    if (this.scanT <= 0) {
      this.scanT = 0.1; this.threat = false;
      for (const p of w.projs) {
        if (p.team === m.team || p.aiSeen === m) continue; if (p.pk !== 'missile' && p.dmg < 240) continue;
        _b.copy(c).sub(p.pos); const d = _b.length(); if (d > 90) continue; const sp = p.vel.length(); if (d / sp > 0.55) continue;
        if (_b.multiplyScalar(1 / d).dot(_c.copy(p.vel).multiplyScalar(1 / sp)) < 0.94) continue;
        p.aiSeen = m; this.threat = true;
        if (this.dodgeT <= 0 && Math.random() < s * 0.8 + 0.05) { this.qbQueued = 1; this.dodgeT = 0.5; this.strafe = Math.random() < 0.5 ? 1 : -1; break; }
      }
    }
    this.evT -= dt;
    if (this.evT <= 0) { this.evT = 1.5 + Math.random() * (4.5 - s * 2.5); if (m.lastHitT < 1.2 && Math.random() < 0.3 + s * 0.5) this.qbQueued = 1; else if (dist > pr * 1.7 && Math.random() < T.agg) this.qbQueued = 2; else if (tStag && dist > pr && Math.random() < T.agg) this.qbQueued = 2; }
    if (this.qbQueued && m.qbT <= 0 && !m.enLock && m.en > m.stats.qbCost * 0.6) { if (this.qbQueued === 2) { I.mx = 0; I.mz = 1; } else { I.mx = this.strafe; I.mz = mz * 0.3; } I.qb = true; this.qbQueued = 0; }
    // sobreimpulso para fechar distância
    if (!m.abOn && dist > Math.max(pr * 2.2, 170) && T.agg > 0.55 && m.en > m.enMax * 0.75 && los && Math.random() < dt * 0.8) I.ab = true;
    if (m.abOn && dist < pr * 1.3) I.ab = true;
    I.aimDir.copy(to).multiplyScalar(1 / dist);
    // ── tiro ──
    this.burstT -= dt; if (this.burstT <= 0) { this.burstOn = !this.burstOn; this.burstT = this.burstOn ? 0.7 + s * 1.8 + Math.random() * 0.5 : Math.max(0.15, 1.2 - s * 0.9) * (0.6 + Math.random() * 0.8); }
    this.heavyT -= dt; if (this.heavyT <= 0) { this.heavyT = 1.6; this.heavyOk = Math.random() < 0.22 + (1 - s) * 0.35; }
    this.meleeT -= dt; if (this.meleeT <= 0) { this.meleeT = 0.6; this.meleeOk = Math.random() < 0.25 + T.agg * 0.45; }
    const can = this.react <= 0 && los && m.target === t;
    for (const k in m.weapons) {
      const wp = m.weapons[k], d = wp.def; let f = false;
      const enOk = !d.enc || (!m.enLock && m.en > m.enMax * 0.22);
      if (can && enOk) switch (d.wt) {
        case 'proj': case 'beam': {
          const inR = dist < d.rng * 1.12 && (d.pk !== 'grenade' || dist > 22), heavy = d.dmg * (d.pel || 1) * (d.burst || 1) > 620;
          const ok = inR && (!heavy || tStag || this.heavyOk);
          if (d.chg && (d.chg.req || s > 0.45)) { const st = this.ch[k] || (this.ch[k] = { h: 0 }); if (ok && wp.cd <= 0 && wp.canFire()) { st.h += dt; f = st.h < d.chg.t + 0.1; if (!f) st.h = 0; } else st.h = 0; }
          else if (d.chg) f = ok && this.burstOn && !I.fire[k];
          else f = ok && (this.burstOn || heavy || tStag);
          break;
        }
        case 'missile': f = dist > 24 && dist < d.rng * 1.25 && (d.mk2 === 'guided' || m.lockProg >= d.lockT * m.lockTimeMul); break;
        case 'cone': f = dist - t.radius < d.rng * 0.95; break;
        case 'melee': {
          const inR = dist < d.lunge * 1.15 + t.radius + m.radius;
          if (d.chg) { const st = this.ch[k] || (this.ch[k] = { h: 0 }); if (inR * 1 && wp.cd <= 0 && !m.melee && (tStag || this.meleeOk)) { st.h += dt; f = st.h < d.chg.t + 0.08; if (!f) st.h = 0; } else st.h = 0; }
          else f = inR && wp.cd <= 0 && !m.melee && (tStag || this.meleeOk) && !I.fire[k];
          break;
        }
        case 'shield': f = (m.lastHitT < 0.7 || this.threat) && m.en > m.enMax * 0.5 && !m.enLock && s > 0.3; break;
        case 'drone': f = wp.cd <= 0 && !I.fire[k]; break;
        case 'active': f = wp.cd <= 0 && !I.fire[k] && (d.act === 'flare' ? this.threat : dist < d.rad * 0.85); break;
      }
      I.fire[k] = f;
    }
    // ── utilitário e reparo ──
    const u = m.P.util;
    if (u && m.utilCd <= 0 && this.react <= 0) {
      if (u.act === 'hook') { if (los && dist > 70 && dist < u.rng && T.agg > 0.5 && Math.random() < dt * 0.5) I.util = true; }
      else if (u.act === 'barrier') { if (m.lastHitT < 0.5 && m.st < m.stMax * 0.8) I.util = true; }
      else if (u.act === 'cloak') { if (m.lastHitT < 0.5 && Math.random() < dt * 2) I.util = true; }
      else if (u.act === 'burst') { if (dist < u.rad * 0.7 && m.utilCharges > 0 && (m.staggered === false) && Math.random() < dt * 3) I.util = true; }
    }
    if (m.kits > 0 && m.st < m.stMax * 0.34 && m.kitCd <= 0) I.repair = true;
  }
}
