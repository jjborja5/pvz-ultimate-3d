// Battle screen: 3D scene + camera, touch input, HUD, seed selection, pause and results.
import * as THREE from 'three';
import type { App, View } from '../app';
import { audio } from '../game/audio';
import { Battle, type BattleEvent, type Pickup, type PlantEntity } from '../game/battle';
import { COLS, LANES, PLANTS, getLevel, nextLevelId, type LevelDef, type PlantId, type ZombieId } from '../game/config';
import { BOARD_LEFT, BOARD_RIGHT, buildEnvironment, colX, laneZ, type Environment } from '../game/environment';
import { safeInsets } from '../ui/safe';
import { rules, type Rules } from '../game/save';
import { clear, h } from '../ui/dom';
import { pauseMenu, resultsScreen, seedSelectScreen } from '../ui/screens';
import { plantThumb } from '../ui/thumbs';

type Mode = 'none' | 'seed' | 'shovel' | 'plantfood' | 'power';
type Power = 'zap' | 'toss' | 'snow';
const POWER_COST = 500;
const POWER_TIME = 5;

export class BattleView implements View {
  readonly scene = new THREE.Scene();
  readonly camera = new THREE.PerspectiveCamera(18, 16 / 9, 0.5, 160);
  readonly level: LevelDef;
  battle!: Battle;
  private env: Environment;
  private stage: 'select' | 'intro' | 'play' | 'ended' = 'select';
  private paused = false;
  speed = 1;
  private mode: Mode = 'none';
  private power: Power | null = null;
  private powerUntil = 0;
  private powerHits = new Map<number, number>();
  private powerEls = new Map<Power, HTMLElement>();
  private selected: PlantId | null = null;
  private dragging = false;
  private dragMoved = false;
  private dragTool: 'plantfood' | 'shovel' | null = null;
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
  private progNameEl!: HTMLElement;
  private lastWave = -1;
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

  private get sandbox() {
    return this.levelId === 'sandbox';
  }

  private rules(): Rules {
    return rules(this.app.save, { sandbox: this.sandbox });
  }

  private makeBattle(loadout: PlantId[]) {
    return new Battle(this.scene, this.level, loadout, this.rules(), { autoCollectSun: this.app.save.settings.autoCollectSun, endless: this.sandbox });
  }

  private listen(t: EventTarget, type: string, fn: EventListener) {
    t.addEventListener(type, fn);
    this.listeners.push([t, type, fn]);
  }

  private newBattle(loadout: PlantId[]) {
    if (this.battle) this.battle.dispose();
    const r = this.rules();
    this.loadout = loadout.slice(0, r.seedSlots);
    this.battle = this.makeBattle(this.loadout);
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
    this.overlay = seedSelectScreen(this.app, this.level, this.rules().seedSlots, (loadout) => this.beginBattle(loadout), () => this.quit());
    this.app.ui.append(this.overlay);
  }

  private beginBattle(loadout: PlantId[]) {
    this.app.save.lastLoadout = loadout;
    this.app.persist();
    this.loadout = loadout;
    // Rebuild battle with the chosen loadout (cooldowns depend on it), keep the lineup for the camera pan.
    this.battle.dispose();
    this.battle = this.makeBattle(loadout);
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
    this.battle.rules = this.rules();
    this.refreshPackets();
  }

  /** Re-apply Ultimate settings changed from the pause menu. */
  applyRules() {
    this.battle.rules = this.rules();
    this.battle.autoCollect = this.app.save.settings.autoCollectSun;
  }

  private quit() {
    this.app.showScreen(this.sandbox ? 'title' : 'map');
  }

