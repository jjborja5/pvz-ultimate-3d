// The battle simulation: plants, zombies, projectiles, sun, waves, plant food and win/lose rules.
// It owns Three.js objects for its entities but never touches the DOM or renderer, so it can be
// unit-tested headlessly. The view layer drains `events` each frame for sound, UI and camera FX.
import * as THREE from 'three';
import {
  COLS,
  LANES,
  PLANTS,
  ZOMBIES,
  levelMultipliers,
  type LevelDef,
  type PlantDef,
  type PlantId,
  type ZombieDef,
  type ZombieId,
} from './config';
import { BOARD_LEFT, BOARD_RIGHT, colX, laneZ } from './environment';
import {
  buildCoin,
  buildMower,
  buildPea,
  buildPlant,
  buildPlantFood,
  buildSun,
  buildTrophy,
  buildZombie,
  type PlantModel,
  type ZombieModel,
} from './models';
import { Particles } from './particles';
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
  | 'gulp';

export type BattleEvent =
  | { type: 'sfx'; name: SfxName }
  | { type: 'banner'; text: string; style: 'huge' | 'final' | 'info' }
  | { type: 'collect'; kind: PickupKind; value: number; world: THREE.Vector3 }
  | { type: 'shake'; amount: number }
  | { type: 'end'; result: 'won' | 'lost' };

export type PickupKind = 'sun' | 'plantfood' | 'coin' | 'trophy';

export interface PlantEntity {
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
  timer: number;
  pendingShots: number[];
  pfTime: number;
  armed: boolean;
  t: number;
  recoil: number;
  dead: boolean;
}

export interface ZombieEntity {
  uid: number;
  def: ZombieDef;
  lane: number;
  x: number;
  hp: number;
  armor: number;
  slow: number;
  freeze: number;
  eating: PlantEntity | null;
  dying: number;
  charred: boolean;
  model: ZombieModel;
  animT: number;
  flash: number;
  hasPlantFood: boolean;
  chompTimer: number;
  smashTimer: number;
}

interface Projectile {
  mesh: THREE.Mesh;
  lane: number;
  x: number;
  y: number;
  damage: number;
  snow: boolean;
  dead: boolean;
}

export interface Pickup {
  kind: PickupKind;
  value: number;
  obj: THREE.Group;
  pos: THREE.Vector3;
  vel: THREE.Vector3;
  groundY: number;
  landed: boolean;
  age: number;
  life: number;
  collected: boolean;
  /** Falls slowly from the sky instead of popping out. */
  sky: boolean;
}

interface Mower {
  lane: number;
  obj: THREE.Group;
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

export interface BattleOptions {
  autoCollectSun?: boolean;
  rng?: () => number;
}

const PEA_SPEED = 6.5;
const SKY_SUN_INTERVAL = 9;
const MOWER_TRIGGER_X = BOARD_LEFT + 0.05;
const HOUSE_X = BOARD_LEFT - 0.95;

export class Battle {
  readonly root = new THREE.Group();
  readonly particles: Particles;
  readonly events: BattleEvent[] = [];

  phase: 'ready' | 'playing' | 'won' | 'lost' = 'ready';
  sun: number;
  plantFood: number;
  readonly cooldown = new Map<PlantId, number>();
  readonly cooldownMax = new Map<PlantId, number>();
  readonly grid: (PlantEntity | null)[][];
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

  stats = { killed: 0, planted: 0, sunCollected: 0, coins: 0, plantFoodUsed: 0 };

  private rng: () => number;
  autoCollect: boolean;

