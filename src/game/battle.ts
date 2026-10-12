// The battle simulation: plants, zombies, projectiles, statuses, sun, waves, plant food and
// win/lose rules. It owns Three.js objects for its entities but never touches the DOM or renderer,
// so it can be unit-tested headlessly. The view drains `events` each frame for sound, UI and FX.
//
// Plant behaviors live in plants/behaviors.ts and talk to the battle through the public helpers
// in the "toolkit" section below (targeting, projectiles, damage, statuses, area effects).
import * as THREE from 'three';
import { COLS, LANES, ZOMBIES, levelMultipliers, type LevelDef, type ZombieDef, type ZombieId } from './config';
import { BOARD_LEFT, BOARD_RIGHT, colX, laneZ } from './environment';
import { buildCoin, buildMower, buildPlantFood, buildSun, buildTrophy, projectileMesh } from './models/props';
import { buildPlant, type PlantModel } from './models/plants';
import { buildZombie, type ZombieModel } from './models/zombies';
import { disposeInstance } from './models/kit';
import { Particles } from './particles';
import { Fx } from './fx';
import { PLANTS } from './plants/roster';
import type { Effect, PlantDef, ProjSpec } from './plants/types';
import { animatePlant, applyPlantFood, initPlant, onPlantEaten, updatePlant } from './plants/behaviors';
import type { Rules } from './save';

export type SfxName =
  | 'shoot'
  | 'hit'
  | 'cone'
  | 'bucket'
  | 'place'
  | 'sun'
  | 'coin'
  | 'plantfood'
  | 'pfuse'
  | 'groan'
  | 'chomp'
  | 'explode'
  | 'mower'
  | 'siren'
  | 'win'
  | 'lose'
  | 'shovel'
  | 'error'
  | 'freeze'
  | 'smash'
  | 'arm'
  | 'gulp'
  | 'lob'
  | 'zap'
  | 'laser'
  | 'fire'
  | 'punch'
  | 'magic'
  | 'wind'
  | 'pop'
  | 'heal'
  | 'splat';

export type BattleEvent =
  | { type: 'sfx'; name: SfxName }
  | { type: 'banner'; text: string; style: 'huge' | 'final' | 'info' }
  | { type: 'collect'; kind: PickupKind; value: number; world: THREE.Vector3 }
  | { type: 'shake'; amount: number }
  | { type: 'end'; result: 'won' | 'lost' };

export type PickupKind = 'sun' | 'plantfood' | 'coin' | 'trophy';

export interface PlantEntity {
  uid: number;
  def: PlantDef;
  lane: number;
  col: number;
  x: number;
  z: number;
  hp: number;
  maxHp: number;
  shell: number;
  level: number;
  mult: ReturnType<typeof levelMultipliers>;
  model: PlantModel;
  /** Main behavior timer. */
  timer: number;
  /** Behavior-specific state. */
  s: Record<string, number>;
  pendingShots: number[];
  pfTime: number;
  pfBoost: number;
  armed: boolean;
  t: number;
  recoil: number;
  dead: boolean;
  overlay: boolean;
  /** Buffs recomputed every frame from support plants. */
  haste: number;
  dmgBuff: number;
  produceBuff: number;
  hitFlash: number;
}

export interface ZombieEntity {
  uid: number;
  def: ZombieDef;
  lane: number;
  x: number;
  /** Visual lane position (animates when switching lanes). */
  zPos: number;
  hp: number;
  maxHp: number;
  armor: number;
  shield: number;
  balloon: number;
  slow: number;
  freeze: number;
  stun: number;
  burnT: number;
  burnDps: number;
  poisonT: number;
  poisonDps: number;
  weakenT: number;
  weakenAmp: number;
  shrunk: boolean;
  hypno: boolean;
  vaulted: boolean;
  vaultT: number;
  raged: boolean;
  eating: PlantEntity | ZombieEntity | null;
  biteT: number;
  dying: number;
  charred: boolean;
  model: ZombieModel;
  animT: number;
  flash: number;
  hasPlantFood: boolean;
  chompTimer: number;
  smashTimer: number;
  knockV: number;
  ally: boolean;
}

export interface Projectile {
  spec: ProjSpec;
  mesh: THREE.Object3D;
  x: number;
  y: number;
  z: number;
  vx: number;
  vz: number;
  traveled: number;
  hits: Set<number>;
  dead: boolean;
  damage: number;
  target: ZombieEntity | null;
  lob: { fx: number; fz: number; tx: number; tz: number; t: number; dur: number; h: number; y0: number } | null;
  returning: boolean;
  bounces: number;
  bounceTo: number | null;
  fire: boolean;
  converted: Set<number>;
}

export interface Pickup {
  kind: PickupKind;
  value: number;
  obj: THREE.Object3D;
  pos: THREE.Vector3;
  vel: THREE.Vector3;
  groundY: number;
  landed: boolean;
  age: number;
  life: number;
  collected: boolean;
  sky: boolean;
}

interface Mower {
  lane: number;
  obj: THREE.Object3D;
  x: number;
  active: boolean;
  gone: boolean;
}

interface Debris {
  obj: THREE.Object3D;
  vel: THREE.Vector3;
  spin: THREE.Vector3;
  life: number;
}

export interface TileHazard {
  lava: number;
  lavaDps: number;
  crater: number;
}

export interface BattleOptions {
  autoCollectSun?: boolean;
  rng?: () => number;
  /** Endless sandbox: waves keep coming. */
  endless?: boolean;
}

const SKY_SUN_INTERVAL = 9;
const MOWER_TRIGGER_X = BOARD_LEFT + 0.05;
const HOUSE_X = BOARD_LEFT - 0.95;
export const RIGHT_EDGE = BOARD_RIGHT + 0.5;

export class Battle {
  readonly root = new THREE.Group();
  readonly particles: Particles;
  readonly fx: Fx;
  readonly events: BattleEvent[] = [];

  phase: 'ready' | 'playing' | 'won' | 'lost' = 'ready';
  sun: number;
  plantFood: number;
  readonly cooldown = new Map<string, number>();
  readonly cooldownMax = new Map<string, number>();
  readonly grid: (PlantEntity | null)[][];
  readonly overlays: (PlantEntity | null)[][];
  readonly hazards: TileHazard[][];
  readonly plants: PlantEntity[] = [];
  readonly zombies: ZombieEntity[] = [];
  readonly projectiles: Projectile[] = [];
  readonly pickups: Pickup[] = [];
  readonly mowers: Mower[] = [];
  private debris: Debris[] = [];

  waveIndex = 0;
  waveTimer: number;
  private hugeWarned = false;
  private lastWaveHp = 1;
  private skyTimer = 6;
  private groanTimer = 4;
  private uid = 0;
  private lastDeathPos = new THREE.Vector3(0, 0, 0);
  private trophySpawned = false;
  time = 0;
  /** Zombies ignore plants while > 0 (concealment). */
  concealT = 0;
  endless: boolean;
  endlessWave = 0;

  stats = { killed: 0, planted: 0, sunCollected: 0, coins: 0, plantFoodUsed: 0 };

  readonly rng: () => number;
  autoCollect: boolean;

  constructor(
    scene: THREE.Object3D,
    readonly level: LevelDef,
    readonly loadout: string[],
    public rules: Rules,
    opts: BattleOptions = {},
  ) {
    this.rng = opts.rng ?? Math.random;
    this.autoCollect = !!opts.autoCollectSun;
    this.endless = !!opts.endless;
    scene.add(this.root);
    this.particles = new Particles(this.root);
    this.fx = new Fx(this.root);
    this.sun = level.startSun;
    this.plantFood = 1;
    this.waveTimer = level.firstWaveDelay;
    this.grid = Array.from({ length: LANES }, () => Array<PlantEntity | null>(COLS).fill(null));
    this.overlays = Array.from({ length: LANES }, () => Array<PlantEntity | null>(COLS).fill(null));
    this.hazards = Array.from({ length: LANES }, () => Array.from({ length: COLS }, () => ({ lava: 0, lavaDps: 0, crater: 0 })));
    for (const id of loadout) {
      const def = PLANTS[id];
      if (!def) continue;
      const max = def.recharge * levelMultipliers(rules.plantLevel(id)).recharge;
      this.cooldownMax.set(id, max);
      this.cooldown.set(id, rules.instantRecharge ? 0 : max * (1 - def.startReady));
    }
    for (let lane = 0; lane < LANES; lane++) {
      const obj = buildMower();
      const x = BOARD_LEFT - 0.42;
      obj.position.set(x, 0, laneZ(lane));
      this.root.add(obj);
      this.mowers.push({ lane, obj, x, active: false, gone: false });
    }
  }

  get totalWaves() {
    return this.level.waves.length;
  }

  get progress() {
    if (this.endless) return (this.endlessWave % 10) / 10;
    const n = this.totalWaves;
    if (this.waveIndex >= n) return 1;
    return Math.min(1, this.waveIndex / n);
  }

  /** Living enemy zombies (excludes hypnotized allies and dying zombies). */
  get aliveZombies() {
    return this.zombies.filter((z) => z.dying < 0 && !z.hypno);
  }

  start() {
    if (this.phase === 'ready') this.phase = 'playing';
  }

  sfx(name: SfxName) {
    this.events.push({ type: 'sfx', name });
  }

  shake(amount: number) {
    this.events.push({ type: 'shake', amount });
  }

  // ================================================================ player actions

  canPlant(id: string): { ok: boolean; reason?: string } {
    if (this.phase !== 'playing') return { ok: false, reason: 'Not now' };
    if ((this.cooldown.get(id) ?? 0) > 0) return { ok: false, reason: 'Recharging' };
    if (!this.rules.unlimitedSun && this.sun < PLANTS[id].cost) return { ok: false, reason: 'Not enough sun' };
    return { ok: true };
  }

