// Teclado, mouse (com trava de ponteiro opcional) e controle.
export const Input = {
  keys: {}, pressed: {}, btn: [false, false, false], btnP: [false, false, false], mdx: 0, mdy: 0, wheel: 0, locked: false, cx: 0.5, cy: 0.5, wantLock: false, pad: null, padPrev: {},
  init(canvas) {
    this.canvas = canvas;
    addEventListener('keydown', e => { if (e.target && /INPUT|TEXTAREA|SELECT/.test(e.target.tagName)) return; if (!this.keys[e.code]) this.pressed[e.code] = true; this.keys[e.code] = true; if (this.wantLock && ['Tab', 'Space', 'KeyQ', 'KeyE', 'KeyF', 'KeyR', 'KeyG', 'ControlLeft', 'AltLeft'].includes(e.code)) e.preventDefault(); });
    addEventListener('keyup', e => { this.keys[e.code] = false; });
    addEventListener('blur', () => { this.keys = {}; this.btn = [false, false, false]; });
    addEventListener('mousemove', e => { if (this.locked || this.wantLock) { this.mdx += e.movementX || 0; this.mdy += e.movementY || 0; } this.cx = e.clientX / innerWidth; this.cy = e.clientY / innerHeight; });
    canvas.addEventListener('mousedown', e => { if (e.button < 3) { this.btn[e.button] = true; this.btnP[e.button] = true; } if (this.wantLock && !this.locked) this.lock(); e.preventDefault(); });
    addEventListener('mouseup', e => { if (e.button < 3) this.btn[e.button] = false; });
    canvas.addEventListener('contextmenu', e => e.preventDefault());
    addEventListener('wheel', e => { this.wheel += Math.sign(e.deltaY); }, { passive: true });
    document.addEventListener('pointerlockchange', () => { this.locked = document.pointerLockElement === canvas; if (!this.locked && this.wantLock && this.onUnlock) this.onUnlock(); });
    document.addEventListener('pointerlockerror', () => { this.locked = false; });
  },
  lock() { try { const p = this.canvas.requestPointerLock && this.canvas.requestPointerLock(); if (p && p.catch) p.catch(() => { }); } catch (e) { /* sem trava: segue com mira por borda */ } },
  unlock() { this.wantLock = false; try { if (document.pointerLockElement) document.exitPointerLock(); } catch (e) { } },
  frame() { this.pressed = {}; this.btnP = [false, false, false]; this.mdx = 0; this.mdy = 0; this.wheel = 0; },
  // controle: retorna eixos e botões com detecção de borda
  gamepad() {
    let g = null; try { const l = navigator.getGamepads ? navigator.getGamepads() : []; for (const p of l) if (p && p.connected && p.axes.length >= 4) { g = p; break; } } catch (e) { }
    if (!g) return null;
    const dz = v => Math.abs(v) < 0.16 ? 0 : v, b = i => !!(g.buttons[i] && (g.buttons[i].pressed || g.buttons[i].value > 0.4));
    const out = { lx: dz(g.axes[0]), ly: dz(g.axes[1]), rx: dz(g.axes[2]), ry: dz(g.axes[3]), b: {}, p: {} };
    for (let i = 0; i < 16; i++) { out.b[i] = b(i); out.p[i] = out.b[i] && !this.padPrev[i]; this.padPrev[i] = out.b[i]; }
    return out;
  },
};
