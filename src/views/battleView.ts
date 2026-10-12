// Battle screen: 3D scene + camera, touch input, HUD, seed selection, pause and results.
import * as THREE from 'three';
import type { App, View } from '../app';
import { audio } from '../game/audio';
import { Battle, type BattleEvent, type Pickup } from '../game/battle';
import { COLS, LANES, PLANTS, getLevel, nextLevelId, type LevelDef, type PlantId, type ZombieId } from '../game/config';
import { BOARD_RIGHT, buildEnvironment, colX, laneZ, type Environment } from '../game/environment';
import { rules } from '../game/save';
import { clear, h } from '../ui/dom';
import { pauseMenu, resultsScreen, seedSelectScreen } from '../ui/screens';
import { plantThumb } from '../ui/thumbs';

type Mode = 'none' | 'seed' | 'shovel' | 'plantfood';

export class BattleView implements View {
  readonly scene = new THREE.Scene();
  readonly camera = new THREE.PerspectiveCamera(36, 16 / 9, 0.1, 100);
  readonly level: LevelDef;
  battle!: Battle;
  private env: Environment;
  private stage: 'select' | 'intro' | 'play' | 'ended' = 'select';
  private paused = false;
  speed = 1;
  private mode: Mode = 'none';
  private selected: PlantId | null = null;
  private dragging = false;
  private dragMoved = false;
  private pointerDown = false;
  private highlight: THREE.Mesh;
  private raycaster = new THREE.Raycaster();
  private plane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
  private shake = 0;
  private focusX = 4.2;
  private focusGoal = 4.2;
  private aspect = 16 / 9;
  private hud: HTMLElement | null = null;
  private overlay: HTMLElement | null = null;
  private packetEls = new Map<PlantId, { el: HTMLElement; cd: HTMLElement }>();
  private sunEl!: HTMLElement;
  private pfEl!: HTMLElement;
  private pfCountEl!: HTMLElement;
  private shovelEl!: HTMLElement;
  private speedEl!: HTMLElement;
  private progressFill!: HTMLElement;
  private progressHead!: HTMLElement;
  private bannerEl!: HTMLElement;
  private lastSun = -1;
  private lastPf = -1;
  private loadout: PlantId[] = [];
  private listeners: [EventTarget, string, EventListener][] = [];
  private disposed = false;

  constructor(
    private app: App,
    private levelId: string,
  ) {
    this.level = getLevel(levelId)!;
    this.scene.background = new THREE.Color('#8fd3ff');
    this.scene.fog = new THREE.Fog('#8fd3ff', 20, 42);
    this.env = buildEnvironment(app.save.settings.highQuality);
    this.scene.add(this.env.group);
    this.highlight = new THREE.Mesh(
      new THREE.BoxGeometry(0.96, 0.02, 0.96),
      new THREE.MeshBasicMaterial({ color: '#ffffff', transparent: true, opacity: 0.35, depthWrite: false }),
    );
    this.highlight.visible = false;
    this.scene.add(this.highlight);
    this.newBattle(app.save.lastLoadout);
    this.showSeedSelect();

    const canvas = app.renderer.domElement;
    this.listen(canvas, 'pointerdown', (e) => this.onCanvasDown(e as PointerEvent));
    this.listen(window, 'pointermove', (e) => this.onMove(e as PointerEvent));
    this.listen(window, 'pointerup', (e) => this.onUp(e as PointerEvent));
    this.listen(window, 'pointercancel', () => this.cancelDrag());
  }

  private listen(t: EventTarget, type: string, fn: EventListener) {
    t.addEventListener(type, fn);
    this.listeners.push([t, type, fn]);
  }

  private newBattle(loadout: PlantId[]) {
    if (this.battle) this.battle.dispose();
    const r = rules(this.app.save);
    this.loadout = loadout.slice(0, r.seedSlots);
    this.battle = new Battle(this.scene, this.level, this.loadout, r, { autoCollectSun: this.app.save.settings.autoCollectSun });
    this.spawnPreview();
  }

  /** Preview lineup of this level's zombies standing on the street. */
  private spawnPreview() {
    const kinds = [...new Set(this.level.waves.flatMap((w) => w.zombies))] as ZombieId[];
    kinds.forEach((id, i) => {
      this.battle.spawnZombie(id, i % LANES, BOARD_RIGHT + 1.4 + (i % 2) * 0.9 + Math.floor(i / LANES) * 0.8);
    });
  }