  /** Whether `id` may be placed on this tile right now (ignores sun/cooldown). */
  canPlaceAt(id: string, col: number, lane: number): boolean {
    if (col < 0 || col >= COLS || lane < 0 || lane >= LANES) return false;
    const def = PLANTS[id];
    const hz = this.hazards[lane][col];
    if (hz.crater > 0 || hz.lava > 0) return false;
    if (def.overlay) return !this.overlays[lane][col];
    return !this.grid[lane][col];
  }

  plantAt(id: string, col: number, lane: number): boolean {
    if (!this.canPlaceAt(id, col, lane) || !this.canPlant(id).ok) {
      this.sfx('error');
      return false;
    }
    const def = PLANTS[id];
    if (!this.rules.unlimitedSun) this.sun -= def.cost;
    this.cooldown.set(id, this.rules.instantRecharge ? 0 : (this.cooldownMax.get(id) ?? def.recharge));
    this.spawnPlant(id, col, lane);
    this.stats.planted++;
    this.sfx('place');
    return true;
  }

  spawnPlant(id: string, col: number, lane: number): PlantEntity {
    const def = PLANTS[id];
    if (!def) throw new Error('unknown plant ' + id);
    const level = this.rules.plantLevel(id);
    const mult = levelMultipliers(level);
    const model = buildPlant(id);
    const x = colX(col);
    const z = laneZ(lane);
    model.root.position.set(x, 0.03, z);
    this.root.add(model.root);
    const hp = def.behavior.type === 'instant' ? def.hp : def.hp * mult.hp;
    const p: PlantEntity = {
      uid: ++this.uid,
      def,
      lane,
      col,
      x,
      z,
      hp,
      maxHp: hp,
      shell: 0,
      level,
      mult,
      model,
      timer: 0.4,
      s: {},
      pendingShots: [],
      pfTime: 0,
      pfBoost: 1,
      armed: false,
      t: this.rng() * 10,
      recoil: 0,
      dead: false,
      overlay: !!def.overlay,
      haste: 1,
      dmgBuff: 1,
      produceBuff: 1,
      hitFlash: 0,
    };
    initPlant(this, p);
    if (p.overlay) this.overlays[lane][col] = p;
    else this.grid[lane][col] = p;
    this.plants.push(p);
    this.particles.burst(new THREE.Vector3(x, 0.1, z), { count: 14, colors: ['#7a5230', '#8f6a3d', '#5a3d20'], speed: 1.6, up: 1.4, size: 0.05 });
    return p;
  }

  plantAtTile(col: number, lane: number): PlantEntity | null {
    if (col < 0 || col >= COLS || lane < 0 || lane >= LANES) return null;
    return this.grid[lane][col] ?? this.overlays[lane][col];
  }

  shovel(col: number, lane: number): boolean {
    if (this.phase !== 'playing') return false;
    const p = this.grid[lane]?.[col] ?? this.overlays[lane]?.[col];
    if (!p) return false;
    this.removePlant(p);
    this.sfx('shovel');
    this.particles.burst(new THREE.Vector3(p.x, 0.2, p.z), { count: 12, colors: ['#7a5230', '#6fbf4a'], speed: 1.5 });
    return true;
  }

  usePlantFood(col: number, lane: number): boolean {
    if (this.phase !== 'playing') return false;
    const p = this.grid[lane]?.[col] ?? this.overlays[lane]?.[col];
    if (!p || p.def.noPlantFood) return false;
    if (!this.rules.unlimitedPlantFood && this.plantFood <= 0) return false;
    if (!this.rules.unlimitedPlantFood) this.plantFood--;
    this.stats.plantFoodUsed++;
    this.sfx('pfuse');
    const at = new THREE.Vector3(p.x, 0.5, p.z);
    this.particles.ring(at, '#5dff6a', 1.6, 0.6);
    this.particles.burst(at, { count: 30, colors: ['#5dff6a', '#b8ffb0', '#ffffff'], speed: 2.5, up: 2, gravity: 2 });
    this.fx.glowBurst(at, '#7dff7a', 1.2);
    applyPlantFood(this, p);
    return true;
  }

  collect(pk: Pickup) {
    if (pk.collected) return;
    pk.collected = true;
    this.root.remove(pk.obj);
    this.events.push({ type: 'collect', kind: pk.kind, value: pk.value, world: pk.pos.clone() });
    switch (pk.kind) {
      case 'sun':
        if (!this.rules.unlimitedSun) this.sun += pk.value;
        this.stats.sunCollected += pk.value;
        this.sfx('sun');
        break;
      case 'plantfood':
        this.addPlantFood(1);
        this.sfx('plantfood');
        break;
      case 'coin':
        this.stats.coins += pk.value;
        this.sfx('coin');
        break;
      case 'trophy':
        this.finish('won');
        break;
    }
  }

  addPlantFood(n: number) {
    if (!this.rules.unlimitedPlantFood) this.plantFood = Math.min(this.rules.plantFoodMax, this.plantFood + n);
  }

  /** Spend sun for an ability (e.g. Sun Lens). Returns false if not enough. */
  spendSun(n: number): boolean {
    if (this.rules.unlimitedSun) return true;
    if (this.sun < n) return false;
    this.sun -= n;
    return true;
  }

  // ================================================================ simulation

  update(dt: number) {
    this.time += dt;
    this.particles.update(dt);
    this.fx.update(dt);
    this.updateDebris(dt);
    this.updatePickups(dt);
    if (this.phase === 'ready') {
      for (const p of this.plants) animatePlant(this, p, dt);
      return;
    }
    if (this.phase !== 'playing') {
      for (const z of this.zombies) this.animateZombie(z, dt);
      return;
    }

    for (const [id, cd] of this.cooldown) if (cd > 0) this.cooldown.set(id, this.rules.instantRecharge ? 0 : Math.max(0, cd - dt));
    if (this.concealT > 0) this.concealT -= dt;

    this.updateHazards(dt);
    this.updateWaves(dt);
    this.updateSky(dt);
    this.computeBuffs();
    for (const p of this.plants) if (!p.dead) updatePlant(this, p, dt);
    for (let i = this.plants.length - 1; i >= 0; i--) if (this.plants[i].dead) this.plants.splice(i, 1);
    this.updateProjectiles(dt);
    for (const z of this.zombies) this.updateZombie(z, dt);
    for (let i = this.zombies.length - 1; i >= 0; i--) {
      const z = this.zombies[i];
      if (z.dying > 2.2 || (z.hypno && z.x > RIGHT_EDGE + 2.5)) {
        this.root.remove(z.model.root);
        disposeInstance(z.model.inst);
        this.zombies.splice(i, 1);
      }
    }
    this.updateMowers(dt);

    this.groanTimer -= dt;
    if (this.groanTimer <= 0) {
      this.groanTimer = 5 + this.rng() * 6;
      if (this.aliveZombies.length) this.sfx('groan');
    }

    if (!this.endless && !this.trophySpawned && this.waveIndex >= this.totalWaves && this.aliveZombies.length === 0) {
      this.trophySpawned = true;
      const pos = this.lastDeathPos.clone();
      pos.x = Math.min(Math.max(pos.x, BOARD_LEFT + 1), BOARD_RIGHT - 0.5);
      this.spawnPickup('trophy', 0, pos, false);
      this.events.push({ type: 'banner', text: 'Level Cleared! Tap the trophy!', style: 'info' });
    }
  }

  finish(result: 'won' | 'lost') {
    if (this.phase !== 'playing') return;
    this.phase = result;
    this.sfx(result === 'won' ? 'win' : 'lose');
    this.events.push({ type: 'end', result });
  }

  /** Support plants grant buffs to their neighbors; recomputed each frame. */
  private computeBuffs() {
    for (const p of this.plants) {
      p.haste = 1;
      p.dmgBuff = 1;
      p.produceBuff = 1;
    }
    for (const s of this.plants) {
      const b = s.def.behavior;
      if (b.type !== 'support' || s.dead) continue;
      if (b.kind !== 'haste' && b.kind !== 'damageBoost' && b.kind !== 'producerBoost') continue;
      const r = b.radius ?? 1;
      for (const p of this.plants) {
        if (p === s || Math.abs(p.col - s.col) > r || Math.abs(p.lane - s.lane) > r) continue;
        if (b.kind === 'haste') p.haste = Math.max(p.haste, b.amount ?? 1.5);
        if (b.kind === 'damageBoost') p.dmgBuff = Math.max(p.dmgBuff, b.amount ?? 1.5);
        if (b.kind === 'producerBoost') p.produceBuff = Math.max(p.produceBuff, b.amount ?? 1.5);
      }
    }
    // Wall plants with damage auras (e.g. Nightbloom) are handled as 'damageBoost' supports too.
  }

  private updateHazards(dt: number) {
    for (let lane = 0; lane < LANES; lane++) {
      for (let col = 0; col < COLS; col++) {
        const h = this.hazards[lane][col];
        if (h.crater > 0) h.crater = Math.max(0, h.crater - dt);
        if (h.lava > 0) {
          h.lava = Math.max(0, h.lava - dt);
          for (const z of this.zombies) {
            if (z.dying < 0 && !z.hypno && z.lane === lane && Math.abs(z.x - colX(col)) < 0.5 && !this.isFlying(z)) {
              this.damageZombie(z, h.lavaDps * dt, { kind: 'fire', silent: true });
            }
          }
          if (this.rng() < dt * 6) this.particles.burst(new THREE.Vector3(colX(col) + (this.rng() - 0.5) * 0.6, 0.08, laneZ(lane) + (this.rng() - 0.5) * 0.6), { count: 1, colors: ['#ff6a1f', '#ffb02a'], speed: 0.5, up: 1.2, gravity: 1, life: 0.5 });
        }
      }
    }
  }

