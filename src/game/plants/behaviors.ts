// Plant behavior interpreter: turns each PlantDef's behavior / Plant Food spec into actions.
import * as THREE from 'three';
import type { Battle, PlantEntity, ZombieEntity } from '../battle';
import { RIGHT_EDGE } from '../battle';
import { COLS, LANES } from '../config';
import { colX, laneZ } from '../environment';
import { PLANTS } from './roster';
import type { Behavior, ProjSpec } from './types';

const muzzle = (p: PlantEntity, lane = p.lane, dx = 0.35) => ({ x: p.x + dx, y: p.model.muzzleY, z: laneZ(lane) });

/** Speed multiplier for timers from buffs and Plant Food boosts. */
const tempo = (p: PlantEntity) => p.haste * (p.pfTime > 0 ? p.pfBoost : 1);

export function initPlant(b: Battle, p: PlantEntity) {
  const bh = p.def.behavior;
  switch (bh.type) {
    case 'produce':
      p.timer = 5 + b.rng() * 3;
      p.s.age = 0;
      p.s.amount = bh.amount;
      break;
    case 'instant':
      p.timer = bh.fuse;
      break;
    case 'mine':
      p.timer = bh.arm * p.mult.armTime;
      p.armed = bh.arm <= 0;
      if (!p.armed) p.model.body.position.y = -0.16;
      break;
    case 'wall':
      p.s.kb = bh.knockbacks ?? 0;
      p.timer = bh.shoot ? 0.5 : 0;
      break;
    case 'support':
      p.timer = (bh.interval ?? 10) * 0.5;
      break;
    case 'beam':
      p.timer = 0.6;
      p.s.strikes = 0;
      break;
    case 'grab':
      p.timer = bh.interval ? bh.interval * 0.4 : 0;
      break;
    default:
      p.timer = 0.4;
  }
  p.s.blink = 1 + b.rng() * 3;
}

// ------------------------------------------------------------------ firing helpers

function anyEnemy(b: Battle, air = true) {
  return b.zombies.some((z) => z.dying < 0 && !z.hypno && z.x < RIGHT_EDGE + 0.2 && (air || !b.isFlying(z)));
}

function shooterHasTarget(b: Battle, p: PlantEntity, bh: Extract<Behavior, { type: 'shoot' }>) {
  const air = !!bh.proj.air;
  if (bh.anywhere || bh.dirs) return anyEnemy(b, air || !!bh.dirs);
  for (const off of bh.lanes ?? [0]) {
    const l = p.lane + off;
    if (l < 0 || l >= LANES) continue;
    if (b.firstInLane(l, p.x, bh.range ?? 99, 1, air)) return true;
  }
  if (bh.back && b.firstInLane(p.lane, p.x, bh.range ?? 99, -1, air)) return true;
  return false;
}

function shooterFire(b: Battle, p: PlantEntity, bh: Extract<Behavior, { type: 'shoot' }>, override?: Partial<ProjSpec>, barrage = false) {
  const spec: ProjSpec = override ? { ...bh.proj, ...override } : bh.proj;
  const dmg = b.damageOf(p, spec.damage);
  if (bh.dirs) {
    for (const [dx, dz] of bh.dirs) b.shoot({ x: p.x, y: p.model.muzzleY, z: p.z }, spec, dx, dz, dmg);
  } else if (bh.anywhere || spec.path === 'homing') {
    const target = bh.antiAir ? b.nearest(p.x, p.z, 99, true, (z) => b.isFlying(z)) ?? b.nearest(p.x, p.z) : b.nearest(p.x, p.z, 99, true);
    const pr = b.shoot(muzzle(p), spec, 1, 0, dmg, target);
    if (barrage) {
      pr.vz = (b.rng() - 0.5) * 4;
      pr.vx = 2 + b.rng() * 3;
    }
  } else {
    for (const off of bh.lanes ?? [0]) {
      const l = p.lane + off;
      if (l < 0 || l >= LANES) continue;
      b.shoot(muzzle(p, l), spec, 1, 0, dmg);
    }
    for (let i = 0; i < (bh.back ?? 0); i++) {
      if (i === 0) b.shoot(muzzle(p, p.lane, -0.3), spec, -1, 0, dmg);
      else p.pendingShots.push(-0.15 * i); // negative = backwards shot
    }
  }
  p.recoil = 1;
  b.sfx(spec.look === 'fire' ? 'fire' : spec.look === 'volt' ? 'zap' : 'shoot');
}

function lobFire(b: Battle, p: PlantEntity, bh: Extract<Behavior, { type: 'lob' }>, target: ZombieEntity | null, override?: Partial<ProjSpec>) {
  let spec: ProjSpec = override ? { ...bh.proj, ...override } : bh.proj;
  let base = spec.damage;
  if (spec.stunChance !== undefined) {
    if (b.rng() < spec.stunChance) {
      spec = { ...spec, look: 'butter', stunChance: 1 };
      base = spec.damage * 2.6;
    } else spec = { ...spec, stun: undefined };
  }
  const from = { x: p.x + 0.1, y: p.model.muzzleY + 0.2, z: p.z };
  if (target) b.lob(from, spec, target, b.damageOf(p, base));
  p.recoil = 1;
}