  // ------------------------------------------------------------ flow

  private showSeedSelect() {
    this.stage = 'select';
    this.focusGoal = 4.2;
    clear(this.app.ui);
    this.overlay = seedSelectScreen(this.app, this.level, (loadout) => this.beginBattle(loadout), () => this.quit());
    this.app.ui.append(this.overlay);
  }

  private beginBattle(loadout: PlantId[]) {
    this.app.save.lastLoadout = loadout;
    this.app.persist();
    this.loadout = loadout;
    this.battle.rules = rules(this.app.save);
    // Rebuild battle with the chosen loadout (cooldowns depend on it), keep the lineup for the camera pan.
    this.battle.dispose();
    this.battle = new Battle(this.scene, this.level, loadout, rules(this.app.save), { autoCollectSun: this.app.save.settings.autoCollectSun });
    this.spawnPreview();
    clear(this.app.ui);
    this.overlay = null;
    this.buildHud();
    this.stage = 'intro';
    this.focusGoal = 0;
    const seq: [string, number][] = [
      ['Ready…', 700],
      ['Set…', 1400],
      ['PLANT!', 2100],
    ];
    for (const [text, t] of seq) setTimeout(() => !this.disposed && this.banner(text, 'ready', 650), t);
    setTimeout(() => {
      if (this.stage !== 'intro' || this.disposed) return;
      this.stage = 'play';
      this.battle.clearZombies();
      this.battle.start();
    }, 2700);
  }

  pause() {
    if (this.stage !== 'play' || this.paused) return;
    this.paused = true;
    audio.play('click');
    this.overlay = pauseMenu(this.app, this, {
      resume: () => this.resume(),
      restart: () => this.app.startLevel(this.levelId),
      quit: () => this.quit(),
    });
    this.app.ui.append(this.overlay);
  }

  resume() {
    this.paused = false;
    this.overlay?.remove();
    this.overlay = null;
    this.battle.rules = rules(this.app.save);
    this.refreshPackets();
  }

  /** Re-apply Ultimate settings changed from the pause menu. */
  applyRules() {
    this.battle.rules = rules(this.app.save);
    this.battle.autoCollect = this.app.save.settings.autoCollectSun;
  }

  private quit() {
    this.app.showScreen('map');
  }

  private onEnd(result: 'won' | 'lost') {
    this.stage = 'ended';
    this.setMode('none');
    const save = this.app.save;
    let gems = 0;
    let coins = 0;
    if (result === 'won') {
      const first = !save.completed[this.levelId];
      save.completed[this.levelId] = (save.completed[this.levelId] ?? 0) + 1;
      coins = this.level.rewardCoins + this.battle.stats.coins;
      gems = first ? 5 : 0;
      save.coins += coins;
      save.gems += gems;
      save.seedPackets += 3;
      this.app.persist();
    }
    setTimeout(() => {
      if (this.disposed) return;
      const next = nextLevelId(this.levelId);
      this.overlay = resultsScreen(this.app, {
        won: result === 'won',
        level: this.level,
        stats: this.battle.stats,
        coins,
        gems,
        next: next ? () => this.app.startLevel(next) : undefined,
        retry: () => this.app.startLevel(this.levelId),
        map: () => this.quit(),
      });
      this.app.ui.append(this.overlay);
    }, result === 'won' ? 900 : 1600);
  }

  // ------------------------------------------------------------ HUD