  private updateWaves(dt: number) {
    if (this.endless) {
      this.waveTimer -= dt;
      const alive = this.aliveZombies.length;
      if (this.waveTimer <= 0 || (alive === 0 && this.waveTimer > 3)) {
        if (this.waveTimer > 0) {
          this.waveTimer = Math.min(this.waveTimer, 3);
          return;
        }
        this.endlessWave++;
        const wave = this.level.waves[(this.endlessWave - 1) % this.level.waves.length];
        const extra = Math.floor(this.endlessWave / this.level.waves.length);
        const ids = [...wave.zombies];
        for (let i = 0; i < extra; i++) ids.push(wave.zombies[i % wave.zombies.length]);
        this.spawnGroup(ids, !!wave.flag);
        if (wave.flag) this.events.push({ type: 'banner', text: `Wave ${this.endlessWave}!`, style: 'huge' });
        this.waveTimer = 22;
      }
      return;
    }
    if (this.waveIndex >= this.totalWaves) return;
    this.waveTimer -= dt;
    const next = this.level.waves[this.waveIndex];
    if (this.waveIndex > 0 && this.waveTimer > 5) {
      const alive = this.aliveZombies.reduce((s, z) => s + z.hp + z.armor, 0);
      if (alive <= this.lastWaveHp * 0.3) this.waveTimer = 5;
    }
    if (this.waveTimer > 0) return;
    if (next.flag && !this.hugeWarned) {
      this.hugeWarned = true;
      this.waveTimer = 3.5;
      this.events.push({ type: 'banner', text: 'A Huge Wave of Zombies is Approaching!', style: 'huge' });
      this.sfx('siren');
      return;
    }
    this.hugeWarned = false;
    this.spawnGroup(next.zombies, this.waveIndex % 3 === 1 || !!next.flag);
    this.waveIndex++;
    if (this.waveIndex === this.totalWaves) this.events.push({ type: 'banner', text: 'FINAL WAVE!', style: 'final' });
    const following = this.level.waves[this.waveIndex];
    this.waveTimer = following?.flag ? 30 : 25;
  }

  private spawnGroup(list: ZombieId[], plantFood: boolean) {
    const pfCarrier = plantFood ? Math.floor(this.rng() * list.length) : -1;
    let hp = 0;
    const ids = [...list].sort((a, b) => (a === 'flag' ? -1 : b === 'flag' ? 1 : 0));
    let lastLane = -1;
    ids.forEach((id, k) => {
      let lane = Math.floor(this.rng() * LANES);
      if (lane === lastLane) lane = (lane + 1 + Math.floor(this.rng() * (LANES - 1))) % LANES;
      lastLane = lane;
      const z = this.spawnZombie(id, lane, BOARD_RIGHT + 0.8 + k * 0.45 + this.rng() * 0.6);
      if (k === pfCarrier) z.hasPlantFood = true;
      hp += z.hp + z.armor + z.shield;
    });
    this.lastWaveHp = Math.max(1, hp);
  }

  spawnZombie(id: ZombieId, lane: number, x: number): ZombieEntity {
    const def = ZOMBIES[id];
    const model = buildZombie(def);
    const zPos = laneZ(lane);
    model.root.position.set(x, 0.03, zPos);
    this.root.add(model.root);
    const z: ZombieEntity = {
      uid: ++this.uid,
      def,
      lane,
      x,
      zPos,
      hp: def.hp,
      maxHp: def.hp,
      armor: def.armor,
      shield: def.shield ?? 0,
      balloon: def.flying ? 20 : 0,
      slow: 0,
      freeze: 0,
      stun: 0,
      burnT: 0,
      burnDps: 0,
      poisonT: 0,
      poisonDps: 0,
      weakenT: 0,
      weakenAmp: 0,
      shrunk: false,
      hypno: false,
      vaulted: !def.vault,
      vaultT: -1,
      raged: false,
      eating: null,
      biteT: 0,
      dying: -1,
      charred: false,
      model,
      animT: this.rng() * 10,
      flash: 0,
      hasPlantFood: false,
      chompTimer: 0,
      smashTimer: 0,
      knockV: 0,
      ally: false,
    };
    this.zombies.push(z);
    return z;
  }

  private updateSky(dt: number) {
    this.skyTimer -= dt;
    if (this.skyTimer > 0) return;
    this.skyTimer = SKY_SUN_INTERVAL + this.rng() * 3;
    const col = Math.floor(this.rng() * COLS);
    const lane = Math.floor(this.rng() * LANES);
    const pos = new THREE.Vector3(colX(col) + (this.rng() - 0.5) * 0.4, 6, laneZ(lane) + 0.2);
    this.spawnPickup('sun', 50, pos, true);
  }

  /** Pop a sun out of a plant. */
  produceSun(p: PlantEntity, value: number, i = 0) {
    const pos = new THREE.Vector3(p.x, 0.8, p.z);
    const pk = this.spawnPickup('sun', value, pos, false);
    pk.vel.set(0.4 + this.rng() * 0.6 + i * 0.2, 2.6 + this.rng(), 0.3 + (this.rng() - 0.5) * 0.6);
  }

  spawnPickup(kind: PickupKind, value: number, pos: THREE.Vector3, sky: boolean): Pickup {
    const obj = kind === 'sun' ? buildSun(value) : kind === 'plantfood' ? buildPlantFood() : kind === 'coin' ? buildCoin(value >= 50) : buildTrophy();
    obj.position.copy(pos);
    this.root.add(obj);
    const pk: Pickup = {
      kind,
      value,
      obj,
      pos: obj.position,
      vel: sky ? new THREE.Vector3(0, -0.9, 0) : new THREE.Vector3((this.rng() - 0.5) * 1.2, 2.8, 0.4),
      groundY: kind === 'trophy' ? 0.05 : 0.32,
      landed: false,
      age: 0,
      life: kind === 'sun' ? 11 : kind === 'trophy' ? Infinity : 13,
      collected: false,
      sky,
    };
    this.pickups.push(pk);
    return pk;
  }

  private updatePickups(dt: number) {
    for (let i = this.pickups.length - 1; i >= 0; i--) {
      const pk = this.pickups[i];
      if (pk.collected) {
        this.pickups.splice(i, 1);
        continue;
      }
      pk.age += dt;
      if (!pk.landed) {
        if (!pk.sky) pk.vel.y -= 7 * dt;
        pk.pos.addScaledVector(pk.vel, dt);
        if (pk.pos.y <= pk.groundY && pk.vel.y < 0) {
          pk.pos.y = pk.groundY;
          pk.landed = true;
          pk.age = 0;
        }
      } else {
        if (pk.kind !== 'trophy') pk.pos.y = pk.groundY + Math.sin(this.time * 3 + i) * 0.04;
        if (pk.kind === 'coin' && pk.age > 0.8) {
          this.collect(pk);
          continue;
        }
        if (pk.kind === 'sun' && this.autoCollect && pk.age > 0.5) {
          this.collect(pk);
          continue;
        }
        if (pk.kind === 'trophy' && pk.age > 8) {
          this.collect(pk);
          continue;
        }
        if (pk.age > pk.life) {
          this.root.remove(pk.obj);
          pk.collected = true;
          continue;
        }
        if (pk.age > pk.life - 2) pk.obj.visible = Math.floor(pk.age * 8) % 2 === 0;
      }
      pk.obj.rotation.y += dt * (pk.kind === 'coin' ? 6 : 1.2);
      const rays = pk.obj.userData.rays as THREE.Object3D | undefined;
      if (rays) rays.rotation.z += dt * 1.5;
    }
  }

  // ================================================================ toolkit for plant behaviors

  isFlying(z: ZombieEntity) {
    return z.balloon > 0;
  }

  /** Enemy zombies that plants may target. */
  enemies(): ZombieEntity[] {
    return this.zombies.filter((z) => z.dying < 0 && !z.hypno && z.x < RIGHT_EDGE + 0.4);
  }

  /** First zombie in a lane ahead of x (or behind when dir = -1), within range tiles. */
  firstInLane(lane: number, x: number, range = 99, dir = 1, air = false, furthest = false): ZombieEntity | null {
    let best: ZombieEntity | null = null;
    for (const z of this.zombies) {
      if (z.dying >= 0 || z.hypno || z.lane !== lane) continue;
      if (!air && this.isFlying(z)) continue;
      if (z.x > RIGHT_EDGE + 0.3) continue;
      const d = (z.x - x) * dir;
      if (d < -0.3 || d > range) continue;
      if (!best || (furthest ? d > (best.x - x) * dir : d < (best.x - x) * dir)) best = z;
    }
    return best;
  }

  /** Nearest enemy zombie to a point within radius (tiles). */
  nearest(x: number, z: number, radius = 99, air = true, filter?: (z: ZombieEntity) => boolean): ZombieEntity | null {
    let best: ZombieEntity | null = null;
    let bd = radius;
    for (const zb of this.zombies) {
      if (zb.dying >= 0 || zb.hypno || zb.x > RIGHT_EDGE + 0.3) continue;
      if (!air && this.isFlying(zb)) continue;
      if (filter && !filter(zb)) continue;
      const d = Math.hypot(zb.x - x, zb.zPos - z);
      if (d <= bd) {
        bd = d;
        best = zb;
      }
    }
    return best;
  }

  /** Enemy zombies inside a rectangle: |dx| <= radius and |lane diff| <= lanes. */
  inArea(x: number, lane: number, radius: number, lanes: number, air = true): ZombieEntity[] {
    return this.zombies.filter(
      (z) => z.dying < 0 && !z.hypno && Math.abs(z.lane - lane) <= lanes && Math.abs(z.x - x) <= radius && z.x < RIGHT_EDGE + 0.5 && (air || !this.isFlying(z)),
    );
  }

  damageOf(p: PlantEntity, base: number) {
    return base * p.mult.damage * p.dmgBuff * (this.rules.maxDamage ? 100 : 1);
  }