  private onEnd(result: 'won' | 'lost') {
    this.stage = 'ended';
    this.setMode('none');
    const save = this.app.save;
    let gems = 0;
    let coins = 0;
    let packets = 0;
    if (result === 'won') {
      const first = !save.completed[this.levelId];
      save.completed[this.levelId] = (save.completed[this.levelId] ?? 0) + 1;
      coins = this.level.rewardCoins + this.battle.stats.coins;
      gems = first ? 5 : 0;
      save.coins += coins;
      save.gems += gems;
      packets = 10 + this.level.index * 2;
      save.seedPackets += packets;
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
        packets,
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
    const railLeft = h('div', { class: 'rail-left' }, sunBox, packets);

    const pauseBtn = h('button', { class: 'hud-btn', text: '⏸', attrs: { 'aria-label': 'Pause' }, onClick: () => this.pause() });
    if (ult) pauseBtn.append(h('span', { class: 'ult-dot', text: '👑' }));
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

    this.pfCountEl = h('span', { class: 'pf-count' });
    this.pfEl = h('button', { class: 'tool-btn pf', attrs: { 'aria-label': 'Plant Food' } }, h('span', { class: 'pf-leaf', text: '🌿' }), this.pfCountEl);
    this.pfEl.addEventListener('pointerdown', (e) => this.onToolDown(e, 'plantfood'));
    this.shovelEl = h('button', { class: 'tool-btn shovel', text: '⛏️', attrs: { 'aria-label': 'Shovel' } });
    this.shovelEl.addEventListener('pointerdown', (e) => this.onToolDown(e, 'shovel'));
    const free = this.battle.rules.unlimitedCurrency;
    const powers = h('div', { class: 'powers' });
    for (const [kind, icon, label] of [
      ['zap', '⚡', 'Power Zap'],
      ['toss', '🖐️', 'Power Toss'],
      ['snow', '❄️', 'Power Snow'],
    ] as [Power, string, string][]) {
      const el = h('button', { class: 'power-btn', attrs: { 'aria-label': label } }, h('span', { text: icon }), h('small', { text: free ? '∞' : `${POWER_COST}` }));
      el.addEventListener('click', () => this.activatePower(kind));
      this.powerEls.set(kind, el);
      powers.append(el);
    }
    const railRight = h('div', { class: 'rail-right' }, h('div', { class: 'rr-row' }, this.speedEl, pauseBtn), this.pfEl, this.shovelEl, powers);

    this.progressFill = h('div', { class: 'prog-fill' });
    this.progressHead = h('div', { class: 'prog-head', text: '🧟' });
    const bar = h('div', { class: 'prog-bar' }, this.progressFill);
    this.level.waves.forEach((w, i) => {
      if (w.flag) bar.append(h('div', { class: 'prog-flag', text: '🚩', style: { left: `${((i + 1) / this.level.waves.length) * 100}%` } }));
    });
    bar.append(this.progressHead);
    this.progNameEl = h('div', { class: 'prog-name', text: this.sandbox ? 'Wave 1' : `${this.level.id}` });
    const progress = h('div', { class: 'progress' }, this.progNameEl, bar);

    this.bannerEl = h('div', { class: 'banner' });
    this.hud = h('div', { class: 'hud' }, railLeft, railRight, progress, this.bannerEl);
    this.app.ui.append(this.hud);
    this.fitKey = '';
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
    if (this.sandbox && b.endlessWave !== this.lastWave) {
      this.lastWave = b.endlessWave;
      this.progNameEl.textContent = `🧪 Wave ${Math.max(1, b.endlessWave)}`;
    }
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

  private activatePower(kind: Power) {
    if (this.stage !== 'play' || this.paused) return;
    if (this.mode === 'power' && this.power === kind) {
      this.setMode('none');
      return;
    }
    const save = this.app.save;
    if (!this.battle.rules.unlimitedCurrency) {
      if (save.coins < POWER_COST) {
        audio.play('error');
        this.banner(`Power-ups cost ${POWER_COST} coins`, 'info', 1600);
        return;
      }
      save.coins -= POWER_COST;
      this.app.persist();
    }
    this.setMode('power');
    this.power = kind;
    this.powerUntil = this.battle.time + POWER_TIME;
    this.powerHits.clear();
    for (const [k, el] of this.powerEls) el.classList.toggle('active', k === kind);
    audio.play('pfuse');
    this.banner(kind === 'zap' ? 'Tap or swipe zombies to zap them!' : kind === 'toss' ? 'Tap zombies to fling them away!' : 'Tap zombies to freeze them!', 'info', 1500);
  }

  /** Apply the active power-up to the zombie under a screen point. */
  private powerAt(x: number, y: number, swipe: boolean) {
    if (this.mode !== 'power' || !this.power) return false;
    if (swipe && this.power === 'toss') return false;
    let best = null as null | (typeof this.battle.zombies)[number];
    let bd = 70;
    for (const z of this.battle.zombies) {
      if (z.dying >= 0 || z.hypno) continue;
      const s = this.toScreen(new THREE.Vector3(z.x, (this.battle.isFlying(z) ? 1.8 : 0.7) * z.def.scale, z.zPos));
      const d = Math.hypot(s.x - x, s.y - y);
      if (d < bd) {
        bd = d;
        best = z;
      }
    }
    if (!best) return false;
    const last = this.powerHits.get(best.uid) ?? -9;
    if (this.battle.time - last < 0.35) return true;
    this.powerHits.set(best.uid, this.battle.time);
    this.battle.powerUp(this.power, best);
    return true;
  }

  private setMode(mode: Mode, plant: PlantId | null = null) {
    if (mode !== 'power') {
      this.power = null;
      for (const el of this.powerEls.values()) el.classList.remove('active');
    }
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

  /**
   * The plant under a screen point. Plants stand up out of their tile, so tapping a plant's face lands
   * on the ground *behind* it; instead we measure the distance to each plant's body on screen.
   */
  private pickPlant(x: number, y: number): PlantEntity | null {
    let best: PlantEntity | null = null;
    let bd = Infinity;
    const a = new THREE.Vector3();
    const b = new THREE.Vector3();
    // Tile size in pixels at this zoom, used as the touch radius.
    const t0 = this.toScreen(new THREE.Vector3(0, 0, 0));
    const t1 = this.toScreen(new THREE.Vector3(1, 0, 0));
    const radius = Math.max(26, Math.hypot(t1.x - t0.x, t1.y - t0.y) * 0.62);
    for (const p of this.battle.plants) {
      if (p.dead) continue;
      const base = this.toScreen(a.set(p.x, 0.12, p.z));
      const top = this.toScreen(b.set(p.x, Math.max(0.3, p.model.muzzleY), p.z));
      // distance from the finger to the segment base..top
      const vx = top.x - base.x;
      const vy = top.y - base.y;
      const len2 = vx * vx + vy * vy || 1;
      const t = Math.max(0, Math.min(1, ((x - base.x) * vx + (y - base.y) * vy) / len2));
      let d = Math.hypot(x - (base.x + vx * t), y - (base.y + vy * t));
      if (p.overlay) d += 6; // prefer the plant inside a pumpkin
      if (d < radius && d < bd) {
        bd = d;
        best = p;
      }
    }
    if (best) return best;
    const tile = this.pickTile(x, y);
    return tile ? this.battle.plantAtTile(tile.col, tile.lane) : null;
  }

  private feedPlant(p: PlantEntity | null) {
    if (!p) {
      audio.play('error');
      return false;
    }
    if (p.def.noPlantFood) {
      audio.play('error');
      this.banner(`${p.def.name} can't use Plant Food`, 'info', 1400);
      return false;
    }
    if (!this.battle.usePlantFood(p.col, p.lane, p)) {
      audio.play('error');
      if (!this.battle.rules.unlimitedPlantFood && this.battle.plantFood <= 0) this.banner('No Plant Food left', 'info', 1400);
      return false;
    }
    return true;
  }

  private onToolDown(e: PointerEvent, mode: 'plantfood' | 'shovel') {
    e.preventDefault();
    e.stopPropagation();
    if (this.stage !== 'play' || this.paused) return;
    if (this.mode === mode) {
      this.setMode('none');
      return;
    }
    audio.play('select');
    this.setMode(mode);
    // The leaf / shovel can also be dragged straight onto a plant.
    this.dragTool = mode;
    this.dragMoved = false;
  }

  private onCanvasDown(e: PointerEvent) {
    if (this.stage !== 'play' || this.paused) return;
    this.pointerDown = true;
    if (this.mode === 'power') {
      this.powerAt(e.clientX, e.clientY, false);
      return;
    }
    if (this.mode === 'plantfood') {
      if (this.feedPlant(this.pickPlant(e.clientX, e.clientY))) this.setMode('none');
      return;
    }
    if (this.mode === 'shovel') {
      const p = this.pickPlant(e.clientX, e.clientY);
      if (p) this.battle.shovel(p.col, p.lane);
      this.setMode('none');
      return;
    }
    if (this.tryCollect(e.clientX, e.clientY)) return;
    const tile = this.pickTile(e.clientX, e.clientY);
    if (!tile) {
      if (this.mode !== 'none') this.setMode('none');
      return;
    }
    if (this.mode === 'seed' && this.selected) {
      if (this.battle.plantAt(this.selected, tile.col, tile.lane)) this.setMode('none');
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
        (this.highlight.material as THREE.MeshBasicMaterial).color.set(this.battle.canPlaceAt(this.selected, tile.col, tile.lane) ? '#ffffff' : '#ff5050');
      } else this.highlight.visible = false;
    } else if (this.dragTool) {
      this.dragMoved = true;
      const p = this.pickPlant(e.clientX, e.clientY);
      this.highlight.visible = !!p;
      if (p) {
        this.highlight.position.set(p.x, 0.05, p.z);
        (this.highlight.material as THREE.MeshBasicMaterial).color.set(this.dragTool === 'plantfood' ? (p.def.noPlantFood ? '#ff5050' : '#6dff6a') : '#ffb04a');
      }
    } else if (this.pointerDown && this.mode === 'power') {
      this.powerAt(e.clientX, e.clientY, true);
    } else if (this.pointerDown) {
      // Swipe over sun to collect it.
      this.tryCollect(e.clientX, e.clientY);
    }
  }

  private onUp(e: PointerEvent) {
    this.pointerDown = false;
    if (this.dragTool) {
      const tool = this.dragTool;
      this.dragTool = null;
      this.highlight.visible = false;
      if (!this.dragMoved) return; // a tap: stay in tool mode and wait for a tap on a plant
      const p = this.pickPlant(e.clientX, e.clientY);
      if (tool === 'plantfood') {
        if (this.feedPlant(p)) this.setMode('none');
      } else if (p) {
        this.battle.shovel(p.col, p.lane);
        this.setMode('none');
      }
      return;
    }
    if (!this.dragging) return;
    this.dragging = false;
    this.highlight.visible = false;
    if (!this.dragMoved || !this.selected) return;
    const tile = this.pickTile(e.clientX, e.clientY);
    if (tile && this.battle.plantAt(this.selected, tile.col, tile.lane)) this.setMode('none');
  }

  private cancelDrag() {
    this.dragging = false;
    this.dragTool = null;
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
      case 'pf': {
        if (!this.hud) break;
        const s = this.toScreen(ev.world);
        const el = h('div', { class: 'pf-pop', text: `🌿 ${ev.name}!` });
        el.style.left = s.x + 'px';
        el.style.top = s.y + 'px';
        this.hud.append(el);
        setTimeout(() => el.remove(), 1700);
        break;
      }
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
    if (this.mode === 'power' && this.battle.time > this.powerUntil) this.setMode('none');
    this.updateCamera(dt);
  }

  /** Screen rectangle (CSS px) the lawn may occupy: everything not covered by HUD rails or safe areas. */
  private freeRect() {
    const W = window.innerWidth;
    const H = window.innerHeight;
    const inset = safeInsets();
    let left = inset.left + 4;
    let right = W - inset.right - 4;
    let top = inset.top + 4;
    let bottom = H - inset.bottom - 4;
    if (this.hud && this.stage !== 'select') {
      const l = this.hud.querySelector('.rail-left')?.getBoundingClientRect();
      const r = this.hud.querySelector('.rail-right')?.getBoundingClientRect();
      const p = this.hud.querySelector('.progress')?.getBoundingClientRect();
      if (l && l.width) left = Math.max(left, l.right + 4);
      if (r && r.width) right = Math.min(right, r.left - 4);
      if (p && p.height) top = Math.max(top, p.bottom + 2);
    }
    return { left, right, top, bottom, W, H };
  }

  /** Points that must stay on screen: every tile, the mowers, plant/zombie heads in the back row and the street entry. */
  private static FIT_POINTS = (() => {
    const pts: THREE.Vector3[] = [];
    const x0 = BOARD_LEFT - 0.85;
    const x1 = BOARD_RIGHT + 0.7;
    const z0 = laneZ(0) - 0.5;
    const z1 = laneZ(LANES - 1) + 0.55;
    for (const x of [x0, x1]) {
      pts.push(new THREE.Vector3(x, 0, z0), new THREE.Vector3(x, 0, z1), new THREE.Vector3(x, 1.35, laneZ(0)), new THREE.Vector3(x, 0.9, z1));
    // Balloon zombies float above the back lane.
    pts.push(new THREE.Vector3(x, 2.1, laneZ(0)));
    }
    return pts;
  })();

  private fitKey = '';
  private fitPos = new THREE.Vector3();
  private fitTarget = new THREE.Vector3();

  /**
   * Fit the whole yard into the free screen rectangle. Works for any aspect ratio: it solves for the
   * camera distance (zoom) and a screen-plane offset so the lawn is as large as possible and centered.
   */
  private fitCheck = 0;

  private computeFit(dt = 0) {
    // Re-measuring the DOM every frame forces layout; check twice a second unless something changed.
    this.fitCheck -= dt;
    if (this.fitKey && this.fitCheck > 0) return;
    this.fitCheck = 0.5;
    const rect = this.freeRect();
    const key = `${rect.left}|${rect.right}|${rect.top}|${rect.bottom}|${rect.W}|${rect.H}`;
    if (key === this.fitKey) return;
    this.fitKey = key;
    const pitch = THREE.MathUtils.degToRad(44);
    const dir = new THREE.Vector3(0, Math.sin(pitch), Math.cos(pitch));
    const target = new THREE.Vector3(0.3, 0, 0);
    const cam = this.camera;
    cam.aspect = rect.W / rect.H;
    cam.updateProjectionMatrix();
    let dist = 20;
    const rw = Math.max(50, rect.right - rect.left);
    const rh = Math.max(50, rect.bottom - rect.top);
    const v = new THREE.Vector3();
    for (let iter = 0; iter < 6; iter++) {
      cam.position.copy(target).addScaledVector(dir, dist);
      cam.lookAt(target);
      cam.updateMatrixWorld(true);
      let minX = Infinity;
      let maxX = -Infinity;
      let minY = Infinity;
      let maxY = -Infinity;
      for (const p of BattleView.FIT_POINTS) {
        v.copy(p).project(cam);
        const sx = ((v.x + 1) / 2) * rect.W;
        const sy = ((1 - v.y) / 2) * rect.H;
        minX = Math.min(minX, sx);
        maxX = Math.max(maxX, sx);
        minY = Math.min(minY, sy);
        maxY = Math.max(maxY, sy);
      }
      const scale = Math.max((maxX - minX) / rw, (maxY - minY) / rh);
      // World units per pixel at the target depth.
      const wpp = (2 * dist * Math.tan(THREE.MathUtils.degToRad(cam.fov) / 2)) / rect.H;
      const dx = (minX + maxX) / 2 - (rect.left + rect.right) / 2;
      const dy = (minY + maxY) / 2 - (rect.top + rect.bottom) / 2;
      const right = new THREE.Vector3().setFromMatrixColumn(cam.matrixWorld, 0);
      const up = new THREE.Vector3().setFromMatrixColumn(cam.matrixWorld, 1);
      // Move the view so the lawn's center lands on the free rectangle's center.
      target.addScaledVector(right, dx * wpp).addScaledVector(up, -dy * wpp);
      dist *= scale * 1.02;
    }
    this.fitTarget.copy(target);
    this.fitPos.copy(target).addScaledVector(dir, dist);
  }

  private updateCamera(dt: number) {
    this.focusX += (this.focusGoal - this.focusX) * Math.min(1, dt * 2.2);
    this.computeFit(dt);
    const off = new THREE.Vector3(this.focusX, 0, 0);
    this.camera.position.copy(this.fitPos).add(off);
    const target = this.fitTarget.clone().add(off);
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
    this.fitKey = '';
  }

  dispose() {
    this.disposed = true;
    for (const [t, type, fn] of this.listeners) t.removeEventListener(type, fn);
    this.battle.dispose();
    document.body.classList.remove('mode-shovel', 'mode-pf');
  }
}
