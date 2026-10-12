// Batch 2: each plant's signature mechanic, verified in a real battle simulation.
import { describe, expect, it } from 'vitest';
import { arena, run } from './helpers';

describe('batch 2 signature mechanics', () => {
  it('Snapjaw swallows a zombie, then has to chew; bosses only get bitten', () => {
    const b = arena();
    const p = b.spawnPlant('snapjaw', 2, 2);
    const a = b.spawnZombie('basic', 2, -1.3);
    run(b, 1);
    expect(a.dying).toBeGreaterThanOrEqual(0);
    expect(p.s.chew).toBeGreaterThan(20);
    const boss = b.spawnZombie('brute', 1, -1.3);
    const p2 = b.spawnPlant('snapjaw', 2, 1);
    run(b, 0.5);
    expect(boss.dying).toBe(-1);
    expect(boss.hp).toBeLessThan(3000);
    expect(p2.s.chew).toBeGreaterThan(0);
  });

  it('Squashling leaps onto a zombie just behind it', () => {
    const b = arena();
    b.spawnPlant('squashling', 4, 2);
    const z = b.spawnZombie('basic', 2, -0.6);
    z.hypno = false;
    run(b, 2);
    expect(z.dying).toBeGreaterThanOrEqual(0);
  });

  it('Thornmat is walked over, not eaten, and hurts zombies on it', () => {
    const b = arena();
    const p = b.spawnPlant('thornmat', 3, 2);
    const z = b.spawnZombie('basic', 2, -0.5);
    z.hp = 5000;
    run(b, 6);
    expect(p.hp).toBe(p.maxHp);
    expect(z.hp).toBeLessThan(5000);
    expect(z.x).toBeLessThan(p.x);
  });

  it('Puffcap only reaches 3 tiles', () => {
    const b = arena();
    b.spawnPlant('puffcap', 0, 1);
    const far = b.spawnZombie('basic', 1, 2);
    far.def = { ...far.def, speed: 0 };
    b.spawnPlant('puffcap', 0, 3);
    const near = b.spawnZombie('basic', 3, -2);
    near.def = { ...near.def, speed: 0 };
    run(b, 4);
    expect(far.hp).toBe(190);
    expect(near.hp).toBeLessThan(190);
  });

  it('Fumecap fumes pass through screen doors and multiple zombies', () => {
    const b = arena();
    b.spawnPlant('fumecap', 1, 2);
    const d = b.spawnZombie('door', 2, -1.5);
    const behind = b.spawnZombie('basic', 2, -0.6);
    d.hp = behind.hp = 3000;
    run(b, 1.5);
    expect(d.hp).toBeLessThan(3000);
    expect(behind.hp).toBeLessThan(3000);
  });

  it('Needle Cactus pops balloons and pierces two zombies', () => {
    const b = arena();
    b.spawnPlant('needlecactus', 0, 2);
    const bal = b.spawnZombie('balloon', 2, 2);
    run(b, 3, () => bal.balloon <= 0);
    expect(bal.balloon).toBeLessThanOrEqual(0);
    const b2 = arena();
    b2.spawnPlant('needlecactus', 0, 2);
    const z1 = b2.spawnZombie('basic', 2, 0);
    const z2 = b2.spawnZombie('basic', 2, 1);
    z1.hp = z2.hp = 3000;
    run(b2, 1);
    expect(z1.hp).toBeLessThan(3000);
    expect(z2.hp).toBeLessThan(3000);
  });

  it('Boomerose boomerangs hit three zombies going out', () => {
    const b = arena();
    b.spawnPlant('boomerose', 0, 2);
    const zs = [b.spawnZombie('basic', 2, -2.5), b.spawnZombie('basic', 2, -1.5), b.spawnZombie('basic', 2, -0.5)];
    for (const z of zs) z.hp = 3000;
    run(b, 1.2);
    for (const z of zs) expect(z.hp).toBeLessThan(3000);
  });

  it('Cabbage Lobber arcs over a screen door', () => {
    const b = arena();
    b.spawnPlant('cabbagelobber', 1, 2);
    const z = b.spawnZombie('door', 2, 2);
    z.hp = 3000;
    run(b, 3);
    expect(z.hp).toBeLessThan(3000);
    expect(z.shield).toBe(1100);
  });

  it('Hex Nut regenerates', () => {
    const b = arena();
    const p = b.spawnPlant('hexnut', 2, 2);
    p.hp = 1000;
    run(b, 4);
    expect(p.hp).toBeGreaterThan(1080);
  });

  it('Spiky Durian thorns ignore armor', () => {
    const b = arena();
    b.spawnPlant('spikydurian', 2, 2);
    const z = b.spawnZombie('cone', 2, -1.6);
    run(b, 4);
    expect(z.armor).toBe(370);
    expect(z.hp).toBeLessThan(190);
  });

  it('Leaf Guard swats biters back exactly three times', () => {
    const b = arena();
    const p = b.spawnPlant('leafguard', 2, 2);
    b.spawnZombie('basic', 2, -1.6);
    run(b, 40);
    expect(p.s.kb).toBe(0);
  });

  it('Boom Nut explodes when it is finally eaten', () => {
    const b = arena();
    const p = b.spawnPlant('boomnut', 2, 2);
    const eater = b.spawnZombie('basic', 2, -1.6);
    const side = b.spawnZombie('basic', 1, -1.5);
    p.hp = 200;
    run(b, 4);
    expect(p.dead).toBe(true);
    expect(eater.dying).toBeGreaterThanOrEqual(0);
    expect(side.dying).toBeGreaterThanOrEqual(0);
  });

  it('Pumpkin Shell can be planted on top of a plant', () => {
    const b = arena();
    b.spawnPlant('peashooter', 2, 2);
    expect(b.canPlaceAt('pumpkinshell', 2, 2)).toBe(true);
    expect(b.canPlaceAt('peashooter', 2, 2)).toBe(false);
    b.spawnPlant('pumpkinshell', 2, 2);
    expect(b.canPlaceAt('pumpkinshell', 2, 2)).toBe(false);
  });

  it('Flame Dragon burns zombies in adjacent lanes; Frost Dragon chills them', () => {
    const b = arena();
    b.spawnPlant('flamedragon', 2, 0);
    const f = b.spawnZombie('basic', 1, -1.2);
    b.spawnPlant('frostdragon', 2, 4);
    const c = b.spawnZombie('basic', 3, -1.2);
    f.hp = c.hp = 3000;
    run(b, 1.5);
    expect(f.burnT).toBeGreaterThan(0);
    expect(c.slow).toBeGreaterThan(0);
  });

  it('Grapeburst hits zombies in several directions', () => {
    const b = arena();
    b.spawnPlant('grapeburst', 4, 2);
    const zs = [b.spawnZombie('basic', 2, 1.5), b.spawnZombie('basic', 2, -1.5), b.spawnZombie('basic', 0, 0)];
    for (const z of zs) z.hp = 3000;
    run(b, 3);
    expect(zs.filter((z) => z.hp < 3000).length).toBeGreaterThanOrEqual(2);
  });

  it('Magma Guava leaves lava that blocks planting and burns walkers', () => {
    const b = arena();
    b.spawnPlant('magmaguava', 4, 2);
    run(b, 1.2);
    expect(b.canPlaceAt('peashooter', 4, 2)).toBe(false);
    const z = b.spawnZombie('basic', 2, 0.4);
    z.hp = 3000;
    run(b, 2);
    expect(z.hp).toBeLessThan(3000);
  });

  it('Wasabi Lash hits zombies in three lanes at once', () => {
    const b = arena();
    b.spawnPlant('wasabilash', 3, 2);
    const zs = [b.spawnZombie('basic', 1, -0.6), b.spawnZombie('basic', 3, -0.6)];
    for (const z of zs) z.hp = 3000;
    run(b, 1.5);
    for (const z of zs) expect(z.hp).toBeLessThan(3000);
  });

  it('Poke Okra stabs very quickly', () => {
    const b = arena();
    b.spawnPlant('pokeokra', 3, 2);
    const z = b.spawnZombie('basic', 2, -0.4);
    z.hp = 3000;
    run(b, 2);
    expect(3000 - z.hp).toBeGreaterThanOrEqual(15 * 5);
  });

  it('Storm Berry strikes zombies anywhere on the lawn', () => {
    const b = arena();
    b.spawnPlant('stormberry', 0, 0);
    const z = b.spawnZombie('basic', 4, 3);
    z.hp = 3000;
    run(b, 14);
    expect(z.hp).toBeLessThanOrEqual(2100);
  });

  it('Plasma Citrus must charge before its heavy shot', () => {
    const b = arena();
    b.spawnPlant('plasmacitrus', 0, 2);
    const z = b.spawnZombie('basic', 2, 0);
    z.def = { ...z.def, speed: 0 };
    z.hp = 3000;
    run(b, 4);
    expect(z.hp).toBe(3000);
    run(b, 6);
    expect(z.hp).toBeLessThanOrEqual(2600);
  });

  it('Hex Hazel turns a zombie into a Puffcap', () => {
    const b = arena();
    b.spawnPlant('hexhazel', 1, 2);
    const z = b.spawnZombie('basic', 2, 0);
    run(b, 3);
    expect(z.dying).toBeGreaterThanOrEqual(0);
    expect(b.plants.some((p) => p.def.id === 'puffcap')).toBe(true);
  });

  it('Snapjaw Plant Food devours several zombies in a row', () => {
    const b = arena();
    b.spawnPlant('snapjaw', 1, 2);
    const zs = [b.spawnZombie('basic', 2, -2.4), b.spawnZombie('basic', 2, -1.6), b.spawnZombie('basic', 2, -0.6)];
    b.usePlantFood(1, 2);
    run(b, 3);
    expect(zs.filter((z) => z.dying >= 0).length).toBeGreaterThanOrEqual(2);
  });
});