  /** Fire a projectile from a point in direction (dx, dz). */
  shoot(from: { x: number; y: number; z: number }, spec: ProjSpec, dx = 1, dz = 0, damage = spec.damage, target: ZombieEntity | null = null): Projectile {
    const mesh = projectileMesh(spec.look, spec.scale ?? 1);
    mesh.position.set(from.x, from.y, from.z);
    this.root.add(mesh);
    const len = Math.hypot(dx, dz) || 1;
    const speed = spec.speed ?? 6.5;
    const pr: Projectile = {
      spec,
      mesh,
      x: from.x,
      y: from.y,
      z: from.z,
      vx: (dx / len) * speed,
      vz: (dz / len) * speed,
      traveled: 0,
      hits: new Set(),
      dead: false,
      damage,
      target,
      lob: null,
      returning: false,
      bounces: 0,
      bounceTo: null,
      fire: spec.look === 'fire',
      converted: new Set(),
    };
    this.projectiles.push(pr);
    return pr;
  }

  /** Lob a projectile in an arc that lands on the target zombie (or a point). */
  lob(from: { x: number; y: number; z: number }, spec: ProjSpec, target: ZombieEntity | null, damage: number, at?: { x: number; z: number }) {
    const pr = this.shoot(from, spec, 1, 0, damage, target);
    const tx = target ? target.x - (target.def.speed ?? 0.2) * 0.6 : at!.x;
    const tz = target ? target.zPos : at!.z;
    const dist = Math.hypot(tx - from.x, tz - from.z);
    pr.lob = { fx: from.x, fz: from.z, tx, tz, t: 0, dur: Math.max(0.55, Math.min(1.3, dist * 0.16 + 0.45)), h: 1.6 + dist * 0.12, y0: from.y };
    this.sfx('lob');
    return pr;
  }

  damageZombie(
    z: ZombieEntity,
    dmg: number,
    o: { kind?: 'pea' | 'fire' | 'ice' | 'blast' | 'mower' | 'poison' | 'melee' | 'beam' | 'volt' | 'magic'; front?: boolean; silent?: boolean; ignoreArmor?: boolean } = {},
  ) {
    if (z.dying >= 0) return;
    const kind = o.kind ?? 'pea';
    if (z.weakenT > 0) dmg *= 1 + z.weakenAmp;
    if (z.shrunk) dmg *= 1.5;
    if (kind === 'mower') {
      z.hp = 0;
      z.armor = 0;
    }
    z.flash = 0.1;
    if (this.isFlying(z)) {
      z.balloon -= dmg;
      if (z.balloon <= 0) this.popBalloon(z);
      return;
    }
    if (o.front && z.shield > 0) {
      z.shield -= dmg;
      if (z.shield <= 0) {
        z.shield = 0;
        this.dropPart(z, 'shield');
      }
      return;
    }
    if (z.armor > 0 && !o.ignoreArmor) {
      z.armor -= dmg;
      if (z.armor <= 0) {
        z.hp += z.armor;
        z.armor = 0;
        this.dropPart(z, 'armor');
        if (z.def.rage) {
          z.raged = true;
          this.particles.burst(new THREE.Vector3(z.x, 1.3, z.zPos), { count: 10, colors: ['#ff3a2a', '#ffffff'], speed: 1.5, up: 1.5 });
        }
      }
    } else {
      z.hp -= dmg;
    }
    if (z.hp <= 0) this.killZombie(z, kind === 'blast' || kind === 'fire' || kind === 'volt');
  }

  /** Apply status effects carried by a projectile/beam. */
  applyStatus(z: ZombieEntity, s: { slow?: number; freeze?: number; burn?: number; stun?: number; poison?: number; weaken?: number; knockback?: number }) {
    if (z.dying >= 0) return;
    if (z.def.boss && (s.freeze || s.stun)) {
      // Bosses shrug off hard control but still get chilled.
      s = { ...s, freeze: undefined, stun: undefined, slow: Math.max(s.slow ?? 0, (s.freeze ?? 0) > 0 ? 3 : 0) };
    }
    if (s.burn) {
      z.burnT = 3;
      z.burnDps = Math.max(z.burnDps * (z.burnT > 0 ? 1 : 0), s.burn);
      z.slow = 0;
      z.freeze = 0;
    }
    if (s.slow) {
      z.slow = Math.max(z.slow, s.slow);
      z.burnT = 0;
    }
    if (s.freeze) {
      z.freeze = Math.max(z.freeze, s.freeze);
      z.burnT = 0;
    }
    if (s.stun) z.stun = Math.max(z.stun, s.stun);
    if (s.poison) {
      z.poisonT = 4;
      z.poisonDps = Math.max(z.poisonDps, s.poison);
    }
    if (s.weaken) {
      z.weakenT = 5;
      z.weakenAmp = Math.max(z.weakenAmp, s.weaken);
    }
    if (s.knockback) this.knockback(z, s.knockback);
  }

  knockback(z: ZombieEntity, tiles: number) {
    if (z.def.boss) tiles *= 0.25;
    z.x = Math.min(z.x + tiles, RIGHT_EDGE + 1.2);
    z.knockV = 0.3;
    z.eating = null;
  }

  hypnotize(z: ZombieEntity, force = false) {
    if (z.dying >= 0 || (z.def.boss && !force) || z.hypno) return false;
    z.hypno = true;
    z.eating = null;
    z.slow = z.freeze = z.stun = 0;
    z.model.root.rotation.y = 0.45; // face right
    z.model.inst.material.color.set('#e9b8ff');
    this.particles.burst(new THREE.Vector3(z.x, 1.2, z.zPos), { count: 18, colors: ['#e07aff', '#ffffff', '#b04fff'], speed: 1.6, up: 1, gravity: 0 });
    this.sfx('magic');
    return true;
  }

  switchLane(z: ZombieEntity, lane: number) {
    if (lane < 0 || lane >= LANES) return;
    z.lane = lane;
    z.eating = null;
  }

  /** Spawn an allied (hypnotized) zombie. */
  spawnAlly(id: ZombieId, lane: number, x: number) {
    const z = this.spawnZombie(id, lane, x);
    z.ally = true;
    this.hypnotize(z, true);
    return z;
  }

