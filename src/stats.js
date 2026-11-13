import { PART, PARTS, LEGTYPE } from './data.js';

export const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
export const lerp = (a, b, t) => a + (b - a) * t;

// RNG determinístico
export function mulberry(seed) {
  let a = seed >>> 0;
  const f = () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; };
  f.range = (lo, hi) => lo + (hi - lo) * f();
  f.int = (lo, hi) => Math.floor(lo + (hi - lo + 1) * f());
  f.pick = (arr) => arr[Math.floor(f() * arr.length)];
  f.chance = (p) => f() < p;
  return f;
}

export function partsOf(build) {
  const g = (k) => build[k] ? PART[build[k]] : null;
  const o = { head: g('head'), core: g('core'), arms: g('arms'), legs: g('legs'), gen: g('gen'), booster: g('booster'), fcs: g('fcs'),
    handR: g('handR'), handL: g('handL'), backR: g('backR'), backL: g('backL'), shoulder: g('shoulder'), util: g('util'),
    mods: (build.mods || []).map(id => PART[id]).filter(Boolean) };
  return o;
}

// Armas efetivas por gatilho (considera braços-arma)
export function weaponDefs(build) {
  const p = partsOf(build);
  const wa = p.arms && p.arms.kind === 'weapon' ? PART[p.arms.wa] : null;
  return { handR: wa || p.handR, handL: wa || p.handL, backR: p.backR, backL: p.backL, shoulder: p.shoulder };
}