// ------------------------------------------------------------------ update

export function updatePlant(b: Battle, p: PlantEntity, dt: number) {
  p.t += dt;
  if (p.pfTime > 0) p.pfTime -= dt;
  const bh = p.def.behavior;
  const k = tempo(p);
  switch (bh.type) {
    case 'shoot':
      updateShooter(b, p, bh, dt, k);
      break;
    case 'lob': {
      p.timer -= dt * k;
      if (p.pfTime > 0 && p.s.pfInterval) {
        if (p.timer <= 0) {
          p.timer = p.s.pfInterval;
          const targets = b.enemies().filter((z) => !b.isFlying(z));
          const t = targets[Math.floor(b.rng() * targets.length)] ?? null;
          if (t) lobFire(b, p, bh, t, p.s.pfOverride ? (p as unknown as { pfProj: Partial<ProjSpec> }).pfProj : undefined);
        }
        break;
      }
      if (p.timer <= 0) {
        const t = b.firstInLane(p.lane, p.x, 99, 1, false);
        if (t) {
          p.timer = bh.interval;
          lobFire(b, p, bh, t);
          for (let s = 1; s < (bh.shots ?? 1); s++) p.pendingShots.push((bh.gap ?? 0.3) * s);
        }
      }
      for (let i = p.pendingShots.length - 1; i >= 0; i--) {
        p.pendingShots[i] -= dt;
        if (p.pendingShots[i] <= 0) {
          p.pendingShots.splice(i, 1);
          lobFire(b, p, bh, b.firstInLane(p.lane, p.x, 99, 1, false));
        }
      }
      break;
    }
    case 'produce': {
      p.s.age += dt;
      if (bh.growAfter && !p.s.grown && p.s.age >= bh.growAfter) growUp(b, p);
      p.timer -= dt * p.produceBuff * k;
      if (p.timer <= 0) {
        p.timer = bh.interval;
        const amount = Math.round(((p.s.amount ?? bh.amount) * p.mult.sun) / 5) * 5;
        for (let i = 0; i < (bh.count ?? 1); i++) b.produceSun(p, amount, i);
        p.recoil = 1;
      }
      break;
    }
    case 'wall':
      updateWall(b, p, bh, dt, k);
      break;
    case 'instant':
      p.timer -= dt;
      if (p.timer <= 0) {
        b.runEffect(bh.effect, p.x, p.lane, p);
        b.removePlant(p);
      }
      break;
    case 'mine':
      if (!p.armed) {
        p.timer -= dt * k;
        if (p.timer <= 0) {
          p.armed = true;
          b.sfx('arm');
          b.particles.burst(new THREE.Vector3(p.x, 0.15, p.z), { count: 10, colors: ['#7a5230', '#8f6a3d'], speed: 1.3 });
        }
      } else if (bh.trigger === 'contact') {
        for (const z of b.zombies) {
          if (z.dying < 0 && !z.hypno && z.lane === p.lane && !b.isFlying(z) && Math.abs(z.x - p.x) < 0.45) {
            b.runEffect(bh.effect, p.x, p.lane, p);
            if (bh.reusable && (p.s.uses ?? 0) + 1 < bh.reusable) {
              p.s.uses = (p.s.uses ?? 0) + 1;
              p.armed = false;
              p.timer = 6;
            } else b.removePlant(p);
            break;
          }
        }
      }
      break;
    case 'melee':
      p.timer -= dt * k;
      if (p.timer <= 0) {
        const lo = p.x - bh.back - 0.15;
        const hi = p.x + bh.front + 0.15;
        const targets = b.zombies.filter((z) => z.dying < 0 && !z.hypno && !b.isFlying(z) && Math.abs(z.lane - p.lane) <= bh.lanes && z.x >= lo && z.x <= hi);
        if (targets.length) {
          p.timer = bh.interval;
          const hitList = bh.lanes > 0 ? targets : [targets.reduce((a, c) => (Math.abs(c.x - p.x) < Math.abs(a.x - p.x) ? c : a))];
          for (const z of hitList) {
            b.damageZombie(z, b.damageOf(p, bh.damage), { kind: 'melee', front: z.x > p.x });
            b.applyStatus(z, { knockback: bh.knockback, slow: bh.slow, burn: bh.burn });
            b.particles.burst(new THREE.Vector3(z.x - 0.1, 0.8, z.zPos), { count: 5, colors: bh.burn ? ['#ff7a1f', '#ffe36a'] : ['#ffe36a', '#ffffff'], speed: 1.8, up: 0.5, size: 0.05, life: 0.25 });
          }
          p.s.facing = hitList[0].x < p.x ? -1 : 1;
          p.recoil = 1;
          b.sfx('punch');
        }
      }
      break;
    case 'beam':
      updateBeam(b, p, bh, dt, k);
      break;
    case 'grab':
      updateGrab(b, p, bh, dt, k);
      break;
    case 'aura': {
      if (bh.whenAttacked && !b.zombies.some((z) => z.eating === p)) break;
      p.timer -= dt * k;
      if (p.timer <= 0) {
        const targets = b.inArea(p.x, p.lane, bh.radius, bh.lanes, false);
        if (targets.length) {
          p.timer = bh.interval;
          for (const z of targets) {
            if (bh.damage) b.damageZombie(z, b.damageOf(p, bh.damage), { kind: bh.burn ? 'fire' : bh.poison ? 'poison' : 'magic', ignoreArmor: !!bh.poison });
            b.applyStatus(z, { slow: bh.slow, poison: bh.poison, stun: bh.stun, burn: bh.burn });
          }
          const c = p.def.family === 'volt' ? '#c8a8ff' : bh.poison ? '#a6ff3a' : bh.burn ? '#ff7a1f' : '#9a5ad8';
          b.particles.ring(new THREE.Vector3(p.x, 0.4, p.z), c, 1 + bh.radius * 1.6, 0.4);
          if (p.def.family === 'volt') for (const z of targets.slice(0, 4)) b.fx.lightning(new THREE.Vector3(p.x, 0.6, p.z), new THREE.Vector3(z.x, 0.7, z.zPos), '#d9b8ff');
          p.recoil = 1;
          b.sfx(p.def.family === 'volt' ? 'zap' : 'magic');
        }
      }
      break;
    }
    case 'ground': {
      for (const z of b.zombies) {
        if (z.dying >= 0 || z.hypno || z.lane !== p.lane || b.isFlying(z) || Math.abs(z.x - p.x) > 0.5) continue;
        if (bh.dps) b.damageZombie(z, b.damageOf(p, bh.dps) * dt, { kind: bh.shock ? 'volt' : 'melee', silent: true, ignoreArmor: !!bh.spikes && false });
        if (bh.slow) b.applyStatus(z, { slow: bh.slow });
        if (bh.stuck && !p.s['stuck' + z.uid]) {
          p.s['stuck' + z.uid] = 1;
          b.applyStatus(z, { stun: bh.stuck });
        }
        if (bh.shock && b.rng() < dt * 3) b.fx.lightning(new THREE.Vector3(p.x, 0.1, p.z), new THREE.Vector3(z.x, 0.8, z.zPos), '#d9b8ff');
        if (b.rng() < dt * 4) p.recoil = 1;
      }
      break;
    }
    case 'support':
      updateSupport(b, p, bh, dt, k);
      break;
    case 'overlay':
      break;
  }

  // Thorns: zombies chewing this plant get hurt.
  if (bh.type === 'wall' && bh.thorns) {
    for (const z of b.zombies) if (z.eating === p && z.dying < 0) b.damageZombie(z, b.damageOf(p, bh.thorns) * dt, { kind: 'melee', silent: true, ignoreArmor: true });
  }

  if (p.hp <= 0 && !p.dead) {
    if (bh.type === 'wall' && bh.explodeOnDeath) {
      const e = bh.explodeOnDeath;
      b.runEffect({ type: 'blast', radius: e.radius, lanes: e.lanes, damage: e.damage }, p.x, p.lane, p);
    }
    b.particles.burst(new THREE.Vector3(p.x, 0.3, p.z), { count: 16, colors: ['#3c9d3a', '#63d35a', '#7a5230'], speed: 1.8 });
    b.sfx('gulp');
    b.removePlant(p);
    return;
  }
  animatePlant(b, p, dt);
}

