// HUD de combate: silhueta de dano, arcos de estrutura/EN/impacto, retículo, radar e alertas.
import * as THREE from 'three';
import { PART } from './data.js';
import { partsOf, clamp } from './stats.js';
import { PARTS5, PART_PT } from './mech.js';
import { sfxPlay } from './audio.js';

const $ = (s, r = document) => r.querySelector(s);
const _v = new THREE.Vector3();
const pol = (cx, cy, r, deg) => { const a = (deg - 90) * Math.PI / 180; return [cx + r * Math.cos(a), cy + r * Math.sin(a)]; };
export function arc(cx, cy, r, a0, a1) { const [x0, y0] = pol(cx, cy, r, a0), [x1, y1] = pol(cx, cy, r, a1); const large = Math.abs(a1 - a0) > 180 ? 1 : 0, sweep = a1 > a0 ? 1 : 0; return `M${x0.toFixed(2)} ${y0.toFixed(2)}A${r} ${r} 0 ${large} ${sweep} ${x1.toFixed(2)} ${y1.toFixed(2)}`; }

// Silhueta esquemática (vista de trás: braço D à direita). viewBox 0 0 120 150
export function silhouette(build, cls = '') {
  const p = partsOf(build), mir = (pts) => pts.split(' ').map(q => { const [x, y] = q.split(','); return (120 - x) + ',' + y; }).join(' ');
  const poly = (part, pts) => `<polygon class="sp" data-p="${part}" points="${pts}"/>`;
  let s = '';
  const lt = p.legs.type;
  if (lt === 'biped') { const a = '45,86 58,86 57,112 61,140 43,140 46,112'; s += poly('legs', a) + poly('legs', mir(a)); }
  else if (lt === 'reverse') { const a = '47,86 58,86 53,104 60,122 55,134 60,142 42,142 49,122 42,104'; s += poly('legs', a) + poly('legs', mir(a)); }
  else if (lt === 'quad') { const a = '44,88 24,98 12,140 24,140 31,108 48,100', b = '50,98 45,120 40,142 51,142 55,120 58,100'; s += poly('legs', a) + poly('legs', mir(a)) + poly('legs', b) + poly('legs', mir(b)) + poly('legs', '46,86 74,86 72,100 48,100'); }
  else { const a = '14,104 42,104 44,142 12,142'; s += poly('legs', a) + poly('legs', mir(a)) + poly('legs', '40,90 80,90 84,130 36,130'); }
  const cc = p.core.cls;
  s += poly('core', cc === 'light' ? '49,44 71,44 67,84 53,84' : cc === 'heavy' ? '40,40 80,40 77,86 43,86' : '44,42 76,42 72,84 48,84');
  const hk = p.head.m.k;
  s += hk === 'fin' || hk === 'fox' ? poly('head', '60,16 69,29 66,38 54,38 51,29') : hk === 'dome' || hk === 'facet' ? `<circle class="sp" data-p="head" cx="60" cy="29" r="9.5"/>` : hk === 'bunker' ? poly('head', '49,26 71,26 71,38 49,38') : poly('head', '52,20 68,20 68,38 52,38');
  const ax = cc === 'heavy' ? 4 : cc === 'light' ? -3 : 0;
  const arm = (part, f) => { const sh = `${82 + ax},40 ${98 + ax},40 ${98 + ax},55 ${82 + ax},55`, lo = p.arms.kind === 'weapon' ? `${83 + ax},57 ${97 + ax},57 ${98 + ax},102 ${93 + ax},102 ${93 + ax},108 ${87 + ax},108 ${87 + ax},102 ${82 + ax},102` : `${84 + ax},57 ${96 + ax},57 ${95 + ax},92 ${85 + ax},92`; return poly(part, f(sh)) + poly(part, f(lo)); };
  s += arm('armR', x => x) + arm('armL', mir);
  if (p.backR) s += `<polygon class="sx" points="66,22 78,22 78,38 70,38"/>`;
  if (p.backL) s += `<polygon class="sx" points="${mir('66,22 78,22 78,38 70,38')}"/>`;
  if (p.shoulder) s += `<polygon class="sx" points="${84 + ax},33 ${96 + ax},33 ${96 + ax},38 ${84 + ax},38"/><polygon class="sx" points="${mir(`${84 + ax},33 ${96 + ax},33 ${96 + ax},38 ${84 + ax},38`)}"/>`;
  return `<svg class="sil ${cls}" viewBox="0 0 120 150">${s}</svg>`;
}
const stateCls = (P) => P.state === 2 ? 'x' : P.state === 1 ? 'b' : P.a / P.max < 0.4 ? 'w' : 'ok';