  constructor(
    scene: THREE.Object3D,
    readonly level: LevelDef,
    readonly loadout: PlantId[],
    public rules: Rules,
    opts: BattleOptions = {},
  ) {
    this.rng = opts.rng ?? Math.random;
    this.autoCollect = !!opts.autoCollectSun;
    scene.add(this.root);
    this.particles = new Particles(this.root);
    this.sun = level.startSun;
    this.plantFood = 1;
    this.waveTimer = level.firstWaveDelay;
    this.grid = Array.from({ length: LANES }, () => Array<PlantEntity | null>(COLS).fill(null));
    for (const id of loadout) {
      const def = PLANTS[id];
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

  /** 0..1 level progress for the progress meter. */
  get progress() {
    const n = this.totalWaves;
    if (this.waveIndex >= n) return 1;
    return Math.min(1, this.waveIndex / n);
  }

  get aliveZombies() {
    return this.zombies.filter((z) => z.dying < 0);
  }

  start() {
    if (this.phase === 'ready') this.phase = 'playing';
  }

  // ---------------- player actions ----------------

  canPlant(id: PlantId): { ok: boolean; reason?: string } {
    if (this.phase !== 'playing') return { ok: false, reason: 'Not now' };
    if ((this.cooldown.get(id) ?? 0) > 0) return { ok: false, reason: 'Recharging' };
    if (!this.rules.unlimitedSun && this.sun < PLANTS[id].cost) return { ok: false, reason: 'Not enough sun' };
    return { ok: true };
  }

  plantAt(id: PlantId, col: number, lane: number): boolean {
    if (col < 0 || col >= COLS || lane < 0 || lane >= LANES) return false;
    if (this.grid[lane][col]) {
      this.events.push({ type: 'sfx', name: 'error' });
      return false;
    }
    if (!this.canPlant(id).ok) {
      this.events.push({ type: 'sfx', name: 'error' });
      return false;
    }
    const def = PLANTS[id];
    if (!this.rules.unlimitedSun) this.sun -= def.cost;
    this.cooldown.set(id, this.rules.instantRecharge ? 0 : this.cooldownMax.get(id) ?? def.recharge);
    this.spawnPlant(id, col, lane);
    this.stats.planted++;
    this.events.push({ type: 'sfx', name: 'place' });
    return true;
  }

  spawnPlant(id: PlantId, col: number, lane: number): PlantEntity {
    const def = PLANTS[id];
    const level = this.rules.plantLevel(id);
    const mult = levelMultipliers(level);
    const model = buildPlant(id);
    const x = colX(col);
    const z = laneZ(lane);
    model.root.position.set(x, 0.03, z);
    this.root.add(model.root);
    const hp = def.kind === 'instant' ? def.hp : def.hp * mult.hp;
    const p: PlantEntity = {
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
      timer: def.kind === 'producer' ? 5 + this.rng() * 3 : def.kind === 'instant' ? def.fuse ?? 1 : def.kind === 'mine' ? (def.armTime ?? 12) * mult.armTime : 0.4,
      pendingShots: [],
      pfTime: 0,
      armed: false,
      t: this.rng() * 10,
      recoil: 0,
      dead: false,
    };
    if (def.kind === 'mine') model.head.position.y = -0.14;
    this.grid[lane][col] = p;
    this.plants.push(p);
    this.particles.burst(new THREE.Vector3(x, 0.1, z), { count: 14, colors: ['#7a5230', '#8f6a3d', '#5a3d20'], speed: 1.6, up: 1.4, size: 0.05 });
    return p;
  }

  plantAtTile(col: number, lane: number): PlantEntity | null {
    if (col < 0 || col >= COLS || lane < 0 || lane >= LANES) return null;
    return this.grid[lane][col];
  }

  shovel(col: number, lane: number): boolean {
    const p = this.plantAtTile(col, lane);
    if (!p || this.phase !== 'playing') return false;
    this.removePlant(p);
    this.events.push({ type: 'sfx', name: 'shovel' });
    this.particles.burst(new THREE.Vector3(p.x, 0.2, p.z), { count: 12, colors: ['#7a5230', '#6fbf4a'], speed: 1.5 });
    return true;
  }

  usePlantFood(col: number, lane: number): boolean {
    const p = this.plantAtTile(col, lane);
    if (!p || this.phase !== 'playing') return false;
    if (!this.rules.unlimitedPlantFood && this.plantFood <= 0) return false;
    if (p.def.kind === 'instant') return false;
    if (!this.rules.unlimitedPlantFood) this.plantFood--;
    this.stats.plantFoodUsed++;
    this.events.push({ type: 'sfx', name: 'pfuse' });
    const at = new THREE.Vector3(p.x, 0.5, p.z);
    this.particles.ring(at, '#5dff6a', 1.6, 0.6);
    this.particles.burst(at, { count: 30, colors: ['#5dff6a', '#b8ffb0', '#ffffff'], speed: 2.5, up: 2, gravity: 2 });
    switch (p.def.kind) {
      case 'shooter':
        p.pfTime = 3;
        if (p.def.slow) {
          for (const z of this.zombies) if (z.lane === p.lane && z.dying < 0 && z.x > p.x - 0.5) z.freeze = 5;
          this.events.push({ type: 'sfx', name: 'freeze' });
        }
        break;
      case 'producer':
        for (let i = 0; i < 3; i++) this.spawnSunFromPlant(p, i);
        p.pfTime = 1;
        break;
      case 'wall':
        p.hp = p.maxHp;
        p.shell = p.maxHp;
        p.pfTime = 1;
        break;
      case 'mine':
        p.timer = 0;
        p.pfTime = 1;
        break;
    }
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
        this.events.push({ type: 'sfx', name: 'sun' });
        break;
      case 'plantfood':
        if (!this.rules.unlimitedPlantFood) this.plantFood = Math.min(this.rules.plantFoodMax, this.plantFood + 1);
        this.events.push({ type: 'sfx', name: 'plantfood' });
        break;
      case 'coin':
        this.stats.coins += pk.value;
        this.events.push({ type: 'sfx', name: 'coin' });
        break;
      case 'trophy':
        this.finish('won');
        break;
    }
  }

  // ---------------- simulation ----------------

  update(dt: number) {
    this.time += dt;
    this.particles.update(dt);
    this.updateDebris(dt);
    this.updatePickups(dt);
    if (this.phase === 'ready') {
      for (const p of this.plants) this.animatePlant(p, dt);
      return;
    }
    if (this.phase !== 'playing') {
      for (const z of this.zombies) this.animateZombie(z, dt);
      return;
    }

    for (const [id, cd] of this.cooldown) if (cd > 0) this.cooldown.set(id, this.rules.instantRecharge ? 0 : Math.max(0, cd - dt));

    this.updateWaves(dt);
    this.updateSky(dt);
    for (const p of this.plants) this.updatePlant(p, dt);
    for (let i = this.plants.length - 1; i >= 0; i--) if (this.plants[i].dead) this.plants.splice(i, 1);
    this.updateProjectiles(dt);
    for (const z of this.zombies) this.updateZombie(z, dt);
    for (let i = this.zombies.length - 1; i >= 0; i--) {
      const z = this.zombies[i];
      if (z.dying > 2.2) {
        this.root.remove(z.model.root);
        for (const m of z.model.mats) m.dispose();
        this.zombies.splice(i, 1);
      }
    }
    this.updateMowers(dt);

    this.groanTimer -= dt;
    if (this.groanTimer <= 0) {
      this.groanTimer = 5 + this.rng() * 6;
      if (this.aliveZombies.length) this.events.push({ type: 'sfx', name: 'groan' });
    }

    if (!this.trophySpawned && this.waveIndex >= this.totalWaves && this.aliveZombies.length === 0) {
      this.trophySpawned = true;
      const pos = this.lastDeathPos.clone();
      pos.x = Math.min(Math.max(pos.x, BOARD_LEFT + 1), BOARD_RIGHT - 0.5);
      this.spawnPickup('trophy', 0, pos, false);
      this.events.push({ type: 'banner', text: 'Level Cleared! Tap the trophy!', style: 'info' });
    }
  }

  private finish(result: 'won' | 'lost') {
    if (this.phase !== 'playing') return;
    this.phase = result;
    this.events.push({ type: 'sfx', name: result === 'won' ? 'win' : 'lose' });
    this.events.push({ type: 'end', result });
  }

  private updateWaves(dt: number) {
    if (this.waveIndex >= this.totalWaves) return;
    this.waveTimer -= dt;
    const next = this.level.waves[this.waveIndex];
    // Speed up when the previous wave is mostly defeated.
    if (this.waveIndex > 0 && this.waveTimer > 5) {
      const alive = this.aliveZombies.reduce((s, z) => s + z.hp + z.armor, 0);
      if (alive <= this.lastWaveHp * 0.3) this.waveTimer = 5;
    }
    if (this.waveTimer > 0) return;
    if (next.flag && !this.hugeWarned) {
      this.hugeWarned = true;
      this.waveTimer = 3.5;
      this.events.push({ type: 'banner', text: 'A Huge Wave of Zombies is Approaching!', style: 'huge' });
      this.events.push({ type: 'sfx', name: 'siren' });
      return;
    }
    this.hugeWarned = false;
    this.spawnWave(this.waveIndex);
    this.waveIndex++;
    if (this.waveIndex === this.totalWaves) this.events.push({ type: 'banner', text: 'FINAL WAVE!', style: 'final' });
    const following = this.level.waves[this.waveIndex];
    this.waveTimer = following?.flag ? 30 : 25;
  }

  private spawnWave(i: number) {
    const wave = this.level.waves[i];
    const pfCarrier = i % 3 === 1 || wave.flag ? Math.floor(this.rng() * wave.zombies.length) : -1;
    let hp = 0;
    const ids = [...wave.zombies];
    // Flag zombie leads the pack.
    ids.sort((a, b) => (a === 'flag' ? -1 : b === 'flag' ? 1 : 0));
    let lastLane = -1;
    ids.forEach((id, k) => {
      let lane = Math.floor(this.rng() * LANES);
      if (lane === lastLane) lane = (lane + 1 + Math.floor(this.rng() * (LANES - 1))) % LANES;
      lastLane = lane;
      const z = this.spawnZombie(id, lane, BOARD_RIGHT + 0.8 + k * 0.45 + this.rng() * 0.6);
      if (k === pfCarrier) z.hasPlantFood = true;
      hp += z.hp + z.armor;
    });
    this.lastWaveHp = Math.max(1, hp);
  }

  spawnZombie(id: ZombieId, lane: number, x: number): ZombieEntity {
    const def = ZOMBIES[id];
    const model = buildZombie(def);
    model.root.position.set(x, 0.03, laneZ(lane) + (this.rng() - 0.5) * 0.12);
    this.root.add(model.root);
    const z: ZombieEntity = {
      uid: ++this.uid,
      def,
      lane,
      x,
      hp: def.hp,
      armor: def.armor,
      slow: 0,
      freeze: 0,
      eating: null,
      dying: -1,
      charred: false,
      model,
      animT: this.rng() * 10,
      flash: 0,
      hasPlantFood: false,
      chompTimer: 0,
      smashTimer: 0,
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

  private spawnSunFromPlant(p: PlantEntity, i = 0) {
    const value = Math.round(((p.def.sunAmount ?? 50) * p.mult.sun) / 5) * 5;
    const pos = new THREE.Vector3(p.x, 0.8, p.z);
    const pk = this.spawnPickup('sun', value, pos, false);
    pk.vel.set(0.4 + this.rng() * 0.6 + i * 0.2, 2.6 + this.rng(), 0.3 + (this.rng() - 0.5) * 0.6);
  }

  spawnPickup(kind: PickupKind, value: number, pos: THREE.Vector3, sky: boolean): Pickup {
    const obj =
      kind === 'sun' ? buildSun() : kind === 'plantfood' ? buildPlantFood() : kind === 'coin' ? buildCoin(value >= 50) : buildTrophy();
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
      if (pk.kind === 'trophy') pk.obj.rotation.y += dt;
    }
  }

  // ---------------- plants ----------------

  private zombieAhead(p: PlantEntity): boolean {
    for (const z of this.zombies) {
      if (z.dying < 0 && z.lane === p.lane && z.x >= p.x - 0.2 && z.x <= BOARD_RIGHT + 0.5) return true;
    }
    return false;
  }

  private fire(p: PlantEntity) {
    const snow = !!p.def.slow;
    const mesh = buildPea(snow ? 'snow' : 'pea');
    const y = 0.55;
    mesh.position.set(p.x + 0.35, y, p.z);
    this.root.add(mesh);
    this.projectiles.push({ mesh, lane: p.lane, x: p.x + 0.35, y, damage: (p.def.damage ?? 20) * p.mult.damage, snow, dead: false });
    p.recoil = 1;
    this.events.push({ type: 'sfx', name: 'shoot' });
  }

  private updatePlant(p: PlantEntity, dt: number) {
    if (p.dead) return;
    p.t += dt;
    if (p.pfTime > 0) p.pfTime -= dt;
    switch (p.def.kind) {
      case 'shooter': {
        for (let i = p.pendingShots.length - 1; i >= 0; i--) {
          p.pendingShots[i] -= dt;
          if (p.pendingShots[i] <= 0) {
            p.pendingShots.splice(i, 1);
            this.fire(p);
          }
        }
        p.timer -= dt;
        if (p.pfTime > 0) {
          if (p.timer <= 0) {
            p.timer = 0.07;
            this.fire(p);
            if ((p.def.shots ?? 1) > 1) p.pendingShots.push(0.035);
          }
        } else if (p.timer <= 0 && this.zombieAhead(p)) {
          p.timer = p.def.fireInterval ?? 1.4;
          this.fire(p);
          for (let s = 1; s < (p.def.shots ?? 1); s++) p.pendingShots.push(0.18 * s);
        }
        break;
      }
      case 'producer':
        p.timer -= dt;
        if (p.timer <= 0) {
          p.timer = p.def.sunInterval ?? 24;
          this.spawnSunFromPlant(p);
        }
        break;
      case 'wall': {
        const r = p.hp / p.maxHp;
        p.model.parts.crack1.visible = r < 0.66;
        p.model.parts.crack2.visible = r < 0.33;
        p.model.parts.shell.visible = p.shell > 0;
        break;
      }
      case 'instant':
        p.timer -= dt;
        if (p.timer <= 0) {
          this.explode(p.x, p.lane, (p.def.blastRadius ?? 1.5) * 1, (p.def.blastDamage ?? 1800) * p.mult.damage, 1, '#ff5a2a');
          this.removePlant(p);
        }
        break;
      case 'mine':
        if (!p.armed) {
          p.timer -= dt;
          if (p.timer <= 0) {
            p.armed = true;
            this.events.push({ type: 'sfx', name: 'arm' });
            this.particles.burst(new THREE.Vector3(p.x, 0.15, p.z), { count: 10, colors: ['#7a5230', '#8f6a3d'], speed: 1.3 });
          }
        } else {
          for (const z of this.zombies) {
            if (z.dying < 0 && z.lane === p.lane && Math.abs(z.x - p.x) < 0.45) {
              this.explode(p.x, p.lane, p.def.blastRadius ?? 0.6, (p.def.blastDamage ?? 1800) * p.mult.damage, 0, '#ffb02a');
              this.removePlant(p);
              break;
            }
          }
        }
        break;
    }
    if (p.hp <= 0 && !p.dead) {
      this.particles.burst(new THREE.Vector3(p.x, 0.3, p.z), { count: 16, colors: ['#3c9d3a', '#63d35a', '#7a5230'], speed: 1.8 });
      this.events.push({ type: 'sfx', name: 'gulp' });
      this.removePlant(p);
    }
    this.animatePlant(p, dt);
  }

  private animatePlant(p: PlantEntity, dt: number) {
    const m = p.model;
    p.recoil = Math.max(0, p.recoil - dt * 6);
    const sway = Math.sin(p.t * 2.2) * 0.05;
    m.body.rotation.z = sway;
    const s = 1 + Math.sin(p.t * 2.2 + 1) * 0.02;
    m.body.scale.set(1, s, 1);
    if (p.def.kind === 'shooter') {
      m.head.position.x = -p.recoil * 0.06;
      m.head.scale.set(1 + p.recoil * 0.15, 1 - p.recoil * 0.1, 1 + p.recoil * 0.1);
    } else if (p.def.kind === 'instant') {
      const f = 1 - Math.max(0, p.timer) / (p.def.fuse ?? 1);
      m.root.scale.setScalar(1 + f * 0.45 + Math.sin(p.t * 40) * 0.04 * f);
    } else if (p.def.kind === 'mine') {
      m.head.position.y = THREE.MathUtils.lerp(m.head.position.y, p.armed ? 0 : -0.14, Math.min(1, dt * 4));
      m.parts.light.visible = !p.armed || Math.floor(p.t * 3) % 2 === 0;
    } else if (p.def.kind === 'producer') {
      m.head.rotation.z = Math.sin(p.t * 1.6) * 0.08;
    }
    if (p.pfTime > 0) {
      const pulse = 1 + Math.sin(p.t * 25) * 0.06;
      m.root.scale.setScalar(1.12 * pulse);
      if (Math.random() < dt * 20)
        this.particles.burst(new THREE.Vector3(p.x, 0.3 + Math.random() * 0.4, p.z), { count: 1, colors: ['#5dff6a', '#c8ffc0'], speed: 0.6, up: 1, gravity: 0, life: 0.5 });
    } else if (p.def.kind !== 'instant') {
      m.root.scale.setScalar(THREE.MathUtils.lerp(m.root.scale.x, 1, Math.min(1, dt * 6)));
    }
  }

  private removePlant(p: PlantEntity) {
    if (p.dead) return;
    p.dead = true;
    if (this.grid[p.lane][p.col] === p) this.grid[p.lane][p.col] = null;
    this.root.remove(p.model.root);
    for (const z of this.zombies) if (z.eating === p) z.eating = null;
  }

  private explode(x: number, lane: number, radius: number, damage: number, laneSpan: number, color: string) {
    const at = new THREE.Vector3(x, 0.4, laneZ(lane));
    for (const z of this.zombies) {
      if (z.dying >= 0) continue;
      if (Math.abs(z.lane - lane) <= laneSpan && Math.abs(z.x - x) <= radius) this.damageZombie(z, damage, 'blast');
    }
    this.particles.ring(at, color, 1.6 + radius, 0.5);
    this.particles.ring(at, '#fff2a0', 0.8 + radius * 0.6, 0.3);
    this.particles.burst(at, { count: 60, colors: ['#ff5a2a', '#ffb02a', '#ffe36a', '#ffffff'], speed: 5, up: 2.5, size: 0.08, life: 0.7 });
    this.particles.burst(at, { count: 25, colors: ['#555555', '#777777', '#3a3a3a'], speed: 1.5, up: 1.5, size: 0.14, life: 1.2, gravity: -0.5, grow: 2 });
    this.events.push({ type: 'sfx', name: 'explode' });
    this.events.push({ type: 'shake', amount: 0.25 });
  }

  // ---------------- projectiles ----------------

  private updateProjectiles(dt: number) {
    for (const pr of this.projectiles) {
      if (pr.dead) continue;
      pr.x += PEA_SPEED * dt;
      pr.mesh.position.x = pr.x;
      let target: ZombieEntity | null = null;
      for (const z of this.zombies) {
        if (z.dying >= 0 || z.lane !== pr.lane) continue;
        if (pr.x >= z.x - 0.18 * z.def.scale && pr.x <= z.x + 0.35 * z.def.scale) {
          if (!target || z.x < target.x) target = z;
        }
      }
      if (target) {
        const hadArmor = target.armor > 0;
        this.damageZombie(target, pr.damage, pr.snow ? 'snow' : 'pea');
        if (pr.snow) target.slow = 10;
        pr.dead = true;
        const at = pr.mesh.position;
        this.particles.burst(at, {
          count: 7,
          colors: pr.snow ? ['#bff0ff', '#ffffff', '#7fd4ff'] : ['#7ae86a', '#3fbf3a', '#c8ffb0'],
          speed: 1.6,
          up: 0.6,
          size: 0.035,
          life: 0.35,
        });
        this.events.push({ type: 'sfx', name: hadArmor ? (target.def.armorType === 'bucket' ? 'bucket' : 'cone') : 'hit' });
      } else if (pr.x > BOARD_RIGHT + 2.5) {
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

  // ---------------- zombies ----------------

  damageZombie(z: ZombieEntity, dmg: number, kind: 'pea' | 'snow' | 'blast' | 'mower') {
    if (z.dying >= 0) return;
    z.flash = 0.12;
    if (z.armor > 0 && kind !== 'mower') {
      z.armor -= dmg;
      if (z.armor <= 0) {
        z.hp += z.armor;
        z.armor = 0;
        this.dropArmor(z);
      }
    } else {
      z.hp -= dmg;
    }
    if (kind === 'mower') z.hp = 0;
    if (z.hp <= 0) this.killZombie(z, kind === 'blast');
  }

  private dropArmor(z: ZombieEntity) {
    const a = z.model.armor;
    if (!a || !a.parent) return;
    a.updateWorldMatrix(true, false);
    const pos = new THREE.Vector3();
    a.getWorldPosition(pos);
    this.root.attach(a);
    a.position.copy(pos);
    this.debris.push({
      obj: a,
      vel: new THREE.Vector3(1.2 + this.rng(), 2.5, (this.rng() - 0.5) * 1.5),
      spin: new THREE.Vector3(this.rng() * 6, 0, -6),
      life: 1.6,
    });
  }

  private killZombie(z: ZombieEntity, charred: boolean) {
    z.dying = 0;
    z.charred = charred;
    z.eating = null;
    this.stats.killed++;
    this.lastDeathPos.set(z.x, 0, laneZ(z.lane));
    if (charred) {
      for (const m of z.model.mats) m.color.set('#2a2a2a');
      if (z.model.armor) z.model.armor.visible = false;
    } else {
      // Pop the head off for comic effect.
      const head = z.model.head;
      head.updateWorldMatrix(true, false);
      const pos = new THREE.Vector3();
      head.getWorldPosition(pos);
      this.root.attach(head);
      head.position.copy(pos);
      this.debris.push({ obj: head, vel: new THREE.Vector3(0.8, 2.2, 0.3), spin: new THREE.Vector3(0, 3, -8), life: 1.6 });
    }
    const at = new THREE.Vector3(z.x, 0.3, laneZ(z.lane));
    if (z.hasPlantFood) this.spawnPickup('plantfood', 1, at.clone().setY(0.8), false);
    const r = this.rng();
    if (r < 0.12) this.spawnPickup('coin', r < 0.03 ? 50 : 10, at.clone().setY(0.8), false);
  }

  private updateZombie(z: ZombieEntity, dt: number) {
    if (z.dying >= 0) {
      z.dying += dt;
      this.animateZombie(z, dt);
      return;
    }
    if (z.slow > 0) z.slow -= dt;
    if (z.freeze > 0) z.freeze -= dt;
    const speedMult = z.freeze > 0 ? 0 : z.slow > 0 ? 0.5 : 1;

    // Find a plant to eat.
    const reach = 0.42 * z.def.scale;
    let target: PlantEntity | null = null;
    for (const p of this.plants) {
      if (p.dead || p.lane !== z.lane) continue;
      if (p.def.kind === 'mine' && p.armed) continue;
      if (p.def.kind === 'instant') continue;
      const d = z.x - p.x;
      if (d >= -0.1 && d < reach && (!target || p.x > target.x)) target = p;
    }
    z.eating = target;
    if (target) {
      if (z.def.smash) {
        z.smashTimer += dt * speedMult;
        if (z.smashTimer > 1.1) {
          z.smashTimer = 0;
          this.events.push({ type: 'sfx', name: 'smash' });
          this.events.push({ type: 'shake', amount: 0.15 });
          this.particles.burst(new THREE.Vector3(target.x, 0.1, target.z), { count: 20, colors: ['#7a5230', '#5a3d20', '#3c9d3a'], speed: 2.5 });
          if (!this.rules.invincible) {
            target.hp = 0;
            target.shell = 0;
          }
        }
      } else {
        const dmg = z.def.eatDps * dt * speedMult;
        if (!this.rules.invincible) {
          if (target.shell > 0) target.shell = Math.max(0, target.shell - dmg);
          else target.hp -= dmg;
        }
        z.chompTimer -= dt * speedMult;
        if (z.chompTimer <= 0) {
          z.chompTimer = 0.55;
          this.events.push({ type: 'sfx', name: 'chomp' });
        }
      }
    } else {
      z.smashTimer = 0;
      z.x -= z.def.speed * speedMult * dt;
    }
    z.model.root.position.x = z.x;

    // Lawn mower / house.
    if (z.x < MOWER_TRIGGER_X) {
      const mower = this.mowers[z.lane];
      if (!mower.active && !mower.gone) {
        mower.active = true;
        this.events.push({ type: 'sfx', name: 'mower' });
      }
    }
    if (z.x < HOUSE_X) {
      if (this.rules.invincible) {
        this.particles.ring(new THREE.Vector3(z.x, 0.6, laneZ(z.lane)), '#7fd4ff', 1.5, 0.5);
        this.events.push({ type: 'sfx', name: 'explode' });
        this.killZombie(z, true);
      } else {
        this.finish('lost');
      }
    }
    this.animateZombie(z, dt);
  }

  private animateZombie(z: ZombieEntity, dt: number) {
    const m = z.model;
    const speedMult = z.freeze > 0 ? 0 : z.slow > 0 ? 0.5 : 1;
    if (z.dying >= 0) {
      const t = Math.min(1, z.dying / 0.7);
      m.body.rotation.z = THREE.MathUtils.lerp(m.body.rotation.z, z.charred ? 0 : 1.45, t);
      if (z.charred) m.root.scale.y = Math.max(0.05, z.def.scale * (1 - Math.max(0, z.dying - 0.4) * 0.8));
      if (z.dying > 1.2) m.root.position.y = -(z.dying - 1.2) * 0.6;
      return;
    }
    z.animT += dt * speedMult;
    const t = z.animT;
    if (z.eating) {
      m.head.rotation.z = Math.sin(t * 14) * 0.18 - 0.1;
      m.armL.rotation.z = 1.5 + Math.sin(t * 14) * 0.2;
      m.armR.rotation.z = 1.5 + Math.sin(t * 14 + 1.5) * 0.2;
      m.legL.rotation.z = 0;
      m.legR.rotation.z = 0;
      if (z.def.smash) m.armL.rotation.z = 0.3 + Math.min(1, z.smashTimer) * 2.5;
    } else {
      const k = z.def.id === 'flag' ? 5.5 : 4;
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
    const pfGlow = z.hasPlantFood ? 0.25 + Math.sin(this.time * 6) * 0.15 : 0;
    for (let i = 0; i < m.mats.length; i++) {
      const mat = m.mats[i];
      if (z.freeze > 0) mat.color.set('#9fdcff');
      else if (z.slow > 0) mat.color.copy(m.baseColors[i]).lerp(new THREE.Color('#7fc8ff'), 0.55);
      else mat.color.copy(m.baseColors[i]);
      if (z.flash > 0) mat.emissive.setRGB(0.3, 0.3, 0.3);
      else if (pfGlow > 0) mat.emissive.setRGB(0, pfGlow, 0);
      else mat.emissive.setRGB(0, 0, 0);
    }
  }

  private updateMowers(dt: number) {
    for (const mw of this.mowers) {
      if (!mw.active || mw.gone) continue;
      mw.x += 6 * dt;
      mw.obj.position.x = mw.x;
      mw.obj.rotation.x = Math.sin(this.time * 40) * 0.04;
      for (const z of this.zombies) {
        if (z.dying < 0 && z.lane === mw.lane && Math.abs(z.x - mw.x) < 0.4) {
          this.damageZombie(z, 99999, 'mower');
          this.particles.burst(new THREE.Vector3(z.x, 0.4, laneZ(z.lane)), { count: 14, colors: ['#9bb88a', '#6b5a48', '#ffffff'], speed: 2.5 });
        }
      }
      if (Math.random() < dt * 30) this.particles.burst(new THREE.Vector3(mw.x - 0.2, 0.1, laneZ(mw.lane)), { count: 1, colors: ['#6fbf4a', '#9be06a'], speed: 1, life: 0.4 });
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

  /** Removes every zombie instantly (used for the pre-battle preview lineup). */
  clearZombies() {
    for (const z of this.zombies) {
      this.root.remove(z.model.root);
      for (const m of z.model.mats) m.dispose();
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
    }
  }

  dispose() {
    this.root.removeFromParent();
    for (const z of this.zombies) for (const m of z.model.mats) m.dispose();
    this.particles.dispose();
  }
}
