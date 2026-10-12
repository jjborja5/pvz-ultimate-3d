import { describe, expect, it } from 'vitest';
import * as THREE from 'three';
import { Battle } from '../src/game/battle';
import { COLS, LANES, LEVELS, type PlantId } from '../src/game/config';
import { defaultSave, rules } from '../src/game/save';
import { mulberry } from '../src/game/environment';

/** A simple scripted player: sunflowers first, then shooters, walls and emergency cherry bombs. */
function think(b: Battle) {
  const zombiesIn = (lane: number) => b.aliveZombies.filter((z) => z.lane === lane && z.x < 5);
  const tryPlant = (id: PlantId, col: number, lane: number) => !b.plantAtTile(col, lane) && b.canPlant(id).ok && b.plantAt(id, col, lane);

  // Emergency: cherry bomb a dangerous lane.
  for (let lane = 0; lane < LANES; lane++) {
    const zs = zombiesIn(lane);
    const threat = zs.reduce((s, z) => s + z.hp + z.armor, 0);
    const close = zs.find((z) => z.x < 1.5);
    if ((threat > 1500 || close) && zs.length) {
      const col = Math.max(0, Math.min(COLS - 1, Math.round(Math.min(...zs.map((z) => z.x)) + 4)));
      if (tryPlant('cherrybomb', col, lane)) return;
    }
  }
  // Economy.
  const sunflowers = b.plants.filter((p) => p.def.id === 'sunflower').length;
  const thistles = b.plants.filter((p) => p.def.id === 'seekerthistle').length;
  if (b.loadout.includes('seekerthistle') && sunflowers >= 3 && thistles < 2) {
    for (let lane = 1; lane < LANES; lane += 2) if (tryPlant('seekerthistle', 1, lane)) return;
    return; // save up for anti-air
  }
  if (sunflowers < 5) {
    for (let lane = 0; lane < LANES; lane++) if (tryPlant('sunflower', 0, lane)) return;
  }
  // Anti-air and anti-shield specialists when needed.
  if (b.loadout.includes('seekerthistle') && b.aliveZombies.some((z) => b.isFlying(z))) {
    for (let lane = 0; lane < LANES; lane++) if (tryPlant('seekerthistle', 3, lane)) return;
  }
  if (b.loadout.includes('melonmortar')) {
    for (let lane = 0; lane < LANES; lane++) if (zombiesIn(lane).some((z) => z.shield > 0) && (tryPlant('melonmortar', 1, lane) || tryPlant('melonmortar', 2, lane))) return;
  }
  // Defend lanes with zombies first, then the rest.
  const lanes = [...Array(LANES).keys()].sort((a, c) => zombiesIn(c).length - zombiesIn(a).length);
  for (const lane of lanes) {
    for (const col of [1, 2]) {
      if (tryPlant('repeater', col, lane) || tryPlant('peashooter', col, lane)) return;
    }
  }
  for (const lane of lanes) {
    if (zombiesIn(lane).some((z) => z.armor > 0 || z.def.vault) && (tryPlant('towernut', 6, lane) || tryPlant('wallnut', 6, lane))) return;
  }
  if (sunflowers < 10) for (let lane = 0; lane < LANES; lane++) if (tryPlant('sunflower', 3, lane)) return;
  for (const lane of lanes) if (tryPlant('snowpea', 4, lane) || tryPlant('repeater', 5, lane)) return;
}

describe('balance', () => {
  for (const level of LEVELS) {
    it(`level ${level.id} is beatable without Ultimate Mode`, () => {
      const save = defaultSave();
      save.ultimate.enabled = false;
      const kinds = new Set(level.waves.flatMap((w) => w.zombies));
      const loadout = ['sunflower', 'peashooter', 'repeater', kinds.has('vaulter') ? 'towernut' : 'wallnut', 'cherrybomb'];
      loadout.push(kinds.has('balloon') ? 'seekerthistle' : kinds.has('door') ? 'melonmortar' : 'snowpea');
      const b = new Battle(new THREE.Scene(), level, loadout, rules(save), {
        rng: mulberry(42),
        autoCollectSun: true,
      });
      b.start();
      const dt = 1 / 30;
      let thinkT = 0;
      for (let t = 0; t < 1200 && b.phase === 'playing'; t += dt) {
        b.update(dt);
        thinkT += dt;
        if (thinkT > 0.5) {
          thinkT = 0;
          think(b);
        }
      }
      expect(b.phase).toBe('won');
    });
  }
});
