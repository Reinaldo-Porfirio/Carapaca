// Menus: título, hangar, Circuito, contratos, modo infinito, garagem, loja, opções, resultados.
import { PARTS, PART, MAKERS, SLOTS, CATS, DT, LEGTYPE, RIVALS, ARENAS, MODIFIERS, CONTRACT_TYPES, CALLSIGNS, MECHNAMES, tierForRank, CLASS_TIER } from './data.js';
import { computeStats, weaponDps, randomBuild, mulberry, ARCHETYPES, partsOf, clamp } from './stats.js';
import { persist, playerRank, usedCount, wipe } from './save.js';
import { silhouette } from './hud.js';
import { sfxPlay, setVolume, initAudio, setMusic } from './audio.js';

const cr = (n) => Math.round(n).toLocaleString('pt-BR') + ' CR';
const f1 = (n) => n.toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 });
const f0 = (n) => Math.round(n).toLocaleString('pt-BR');
const pct = (v) => (v > 0 ? '+' : '') + Math.round(v * 100) + '%';
const TIERCLS = ['E', 'D', 'C', 'B', 'A', 'S'];
const esc = (s) => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

const BONUS = { cap: ['Reserva de EN', f0], out: ['Saída de EN', f0], rech: ['Recarga de EN', pct], delay: ['Retomada da recarga', v => f1(v) + ' s'], scan: ['Alcance de trava', pct], lock: ['Tempo de trava', pct], radar: ['Radar', v => '+' + v + ' m'], ecm: ['Desvio de mísseis inimigos', pct],
  thrust: ['Empuxo', pct], qb: ['Força do impulso rápido', pct], qbReload: ['Espera do impulso rápido', pct], up: ['Subida', pct], armArms: ['Blindagem dos braços', v => '+' + v], armCore: ['Blindagem do tronco', v => '+' + v], armLegs: ['Blindagem das pernas', v => '+' + v],
  def: ['Defesa C / E / X', v => v.map(x => '+' + x).join(' / ')], stab: ['Estabilidade', v => '+' + v], ammo: ['Munição', pct], kits: ['Kits de reparo', v => '+' + v], kitArmor: ['Blindagem por kit', pct], heatRes: ['Resistência a calor', pct], shockRes: ['Resistência a choque', pct], cool: ['Resfriamento de armas', pct] };
const WT = { proj: 'Projétil', beam: 'Feixe', cone: 'Contato contínuo', melee: 'Corpo a corpo', shield: 'Escudo', missile: 'Míssil', drone: 'Drones', passive: 'Passivo', active: 'Ativo' };
const MK = { direct: 'direto', vertical: 'vertical em arco', swarm: 'enxame', guided: 'teleguiado', cluster: 'fragmentação' };

export function specRows(p) {
  const r = [];
  const add = (l, v) => r.push([l, v]);
  if (p.arm !== undefined) { add(p.slot === 'arms' ? 'Blindagem (cada)' : 'Blindagem', f0(p.arm)); add('Estrutura', f0(p.ap)); add('Defesa C / E / X', p.def.join(' / ')); }
  switch (p.slot) {
    case 'head': add('Estabilidade', p.stab); add('Alcance de trava', '×' + p.scan.toFixed(2)); add('Radar', p.radar + ' m'); break;
    case 'core': add('Estabilidade', p.stab); add('Baias de módulo', p.slots); add('Saída do gerador', '×' + p.out.toFixed(2)); add('Classe', { light: 'Leve', medium: 'Média', heavy: 'Pesada' }[p.cls]); break;
    case 'arms': add('Tipo', p.kind === 'hand' ? 'Com mãos' : 'Braços-arma'); if (p.kind === 'hand') { add('Carga dos braços', p.load + ' t'); add('Corpo a corpo', '×' + p.melee.toFixed(2)); } add('Rastreio', p.track.toFixed(2)); break;
    case 'legs': add('Tipo', LEGTYPE[p.type]); add('Capacidade de carga', p.load + ' t'); add('Estabilidade', p.stab); add('Velocidade no solo', Math.round(p.speed * 3.6) + ' km/h'); add('Salto', p.jump); if (p.boost) add('Propulsor', 'Embutido'); break;
    case 'gen': add('Reserva de EN', f0(p.cap)); add('Saída de EN', f0(p.out)); add('Recarga', f0(p.rech) + ' /s'); add('Retomada', f1(p.delay) + ' s'); if (p.eb) add('Armas de energia', pct(p.eb)); break;
    case 'booster': add('Empuxo', p.thrust.toFixed(2)); add('Impulso rápido', p.qb.toFixed(2)); add('Custo do impulso', p.qbCost + ' EN'); add('Espera do impulso', p.qbReload.toFixed(2) + ' s'); add('Subida', p.up.toFixed(2)); add('Sobreimpulso', p.ab.toFixed(2)); break;
    case 'fcs': add('Alcance de trava', p.range + ' m'); add('Tempo de trava', '×' + p.lock.toFixed(2)); add('Precisão curta / média / longa', [p.near, p.mid, p.far].map(x => x.toFixed(1)).join(' / ')); break;
  }
  const w = p.slot === 'arms' && p.wa ? PART[p.wa] : p;
  if (w.wt || p.wa) {
    add('Arma', WT[w.wt] + (w.mk2 ? ' ' + MK[w.mk2] : '') + (p.wa ? ' — ' + w.name : ''));
    if (w.dmg) { add('Dano', f0(w.dmg) + (w.pel ? ' ×' + w.pel : '') + (w.n > 1 ? ' ×' + w.n : '') + (w.sub ? ' ×' + w.sub : '') + (w.burst ? ' ×' + w.burst : '') + ' · ' + DT[w.dt]); add('Impacto', f0(w.imp || 0)); add('Dano por segundo', f0(weaponDps(w))); }
    if (w.rof) add('Cadência', w.rof >= 1 ? f1(w.rof) + ' /s' : f1(1 / w.rof) + ' s por tiro');
    if (w.mag > 1) add('Pente / recarga', w.mag + ' / ' + f1(w.rel) + ' s'); else if (w.rel && w.wt !== 'proj') add('Recarga', f1(w.rel) + ' s');
    if (w.cd && w.wt === 'melee') add('Intervalo', f1(w.cd) + ' s');
    if (w.ammo) add('Munição', w.ammo); else if (w.enc) add('Munição', 'Ilimitada (usa EN)');
    if (w.rng) add('Alcance', w.rng + ' m'); if (w.lunge) add('Avanço', w.lunge + ' m');
    if (w.spd) add('Velocidade do projétil', w.spd + ' m/s'); if (w.enc) add('EN por disparo', w.enc); if (w.ht) add('Calor por disparo', w.ht + '%');
    if (w.chg) add('Carga', f1(w.chg.t) + ' s' + (w.chg.mul > 1 ? ' → ×' + w.chg.mul : '') + (w.chg.req ? ' (obrigatória)' : ''));
    if (w.spl) add('Raio da explosão', w.spl + ' m'); if (w.lockT) add('Travamento', f1(w.lockT) + ' s');
    if (w.st) add('Acúmulo de status', Object.entries(w.st).map(([k, v]) => ({ heat: 'calor', shock: 'choque', corr: 'corrosão' }[k]) + ' ' + v).join(', '));
    if (w.heavy) add('Arma pesada', 'Bípedes ancoram para disparar'); if (w.block) add('Bloqueio / aparo', Math.round(w.block * 100) + '% / ' + Math.round(w.parry * 100) + '%');
  }
  if (p.act && p.slot === 'util') { if (p.cd) add('Espera', f1(p.cd) + ' s'); if (p.rng) add('Alcance', p.rng + ' m'); if (p.hp) add('Absorção', f0(p.hp)); if (p.dur) add('Duração', f1(p.dur) + ' s'); if (p.charges) add('Cargas', p.charges); if (p.dmg) add('Dano', f0(p.dmg)); if (p.rad) add('Raio', p.rad + ' m'); }
  if (p.slot === 'shoulder' && p.act) { add('Espera', f1(p.cd) + ' s'); if (p.rad) add('Raio', p.rad + ' m'); if (p.charges) add('Cargas', p.charges); }
  if (p.bonus) for (const [k, v] of Object.entries(p.bonus)) if (BONUS[k]) add(BONUS[k][0], BONUS[k][1](v));
  add('Peso', f1(p.w) + ' t'); add('Carga de EN', p.en || 0);
  const lim = [];
  if (p.wide) lim.push('Unidade larga: não convive com saias de ombro'); if (p.noWide) lim.push('Bloqueia unidades dorsais largas'); if (p.notLegs) lim.push('Não cabe em: ' + p.notLegs.map(t => LEGTYPE[t].toLowerCase()).join(', ')); if (p.notCore) lim.push('Exige tronco médio ou pesado'); if (p.needHand) lim.push('Exige braços com mão');
  if (p.conflicts) lim.push('Interfere com: ' + p.conflicts.map(c => PART[c].name).join(', ')); if (p.kind === 'weapon') lim.push('Sem mãos: impede armas de mão'); if (p.slot === 'legs' && p.boost) lim.push('Impede propulsor externo'); if (p.mount) lim.push('Ponto de fixação: ' + { chest: 'peito', legs: 'pernas', hip: 'quadril', arms: 'antebraços', backtop: 'dorso superior', waist: 'cintura', hipback: 'lombar', coat: 'revestimento', mast: 'mastro' }[p.mount]);
  return { rows: r, lim };
}
const specHtml = (p) => { const s = specRows(p); return `<table class="spec">${s.rows.map(([l, v]) => `<tr><td>${l}</td><td>${v}</td></tr>`).join('')}</table>` + (s.lim.length ? `<ul class="lim">${s.lim.map(l => `<li>${l}</li>`).join('')}</ul>` : ''); };
const mkTag = (p) => `<span class="mk" style="--mk:${MAKERS[p.mk].color}">${p.mk}</span>`;

