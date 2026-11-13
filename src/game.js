// Partida: arena, entrada do jogador, câmera, ondas do modo infinito e condição de vitória.
import * as THREE from 'three';
import { World } from './world.js';
import { Mech } from './mech.js';
import { AI } from './ai.js';
import { buildArena } from './arena.js';
import { Input } from './input.js';
import { PERKS, CALLSIGNS, MECHNAMES } from './data.js';
import { randomBuild, mulberry, clamp, lerp, ARCHETYPES } from './stats.js';
import { sfxPlay, setListener, setBoostLoop, setMusic } from './audio.js';

const _a = new THREE.Vector3(), _b = new THREE.Vector3(), _c = new THREE.Vector3(), _d = new THREE.Vector3(), _hit = {};

export class Match {
  constructor(app, cfg) {
    this.app = app; this.cfg = cfg; const eng = app.engine;
    this.rng = mulberry((cfg.seed || 1) * 31 + 7);
    this.arena = buildArena(cfg.arena, cfg.seed || 1, eng, { fog: cfg.mods && cfg.mods.fog });
    this.world = new World(eng, this.arena, cfg.mods || {});
    this.cam = new THREE.PerspectiveCamera(62, innerWidth / innerHeight, 0.6, 2400);
    eng.use(this.world.scene, this.cam); eng.renderer.toneMappingExposure = this.arena.exposure;
    this.player = this.world.add(new Mech(this.world, cfg.playerBuild, { team: 0, player: true, name: cfg.playerBuild.name }));
    this.player.pos.copy(this.arena.spawnP); this.player.yaw = 0; this.player.input.yaw = 0;
    this.fill = new THREE.DirectionalLight('#dfe6f0', 0.75); this.world.scene.add(this.fill, this.fill.target);
    this.ais = [];
    (cfg.allies || []).forEach((s, i) => this.spawn(s, 0, i));
    this.queue = (cfg.enemies || []).slice();
    this.wave = 0; this.score = 0; this.kills = 0; this.perks = {}; this.earned = 0;
    if (cfg.endless) this.nextWave(); else if (cfg.sequence) this.spawn(this.queue.shift(), 1, 0); else { const all = this.queue.splice(0); all.forEach((s, i) => this.spawn(s, 1, i, all.length)); }
    this.camYaw = 0; this.camPitch = 0.08; this.state = 'intro'; this.t = 0; this.time = 0; this.timeScale = 1; this.paused = false; this.fov = 62; this.missileWarn = 0; this.breaches = 0;
    this.sens = app.save.settings.sens; this.invY = app.save.settings.invY ? -1 : 1;
    this.lastCount = 4; setMusic(1);
    if (cfg.autopilot) this.auto = new AI(this.player, cfg.autopilot);
    this.world.fx.setViewport(innerHeight * eng.renderer.getPixelRatio(), 62);
    try { eng.renderer.compile(this.world.scene, this.cam); } catch (e) { /* segue sem pré-compilar */ }
    app.hud.begin(this);
    this.updateCamera(0.016, true);
  }
  spawn(spec, team, i, n = 1) {
    const w = this.world, A = this.arena;
    const m = w.add(new Mech(w, spec.build, { team, name: spec.name, call: spec.call, hpMul: spec.hpMul, scale: spec.scale }));
    const base = team === 0 ? A.spawnP : A.spawnE; const off = (i - (n - 1) / 2) * 30 + (team === 0 ? -24 : 0);
    m.pos.set(base.x + off, 0, base.z + (team === 0 ? -6 : 0)); A.clampPos(m.pos, m.radius + 4);
    m.pos.y = A.groundAt(m.pos.x, m.pos.z, 1e9, m.radius); m.yaw = m.input.yaw = team === 0 ? 0 : Math.PI;
    const ai = new AI(m, spec.ai || {}); this.ais.push(ai); m.spec = spec;
    if (this.state === 'fight') { w.fx.orb(m.center(_a).clone(), '#ffd9a0', 14, 0.5); w.fx.ring(m.pos.clone().setY(m.pos.y + 0.5), '#ffd9a0', 16, 0.6); sfxPlay('emp', m.pos, 0.6); }
    return m;
  }
  // ───── modo infinito ─────
  nextWave() {
    const n = ++this.wave, r = this.rng, boss = n % 5 === 0;
    const tier = Math.min(5, Math.floor((n - 1) / 2.2)), skill = clamp(0.1 + n * 0.045, 0, 0.95);
    const count = boss ? (n >= 10 ? 2 : 1) : Math.min(4, 1 + Math.floor(n / 3));
    // limpa carcaças abatidas
    this.world.mechs = this.world.mechs.filter(m => { if (m.alive || m === this.player) return true; m.dispose(); return false; });
    this.ais = this.ais.filter(a => a.m.alive);
    for (let i = 0; i < count; i++) {
      const isBoss = boss && i === 0, arch = isBoss ? r.pick(['fortress', 'brawler', 'energy']) : r.pick(ARCHETYPES);
      const b = randomBuild(r, isBoss ? Math.min(5, tier + 1) : tier, arch);
      const spec = { build: b, call: r.pick(CALLSIGNS), name: r.pick(MECHNAMES), ai: { ...b._ai, skill: isBoss ? Math.min(1, skill + 0.15) : skill }, hpMul: isBoss ? 1.7 + n * 0.05 : clamp(0.5 + n * 0.035, 0.5, 1.2) / (count > 2 ? 1.25 : 1), scale: isBoss ? 1.28 : count > 2 ? 0.88 : 1, boss: isBoss };
      const m = this.spawn(spec, 1, i, count);
      // entra pelas bordas, em volta do jogador
      const a = r() * Math.PI * 2, d = this.arena.size * 0.7; m.pos.set(Math.cos(a) * d, 0, Math.sin(a) * d); this.arena.clampPos(m.pos, m.radius + 6); m.pos.y = 40 + i * 6; m.grounded = false;
    }
    this.app.hud.banner(boss ? `ONDA ${n} — ALVO PRIORITÁRIO` : `ONDA ${n}`, boss ? 'Estrutura reforçada. Recompensa dobrada.' : `${count} ${count > 1 ? 'adversários' : 'adversário'}`);
    sfxPlay('alert');
  }
  perkChoices() {
    const r = this.rng, pool = PERKS.filter(p => (this.perks[p.id] || 0) < p.max), out = [];
    while (out.length < 3 && pool.length) out.push(pool.splice(r.int(0, pool.length - 1), 1)[0]);
    return out;
  }
  applyPerk(id) {
    const p = this.player, k = p.perk; this.perks[id] = (this.perks[id] || 0) + 1;
    switch (id) {
      case 'kdmg': k.k += 0.18; break; case 'edmg': k.e += 0.18; break; case 'xdmg': k.x += 0.18; break; case 'rof': k.rof += 0.12; break; case 'imp': k.imp += 0.25; break;
      case 'ammo': for (const s in p.weapons) p.weapons[s].refill(1.2); break; case 'kit': p.kits++; break; case 'plate': p.restoreParts(); break;
      case 'struct': { const add = p.stMax * 0.12; p.stMax += add; p.st += add; break; } case 'en': k.en += 0.25; break; case 'qb': k.qb *= 0.78; break; case 'salvage': k.salvage++; break;
      case 'stab': k.stab += 0.25; break; case 'missile': k.missile += 2; break; case 'direct': k.direct += 0.3; break; case 'shockr': k.shock++; break; case 'burn': k.burn++; break; case 'speed': k.speed += 0.1; break;
    }
    sfxPlay('buy');
  }

