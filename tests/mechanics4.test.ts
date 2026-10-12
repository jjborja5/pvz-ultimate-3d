// Batch 4: each plant's signature mechanic, verified in a real battle simulation.
import { describe, expect, it } from 'vitest';
import { PLANT_LIST } from '../src/game/config';
import { arena, run } from './helpers';

describe('batch 4 signature mechanics', () => {
  it('the collection has exactly 100 plants in four batches of 25', () => {
    expect(PLANT_LIST.length).toBe(100);
    for (const n of [1, 2, 3, 4]) expect(PLANT_LIST.filter((p) => p.batch === n).length).toBe(25);
  });

  it('Roto Turnip hits zombies diagonally', () => {
    const b = arena();
    b.spawnPlant('rototurnip', 2, 2);
    const z = b.spawnZombie('basic', 0, 0);
    z.def = { ...z.def, speed: 0 };
    z.hp = 5000;
    run(b, 3);
    expect(z.hp).toBeLessThan(5000);
  });

  it('Volt Pea arcs to a zombie in another lane', () => {
    const b = arena();
    b.spawnPlant('voltpea', 0, 2);
    const a = b.spawnZombie('basic', 2, 1);
    const c = b.spawnZombie('basic', 3, 1.3);
    a.hp = c.hp = 5000;
    run(b, 2);
    expect(c.hp).toBeLessThan(5000);
  });

  it('Goo Pea poison bypasses a bucket', () => {
    const b = arena();
    b.spawnPlant('goopea', 0, 2);
    const z = b.spawnZombie('bucket', 2, 2);
    run(b, 3);
    expect(z.hp).toBeLessThan(190);
  });

  it('Pea-nut blocks like a wall and shoots like a peashooter', () => {
    const b = arena();
    const p = b.spawnPlant('peanut', 2, 2);
    const z = b.spawnZombie('basic', 2, -1.6);
    z.hp = 5000;
    run(b, 4);
    expect(z.eating).toBe(p);
    expect(z.hp).toBeLessThan(5000);
  });

  it('Magnet Cap rips off screen doors too', () => {
    const b = arena();
    const p = b.spawnPlant('magnetcap', 2, 2);
    p.timer = 0.1;
    const z = b.spawnZombie('door', 2, 0);
    run(b, 1);
    expect(z.shield).toBe(0);
  });

  it('Coconut Cannon explodes on impact, hitting a group', () => {
    const b = arena();
    b.spawnPlant('coconutcannon', 0, 2);
    const zs = [b.spawnZombie('basic', 2, 1), b.spawnZombie('basic', 2, 1.5)];
    run(b, 3);
    for (const z of zs) expect(z.dying).toBeGreaterThanOrEqual(0);
  });

  it('Chili Bean stuns its eater and the zombies around it', () => {
    const b = arena();
    b.spawnPlant('chilibean', 2, 2);
    const eater = b.spawnZombie('basic', 2, -1.6);
    const near = b.spawnZombie('basic', 1, -1.2);
    run(b, 2, () => eater.stun > 0);
    expect(eater.stun).toBeGreaterThan(0);
    expect(near.stun).toBeGreaterThan(0);
  });

  it('Stink Onion stuns biters', () => {
    const b = arena();
    b.spawnPlant('stinkonion', 2, 2);
    const z = b.spawnZombie('basic', 2, -1.6);
    run(b, 3, () => z.stun > 0);
    expect(z.stun).toBeGreaterThan(0);
  });

  it('Sniper Pea hits the farthest zombie first', () => {
    const b = arena();
    b.spawnPlant('sniperpea', 0, 2);
    const near = b.spawnZombie('basic', 2, -1);
    const far = b.spawnZombie('basic', 2, 3.5);
    near.hp = far.hp = 5000;
    run(b, 1);
    expect(far.hp).toBeLessThan(5000);
    expect(near.hp).toBe(5000);
  });

  it('Sticky Sap traps zombies, then keeps them chilled', () => {
    const b = arena();
    b.spawnPlant('stickysap', 4, 2);
    const z = b.spawnZombie('basic', 2, 0.4);
    run(b, 1, () => z.stun > 0);
    expect(z.stun).toBeGreaterThan(0);
    expect(z.slow).toBeGreaterThan(0);
  });

  it('Tangle Vine roots every zombie in range in its lane', () => {
    const b = arena();
    b.spawnPlant('tanglevine', 1, 2);
    const zs = [b.spawnZombie('basic', 2, -2.2), b.spawnZombie('basic', 2, -1)];
    run(b, 5, () => zs.every((z) => z.stun > 0));
    for (const z of zs) expect(z.stun).toBeGreaterThan(0);
  });

  it('Seed Sower plants free Puffcaps ahead of it', () => {
    const b = arena();
    b.spawnPlant('seedsower', 0, 2);
    run(b, 12);
    const puff = b.plants.find((p) => p.def.id === 'puffcap');
    expect(puff).toBeTruthy();
    expect(puff!.lane).toBe(2);
    expect(puff!.col).toBeGreaterThan(0);
  });

  it('Sun Bean pays out sun when a zombie bites it', () => {
    const b = arena();
    b.spawnPlant('sunbean', 2, 2);
    b.spawnZombie('basic', 2, -1.6);
    run(b, 2);
    expect(b.pickups.filter((k) => k.kind === 'sun').reduce((s, k) => s + k.value, 0)).toBe(150);
  });

  it('Doom Cap leaves a crater that blocks planting', () => {
    const b = arena();
    b.spawnPlant('doomcap', 4, 2);
    const zs = [b.spawnZombie('knight', 0, 1.5), b.spawnZombie('bucket', 4, -1.5)];
    run(b, 2);
    for (const z of zs) expect(z.dying).toBeGreaterThanOrEqual(0);
    expect(b.canPlaceAt('peashooter', 4, 2)).toBe(false);
  });

  it('Frost Cap freezes a 3x3 area for a long time', () => {
    const b = arena();
    b.spawnPlant('frostcap', 4, 2);
    const inside = b.spawnZombie('basic', 3, 0.8);
    const outside = b.spawnZombie('basic', 0, 0.8);
    run(b, 1.2);
    expect(inside.freeze).toBeGreaterThan(12);
    expect(outside.freeze).toBe(0);
  });

  it('Gust Fern keeps pushing its lane back', () => {
    const b = arena();
    const p = b.spawnPlant('gustfern', 1, 2);
    p.timer = 0.1;
    const z = b.spawnZombie('basic', 2, -1);
    run(b, 1);
    expect(z.x).toBeGreaterThan(-0.6);
  });

  it('Pepper Pult sets zombies on fire', () => {
    const b = arena();
    b.spawnPlant('pepperpult', 0, 2);
    const z = b.spawnZombie('basic', 2, 1);
    z.hp = 5000;
    run(b, 3, () => z.burnT > 0);
    expect(z.burnT).toBeGreaterThan(0);
  });

  it('Toxic Ivy poisons only its own lane', () => {
    const b = arena();
    b.spawnPlant('toxicivy', 3, 2);
    const inLane = b.spawnZombie('basic', 2, 0.5);
    const other = b.spawnZombie('basic', 3, 0.5);
    run(b, 1);
    expect(inLane.poisonT).toBeGreaterThan(0);
    expect(other.poisonT).toBe(0);
  });

  it('Ricochet Radish shots bounce into neighboring lanes', () => {
    const b = arena();
    b.spawnPlant('ricochetradish', 0, 2);
    const main = b.spawnZombie('basic', 2, 1);
    const up = b.spawnZombie('basic', 1, 1.5);
    main.hp = up.hp = 5000;
    run(b, 2);
    expect(up.hp).toBeLessThan(5000);
  });

  it('Time Thyme slows every zombie on the lawn', () => {
    const b = arena();
    const p = b.spawnPlant('timethyme', 0, 0);
    p.timer = 0.1;
    const zs = [b.spawnZombie('basic', 4, 3), b.spawnZombie('basic', 2, 0)];
    run(b, 0.5);
    for (const z of zs) expect(z.slow).toBeGreaterThan(0);
  });

  it('Pinecone Pitcher targets the back of the line', () => {
    const b = arena();
    b.spawnPlant('pineconepitcher', 0, 2);
    const front = b.spawnZombie('basic', 2, -1);
    const back = b.spawnZombie('basic', 2, 3);
    front.hp = back.hp = 5000;
    run(b, 2.5);
    expect(back.hp).toBeLessThan(5000);
    expect(front.hp).toBe(5000);
  });

  it('Drum Daisy speeds up neighbors', () => {
    const b = arena();
    b.spawnPlant('drumdaisy', 1, 2);
    const n = b.spawnPlant('peashooter', 2, 2);
    run(b, 0.1);
    expect(n.haste).toBe(1.5);
  });

  it('Lucky Clover finds coins', () => {
    const b = arena();
    b.spawnPlant('luckyclover', 0, 0);
    run(b, 12);
    expect(b.stats.coins).toBeGreaterThan(0);
  });

  it('Dandelion Drifter seeds home in on flying zombies', () => {
    const b = arena();
    b.spawnPlant('dandelion', 0, 0);
    const z = b.spawnZombie('balloon', 4, 2);
    run(b, 5, () => z.balloon <= 0);
    expect(z.balloon).toBeLessThanOrEqual(0);
  });

  it('Healing Hibiscus heals the plants around it', () => {
    const b = arena();
    b.spawnPlant('hibiscus', 2, 2);
    const w = b.spawnPlant('wallnut', 3, 3);
    w.hp = 1000;
    run(b, 6);
    expect(w.hp).toBeGreaterThan(1000);
  });
});