const STATROWS = [
  ['Estrutura', s => s.structure, f0, 1], ['Blindagem somada', s => s.partArmor.head + s.partArmor.core + s.partArmor.armR * 2 + s.partArmor.legs, f0, 1],
  ['Defesa cinética', s => s.defAvg[0], f0, 1], ['Defesa de energia', s => s.defAvg[1], f0, 1], ['Defesa explosiva', s => s.defAvg[2], f0, 1], ['Estabilidade', s => s.stab, f0, 1], null,
  ['Peso total', s => s.weight, v => f1(v) + ' t', -1], ['Reserva de EN', s => s.enCap, f0, 1], ['Recarga de EN', s => s.enRech, v => f0(v) + ' /s', 1], ['Retomada da recarga', s => s.enDelay, v => f1(v) + ' s', -1], null,
  ['Velocidade de impulso', s => s.boostSpeed * 3.6, v => f0(v) + ' km/h', 1], ['Impulso rápido', s => s.qbSpeed * 3.6, v => f0(v) + ' km/h', 1], ['Espera do impulso', s => s.qbReload, v => v.toFixed(2) + ' s', -1], ['Salto', s => s.jump, f1, 1], null,
  ['Alcance de trava', s => s.lockRange, v => f0(v) + ' m', 1], ['Tempo de trava', s => s.lockTime, v => '×' + v.toFixed(2), -1], ['Rastreio dos braços', s => s.track, v => v.toFixed(2), 1], ['Kits de reparo', s => s.kits, f0, 1],
];

export class UI {
  constructor(app, root) {
    this.app = app; this.root = root; this.screen = ''; this.sel = {}; this.contractList = null; this.overlay = document.getElementById('overlay');
    const click = (e) => { const el = e.target.closest('[data-act]'); if (!el || el.disabled) return; e.preventDefault(); this.act(el.dataset.act, el.dataset, el); };
    root.addEventListener('click', click); this.overlay.addEventListener('click', click);
    root.addEventListener('mouseover', (e) => { const el = e.target.closest('[data-hov]'); if (el && el !== this.lastHov) { this.lastHov = el; sfxPlay('hover'); this.hover(el.dataset.hov, el.dataset); } });
    root.addEventListener('mouseleave', () => { this.lastHov = null; }, true);
    root.addEventListener('input', (e) => { const el = e.target; if (el.dataset.inp) this.input(el.dataset.inp, el); });
  }
  get save() { return this.app.save; }
  hide() { this.root.hidden = true; this.root.innerHTML = ''; this.screen = ''; }
  show(name, arg) {
    this.screen = name; this.root.hidden = false; this.overlay.hidden = true; this.overlay.innerHTML = ''; this.lastHov = null;
    this.root.className = 'scr-' + name; this[name](arg); this.root.scrollTop = 0;
  }
  topbar(title, sub = '') {
    const s = this.save, r = playerRank(s);
    return `<header class="top"><button class="back" data-act="menu">◂ HANGAR</button><div class="tt"><h2>${title}</h2><span>${sub}</span></div><div class="wallet"><span class="lbl">SALDO</span><b class="num">${cr(s.credits)}</b><span class="lbl">POSIÇÃO</span><b class="num">${r > 18 ? 'S/R' : r + 'º'}</b></div></header>`;
  }