  private buildHud() {
    const ult = this.battle.rules.ultimate;
    this.sunEl = h('span', { class: 'sun-val', text: '0' });
    const sunBox = h('div', { class: 'sun-box' }, h('div', { class: 'sun-icon' }), this.sunEl);
    const packets = h('div', { class: 'packets' });
    for (const id of this.loadout) {
      const def = PLANTS[id];
      const cd = h('div', { class: 'cd' });
      const el = h(
        'div',
        { class: 'packet', attrs: { 'data-id': id } },
        h('img', { attrs: { src: plantThumb(id), alt: def.name, draggable: 'false' } }),
        h('div', { class: 'cost', text: String(def.cost) }),
        cd,
      );
      el.addEventListener('pointerdown', (e) => this.onPacketDown(e, id));
      packets.append(el);
      this.packetEls.set(id, { el, cd });
    }
    const seedbar = h('div', { class: 'seedbar' }, sunBox, packets);

    const pauseBtn = h('button', { class: 'hud-btn', text: '⏸', attrs: { 'aria-label': 'Pause' }, onClick: () => this.pause() });
    this.speedEl = h('button', {
      class: 'hud-btn speed',
      text: '1×',
      onClick: () => {
        this.speed = this.speed === 1 ? 2 : 1;
        this.speedEl.textContent = this.speed + '×';
        this.speedEl.classList.toggle('on', this.speed > 1);
        audio.play('click');
      },
    });
    const topRight = h('div', { class: 'hud-tr' }, ult ? h('div', { class: 'ult-chip', text: '👑 ULTIMATE' }) : null, this.speedEl, pauseBtn);

    this.pfCountEl = h('span', { class: 'pf-count' });
    this.pfEl = h('button', { class: 'tool-btn pf', attrs: { 'aria-label': 'Plant Food' } }, h('span', { class: 'pf-leaf', text: '🌿' }), this.pfCountEl);
    this.pfEl.addEventListener('click', () => this.setMode(this.mode === 'plantfood' ? 'none' : 'plantfood'));
    this.shovelEl = h('button', { class: 'tool-btn shovel', text: '⛏️', attrs: { 'aria-label': 'Shovel' } });
    this.shovelEl.addEventListener('click', () => this.setMode(this.mode === 'shovel' ? 'none' : 'shovel'));
    const tools = h('div', { class: 'hud-br' }, this.pfEl, this.shovelEl);

    this.progressFill = h('div', { class: 'prog-fill' });
    this.progressHead = h('div', { class: 'prog-head', text: '🧟' });
    const bar = h('div', { class: 'prog-bar' }, this.progressFill);
    this.level.waves.forEach((w, i) => {
      if (w.flag) bar.append(h('div', { class: 'prog-flag', text: '🚩', style: { left: `${((i + 1) / this.level.waves.length) * 100}%` } }));
    });
    bar.append(this.progressHead);
    const progress = h('div', { class: 'progress' }, h('div', { class: 'prog-name', text: `Level ${this.level.id}` }), bar);

    this.bannerEl = h('div', { class: 'banner' });
    this.hud = h('div', { class: 'hud' }, seedbar, topRight, tools, progress, this.bannerEl);
    this.app.ui.append(this.hud);
    this.lastSun = -1;
    this.lastPf = -1;
    this.refreshPackets();
  }

  private refreshPackets() {
    for (const [id, { el, cd }] of this.packetEls) {
      const max = this.battle.cooldownMax.get(id) ?? 1;
      const cur = this.battle.cooldown.get(id) ?? 0;
      const ratio = max > 0 ? cur / max : 0;
      cd.style.height = `${ratio * 100}%`;
      const affordable = this.battle.rules.unlimitedSun || this.battle.sun >= PLANTS[id].cost;
      el.classList.toggle('disabled', !affordable || ratio > 0);
      el.classList.toggle('selected', this.selected === id);
    }
  }

  private updateHud() {
    if (!this.hud) return;
    const b = this.battle;
    const sun = b.rules.unlimitedSun ? Infinity : b.sun;
    if (sun !== this.lastSun) {
      this.lastSun = sun;
      this.sunEl.textContent = sun === Infinity ? '∞' : String(sun);
    }
    const pf = b.rules.unlimitedPlantFood ? Infinity : b.plantFood;
    if (pf !== this.lastPf) {
      this.lastPf = pf;
      this.pfCountEl.textContent = pf === Infinity ? '∞' : String(pf);
      this.pfEl.classList.toggle('empty', pf <= 0);
    }
    this.refreshPackets();
    const p = b.progress;
    this.progressFill.style.width = `${p * 100}%`;
    this.progressHead.style.left = `${p * 100}%`;
  }

  private banner(text: string, style: string, ms = 2600) {
    if (!this.bannerEl) return;
    this.bannerEl.textContent = text;
    this.bannerEl.className = 'banner show ' + style;
    clearTimeout((this.bannerEl as unknown as { _t: number })._t);
    (this.bannerEl as unknown as { _t: number })._t = window.setTimeout(() => (this.bannerEl.className = 'banner'), ms);
  }

