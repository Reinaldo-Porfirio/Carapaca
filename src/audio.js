// Áudio 100% sintetizado (WebAudio): tiros, explosões, propulsores, alertas e trilha generativa.
let ctx = null, master = null, sfx = null, mus = null, noiseBuf = null, comp = null;
let listener = { x: 0, y: 0, z: 0, yaw: 0 };
const last = {};
export const AudioCfg = { vol: 0.8, music: 0.5 };

export function initAudio() {
  if (ctx) { if (ctx.state === 'suspended') ctx.resume(); return; }
  try {
    ctx = new (window.AudioContext || window.webkitAudioContext)();
    comp = ctx.createDynamicsCompressor(); comp.threshold.value = -14; comp.ratio.value = 6; comp.attack.value = 0.003; comp.release.value = 0.18;
    master = ctx.createGain(); master.gain.value = AudioCfg.vol; comp.connect(master); master.connect(ctx.destination);
    sfx = ctx.createGain(); sfx.connect(comp);
    mus = ctx.createGain(); mus.gain.value = AudioCfg.music * 0.5; mus.connect(comp);
    noiseBuf = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate);
    const d = noiseBuf.getChannelData(0); for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    startLoops();
  } catch (e) { ctx = null; }
}
export function setVolume(v, m) { AudioCfg.vol = v; AudioCfg.music = m; if (master) { master.gain.value = v; mus.gain.value = m * 0.5; } }
export function setListener(x, y, z, yaw) { listener.x = x; listener.y = y; listener.z = z; listener.yaw = yaw; }

function spatial(pos) {
  if (!pos) return { g: 1, pan: 0 };
  const dx = pos.x - listener.x, dy = pos.y - listener.y, dz = pos.z - listener.z, d = Math.sqrt(dx * dx + dy * dy + dz * dz);
  const g = Math.min(1, 34 / (34 + d)) * (d > 600 ? 0 : 1);
  const ang = Math.atan2(dx, dz) - listener.yaw;
  return { g, pan: Math.max(-1, Math.min(1, -Math.sin(ang) * Math.min(1, d / 20))) };
}
function out(pos, vol) {
  const s = spatial(pos), g = ctx.createGain(); g.gain.value = vol * s.g;
  if (ctx.createStereoPanner) { const p = ctx.createStereoPanner(); p.pan.value = s.pan; g.connect(p); p.connect(sfx); } else g.connect(sfx);
  return g;
}
function noise(dst, t, dur, f0, f1, q, vol, type = 'bandpass') {
  const src = ctx.createBufferSource(); src.buffer = noiseBuf; src.loop = true;
  const f = ctx.createBiquadFilter(); f.type = type; f.Q.value = q; f.frequency.setValueAtTime(f0, t); f.frequency.exponentialRampToValueAtTime(Math.max(30, f1), t + dur);
  const g = ctx.createGain(); g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.001, t + dur);
  src.connect(f); f.connect(g); g.connect(dst); src.start(t, Math.random()); src.stop(t + dur + 0.02);
}
function tone(dst, t, dur, f0, f1, vol, type = 'sine', attack = 0.002) {
  const o = ctx.createOscillator(); o.type = type; o.frequency.setValueAtTime(f0, t); o.frequency.exponentialRampToValueAtTime(Math.max(20, f1), t + dur);
  const g = ctx.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(vol, t + attack); g.gain.exponentialRampToValueAtTime(0.001, t + dur);
  o.connect(g); g.connect(dst); o.start(t); o.stop(t + dur + 0.02);
}