  // ───────── título e menu ─────────
  title() {
    this.app.hangar.showMech(this.save.build); this.app.hangar.view(0.16, 36);
    this.root.innerHTML = `<div class="titlebox"><div class="pre">CIRCUITO FORNALHA <i></i> TEMPORADA 31 <i></i> LICENÇA DE OPERADOR Nº 0-7731</div><h1>CARCAÇA</h1>
      <p>Combate de arena entre carcaças blindadas montadas peça por peça. Cada tonelada pesa nas pernas, cada arma puxa do gerador, cada placa que cai deixa algo exposto.</p>
      <button class="btn pri" data-act="enter">ENTRAR NO HANGAR</button>
      <div class="foot">Teclado e mouse, ou controle. Progresso salvo neste navegador.</div></div>`;
  }
  menu() {
    const s = this.save, r = playerRank(s), st = computeStats(s.build), next = RIVALS.find(v => v.rank === r - 1), tier = tierForRank(r);
    this.app.hangar.showMech(s.build); this.app.hangar.view(0.17, 0);
    const it = (act, t, d, warn) => `<button class="mi" data-act="${act}" data-hov="mi"><b>${t}</b><span class="${warn ? 'warn' : ''}">${d}</span></button>`;
    this.root.innerHTML = `<div class="menu"><div class="brand"><h1>CARCAÇA</h1><span>CIRCUITO FORNALHA · T31</span></div>
      <nav>${it('go:league', 'CIRCUITO', r <= 1 ? 'Você é a campeã da temporada' : `${r > 18 ? 'Sem posição' : r + 'º lugar'} · próximo: ${next.call}`)}
      ${it('go:contracts', 'CONTRATOS', 'Quatro no mural · regras e pagamento variam')}
      ${it('go:endless', 'MODO INFINITO', s.bestWave ? `Recorde: onda ${s.bestWave} · ${f0(s.bestScore)} pts` : 'Ondas sem fim, melhorias entre elas')}
      ${it('test', 'CAMPO DE TESTES', 'Adversário passivo, sem recompensa')}
      <hr>${it('go:garage', 'GARAGEM', st.valid ? `${esc(s.build.name)} · pronta para combate` : `${esc(s.build.name)} · montagem irregular`, !st.valid)}
      ${it('go:shop', 'LOJA', `Catálogo classe ${TIERCLS[tier]} liberado`)}
      ${it('go:options', 'OPÇÕES', 'Áudio, mira, gráficos, controles')}</nav></div>
      <div class="plate"><div class="row"><span class="lbl">OPERADOR</span><b>Nº 0-7731</b></div><div class="row"><span class="lbl">SALDO</span><b class="num">${cr(s.credits)}</b></div><div class="row"><span class="lbl">CARCAÇA</span><b>${esc(s.build.name)}</b></div><div class="row"><span class="lbl">HISTÓRICO</span><b class="num">${s.wins} V · ${s.losses} D</b></div><div class="hint">Arraste para girar · roda do mouse aproxima</div></div>`;
  }

  // ───────── Circuito ─────────
  league() {
    const s = this.save, r = playerRank(s); this.sel.rival = this.sel.rival || Math.max(1, r - 1);
    this.root.innerHTML = this.topbar('CIRCUITO', 'Dezoito pilotos entre você e o topo. Cada vitória inédita paga o prêmio cheio e pode liberar uma classe da loja.') +
      `<div class="cols"><section class="panel list ladder">${RIVALS.slice().reverse().map(v => { const beaten = s.beaten.includes(v.rank), open = v.rank >= r - 1; return `<button class="rv ${beaten ? 'done' : ''} ${open ? '' : 'locked'} ${v.rank === this.sel.rival ? 'on' : ''}" data-act="rival" data-rank="${v.rank}" data-hov="x"><span class="rk num">${String(v.rank).padStart(2, '0')}</span><span class="cl">${v.cls}</span><span class="nm"><b>${v.call}</b><i>${v.mech}</i></span><span class="pz num">${beaten ? 'VENCIDO' : open ? cr(v.prize) : 'BLOQUEADO'}</span></button>`; }).reverse().join('')}</section>
      <section class="panel detail" id="rv-detail"></section></div>`;
    this.rivalDetail();
  }
  rivalDetail() {
    const s = this.save, r = playerRank(s), v = RIVALS.find(x => x.rank === this.sel.rival), st = computeStats(v.build), p = partsOf(v.build), beaten = s.beaten.includes(v.rank), open = v.rank >= r - 1, me = computeStats(s.build);
    this.app.hangar.showMech(v.build); this.app.hangar.view(-0.02, 0);
    const wl = ['handR', 'handL', 'backR', 'backL', 'shoulder', 'util'].map(k => p[k]).filter(Boolean).map(x => `<li>${mkTag(x)} ${x.name}</li>`).join('') + (p.arms.kind === 'weapon' ? `<li>${mkTag(p.arms)} ${p.arms.name}</li>` : '');
    document.getElementById('rv-detail').innerHTML = `<div class="dh"><span class="lbl">${v.rank}º LUGAR · CLASSE ${v.cls}</span><h3>${v.call}</h3><div class="sub">${v.pilot} — carcaça “${v.mech}”</div></div>
      <blockquote>${v.quote}</blockquote>
      <div class="rvgrid">${silhouette(v.build, 'med')}<table class="spec"><tr><td>Estrutura</td><td>${f0(st.structure * (v.hpMul || 1))}</td></tr><tr><td>Peso</td><td>${f1(st.weight)} t</td></tr><tr><td>Pernas</td><td>${LEGTYPE[st.legType]}</td></tr><tr><td>Impulso</td><td>${f0(st.boostSpeed * 3.6)} km/h</td></tr><tr><td>Arena</td><td>${ARENAS[v.arena].name}</td></tr></table></div>
      <div class="lbl">ARMAMENTO DECLARADO</div><ul class="wl">${wl}</ul>
      <div class="cta">${!me.valid ? '<div class="err">Sua montagem está irregular. Corrija na garagem.</div>' : ''}<div class="pay"><span class="lbl">PRÊMIO</span><b class="num">${cr(beaten ? v.prize * 0.25 : v.prize)}</b>${beaten ? '<i>revanche</i>' : ''}</div>
      <button class="btn pri" data-act="fight-rival" ${open && me.valid ? '' : 'disabled'}>${open ? 'DESAFIAR' : 'VENÇA O ANTERIOR PRIMEIRO'}</button></div>`;
  }