  update(rawDt) {
    if (this.paused) return;
    const w = this.world, p = this.player; this.t += rawDt;
    let dt = rawDt * this.timeScale;
    if (this.state === 'intro') {
      const c = 3 - Math.floor(this.t / 0.8); if (c !== this.lastCount && c > 0) { this.lastCount = c; this.app.hud.count(c); sfxPlay('count'); }
      if (this.t > 2.4) { this.state = 'fight'; this.app.hud.count(0); sfxPlay('go'); Input.frame(); }
    }
    const fighting = this.state === 'fight';
    if (fighting) { this.time += dt; if (this.auto) { this.auto.update(dt, w); this.camYaw = p.input.yaw; this.camPitch = p.pitch; } else this.control(rawDt); for (const a of this.ais) a.update(dt, w); }
    else if (this.state !== 'perk') { const I = p.input; I.mx = I.mz = 0; I.jump = I.qb = I.ab = I.jumpP = I.util = I.repair = false; for (const k in I.fire) I.fire[k] = false; for (const a of this.ais) { const J = a.m.input; J.mx = J.mz = 0; J.jump = J.qb = J.ab = false; for (const k in J.fire) J.fire[k] = false; } }
    if (this.state !== 'perk') w.update(dt);
    this.updateCamera(rawDt);
    this.arena.update(dt, this.cam.position, p.pos);
    // eventos
    for (const e of w.events) {
      if (e.type === 'kill') {
        if (e.mech === p) { if (this.state === 'fight') this.finish(false); }
        else if (e.mech.team !== 0) { this.kills++; this.score += Math.round(100 * (this.wave || 1) * (e.mech.spec && e.mech.spec.boss ? 5 : 1)); }
      }
      if (e.type === 'breach' && e.mech !== p && e.mech.team !== 0) this.breaches++;
    }
    this.app.hud.update(this, rawDt, w.events); w.events.length = 0;
    if (fighting) {
      const left = w.mechs.filter(m => m.team !== 0 && m.alive).length;
      if (left === 0) {
        if (this.cfg.sequence && this.queue.length) { this.spawn(this.queue.shift(), 1, 0); this.app.hud.banner('PRÓXIMO ADVERSÁRIO', `Restam ${this.queue.length + 1}`); }
        else if (this.cfg.endless) { this.state = 'clear'; this.t = 0; const pay = 1500 + 500 * this.wave * (this.wave % 5 === 0 ? 2 : 1); this.earned += pay; this.score += 250 * this.wave; this.app.hud.banner(`ONDA ${this.wave} LIMPA`, `+${pay.toLocaleString('pt-BR')} CR`); sfxPlay('ok'); }
        else this.finish(true);
      }
    } else if (this.state === 'clear' && this.t > 1.8) {
      this.state = 'perk'; Input.unlock(); p.st = Math.min(p.stMax, p.st + p.stMax * 0.15); p.en = p.enMax; setBoostLoop(0);
      this.app.ui.showPerks(this.perkChoices(), this, (id) => { if (id) this.applyPerk(id); this.state = 'fight'; this.nextWave(); Input.wantLock = true; Input.lock(); });
    } else if (this.state === 'over') { this.timeScale = lerp(this.timeScale, 0.3, Math.min(1, rawDt * 4)); if (this.t > 3.0) { this.state = 'done'; this.end(); } }
    // áudio contínuo
    setListener(this.cam.position.x, this.cam.position.y, this.cam.position.z, this.camYaw);
    const sp = Math.hypot(p.vel.x, p.vel.z); setBoostLoop(p.alive && this.state !== 'perk' ? clamp((p.abOn ? 1.6 : p.qbFx > 0 ? 1.5 : sp / 50) + (p.ascending ? 0.5 : 0), 0, 1.6) : 0);
  }
  finish(win) { if (this.state === 'over' || this.state === 'done') return; this.state = 'over'; this.t = 0; this.win = win; this.player.hardLock = false; this.app.hud.banner(win ? 'ADVERSÁRIO NEUTRALIZADO' : 'CARCAÇA PERDIDA', win ? '' : (this.cfg.endless ? `Onda ${this.wave}` : ''), true); sfxPlay(win ? 'win' : 'lose'); setMusic(0.2); }
  end() {
    const p = this.player; setBoostLoop(0);
    this.cfg.onEnd({ win: this.win, time: this.time, dealt: Math.round(p.dmgDealt), taken: Math.round(p.dmgTaken), kills: this.kills, wave: this.wave, score: this.score, earned: this.earned, breaches: this.breaches, left: Math.round(p.st / p.stMax * 100), perks: this.perks });
  }

