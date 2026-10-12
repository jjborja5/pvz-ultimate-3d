// Every plant must: have valid data, a dedicated 3D model, a unique behavior, survive a real battle
// simulation, accept Plant Food, and visibly affect zombies (or the economy) in its own way.
import { describe, expect, it } from 'vitest';
import { PLANT_LIST } from '../src/game/config';
import { buildPlant, hasPlantModel } from '../src/game/models/plants';
import { plantStats } from '../src/game/plants/stats';
import { FAMILIES, type PlantDef } from '../src/game/plants/types';
import type { Battle, ZombieEntity } from '../src/game/battle';
import { arena, run } from './helpers';

const LANE = 2;

/** Zombie state snapshot to detect any effect a plant had. */
function affected(z: ZombieEntity, hp0: number) {
  return z.dying >= 0 || z.hp < hp0 || z.armor < (z.def.armor ?? 0) || z.slow > 0 || z.freeze > 0 || z.stun > 0 || z.hypno || z.burnT > 0 || z.poisonT > 0 || z.weakenT > 0 || z.shrunk;
}

/** Default scenario: put the plant at column 2 and a zombie where this plant can reach it. */
function engage(b: Battle, def: PlantDef) {
  const bh = def.behavior;
  let col = 2;
  let zx = 1.5; // world x (col 2 is x = -2)
  switch (bh.type) {
    case 'melee':
      zx = -2 + Math.min(bh.front, 1) * 0.8;
      break;
    case 'grab':
      zx = -2 + Math.min(bh.range, 1) * 0.9;
      break;
    case 'aura':
      zx = -2 + Math.min(bh.radius, 1) * 0.8;
      break;
    case 'mine':
      zx = -1.4;
      break;
    case 'ground':
      zx = -1.6;
      break;
    case 'instant':
      col = 4;
      zx = 0.3;
      break;
    case 'beam':
      zx = bh.kind === 'breath' ? -2 + Math.min(bh.range ?? 2, 1.5) : -0.5;
      break;
    case 'support':
      zx = -1.2;
      break;
    case 'wall':
      zx = -1.6;
      break;
  }
  const p = b.spawnPlant(def.id, col, LANE);
  const z = b.spawnZombie('basic', LANE, zx);
  z.hp = 5000; // tanky so we can observe the effect
  return { p, z };
}

describe('plant roster data', () => {
  it('has unique ids and names', () => {
    expect(new Set(PLANT_LIST.map((p) => p.id)).size).toBe(PLANT_LIST.length);
    expect(new Set(PLANT_LIST.map((p) => p.name)).size).toBe(PLANT_LIST.length);
  });

  it('every plant has a unique behavior + Plant Food combination', () => {
    const sigs = PLANT_LIST.map((p) => JSON.stringify({ b: p.behavior, pf: p.pf, cost: p.cost, hp: p.hp }));
    const dupes = PLANT_LIST.filter((_, i) => sigs.indexOf(sigs[i]) !== i).map((p) => p.id);
    expect(dupes).toEqual([]);
  });

  it('every plant has a dedicated, distinct 3D model', () => {
    const prints = new Map<string, string>();
    for (const p of PLANT_LIST) {
      expect(hasPlantModel(p.id), `${p.id} needs its own model builder`).toBe(true);
      const m = buildPlant(p.id);
      const pos = m.inst.mesh.geometry.attributes.position;
      let sum = 0;
      for (let i = 0; i < pos.count; i += 7) sum += pos.getX(i) * 3.1 + pos.getY(i) * 1.7 + pos.getZ(i);
      const key = `${pos.count}:${sum.toFixed(3)}`;
      expect(prints.has(key), `${p.id} model is identical to ${prints.get(key)}`).toBe(false);
      prints.set(key, p.id);
      expect(m.head).toBeTruthy();
      expect(m.body).toBeTruthy();
    }
  });

  for (const p of PLANT_LIST) {
    it(`${p.id}: complete almanac data`, () => {
      expect(p.name.length).toBeGreaterThan(2);
      expect(p.ability.length).toBeGreaterThan(10);
      expect(p.blurb.length).toBeGreaterThan(10);
      expect(p.pfText.length).toBeGreaterThan(5);
      expect(FAMILIES[p.family]).toBeTruthy();
      expect(p.cost).toBeGreaterThanOrEqual(0);
      expect(p.recharge).toBeGreaterThan(0);
      expect(plantStats(p, 1).length).toBeGreaterThanOrEqual(3);
      if (p.noPlantFood) expect(p.pf.type).toBe('none');
      else expect(p.pf.type).not.toBe('none');
    });
  }
});