  // ───────── contratos ─────────
  genContracts() {
    const s = this.save, rank = playerRank(s), tier = tierForRank(rank), rng = mulberry(s.contractSeed), out = [];
    const types = ['duel', 'duel', 'ambush', 'squad', 'hunt', 'gauntlet'], mk = Object.keys(MODIFIERS), ak = Object.keys(ARENAS);
    const baseSkill = clamp(0.18 + (19 - rank) * 0.036, 0.15, 0.9);
    for (let i = 0; i < 4; i++) {
      const type = i === 0 ? 'duel' : rng.pick(types), arena = rng.pick(ak), mods = {}; const nm = rng.int(0, 2) + (i === 3 ? 1 : 0);
      for (let k = 0; k < nm; k++) mods[rng.pick(mk)] = true;
      const mkE = (t, hp, sc, sk, boss) => { const b = randomBuild(rng, clamp(t, 0, 5), rng.pick(ARCHETYPES)); return { build: b, call: rng.pick(CALLSIGNS), name: rng.pick(MECHNAMES), ai: { ...b._ai, skill: clamp(baseSkill + sk + rng.range(-0.05, 0.08), 0.05, 1) }, hpMul: hp, scale: sc, boss }; };
      let enemies = [], allies = [], mul = 1, sequence = false;
      if (type === 'duel') { enemies = [mkE(tier, 1, 1, 0.05)]; }
      else if (type === 'ambush') { enemies = [mkE(tier - 1, 0.8, 1, -0.05), mkE(tier - 1, 0.8, 1, -0.05)]; mul = 1.5; }
      else if (type === 'squad') { enemies = [mkE(tier - 1, 0.7, 0.92, -0.08), mkE(tier - 1, 0.7, 0.92, -0.08), mkE(tier, 0.8, 1, 0)]; allies = [mkE(tier, 1, 1, 0.1)]; mul = 1.6; }
      else if (type === 'hunt') { enemies = [mkE(tier + 1, 2.3, 1.3, 0.1, true)]; mul = 1.8; }
      else { enemies = [mkE(tier - 1, 0.85, 1, -0.05), mkE(tier, 0.85, 1, 0), mkE(tier, 0.95, 1, 0.05)]; sequence = true; mul = 2.0; }
      let pay = (11000 + tier * 9000) * mul; for (const m in mods) pay *= MODIFIERS[m].pay;
      out.push({ i, type, arena, mods, enemies, allies, sequence, pay: Math.round(pay / 500) * 500, seed: s.contractSeed * 10 + i });
    }
    return out;
  }
  contracts() {
    const s = this.save; if (!this.contractList || this.contractSeed !== s.contractSeed) { this.contractList = this.genContracts(); this.contractSeed = s.contractSeed; }
    this.app.hangar.showMech(s.build); this.app.hangar.view(-0.2, 0);
    const me = computeStats(s.build);
    this.root.innerHTML = this.topbar('CONTRATOS', 'O mural muda a cada combate aceito. Modificadores pagam mais.') + `<div class="cgrid">${this.contractList.map(c => `<article class="panel ctr"><div class="ch"><span class="lbl">${ARENAS[c.arena].name.toUpperCase()}</span><h3>${CONTRACT_TYPES[c.type].name}</h3><p>${CONTRACT_TYPES[c.type].desc}</p></div>
        <ul class="opp">${c.enemies.map(e => `<li>${silhouette(e.build, 'mini')}<span><b>${e.call}</b><i>${e.name}${e.boss ? ' · superpesado' : ''}</i></span></li>`).join('')}${c.allies.map(e => `<li class="ally">${silhouette(e.build, 'mini')}<span><b>${e.call}</b><i>aliado</i></span></li>`).join('')}</ul>
        <div class="mods">${Object.keys(c.mods).map(m => `<div><b>${MODIFIERS[m].name}</b><span>${MODIFIERS[m].desc}</span></div>`).join('') || '<div class="none">Sem modificadores</div>'}</div>
        <div class="cta"><div class="pay"><span class="lbl">PAGAMENTO</span><b class="num">${cr(c.pay)}</b></div><button class="btn pri" data-act="fight-contract" data-i="${c.i}" ${me.valid ? '' : 'disabled'}>ACEITAR</button></div></article>`).join('')}</div>
      <div class="cfoot">${me.valid ? '' : '<span class="err">Sua montagem está irregular. Corrija na garagem.</span>'}<button class="btn" data-act="reroll" ${s.credits >= 2000 ? '' : 'disabled'}>TROCAR O MURAL — 2.000 CR</button></div>`;
  }
  endless() {
    const s = this.save, me = computeStats(s.build); this.app.hangar.showMech(s.build); this.app.hangar.view(-0.14, 0);
    this.root.innerHTML = this.topbar('MODO INFINITO', 'A Fornalha não fecha.') + `<div class="cols right"><section class="panel detail wide"><div class="dh"><span class="lbl">REGRAS</span><h3>Ondas sem fim</h3></div>
      <ul class="rules"><li>Cada onda traz mais adversários, com peças de classe mais alta e pilotos melhores.</li><li>A cada cinco ondas entra um <b>alvo prioritário</b> superpesado, que paga em dobro.</li><li>Entre ondas você recupera 15% da estrutura e escolhe <b>uma de três melhorias de campo</b>. Elas valem até a carcaça cair.</li><li>Munição não volta sozinha: armas de energia, reabastecimento e corpo a corpo seguram as ondas longas.</li><li>Os créditos das ondas limpas são seus mesmo quando você perde.</li></ul>
      <div class="rec"><div><span class="lbl">MELHOR ONDA</span><b class="num">${s.bestWave || '—'}</b></div><div><span class="lbl">MELHOR PONTUAÇÃO</span><b class="num">${s.bestScore ? f0(s.bestScore) : '—'}</b></div></div>
      <div class="cta">${me.valid ? '' : '<div class="err">Sua montagem está irregular. Corrija na garagem.</div>'}<button class="btn pri" data-act="fight-endless" ${me.valid ? '' : 'disabled'}>DESCER À ARENA</button></div></section></div>`;
  }