const KEYLBL = { handL: 'BTN ESQ', handR: 'BTN DIR', backL: 'Q', backR: 'E', shoulder: 'R', util: 'F' };
const SLOTLBL = { handL: 'MÃO E', handR: 'MÃO D', backL: 'DORSO E', backR: 'DORSO D', shoulder: 'OMBROS', util: 'UTIL' };

export class HUD {
  constructor(root) {
    this.root = root; this.alerts = []; this.cache = new Map();
    root.innerHTML = `
      <div id="h-vig"></div><div id="h-static"></div>
      <svg id="h-ret" viewBox="-220 -220 440 440">
        <defs><mask id="mseg"><path d="${arc(0, 0, 190, 215, 325)}" class="segmask" pathLength="100"/><path d="${arc(0, 0, 190, 145, 35)}" class="segmask" pathLength="100"/></mask></defs>
        <circle r="92" class="fcs"/><circle r="2.2" class="dot"/>
        <path d="M-16 0H-7M7 0H16M0 -16V-7M0 7V16" class="cross"/>
        <g mask="url(#mseg)"><path d="${arc(0, 0, 190, 215, 325)}" class="trk" pathLength="100"/><path id="h-en" d="${arc(0, 0, 190, 215, 325)}" class="en" pathLength="100"/>
        <path d="${arc(0, 0, 190, 145, 35)}" class="trk" pathLength="100"/><path id="h-imp" d="${arc(0, 0, 190, 145, 35)}" class="imp" pathLength="100"/></g>
        <text x="-200" y="96" class="lbl" text-anchor="end">EN</text><text id="h-entx" x="-200" y="110" class="num" text-anchor="end">0</text>
        <text x="200" y="96" class="lbl">IMPACTO</text><text id="h-imptx" x="200" y="110" class="num">0%</text>
        <text id="h-spd" x="-200" y="-100" class="num sm" text-anchor="end">0 km/h</text><text id="h-alt" x="200" y="-100" class="num sm">ALT 0</text>
        <g id="h-hit" opacity="0"><path d="M-12 -12L-5 -5M12 -12L5 -5M-12 12L-5 5M12 12L5 5" class="hitm"/></g>
        <g id="h-dmg"></g>
        <text id="h-qb" y="150" class="lbl" text-anchor="middle"></text>
      </svg>
      <div id="h-lock" hidden><svg viewBox="-60 -60 120 120"><g id="h-lk-rot"><path d="M-34 -14V-34H-14M14 -34H34V-14M34 14V34H14M-14 34H-34V14" class="lk"/></g>
        <path d="${arc(0, 0, 46, 200, 340)}" class="trk2"/><path id="h-lk-st" d="${arc(0, 0, 46, 200, 340)}" class="lkst" pathLength="100"/>
        <path d="${arc(0, 0, 46, 160, 20)}" class="trk2"/><path id="h-lk-imp" d="${arc(0, 0, 46, 160, 20)}" class="lkimp" pathLength="100"/>
        <circle id="h-lk-ms" r="26" class="lkms" pathLength="100"/></svg><div id="h-lk-tx"></div></div>
      <div id="h-tgt" hidden><div class="tg-l"><div id="h-tg-call"></div><div id="h-tg-name"></div></div><div id="h-tg-sil"></div><div class="tg-r"><div id="h-tg-st" class="num"></div><div id="h-tg-flag"></div></div></div>
      <div id="h-me"><svg viewBox="0 0 280 280" id="h-me-svg">
          <defs><mask id="mring"><path d="${arc(140, 140, 126, 225, 495)}" class="segmask2" pathLength="100"/></mask></defs>
          <g mask="url(#mring)"><path d="${arc(140, 140, 126, 225, 495)}" class="trk" pathLength="100"/><path id="h-st" d="${arc(140, 140, 126, 225, 495)}" class="st" pathLength="100"/></g>
          <path d="${arc(140, 140, 112, 200, 160)}" class="trk3"/>
          ${['heat', 'shock', 'corr'].map((k, i) => `<path d="${arc(140, 140, 138, 196 - i * 16, 184 - i * 16)}" class="trk3 w5"/><path id="h-s-${k}" d="${arc(140, 140, 138, 196 - i * 16, 184 - i * 16)}" class="stt ${k}" pathLength="100"/>`).join('')}
        </svg><div id="h-me-sil"></div>
        <div class="co" data-p="head" style="left:62%;top:14%"></div><div class="co" data-p="armL" style="left:8%;top:38%"></div><div class="co" data-p="armR" style="right:8%;top:38%"></div><div class="co" data-p="core" style="left:62%;top:44%"></div><div class="co" data-p="legs" style="left:66%;top:70%"></div>
        <div id="h-me-num"><span class="lbl">ESTRUTURA</span><span id="h-sttx" class="num big">0</span></div>
        <div id="h-kits"></div><div id="h-sttlbl"><span data-k="corr">COR</span><span data-k="shock">CHQ</span><span data-k="heat">CAL</span></div></div>
      <div id="h-wpn"></div>
      <div id="h-info"></div>
      <div id="h-radarbox"><svg id="h-radar" viewBox="-80 -80 160 160"><circle r="74" class="rd"/><circle r="37" class="rd2"/><path d="M0 -74V74M-74 0H74" class="rd2"/><path d="M0 -7L5 6H-5Z" class="rme"/><g id="h-blips"></g><text id="h-rd-off" y="4" text-anchor="middle" class="lbl" hidden>SEM SINAL</text><text y="-62" text-anchor="middle" class="lbl" id="h-rd-n"></text></svg></div>
      <div id="h-alerts"></div><div id="h-warn" hidden>MÍSSIL</div>
      <div id="h-banner" hidden><div id="h-bn-t"></div><div id="h-bn-s"></div></div><div id="h-count" hidden></div>
      <div id="h-help"></div>`;
    this.el = {}; root.querySelectorAll('[id]').forEach(e => { this.el[e.id] = e; });
    this.blips = []; for (let i = 0; i < 14; i++) { const c = document.createElementNS('http://www.w3.org/2000/svg', 'circle'); c.setAttribute('r', 3); c.setAttribute('class', 'blip'); c.style.display = 'none'; this.el['h-blips'].appendChild(c); this.blips.push(c); }
    this.dmgArcs = []; for (let i = 0; i < 6; i++) { const pth = document.createElementNS('http://www.w3.org/2000/svg', 'path'); pth.setAttribute('class', 'dmgarc'); pth.setAttribute('d', arc(0, 0, 130, -16, 16)); pth.style.opacity = 0; this.el['h-dmg'].appendChild(pth); this.dmgArcs.push({ el: pth, t: 0 }); }
    this.hitT = 0; this.bannerT = 0; this.helpT = 0;
  }
  set(id, v) { if (this.cache.get(id) !== v) { this.cache.set(id, v); this.el[id].textContent = v; } }
  attr(id, k, v) { const key = id + '|' + k; if (this.cache.get(key) !== v) { this.cache.set(key, v); this.el[id].setAttribute(k, v); } }
  begin(match) {
    this.root.hidden = false; this.cache.clear(); this.alerts.length = 0; this.el['h-alerts'].innerHTML = ''; this.el['h-banner'].hidden = true; this.el['h-count'].hidden = true; this.tgtRef = null;
    const p = match.player;
    this.el['h-me-sil'].innerHTML = silhouette(p.build);
    this.meParts = {}; this.el['h-me-sil'].querySelectorAll('.sp').forEach(e => { (this.meParts[e.dataset.p] || (this.meParts[e.dataset.p] = [])).push(e); });
    this.co = {}; this.root.querySelectorAll('#h-me .co').forEach(e => { this.co[e.dataset.p] = e; });
    // armas
    const slots = ['backL', 'backR', 'handL', 'handR', 'shoulder', 'util'];
    this.wp = {};
    this.el['h-wpn'].innerHTML = slots.map(k => {
      const d = k === 'util' ? p.P.util : p.weapons[k] && p.weapons[k].def; if (!d) return `<div class="wp empty ${k}"><span class="k">${KEYLBL[k]}</span><span class="nm">— ${SLOTLBL[k]} vazio —</span></div>`;
      const nm = d.name.replace(/^[A-Z]+-[A-Z0-9]+ /, '');
      return `<div class="wp ${k}" data-k="${k}"><svg viewBox="-22 -22 44 44"><circle r="17" class="wtrk"/><circle r="17" class="wring" pathLength="100" transform="rotate(-90)"/><circle r="10" class="wlock" pathLength="100" transform="rotate(-90)"/></svg><span class="k">${KEYLBL[k]}</span><span class="nm">${nm}</span><span class="am num"></span><span class="stx"></span></div>`;
    }).join('');
    this.el['h-wpn'].querySelectorAll('.wp[data-k]').forEach(e => { this.wp[e.dataset.k] = { el: e, ring: e.querySelector('.wring'), lock: e.querySelector('.wlock'), am: e.querySelector('.am'), stx: e.querySelector('.stx'), c: {} }; });
    const mods = Object.keys(match.cfg.mods || {});
    this.infoBase = `<div class="ttl">${match.cfg.title || ''}</div><div class="sub">${match.arena.def.name}</div>` + (mods.length ? `<div class="mods">${mods.map(m => `<span>${match.cfg.modNames[m]}</span>`).join('')}</div>` : '');
    this.el['h-info'].innerHTML = this.infoBase + '<div id="h-info2" class="num"></div>'; this.el['h-info2'] = $('#h-info2', this.root);
    this.el['h-help'].innerHTML = '<b>WASD</b> mover · <b>ESPAÇO</b> saltar/subir · <b>SHIFT</b> impulso rápido · <b>CTRL</b> sobreimpulso · <b>BOTÕES</b> mãos · <b>Q/E</b> dorso · <b>R</b> ombros · <b>F</b> utilitário · <b>G</b> reparo · <b>T</b> travar · <b>TAB</b> trocar alvo';
    this.helpT = match.app.save.wins + match.app.save.losses < 3 ? 14 : 5; this.el['h-help'].style.opacity = 1;
    this.resize(match);
  }
  resize(match) { const r = Math.tan(0.17) / Math.tan(62 * Math.PI / 360) * (innerHeight / 2); const sc = 440 / Math.min(innerHeight * 0.78, 620); this.attr('h-ret', 'data-r', '1'); this.root.querySelector('#h-ret .fcs').setAttribute('r', (r * sc).toFixed(1)); }
  end() { this.root.hidden = true; }
  count(n) { const e = this.el['h-count']; if (n > 0) { e.hidden = false; e.textContent = n; e.classList.remove('pop'); void e.offsetWidth; e.classList.add('pop'); } else { e.textContent = 'COMBATE'; e.classList.remove('pop'); void e.offsetWidth; e.classList.add('pop'); setTimeout(() => { e.hidden = true; }, 900); } }
  banner(t, s = '', hold = false) { const e = this.el['h-banner']; e.hidden = false; this.el['h-bn-t'].textContent = t; this.el['h-bn-s'].textContent = s; e.classList.remove('in'); void e.offsetWidth; e.classList.add('in'); this.bannerT = hold ? 99 : 2.6; }
  alert(text, cls = '') { const d = document.createElement('div'); d.className = 'al ' + cls; d.textContent = text; this.el['h-alerts'].prepend(d); this.alerts.push({ el: d, t: 2.4 }); while (this.alerts.length > 4) { const a = this.alerts.shift(); a.el.remove(); } }