function updateShooter(b: Battle, p: PlantEntity, bh: Extract<Behavior, { type: 'shoot' }>, dt: number, k: number) {
  for (let i = p.pendingShots.length - 1; i >= 0; i--) {
    const back = p.pendingShots[i] < 0;
    p.pendingShots[i] += back ? dt : -dt;
    if (back ? p.pendingShots[i] >= 0 : p.pendingShots[i] <= 0) {
      p.pendingShots.splice(i, 1);
      if (back) b.shoot(muzzle(p, p.lane, -0.3), bh.proj, -1, 0, b.damageOf(p, bh.proj.damage));
      else shooterFire(b, p, { ...bh, back: 0 });
    }
  }
  p.timer -= dt * k;
  if (p.pfTime > 0 && p.s.pfInterval) {
    if (p.timer <= 0) {
      p.timer = p.s.pfInterval;
      shooterFire(b, p, bh, (p as unknown as { pfProj?: Partial<ProjSpec> }).pfProj, true);
    }
    return;
  }
  if (bh.charge) {
    if (shooterHasTarget(b, p, bh)) {
      p.s.charge = (p.s.charge ?? 0) + dt * k;
      if (p.s.charge >= bh.charge && p.timer <= 0) {
        p.s.charge = 0;
        p.timer = bh.interval;
        shooterFire(b, p, bh);
      }
    } else p.s.charge = Math.max(0, (p.s.charge ?? 0) - dt);
    return;
  }
  if (p.timer <= 0 && shooterHasTarget(b, p, bh)) {
    if (bh.sunCost && !b.spendSun(bh.sunCost)) return;
    p.timer = bh.interval;
    shooterFire(b, p, bh);
    for (let s = 1; s < (bh.shots ?? 1); s++) p.pendingShots.push((bh.gap ?? 0.18) * s);
  }
}