  // ───────── garagem ─────────
  garage() {
    const s = this.save; this.sel.slot = this.sel.slot || 'head'; this.sel.tab = this.sel.tab || 'parts';
    this.app.hangar.showMech(s.build); this.app.hangar.view(0.09, 0);
    this.root.innerHTML = this.topbar('GARAGEM', 'Monte dentro dos limites de carga e energia. Peças fora da regra impedem a saída.') + `<div class="g3"><section class="panel slots" id="g-slots"></section><section class="panel cat" id="g-cat"></section><section class="panel sheet" id="g-sheet"></section></div>`;
    this.garageSlots(); this.garageCat(); this.garageSheet();
  }
  slotList() { const b = this.save.build, core = PART[b.core], l = SLOTS.map(x => ({ ...x })); for (let i = 0; i < (core ? core.slots : 2); i++) l.push({ k: 'mod' + i, label: 'Módulo ' + (i + 1), cat: 'mod' }); return l; }
  slotPart(k) { const b = this.save.build; return k.startsWith('mod') ? PART[b.mods[+k.slice(3)]] : PART[b[k]]; }
  garageSlots() {
    const b = this.save.build, isTank = PART[b.legs].type === 'tank', wa = PART[b.arms].kind === 'weapon';
    document.getElementById('g-slots').innerHTML = `<div class="tabs"><button class="${this.sel.tab === 'parts' ? 'on' : ''}" data-act="gtab" data-t="parts">PEÇAS</button><button class="${this.sel.tab === 'paint' ? 'on' : ''}" data-act="gtab" data-t="paint">PINTURA</button></div>` +
      this.slotList().map(sl => { const p = this.slotPart(sl.k), blocked = (sl.k === 'booster' && isTank) || ((sl.k === 'handR' || sl.k === 'handL') && wa); return `<button class="sl ${this.sel.slot === sl.k && this.sel.tab === 'parts' ? 'on' : ''} ${blocked ? 'blocked' : ''}" data-act="slot" data-k="${sl.k}" data-hov="x"><span class="lbl">${sl.label}</span><b>${blocked ? (sl.k === 'booster' ? 'embutido nas esteiras' : 'braços-arma') : p ? p.name : '— vazio —'}</b></button>`; }).join('');
  }
  garageCat() {
    const s = this.save, b = s.build, el = document.getElementById('g-cat');
    if (this.sel.tab === 'paint') {
      const pt = b.paint, sw = [['#8a8f86', '#c9541e', '#2b2e30', '#ff9a3c'], ['#d9d5c8', '#3d6e8c', '#26292c', '#8fd3ff'], ['#2a2a2c', '#7a1c16', '#131314', '#ff2e1f'], ['#c9a227', '#2d2d2d', '#191919', '#ff5a1f'], ['#4a4f45', '#8c8a7c', '#1c1d1b', '#ffa53a'], ['#e8e6df', '#c22a1f', '#1e1f22', '#ff3b2f'], ['#1f4a5e', '#e6e1cf', '#16242c', '#59c9ff'], ['#5c3d52', '#cfc8bb', '#1d1a1e', '#ff8ad0'], ['#3a2420', '#d9731f', '#141211', '#ffb02e'], ['#6b6f72', '#1f3f5c', '#1a1c1e', '#ffb347']];
      el.innerHTML = `<div class="ph"><span class="lbl">IDENTIFICAÇÃO</span></div><label class="fld"><span>Nome da carcaça</span><input id="inp-name" data-inp="name" maxlength="20" value="${esc(b.name)}"></label>
        <div class="ph"><span class="lbl">ESQUEMA DE CORES</span></div>${[['a', 'Blindagem principal'], ['b', 'Placas secundárias'], ['c', 'Estrutura'], ['glow', 'Sensores e emissores']].map(([k, l]) => `<label class="fld col"><span>${l}</span><input type="color" id="inp-col-${k}" data-inp="col" data-k="${k}" value="${pt[k]}"><code>${pt[k]}</code></label>`).join('')}
        <label class="fld"><span>Desgaste</span><input type="range" id="inp-wear" data-inp="wear" min="0" max="1" step="0.05" value="${pt.wear ?? 0.5}"></label>
        <div class="ph"><span class="lbl">ESQUEMAS DE FÁBRICA</span></div><div class="sws">${sw.map((c, i) => `<button class="sw" data-act="swatch" data-c="${c.join(',')}" title="Esquema ${i + 1}"><i style="background:${c[0]}"></i><i style="background:${c[1]}"></i><i style="background:${c[2]}"></i><i style="background:${c[3]}"></i></button>`).join('')}</div>`;
      return;
    }
    const sl = this.slotList().find(x => x.k === this.sel.slot) || this.slotList()[0], cur = this.slotPart(sl.k);
    const owned = PARTS.filter(p => p.slot === sl.cat && s.owned[p.id]);
    const optional = !['head', 'core', 'arms', 'legs', 'gen', 'fcs'].includes(sl.k);
    el.innerHTML = `<div class="ph"><span class="lbl">${CATS[sl.cat].toUpperCase()} NO ESTOQUE</span><button class="lnk" data-act="go:shop" data-cat="${sl.cat}">comprar mais ▸</button></div><div class="plist">` +
      (optional ? `<button class="pi ${!cur ? 'eq' : ''}" data-act="equip" data-id="" data-hov="part" data-id2=""><b>— deixar vazio —</b></button>` : '') +
      owned.map(p => { const free = s.owned[p.id] - usedCount(b, p.id), isCur = cur && cur.id === p.id; return `<button class="pi ${isCur ? 'eq' : ''} ${!isCur && free <= 0 ? 'used' : ''}" data-act="equip" data-id="${p.id}" data-hov="part"><span class="r1">${mkTag(p)}<b>${p.name}</b>${isCur ? '<em>INSTALADA</em>' : free <= 0 ? '<em>EM USO</em>' : s.owned[p.id] > 1 ? `<em>×${s.owned[p.id]}</em>` : ''}</span><span class="r2 num">${f1(p.w)} t · ${p.en || 0} EN${p.dmg ? ' · ' + f0(weaponDps(p.wa ? PART[p.wa] : p)) + ' DPS' : ''}${p.arm ? ' · bl. ' + p.arm : ''}</span></button>`; }).join('') + `</div><div class="pdesc" id="g-pdesc"></div>`;
    this.partDesc(cur);
  }
  partDesc(p) { const el = document.getElementById('g-pdesc'); if (!el) return; el.innerHTML = p ? `<div class="pd-h">${mkTag(p)}<b>${p.name}</b><i>${MAKERS[p.mk].name}</i></div><p>${p.desc || ''}</p>${specHtml(p)}` : '<p class="dim">Passe o cursor sobre uma peça para ver a ficha e a diferença na carcaça.</p>'; }
  garageSheet(alt) {
    const s = this.save, cur = computeStats(s.build), nw = alt ? computeStats(alt) : null, el = document.getElementById('g-sheet'); if (!el) return;
    const show = nw && nw.structure !== undefined ? nw : cur;
    const meter = (label, v, max, unit, warnAt = 1) => { const r = max > 0 ? v / max : 0; return `<div class="mt ${r > warnAt ? 'over' : r > 0.9 ? 'near' : ''}"><div class="ml"><span>${label}</span><b class="num">${unit === 't' ? f1(v) : f0(v)} / ${unit === 't' ? f1(max) : f0(max)} ${unit}</b></div><div class="mb"><i style="width:${Math.min(100, r * 100).toFixed(1)}%"></i></div></div>`; };
    let rows = '';
    if (cur.structure === undefined) rows = '<p class="err">Montagem incompleta.</p>';
    else for (const R of STATROWS) { if (!R) { rows += '<tr class="gap"><td colspan="3"></td></tr>'; continue; } const a = R[1](cur), b = nw && nw.structure !== undefined ? R[1](nw) : a, d = b - a, good = d * R[3] > 0; rows += `<tr><td>${R[0]}</td><td class="num">${R[2](b)}</td><td class="num dl ${Math.abs(d) < 1e-6 ? '' : good ? 'up' : 'dn'}">${Math.abs(d) < 1e-6 ? '' : (d > 0 ? '▲' : '▼')}</td></tr>`; }
    const msgs = show.errors.map(e => `<div class="err">${e}</div>`).join('') + show.warns.map(e => `<div class="wrn">${e}</div>`).join('');
    el.innerHTML = `<div class="ph"><span class="lbl">FICHA TÉCNICA${alt ? ' — COM A PEÇA' : ''}</span><span class="stamp ${show.valid ? 'ok' : 'bad'}">${show.valid ? 'APTA' : 'IRREGULAR'}</span></div>
      ${show.structure !== undefined ? meter('Carga nas pernas', show.carried, show.legLoad, 't') + (show.armsWeapon ? '' : meter('Carga nos braços', show.armWeight, show.armLoad, 't')) + meter('Consumo de EN', show.enLoad, show.enOut, 'EN') + `<div class="mt"><div class="ml"><span>Módulos</span><b class="num">${(alt || s.build).mods.length} / ${show.slots}</b></div></div>` : ''}
      <div class="msgs">${msgs}</div><table class="stats">${rows}</table>`;
  }
  candidate(id) {
    const b = JSON.parse(JSON.stringify(this.save.build)), k = this.sel.slot;
    if (k.startsWith('mod')) { const i = +k.slice(3); if (id) b.mods[i] = id; else b.mods.splice(i, 1); b.mods = b.mods.filter(Boolean); }
    else b[k] = id || null;
    this.normalize(b); return b;
  }
  normalize(b) { // ajustes automáticos quando uma peça muda as regras das outras
    const s = this.save, legs = PART[b.legs], arms = PART[b.arms], core = PART[b.core];
    if (legs && legs.type === 'tank') b.booster = null; else if (!b.booster) { const o = PARTS.find(p => p.slot === 'booster' && s.owned[p.id]); if (o) b.booster = o.id; }
    if (arms && arms.kind === 'weapon') { b.handR = null; b.handL = null; }
    if (core && b.mods.length > core.slots) b.mods.length = core.slots;
  }
  equip(id) {
    const s = this.save, k = this.sel.slot, cur = this.slotPart(k);
    if (id && cur && cur.id === id) return;
    if (id && s.owned[id] - usedCount(s.build, id) <= 0) { sfxPlay('error'); this.toast('Essa unidade já está instalada em outro ponto. Compre outra na loja.'); return; }
    if (!id && ['head', 'core', 'arms', 'legs', 'gen', 'fcs'].includes(k)) return;
    s.build = this.candidate(id); persist(s); sfxPlay('equip');
    this.app.hangar.showMech(s.build); this.garageSlots(); this.garageCat(); this.garageSheet();
  }

