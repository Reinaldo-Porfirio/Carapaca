// Progresso salvo no navegador (localStorage), com alternativa em memória.
import { STARTER_BUILD, STARTER_OWNED, PART } from './data.js';
const KEY = 'carcaca.save.v1';
const fresh = () => ({ credits: 30000, owned: Object.fromEntries(STARTER_OWNED.map(id => [id, 1])), build: JSON.parse(JSON.stringify(STARTER_BUILD)), beaten: [], bestWave: 0, bestScore: 0, contractSeed: Math.floor(Math.random() * 1e6), wins: 0, losses: 0,
  settings: { vol: 0.8, music: 0.5, sens: 1, invY: false, quality: 2 } });
export function loadSave() {
  const s = fresh();
  try { const raw = localStorage.getItem(KEY); if (raw) { const o = JSON.parse(raw); Object.assign(s, o); s.settings = { ...fresh().settings, ...(o.settings || {}) };
    for (const k of ['head', 'core', 'arms', 'legs', 'gen', 'booster', 'fcs', 'handR', 'handL', 'backR', 'backL', 'shoulder', 'util']) if (s.build[k] && !PART[s.build[k]]) s.build[k] = STARTER_BUILD[k];
    s.build.mods = (s.build.mods || []).filter(id => PART[id]); } } catch (e) { /* sem armazenamento: joga sem salvar */ }
  return s;
}
export function persist(s) { try { localStorage.setItem(KEY, JSON.stringify(s)); } catch (e) { /* ignora */ } }
export function wipe() { try { localStorage.removeItem(KEY); } catch (e) { } return fresh(); }
export const playerRank = (s) => s.beaten.length ? Math.min(...s.beaten) : 19;
export function usedCount(build, id) { let n = 0; for (const k of ['head', 'core', 'arms', 'legs', 'gen', 'booster', 'fcs', 'handR', 'handL', 'backR', 'backL', 'shoulder', 'util']) if (build[k] === id) n++; for (const m of build.mods || []) if (m === id) n++; return n; }