function updateWall(b: Battle, p: PlantEntity, bh: Extract<Behavior, { type: 'wall' }>, dt: number, k: number) {
  if (bh.regen && p.hp < p.maxHp) p.hp = Math.min(p.maxHp, p.hp + bh.regen * dt * k);
  if (p.s.kb > 0) {
    p.s.kbCd = Math.max(0, (p.s.kbCd ?? 0) - dt);
    const eater = b.zombies.find((z) => z.eating === p && z.dying < 0);
    if (eater && p.s.kbCd <= 0) {
      p.s.kb--;
      p.s.kbCd = 1;
      for (const z of b.zombies) if (z.eating === p) b.knockback(z, 1.6);
      p.recoil = 1;
      b.sfx('punch');
      b.particles.burst(new THREE.Vector3(p.x + 0.3, 0.6, p.z), { count: 10, colors: ['#c8f07a', '#ffffff'], speed: 2 });
    }
  }
  if (bh.shoot) {
    p.timer -= dt * k;
    if (p.timer <= 0 && b.firstInLane(p.lane, p.x)) {
      p.timer = bh.shoot.interval;
      b.shoot(muzzle(p), bh.shoot.proj, 1, 0, b.damageOf(p, bh.shoot.proj.damage));
      p.recoil = 1;
      b.sfx('shoot');
    }
  }
}

function updateBeam(b: Battle, p: PlantEntity, bh: Extract<Behavior, { type: 'beam' }>, dt: number, k: number) {
  p.timer -= dt * k;
  if (p.timer > 0) return;
  const dmg = b.damageOf(p, bh.damage);
  const from = new THREE.Vector3(p.x + 0.3, p.model.muzzleY, p.z);
  switch (bh.kind) {
    case 'laser': {
      const t = b.firstInLane(p.lane, p.x, bh.range ?? 99);
      if (!t) return;
      for (const z of b.zombies) if (z.dying < 0 && !z.hypno && z.lane === p.lane && z.x > p.x - 0.2 && z.x < RIGHT_EDGE + 0.4 && !b.isFlying(z)) b.damageZombie(z, dmg, { kind: 'beam' });
      b.fx.beam(from, new THREE.Vector3(RIGHT_EDGE + 1, p.model.muzzleY, p.z), '#ff4af0', 0.12, 0.35);
      b.sfx('laser');
      break;
    }
    case 'chain': {
      const t = b.firstInLane(p.lane, p.x, bh.range ?? 4, 1, true) ?? b.nearest(p.x, p.z, bh.range ?? 4);
      if (!t) return;
      b.fx.lightning(from, new THREE.Vector3(t.x, 0.8, t.zPos), '#d9b8ff');
      b.damageZombie(t, dmg, { kind: 'volt' });
      b.chainFrom(t, bh.chain ?? 3, dmg);
      b.sfx('zap');
      break;
    }
    case 'random': {
      const pool = b.enemies();
      if (!pool.length) return;
      for (let i = 0; i < (bh.strikes ?? 1); i++) {
        const t = pool[Math.floor(b.rng() * pool.length)];
        b.fx.lightning(new THREE.Vector3(t.x, 5, t.zPos), new THREE.Vector3(t.x, 0.6, t.zPos), '#9fd8ff');
        b.damageZombie(t, dmg, { kind: 'volt' });
        b.particles.burst(new THREE.Vector3(t.x, 0.5, t.zPos), { count: 12, colors: ['#9fd8ff', '#ffffff'], speed: 2 });
      }
      b.sfx('zap');
      b.shake(0.08);
      break;
    }
    case 'lens': {
      const t = b.firstInLane(p.lane, p.x, bh.range ?? 99);
      if (!t) return;
      if (bh.sunCost && !b.spendSun(bh.sunCost)) return;
      b.fx.beam(new THREE.Vector3(p.x, 1.1, p.z), new THREE.Vector3(t.x, 0.7, t.zPos), '#fff27a', 0.1, 0.4);
      b.damageZombie(t, dmg, { kind: 'fire' });
      b.applyStatus(t, { burn: bh.burn });
      b.fx.glowBurst(new THREE.Vector3(t.x, 0.7, t.zPos), '#ffe36a', 0.6);
      b.sfx('laser');
      break;
    }
    case 'breath': {
      const range = bh.range ?? 2;
      const lanes = bh.lanes ?? 1;
      const targets = b.zombies.filter((z) => z.dying < 0 && !z.hypno && !b.isFlying(z) && Math.abs(z.lane - p.lane) <= lanes && z.x > p.x - 0.2 && z.x < p.x + range + 0.5);
      if (!targets.length) return;
      for (const z of targets) {
        b.damageZombie(z, dmg, { kind: bh.burn ? 'fire' : 'ice' });
        b.applyStatus(z, { burn: bh.burn, slow: bh.slow, freeze: bh.freeze });
      }
      const colors = bh.burn ? ['#ff5a1f', '#ffb02a', '#ffe36a'] : ['#bff0ff', '#ffffff', '#7fd4ff'];
      for (let i = 0; i < 4; i++) {
        b.particles.burst(new THREE.Vector3(p.x + 0.4 + i * (range / 4), 0.5, p.z), { count: 8, colors, speed: 1.4, up: 0.6, size: 0.09, life: 0.5, gravity: -0.5, spread: lanes * 1.4 });
      }
      b.fx.glowBurst(new THREE.Vector3(p.x + 0.8, 0.5, p.z), bh.burn ? '#ff8a2a' : '#bfefff', range * 0.6);
      b.sfx(bh.burn ? 'fire' : 'freeze');
      break;
    }
  }
  p.timer = bh.interval;
  p.recoil = 1;
}

