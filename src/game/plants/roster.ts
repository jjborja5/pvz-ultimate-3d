// The full plant roster, assembled from tested batches.
import { BATCH1 } from './batch1';
import { BATCH2 } from './batch2';
import { BATCH3 } from './batch3';
import { BATCH4 } from './batch4';
import type { Family, PlantDef } from './types';

export const PLANT_LIST: PlantDef[] = [...BATCH1, ...BATCH2, ...BATCH3, ...BATCH4];

export const PLANTS: Record<string, PlantDef> = Object.fromEntries(PLANT_LIST.map((p) => [p.id, p]));

export const PLANT_ORDER: string[] = PLANT_LIST.map((p) => p.id);

export function plantsByFamily(f: Family | 'all'): PlantDef[] {
  return f === 'all' ? PLANT_LIST : PLANT_LIST.filter((p) => p.family === f);
}
