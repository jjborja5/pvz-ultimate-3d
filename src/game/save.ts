// Persistent save data (progress, resources, Ultimate Mode and settings) stored in localStorage.
import { BASE_PLANT_FOOD_MAX, BASE_SEED_SLOTS, MAX_PLANT_LEVEL, PLANT_ORDER, ULTIMATE_EXTRA_SLOTS, type PlantId } from './config';

export interface UltimateSettings {
  enabled: boolean;
  unlimitedSun: boolean;
  unlimitedPlantFood: boolean;
  instantRecharge: boolean;
  invincible: boolean;
  extraSlots: boolean;
  maxUpgrades: boolean;
}

export interface GameSettings {
  music: boolean;
  sfx: boolean;
  highQuality: boolean;
  autoCollectSun: boolean;
}

export interface SaveData {
  version: 1;
  coins: number;
  gems: number;
  seedPackets: number;
  completed: Record<string, number>; // level id -> times cleared
  plantLevels: Partial<Record<PlantId, number>>;
  lastLoadout: PlantId[];
  ultimate: UltimateSettings;
  settings: GameSettings;
}

const KEY = 'pvz-ultimate-3d.save.v1';

export function defaultSave(): SaveData {
  return {
    version: 1,
    coins: 0,
    gems: 0,
    seedPackets: 0,
    completed: {},
    plantLevels: {},
    lastLoadout: ['peashooter', 'sunflower', 'wallnut', 'potatomine', 'cherrybomb', 'snowpea'],
    ultimate: {
      enabled: true,
      unlimitedSun: true,
      unlimitedPlantFood: true,
      instantRecharge: false,
      invincible: false,
      extraSlots: true,
      maxUpgrades: true,
    },
    settings: { music: true, sfx: true, highQuality: true, autoCollectSun: false },
  };
}

function storage(): Storage | null {
  try {
    return typeof localStorage !== 'undefined' ? localStorage : null;
  } catch {
    return null;
  }
}

export function loadSave(): SaveData {
  const base = defaultSave();
  try {
    const raw = storage()?.getItem(KEY);
    if (!raw) return base;
    const data = JSON.parse(raw) as Partial<SaveData>;
    return {
      ...base,
      ...data,
      version: 1,
      ultimate: { ...base.ultimate, ...(data.ultimate ?? {}) },
      settings: { ...base.settings, ...(data.settings ?? {}) },
      completed: { ...(data.completed ?? {}) },
      plantLevels: { ...(data.plantLevels ?? {}) },
      lastLoadout: (data.lastLoadout ?? base.lastLoadout).filter((p) => PLANT_ORDER.includes(p)),
    };
  } catch {
    return base;
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
export function rules(save: SaveData) {
  const u = save.ultimate;
  const on = u.enabled;
  return {
    ultimate: on,
    unlimitedSun: on && u.unlimitedSun,
    unlimitedPlantFood: on && u.unlimitedPlantFood,
    instantRecharge: on && u.instantRecharge,
    invincible: on && u.invincible,
    seedSlots: BASE_SEED_SLOTS + (on && u.extraSlots ? ULTIMATE_EXTRA_SLOTS : 0),
    plantFoodMax: BASE_PLANT_FOOD_MAX,
    unlimitedCurrency: on,
    plantLevel: (id: PlantId) =>
      on && u.maxUpgrades ? MAX_PLANT_LEVEL : Math.max(1, Math.min(MAX_PLANT_LEVEL, save.plantLevels[id] ?? 1)),
  };
}

export type Rules = ReturnType<typeof rules>;