function updateGrab(b: Battle, p: PlantEntity, bh: Extract<Behavior, { type: 'grab' }>, dt: number, k: number) {
  if (p.s.chew > 0) {
    p.s.chew -= dt * k;
    return;
  }
  if (p.s.jump !== undefined && p.s.jump >= 0) {
    // squash in flight
    p.s.jump += dt;
    const t = Math.min(1, p.s.jump / 0.6);
    p.model.root.position.x = p.x + (p.s.jx - p.x) * t;
    p.model.root.position.y = Math.sin(t * Math.PI) * 1.4;
    if (t >= 1) {
      for (const z of b.inArea(p.s.jx, p.lane, 0.6, 0, false)) b.damageZombie(z, b.damageOf(p, 1800), { kind: 'blast' });
      b.particles.burst(new THREE.Vector3(p.s.jx, 0.1, p.z), { count: 26, colors: ['#7a5230', '#5aa040', '#ffffff'], speed: 3 });
      b.sfx('smash');
      b.shake(0.2);
      b.removePlant(p);
    }
    return;
  }
  p.timer -= dt * k;
  if (p.timer > 0) return;
  const t = b.firstInLane(p.lane, p.x - (bh.kind === 'squash' ? bh.range : 0), bh.range * (bh.kind === 'squash' ? 2 : 1) + 0.1, 1, false);
  if (!t) return;
  switch (bh.kind) {
    case 'devour':
      if (t.def.boss) b.damageZombie(t, b.damageOf(p, 600), { kind: 'melee' });
      else b.consumeZombie(t, '#5aa040');
      p.s.chew = bh.chew ?? 30;
      p.recoil = 1;
      b.sfx('gulp');
      break;
    case 'squash':
      p.s.jump = 0;
      p.s.jx = t.x;
      b.sfx('pop');
      break;
    case 'drag':
      if (t.def.boss) b.damageZombie(t, b.damageOf(p, 1200), { kind: 'magic' });
      else b.consumeZombie(t, '#3a1a5a');
      b.fx.glowBurst(new THREE.Vector3(t.x, 0.3, t.zPos), '#7a4fc3', 0.8);
      b.sfx('magic');
      b.removePlant(p);
      break;
    case 'transform': {
      if (t.def.boss) {
        b.damageZombie(t, b.damageOf(p, 500), { kind: 'magic' });
      } else {
        const col = Math.round(t.x + (COLS - 1) / 2);
        b.consumeZombie(t, '#c07ad8');
        const id = PLANTS.puffcap ? 'puffcap' : 'peashooter';
        if (col >= 0 && col < COLS && b.canPlaceAt(id, col, t.lane)) b.spawnPlant(id, col, t.lane);
      }
      b.fx.glowBurst(new THREE.Vector3(t.x, 0.6, t.zPos), '#e07aff', 0.8);
      b.sfx('magic');
      p.recoil = 1;
      break;
    }
  }
  p.timer = bh.interval ?? 0;
}

