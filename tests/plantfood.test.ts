// Plant Food audit: every plant's Plant Food must produce a real, measurable effect quickly.
// Each plant is run twice from an identical setup — once with Plant Food, once without — and the
// Plant Food run must beat the control run in at least one gameplay metric within 1.5 seconds.
import { describe, expect, it } from 'vitest';
import type { Battle, ZombieEntity } from '../src/game/battle';
import { PLANT_LIST, type ZombieId } from '../src/game/config';
import { arena, run } from './helpers';

const WINDOW = 1.5;

function setup(id: string, unlimited = false, far = false) {
  const b = arena({ seed: 11 });
  b.rules = { ...b.rules, unlimitedPlantFood: unlimited };
  b.plantFood = 3;
  const p = b.spawnPlant(id, 2, 2);
  b.spawnPlant('sunflower', 0, 0);
  const wall = b.spawnPlant('wallnut', 0, 4);
  wall.hp = 500;
  const zs: [ZombieId, number, number][] = far
    ? [
        ['basic', 2, 2.8],
        ['bucket', 2, 3.6],
        ['cone', 1, 3.2],
        ['basic', 3, 3.8],
      ]
    : [
        ['basic', 2, 0.4],
        ['bucket', 2, 2.5],
        ['basic', 1, -1.2],
        ['cone', 3, 1.5],
        ['basic', 0, 3],
        ['door', 4, 2],
      ];
  const zombies: { z: ZombieEntity; total: number; x0: number; lane0: number }[] = [];
  for (const [zid, lane, x] of zs) {
    const z = b.spawnZombie(zid, lane, x);
    z.def = { ...z.def, speed: 0 }; // keep positions identical between runs
    z.hp = 4000;
    zombies.push({ z, total: z.hp + z.armor + z.shield, x0: x, lane0: lane });
  }
  return { b, p, zombies };
}

function metrics(b: Battle, zombies: ReturnType<typeof setup>['zombies']) {
  let dmg = 0;
  let status = 0;
  let knock = 0;
  let allies = 0;
  let moved = 0;
  for (const { z, total, x0, lane0 } of zombies) {
    dmg += z.dying >= 0 ? total : total - (Math.max(0, z.hp) + z.armor + z.shield);
    if (z.freeze > 0 || z.stun > 0 || z.slow > 0 || z.poisonT > 0 || z.burnT > 0 || z.weakenT > 0 || z.shrunk) status++;
    if (z.hypno) allies++;
    knock += Math.max(0, z.x - x0);
    if (z.lane !== lane0) moved++;
  }
  allies += b.zombies.filter((z) => z.hypno && z.ally).length;
  return {
    dmg,
    status,
    knock,
    allies,
    moved,
    sun: b.pickups.filter((k) => k.kind === 'sun').reduce((s, k) => s + k.value, 0) + b.stats.sunCollected,
    plants: b.plants.filter((p) => !p.dead).length,
    shell: b.plants.reduce((s, p) => s + p.shell, 0),
    heal: b.plants.reduce((s, p) => s + (p.dead ? 0 : p.hp), 0),
    pf: b.plantFood + b.pickups.filter((k) => k.kind === 'plantfood').length,
    projectiles: b.stats.shots,
  };
}

function improvement(pf: ReturnType<typeof metrics>, ctl: ReturnType<typeof metrics>) {
  const why: string[] = [];
  if (pf.dmg > ctl.dmg + 40) why.push(`damage +${Math.round(pf.dmg - ctl.dmg)}`);
  if (pf.status > ctl.status) why.push('statuses');
  if (pf.knock > ctl.knock + 0.3) why.push('knockback');
  if (pf.allies > ctl.allies) why.push('allies');
  if (pf.moved > ctl.moved) why.push('lane change');
  if (pf.sun > ctl.sun) why.push(`sun +${pf.sun - ctl.sun}`);
  if (pf.plants > ctl.plants) why.push('new plants');
  if (pf.shell > ctl.shell) why.push('armor');
  if (pf.heal > ctl.heal + 50) why.push('healing');
  if (pf.pf > ctl.pf - 1) why.push('plant food');
  if (pf.projectiles > ctl.projectiles + 3) why.push(`shots +${pf.projectiles - ctl.projectiles}`);
  return why;
}

describe('Plant Food audit (all plants)', () => {
  for (const def of PLANT_LIST) {
    if (def.noPlantFood) {
      it(`${def.id}: refuses Plant Food (instant plant)`, () => {
        const { b } = setup(def.id);
        expect(b.usePlantFood(2, 2)).toBe(false);
        expect(b.plantFood).toBe(3);
      });
      continue;
    }
    it(`${def.id}: Plant Food has a real effect within ${WINDOW}s`, () => {
      const A = setup(def.id);
      const B = setup(def.id);
      expect(A.b.usePlantFood(2, 2)).toBe(true);
      expect(A.b.plantFood).toBe(2);
      run(A.b, WINDOW);
      run(B.b, WINDOW);
      const why = improvement(metrics(A.b, A.zombies), metrics(B.b, B.zombies));
      expect(why.length, `${def.id} (${def.pf.type}) Plant Food did nothing measurable`).toBeGreaterThan(0);
      // Every activation is announced so the player sees what happened.
      expect(A.b.events.some((e) => e.type === 'pf')).toBe(true);
    });
  }

  for (const def of PLANT_LIST.filter((p) => !p.noPlantFood)) {
    it(`${def.id}: Plant Food still does something when zombies are far away`, () => {
      const A = setup(def.id, false, true);
      const B = setup(def.id, false, true);
      A.b.usePlantFood(2, 2);
      run(A.b, 3);
      run(B.b, 3);
      const why = improvement(metrics(A.b, A.zombies), metrics(B.b, B.zombies));
      expect(why.length, `${def.id} (${def.pf.type}) Plant Food did nothing with distant zombies`).toBeGreaterThan(0);
    });
  }

  it('unlimited Plant Food never runs out and can be used repeatedly', () => {
    const { b } = setup('peashooter', true);
    for (let i = 0; i < 5; i++) {
      expect(b.usePlantFood(2, 2)).toBe(true);
      run(b, 0.2);
    }
    expect(b.plantFood).toBe(3);
  });

  it('Plant Food works on a plant inside a Pumpkin Shell and on the shell itself', () => {
    const { b, p } = setup('peashooter');
    const shell = b.spawnPlant('pumpkinshell', 2, 2);
    expect(b.usePlantFood(2, 2, p)).toBe(true);
    expect(p.pfTime).toBeGreaterThan(0);
    expect(b.usePlantFood(2, 2, shell)).toBe(true);
    expect(shell.shell).toBeGreaterThan(0);
  });
});