  private setMode(mode: Mode, plant: PlantId | null = null) {
    this.mode = mode;
    this.selected = mode === 'seed' ? plant : null;
    this.pfEl?.classList.toggle('active', mode === 'plantfood');
    this.shovelEl?.classList.toggle('active', mode === 'shovel');
    document.body.classList.toggle('mode-shovel', mode === 'shovel');
    document.body.classList.toggle('mode-pf', mode === 'plantfood');
    if (mode === 'none') this.highlight.visible = false;
    if (this.hud) this.refreshPackets();
  }

  private flyTo(kind: Pickup['kind'], world: THREE.Vector3, value: number) {
    if (!this.hud) return;
    const s = this.toScreen(world);
    const target = kind === 'sun' ? this.sunEl : kind === 'plantfood' ? this.pfEl : null;
    const el = h('div', { class: `fly fly-${kind}`, text: kind === 'sun' ? '' : kind === 'plantfood' ? '🌿' : kind === 'coin' ? `🪙${value}` : '🏆' });
    el.style.left = s.x + 'px';
    el.style.top = s.y + 'px';
    this.hud.append(el);
    requestAnimationFrame(() => {
      if (target) {
        const r = target.getBoundingClientRect();
        el.style.transform = `translate(${r.left + r.width / 2 - s.x}px, ${r.top + r.height / 2 - s.y}px) scale(0.6)`;
      } else {
        el.style.transform = 'translate(0, -60px)';
      }
      el.style.opacity = '0.2';
    });
    setTimeout(() => el.remove(), 650);
  }

  // ------------------------------------------------------------ input

  private toScreen(v: THREE.Vector3) {
    const p = v.clone().project(this.camera);
    return { x: ((p.x + 1) / 2) * window.innerWidth, y: ((1 - p.y) / 2) * window.innerHeight };
  }

  private pickTile(x: number, y: number): { col: number; lane: number } | null {
    const ndc = new THREE.Vector2((x / window.innerWidth) * 2 - 1, -(y / window.innerHeight) * 2 + 1);
    this.raycaster.setFromCamera(ndc, this.camera);
    const hit = new THREE.Vector3();
    if (!this.raycaster.ray.intersectPlane(this.plane, hit)) return null;
    const col = Math.round(hit.x + (COLS - 1) / 2);
    const lane = Math.round(hit.z + (LANES - 1) / 2);
    if (col < 0 || col >= COLS || lane < 0 || lane >= LANES) return null;
    return { col, lane };
  }

  /** Collect any pickup within reach of a screen point. Returns true if one was collected. */
  private tryCollect(x: number, y: number): boolean {
    let best: Pickup | null = null;
    let bestD = Infinity;
    for (const pk of this.battle.pickups) {
      if (pk.collected) continue;
      const s = this.toScreen(pk.pos);
      const d = Math.hypot(s.x - x, s.y - y);
      const r = pk.kind === 'trophy' ? 80 : 46;
      if (d < r && d < bestD) {
        best = pk;
        bestD = d;
      }
    }
    if (best) this.battle.collect(best);
    return !!best;
  }

  private onPacketDown(e: PointerEvent, id: PlantId) {
    e.preventDefault();
    e.stopPropagation();
    if (this.stage !== 'play' || this.paused) return;
    const ok = this.battle.canPlant(id);
    if (!ok.ok) {
      audio.play('error');
      this.packetEls.get(id)?.el.classList.add('shake');
      setTimeout(() => this.packetEls.get(id)?.el.classList.remove('shake'), 300);
      return;
    }
    if (this.selected === id) {
      this.setMode('none');
      return;
    }
    audio.play('select');
    this.setMode('seed', id);
    this.dragging = true;
    this.dragMoved = false;
  }

  private onCanvasDown(e: PointerEvent) {
    if (this.stage !== 'play' || this.paused) return;
    this.pointerDown = true;
    if (this.tryCollect(e.clientX, e.clientY)) return;
    const tile = this.pickTile(e.clientX, e.clientY);
    if (!tile) {
      if (this.mode !== 'none') this.setMode('none');
      return;
    }
    if (this.mode === 'seed' && this.selected) {
      if (this.battle.plantAt(this.selected, tile.col, tile.lane)) this.setMode('none');
    } else if (this.mode === 'shovel') {
      this.battle.shovel(tile.col, tile.lane);
      this.setMode('none');
    } else if (this.mode === 'plantfood') {
      if (this.battle.usePlantFood(tile.col, tile.lane)) this.setMode('none');
      else audio.play('error');
    }
  }