describe('every plant works in battle', () => {
  for (const def of PLANT_LIST) {
    it(`${def.id}: acts on the lawn`, () => {
      const b = arena();
      const bh = def.behavior;
      if (bh.type === 'produce') {
        b.spawnPlant(def.id, 2, LANE);
        expect(run(b, bh.interval + 12, () => b.pickups.some((k) => k.kind === 'sun'))).toBe(true);
        return;
      }
      if (bh.type === 'overlay') {
        const under = b.spawnPlant('peashooter', 2, LANE);
        const shell = b.spawnPlant(def.id, 2, LANE);
        const z = b.spawnZombie('basic', LANE, -1.7);
        run(b, 4);
        expect(shell.hp).toBeLessThan(shell.maxHp);
        expect(under.hp).toBe(under.maxHp);
        expect(z.eating).toBe(shell);
        return;
      }
      if (bh.type === 'wall' && !bh.shoot && !bh.thorns && !bh.knockbacks && !bh.stunOnBite) {
        const p = b.spawnPlant(def.id, 2, LANE);
        const z = b.spawnZombie('basic', LANE, -1.6);
        run(b, 5);
        expect(z.eating).toBe(p);
        expect(p.hp).toBeLessThan(p.maxHp);
        expect(z.x).toBeGreaterThan(p.x);
        return;
      }
      if (bh.type === 'support' && (bh.kind === 'haste' || bh.kind === 'damageBoost' || bh.kind === 'producerBoost')) {
        const s = b.spawnPlant(def.id, 2, LANE);
        const n = b.spawnPlant(bh.kind === 'producerBoost' ? 'sunflower' : 'peashooter', 3, LANE);
        run(b, 0.5);
        const v = bh.kind === 'haste' ? n.haste : bh.kind === 'damageBoost' ? n.dmgBuff : n.produceBuff;
        expect(v, `${s.def.id} buffs neighbors`).toBeGreaterThan(1);
        return;
      }
      if (bh.type === 'support' && bh.kind === 'fireConvert') {
        b.spawnPlant('peashooter', 1, LANE);
        b.spawnPlant(def.id, 2, LANE);
        const z = b.spawnZombie('basic', LANE, 1);
        z.hp = 5000;
        run(b, 6, () => z.burnT > 0);
        expect(z.burnT).toBeGreaterThan(0);
        return;
      }
      if (bh.type === 'support' && bh.kind === 'heal') {
        b.spawnPlant(def.id, 2, LANE);
        const w = b.spawnPlant('wallnut', 3, LANE);
        w.hp = 100;
        run(b, (bh.interval ?? 5) + 1);
        expect(w.hp).toBeGreaterThan(100);
        return;
      }
      if (bh.type === 'support' && bh.kind === 'summon') {
        b.spawnPlant(def.id, 2, LANE);
        const before = b.plants.length;
        run(b, (bh.interval ?? 10) + 1);
        expect(b.plants.length).toBeGreaterThan(before);
        return;
      }
      if (bh.type === 'support' && bh.kind === 'coins') {
        b.spawnPlant(def.id, 2, LANE);
        run(b, (bh.interval ?? 10) + 2);
        expect(b.stats.coins).toBeGreaterThan(0);
        return;
      }
      if (bh.type === 'support' && bh.kind === 'divert') {
        b.spawnPlant(def.id, 2, LANE);
        const z = b.spawnZombie('basic', LANE, -1.6);
        run(b, 4);
        expect(z.lane).not.toBe(LANE);
        return;
      }
      if (bh.type === 'support' && bh.kind === 'magnet') {
        b.spawnPlant(def.id, 2, LANE);
        const z = b.spawnZombie('bucket', LANE, 0);
        run(b, (bh.interval ?? 8) + 1);
        expect(z.armor).toBe(0);
        return;
      }
      if (bh.type === 'instant' && (bh.effect.type === 'giveSun' || bh.effect.type === 'givePlantFood')) {
        b.plantFood = 0;
        b.rules = { ...b.rules, unlimitedPlantFood: false };
        b.spawnPlant(def.id, 2, LANE);
        run(b, 3);
        if (bh.effect.type === 'giveSun') expect(b.pickups.filter((k) => k.kind === 'sun').reduce((s, k) => s + k.value, 0)).toBe(bh.effect.amount);
        else expect(b.plantFood).toBe(1);
        return;
      }
      if (bh.type === 'instant' && bh.effect.type === 'boostProducers') {
        b.spawnPlant('sunflower', 0, 0);
        b.spawnPlant(def.id, 2, LANE);
        run(b, 2);
        expect(b.pickups.some((k) => k.kind === 'sun')).toBe(true);
        return;
      }
      if (bh.type === 'instant' && bh.effect.type === 'conceal') {
        const w = b.spawnPlant('wallnut', 2, LANE);
        b.spawnPlant(def.id, 5, 0);
        const z = b.spawnZombie('basic', LANE, -1.4);
        run(b, 4);
        expect(w.hp).toBe(w.maxHp);
        expect(z.x).toBeLessThan(w.x);
        return;
      }
      if (bh.type === 'mine' && bh.trigger === 'eaten') {
        const p = b.spawnPlant(def.id, 2, LANE);
        const z = b.spawnZombie('basic', LANE, -1.6);
        z.hp = 5000;
        const hp0 = z.hp;
        run(b, 4 + bh.arm, () => p.dead);
        expect(p.dead).toBe(true);
        const sunMade = b.pickups.some((k) => k.kind === 'sun');
        expect(affected(z, hp0) || sunMade).toBe(true);
        return;
      }
      const { p, z } = engage(b, def);
      const hp0 = z.hp;
      const x0 = z.x;
      if (bh.type === 'mine' && bh.arm > 0) {
        p.armed = true;
        p.timer = 0;
        p.model.body.position.y = 0;
      }
      if (bh.type === 'support' && (bh.kind === 'globalSlow' || bh.kind === 'wind' || bh.kind === 'hypnoAura')) p.timer = 0.1;
      const ok = run(b, 14, () => affected(z, hp0) || z.x > x0 + 0.4 || (((bh.type === 'support' && bh.kind === 'wind') || bh.type === 'wall') && z.x > -1.1));
      if (bh.type === 'wall') {
        // wall with an active twist (thorns / knockback / shooting / stun)
        expect(ok || z.x > -1.2).toBe(true);
        return;
      }
      expect(ok, `${def.id} should affect the zombie`).toBe(true);
    });

    if (!def.noPlantFood) {
      it(`${def.id}: Plant Food ability runs`, () => {
        const b = arena();
        const p = b.spawnPlant(def.id, 2, LANE);
        const zs = [b.spawnZombie('basic', LANE, 1), b.spawnZombie('cone', LANE + 1, 2), b.spawnZombie('basic', LANE - 1, 0.5)];
        for (const z of zs) z.hp = 3000;
        expect(b.usePlantFood(2, LANE)).toBe(true);
        const sun0 = b.pickups.length;
        run(b, 5);
        const changed = zs.some((z) => affected(z, 3000)) || b.pickups.length > sun0 || b.plants.length > 1 || p.shell > 0 || b.zombies.some((z) => z.hypno) || b.plantFood >= 1 || p.armed;
        expect(changed, `${def.id} plant food should do something`).toBe(true);
      });
    }
  }
});