  // ───────── loja ─────────
  shop(arg) {
    const s = this.save; if (arg && arg.cat) this.sel.cat = arg.cat; this.sel.cat = this.sel.cat || 'hand';
    this.root.innerHTML = this.topbar('LOJA', 'Peças novas liberam conforme você sobe no Circuito. Revenda devolve 60%.') + `<div class="shoptabs">${Object.entries(CATS).map(([k, v]) => `<button class="${k === this.sel.cat ? 'on' : ''}" data-act="scat" data-c="${k}">${v}</button>`).join('')}</div><div class="cols shopc"><section class="panel list" id="s-list"></section><section class="panel detail" id="s-detail"></section></div>`;
    this.shopList();
  }
  shopList() {
    const s = this.save, tier = tierForRank(playerRank(s)), list = PARTS.filter(p => p.slot === this.sel.cat).sort((a, b) => (a.tier - b.tier) || (a.price - b.price));
    if (!list.find(p => p.id === this.sel.item)) this.sel.item = list[0].id;
    document.getElementById('s-list').innerHTML = `<div class="plist">` + list.map(p => { const locked = p.tier > tier; return `<button class="pi ${p.id === this.sel.item ? 'on' : ''} ${locked ? 'locked' : ''}" data-act="sitem" data-id="${p.id}" data-hov="x"><span class="r1">${mkTag(p)}<b>${p.name}</b>${s.owned[p.id] ? `<em>TEM ${s.owned[p.id]}</em>` : ''}</span><span class="r2 num">${locked ? 'LIBERA NA CLASSE ' + TIERCLS[p.tier] : p.price ? cr(p.price) : 'EQUIPAMENTO INICIAL'}</span></button>`; }).join('') + '</div>';
    this.shopDetail();
  }
  shopDetail() {
    const s = this.save, p = PART[this.sel.item], tier = tierForRank(playerRank(s)), locked = p.tier > tier, own = s.owned[p.id] || 0, used = usedCount(s.build, p.id);
    this.app.hangar.showPart(p.id, s.build.paint); this.app.hangar.view(0.02, 30);
    const can = !locked && s.credits >= p.price && p.price > 0, sell = own > used && p.price > 0;
    document.getElementById('s-detail').innerHTML = `<div class="dh"><span class="lbl">${MAKERS[p.mk].name.toUpperCase()} · ${MAKERS[p.mk].sub}</span><h3>${p.name}</h3><div class="sub">Classe ${TIERCLS[p.tier]} · ${CATS[p.slot]}</div></div><p>${p.desc}</p>${specHtml(p)}
      <div class="cta"><div class="pay"><span class="lbl">PREÇO</span><b class="num">${p.price ? cr(p.price) : '—'}</b><i>você tem ${own}${used ? ', ' + used + ' em uso' : ''}</i></div>
      <div class="btns"><button class="btn" data-act="sell" ${sell ? '' : 'disabled'}>VENDER ${p.price ? cr(p.price * 0.6) : ''}</button><button class="btn pri" data-act="buy" ${can ? '' : 'disabled'}>${locked ? 'BLOQUEADA' : !p.price ? 'INICIAL' : s.credits < p.price ? 'SALDO INSUFICIENTE' : 'COMPRAR'}</button></div></div>`;
  }