export function computeStats(build) {
  const p = partsOf(build);
  const errors = [], warns = [];
  const need = ['head', 'core', 'arms', 'legs', 'gen', 'fcs'];
  for (const k of need) if (!p[k]) errors.push(`Falta ${k === 'gen' ? 'gerador' : k === 'fcs' ? 'FCS' : k}.`);
  if (errors.length) return { errors, warns, valid: false };

  const isTank = p.legs.type === 'tank';
  const bo = isTank ? p.legs.boost : p.booster;
  if (!isTank && !p.booster) errors.push('Sem propulsor instalado.');
  if (isTank && p.booster) errors.push('Chassi de esteira já tem propulsor embutido: remova o propulsor externo.');
  const armsWeapon = p.arms.kind === 'weapon';
  if (armsWeapon && (p.handR || p.handL)) errors.push('Braços-arma não têm mãos: remova as armas de mão.');

  const all = [p.head, p.core, p.arms, p.legs, p.gen, p.booster, p.fcs, p.handR, p.handL, p.backR, p.backL, p.shoulder, p.util, ...p.mods].filter(Boolean);

  // bônus agregados
  const bn = { cap: 0, out: 0, rech: 0, delay: 0, scan: 0, lock: 0, radar: 0, ecm: 0, thrust: 0, qb: 0, qbReload: 0, up: 0,
    armArms: 0, armCore: 0, armLegs: 0, armHead: 0, def: [0, 0, 0], stab: 0, ammo: 0, kits: 0, kitArmor: 0, heatRes: 0, shockRes: 0, cool: 0 };
  for (const it of all) {
    if (!it.bonus) continue;
    for (const [k, v] of Object.entries(it.bonus)) {
      if (k === 'def') { bn.def[0] += v[0]; bn.def[1] += v[1]; bn.def[2] += v[2]; } else bn[k] += v;
    }
  }

  // módulos: baias, pontos de fixação e conflitos
  if (p.mods.length > p.core.slots) errors.push(`O tronco tem ${p.core.slots} baias de módulo; há ${p.mods.length} instalados.`);
  const mounts = {};
  for (const m of p.mods) {
    if (mounts[m.mount]) errors.push(`${m.name} e ${mounts[m.mount].name} disputam o mesmo ponto de fixação.`);
    mounts[m.mount] = m;
    if (m.notLegs && m.notLegs.includes(p.legs.type)) errors.push(`${m.name} não cabe em pernas do tipo ${LEGTYPE[p.legs.type].toLowerCase()}.`);
    if (m.notCore && m.notCore.includes(p.core.cls)) errors.push(`${m.name} exige tronco médio ou pesado.`);
    if (m.needHand && armsWeapon) errors.push(`${m.name} só serve em braços com mão.`);
    for (const c of (m.conflicts || [])) if (p.mods.some(o => o.id === c) && m.id < c) errors.push(`${m.name} interfere com ${PART[c].name}.`);
  }
  const ids = p.mods.map(m => m.id);
  if (new Set(ids).size !== ids.length) errors.push('Módulo repetido.');
  if (p.shoulder && p.shoulder.noWide) {
    for (const b of [p.backR, p.backL]) if (b && b.wide) errors.push(`${p.shoulder.name} interfere com ${b.name} (unidade dorsal larga).`);
  }

  const weight = all.reduce((s, it) => s + it.w, 0);
  const legLoad = p.legs.load;
  const carried = weight - p.legs.w;
  if (carried > legLoad) errors.push(`Sobrecarga: as pernas suportam ${legLoad.toFixed(1)} t e carregam ${carried.toFixed(1)} t.`);
  const armWeight = (p.handR ? p.handR.w : 0) + (p.handL ? p.handL.w : 0);
  const armLoad = p.arms.load;
  const armOver = !armsWeapon && armWeight > armLoad;
  if (armOver) warns.push(`Braços sobrecarregados (${armWeight.toFixed(1)}/${armLoad} t): mira e recuo piores.`);

  const enLoad = all.reduce((s, it) => s + (it.en || 0), 0);
  const enOut = Math.round(p.gen.out * p.core.out + bn.out);
  if (enLoad > enOut) errors.push(`Falta energia: consumo ${enLoad} EN, saída do gerador ${enOut} EN.`);
  const enCap = p.gen.cap + bn.cap;
  // sobra de saída acelera a recarga
  const surplus = clamp((enOut - enLoad) / enOut, 0, 0.6);
  const enRech = p.gen.rech * (1 + bn.rech) * (0.8 + surplus * 1.2);
  const enDelay = Math.max(0.3, p.gen.delay + bn.delay);

  const partArmor = {
    head: p.head.arm + bn.armHead,
    core: p.core.arm + bn.armCore,
    armR: p.arms.arm + bn.armArms,
    armL: p.arms.arm + bn.armArms,
    legs: p.legs.arm + bn.armLegs,
  };
  const structure = p.head.ap + p.core.ap + p.arms.ap + p.legs.ap;
  const dz = (part) => [0, 1, 2].map(i => part.def[i] + bn.def[i]);
  const def = { head: dz(p.head), core: dz(p.core), armR: dz(p.arms), armL: dz(p.arms), legs: dz(p.legs) };
  const defAvg = [0, 1, 2].map(i => Math.round((def.head[i] * 0.1 + def.core[i] * 0.4 + def.armR[i] * 0.2 + def.legs[i] * 0.3)));
  const stab = p.head.stab + p.core.stab + p.legs.stab + bn.stab;

  const loadRatio = carried / legLoad;
  const wf = clamp(1.36 - weight / 200, 0.55, 1.2) * (loadRatio > 0.9 ? 0.94 : 1);
  const thrust = bo ? bo.thrust * (1 + bn.thrust) : 0.5;
  const boostSpeed = 36 * thrust * wf;
  const groundSpeed = p.legs.speed * (0.75 + wf * 0.3);
  const qbSpeed = 92 * (bo ? bo.qb : 0.6) * (1 + bn.qb) * (0.7 + 0.3 * wf);
  const qbCost = bo ? bo.qbCost : 700;
  const qbReload = Math.max(0.25, (bo ? bo.qbReload : 1.2) * (1 + bn.qbReload));
  const upThrust = (bo ? bo.up : 0.5) * (1 + bn.up) * (0.75 + 0.35 * wf);
  const abSpeed = 74 * (bo ? bo.ab : 0.6) * (0.75 + 0.3 * wf);
  const lockRange = p.fcs.range * p.head.scan * (1 + bn.scan);
  const lockTime = Math.max(0.2, p.fcs.lock * (1 + bn.lock));
  const radar = p.head.radar + bn.radar;
  const track = p.arms.track * (armOver ? 0.6 : 1);

  return {
    valid: errors.length === 0, errors, warns,
    weight, carried, legLoad, armWeight, armLoad, armOver, enLoad, enOut, enCap, enRech, enDelay,
    partArmor, structure, def, defAvg, stab,
    boostSpeed, groundSpeed, qbSpeed, qbCost, qbReload, upThrust, abSpeed, jump: p.legs.jump * (0.8 + 0.25 * wf),
    lockRange, lockTime, radar, track, melee: p.arms.melee, fcs: p.fcs, eb: p.gen.eb || 0,
    kits: 3 + bn.kits, kitArmor: bn.kitArmor, ammoMul: 1 + bn.ammo, heatRes: bn.heatRes, shockRes: bn.shockRes, cool: 1 + bn.cool, ecm: bn.ecm,
    legType: p.legs.type, isTank, armsWeapon, slots: p.core.slots, cls: p.core.cls,
    anchorMul: p.legs.id === 'hb_l2' ? 0.5 : 1,
  };
}