const S = {
  rifle: (d, t) => { noise(d, t, 0.12, 2400, 500, 0.8, 0.9); tone(d, t, 0.09, 190, 60, 0.7, 'square'); },
  smg: (d, t) => { noise(d, t, 0.07, 3200, 900, 0.9, 0.7); tone(d, t, 0.05, 260, 90, 0.4, 'square'); },
  shotgun: (d, t) => { noise(d, t, 0.26, 1500, 220, 0.6, 1.2); tone(d, t, 0.2, 120, 40, 0.9, 'sawtooth'); },
  pistol: (d, t) => { noise(d, t, 0.18, 1800, 300, 0.8, 1.0); tone(d, t, 0.16, 150, 45, 0.9, 'square'); },
  heavy: (d, t) => { noise(d, t, 0.5, 900, 90, 0.5, 1.4, 'lowpass'); tone(d, t, 0.45, 90, 28, 1.2, 'sawtooth'); noise(d, t, 0.08, 4000, 1200, 1, 0.6); },
  gatling: (d, t) => { noise(d, t, 0.06, 2000, 700, 1.2, 0.8); tone(d, t, 0.05, 140, 70, 0.6, 'sawtooth'); },
  laser: (d, t) => { tone(d, t, 0.22, 1900, 300, 0.5, 'sawtooth'); tone(d, t, 0.22, 2850, 460, 0.25, 'square'); noise(d, t, 0.12, 6000, 2000, 2, 0.25); },
  biglaser: (d, t) => { tone(d, t, 0.9, 900, 70, 0.9, 'sawtooth'); tone(d, t, 0.9, 1360, 110, 0.5, 'square'); noise(d, t, 0.8, 3000, 200, 0.7, 0.8); },
  pulse: (d, t) => { tone(d, t, 0.07, 1400, 700, 0.35, 'square'); noise(d, t, 0.05, 5000, 3000, 3, 0.2); },
  plasma: (d, t) => { tone(d, t, 0.4, 320, 80, 0.7, 'sawtooth'); noise(d, t, 0.4, 800, 200, 1.5, 0.7); tone(d, t, 0.3, 1100, 500, 0.2, 'sine'); },
  arc: (d, t) => { for (let i = 0; i < 5; i++) noise(d, t + i * 0.035, 0.04, 5000 - i * 500, 1500, 3, 0.7); tone(d, t, 0.2, 100, 50, 0.6, 'sawtooth'); },
  rail: (d, t) => { tone(d, t, 0.35, 3200, 120, 0.7, 'sawtooth'); noise(d, t, 0.5, 6000, 300, 0.6, 1.1); tone(d, t, 0.5, 70, 30, 1.0, 'sine'); },
  missile: (d, t) => { noise(d, t, 0.6, 500, 2600, 1.2, 0.55); tone(d, t, 0.3, 140, 300, 0.3, 'sawtooth', 0.05); },
  explosion: (d, t) => { noise(d, t, 0.7, 700, 50, 0.4, 1.5, 'lowpass'); tone(d, t, 0.55, 75, 24, 1.3, 'sine'); noise(d, t, 0.15, 3000, 600, 0.7, 0.6); },
  bigexplosion: (d, t) => { noise(d, t, 1.6, 500, 30, 0.4, 2.0, 'lowpass'); tone(d, t, 1.3, 60, 18, 1.8, 'sine'); noise(d, t, 0.3, 2400, 300, 0.6, 1.0); noise(d, t + 0.25, 1.2, 240, 40, 0.5, 0.9, 'lowpass'); },
  hit: (d, t) => { noise(d, t, 0.06, 3600, 1500, 2.5, 0.5); tone(d, t, 0.07, 900 + Math.random() * 500, 320, 0.22, 'triangle'); },
  hitself: (d, t) => { noise(d, t, 0.12, 900, 200, 1, 0.9); tone(d, t, 0.12, 180, 60, 0.7, 'square'); },
  qb: (d, t) => { noise(d, t, 0.38, 300, 4200, 0.9, 0.9); noise(d, t, 0.3, 2000, 300, 0.6, 0.5, 'lowpass'); },
  jump: (d, t) => { noise(d, t, 0.3, 400, 1600, 0.8, 0.5); },
  step: (d, t) => { noise(d, t, 0.14, 260, 60, 0.6, 0.9, 'lowpass'); tone(d, t, 0.1, 70, 35, 0.6, 'sine'); },
  land: (d, t) => { noise(d, t, 0.3, 400, 50, 0.5, 1.2, 'lowpass'); tone(d, t, 0.22, 60, 26, 1.0, 'sine'); },
  lock: (d, t) => { tone(d, t, 0.05, 1500, 1500, 0.22, 'square'); tone(d, t + 0.07, 0.07, 2000, 2000, 0.22, 'square'); },
  alert: (d, t) => { tone(d, t, 0.1, 880, 880, 0.3, 'square'); tone(d, t + 0.14, 0.1, 880, 880, 0.3, 'square'); },
  warn: (d, t) => { tone(d, t, 0.16, 520, 400, 0.35, 'sawtooth'); },
  ui: (d, t) => { tone(d, t, 0.035, 1250, 900, 0.16, 'square'); },
  hover: (d, t) => { tone(d, t, 0.02, 2100, 2100, 0.05, 'sine'); },
  ok: (d, t) => { tone(d, t, 0.06, 660, 660, 0.2, 'square'); tone(d, t + 0.07, 0.1, 990, 990, 0.2, 'square'); },
  buy: (d, t) => { tone(d, t, 0.05, 1200, 1200, 0.2, 'triangle'); tone(d, t + 0.06, 0.05, 1500, 1500, 0.2, 'triangle'); tone(d, t + 0.12, 0.14, 2000, 2000, 0.2, 'triangle'); noise(d, t, 0.2, 5000, 4000, 4, 0.12); },
  error: (d, t) => { tone(d, t, 0.14, 160, 130, 0.35, 'sawtooth'); tone(d, t + 0.16, 0.16, 130, 110, 0.35, 'sawtooth'); },
  equip: (d, t) => { noise(d, t, 0.09, 1200, 300, 1, 0.5); tone(d, t + 0.05, 0.1, 220, 110, 0.4, 'square'); noise(d, t + 0.12, 0.05, 4000, 2500, 3, 0.25); },
  charge: (d, t) => { tone(d, t, 0.9, 220, 1700, 0.22, 'sawtooth', 0.4); },
  swing: (d, t) => { noise(d, t, 0.22, 600, 5000, 1.4, 0.8); tone(d, t, 0.2, 900, 240, 0.3, 'sawtooth'); },
  meleehit: (d, t) => { noise(d, t, 0.3, 2400, 150, 0.6, 1.5); tone(d, t, 0.3, 140, 34, 1.2, 'square'); tone(d, t, 0.2, 1600, 400, 0.4, 'triangle'); },
  stagger: (d, t) => { tone(d, t, 0.5, 1300, 120, 0.5, 'sawtooth'); noise(d, t, 0.4, 3000, 200, 1, 0.9); tone(d, t, 0.4, 80, 40, 0.9, 'sine'); },
  break: (d, t) => { noise(d, t, 0.4, 2600, 120, 0.7, 1.3); tone(d, t, 0.3, 480, 70, 0.6, 'square'); tone(d, t + 0.05, 0.4, 1900, 500, 0.3, 'triangle'); },
  repair: (d, t) => { tone(d, t, 0.5, 300, 900, 0.3, 'sine', 0.1); noise(d, t, 0.5, 2000, 6000, 3, 0.2); },
  hook: (d, t) => { noise(d, t, 0.2, 3000, 800, 2, 0.6); tone(d, t, 0.25, 600, 1500, 0.25, 'sawtooth'); },
  clank: (d, t) => { tone(d, t, 0.16, 1100, 500, 0.4, 'triangle'); noise(d, t, 0.1, 2500, 800, 2, 0.6); },
  shield: (d, t) => { tone(d, t, 0.3, 500, 1100, 0.3, 'sine', 0.05); tone(d, t, 0.3, 755, 1650, 0.15, 'sine', 0.05); },
  shieldhit: (d, t) => { tone(d, t, 0.14, 2200, 900, 0.3, 'sine'); noise(d, t, 0.08, 6000, 3000, 3, 0.3); },
  emp: (d, t) => { tone(d, t, 0.6, 2400, 60, 0.6, 'sawtooth'); noise(d, t, 0.6, 5000, 100, 0.8, 1.0); },
  flare: (d, t) => { noise(d, t, 0.3, 2500, 5000, 1.5, 0.5); },
  count: (d, t) => { tone(d, t, 0.12, 440, 440, 0.3, 'square'); },
  go: (d, t) => { tone(d, t, 0.5, 880, 880, 0.35, 'square'); tone(d, t, 0.5, 1320, 1320, 0.2, 'square'); },
  win: (d, t) => { [392, 494, 587, 784].forEach((f, i) => tone(d, t + i * 0.13, 0.5, f, f, 0.25, 'triangle', 0.01)); },
  lose: (d, t) => { [392, 349, 294, 196].forEach((f, i) => tone(d, t + i * 0.2, 0.7, f, f * 0.97, 0.25, 'sawtooth', 0.02)); },
  flame: (d, t) => { noise(d, t, 0.14, 700, 1400, 0.5, 0.5); },
  saw: (d, t) => { tone(d, t, 0.12, 140 + Math.random() * 30, 120, 0.4, 'sawtooth'); noise(d, t, 0.1, 3500, 2500, 2, 0.35); },
};
const RATE = { hit: 0.04, flame: 0.09, saw: 0.08, pulse: 0.05, smg: 0.045, gatling: 0.04, step: 0.12, explosion: 0.05, hover: 0.03, rifle: 0.05, missile: 0.06, laser: 0.04, hitself: 0.06, shieldhit: 0.06 };

