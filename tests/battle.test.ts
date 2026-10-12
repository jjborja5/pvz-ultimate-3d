import { describe, expect, it } from 'vitest';
import * as THREE from 'three';
import { Battle } from '../src/game/battle';
import { LEVELS, PLANT_ORDER, getLevel, type PlantId } from '../src/game/config';
import { defaultSave, rules } from '../src/game/save';
import { mulberry } from '../src/game/environment';

function makeRules(mutate?: (s: ReturnType<typeof defaultSave>) => void) {
  const save = defaultSave();
  mutate?.(save);
  return rules(save);
}

function run(b: Battle, maxSeconds = 900) {
  const dt = 1 / 30;
  for (let t = 0; t < maxSeconds && (b.phase === 'playing' || b.phase === 'ready'); t += dt) b.update(dt);
  return b.phase;
}

describe('battle simulation', () => {
  it('wins level 1-1 with a row of peashooters in every lane (Ultimate on)', () => {
    const b = new Battle(new THREE.Scene(), getLevel('1-1')!, ['peashooter', 'repeater', 'wallnut'], makeRules(), { rng: mulberry(1) });
    b.start();
    for (let lane = 0; lane < 5; lane++) {
      expect(b.plantAt('repeater', 0, lane)).toBe(true);
      // Repeater is on cooldown unless instant recharge; place peashooters via spawn for setup.
      b.spawnPlant('peashooter', 1, lane);
      b.spawnPlant('wallnut', 6, lane);
      b.cooldown.set('repeater', 0);
    }
    expect(run(b)).toBe('won');
    expect(b.stats.killed).toBe(LEVELS[0].waves.reduce((s, w) => s + w.zombies.length, 0));
  });

  it('loses when nothing defends the lawn and Ultimate Mode is off', () => {
    const r = makeRules((s) => (s.ultimate.enabled = false));
    const b = new Battle(new THREE.Scene(), getLevel('1-2')!, ['peashooter'], r, { rng: mulberry(2) });
    b.start();
    expect(run(b)).toBe('lost');
    // At least one mower should have fired before the zombies broke through.
    expect(b.mowers.some((m) => m.active || m.gone)).toBe(true);
  });

  it('invincibility protects the house even with no plants', () => {
    const r = makeRules((s) => (s.ultimate.invincible = true));
    const b = new Battle(new THREE.Scene(), getLevel('1-1')!, ['peashooter'], r, { rng: mulberry(3) });
    b.start();
    expect(run(b)).toBe('won');
  });

  it('spends sun and enforces recharge when Ultimate Mode is off', () => {
    const r = makeRules((s) => (s.ultimate.enabled = false));
    const b = new Battle(new THREE.Scene(), getLevel('1-1')!, ['peashooter', 'sunflower'], r, { rng: mulberry(4) });
    b.start();
    expect(b.sun).toBe(150);
    expect(b.plantAt('peashooter', 0, 0)).toBe(true);
    expect(b.sun).toBe(50);
    expect(b.canPlant('peashooter').ok).toBe(false); // recharging + not enough sun
    expect(b.plantAt('sunflower', 0, 1)).toBe(true);
    expect(b.sun).toBe(0);
    expect(b.canPlant('sunflower')).toEqual({ ok: false, reason: 'Recharging' });
    expect(b.plantAt('sunflower', 0, 1)).toBe(false); // occupied
  });

  it('unlimited sun and instant recharge allow unlimited planting', () => {
    const r = makeRules((s) => (s.ultimate.instantRecharge = true));
    const b = new Battle(new THREE.Scene(), getLevel('1-1')!, ['repeater'], r, { rng: mulberry(5) });
    b.start();
    let placed = 0;
    for (let lane = 0; lane < 5; lane++) for (let col = 0; col < 9; col++) if (b.plantAt('repeater', col, lane)) placed++;
    expect(placed).toBe(45);
  });

  it('plant food powers up a sunflower and is consumed without Ultimate', () => {
    const r = makeRules((s) => (s.ultimate.enabled = false));
    const b = new Battle(new THREE.Scene(), getLevel('1-1')!, ['sunflower'], r, { rng: mulberry(6) });
    b.start();
    b.plantAt('sunflower', 2, 2);
    expect(b.plantFood).toBe(1);
    expect(b.usePlantFood(2, 2)).toBe(true);
    expect(b.plantFood).toBe(0);
    expect(b.usePlantFood(2, 2)).toBe(false);
    expect(b.pickups.filter((p) => p.kind === 'sun').length).toBe(3);
  });

  it('cherry bomb clears a 3x3 area', () => {
    const b = new Battle(new THREE.Scene(), getLevel('1-1')!, ['cherrybomb'], makeRules(), { rng: mulberry(7) });
    b.start();
    const near = [b.spawnZombie('bucket', 1, 0.5), b.spawnZombie('cone', 2, 0.2), b.spawnZombie('basic', 3, -0.5)];
    const far = b.spawnZombie('basic', 2, 3.5);
    b.spawnPlant('cherrybomb', 4, 2);
    for (let i = 0; i < 60; i++) b.update(1 / 30);
    for (const z of near) expect(z.dying).toBeGreaterThanOrEqual(0);
    expect(far.dying).toBe(-1);
  });

  it('every level and plant definition is valid', () => {
    for (const l of LEVELS) {
      expect(l.waves.length).toBeGreaterThan(0);
      expect(l.waves[l.waves.length - 1].flag).toBe(true);
    }
    const ids: PlantId[] = PLANT_ORDER;
    expect(new Set(ids).size).toBe(ids.length);
  });
});
