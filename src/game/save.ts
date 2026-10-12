// Persistent save data (progress, resources, Ultimate Mode and settings) stored in localStorage.
// Version history:
//   v1 (Phase 1): 5 levels, 7 plants, levels capped at 5.
//   v2 (Phase 2): 10 World 1 levels (old 1-4 -> 1-5, old 1-5 -> 1-10), 100-plant roster,
//                 plant levels up to 10, Maximum Damage perk, daily reward streak.
import { BASE_PLANT_FOOD_MAX, BASE_SEED_SLOTS, MAX_PLANT_LEVEL, PLANTS, ULTIMATE_EXTRA_SLOTS, type PlantId } from './config';

export interface UltimateSettings {
  enabled: boolean;
  unlimitedSun: boolean;
  unlimitedPlantFood: boolean;
  instantRecharge: boolean;
  invincible: boolean;
  extraSlots: boolean;
  maxUpgrades: boolean;
  maxDamage: boolean;
}

export interface GameSettings {
  music: boolean;
  sfx: boolean;
  highQuality: boolean;
  autoCollectSun: boolean;
  outlines: boolean;
}

export interface SaveData {
  version: 2;
  coins: number;
  gems: number;
  seedPackets: number;
  completed: Record<string, number>; // level id -> times cleared
  plantLevels: Partial<Record<PlantId, number>>;
  lastLoadout: PlantId[];
  ultimate: UltimateSettings;
  settings: GameSettings;
  daily: { lastClaim: string; streak: number };
}

const KEY = 'pvz-ultimate-3d.save.v1';

export function defaultSave(): SaveData {
  return {
    version: 2,
    coins: 0,
    gems: 0,
    seedPackets: 0,
    completed: {},
    plantLevels: {},
    lastLoadout: ['peashooter', 'sunflower', 'wallnut', 'potatomine', 'cherrybomb', 'snowpea', 'repeater', 'buttercob'],
    ultimate: {
      enabled: true,
      unlimitedSun: true,
      unlimitedPlantFood: true,
      instantRecharge: false,
      invincible: false,
      extraSlots: true,
      maxUpgrades: true,
      maxDamage: false,
    },
    settings: { music: true, sfx: true, highQuality: true, autoCollectSun: false, outlines: true },
    daily: { lastClaim: '', streak: 0 },
  };
}

function storage(): Storage | null {
  try {
    return typeof localStorage !== 'undefined' ? localStorage : null;
  } catch {
    return null;
  }
}

/** Upgrade any older save object to the current version (pure; exported for tests). */
export function migrate(data: Record<string, unknown>): SaveData {
  const base = defaultSave();
  const version = typeof data.version === 'number' ? data.version : 1;
  const completed = { ...((data.completed as Record<string, number>) ?? {}) };
  if (version < 2) {
    // Phase 2 inserted new levels into World 1.
    const remapped: Record<string, number> = {};
    for (const [id, n] of Object.entries(completed)) {
      const to = id === '1-4' ? '1-5' : id === '1-5' ? '1-10' : id;
      remapped[to] = (remapped[to] ?? 0) + n;
    }
    Object.keys(completed).forEach((k) => delete completed[k]);
    Object.assign(completed, remapped);
  }
  const levels = { ...((data.plantLevels as Record<string, number>) ?? {}) };
  for (const k of Object.keys(levels)) {
    if (!PLANTS[k]) delete levels[k];
    else levels[k] = Math.max(1, Math.min(MAX_PLANT_LEVEL, Math.round(levels[k])));
  }
  const loadout = ((data.lastLoadout as string[]) ?? base.lastLoadout).filter((p) => !!PLANTS[p]);
  return {
    ...base,
    coins: Number(data.coins ?? 0) || 0,
    gems: Number(data.gems ?? 0) || 0,
    seedPackets: Number(data.seedPackets ?? 0) || 0,
    version: 2,
    ultimate: { ...base.ultimate, ...((data.ultimate as object) ?? {}) },
    settings: { ...base.settings, ...((data.settings as object) ?? {}) },
    completed,
    plantLevels: levels,
    lastLoadout: loadout.length ? loadout : base.lastLoadout,
    daily: { ...base.daily, ...((data.daily as object) ?? {}) },
  };
}

export function loadSave(): SaveData {
  try {
    const raw = storage()?.getItem(KEY);
    if (!raw) return defaultSave();
    return migrate(JSON.parse(raw));
  } catch {
    return defaultSave();
  }
}

export function writeSave(save: SaveData): void {
  try {
    storage()?.setItem(KEY, JSON.stringify(save));
  } catch {
    // Private mode or storage full: the game keeps running, progress just isn't persisted.
  }
}

/** Derived rules: what the current save + Ultimate Mode actually grant. */
export function rules(save: SaveData, opts: { sandbox?: boolean } = {}) {
  const u = save.ultimate;
  const on = u.enabled;
  return {
    ultimate: on,
    unlimitedSun: on && u.unlimitedSun,
    unlimitedPlantFood: on && u.unlimitedPlantFood,
    instantRecharge: on && u.instantRecharge,
    invincible: on && u.invincible,
    maxDamage: on && u.maxDamage,
    seedSlots: opts.sandbox ? 10 : BASE_SEED_SLOTS + (on && u.extraSlots ? ULTIMATE_EXTRA_SLOTS : 0),
    plantFoodMax: BASE_PLANT_FOOD_MAX,
    unlimitedCurrency: on,
    plantLevel: (id: PlantId) => (on && u.maxUpgrades ? MAX_PLANT_LEVEL : Math.max(1, Math.min(MAX_PLANT_LEVEL, save.plantLevels[id] ?? 1))),
  };
}

export type Rules = ReturnType<typeof rules>;