export function sfxPlay(name, pos = null, vol = 1) {
  if (!ctx || !S[name]) return;
  const now = ctx.currentTime; if (now - (last[name] || -1) < (RATE[name] || 0.02)) return; last[name] = now;
  try { S[name](out(pos, vol * 0.5), now); } catch (e) { /* ignora */ }
}

// laços contínuos: propulsor do jogador + trilha
let boostG = null, boostF = null, musicOn = false, musicIntensity = 0, musTimer = null, step = 0, nextT = 0;
function startLoops() {
  const src = ctx.createBufferSource(); src.buffer = noiseBuf; src.loop = true;
  boostF = ctx.createBiquadFilter(); boostF.type = 'bandpass'; boostF.frequency.value = 300; boostF.Q.value = 0.7;
  boostG = ctx.createGain(); boostG.gain.value = 0; src.connect(boostF); boostF.connect(boostG); boostG.connect(sfx); src.start();
  // base contínua da trilha
  const d1 = ctx.createOscillator(), d2 = ctx.createOscillator(), dg = ctx.createGain(), df = ctx.createBiquadFilter();
  d1.type = 'sawtooth'; d2.type = 'sawtooth'; d1.frequency.value = 36.71; d2.frequency.value = 36.95; df.type = 'lowpass'; df.frequency.value = 180; dg.gain.value = 0.5;
  d1.connect(df); d2.connect(df); df.connect(dg); dg.connect(mus); d1.start(); d2.start();
  nextT = ctx.currentTime + 0.1;
  musTimer = setInterval(scheduler, 60);
}
export function setBoostLoop(level) { if (!ctx) return; const t = ctx.currentTime; boostG.gain.setTargetAtTime(Math.min(0.5, level * 0.32), t, 0.06); boostF.frequency.setTargetAtTime(240 + level * 900, t, 0.08); }
export function setMusic(intensity) { musicIntensity = intensity; musicOn = true; }