// DPS aproximado (para a ficha da garagem)
export function weaponDps(w) {
  if (!w || !w.dmg) return 0;
  if (w.wt === 'melee') return w.dmg / w.cd;
  if (w.wt === 'missile') return w.dmg * w.n * (w.sub || 1) / w.rel;
  if (w.wt === 'drone') return w.dmg * w.n * w.rof * w.life / (w.rel + w.life);
  const per = w.dmg * (w.pel || 1) * (w.burst || 1);
  if (w.mag && w.rel) { const t = w.mag / w.rof + w.rel; return per * w.mag / t; }
  return per * w.rof;
}

// ───────── gerador de montagens (contratos / modo infinito) ─────────
const ARCH = {
  striker: { legs: ['biped', 'reverse'], cls: ['light', 'medium'], hands: ['rifle', 'smg', 'shotgun', 'pistol', 'pulse', 'melee'], backs: ['missile'], agg: 0.8, air: 0.4 },
  brawler: { legs: ['biped', 'tank'], cls: ['medium', 'heavy'], hands: ['shotgun', 'flame', 'melee', 'pistol', 'saw', 'bazooka'], backs: ['gatling', 'missile'], agg: 1.0, air: 0.1 },
  missile: { legs: ['quad', 'biped', 'reverse'], cls: ['medium'], hands: ['rifle', 'smg'], backs: ['missile', 'missile'], agg: 0.35, air: 0.5, keep: 180 },
  sniper: { legs: ['quad', 'biped', 'reverse'], cls: ['light', 'medium'], hands: ['brifle', 'linear', 'laser'], backs: ['heavy', 'missile'], agg: 0.2, air: 0.3, keep: 240 },
  fortress: { legs: ['tank', 'quad'], cls: ['heavy', 'medium'], hands: ['bazooka', 'rifle', 'brifle', 'shotgun'], backs: ['heavy', 'gatling', 'missile'], agg: 0.5, air: 0.0 },
  energy: { legs: ['biped', 'quad', 'reverse'], cls: ['medium', 'light'], hands: ['laser', 'plasma', 'pulse', 'arc', 'melee'], backs: ['energy', 'drone'], agg: 0.55, air: 0.45 },
};
const HANDTAG = { qf_r0: 'rifle', qf_k0: 'melee', tsk_m1: 'smg', qf_f1: 'flame', qf_s2: 'shotgun', hb_h1: 'pistol', hb_r3: 'brifle', tsk_k2: 'melee', qf_g3: 'bazooka', mrs_e2: 'shield', hb_b5: 'bazooka', mrs_p1: 'pulse', qf_x3: 'bazooka', qf_k1: 'saw', nle_l2: 'laser', hb_k4: 'melee', nle_s5: 'arc', nle_p4: 'plasma', mrs_r6: 'linear' };
const BACKTAG = { qf_bm0: 'missile', mrs_bv2: 'missile', mrs_bg3: 'none', hb_bg5: 'gatling', hb_bc3: 'heavy', mrs_bs4: 'missile', tsk_bd3: 'drone', nle_bp5: 'energy', nle_bl4: 'energy', mrs_bc6: 'missile', hb_br6: 'heavy', nle_bb1: 'none', mrs_br2: 'none', tsk_bj4: 'none' };
export const ARCHETYPES = Object.keys(ARCH);

const PAINTS = [
  ['#6e7468', '#c9541e', '#22252a', '#ff9a3c'], ['#3a4a57', '#d8d2bd', '#1c2126', '#7fd0ff'], ['#7a2e24', '#d6c9a8', '#1e1b1a', '#ff6a3a'],
  ['#c9c4b4', '#30343a', '#24262a', '#ffd27a'], ['#44503a', '#b9a05a', '#1c1f1a', '#d8ff7a'], ['#2b2b30', '#8a8f96', '#141416', '#ff4433'],
  ['#8c7a55', '#3b3a36', '#22211f', '#ffb347'], ['#d0cdc2', '#b02a22', '#25272a', '#ff5540'], ['#1f3a4a', '#c8a23a', '#131c22', '#6ff3e0'],
  ['#55595e', '#e0b23a', '#1b1c1e', '#ffe08a'], ['#5c3d52', '#cfc8bb', '#1d1a1e', '#ff8ad0'],
];