  // ───────── opções ─────────
  options() {
    const st = this.save.settings; this.app.hangar.showMech(this.save.build); this.app.hangar.view(-0.14, 0);
    const keys = [['W A S D', 'Mover'], ['Mouse', 'Mirar'], ['Espaço', 'Saltar · segurar para subir'], ['Shift', 'Impulso rápido'], ['Ctrl ou C', 'Sobreimpulso (liga/desliga)'], ['Botão esquerdo / direito', 'Arma da mão esquerda / direita'], ['Q / E', 'Unidade dorsal esquerda / direita'], ['R', 'Ombros'], ['F', 'Utilitário (gancho, barreira…)'], ['G', 'Kit de reparo'], ['T ou botão do meio', 'Trava fixa no alvo'], ['Tab ou roda', 'Trocar de alvo'], ['Esc', 'Pausa']];
    this.root.innerHTML = this.topbar('OPÇÕES', '') + `<div class="cols right"><section class="panel detail wide">
      <div class="ph"><span class="lbl">ÁUDIO E MIRA</span></div>
      <label class="fld"><span>Volume geral</span><input type="range" id="opt-vol" data-inp="opt" data-k="vol" min="0" max="1" step="0.05" value="${st.vol}"></label>
      <label class="fld"><span>Trilha</span><input type="range" id="opt-music" data-inp="opt" data-k="music" min="0" max="1" step="0.05" value="${st.music}"></label>
      <label class="fld"><span>Sensibilidade do mouse</span><input type="range" id="opt-sens" data-inp="opt" data-k="sens" min="0.3" max="2.5" step="0.05" value="${st.sens}"></label>
      <label class="fld chk"><span>Inverter eixo vertical</span><input type="checkbox" id="opt-inv" data-inp="opt" data-k="invY" ${st.invY ? 'checked' : ''}></label>
      <div class="ph"><span class="lbl">GRÁFICOS</span></div><div class="seg">${['Leve', 'Médio', 'Alto'].map((l, i) => `<button class="${st.quality === i ? 'on' : ''}" data-act="quality" data-q="${i}">${l}</button>`).join('')}</div>
      <div class="ph"><span class="lbl">CONTROLES</span></div><table class="spec keys">${keys.map(([k, v]) => `<tr><td><kbd>${k}</kbd></td><td>${v}</td></tr>`).join('')}</table>
      <p class="dim">Controle: analógicos movem e miram; LB/RB mãos, LT/RT dorso, A salto, X impulso, Y reparo, L3 sobreimpulso, R3 trava.</p>
      <div class="ph"><span class="lbl">PROGRESSO</span></div><button class="btn" data-act="wipe" id="btn-wipe">APAGAR PROGRESSO</button></section></div>`;
  }

  // ───────── resultados ─────────
  results(r) {
    this.app.hangar.showMech(this.save.build); this.app.hangar.view(-0.14, 0);
    const tm = Math.floor(r.time), t = String(Math.floor(tm / 60)).padStart(2, '0') + ':' + String(tm % 60).padStart(2, '0');
    this.root.innerHTML = `<div class="cols right"><section class="panel detail wide res ${r.win ? 'win' : 'lose'}"><div class="dh"><span class="lbl">${r.title}</span><h3>${r.headline}</h3><div class="sub">${r.subline || ''}</div></div>
      <table class="spec big"><tr><td>Tempo de combate</td><td>${t}</td></tr><tr><td>Dano causado</td><td>${f0(r.dealt)}</td></tr><tr><td>Dano sofrido</td><td>${f0(r.taken)}</td></tr><tr><td>Partes rompidas no adversário</td><td>${r.breaches}</td></tr>${r.wave ? `<tr><td>Ondas limpas</td><td>${r.wave - 1}</td></tr><tr><td>Abates</td><td>${r.kills}</td></tr><tr><td>Pontuação</td><td>${f0(r.score)}${r.record ? ' — recorde' : ''}</td></tr>` : `<tr><td>Estrutura restante</td><td>${r.left}%</td></tr>`}</table>
      <div class="cta"><div class="pay"><span class="lbl">CRÉDITOS</span><b class="num">+${cr(r.reward)}</b>${r.rewardNote ? `<i>${r.rewardNote}</i>` : ''}</div>${r.unlock ? `<div class="unl">Catálogo classe ${r.unlock} liberado na loja.</div>` : ''}
      <div class="btns">${r.retry ? '<button class="btn" data-act="retry">REPETIR</button>' : ''}<button class="btn pri" data-act="menu">VOLTAR AO HANGAR</button></div></div></section></div>`;
  }

  // ───────── sobreposições ─────────
  showPause(match) {
    this.overlay.hidden = false;
    this.overlay.innerHTML = `<div class="ov"><div class="panel pausebox"><div class="dh"><span class="lbl">COMBATE SUSPENSO</span><h3>Pausa</h3></div><div class="btns v"><button class="btn pri" data-act="resume">CONTINUAR</button><button class="btn" data-act="abandon">ABANDONAR${match.cfg.endless ? ' E RECEBER' : ''}</button></div>
      <p class="dim">WASD mover · Espaço saltar/subir · Shift impulso · Ctrl sobreimpulso · botões do mouse mãos · Q/E dorso · R ombros · F utilitário · G reparo · T trava fixa · Tab troca de alvo</p></div></div>`;
  }
  showPerks(choices, match, cb) {
    this.perkCb = cb; this.overlay.hidden = false;
    this.overlay.innerHTML = `<div class="ov"><div class="perkwrap"><div class="dh c"><span class="lbl">ONDA ${match.wave} LIMPA · ESTRUTURA +15%</span><h3>Escolha uma melhoria de campo</h3></div><div class="perks">${choices.map(p => `<button class="panel perk" data-act="perk" data-id="${p.id}" data-hov="x"><span class="lbl">${match.perks[p.id] ? 'NÍVEL ' + (match.perks[p.id] + 1) : 'NOVA'}</span><b>${p.name}</b><p>${p.desc}</p></button>`).join('')}</div>${choices.length ? '' : '<button class="btn pri" data-act="perk" data-id="">SEGUIR</button>'}</div></div>`;
  }
  closeOverlay() { this.overlay.hidden = true; this.overlay.innerHTML = ''; }
  toast(t) { let e = document.getElementById('toast'); e.textContent = t; e.hidden = false; e.classList.remove('in'); void e.offsetWidth; e.classList.add('in'); clearTimeout(this.toastT); this.toastT = setTimeout(() => { e.hidden = true; }, 3200); }