function updateSupport(b: Battle, p: PlantEntity, bh: Extract<Behavior, { type: 'support' }>, dt: number, k: number) {
  if (bh.kind === 'haste' || bh.kind === 'damageBoost' || bh.kind === 'producerBoost' || bh.kind === 'fireConvert' || bh.kind === 'divert') return;
  p.timer -= dt * k;
  if (p.timer > 0) return;
  const interval = bh.interval ?? 10;
  const r = bh.radius ?? 1;
  switch (bh.kind) {
    case 'heal': {
      let healed = false;
      for (const o of b.plants) {
        if (o.dead || Math.abs(o.col - p.col) > r || Math.abs(o.lane - p.lane) > r || o.hp >= o.maxHp) continue;
        o.hp = Math.min(o.maxHp, o.hp + (bh.amount ?? 100) * p.mult.hp);
        b.particles.burst(new THREE.Vector3(o.x, 0.7, o.z), { count: 6, colors: ['#7dffb0', '#ffffff'], speed: 0.8, up: 1.2, gravity: -0.5 });
        healed = true;
      }
      if (healed) {
        b.sfx('heal');
        p.recoil = 1;
      }
      break;
    }
    case 'summon': {
      const id = PLANTS.puffcap ? 'puffcap' : 'peashooter';
      const free: number[] = [];
      for (let c = p.col + 1; c < COLS; c++) if (b.canPlaceAt(id, c, p.lane)) free.push(c);
      if (free.length) {
        const c = free[Math.floor(b.rng() * free.length)];
        b.spawnPlant(id, c, p.lane);
        b.fx.glowBurst(new THREE.Vector3(colX(c), 0.3, p.z), '#c8ffb0', 0.5);
        p.recoil = 1;
      }
      break;
    }
    case 'globalSlow':
      if (b.enemies().length) {
        b.runEffect({ type: 'globalSlow', duration: bh.amount ?? 4 }, p.x, p.lane, p);
        p.recoil = 1;
      }
      break;
    case 'magnet': {
      const t = b.nearest(p.x, p.z, r + 0.5, true, (z) => (z.armor > 0 && !!z.def.armorMetal) || z.shield > 0);
      if (!t) return;
      b.fx.beam(new THREE.Vector3(p.x, 0.9, p.z), new THREE.Vector3(t.x, 1.2, t.zPos), '#ff5a5a', 0.05, 0.4);
      if (t.shield > 0) {
        t.shield = 0;
        if (t.model.shield) t.model.shield.visible = false;
      } else {
        t.armor = 0;
        if (t.model.armor) t.model.armor.visible = false;
      }
      p.recoil = 1;
      b.sfx('zap');
      break;
    }
    case 'hypnoAura': {
      const t = b.nearest(p.x, p.z, r + 0.5, false, (z) => !z.def.boss);
      if (!t) return;
      b.hypnotize(t);
      b.fx.beam(new THREE.Vector3(p.x, 0.8, p.z), new THREE.Vector3(t.x, 1.1, t.zPos), '#e07aff', 0.06, 0.4);
      p.recoil = 1;
      break;
    }
    case 'wind': {
      let pushed = false;
      for (const z of b.zombies) {
        if (z.dying >= 0 || z.hypno || z.lane !== p.lane || z.x < p.x || z.x > p.x + r + 0.5 || z.x > RIGHT_EDGE) continue;
        if (b.isFlying(z)) b.popBalloon(z);
        b.knockback(z, bh.amount ?? 0.6);
        pushed = true;
      }
      if (pushed) {
        b.fx.wind(p.z, p.x, '#e8fff6', false);
        b.sfx('wind');
        p.recoil = 1;
      } else return;
      break;
    }
    case 'coins':
      b.spawnPickup('coin', bh.amount ?? 10, new THREE.Vector3(p.x, 0.8, p.z), false);
      p.recoil = 1;
      break;
  }
  p.timer = interval;
}

function growUp(b: Battle, p: PlantEntity) {
  const bh = p.def.behavior;
  if (bh.type !== 'produce' || p.s.grown) return;
  p.s.grown = 1;
  p.s.amount = bh.grownAmount ?? bh.amount;
  b.particles.burst(new THREE.Vector3(p.x, 0.5, p.z), { count: 14, colors: ['#ffe36a', '#ffffff'], speed: 1.5 });
}

// ------------------------------------------------------------------ Plant Food

