import * as THREE from 'three';
import { Battle } from '../src/game/battle';
import { PLANT_ORDER, type LevelDef } from '../src/game/config';
import { defaultSave, rules } from '../src/game/save';
import { mulberry } from '../src/game/environment';

/** A quiet test lawn: no waves arrive, sun is unlimited, plants are level 1 (base stats). */
export function arena(o: { invincible?: boolean; seed?: number; ultimate?: boolean } = {}) {
  const save = defaultSave();
  save.ultimate.enabled = o.ultimate ?? true;
  save.ultimate.maxUpgrades = false;
  save.ultimate.invincible = !!o.invincible;
  save.ultimate.instantRecharge = true;
  const level: LevelDef = { id: 'test', world: 0, index: 0, name: 'Test', startSun: 9999, firstWaveDelay: 1e9, rewardCoins: 0, waves: [{ zombies: ['basic'] }] };
  const b = new Battle(new THREE.Scene(), level, PLANT_ORDER, rules(save), { rng: mulberry(o.seed ?? 7) });
  b.start();
  (b as unknown as { skyTimer: number }).skyTimer = 1e9;
  return b;
}

export function run(b: Battle, seconds: number, until?: () => boolean) {
  const dt = 1 / 30;
  for (let t = 0; t < seconds; t += dt) {
    b.update(dt);
    if (until && until()) return true;
  }
  return false;
}
