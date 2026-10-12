// Batch 3: each plant's signature mechanic, verified in a real battle simulation.
import { describe, expect, it } from 'vitest';
import { arena, run } from './helpers';

describe('batch 3 signature mechanics', () => {
  it('Rock Pea pushes zombies back', () => {
    const b = arena();
    b.spawnPlant('rockpea', 0, 2);
    const z = b.spawnZombie('basic', 2, 0);
    z.hp = 5000;
    run(b, 6);
    expect(z.x).toBeGreaterThan(0);
  });

  it('Shade Pea curses zombies to take more damage', () => {
    const b = arena();
    b.spawnPlant('shadepea', 0, 2);
    const z = b.spawnZombie('basic', 2, 2);
    z.hp = 5000;
    run(b, 2.5, () => z.weakenT > 0);
    expect(z.weakenAmp).toBeCloseTo(0.5);
    const before = z.hp;
    b.damageZombie(z, 100);
    expect(before - z.hp).toBeCloseTo(150);
  });

  it('Ancient Sunflower makes 75-sun suns', () => {
    const b = arena();
    b.spawnPlant('ancientflower', 0, 0);
    run(b, 10, () => b.pickups.some((k) => k.kind === 'sun'));
    expect(b.pickups.find((k) => k.kind === 'sun')!.value).toBe(75);
  });

  it('Moon Blossom speeds up neighboring sun producers only', () => {
    const b = arena();
    b.spawnPlant('moonblossom', 1, 1);
    const near = b.spawnPlant('sunflower', 2, 1);
    const far = b.spawnPlant('sunflower', 6, 3);
    run(b, 0.2);
    expect(near.produceBuff).toBe(1.5);
    expect(far.produceBuff).toBe(1);
  });

  it('Stone Mine re-arms after its first blast', () => {
    const b = arena();
    const p = b.spawnPlant('stonemine', 2, 2);
    p.armed = true;
    p.timer = 0;
    const z1 = b.spawnZombie('basic', 2, -1.5);
    run(b, 1.5);
    expect(z1.dying).toBeGreaterThanOrEqual(0);
    expect(p.dead).toBe(false);
    run(b, 7);
    const z2 = b.spawnZombie('basic', 2, -1.5);
    run(b, 1.5);
    expect(z2.dying).toBeGreaterThanOrEqual(0);
    expect(p.dead).toBe(true);
  });

  it('Boulder Nut survives a Mega Brute smash that flattens a Wall-nut', () => {
    const b = arena();
    const boulder = b.spawnPlant('bouldernut', 2, 1);
    const wall = b.spawnPlant('wallnut', 2, 3);
    b.spawnZombie('brute', 1, -1.4);
    b.spawnZombie('brute', 3, -1.4);
    run(b, 2.5);
    expect(wall.dead).toBe(true);
    expect(boulder.dead).toBe(false);
  });

  it('Pomegrenade bombs splash and burn', () => {
    const b = arena();
    b.spawnPlant('pomegrenade', 0, 2);
    const a = b.spawnZombie('basic', 2, 1);
    const c = b.spawnZombie('basic', 2, 1.6);
    a.hp = c.hp = 5000;
    run(b, 4);
    expect(c.hp).toBeLessThan(5000);
    expect(a.burnT + c.burnT).toBeGreaterThan(0);
  });

  it('Firecracker Fig explodes on the first bite', () => {
    const b = arena();
    b.spawnPlant('firecrackerfig', 3, 2);
    const eater = b.spawnZombie('basic', 2, -0.6);
    const side = b.spawnZombie('cone', 3, -0.4);
    run(b, 2);
    expect(eater.dying).toBeGreaterThanOrEqual(0);
    expect(side.dying).toBeGreaterThanOrEqual(0);
  });

  it('Torch Vine turns snow peas back into plain peas', () => {
    const b = arena();
    b.spawnPlant('snowpea', 0, 2);
    b.spawnPlant('torchvine', 1, 2);
    const z = b.spawnZombie('basic', 2, 1);
    z.hp = 5000;
    run(b, 3);
    expect(z.hp).toBeLessThan(5000);
    expect(z.slow).toBe(0);
  });

  it('Shock Currant zaps zombies that walk over it and is never eaten', () => {
    const b = arena();
    const p = b.spawnPlant('shockcurrant', 4, 2);
    const z = b.spawnZombie('basic', 2, 0.4);
    z.hp = 5000;
    run(b, 6);
    expect(z.hp).toBeLessThan(5000);
    expect(p.hp).toBe(p.maxHp);
  });

  it('Volt Tea pulses all around it', () => {
    const b = arena();
    b.spawnPlant('volttea', 4, 2);
    const zs = [b.spawnZombie('basic', 1, 0.5), b.spawnZombie('basic', 3, -0.5)];
    for (const z of zs) z.hp = 5000;
    run(b, 2);
    for (const z of zs) expect(z.hp).toBeLessThan(5000);
  });

  it('Sun Lens spends sun for each shot', () => {
    const b = arena({ ultimate: false });
    b.sun = 100;
    b.spawnPlant('sunlens', 0, 2);
    const z = b.spawnZombie('basic', 2, 2);
    z.hp = 5000;
    run(b, 1);
    expect(b.sun).toBe(75);
    expect(z.hp).toBeLessThan(5000);
    b.sun = 0;
    const hp = z.hp;
    run(b, 4);
    expect(z.hp).toBeGreaterThan(hp - 60); // only burn ticks, no new shots
  });

  it('Shadow Lobber curses its target', () => {
    const b = arena();
    b.spawnPlant('shadowlobber', 0, 2);
    const z = b.spawnZombie('basic', 2, 1);
    z.hp = 5000;
    run(b, 3, () => z.weakenT > 0);
    expect(z.weakenT).toBeGreaterThan(0);
  });

  it('Gloomcap poisons everything around it', () => {
    const b = arena();
    b.spawnPlant('gloomcap', 4, 2);
    const z = b.spawnZombie('knight', 1, 0.6);
    run(b, 2);
    expect(z.poisonT).toBeGreaterThan(0);
  });

  it('Nightbloom boosts neighbor damage', () => {
    const b = arena();
    b.spawnPlant('nightbloom', 1, 2);
    const shooter = b.spawnPlant('peashooter', 0, 2);
    run(b, 0.1);
    expect(b.damageOf(shooter, 20)).toBeCloseTo(30);
  });

  it('Grim Rose drags one zombie underground, then is gone', () => {
    const b = arena();
    const p = b.spawnPlant('grimrose', 3, 2);
    const z = b.spawnZombie('bucket', 2, 0);
    run(b, 2);
    expect(z.dying).toBeGreaterThanOrEqual(0);
    expect(p.dead).toBe(true);
  });

  it('Mind Flower hypnotizes a nearby zombie', () => {
    const b = arena();
    const p = b.spawnPlant('mindflower', 3, 2);
    p.timer = 0.1;
    const z = b.spawnZombie('cone', 3, 0);
    run(b, 1);
    expect(z.hypno).toBe(true);
  });

  it('Shrink Violet halves zombie health in a 3x3 area', () => {
    const b = arena();
    b.spawnPlant('shrinkviolet', 4, 2);
    const z = b.spawnZombie('cone', 3, 0.5);
    run(b, 1.2);
    expect(z.shrunk).toBe(true);
    expect(z.hp).toBeLessThanOrEqual(95);
    expect(z.armor).toBeLessThanOrEqual(185);
  });

  it('Headbutt Lettuce knocks zombies back a whole tile', () => {
    const b = arena();
    b.spawnPlant('headbutt', 0, 2);
    const z = b.spawnZombie('basic', 2, 1);
    z.hp = 5000;
    run(b, 3, () => z.x > 1.5);
    expect(z.x).toBeGreaterThan(1.5);
  });

  it('Frost Bloom freezes every zombie on the lawn', () => {
    const b = arena();
    b.spawnPlant('frostbloom', 0, 0);
    const zs = [b.spawnZombie('basic', 4, 3), b.spawnZombie('basic', 2, 0), b.spawnZombie('basic', 0, 4)];
    run(b, 1.2);
    for (const z of zs) expect(z.freeze).toBeGreaterThan(0);
  });

  it('Gale Kale blows its lane back; Fan Clover blows balloons away', () => {
    const b = arena();
    b.spawnPlant('galekale', 0, 2);
    const z = b.spawnZombie('basic', 2, 0);
    const other = b.spawnZombie('basic', 3, 0);
    run(b, 1);
    expect(z.x).toBeGreaterThan(2);
    expect(other.x).toBeLessThan(0.1);
    const b2 = arena();
    b2.spawnPlant('fanclover', 0, 0);
    const bal = b2.spawnZombie('balloon', 3, 1);
    run(b2, 1);
    expect(bal.dying).toBeGreaterThanOrEqual(0);
  });

  it('Bulb Bowler bulbs bounce into other lanes', () => {
    const b = arena();
    b.spawnPlant('bulbbowler', 0, 2);
    b.spawnZombie('basic', 2, -1).hp = 5000;
    const others = [b.spawnZombie('basic', 1, 0.6), b.spawnZombie('basic', 3, 0.6)];
    for (const z of others) z.hp = 5000;
    run(b, 4);
    expect(others.some((z) => z.hp < 5000)).toBe(true);
  });

  it('Veil-mint hides plants from zombies', () => {
    const b = arena();
    const w = b.spawnPlant('wallnut', 2, 2);
    b.spawnPlant('veilmint', 6, 0);
    const z = b.spawnZombie('basic', 2, -1.4);
    run(b, 3);
    expect(w.hp).toBe(w.maxHp);
    expect(z.x).toBeLessThan(w.x);
  });
});