export function applyPlantFood(b: Battle, p: PlantEntity) {
  const pf = p.def.pf;
  const bh = p.def.behavior;
  switch (pf.type) {
    case 'barrage':
      p.pfTime = pf.duration;
      p.s.pfInterval = pf.interval;
      p.timer = 0;
      (p as unknown as { pfProj?: Partial<ProjSpec> }).pfProj = pf.proj;
      p.s.pfOverride = pf.proj ? 1 : 0;
      if (bh.type === 'shoot' && bh.proj.slow && pf.proj?.freeze) {
        for (const z of b.zombies) if (z.lane === p.lane && z.dying < 0 && !z.hypno && z.x > p.x - 0.5) b.applyStatus(z, { freeze: pf.proj.freeze });
        b.sfx('freeze');
      }
      break;
    case 'megaShot':
      for (let i = 0; i < (pf.count ?? 1); i++) {
        const pr = b.shoot(muzzle(p), pf.proj, 1, 0, b.damageOf(p, pf.proj.damage));
        pr.x -= i * 0.6;
      }
      p.recoil = 1;
      p.pfTime = 1;
      b.sfx('shoot');
      break;
    case 'sun': {
      const n = Math.ceil(pf.amount / 50);
      for (let i = 0; i < n; i++) b.produceSun(p, Math.min(50, pf.amount - i * 50), i);
      if (bh.type === 'produce') growUp(b, p);
      p.pfTime = 1;
      break;
    }
    case 'armor':
      p.hp = p.maxHp;
      p.shell = p.maxHp;
      p.pfTime = 1.2;
      if (bh.type === 'wall' && bh.knockbacks) p.s.kb = bh.knockbacks;
      break;
    case 'effect':
      b.runEffect(pf.effect, p.x, p.lane, p);
      p.pfTime = 1.2;
      p.recoil = 1;
      break;
    case 'arm': {
      p.armed = true;
      p.timer = 0;
      const free: number[] = [];
      for (let c = p.col + 1; c < COLS; c++) if (b.canPlaceAt(p.def.id, c, p.lane)) free.push(c);
      for (let i = 0; i < (pf.copies ?? 0) && free.length; i++) {
        const c = free.splice(Math.floor(b.rng() * free.length), 1)[0];
        const m = b.spawnPlant(p.def.id, c, p.lane);
        m.armed = true;
        m.timer = 0;
        m.model.body.position.y = 0;
      }
      p.pfTime = 1;
      break;
    }
    case 'boost':
      p.pfTime = pf.duration;
      p.pfBoost = pf.factor;
      p.timer = 0;
      if (bh.type === 'grab') p.s.chew = 0;
      if (bh.type === 'wall' && p.hp < p.maxHp) p.hp = p.maxHp;
      break;
    case 'none':
      break;
  }
}

// ------------------------------------------------------------------ reactions

/** Called every frame a zombie bites this plant (dmg = this frame's bite damage). */
export function onPlantEaten(b: Battle, p: PlantEntity, z: ZombieEntity, _dmg: number) {
  const bh = p.def.behavior;
  if (bh.type === 'mine' && bh.trigger === 'eaten' && p.armed) {
    const e = bh.effect;
    switch (e.type) {
      case 'hypnoEater':
        b.hypnotize(z);
        break;
      case 'stunEater':
        for (const o of b.inArea(z.x, z.lane, e.radius, e.radius > 0.6 ? 1 : 0)) b.applyStatus(o, { stun: e.duration });
        b.applyStatus(z, { stun: e.duration });
        b.particles.burst(new THREE.Vector3(z.x, 1, z.zPos), { count: 16, colors: ['#c8ff7a', '#a6d83a'], speed: 1.5, up: 1 });
        b.sfx('splat');
        break;
      case 'sunEater':
        b.produceSun(p, e.amount);
        b.produceSun(p, e.amount, 1);
        break;
      default:
        b.runEffect(e, p.x, p.lane, p);
    }
    b.removePlant(p);
    return;
  }
  if (bh.type === 'support' && bh.kind === 'divert') {
    p.s['bite' + z.uid] = (p.s['bite' + z.uid] ?? 0) + _dmg;
    if (p.s['bite' + z.uid] > 40) {
      p.s['bite' + z.uid] = 0;
      const options = [z.lane - 1, z.lane + 1].filter((l) => l >= 0 && l < LANES);
      b.switchLane(z, options[Math.floor(b.rng() * options.length)]);
      b.particles.burst(new THREE.Vector3(z.x, 1.2, z.zPos), { count: 8, colors: ['#e8f0c8', '#c8d89a'], speed: 1, up: 1 });
      b.sfx('splat');
    }
    return;
  }
  if (bh.type === 'wall' && bh.stunOnBite) {
    const key = 'stun' + z.uid;
    if ((p.s[key] ?? 0) <= b.time) {
      p.s[key] = b.time + 3;
      b.applyStatus(z, { stun: bh.stunOnBite });
      b.particles.burst(new THREE.Vector3(z.x, 1, z.zPos), { count: 10, colors: ['#c8ff7a', '#e8ffb0'], speed: 1.2, up: 1 });
    }
  }
  if (bh.type === 'aura' && bh.whenAttacked) {
    // handled in update (only fires while being attacked)
  }
}

// ------------------------------------------------------------------ animation