  /** Run an area effect centered on a tile. */
  runEffect(e: Effect, x: number, lane: number, src?: PlantEntity) {
    const z0 = laneZ(lane);
    const dm = (d: number) => (src ? this.damageOf(src, d) : d);
    switch (e.type) {
      case 'blast': {
        for (const z of this.inArea(x, lane, e.radius, e.lanes)) this.damageZombie(z, dm(e.damage), { kind: e.fire ? 'fire' : 'blast' });
        this.explosionFx(x, z0, e.radius, e.color ?? (e.fire ? '#ff5a2a' : '#ffb02a'));
        if (e.crater) {
          const col = Math.round(x + (COLS - 1) / 2);
          if (col >= 0 && col < COLS) this.hazards[lane][col].crater = e.crater;
          this.fx.crater(new THREE.Vector3(x, 0.05, z0), e.crater);
        }
        break;
      }
      case 'laneFire': {
        for (const z of this.zombies) if (z.dying < 0 && !z.hypno && z.lane === lane && z.x < RIGHT_EDGE + 0.5) this.damageZombie(z, dm(e.damage), { kind: 'fire' });
        for (let c = 0; c < COLS; c++) this.particles.burst(new THREE.Vector3(colX(c), 0.3, z0), { count: 10, colors: ['#ff5a1f', '#ffb02a', '#ffe36a'], speed: 1.8, up: 3, size: 0.09, life: 0.8, gravity: -1 });
        this.fx.laneFlash(z0, '#ff7a1f');
        this.sfx('fire');
        this.shake(0.18);
        break;
      }
      case 'freezeAll': {
        for (const z of this.enemies()) {
          if (e.damage) this.damageZombie(z, dm(e.damage), { kind: 'ice' });
          this.applyStatus(z, { freeze: e.duration, slow: e.duration + 6 });
        }
        this.fx.screenTint('#bfefff', 0.6);
        this.sfx('freeze');
        break;
      }
      case 'freezeArea': {
        for (const z of this.inArea(x, lane, e.radius, e.lanes)) {
          if (e.damage) this.damageZombie(z, dm(e.damage), { kind: 'ice' });
          this.applyStatus(z, { freeze: e.duration, slow: e.duration + 5 });
        }
        this.particles.burst(new THREE.Vector3(x, 0.4, z0), { count: 30, colors: ['#dff6ff', '#9fdcff', '#ffffff'], speed: 2.5, up: 1.5, size: 0.06 });
        this.particles.ring(new THREE.Vector3(x, 0.3, z0), '#bfefff', 1.2 + e.radius, 0.5);
        this.sfx('freeze');
        break;
      }
      case 'stunAll': {
        for (const z of this.enemies()) {
          if (e.damage) this.damageZombie(z, dm(e.damage), { kind: 'pea' });
          this.applyStatus(z, { stun: e.duration });
          this.particles.burst(new THREE.Vector3(z.x, 1.3, z.zPos), { count: 6, colors: ['#ffe36a', '#fff6b0'], speed: 1, up: 1 });
        }
        this.sfx('splat');
        break;
      }
      case 'strikeAll': {
        for (const z of this.enemies()) {
          this.damageZombie(z, dm(e.damage), { kind: 'volt' });
          this.fx.lightning(new THREE.Vector3(z.x, 5, z.zPos), new THREE.Vector3(z.x, 0.6, z.zPos), '#d9b8ff');
        }
        this.sfx('zap');
        this.shake(0.15);
        break;
      }
      case 'laser': {
        for (const z of this.zombies) if (z.dying < 0 && !z.hypno && Math.abs(z.lane - lane) <= e.lanes && z.x > x - 0.3) this.damageZombie(z, dm(e.damage), { kind: 'beam' });
        for (let l = Math.max(0, lane - e.lanes); l <= Math.min(LANES - 1, lane + e.lanes); l++)
          this.fx.beam(new THREE.Vector3(x + 0.3, 0.6, laneZ(l)), new THREE.Vector3(RIGHT_EDGE + 1, 0.6, laneZ(l)), '#ff4af0', 0.22, 0.5);
        this.sfx('laser');
        break;
      }
      case 'shrink': {
        for (const z of this.inArea(x, lane, e.radius, e.lanes)) this.shrinkZombie(z);
        this.particles.ring(new THREE.Vector3(x, 0.5, z0), '#c48aff', 2.5, 0.5);
        this.sfx('magic');
        break;
      }
      case 'blowAll': {
        for (const z of this.enemies()) {
          if (this.isFlying(z)) {
            this.blowAway(z);
            continue;
          }
          this.knockback(z, e.distance);
        }
        this.fx.wind(0, 0, '#e8fff6', true);
        this.sfx('wind');
        break;
      }
      case 'blowLane': {
        for (const z of this.zombies) {
          if (z.dying >= 0 || z.hypno || z.lane !== lane) continue;
          if (this.isFlying(z)) this.blowAway(z);
          else {
            this.knockback(z, e.distance);
            this.applyStatus(z, { slow: e.chill });
          }
        }
        this.fx.wind(z0, x, '#dff6ff', false);
        this.sfx('wind');
        break;
      }
      case 'giveSun':
        if (src) for (let i = 0; i < Math.ceil(e.amount / 75); i++) this.produceSun(src, Math.min(75, e.amount - i * 75), i);
        break;
      case 'givePlantFood':
        this.addPlantFood(e.amount);
        if (src) this.spawnPickup('plantfood', 1, new THREE.Vector3(src.x, 0.9, src.z), false).collected = false;
        break;
      case 'boostProducers':
        for (const p of this.plants) {
          if (p.def.behavior.type === 'produce') {
            const b = p.def.behavior;
            for (let i = 0; i < (b.count ?? 1); i++) this.produceSun(p, Math.round((p.s.amount ?? b.amount) * p.mult.sun), i);
            p.timer = Math.min(p.timer, b.interval * 0.5);
          }
        }
        this.sfx('sun');
        break;
      case 'conceal':
        this.concealT = e.duration;
        for (const z of this.zombies) if (z.eating && 'col' in z.eating) z.eating = null;
        this.fx.screenTint('#9fffd0', 0.5);
        this.sfx('magic');
        break;
      case 'lavaPool': {
        for (const z of this.inArea(x, lane, 0.6, 0)) this.damageZombie(z, dm(e.damage), { kind: 'fire' });
        const col = Math.round(x + (COLS - 1) / 2);
        if (col >= 0 && col < COLS) {
          const h = this.hazards[lane][col];
          h.lava = e.duration;
          h.lavaDps = e.dps;
          this.fx.pool(new THREE.Vector3(x, 0.05, z0), '#ff6a1f', e.duration);
        }
        this.explosionFx(x, z0, 0.6, '#ff6a1f');
        break;
      }
      case 'grapes': {
        for (let i = 0; i < e.count; i++) {
          const a = (i / e.count) * Math.PI * 2;
          this.shoot({ x, y: 0.4, z: z0 }, { look: 'grape', damage: e.damage, speed: 5, range: 4, air: true }, Math.cos(a), Math.sin(a), dm(e.damage));
        }
        this.explosionFx(x, z0, 0.5, '#9a4fd8');
        break;
      }
      case 'globalSlow':
        for (const z of this.enemies()) this.applyStatus(z, { slow: e.duration });
        this.fx.screenTint('#c8d8ff', 0.4);
        this.sfx('magic');
        break;
      case 'summonAlly':
        this.spawnAlly(e.zombie, lane, x + 0.3);
        break;
      case 'laneStrike': {
        for (const z of this.zombies) if (z.dying < 0 && !z.hypno && z.lane === lane && z.x < RIGHT_EDGE + 0.5 && !this.isFlying(z)) this.damageZombie(z, dm(e.damage), { kind: 'melee' });
        for (let c = 0; c < COLS; c++) this.particles.burst(new THREE.Vector3(colX(c), 0.1, z0), { count: 6, colors: [e.color, '#ffffff'], speed: 1.2, up: 3.5, size: 0.06, life: 0.5 });
        this.fx.laneFlash(z0, e.color);
        this.sfx('punch');
        this.shake(0.12);
        break;
      }
      case 'healAll':
        for (const p of this.plants) {
          if (p.dead) continue;
          p.hp = Math.min(p.maxHp, p.hp + e.amount);
          this.particles.burst(new THREE.Vector3(p.x, 0.6, p.z), { count: 5, colors: ['#7dffb0', '#ffffff'], speed: 0.8, up: 1.2, gravity: -0.5 });
        }
        this.fx.screenTint('#9fffc8', 0.5);
        this.sfx('heal');
        break;
      case 'hypnoArea': {
        for (const z of this.inArea(x, lane, e.radius, e.lanes, false)) this.hypnotize(z);
        this.particles.ring(new THREE.Vector3(x, 0.5, z0), '#e07aff', 2.5, 0.5);
        break;
      }
      case 'transformArea': {
        const id = 'puffcap';
        for (const z of this.inArea(x, lane, e.radius, e.lanes)) {
          if (z.def.boss) {
            this.damageZombie(z, dm(500), { kind: 'magic' });
            continue;
          }
          const col = Math.round(z.x + (COLS - 1) / 2);
          const zl = z.lane;
          this.consumeZombie(z, '#c07ad8');
          if (col >= 0 && col < COLS && this.canPlaceAt(id, col, zl)) this.spawnPlant(id, col, zl);
        }
        this.particles.ring(new THREE.Vector3(x, 0.5, z0), '#e07aff', 2 + e.radius, 0.5);
        this.sfx('magic');
        break;
      }
      case 'hypnoEater':
      case 'stunEater':
      case 'sunEater':
      case 'drag':
        // Handled by the owning plant (they need the eating zombie).
        break;
    }
  }

  explosionFx(x: number, z: number, radius: number, color: string) {
    const at = new THREE.Vector3(x, 0.4, z);
    this.particles.ring(at, color, 1.6 + radius, 0.5);
    this.particles.ring(at, '#fff2a0', 0.8 + radius * 0.6, 0.3);
    this.particles.burst(at, { count: 50, colors: [color, '#ffb02a', '#ffe36a', '#ffffff'], speed: 4 + radius, up: 2.5, size: 0.08, life: 0.7 });
    this.particles.burst(at, { count: 12, colors: ['#9a9088', '#b8b0a8', '#7a7470'], speed: 1.4, up: 1.6, size: 0.07, life: 0.8, gravity: -0.6, grow: 1.4 });
    this.fx.glowBurst(at, color, 1 + radius);
    this.sfx('explode');
    this.shake(0.2 + radius * 0.05);
  }

  shrinkZombie(z: ZombieEntity) {
    if (z.shrunk || z.dying >= 0) return;
    z.shrunk = true;
    if (z.def.boss) {
      z.hp *= 0.75;
    } else {
      z.hp *= 0.5;
      z.armor *= 0.5;
      z.shield *= 0.5;
    }
  }

  blowAway(z: ZombieEntity) {
    z.dying = 0;
    z.charred = false;
    this.stats.killed++;
    z.knockV = 3;
    this.lastDeathPos.set(Math.min(z.x, BOARD_RIGHT), 0, z.zPos);
  }

  popBalloon(z: ZombieEntity) {
    z.balloon = 0;
    this.dropPart(z, 'balloon');
    this.particles.burst(new THREE.Vector3(z.x, 2.1, z.zPos), { count: 12, colors: ['#ff4a6a', '#ffffff'], speed: 2, up: 0.5 });
    this.sfx('pop');
  }

  /** A plant devours / removes a zombie outright (counts as a kill). */
  consumeZombie(z: ZombieEntity, fxColor = '#7a4fc3') {
    if (z.dying >= 0) return;
    this.particles.burst(new THREE.Vector3(z.x, 0.6, z.zPos), { count: 20, colors: [fxColor, '#ffffff'], speed: 2, up: 1 });
    this.killZombie(z, false, true);
    z.dying = 2.1;
  }

  // ================================================================ projectiles