  private onMove(e: PointerEvent) {
    if (this.stage !== 'play' || this.paused) return;
    if (this.dragging && this.selected) {
      this.dragMoved = true;
      const tile = this.pickTile(e.clientX, e.clientY);
      if (tile) {
        this.highlight.visible = true;
        this.highlight.position.set(colX(tile.col), 0.05, laneZ(tile.lane));
        (this.highlight.material as THREE.MeshBasicMaterial).color.set(this.battle.plantAtTile(tile.col, tile.lane) ? '#ff5050' : '#ffffff');
      } else this.highlight.visible = false;
    } else if (this.pointerDown) {
      // Swipe over sun to collect it.
      this.tryCollect(e.clientX, e.clientY);
    }
  }

  private onUp(e: PointerEvent) {
    this.pointerDown = false;
    if (!this.dragging) return;
    this.dragging = false;
    this.highlight.visible = false;
    if (!this.dragMoved || !this.selected) return;
    const tile = this.pickTile(e.clientX, e.clientY);
    if (tile && this.battle.plantAt(this.selected, tile.col, tile.lane)) this.setMode('none');
  }

  private cancelDrag() {
    this.dragging = false;
    this.pointerDown = false;
    this.highlight.visible = false;
  }

  // ------------------------------------------------------------ frame

  private handleEvent(ev: BattleEvent) {
    switch (ev.type) {
      case 'sfx':
        audio.play(ev.name);
        break;
      case 'banner':
        this.banner(ev.text, ev.style, ev.style === 'info' ? 3500 : 2600);
        break;
      case 'collect':
        this.flyTo(ev.kind, ev.world, ev.value);
        break;
      case 'shake':
        this.shake = Math.max(this.shake, ev.amount);
        break;
      case 'end':
        this.onEnd(ev.result);
        break;
    }
  }

  update(dt: number) {
    this.env.update(dt);
    if (this.stage === 'select') {
      this.battle.idleZombies(dt);
      this.battle.particles.update(dt);
    } else if (this.stage === 'intro') {
      this.battle.update(dt);
      this.battle.idleZombies(dt);
    } else if (!this.paused) {
      const total = dt * this.speed;
      const steps = Math.max(1, Math.ceil(total / 0.034));
      for (let i = 0; i < steps; i++) this.battle.update(total / steps);
    }
    const events = this.battle.events.splice(0);
    for (const ev of events) this.handleEvent(ev);
    if (this.stage !== 'select') this.updateHud();
    this.updateCamera(dt);
  }

  private updateCamera(dt: number) {
    this.focusX += (this.focusGoal - this.focusX) * Math.min(1, dt * 2.2);
    // Fit the battlefield (house edge to street) to the screen width.
    const vfov = THREE.MathUtils.degToRad(this.camera.fov);
    const hfov = 2 * Math.atan(Math.tan(vfov / 2) * this.aspect);
    const halfW = 7.6;
    const dist = Math.max(halfW / Math.tan(hfov / 2), 8.5);
    const pitch = THREE.MathUtils.degToRad(52);
    const dir = new THREE.Vector3(0, Math.sin(pitch), Math.cos(pitch));
    const target = new THREE.Vector3(0.5 + this.focusX, 0, -0.3);
    this.camera.position.copy(target).addScaledVector(dir, dist);
    if (this.shake > 0) {
      this.shake = Math.max(0, this.shake - dt * 0.8);
      this.camera.position.x += (Math.random() - 0.5) * this.shake;
      this.camera.position.y += (Math.random() - 0.5) * this.shake;
    }
    this.camera.lookAt(target);
  }

  resize(w: number, h: number) {
    this.aspect = w / h;
    this.camera.aspect = this.aspect;
    this.camera.updateProjectionMatrix();
  }

  dispose() {
    this.disposed = true;
    for (const [t, type, fn] of this.listeners) t.removeEventListener(type, fn);
    this.battle.dispose();
    document.body.classList.remove('mode-shovel', 'mode-pf');
  }
}
