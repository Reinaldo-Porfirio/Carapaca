// Inicialização, laço principal e fluxo entre hangar e combate.
import { Engine } from './fx.js';
import { Hangar } from './hangar.js';
import { HUD } from './hud.js';
import { UI } from './ui.js';
import { Match } from './game.js';
import { Input } from './input.js';
import { loadSave, persist, playerRank } from './save.js';
import { MODIFIERS, tierForRank } from './data.js';
import { computeStats } from './stats.js';
import { setMusic, sfxPlay, setBoostLoop } from './audio.js';

const TIERCLS = ['E', 'D', 'C', 'B', 'A', 'S'];
function boot() {
  const canvas = document.getElementById('gl');
  let engine;
  try { engine = new Engine(canvas); } catch (e) { document.getElementById('ui').innerHTML = '<div class="titlebox"><h1>CARCAÇA</h1><p>Este navegador não liberou WebGL. Ative a aceleração gráfica ou abra em outro navegador.</p></div>'; return; }
  const app = window.__app = { engine, save: loadSave(), match: null, lastCfg: null, pendingEnd: null };
  engine.setQuality(app.save.settings.quality);
  Input.init(canvas);
  app.hangar = new Hangar(engine); app.hud = new HUD(document.getElementById('hud')); app.ui = new UI(app, document.getElementById('ui'));
  engine.use(app.hangar.scene, app.hangar.cam);

  app.startMatch = (cfg) => {
    if (!computeStats(app.save.build).valid) { sfxPlay('error'); app.ui.toast('Montagem irregular: corrija na garagem antes de sair.'); return; }
    app.lastCfg = cfg; app.ui.hide(); sfxPlay('ok');
    const full = { ...cfg, playerBuild: JSON.parse(JSON.stringify(cfg.playerBuild || app.save.build)), modNames: Object.fromEntries(Object.entries(MODIFIERS).map(([k, v]) => [k, v.name])), onEnd: (res) => { app.pendingEnd = () => app.finishMatch(cfg, res); } };
    Input.wantLock = true; Input.lock();
    app.match = new Match(app, full);
  };
  app.pause = () => { const m = app.match; if (!m || m.paused || m.state === 'perk' || m.state === 'over' || m.state === 'done') return; m.paused = true; setBoostLoop(0); Input.unlock(); app.ui.showPause(m); };
  app.resume = () => { const m = app.match; if (!m) return; app.ui.closeOverlay(); m.paused = false; Input.wantLock = true; Input.lock(); sfxPlay('ui'); };
  app.abandon = () => { const m = app.match; if (!m) return; app.ui.closeOverlay(); m.paused = false; m.win = false; m.state = 'done'; m.end(); };
  Input.onUnlock = () => app.pause();
  app.finishMatch = (cfg, res) => {
    const s = app.save, before = tierForRank(playerRank(s)); let reward = 0, note = '', headline, subline = '', record = false, win = res.win;
    if (cfg.kind === 'league') {
      const v = cfg.rival;
      if (res.win) { const first = !s.beaten.includes(v.rank); reward = first ? v.prize : v.prize * 0.25; note = first ? 'prêmio da posição' : 'revanche paga 25%'; if (first) s.beaten.push(v.rank); headline = first ? (v.rank === 1 ? 'Campeã do Circuito' : `${v.rank}º lugar conquistado`) : 'Revanche vencida'; subline = `${v.call} está fora de combate.`; s.wins++; }
      else { headline = 'Carcaça perdida'; subline = `${v.call} mantém a posição. A seguradora cobre o conserto.`; s.losses++; }
    } else if (cfg.kind === 'contract') {
      const c = cfg.contract; if (res.win) { reward = c.pay; headline = 'Contrato cumprido'; s.wins++; } else { reward = c.pay * 0.1; note = 'taxa de comparecimento'; headline = 'Contrato perdido'; s.losses++; }
      s.contractSeed++;
    } else if (cfg.kind === 'endless') {
      reward = res.earned; win = res.wave > 1; headline = res.wave > 1 ? `Caiu na onda ${res.wave}` : 'Caiu na primeira onda'; subline = 'Os créditos das ondas limpas são seus.';
      if (res.wave - 1 > s.bestWave) { s.bestWave = res.wave - 1; } if (res.score > s.bestScore) { s.bestScore = res.score; record = true; }
    } else { headline = res.win ? 'Alvo destruído' : 'Teste encerrado'; subline = 'Sem recompensa no campo de testes.'; }
    s.credits += Math.round(reward); persist(s);
    const after = tierForRank(playerRank(s));
    app.match.dispose(); app.match = null; Input.unlock(); app.ui.closeOverlay();
    engine.use(app.hangar.scene, app.hangar.cam); engine.renderer.toneMappingExposure = 1; setMusic(0);
    app.ui.show('results', { ...res, win, title: cfg.title, headline, subline, reward: Math.round(reward), rewardNote: note, record, unlock: after > before ? TIERCLS[after] : null, retry: cfg.kind === 'endless' || cfg.kind === 'test' || (cfg.kind === 'league' && !res.win) });
  };
  addEventListener('keydown', (e) => { if ((e.code === 'Escape' || e.code === 'KeyP') && app.match) { if (app.match.paused) app.resume(); else app.pause(); } });
  addEventListener('resize', () => { if (app.match) { app.match.world.fx.setViewport(innerHeight * engine.renderer.getPixelRatio(), 62); app.hud.resize(app.match); } });
  document.addEventListener('visibilitychange', () => { if (document.hidden) app.pause(); });

  window.__simList = () => window.__mkSim ? window.__mkSim(app) : [];
  app.ui.show('title');
  let last = performance.now();
  function frame(t) {
    const dt = Math.min(0.05, Math.max(0.001, (t - last) / 1000)); last = t;
    try {
      if (app.match) { app.match.update(dt); if (app.pendingEnd) { const f = app.pendingEnd; app.pendingEnd = null; f(); } }
      if (!app.match) app.hangar.update(dt);
      engine.render();
    } catch (err) { if (!app.errShown) { app.errShown = true; console.error(err); } }
    Input.frame();
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}
if (window.claude && window.claude.hot && window.claude.hot.ready) window.claude.hot.ready(boot); else boot();