  private updateProjectiles(dt: number) {
    for (const pr of this.projectiles) {
      if (pr.dead) continue;
      const sp = pr.spec;
      if (pr.lob) {
        const L = pr.lob;
        if (pr.target && pr.target.dying < 0) {
          L.tx = pr.target.x;
          L.tz = pr.target.zPos;
        }
        L.t += dt / L.dur;
        const t = Math.min(1, L.t);
        pr.x = L.fx + (L.tx - L.fx) * t;
        pr.z = L.fz + (L.tz - L.fz) * t;
        pr.y = L.y0 + (0.35 - L.y0) * t + Math.sin(Math.PI * t) * L.h;
        pr.mesh.position.set(pr.x, pr.y, pr.z);
        pr.mesh.rotation.z -= dt * 8;
        if (t >= 1) this.lobImpact(pr);
        continue;
      }
      if (sp.path === 'homing') {
        if (!pr.target || pr.target.dying >= 0 || pr.target.hypno) pr.target = this.nearest(pr.x, pr.z, 99, true);
        if (pr.target) {
          const dx = pr.target.x - pr.x;
          const dz = pr.target.zPos - pr.z;
          const len = Math.hypot(dx, dz) || 1;
          const speed = sp.speed ?? 6;
          const k = Math.min(1, dt * 6);
          pr.vx += ((dx / len) * speed - pr.vx) * k;
          pr.vz += ((dz / len) * speed - pr.vz) * k;
          const ty = this.isFlying(pr.target) ? 2 : 0.6;
          pr.y += (ty - pr.y) * Math.min(1, dt * 4);
        }
      }
      if (sp.path === 'boomerang') {
        const range = sp.range ?? 5;
        if (!pr.returning && pr.traveled >= range) {
          pr.returning = true;
          pr.vx = -pr.vx;
          pr.vz = -pr.vz;
          pr.hits.clear();
        }
      }
      pr.x += pr.vx * dt;
      pr.z += pr.vz * dt;
      if (pr.bounceTo !== null && pr.vz !== 0 && (pr.vz > 0 ? pr.z >= pr.bounceTo : pr.z <= pr.bounceTo)) {
        // Finished hopping to the next lane: roll straight again.
        pr.z = pr.bounceTo;
        pr.vx = Math.hypot(pr.vx, pr.vz);
        pr.vz = 0;
      }
      pr.traveled += Math.hypot(pr.vx, pr.vz) * dt;
      pr.mesh.position.set(pr.x, pr.y, pr.z);
      if (sp.look === 'star' || sp.look === 'boomerang' || sp.look === 'thistle' || sp.look === 'bulb' || sp.look === 'spike') pr.mesh.rotation.y += dt * 12;
      else pr.mesh.rotation.x += dt * 6;

      // Torch Vine converts passing peas into fire peas.
      const col = Math.round(pr.x + (COLS - 1) / 2);
      const lane = Math.round(pr.z + (LANES - 1) / 2);
      if (col >= 0 && col < COLS && lane >= 0 && lane < LANES) {
        const tp = this.grid[lane][col];
        if (tp && tp.def.behavior.type === 'support' && tp.def.behavior.kind === 'fireConvert' && !pr.converted.has(tp.uid) && Math.abs(pr.x - tp.x) < 0.2) {
          pr.converted.add(tp.uid);
          if (pr.spec.look === 'snow') {
            pr.spec = { ...pr.spec, look: 'pea', slow: undefined };
          } else if (!pr.fire && (pr.spec.look === 'pea' || pr.spec.look === 'mega' || pr.spec.look === 'goo')) {
            pr.fire = true;
            pr.damage *= 2;
            pr.spec = { ...pr.spec, look: 'fire', burn: Math.max(pr.spec.burn ?? 0, 8), splash: Math.max(pr.spec.splash ?? 0, 0.4), splashFrac: 0.3 };
            this.root.remove(pr.mesh);
            pr.mesh = projectileMesh('fire', (sp.scale ?? 1) * 1.2);
            pr.mesh.position.set(pr.x, pr.y, pr.z);
            this.root.add(pr.mesh);
            this.particles.burst(pr.mesh.position, { count: 6, colors: ['#ff7a1f', '#ffe36a'], speed: 1, up: 0.5, life: 0.3 });
          }
        }
      }

      // Collision
      let hit: ZombieEntity | null = null;
      for (const z of this.zombies) {
        if (z.dying >= 0 || z.hypno || pr.hits.has(z.uid)) continue;
        const flying = this.isFlying(z);
        if (flying && !sp.air) continue;
        if (Math.abs(z.zPos - pr.z) > 0.42) continue;
        const s = z.def.scale * (z.shrunk ? 0.6 : 1);
        if (pr.x >= z.x - 0.22 * s && pr.x <= z.x + 0.32 * s) {
          if (!hit || (pr.vx >= 0 ? z.x < hit.x : z.x > hit.x)) hit = z;
        }
      }
      if (hit) {
        this.projectileHit(pr, hit);
        if (pr.dead) continue;
      }
      const maxRange = sp.range ?? 30;
      if (pr.traveled > maxRange || pr.x > RIGHT_EDGE + 2.5 || pr.x < BOARD_LEFT - 2 || pr.z < -4 || pr.z > 4) {
        if (sp.path === 'boomerang' && !pr.returning) continue;
        pr.dead = true;
      }
    }
    for (let i = this.projectiles.length - 1; i >= 0; i--) {
      if (this.projectiles[i].dead) {
        this.root.remove(this.projectiles[i].mesh);
        this.projectiles.splice(i, 1);
      }
    }
  }

  private projectileHit(pr: Projectile, z: ZombieEntity) {
    const sp = pr.spec;
    pr.hits.add(z.uid);
    const hadArmor = z.armor > 0 || z.shield > 0;
    const front = pr.vx > 0 && sp.path !== 'lob' && sp.pierce !== Infinity;
    const kind = pr.fire ? 'fire' : sp.look === 'snow' || sp.look === 'wmelon' ? 'ice' : sp.look === 'volt' || sp.look === 'plasma' ? 'volt' : sp.look === 'goo' ? 'poison' : 'pea';
    const blocked = front && z.shield > 0;
    this.damageZombie(z, pr.damage, { kind, front });
    if (!blocked) {
      this.applyStatus(z, {
        slow: sp.slow,
        freeze: sp.freeze,
        burn: pr.fire ? (sp.burn ?? 6) : undefined,
        poison: sp.poison,
        weaken: sp.weaken,
        knockback: sp.knockback,
        stun: sp.stun && (sp.stunChance === undefined || this.rng() < sp.stunChance) ? sp.stun : undefined,
      });
    }
    if (sp.splash) this.splash(pr, z);
    if (sp.chain) this.chainFrom(z, sp.chain, pr.damage * 0.6);
    if (sp.split) this.splitShards(pr.x, z.lane, pr.damage * 0.6, pr.y);
    if (sp.look === 'coconut') this.explosionFx(pr.x, pr.z, sp.splash ?? 0.8, '#ff8a2a');
    this.hitFx(pr, z);
    this.sfx(hadArmor ? (z.def.armorMetal || z.shield > 0 ? 'bucket' : 'cone') : pr.fire ? 'fire' : 'hit');
    if (sp.path === 'bounce' && pr.bounces < 3) {
      pr.bounces++;
      pr.hits.clear();
      pr.hits.add(z.uid);
      const lane = Math.round(pr.z + (LANES - 1) / 2);
      const dir = lane <= 0 ? 1 : lane >= LANES - 1 ? -1 : pr.bounceTo !== null && pr.bounceTo < pr.z - 0.01 ? -1 : pr.bounceTo !== null ? 1 : this.rng() < 0.5 ? -1 : 1;
      const speed = Math.hypot(pr.vx, pr.vz);
      pr.bounceTo = laneZ(lane + dir);
      pr.vz = dir * speed * 0.8;
      pr.vx = speed * 0.6;
      return;
    }
    const pierce = sp.pierce ?? 0;
    if (pr.hits.size > pierce && sp.path !== 'boomerang') pr.dead = true;
    if (sp.path === 'boomerang' && pr.hits.size > (sp.pierce ?? 3)) pr.dead = true;
  }

  private lobImpact(pr: Projectile) {
    pr.dead = true;
    const sp = pr.spec;
    const target = pr.target && pr.target.dying < 0 && Math.abs(pr.target.x - pr.x) < 0.8 ? pr.target : this.nearest(pr.x, pr.z, 0.6, false);
    if (target) {
      const blockedNothing = true;
      this.damageZombie(target, pr.damage, { kind: sp.look === 'wmelon' ? 'ice' : sp.look === 'pepper' || sp.look === 'bomb' ? 'fire' : 'pea' });
      if (blockedNothing)
        this.applyStatus(target, {
          slow: sp.slow,
          freeze: sp.freeze,
          burn: sp.burn,
          poison: sp.poison,
          weaken: sp.weaken,
          knockback: sp.knockback,
          stun: sp.stun && (sp.stunChance === undefined || this.rng() < sp.stunChance) ? sp.stun : undefined,
        });
      pr.hits.add(target.uid);
    }
    if (sp.splash) this.splash(pr, target ?? null);
    if (sp.split) this.splitShards(pr.x, Math.round(pr.z + (LANES - 1) / 2), pr.damage * 0.5, 0.4);
    this.hitFx(pr, target ?? null);
    this.sfx(sp.look === 'melon' || sp.look === 'wmelon' || sp.look === 'bomb' || sp.look === 'coconut' ? 'splat' : 'hit');
    if (sp.look === 'bomb' || sp.look === 'coconut') this.explosionFx(pr.x, pr.z, sp.splash ?? 0.6, '#ff8a2a');
  }

  /** Shards that ricochet into the nearest zombies in the lanes above and below. */
  private splitShards(x: number, lane: number, damage: number, y: number) {
    for (const dl of [-1, 1]) {
      const l = lane + dl;
      if (l < 0 || l >= LANES) continue;
      const t2 = this.firstInLane(l, x - 1.5, 3);
      if (t2) {
        this.damageZombie(t2, damage, { kind: 'pea' });
        this.fx.beam(new THREE.Vector3(x, y, laneZ(lane)), new THREE.Vector3(t2.x, 0.6, t2.zPos), '#ff8aa8', 0.05, 0.25);
      }
    }
  }

  private splash(pr: Projectile, center: ZombieEntity | null) {
    const sp = pr.spec;
    const r = sp.splash ?? 0;
    const frac = sp.splashFrac ?? 0.33;
    for (const z of this.zombies) {
      if (z === center || z.dying >= 0 || z.hypno || this.isFlying(z)) continue;
      if (Math.hypot(z.x - pr.x, z.zPos - pr.z) <= r + 0.3) {
        this.damageZombie(z, pr.damage * frac, { kind: pr.fire ? 'fire' : 'pea' });
        if (sp.slow) this.applyStatus(z, { slow: sp.slow });
        if (pr.fire || sp.burn) this.applyStatus(z, { burn: (sp.burn ?? 6) * 0.5 });
      }
    }
  }

