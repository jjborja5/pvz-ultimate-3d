// Batch 1: each plant's signature mechanic, verified in a real battle simulation.
import { describe, expect, it } from 'vitest';
import { arena, run } from './helpers';

describe('batch 1 signature mechanics', () => {
  it('Tri-Pea hits the lanes above and below', () => {
    const b = arena();
    b.spawnPlant('tripea', 1, 2);
    const up = b.spawnZombie('basic', 1, 2);
    const down = b.spawnZombie('basic', 3, 2);
    up.hp = down.hp = 5000;
    run(b, 4);
    expect(up.hp).toBeLessThan(5000);
    expect(down.hp).toBeLessThan(5000);
  });

  it('Peek-a-Pea shoots zombies behind it', () => {
    const b = arena();
    b.spawnPlant('peekapea', 5, 2);
    const z = b.spawnZombie('basic', 2, -2);
    z.hp = 5000;
    run(b, 3);
    expect(z.hp).toBeLessThan(5000);
  });

  it('Ember Pea burns and splashes', () => {
    const b = arena();
    b.spawnPlant('emberpea', 1, 2);
    const a = b.spawnZombie('basic', 2, 1);
    const c = b.spawnZombie('basic', 2, 1.3);
    a.hp = c.hp = 5000;
    run(b, 2.5, () => a.burnT > 0 && c.hp < 5000);
    expect(a.burnT).toBeGreaterThan(0);
    expect(c.hp).toBeLessThan(5000);
  });

  it('Snow Pea chills; fire melts the chill', () => {
    const b = arena();
    b.spawnPlant('snowpea', 1, 2);
    const z = b.spawnZombie('basic', 2, 2);
    z.hp = 5000;
    run(b, 3, () => z.slow > 0);
    expect(z.slow).toBeGreaterThan(0);
    b.applyStatus(z, { burn: 5 });
    expect(z.slow).toBe(0);
  });

  it('Gatling Pod fires four peas per burst', () => {
    const b = arena();
    b.spawnPlant('gatlingpod', 0, 2);
    b.spawnZombie('basic', 2, 3.5).hp = 5000;
    let max = 0;
    run(b, 1.2, () => ((max = Math.max(max, b.projectiles.length)), false));
    expect(max).toBeGreaterThanOrEqual(4);
  });

  it('Double Bloom makes two suns at once; Sunspore grows into full suns', () => {
    const b = arena();
    b.spawnPlant('doublebloom', 0, 0);
    run(b, 9, () => b.pickups.filter((p) => p.kind === 'sun').length >= 2);
    expect(b.pickups.filter((p) => p.kind === 'sun').length).toBeGreaterThanOrEqual(2);
    const s = b.spawnPlant('sunspore', 3, 3);
    expect(s.s.amount).toBe(25);
    run(b, 61);
    expect(s.s.amount).toBe(50);
  });

  it('Tower Nut stops a vaulter; Wall-nut gets vaulted over', () => {
    const b = arena();
    const tall = b.spawnPlant('towernut', 3, 1);
    const v1 = b.spawnZombie('vaulter', 1, 0);
    const wall = b.spawnPlant('wallnut', 3, 3);
    const v2 = b.spawnZombie('vaulter', 3, 0);
    run(b, 8);
    expect(v1.x).toBeGreaterThan(tall.x);
    expect(v1.eating).toBe(tall);
    expect(v2.x).toBeLessThan(wall.x);
  });

  it('Blaze Pepper burns its whole lane only', () => {
    const b = arena();
    b.spawnPlant('blazepepper', 0, 2);
    const inLane = [b.spawnZombie('basic', 2, -1), b.spawnZombie('basic', 2, 3.5)];
    const other = b.spawnZombie('basic', 1, 1);
    run(b, 2);
    for (const z of inLane) expect(z.dying).toBeGreaterThanOrEqual(0);
    expect(other.dying).toBe(-1);
  });

  it('Butter Cob lobs over a screen door and sometimes stuns', () => {
    const b = arena({ seed: 3 });
    b.spawnPlant('buttercob', 1, 2);
    const z = b.spawnZombie('door', 2, 2.5);
    z.hp = 5000;
    let stunned = false;
    run(b, 30, () => ((stunned = stunned || z.stun > 0), stunned && z.hp < 5000));
    expect(z.hp).toBeLessThan(5000);
    expect(z.shield).toBe(1100);
    expect(stunned).toBe(true);
  });

  it('Peashooter peas are blocked by a screen door', () => {
    const b = arena();
    b.spawnPlant('peashooter', 1, 2);
    const z = b.spawnZombie('door', 2, 2.5);
    run(b, 4);
    expect(z.shield).toBeLessThan(1100);
    expect(z.hp).toBe(190);
  });

  it('Melon Mortar splashes and Frost Melon chills the whole group', () => {
    const b = arena();
    b.spawnPlant('melonmortar', 1, 1);
    b.spawnPlant('frostmelon', 1, 3);
    const m1 = b.spawnZombie('basic', 1, 2);
    const m2 = b.spawnZombie('basic', 1, 2.4);
    const f1 = b.spawnZombie('basic', 3, 2);
    const f2 = b.spawnZombie('basic', 3, 2.4);
    for (const z of [m1, m2, f1, f2]) z.hp = 5000;
    run(b, 5);
    expect(m1.hp).toBeLessThan(5000);
    expect(m2.hp).toBeLessThan(5000);
    expect(f1.slow).toBeGreaterThan(0);
    expect(f2.slow).toBeGreaterThan(0);
  });

  it('Punch Choy hits zombies on both sides', () => {
    const b = arena();
    b.spawnPlant('punchchoy', 4, 2);
    const back = b.spawnZombie('basic', 2, -0.7);
    back.hypno = false;
    back.hp = 5000;
    run(b, 2);
    expect(back.hp).toBeLessThan(5000);
  });

  it('Beam Bean hits every zombie in the lane at once and ignores shields', () => {
    const b = arena();
    b.spawnPlant('beambean', 0, 2);
    const zs = [b.spawnZombie('basic', 2, 0), b.spawnZombie('door', 2, 2), b.spawnZombie('basic', 2, 3.5)];
    for (const z of zs) z.hp = 5000;
    run(b, 1.5);
    for (const z of zs) expect(z.hp).toBeLessThan(5000);
    expect(zs[1].shield).toBe(1100);
  });

  it('Zap Reed chains lightning into other lanes', () => {
    const b = arena();
    b.spawnPlant('zapreed', 2, 2);
    const a = b.spawnZombie('basic', 2, 0);
    const c = b.spawnZombie('basic', 3, 0.5);
    a.hp = c.hp = 5000;
    run(b, 2);
    expect(a.hp).toBeLessThan(5000);
    expect(c.hp).toBeLessThan(5000);
  });

  it('Star Sprout hits a zombie behind it', () => {
    const b = arena();
    b.spawnPlant('starsprout', 6, 2);
    const z = b.spawnZombie('basic', 2, -2);
    z.hp = 5000;
    run(b, 4);
    expect(z.hp).toBeLessThan(5000);
  });

  it('Seeker Thistle pops balloons that straight shooters cannot reach', () => {
    const b = arena();
    b.spawnPlant('peashooter', 1, 1);
    const z1 = b.spawnZombie('balloon', 1, 3);
    run(b, 4);
    expect(z1.balloon).toBeGreaterThan(0);
    const b2 = arena();
    b2.spawnPlant('seekerthistle', 1, 3);
    const z2 = b2.spawnZombie('balloon', 1, 3);
    run(b2, 4, () => z2.balloon <= 0);
    expect(z2.balloon).toBeLessThanOrEqual(0);
  });

  it('Hypno Cap turns its eater into an ally that fights other zombies', () => {
    const b = arena();
    b.spawnPlant('hypnocap', 2, 2);
    const eater = b.spawnZombie('basic', 2, -1.6);
    run(b, 2, () => eater.hypno);
    expect(eater.hypno).toBe(true);
    const enemy = b.spawnZombie('basic', 2, eater.x + 1.2);
    run(b, 6);
    expect(enemy.hp).toBeLessThan(190);
  });

  it('Frostbite Lettuce freezes the first zombie to touch it', () => {
    const b = arena();
    const p = b.spawnPlant('frostlettuce', 2, 2);
    const z = b.spawnZombie('basic', 2, -1.4);
    run(b, 3, () => z.freeze > 0);
    expect(z.freeze).toBeGreaterThan(0);
    expect(p.dead).toBe(true);
  });

  it('Potato Mine is harmless until armed', () => {
    const b = arena();
    b.spawnPlant('potatomine', 2, 2);
    const z = b.spawnZombie('basic', 2, -1.6);
    run(b, 3);
    expect(z.dying).toBe(-1);
  });

  it('Repeater Plant Food mega pea pierces the whole lane', () => {
    const b = arena();
    b.spawnPlant('repeater', 0, 2);
    const zs = [b.spawnZombie('basic', 2, 0), b.spawnZombie('basic', 2, 1.5), b.spawnZombie('basic', 2, 3)];
    b.usePlantFood(0, 2);
    run(b, 2.5);
    for (const z of zs) expect(z.dying).toBeGreaterThanOrEqual(0);
  });

  it('Wall-nut Plant Food adds an armor shell', () => {
    const b = arena();
    const w = b.spawnPlant('wallnut', 2, 2);
    b.usePlantFood(2, 2);
    expect(w.shell).toBe(w.maxHp);
  });

  it('Hypno Cap Plant Food summons an allied Mega Brute', () => {
    const b = arena();
    b.spawnPlant('hypnocap', 2, 2);
    b.usePlantFood(2, 2);
    expect(b.zombies.some((z) => z.hypno && z.def.id === 'brute')).toBe(true);
  });

  it('Maximum Damage (Ultimate) one-shots tough zombies', () => {
    const b = arena();
    b.rules = { ...b.rules, maxDamage: true };
    b.spawnPlant('peashooter', 1, 2);
    const z = b.spawnZombie('bucket', 2, 2);
    run(b, 1.5, () => z.armor === 0);
    expect(z.armor).toBe(0);
  });
});