export function animatePlant(b: Battle, p: PlantEntity, dt: number) {
  const m = p.model;
  const bh = p.def.behavior;
  p.recoil = Math.max(0, p.recoil - dt * 5);
  const sway = Math.sin(p.t * 2.2) * 0.05;
  m.body.rotation.z = sway;
  m.body.scale.set(1, 1 + Math.sin(p.t * 2.2 + 1) * 0.025, 1);
  // Blink.
  p.s.blink -= dt;
  if (m.eyes) {
    const closed = p.s.blink < 0.12;
    m.eyes.scale.y = closed ? 0.1 : 1;
    if (p.s.blink < 0) p.s.blink = 2 + Math.random() * 3.5;
  }
  const r = p.recoil;
  const kind = bh.type;
  if (kind === 'shoot' || kind === 'beam' || (kind === 'wall' && bh.shoot)) {
    m.head.position.x = m.headRest.x - r * 0.07;
    m.head.scale.set(1 + r * 0.15, 1 - r * 0.12, 1 + r * 0.1);
  } else if (kind === 'lob') {
    if (m.bones.arm) m.bones.arm.rotation.z = r > 0.5 ? (1 - r) * 2 * -2.2 + 0.6 : 0.6 - r * 2.2;
  } else if (kind === 'melee') {
    const f = p.s.facing ?? 1;
    m.head.position.x = m.headRest.x + Math.sin(r * Math.PI) * 0.12 * f;
    if (m.bones.armL) m.bones.armL.rotation.z = -0.3 + Math.sin(r * Math.PI) * 1.6 * f;
    if (m.bones.armR) m.bones.armR.rotation.z = -0.3 + Math.sin(Math.max(0, r - 0.3) * Math.PI) * 1.6 * f;
  } else if (kind === 'instant') {
    const fuse = bh.fuse;
    const f = 1 - Math.max(0, p.timer) / fuse;
    m.root.scale.setScalar(1 + f * 0.5 + Math.sin(p.t * 45) * 0.05 * f);
    p.model.inst.material.emissive.setRGB(f * 0.6, f * 0.15, 0);
    return;
  } else if (kind === 'mine') {
    m.body.position.y = THREE.MathUtils.lerp(m.body.position.y, p.armed ? 0 : -0.16, Math.min(1, dt * 4));
    if (m.bones.light) m.bones.light.scale.setScalar(p.armed && Math.floor(p.t * 3) % 2 === 0 ? 1.4 : 0.8);
  } else if (kind === 'produce') {
    m.head.rotation.z = Math.sin(p.t * 1.6) * 0.08;
    if (m.bones.petals) m.bones.petals.rotation.x += dt * (0.3 + r * 3);
    m.head.scale.setScalar(1 + r * 0.12);
    if (p.def.behavior.type === 'produce' && p.def.behavior.growAfter) {
      const target = p.s.grown ? 1.35 : 0.85;
      m.body.scale.setScalar(THREE.MathUtils.lerp(m.body.scale.x, target, Math.min(1, dt * 3)));
    }
  } else if (kind === 'grab') {
    if (m.bones.jaw) m.bones.jaw.rotation.z = p.s.chew > 0 ? Math.abs(Math.sin(p.t * 8)) * 0.4 : Math.max(0, Math.sin(p.t * 1.5)) * 0.25 + r * 0.8;
    m.head.scale.setScalar(1 + r * 0.2);
  } else if (kind === 'wall') {
    const dmg = 1 - p.hp / p.maxHp;
    m.head.rotation.z = Math.sin(p.t * 1.3) * 0.03 + (r > 0 ? Math.sin(r * Math.PI) * 0.4 : 0);
    if (!p.pfTime) p.model.inst.material.color.setRGB(1 - dmg * 0.35, 1 - dmg * 0.4, 1 - dmg * 0.45);
  } else {
    m.head.scale.setScalar(1 + r * 0.1);
    if (m.bones.spin) m.bones.spin.rotation.y += dt * 2;
  }
  if (bh.type === 'shoot' && bh.charge) {
    const c = Math.min(1, (p.s.charge ?? 0) / bh.charge);
    p.model.inst.material.emissive.setRGB(c * 0.5, c * 0.45, c * 0.1);
  }
  if (m.bones.spin && kind !== 'support') m.bones.spin.rotation.y += dt * (1 + r * 6);
  // Plant Food pulse / hit flash.
  p.hitFlash = Math.max(0, p.hitFlash - dt);
  const mat = p.model.inst.material;
  if (p.pfTime > 0) {
    const pulse = 1 + Math.sin(p.t * 25) * 0.06;
    m.root.scale.setScalar(1.12 * pulse);
    mat.emissive.setRGB(0.05, 0.35 + Math.sin(p.t * 12) * 0.1, 0.05);
    if (Math.random() < dt * 20) b.particles.burst(new THREE.Vector3(p.x, 0.3 + Math.random() * 0.4, p.z), { count: 1, colors: ['#5dff6a', '#c8ffc0'], speed: 0.6, up: 1, gravity: 0, life: 0.5 });
  } else {
    m.root.scale.setScalar(THREE.MathUtils.lerp(m.root.scale.x, 1, Math.min(1, dt * 6)));
    if (!(bh.type === 'shoot' && bh.charge)) {
      if (p.hitFlash > 0) mat.emissive.setRGB(0.25, 0.12, 0.08);
      else if (p.shell > 0) mat.emissive.setRGB(0.12, 0.14, 0.18);
      else mat.emissive.setRGB(0, 0, 0);
    }
  }
}