  /** Electric arc from a zombie to up to `n` more nearby zombies. */
  chainFrom(z: ZombieEntity, n: number, damage: number) {
    let cur = z;
    const hit = new Set<number>([z.uid]);
    for (let i = 0; i < n; i++) {
      const next = this.nearest(cur.x, cur.zPos, 2.2, true, (c) => !hit.has(c.uid));
      if (!next) break;
      hit.add(next.uid);
      this.fx.lightning(new THREE.Vector3(cur.x, 0.8, cur.zPos), new THREE.Vector3(next.x, 0.8, next.zPos), '#d9b8ff');
      this.damageZombie(next, damage, { kind: 'volt' });
      cur = next;
    }
  }

  private hitFx(pr: Projectile, z: ZombieEntity | null) {
    const at = z ? new THREE.Vector3(z.x - 0.1, pr.y, z.zPos) : pr.mesh.position.clone();
    const colors: Record<string, string[]> = {
      snow: ['#bff0ff', '#ffffff', '#7fd4ff'],
      wmelon: ['#bff0ff', '#ffffff', '#7fd4ff', '#5fae3a'],
      fire: ['#ff7a1f', '#ffe36a', '#ff3a1f'],
      goo: ['#a6ff3a', '#5fbf1f'],
      shadow: ['#b04fff', '#3a1a5a'],
      volt: ['#e8d0ff', '#b98cff'],
      plasma: ['#ffe36a', '#b8ff6a'],
      melon: ['#ff5a6a', '#5fae3a', '#2a7a27'],
      butter: ['#ffe36a', '#fff6b0'],
      kernel: ['#ffe36a', '#ffcf33'],
      cabbage: ['#8fcf3a', '#c8f07a'],
      bomb: ['#ff5a2a', '#ffb02a'],
      rock: ['#9a8a7a', '#6a5a4a'],
    };
    const look = pr.fire ? 'fire' : pr.spec.look;
    this.particles.burst(at, { count: pr.spec.splash ? 14 : 7, colors: colors[look] ?? ['#7ae86a', '#3fbf3a', '#c8ffb0'], speed: 1.6 + (pr.spec.splash ?? 0) * 2, up: 0.6, size: 0.04, life: 0.35 });
    if (pr.fire) this.fx.glowBurst(at, '#ff8a2a', 0.4);
  }

  // ================================================================ zombies

  private dropPart(z: ZombieEntity, which: 'armor' | 'shield' | 'balloon') {
    const part = which === 'armor' ? z.model.armor : which === 'shield' ? z.model.shield : z.model.balloon;
    if (!part || !part.parent) return;
    part.updateWorldMatrix(true, false);
    const pos = new THREE.Vector3();
    part.getWorldPosition(pos);
    this.root.attach(part);
    if (which === 'balloon') {
      this.debris.push({ obj: part, vel: new THREE.Vector3(0, 3, 0), spin: new THREE.Vector3(0, 2, 0), life: 1 });
      return;
    }
    this.debris.push({ obj: part, vel: new THREE.Vector3(1.2 + this.rng(), 2.5, (this.rng() - 0.5) * 1.5), spin: new THREE.Vector3(this.rng() * 6, 0, -6), life: 1.6 });
  }

  private killZombie(z: ZombieEntity, charred: boolean, quiet = false) {
    if (z.dying >= 0) return;
    z.dying = 0;
    z.charred = charred;
    z.eating = null;
    this.stats.killed++;
    this.lastDeathPos.set(z.x, 0, z.zPos);
    if (quiet) {
      z.model.root.visible = false;
    } else if (charred) {
      z.model.inst.material.color.set('#3a3a3a');
      if (z.model.armor) z.model.armor.visible = false;
      if (z.model.shield) z.model.shield.visible = false;
    } else {
      // Pop the head off for comic effect.
      const headPos = new THREE.Vector3();
      z.model.head.getWorldPosition(headPos);
      z.model.head.scale.setScalar(0.001);
      const debris = z.model.makeHeadDebris();
      debris.position.copy(headPos);
      debris.scale.setScalar(z.def.scale * (z.shrunk ? 0.6 : 1));
      this.root.add(debris);
      this.debris.push({ obj: debris, vel: new THREE.Vector3(0.8, 2.2, 0.3), spin: new THREE.Vector3(0, 3, -8), life: 1.6 });
      if (z.model.armor) {
        this.dropPart(z, 'armor');
      }
    }
    if (z.hypno) return;
    const at = new THREE.Vector3(z.x, 0.3, z.zPos);
    if (z.hasPlantFood) this.spawnPickup('plantfood', 1, at.clone().setY(0.8), false);
    const r = this.rng();
    if (r < 0.12) this.spawnPickup('coin', r < 0.03 ? 50 : 10, at.clone().setY(0.8), false);
    if (z.def.dropsSun) this.spawnPickup('sun', z.def.dropsSun, at.clone().setY(0.8), false);
  }

  /** What a zombie at `z` would bite right now, if anything. */
  private biteTarget(z: ZombieEntity): PlantEntity | ZombieEntity | null {
    const reach = 0.42 * z.def.scale * (z.shrunk ? 0.6 : 1);
    if (z.hypno) {
      let best: ZombieEntity | null = null;
      for (const o of this.zombies) {
        if (o === z || o.dying >= 0 || o.hypno || o.lane !== z.lane || this.isFlying(o)) continue;
        const d = o.x - z.x;
        if (d >= -0.1 && d < reach + 0.2 && (!best || o.x < best.x)) best = o;
      }
      return best;
    }
    // Hypnotized allies block enemies.
    for (const o of this.zombies) {
      if (o.hypno && o.dying < 0 && o.lane === z.lane) {
        const d = z.x - o.x;
        if (d >= -0.1 && d < reach + 0.2) return o;
      }
    }
    if (this.concealT > 0) return null;
    let target: PlantEntity | null = null;
    for (const p of this.plants) {
      if (p.dead || p.lane !== z.lane) continue;
      if (p.def.untargetable) continue;
      if (p.def.behavior.type === 'mine' && p.armed && p.def.behavior.trigger === 'contact') continue;
      const d = z.x - p.x;
      if (d >= -0.1 && d < reach && (!target || p.x > target.x || (p.x === target.x && p.overlay))) target = p;
    }
    return target;
  }

  private updateZombie(z: ZombieEntity, dt: number) {
    if (z.dying >= 0) {
      z.dying += dt;
      this.animateZombie(z, dt);
      return;
    }
    if (z.slow > 0) z.slow -= dt;
    if (z.freeze > 0) z.freeze -= dt;
    if (z.stun > 0) z.stun -= dt;
    if (z.weakenT > 0) z.weakenT -= dt;
    if (z.knockV > 0) z.knockV -= dt;
    if (z.burnT > 0) {
      z.burnT -= dt;
      this.damageZombie(z, z.burnDps * dt, { kind: 'fire', silent: true, ignoreArmor: false });
      if (this.rng() < dt * 8) this.particles.burst(new THREE.Vector3(z.x, 0.9, z.zPos), { count: 1, colors: ['#ff7a1f', '#ffe36a'], speed: 0.4, up: 1.5, gravity: -1, life: 0.4 });
      if (z.dying >= 0) return;
    }
    if (z.poisonT > 0) {
      z.poisonT -= dt;
      this.damageZombie(z, z.poisonDps * dt, { kind: 'poison', silent: true, ignoreArmor: true });
      if (this.rng() < dt * 6) this.particles.burst(new THREE.Vector3(z.x, 1, z.zPos), { count: 1, colors: ['#a6ff3a', '#5fbf1f'], speed: 0.3, up: 0.8, gravity: -0.5, life: 0.5 });
      if (z.dying >= 0) return;
    }
    // Lane switching animation.
    const targetZ = laneZ(z.lane);
    z.zPos += (targetZ - z.zPos) * Math.min(1, dt * 4);
    z.model.root.position.z = z.zPos;

    const disabled = z.freeze > 0 || z.stun > 0;
    const speedMult = disabled ? 0 : (z.slow > 0 ? 0.5 : 1) * (z.raged ? 2 : 1);
    const dir = z.hypno ? 1 : -1;

    // Vaulting animation in progress.
    if (z.vaultT >= 0) {
      z.vaultT += dt * (disabled ? 0 : 1);
      z.x += dir * 1.4 * dt * (disabled ? 0 : 1);
      if (z.vaultT >= 0.8) {
        z.vaultT = -1;
        z.vaulted = true;
      }
      z.model.root.position.x = z.x;
      this.animateZombie(z, dt);
      return;
    }

    const flying = this.isFlying(z);
    const target = flying ? null : this.biteTarget(z);
    z.eating = target;
    if (target) {
      const isPlant = 'def' in target && 'col' in target;
      if (isPlant && !z.vaulted && z.def.vault && !z.hypno) {
        const p = target as PlantEntity;
        const tall = p.def.behavior.type === 'wall' && p.def.behavior.tall;
        if (tall) {
          z.vaulted = true;
          this.particles.burst(new THREE.Vector3(z.x, 1, z.zPos), { count: 8, colors: ['#8a5a2b', '#ffffff'], speed: 1.5 });
          this.sfx('bucket');
        } else {
          z.vaultT = 0;
          z.eating = null;
          this.sfx('pop');
          this.animateZombie(z, dt);
          return;
        }
      }
      if (isPlant && z.def.smash) {
        const p = target as PlantEntity;
        z.smashTimer += dt * speedMult;
        if (z.smashTimer > 1.1) {
          z.smashTimer = 0;
          this.sfx('smash');
          this.shake(0.15);
          this.particles.burst(new THREE.Vector3(p.x, 0.1, p.z), { count: 20, colors: ['#7a5230', '#5a3d20', '#3c9d3a'], speed: 2.5 });
          const proof = p.def.behavior.type === 'wall' && p.def.behavior.smashProof;
          if (!this.rules.invincible) {
            if (proof) this.hurtPlant(p, 1500, z);
            else {
              p.hp = 0;
              p.shell = 0;
            }
          }
        }
      } else {
        const dmg = z.def.eatDps * dt * speedMult * (z.raged ? 1 : 1) * (z.shrunk ? 0.5 : 1);
        if (isPlant) this.hurtPlant(target as PlantEntity, dmg, z);
        else this.damageZombie(target as ZombieEntity, dmg, { kind: 'melee', silent: true });
        z.chompTimer -= dt * speedMult;
        if (z.chompTimer <= 0) {
          z.chompTimer = 0.55;
          this.sfx('chomp');
        }
      }
    } else {
      z.smashTimer = 0;
      const vaultBoost = z.def.vault && !z.vaulted ? 2 : 1;
      if (z.knockV <= 0) z.x += dir * z.def.speed * speedMult * vaultBoost * (z.shrunk ? 1.2 : 1) * dt;
    }
    z.model.root.position.x = z.x;

    if (!z.hypno) {
      if (z.x < MOWER_TRIGGER_X && !flying) {
        const mower = this.mowers[z.lane];
        if (!mower.active && !mower.gone) {
          mower.active = true;
          this.sfx('mower');
        }
      }
      if (z.x < HOUSE_X) {
        if (this.rules.invincible) {
          this.particles.ring(new THREE.Vector3(z.x, 0.6, z.zPos), '#7fd4ff', 1.5, 0.5);
          this.sfx('explode');
          this.killZombie(z, true);
        } else {
          this.finish('lost');
        }
      }
    }
    this.animateZombie(z, dt);
  }