export function randomBuild(rng, tier, archName) {
  const A = ARCH[archName] || ARCH[rng.pick(ARCHETYPES)];
  const pool = (slot, f = () => true) => PARTS.filter(p => p.slot === slot && (p.tier ?? 9) <= tier && f(p));
  const pickBest = (arr) => {
    // favorece peças do tier mais alto disponível
    if (!arr.length) return null;
    const w = arr.map(p => 1 + (p.tier || 0) * 1.5); let s = w.reduce((a, b) => a + b, 0) * rng();
    for (let i = 0; i < arr.length; i++) { s -= w[i]; if (s <= 0) return arr[i]; }
    return arr[arr.length - 1];
  };
  for (let tries = 0; tries < 60; tries++) {
    const legs = pickBest(pool('legs', p => A.legs.includes(p.type))) || pickBest(pool('legs'));
    const core = pickBest(pool('core', p => A.cls.includes(p.cls))) || pickBest(pool('core'));
    const armsAll = pool('arms', p => tries < 30 ? true : p.kind === 'hand');
    const arms = rng.chance(0.82) ? pickBest(armsAll.filter(p => p.kind === 'hand')) : pickBest(armsAll);
    const b = { name: '', head: pickBest(pool('head')).id, core: core.id, arms: arms.id, legs: legs.id, gen: pickBest(pool('gen')).id,
      booster: legs.type === 'tank' ? null : pickBest(pool('booster')).id, fcs: pickBest(pool('fcs')).id,
      handR: null, handL: null, backR: null, backL: null, shoulder: null, util: null, mods: [] };
    if (arms.kind === 'hand') {
      const hp = pool('hand', p => A.hands.includes(HANDTAG[p.id]));
      const guns = hp.filter(p => p.wt !== 'melee' && p.wt !== 'shield');
      b.handR = (pickBest(guns.length ? guns : pool('hand', p => p.wt === 'proj'))).id;
      if (rng.chance(0.85 - tries * 0.01)) b.handL = pickBest(hp.length ? hp : pool('hand')).id;
    }
    const bp = pool('back', p => A.backs.includes(BACKTAG[p.id]));
    if (bp.length && rng.chance(0.9 - tries * 0.01)) b.backR = pickBest(bp).id;
    if (bp.length && rng.chance(0.6 - tries * 0.01) && tier >= 1) b.backL = pickBest(bp).id;
    if (tier >= 1 && rng.chance(0.45)) { const sp = pool('shoulder', p => !p.noWide); if (sp.length) b.shoulder = pickBest(sp).id; }
    if (tier >= 2 && rng.chance(0.5)) { const up = pool('util', p => p.act !== 'hook'); if (up.length) b.util = pickBest(up).id; }
    const mp = pool('mod', p => !(p.notLegs || []).includes(legs.type) && !(p.notCore || []).includes(core.cls) && !(p.needHand && arms.kind !== 'hand'));
    const used = {};
    for (let i = 0; i < core.slots && mp.length; i++) {
      if (!rng.chance(0.55)) continue;
      const m = rng.pick(mp);
      if (used[m.mount] || b.mods.some(x => (PART[x].conflicts || []).includes(m.id))) continue;
      used[m.mount] = 1; b.mods.push(m.id);
    }
    const pc = rng.pick(PAINTS);
    b.paint = { a: pc[0], b: pc[1], c: pc[2], glow: pc[3], wear: rng.range(0.3, 0.9) };
    const st = computeStats(b);
    if (st.valid) { b._ai = { agg: clamp(A.agg + rng.range(-0.15, 0.15), 0, 1), air: clamp(A.air + rng.range(-0.15, 0.2), 0, 1), keep: A.keep }; return b; }
  }
  // fallback garantido
  return { name: '', head: 'qf_h0', core: 'qf_c0', arms: 'qf_a0', legs: 'qf_l0', gen: 'qf_g0', booster: 'qf_b0', fcs: 'qf_f0', handR: 'qf_r0', handL: null, backR: null, backL: null, shoulder: null, util: null, mods: [],
    paint: { a: '#6e7468', b: '#c9541e', c: '#22252a', glow: '#ff9a3c', wear: 0.6 }, _ai: { agg: 0.5, air: 0.2 } };
}
