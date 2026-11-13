// (somente desenvolvimento) lista de combates simulados com piloto automático
import { RIVALS, ARENAS } from './data.js';
window.__mkSim = (app) => {
  const L = [];
  for (const rk of (window.__simAll ? [18,17,16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1] : [18, 10, 6, 1])) { const v = RIVALS.find(x => x.rank === rk); L.push({ maxT: 200, cfg: { kind: 'test', title: 'mirror ' + v.call, arena: v.arena, seed: rk, mods: {}, playerBuild: v.build, autopilot: { ...v.ai, skill: 0.6 }, enemies: [{ build: v.build, call: v.call, name: v.mech, ai: v.ai, hpMul: v.hpMul || 1 }] } }); }
  const st = app.save.build;
  for (const rk of [18, 17, 16, 15]) { const v = RIVALS.find(x => x.rank === rk); L.push({ maxT: 200, cfg: { kind: 'test', title: 'starter vs ' + v.call, arena: v.arena, seed: rk, mods: {}, playerBuild: st, autopilot: { skill: 0.6, agg: 0.6, air: 0.3 }, enemies: [{ build: v.build, call: v.call, name: v.mech, ai: v.ai, hpMul: v.hpMul || 1 }] } }); }
  app.save.contractSeed = 1234; const cs = app.ui.genContracts();
  for (const c of cs) L.push({ maxT: 240, cfg: { kind: 'test', title: 'contract ' + c.type + ' ' + Object.keys(c.mods).join('+'), arena: c.arena, seed: c.seed, mods: { ...c.mods }, enemies: c.enemies, allies: c.allies, sequence: c.sequence, playerBuild: RIVALS[8].build, autopilot: { skill: 0.7, agg: 0.6, air: 0.3 } } });
  for (const a of ['doca', 'salar', 'boreal']) L.push({ maxT: 420, cfg: { kind: 'test', endless: true, title: 'endless ' + a, arena: a, seed: 77, mods: {}, enemies: [], playerBuild: RIVALS[9].build, autopilot: { skill: 0.8, agg: 0.6, air: 0.3 } } });
  return L;
};