  /** Damage a plant (respects invincibility, shells, thorns and on-bite reactions). */
  hurtPlant(p: PlantEntity, dmg: number, by: ZombieEntity | null) {
    if (p.dead) return;
    if (by) onPlantEaten(this, p, by, dmg);
    if (p.dead) return;
    if (this.rules.invincible) return;
    p.hitFlash = 0.1;
    if (p.shell > 0) p.shell = Math.max(0, p.shell - dmg);
    else p.hp -= dmg;
  }

  animateZombie(z: ZombieEntity, dt: number) {
    const m = z.model;
    const speedMult = z.freeze > 0 || z.stun > 0 ? 0 : z.slow > 0 ? 0.5 : 1;
    const baseScale = z.def.scale * (z.shrunk ? 0.6 : 1);
    m.root.scale.setScalar(THREE.MathUtils.lerp(m.root.scale.x, baseScale, Math.min(1, dt * 5)));
    if (z.dying >= 0) {
      const t = Math.min(1, z.dying / 0.7);
      if (z.knockV > 1) {
        // blown away
        m.root.position.x += dt * 6;
        m.root.position.y += dt * 3;
        m.root.rotation.z += dt * 6;
        return;
      }
      m.body.rotation.z = THREE.MathUtils.lerp(m.body.rotation.z, z.charred ? 0 : 1.45, t);
      if (z.charred) m.root.scale.y = Math.max(0.05, baseScale * (1 - Math.max(0, z.dying - 0.4) * 0.8));
      if (z.dying > 1.2) m.root.position.y = -(z.dying - 1.2) * 0.6;
      return;
    }
    z.animT += dt * speedMult;
    const t = z.animT;
    const flying = this.isFlying(z);
    m.root.position.y = flying ? 1.2 + Math.sin(t * 2) * 0.08 : z.vaultT >= 0 ? Math.sin((z.vaultT / 0.8) * Math.PI) * 1.1 : 0.03;
    // Keep the contact shadow on the ground while airborne.
    m.inst.blob.position.y = (0.035 - m.root.position.y) / Math.max(0.01, m.root.scale.y);
    if (flying) {
      m.legL.rotation.z = 0.2 + Math.sin(t * 3) * 0.2;
      m.legR.rotation.z = -0.1 - Math.sin(t * 3) * 0.2;
      m.armL.rotation.z = 2.6;
      m.armR.rotation.z = 1.2 + Math.sin(t * 2) * 0.1;
    } else if (z.eating) {
      m.head.rotation.z = Math.sin(t * 14) * 0.18 - 0.1;
      m.armL.rotation.z = 1.5 + Math.sin(t * 14) * 0.2;
      m.armR.rotation.z = 1.5 + Math.sin(t * 14 + 1.5) * 0.2;
      m.legL.rotation.z = 0;
      m.legR.rotation.z = 0;
      if (z.def.smash) m.armL.rotation.z = 0.3 + Math.min(1, z.smashTimer) * 2.5;
    } else {
      const k = (z.def.id === 'flag' || z.def.id === 'imp' ? 5.5 : 4) * (z.raged ? 1.8 : 1) * (z.def.vault && !z.vaulted ? 1.6 : 1);
      m.legL.rotation.z = Math.sin(t * k) * 0.45;
      m.legR.rotation.z = -Math.sin(t * k) * 0.45;
      m.armL.rotation.z = 1.25 + Math.sin(t * k) * 0.12;
      m.armR.rotation.z = 1.25 - Math.sin(t * k) * 0.12;
      m.body.position.y = Math.abs(Math.cos(t * k)) * 0.03;
      m.body.rotation.x = Math.sin(t * k) * 0.05;
      m.head.rotation.z = Math.sin(t * 2) * 0.1;
    }
    // Hit flash / chill tint / plant food glow.
    z.flash = Math.max(0, z.flash - dt);
    const mat = m.inst.material;
    const pfGlow = z.hasPlantFood ? 0.25 + Math.sin(this.time * 6) * 0.15 : 0;
    if (z.hypno) mat.color.set('#f0c8ff');
    else if (z.freeze > 0) mat.color.set('#a8e4ff');
    else if (z.stun > 0) mat.color.set('#fff2a0');
    else if (z.slow > 0) mat.color.set('#a8d4ff');
    else if (z.poisonT > 0) mat.color.set('#c8ff9a');
    else if (z.burnT > 0) mat.color.set('#ffb08a');
    else if (z.weakenT > 0) mat.color.set('#d8b8ff');
    else mat.color.set('#ffffff');
    if (z.flash > 0) mat.emissive.setRGB(0.3, 0.3, 0.3);
    else if (pfGlow > 0) mat.emissive.setRGB(0, pfGlow, 0);
    else mat.emissive.setRGB(0, 0, 0);
  }

  private updateMowers(dt: number) {
    for (const mw of this.mowers) {
      if (!mw.active || mw.gone) continue;
      mw.x += 6 * dt;
      mw.obj.position.x = mw.x;
      mw.obj.rotation.x = Math.sin(this.time * 40) * 0.04;
      for (const z of this.zombies) {
        if (z.dying < 0 && !z.hypno && z.lane === mw.lane && !this.isFlying(z) && Math.abs(z.x - mw.x) < 0.4) {
          this.damageZombie(z, 99999, { kind: 'mower' });
          this.particles.burst(new THREE.Vector3(z.x, 0.4, z.zPos), { count: 14, colors: ['#9bb88a', '#6b5a48', '#ffffff'], speed: 2.5 });
        }
      }
      if (this.rng() < dt * 30) this.particles.burst(new THREE.Vector3(mw.x - 0.2, 0.1, laneZ(mw.lane)), { count: 1, colors: ['#6fbf4a', '#9be06a'], speed: 1, life: 0.4 });
      if (mw.x > BOARD_RIGHT + 3) {
        mw.gone = true;
        this.root.remove(mw.obj);
      }
    }
  }

  private updateDebris(dt: number) {
    for (let i = this.debris.length - 1; i >= 0; i--) {
      const d = this.debris[i];
      d.life -= dt;
      d.vel.y -= 9 * dt;
      d.obj.position.addScaledVector(d.vel, dt);
      if (d.obj.position.y < 0.1) {
        d.obj.position.y = 0.1;
        d.vel.multiplyScalar(0.3);
        d.vel.y = Math.abs(d.vel.y);
        d.spin.multiplyScalar(0.5);
      }
      d.obj.rotation.x += d.spin.x * dt;
      d.obj.rotation.y += d.spin.y * dt;
      d.obj.rotation.z += d.spin.z * dt;
      if (d.life < 0.4) d.obj.scale.multiplyScalar(Math.max(0, 1 - dt * 6));
      if (d.life <= 0) {
        d.obj.removeFromParent();
        this.debris.splice(i, 1);
      }
    }
  }

  removePlant(p: PlantEntity) {
    if (p.dead) return;
    p.dead = true;
    if (p.overlay) {
      if (this.overlays[p.lane][p.col] === p) this.overlays[p.lane][p.col] = null;
    } else if (this.grid[p.lane][p.col] === p) this.grid[p.lane][p.col] = null;
    this.root.remove(p.model.root);
    disposeInstance(p.model.inst);
    for (const z of this.zombies) if (z.eating === p) z.eating = null;
  }

  /** Removes every zombie instantly (used for the pre-battle preview lineup). */
  clearZombies() {
    for (const z of this.zombies) {
      this.root.remove(z.model.root);
      disposeInstance(z.model.inst);
    }
    this.zombies.length = 0;
  }

  /** Idle animation for zombies standing still (preview lineup). */
  idleZombies(dt: number) {
    for (const z of this.zombies) {
      z.animT += dt;
      const m = z.model;
      m.head.rotation.z = Math.sin(z.animT * 1.5) * 0.15;
      m.armL.rotation.z = 1.2 + Math.sin(z.animT * 2) * 0.1;
      m.armR.rotation.z = 1.2 - Math.sin(z.animT * 2) * 0.1;
      m.body.rotation.x = Math.sin(z.animT) * 0.05;
      if (this.isFlying(z)) m.root.position.y = 1.2 + Math.sin(z.animT * 2) * 0.08;
    }
  }

  dispose() {
    this.root.removeFromParent();
    for (const z of this.zombies) disposeInstance(z.model.inst);
    for (const p of this.plants) disposeInstance(p.model.inst);
    this.particles.dispose();
    this.fx.dispose();
  }
}