  // ───── entrada do jogador ─────
  control(dt) {
    const p = this.player, I = p.input, K = Input.keys, P = Input.pressed, g = Input.gamepad();
    // mira
    let dx = Input.mdx, dy = Input.mdy;
    if (!Input.locked) { // sem trava de ponteiro: bordas da tela giram a câmera
      const ex = Input.cx - 0.5, ey = Input.cy - 0.5; if (Math.abs(ex) > 0.36) dx += Math.sign(ex) * (Math.abs(ex) - 0.36) * 9000 * dt; if (Math.abs(ey) > 0.38) dy += Math.sign(ey) * (Math.abs(ey) - 0.38) * 5000 * dt;
    }
    if (g) { dx += g.rx * 900 * dt; dy += g.ry * 600 * dt; }
    const s = 0.0022 * this.sens;
    const manual = Math.abs(dx) + Math.abs(dy) > 0.5;
    if (!p.hardLock || !p.target) { this.camYaw -= dx * s; this.camPitch = clamp(this.camPitch - dy * s * this.invY, -1.1, 1.25); }
    // travamento fixo
    if (P.KeyT || Input.btnP[1] || (g && g.p[11])) { if (p.hardLock) p.hardLock = false; else if (p.target) { p.hardLock = true; sfxPlay('lock'); } else this.cycleTarget(1, true); }
    if (P.Tab || Input.wheel !== 0 || (g && g.p[15])) this.cycleTarget(Input.wheel < 0 ? -1 : 1, false);
    if (p.hardLock && p.target) {
      _a.copy(p.target.center(_b)).sub(_c.set(p.pos.x, p.pos.y + p.height * 0.8, p.pos.z));
      const ty = Math.atan2(_a.x, _a.z), tp = Math.atan2(_a.y, Math.hypot(_a.x, _a.z)) + 0.07;
      let d = ty - this.camYaw; while (d > Math.PI) d -= Math.PI * 2; while (d < -Math.PI) d += Math.PI * 2;
      const k = Math.min(1, 12 * dt); this.camYaw += d * k; this.camPitch += (clamp(tp, -1.1, 1.25) - this.camPitch) * k;
    }
    // movimento
    let mx = (K.KeyD ? 1 : 0) - (K.KeyA ? 1 : 0), mz = (K.KeyW ? 1 : 0) - (K.KeyS ? 1 : 0);
    if (g) { mx += g.lx; mz -= g.ly; }
    I.mx = clamp(mx, -1, 1); I.mz = clamp(mz, -1, 1);
    I.jump = !!K.Space || !!(g && g.b[0]); I.jumpP = !!P.Space || !!(g && g.p[0]);
    I.qb = !!P.ShiftLeft || !!P.ShiftRight || !!(g && g.p[2]);
    I.ab = !!P.ControlLeft || !!P.KeyC || !!(g && g.p[10]);
    I.fire.handL = Input.btn[0] || !!(g && g.b[4]); I.fire.handR = Input.btn[2] || !!(g && g.b[5]);
    I.fire.backL = !!K.KeyQ || !!(g && g.b[6]); I.fire.backR = !!K.KeyE || !!(g && g.b[7]);
    I.fire.shoulder = !!K.KeyR || !!(g && g.b[12]); I.util = !!P.KeyF || !!(g && g.p[13]); I.repair = !!P.KeyG || !!(g && g.p[3]);
    I.yaw = this.camYaw;
  }
  cycleTarget(dir, nearestToCenter) {
    const p = this.player, w = this.world, c = p.center(_a).clone();
    const list = w.mechs.filter(m => m.alive && m.team !== 0 && !m.cloaked && m.center(_b).distanceTo(c) < p.lockRange && w.arena.los(c, m.center(_b)));
    if (!list.length || p.status.shock.t > 0 || p.parts.head.state === 2) { sfxPlay('error', null, 0.5); return; }
    const ang = (m) => { _c.copy(m.pos).sub(p.pos); let d = Math.atan2(_c.x, _c.z) - this.camYaw; while (d > Math.PI) d -= Math.PI * 2; while (d < -Math.PI) d += Math.PI * 2; return d; };
    list.sort((a, b) => nearestToCenter ? Math.abs(ang(a)) - Math.abs(ang(b)) : ang(a) - ang(b));
    let i = nearestToCenter ? 0 : (list.indexOf(p.target) + dir + list.length) % list.length; if (i < 0) i = 0;
    p.target = list[i]; p.lockProg = 0; p.trk.ok = false; p.hardLock = true; sfxPlay('lock');
  }
  updateCamera(dt, snap = false) {
    const p = this.player, cam = this.cam, w = this.world;
    const cy = Math.cos(this.camYaw), sy = Math.sin(this.camYaw), cp = Math.cos(this.camPitch), sp = Math.sin(this.camPitch);
    const fwd = _a.set(sy * cp, sp, cy * cp), right = _b.set(-cy, 0, sy);
    let dist = p.height * 2.15 + 3, yawOff = 0;
    if (this.state === 'intro') { const k = 1 - clamp(this.t / 2.2, 0, 1); yawOff = k * k * 2.6; dist += k * 10; }
    if (this.state === 'over' && !this.win) dist += Math.min(18, this.t * 6);
    const pivot = _c.set(p.pos.x, p.pos.y + p.height * 0.8, p.pos.z);
    this.pivot = (this.pivot || pivot.clone()); this.pivot.lerp(pivot, snap ? 1 : Math.min(1, 18 * dt));
    const f2 = _d.set(Math.sin(this.camYaw + yawOff) * cp, sp, Math.cos(this.camYaw + yawOff) * cp);
    const want = new THREE.Vector3().copy(this.pivot).addScaledVector(f2, -dist).addScaledVector(right, p.radius * 1.25 * (yawOff ? 0 : 1)).add(new THREE.Vector3(0, 1.6, 0));
    // colisão da câmera
    const dir = want.clone().sub(this.pivot), len = dir.length(); dir.multiplyScalar(1 / len);
    const t = w.arena.ray(this.pivot, dir, len, _hit); if (t !== Infinity && t < len) want.copy(this.pivot).addScaledVector(dir, Math.max(2, t - 1.2));
    if (want.y < 1.2) want.y = 1.2; w.arena.clampPos(want, -2);
    cam.position.copy(want);
    const sh = w.fx.shake; if (sh > 0) cam.position.add(new THREE.Vector3((Math.random() - 0.5) * sh * 1.6, (Math.random() - 0.5) * sh * 1.6, (Math.random() - 0.5) * sh * 1.6));
    cam.lookAt(new THREE.Vector3().copy(cam.position).addScaledVector(f2, 100));
    const tf = p.abOn ? 76 : p.qbFx > 0 ? 68 : 62; this.fov = lerp(this.fov, tf, Math.min(1, 6 * dt)); if (Math.abs(cam.fov - this.fov) > 0.05) { cam.fov = this.fov; cam.updateProjectionMatrix(); }
    w.camPos.copy(cam.position); this.fill.position.copy(cam.position).add(_c.set(0, 6, 0)); this.fill.target.position.copy(this.pivot);
    // ponto de mira livre: raio da câmera a partir da frente da carcaça
    const I = p.input; I.aimDir.copy(fwd); I.aimOrigin = (I.aimOrigin || new THREE.Vector3()).copy(cam.position);
    if (!p.target) {
      const o = new THREE.Vector3().copy(cam.position).addScaledVector(fwd, dist + 4);
      let d = w.arena.ray(o, fwd, 600, _hit); const mh = w.rayMechs(o, fwd, Math.min(600, d), 0, null); if (mh) d = mh.t; if (d === Infinity) d = 400;
      I.aimPoint.copy(o).addScaledVector(fwd, Math.max(12, d));
    }
  }
  dispose() { this.app.hud.end(); this.world.dispose(); setBoostLoop(0); }
}