  update(match, dt, events) {
    const p = match.player, w = match.world, cam = match.cam, E = this.el;
    // eventos
    for (const e of events) {
      if (e.type === 'hit') { this.hitT = 0.22; this.hitCrit = e.crit; E['h-hit'].setAttribute('class', e.shield ? 'sh' : e.crit ? 'crit' : ''); }
      else if (e.type === 'dmg' && e.from) { const a = this.dmgArcs.reduce((m, x) => x.t < m.t ? x : m); const dx = e.from.x - p.pos.x, dz = e.from.z - p.pos.z; a.ang = -(Math.atan2(dx, dz) - match.camYaw) * 180 / Math.PI; a.t = 0.9; a.el.setAttribute('transform', `rotate(${a.ang.toFixed(1)})`); }
      else if (e.type === 'note') this.alert(e.text);
      else if (e.type === 'alert') this.alert(e.text, 'red');
      else if (e.type === 'status') { if (e.mech === p) this.alert(e.text, 'red'); else if (e.mech.team !== 0) this.alert('ALVO: ' + e.text, 'amb'); }
      else if (e.type === 'breach') { if (e.mech === p) { this.alert(`${PART_PT[e.part].toUpperCase()}: BLINDAGEM ROMPIDA`, 'red'); sfxPlay('alert'); } else if (e.mech.team !== 0) this.alert(`ALVO: ${PART_PT[e.part].toUpperCase()} ROMPIDO`, 'amb'); }
      else if (e.type === 'destroy') { if (e.mech === p) this.alert(`${PART_PT[e.part].toUpperCase()} DESTRUÍDO`, 'red'); else if (e.mech.team !== 0) this.alert(`ALVO: ${PART_PT[e.part].toUpperCase()} DESTRUÍDO`, 'amb'); }
      else if (e.type === 'stagger') { if (e.mech === p) this.alert('POSTURA QUEBRADA', 'red'); else if (e.mech.team !== 0) this.alert('ALVO ATORDOADO — DANO DIRETO', 'amb'); }
    }
    for (let i = this.alerts.length - 1; i >= 0; i--) { const a = this.alerts[i]; a.t -= dt; if (a.t < 0.4) a.el.style.opacity = Math.max(0, a.t / 0.4); if (a.t <= 0) { a.el.remove(); this.alerts.splice(i, 1); } }
    if (this.bannerT < 90) { this.bannerT -= dt; if (this.bannerT <= 0 && !E['h-banner'].hidden) E['h-banner'].hidden = true; }
    if (this.helpT > 0) { this.helpT -= dt; if (this.helpT <= 0) E['h-help'].style.opacity = 0; }
    // retículo: EN, impacto, velocidade
    const en = p.en / p.enMax; this.attr('h-en', 'stroke-dasharray', `${(en * 100).toFixed(1)} 100`); this.attr('h-en', 'class', 'en' + (p.enLock ? ' lockd' : en < 0.25 ? ' low' : ''));
    this.set('h-entx', String(Math.round(p.en)));
    const imp = clamp(p.impact / p.stabMax, 0, 1); this.attr('h-imp', 'stroke-dasharray', `${(imp * 100).toFixed(1)} 100`); this.attr('h-imp', 'class', 'imp' + (p.staggered ? ' stg' : imp > 0.7 ? ' hi' : ''));
    this.set('h-imptx', p.staggered ? 'ATORDOADO' : Math.round(imp * 100) + '%');
    this.set('h-spd', Math.round(p.vel.length() * 3.6) + ' km/h'); this.set('h-alt', 'ALT ' + Math.round(p.pos.y) + ' m');
    this.set('h-qb', p.enLock ? 'EN ESGOTADA — AGUARDE' : p.abOn ? 'SOBREIMPULSO' : p.anchorT > 0 ? 'ANCORADO' : '');
    this.hitT -= dt; E['h-hit'].setAttribute('opacity', this.hitT > 0 ? Math.min(1, this.hitT / 0.1) : 0);
    for (const a of this.dmgArcs) if (a.t > 0) { a.t -= dt; a.el.style.opacity = Math.max(0, a.t / 0.9); }
    this.root.classList.toggle('free', !Input_locked());
    // silhueta e estrutura
    const sr = clamp(p.st / p.stMax, 0, 1); this.attr('h-st', 'stroke-dasharray', `${(sr * 100).toFixed(1)} 100`); this.attr('h-st', 'class', 'st' + (sr < 0.25 ? ' crit' : sr < 0.5 ? ' low' : ''));
    this.set('h-sttx', String(Math.max(0, Math.round(p.st))));
    for (const k of PARTS5) { const P = p.parts[k], c = stateCls(P), key = 'me' + k; if (this.cache.get(key) !== c) { this.cache.set(key, c); for (const e of this.meParts[k]) e.setAttribute('class', 'sp ' + c); this.co[k].className = 'co ' + c; }
      const tx = P.state === 2 ? 'DESTR.' : P.state === 1 ? 'ROMP.' : Math.round(P.a / P.max * 100) + '%'; if (this.cache.get(key + 't') !== tx) { this.cache.set(key + 't', tx); this.co[k].textContent = tx; } }
    const kk = p.kits; if (this.cache.get('kits') !== kk) { this.cache.set('kits', kk); E['h-kits'].innerHTML = '<span class="lbl">REPARO [G]</span>' + Array.from({ length: Math.max(kk, 3) }, (_, i) => `<i class="${i < kk ? 'on' : ''}"></i>`).join(''); }
    for (const k of ['heat', 'shock', 'corr']) { const s = p.status[k], on = s.t > 0; this.attr('h-s-' + k, 'stroke-dasharray', `${on ? 100 : s.v.toFixed(0)} 100`); this.attr('h-s-' + k, 'class', `stt ${k}` + (on ? ' on' : '')); }
    const vg = sr < 0.3 ? 'crit' : p.status.heat.t > 0 ? 'heat' : ''; if (this.cache.get('vig') !== vg) { this.cache.set('vig', vg); E['h-vig'].className = vg; }
    const stc = p.status.shock.t > 0 || p.parts.head.state === 2; if (this.cache.get('stc') !== stc) { this.cache.set('stc', stc); E['h-static'].className = stc ? (p.status.shock.t > 0 ? 'on' : 'half') : ''; }
    // armas
    for (const k in this.wp) {
      const W = this.wp[k]; let h;
      if (k === 'util') { const u = p.P.util; const tot = u.cd || 1; h = { ring: u.act === 'passive' ? 1 : 1 - clamp(p.utilCd / tot, 0, 1), state: u.act === 'passive' ? 'passive' : p.utilCd > 0 ? 'cool' : 'ok', txt: u.act === 'passive' ? 'PASSIVO' : '', ammo: u.charges ? String(p.utilCharges) : u.act === 'barrier' && p.barrier.t > 0 ? Math.round(p.barrier.hp) + '' : '', lock: 0 }; }
      else h = p.weapons[k].hud();
      const rv = (h.ring * 100).toFixed(0); if (W.c.r !== rv) { W.c.r = rv; W.ring.setAttribute('stroke-dasharray', `${rv} 100`); }
      if (W.c.s !== h.state) { W.c.s = h.state; W.el.dataset.s = h.state; } if (W.c.a !== h.ammo) { W.c.a = h.ammo; W.am.textContent = h.ammo; } if (W.c.t !== h.txt) { W.c.t = h.txt; W.stx.textContent = h.txt; }
      const lv = (h.lock * 100).toFixed(0); if (W.c.l !== lv) { W.c.l = lv; W.lock.setAttribute('stroke-dasharray', `${lv} 100`); W.el.classList.toggle('locked', h.lock >= 1); }
      const act = k !== 'util' && p.input.fire[k]; if (W.c.f !== act) { W.c.f = act; W.el.classList.toggle('fire', !!act); }
    }
    // alvo travado
    const t = p.target;
    if (t && t.alive) {
      _v.copy(t.center(_v)).project(cam);
      const on = _v.z < 1; E['h-lock'].hidden = !on;
      if (on) { E['h-lock'].style.transform = `translate(${((_v.x * 0.5 + 0.5) * innerWidth).toFixed(1)}px,${((-_v.y * 0.5 + 0.5) * innerHeight).toFixed(1)}px)`;
        this.attr('h-lk-rot', 'transform', `rotate(${p.hardLock ? 45 : (match.t * 60 % 360).toFixed(0)}) scale(${p.hardLock ? 0.82 : 1})`); E['h-lock'].classList.toggle('hard', p.hardLock);
        const ts = clamp(t.st / t.stMax, 0, 1), ti = clamp(t.impact / t.stabMax, 0, 1);
        this.attr('h-lk-st', 'stroke-dasharray', `${(ts * 100).toFixed(0)} 100`); this.attr('h-lk-imp', 'stroke-dasharray', `${(ti * 100).toFixed(0)} 100`); this.attr('h-lk-imp', 'class', 'lkimp' + (t.staggered ? ' stg' : ''));
        let ml = 0; for (const k in p.weapons) { const d = p.weapons[k].def; if (d.wt === 'missile' && d.lockT) ml = Math.max(ml, clamp(p.lockProg / (d.lockT * p.lockTimeMul), 0, 1)); }
        this.attr('h-lk-ms', 'stroke-dasharray', `${(ml * 100).toFixed(0)} 100`); this.attr('h-lk-ms', 'class', 'lkms' + (ml >= 1 ? ' full' : ''));
        this.set('h-lk-tx', Math.round(t.pos.distanceTo(p.pos)) + ' m'); }
      E['h-tgt'].hidden = false;
      if (this.tgtRef !== t) { this.tgtRef = t; this.set('h-tg-call', t.call || 'ALVO'); this.set('h-tg-name', t.name); E['h-tg-sil'].innerHTML = silhouette(t.build, 'mini'); this.tgParts = {}; E['h-tg-sil'].querySelectorAll('.sp').forEach(e => { (this.tgParts[e.dataset.p] || (this.tgParts[e.dataset.p] = [])).push(e); }); this.cache.delete('tgs'); for (const k of PARTS5) this.cache.delete('tg' + k); }
      for (const k of PARTS5) { const c = stateCls(t.parts[k]); if (this.cache.get('tg' + k) !== c) { this.cache.set('tg' + k, c); for (const e of this.tgParts[k]) e.setAttribute('class', 'sp ' + c); } }
      this.set('h-tg-st', Math.max(0, Math.round(t.st)) + ''); this.set('h-tg-flag', t.staggered ? 'ATORDOADO' : t.barrier.t > 0 ? 'BARREIRA' : t.status.heat.t > 0 ? 'EM CHAMAS' : t.status.shock.t > 0 ? 'EM CURTO' : t.status.corr.t > 0 ? 'CORROÍDO' : p.hardLock ? 'TRAVA FIXA' : 'TRAVA LIVRE');
    } else { E['h-lock'].hidden = true; E['h-tgt'].hidden = true; this.tgtRef = null; }
    // radar
    const rOff = p.parts.head.state > 0 || p.status.shock.t > 0; E['h-rd-off'].toggleAttribute('hidden', !rOff);
    let bi = 0; const rr = p.stats.radar, cy = Math.cos(match.camYaw), sy = Math.sin(match.camYaw); let left = 0;
    for (const m of w.mechs) { if (m === p || !m.alive) continue; if (m.team !== 0) left++; if (rOff || m.cloaked || bi >= this.blips.length) continue; const dx = m.pos.x - p.pos.x, dz = m.pos.z - p.pos.z; let rx = -(dx * cy - dz * sy), ry = -(dx * sy + dz * cy); let d = Math.hypot(rx, ry) / rr; if (d > 1) { rx /= d; ry /= d; } const b = this.blips[bi++]; b.style.display = ''; b.setAttribute('cx', (rx / rr * 72).toFixed(1)); b.setAttribute('cy', (ry / rr * 72).toFixed(1)); b.setAttribute('class', 'blip ' + (m.team === 0 ? 'ally' : m === t ? 'tg' : '') + (d > 1 ? ' far' : '')); b.setAttribute('r', m.pos.y - p.pos.y > 12 ? 4 : 3); }
    let warn = false;
    for (const pr of w.projs) { if (pr.pk !== 'missile' || pr.team === 0) continue; const d = pr.pos.distanceTo(p.pos); if (pr.target === p && d < 170) warn = true; if (rOff || bi >= this.blips.length || d > rr) continue; const dx = pr.pos.x - p.pos.x, dz = pr.pos.z - p.pos.z; const b = this.blips[bi++]; b.style.display = ''; b.setAttribute('cx', (-(dx * cy - dz * sy) / rr * 72).toFixed(1)); b.setAttribute('cy', (-(dx * sy + dz * cy) / rr * 72).toFixed(1)); b.setAttribute('class', 'blip ms'); b.setAttribute('r', 1.6); }
    for (; bi < this.blips.length; bi++) this.blips[bi].style.display = 'none';
    this.set('h-rd-n', Math.round(rr) + ' m');
    if (warn !== this.warnOn) { this.warnOn = warn; E['h-warn'].hidden = !warn; } if (warn) { this.warnT = (this.warnT || 0) - dt; if (this.warnT <= 0) { this.warnT = 0.45; sfxPlay('alert', null, 0.6); } }
    // informações da partida
    const tm = Math.floor(match.time), ts = String(Math.floor(tm / 60)).padStart(2, '0') + ':' + String(tm % 60).padStart(2, '0');
    this.set('h-info2', match.cfg.endless ? `ONDA ${match.wave} · ${match.score.toLocaleString('pt-BR')} PTS · ${left} VIVOS · ${ts}` : `${left} ${left === 1 ? 'ADVERSÁRIO' : 'ADVERSÁRIOS'} · ${ts}`);
  }
}
import { Input } from './input.js';
function Input_locked() { return Input.locked; }