  // ───────── ações ─────────
  hover(kind, d) {
    if (kind === 'part' && this.screen === 'garage') { const id = d.id; const p = id ? PART[id] : null; this.partDesc(p || this.slotPart(this.sel.slot)); const cur = this.slotPart(this.sel.slot); if ((cur ? cur.id : '') !== (id || '')) this.garageSheet(this.candidate(id)); else this.garageSheet(); }
  }
  input(kind, el) {
    const s = this.save, b = s.build;
    if (kind === 'name') { b.name = el.value.toUpperCase().slice(0, 20) || 'SEM NOME'; persist(s); }
    else if (kind === 'col') { b.paint[el.dataset.k] = el.value; el.nextElementSibling.textContent = el.value; clearTimeout(this.paintT); this.paintT = setTimeout(() => { persist(s); this.app.hangar.showMech(b); }, 120); }
    else if (kind === 'wear') { b.paint.wear = +el.value; clearTimeout(this.paintT); this.paintT = setTimeout(() => { persist(s); this.app.hangar.showMech(b); }, 120); }
    else if (kind === 'opt') { const k = el.dataset.k; s.settings[k] = el.type === 'checkbox' ? el.checked : +el.value; setVolume(s.settings.vol, s.settings.music); persist(s); }
  }
  act(a, d, el) {
    const s = this.save, app = this.app;
    if (a.startsWith('go:')) { sfxPlay('ui'); this.show(a.slice(3), d.cat ? { cat: d.cat } : undefined); return; }
    switch (a) {
      case 'enter': initAudio(); setVolume(s.settings.vol, s.settings.music); setMusic(0); sfxPlay('ok'); this.show('menu'); break;
      case 'menu': sfxPlay('ui'); this.show('menu'); break;
      case 'rival': this.sel.rival = +d.rank; sfxPlay('ui'); this.root.querySelectorAll('.rv').forEach(e => e.classList.toggle('on', +e.dataset.rank === this.sel.rival)); this.rivalDetail(); break;
      case 'fight-rival': { const v = RIVALS.find(x => x.rank === this.sel.rival); app.startMatch({ kind: 'league', rival: v, title: `CIRCUITO · ${v.rank}º LUGAR`, arena: v.arena, seed: v.rank * 13 + s.wins + s.losses, mods: {}, enemies: [{ build: v.build, call: v.call, name: v.mech, ai: v.ai, hpMul: v.hpMul || 1 }] }); break; }
      case 'fight-contract': { const c = this.contractList[+d.i]; app.startMatch({ kind: 'contract', contract: c, title: 'CONTRATO · ' + CONTRACT_TYPES[c.type].name.toUpperCase(), arena: c.arena, seed: c.seed, mods: { ...c.mods }, enemies: c.enemies, allies: c.allies, sequence: c.sequence }); break; }
      case 'fight-endless': app.startMatch({ kind: 'endless', endless: true, title: 'MODO INFINITO', arena: Object.keys(ARENAS)[Math.floor(Math.random() * 5)], seed: Math.floor(Math.random() * 1e5), mods: {}, enemies: [] }); break;
      case 'test': app.startMatch({ kind: 'test', title: 'CAMPO DE TESTES', arena: 'coliseu', seed: 3, mods: {}, enemies: [{ build: RIVALS[5].build, call: 'Alvo', name: 'BONECO DE PROVA', ai: { passive: true, skill: 0 }, hpMul: 4 }] }); break;
      case 'retry': if (app.lastCfg) app.startMatch(app.lastCfg); break;
      case 'reroll': if (s.credits >= 2000) { s.credits -= 2000; s.contractSeed++; persist(s); sfxPlay('buy'); this.show('contracts'); } break;
      case 'gtab': this.sel.tab = d.t; sfxPlay('ui'); this.garageSlots(); this.garageCat(); break;
      case 'slot': this.sel.slot = d.k; this.sel.tab = 'parts'; sfxPlay('ui'); this.garageSlots(); this.garageCat(); this.garageSheet(); break;
      case 'equip': this.equip(d.id); break;
      case 'swatch': { const c = d.c.split(','); Object.assign(s.build.paint, { a: c[0], b: c[1], c: c[2], glow: c[3] }); persist(s); sfxPlay('equip'); app.hangar.showMech(s.build); this.garageCat(); break; }
      case 'scat': this.sel.cat = d.c; this.sel.item = null; sfxPlay('ui'); this.root.querySelectorAll('.shoptabs button').forEach(e => e.classList.toggle('on', e.dataset.c === d.c)); this.shopList(); break;
      case 'sitem': this.sel.item = d.id; sfxPlay('ui'); this.root.querySelectorAll('#s-list .pi').forEach(e => e.classList.toggle('on', e.dataset.id === d.id)); this.shopDetail(); break;
      case 'buy': { const p = PART[this.sel.item]; if (s.credits < p.price) { sfxPlay('error'); break; } s.credits -= p.price; s.owned[p.id] = (s.owned[p.id] || 0) + 1; persist(s); sfxPlay('buy'); this.toast(`${p.name} entregue no hangar.`); this.root.querySelector('.wallet .num').textContent = cr(s.credits); this.shopList(); break; }
      case 'sell': { const p = PART[this.sel.item]; if ((s.owned[p.id] || 0) <= usedCount(s.build, p.id)) { sfxPlay('error'); break; } s.owned[p.id]--; if (!s.owned[p.id]) delete s.owned[p.id]; s.credits += Math.round(p.price * 0.6); persist(s); sfxPlay('buy'); this.root.querySelector('.wallet .num').textContent = cr(s.credits); this.shopList(); break; }
      case 'quality': s.settings.quality = +d.q; persist(s); app.engine.setQuality(+d.q); sfxPlay('ui'); this.show('options'); break;
      case 'wipe': if (el.dataset.sure) { app.save = wipe(); persist(app.save); this.sel = {}; this.contractList = null; sfxPlay('ok'); this.show('menu'); } else { el.dataset.sure = '1'; el.textContent = 'CONFIRMAR: APAGAR TUDO'; el.classList.add('danger'); sfxPlay('warn'); } break;
      case 'resume': app.resume(); break;
      case 'abandon': app.abandon(); break;
      case 'perk': { const cb = this.perkCb; this.perkCb = null; this.closeOverlay(); if (cb) cb(d.id || null); break; }
    }
  }
}