const SCALE = [73.42, 87.31, 98.0, 110.0, 130.81, 146.83]; // ré menor pentatônica
const BASS = [0, 0, 3, 0, 0, 5, 3, 1, 0, 0, 3, 0, 4, 3, 1, 2];
function scheduler() {
  if (!ctx || !musicOn) return;
  const spb = 60 / 104 / 4;
  while (nextT < ctx.currentTime + 0.15) {
    const s = step % 64, b = step % 16, t = nextT, I = musicIntensity;
    if (I > 0.5) {
      if (b % 4 === 0) { tone(mus, t, 0.22, 110, 34, 0.9, 'sine'); noise(mus, t, 0.03, 2500, 800, 1, 0.2); }
      if (b % 8 === 4) noise(mus, t, 0.14, 1900, 900, 1.2, 0.4);
      if (b % 2 === 1) noise(mus, t, 0.03, 8000, 6000, 3, 0.1 + (b % 4 === 3 ? 0.08 : 0));
      const n = SCALE[BASS[(s >> 1) % 16]];
      if (b % 2 === 0 || b === 7 || b === 15) { const o = ctx.createOscillator(), g = ctx.createGain(), f = ctx.createBiquadFilter(); o.type = 'sawtooth'; o.frequency.value = n; f.type = 'lowpass'; f.frequency.setValueAtTime(900, t); f.frequency.exponentialRampToValueAtTime(140, t + 0.16); f.Q.value = 6; g.gain.setValueAtTime(0.42, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.18); o.connect(f); f.connect(g); g.connect(mus); o.start(t); o.stop(t + 0.2); }
      if (I > 0.8 && s % 32 === 12) tone(mus, t, 0.5, 1174, 1150, 0.06, 'triangle', 0.02);
    }
    if (s % 32 === 0) { // acorde longo, em qualquer intensidade
      for (const f of [146.83, 220, s === 32 ? 261.63 : 293.66]) { const o = ctx.createOscillator(), g = ctx.createGain(); o.type = 'triangle'; o.frequency.value = f; g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(0.07 + I * 0.03, t + 1.2); g.gain.linearRampToValueAtTime(0.0001, t + spb * 32); o.connect(g); g.connect(mus); o.start(t); o.stop(t + spb * 32 + 0.1); }
    }
    if (I <= 0.5 && s % 16 === 8 && Math.random() < 0.6) tone(mus, t, 1.4, SCALE[Math.floor(Math.random() * 6)] * 4, SCALE[2] * 4, 0.035, 'sine', 0.3);
    nextT += spb; step++;
  }
}
