// Static game data: board constants, zombies, worlds and levels. Plants live in plants/roster.ts.
export { PLANTS, PLANT_ORDER, PLANT_LIST, plantsByFamily } from './plants/roster';
export type { PlantDef, Family } from './plants/types';
export { FAMILIES } from './plants/types';

export const COLS = 9;
export const LANES = 5;
export const MAX_PLANT_LEVEL = 10;
export const BASE_SEED_SLOTS = 6;
export const ULTIMATE_EXTRA_SLOTS = 2;
export const SANDBOX_SEED_SLOTS = 10;
export const BASE_PLANT_FOOD_MAX = 3;

/** Plant ids are strings so the roster can grow without touching types. */
export type PlantId = string;

export type ZombieId = 'basic' | 'flag' | 'cone' | 'bucket' | 'brute' | 'vaulter' | 'imp' | 'balloon' | 'door' | 'knight' | 'reader';

export interface ZombieDef {
  id: ZombieId;
  name: string;
  hp: number;
  armor: number;
  armorType: 'none' | 'cone' | 'bucket' | 'knight' | 'paper';
  /** Armor is metal (Magnet Cap can steal it). */
  armorMetal?: boolean;
  /** Front shield that blocks straight shots (lobbed shots fly over it). */
  shield?: number;
  /** Tiles per second. */
  speed: number;
  /** Damage per second while eating. */
  eatDps: number;
  /** Brutes smash plants instead of eating them. */
  smash?: boolean;
  /** Floats over plants; only anti-air attacks can pop the balloon. */
  flying?: boolean;
  /** Vaults over the first plant it meets (except tall walls). */
  vault?: boolean;
  /** Speeds up when its armor is destroyed. */
  rage?: boolean;
  boss?: boolean;
  dropsSun?: number;
  scale: number;
  skin: string;
  coat: string;
  blurb: string;
  toughness: string;
  speedLabel: string;
  counter: string;
}

export const ZOMBIES: Record<ZombieId, ZombieDef> = {
  basic: {
    id: 'basic',
    name: 'Shambler Zombie',
    hp: 190,
    armor: 0,
    armorType: 'none',
    speed: 0.21,
    eatDps: 100,
    scale: 1,
    skin: '#9bb88a',
    coat: '#6b5a48',
    blurb: 'An ordinary zombie with an extraordinary appetite for gardens.',
    toughness: 'Low',
    speedLabel: 'Basic',
    counter: 'Anything works.',
  },
  flag: {
    id: 'flag',
    name: 'Banner Zombie',
    hp: 190,
    armor: 0,
    armorType: 'none',
    speed: 0.3,
    eatDps: 100,
    scale: 1,
    skin: '#a3c08f',
    coat: '#4e5f8a',
    blurb: 'Waves a banner to announce a huge horde. Walks a little faster than the rest.',
    toughness: 'Low',
    speedLabel: 'Hungry',
    counter: 'Anything works.',
  },
  cone: {
    id: 'cone',
    name: 'Conehead Zombie',
    hp: 190,
    armor: 370,
    armorType: 'cone',
    speed: 0.21,
    eatDps: 100,
    scale: 1,
    skin: '#9bb88a',
    coat: '#7a5a3a',
    blurb: 'Found a traffic cone and decided it was armor. It kind of is.',
    toughness: 'Medium',
    speedLabel: 'Basic',
    counter: 'Repeaters and lobbers.',
  },
  bucket: {
    id: 'bucket',
    name: 'Buckethead Zombie',
    hp: 190,
    armor: 1100,
    armorType: 'bucket',
    armorMetal: true,
    speed: 0.21,
    eatDps: 100,
    scale: 1,
    skin: '#94b282',
    coat: '#5a4a6a',
    blurb: 'Wears a metal pail that soaks up an impressive number of peas.',
    toughness: 'High',
    speedLabel: 'Basic',
    counter: 'Magnet Cap steals the bucket; Goo Pea poison skips it.',
  },
  vaulter: {
    id: 'vaulter',
    name: 'Pole Jumper Zombie',
    hp: 340,
    armor: 0,
    armorType: 'none',
    vault: true,
    speed: 0.21,
    eatDps: 100,
    scale: 1,
    skin: '#a0bc8c',
    coat: '#c8463a',
    blurb: 'Sprints in and pole-vaults over the first plant in its way.',
    toughness: 'Medium',
    speedLabel: 'Fast, then basic',
    counter: 'Tower Nut stops the jump cold.',
  },
  imp: {
    id: 'imp',
    name: 'Scrappy Imp',
    hp: 130,
    armor: 0,
    armorType: 'none',
    speed: 0.42,
    eatDps: 80,
    scale: 0.65,
    skin: '#a8c895',
    coat: '#8a6a3a',
    blurb: 'Tiny, quick and always in a hurry to reach your brains.',
    toughness: 'Low',
    speedLabel: 'Fast',
    counter: 'Fast-firing plants and walls.',
  },
  balloon: {
    id: 'balloon',
    name: 'Balloon Zombie',
    hp: 190,
    armor: 0,
    armorType: 'none',
    flying: true,
    speed: 0.26,
    eatDps: 100,
    scale: 1,
    skin: '#9bb88a',
    coat: '#6a8ab8',
    blurb: 'Floats right over your defenses. Pop the balloon and it has to walk.',
    toughness: 'Low',
    speedLabel: 'Hovering',
    counter: 'Needle Cactus, Seeker Thistle, Fan Clover, explosions.',
  },
  door: {
    id: 'door',
    name: 'Screen Door Zombie',
    hp: 190,
    armor: 0,
    armorType: 'none',
    shield: 1100,
    speed: 0.21,
    eatDps: 100,
    scale: 1,
    skin: '#9bb88a',
    coat: '#5a6a4a',
    blurb: 'Holds a screen door that blocks straight shots from the front.',
    toughness: 'High',
    speedLabel: 'Basic',
    counter: 'Lobbers fly over the door; magnets steal it; Peek-a-Pea hits from behind.',
  },
  knight: {
    id: 'knight',
    name: 'Iron Knight Zombie',
    hp: 260,
    armor: 1600,
    armorType: 'knight',
    armorMetal: true,
    speed: 0.24,
    eatDps: 120,
    scale: 1.08,
    skin: '#90ac80',
    coat: '#5a5a66',
    blurb: 'Clanks forward in full plate armor. Very hard to stop.',
    toughness: 'Very High',
    speedLabel: 'Basic',
    counter: 'Magnet Cap, Beam Bean, Plasma Citrus, explosives.',
  },
  reader: {
    id: 'reader',
    name: 'Newsreader Zombie',
    hp: 190,
    armor: 150,
    armorType: 'paper',
    rage: true,
    speed: 0.21,
    eatDps: 100,
    scale: 1,
    skin: '#a0bc8c',
    coat: '#7a6a5a',
    blurb: 'Reads the paper on the way. Destroy the paper and it flies into a rage.',
    toughness: 'Medium',
    speedLabel: 'Basic, then fast',
    counter: 'Strong single hits; slow it down.',
  },
  brute: {
    id: 'brute',
    name: 'Mega Brute',
    hp: 3000,
    armor: 0,
    armorType: 'none',
    speed: 0.16,
    eatDps: 0,
    smash: true,
    boss: true,
    scale: 1.5,
    skin: '#7f9c70',
    coat: '#3f3a34',
    blurb: 'A towering boss zombie that flattens plants with a giant log club.',
    toughness: 'Boss',
    speedLabel: 'Slow',
    counter: 'Explosives and Boulder Nut (survives a smash).',
  },
};

export const ZOMBIE_ORDER: ZombieId[] = ['basic', 'flag', 'cone', 'bucket', 'vaulter', 'imp', 'reader', 'door', 'balloon', 'knight', 'brute'];

export interface WaveDef {
  zombies: ZombieId[];
  flag?: boolean;
}

export interface LevelDef {
  id: string;
  world: number;
  index: number;
  name: string;
  startSun: number;
  waves: WaveDef[];
  rewardCoins: number;
  firstWaveDelay: number;
  boss?: boolean;
  /** Plant this level shows off (suggested in seed selection). */
  feature?: string;
}

export interface WorldDef {
  id: number;
  name: string;
  theme: string;
  emoji: string;
  available: boolean;
}

export const WORLDS: WorldDef[] = [
  { id: 1, name: 'Sunrise Meadow', theme: 'Modern-day backyard (home base)', emoji: '🌻', available: true },
  { id: 2, name: "Pharaoh's Dunes", theme: 'Ancient desert tombs and sandstorms', emoji: '🏜️', available: false },
  { id: 3, name: 'Buccaneer Bay', theme: 'Pirate ships, planks and cannons', emoji: '🏴‍☠️', available: false },
  { id: 4, name: 'Dusty Frontier', theme: 'Mine carts and saloons', emoji: '🤠', available: false },
  { id: 5, name: 'Neon Tomorrow', theme: 'Robots and power tiles', emoji: '🤖', available: false },
  { id: 6, name: 'Shadow Kingdom', theme: 'Castles and dark magic', emoji: '🏰', available: false },
  { id: 7, name: 'Tidal Shores', theme: 'Beach with water lanes', emoji: '🌊', available: false },
  { id: 8, name: 'Glacier Gorge', theme: 'Frozen caves and slider tiles', emoji: '🧊', available: false },
  { id: 9, name: 'Golden Ruins', theme: 'Lost city of gold tiles', emoji: '🗿', available: false },
  { id: 10, name: 'Retro Rave', theme: 'Neon music tour', emoji: '🎸', available: false },
  { id: 11, name: 'Primal Valley', theme: 'Dinosaurs and swamps', emoji: '🦖', available: false },
];

/** Compact wave notation, e.g. w('basic*3 cone') -> 3 basic + 1 cone. */
function w(spec: string, flag = false): WaveDef {
  const zombies: ZombieId[] = [];
  for (const token of spec.trim().split(/\s+/)) {
    const [id, count] = token.split('*');
    const n = count ? parseInt(count, 10) : 1;
    for (let i = 0; i < n; i++) zombies.push(id as ZombieId);
  }
  return { zombies, flag };
}

export const LEVELS: LevelDef[] = [
  {
    id: '1-1',
    world: 1,
    index: 1,
    name: 'First Sprouts',
    startSun: 150,
    firstWaveDelay: 18,
    rewardCoins: 100,
    waves: [w('basic'), w('basic'), w('basic*2'), w('basic*2'), w('basic*3'), w('flag basic*4', true)],
  },
  {
    id: '1-2',
    world: 1,
    index: 2,
    name: 'Cone Zone',
    startSun: 150,
    firstWaveDelay: 18,
    rewardCoins: 150,
    waves: [w('basic'), w('basic*2'), w('cone'), w('flag basic*3 cone', true), w('basic*2 cone'), w('basic*3'), w('cone*2 basic'), w('flag basic*4 cone*2', true)],
  },
  {
    id: '1-3',
    world: 1,
    index: 3,
    name: 'Pail Patrol',
    startSun: 150,
    firstWaveDelay: 16,
    rewardCoins: 200,
    waves: [w('basic*2'), w('basic cone'), w('basic*3'), w('bucket'), w('flag basic*3 cone*2', true), w('basic*2 cone'), w('cone*2 bucket'), w('basic*4'), w('cone*2 basic*2'), w('flag basic*4 cone*2 bucket', true)],
  },
  {
    id: '1-4',
    world: 1,
    index: 4,
    name: 'Pole Position',
    startSun: 150,
    firstWaveDelay: 16,
    rewardCoins: 200,
    feature: 'towernut',
    waves: [w('basic*2'), w('vaulter'), w('basic cone'), w('vaulter basic'), w('flag basic*3 vaulter*2', true), w('cone*2 vaulter'), w('bucket vaulter basic'), w('flag basic*4 cone*2 vaulter*2', true)],
  },
  {
    id: '1-5',
    world: 1,
    index: 5,
    name: 'Rush Hour',
    startSun: 200,
    firstWaveDelay: 16,
    rewardCoins: 250,
    waves: [w('basic*2'), w('cone basic'), w('basic*3 cone'), w('imp*2 basic'), w('flag basic*4 cone*2', true), w('cone*2 imp*2'), w('bucket cone basic'), w('basic*5'), w('bucket*2 imp*2'), w('flag basic*5 cone*3 bucket', true), w('cone*3 bucket imp*2'), w('flag basic*6 cone*3 bucket*2', true)],
  },
  {
    id: '1-6',
    world: 1,
    index: 6,
    name: 'Door to Door',
    startSun: 200,
    firstWaveDelay: 16,
    rewardCoins: 250,
    feature: 'buttercob',
    waves: [w('basic*2'), w('door'), w('basic cone'), w('door basic'), w('flag basic*3 door cone', true), w('door*2'), w('cone*2 door basic'), w('flag basic*4 door*2 cone*2', true)],
  },
  {
    id: '1-7',
    world: 1,
    index: 7,
    name: 'Hot Air',
    startSun: 200,
    firstWaveDelay: 16,
    rewardCoins: 300,
    feature: 'seekerthistle',
    waves: [w('basic*2'), w('basic'), w('basic cone'), w('balloon'), w('flag basic*3 balloon', true), w('cone balloon basic'), w('bucket balloon*2 basic'), w('flag basic*4 balloon*3 cone', true)],
  },
  {
    id: '1-8',
    world: 1,
    index: 8,
    name: 'Breaking News',
    startSun: 200,
    firstWaveDelay: 16,
    rewardCoins: 300,
    waves: [w('basic*2'), w('reader'), w('reader basic'), w('cone reader'), w('flag basic*3 reader*2', true), w('reader*2 cone'), w('bucket reader*2'), w('imp*3 reader'), w('flag basic*4 reader*3 bucket', true)],
  },
  {
    id: '1-9',
    world: 1,
    index: 9,
    name: 'Iron March',
    startSun: 250,
    firstWaveDelay: 16,
    rewardCoins: 350,
    feature: 'magnetcap',
    waves: [w('basic*2'), w('cone*2'), w('knight'), w('bucket basic'), w('flag basic*3 knight cone', true), w('door knight'), w('bucket*2 imp*2'), w('knight*2 basic'), w('flag basic*4 knight*2 bucket door', true)],
  },
  {
    id: '1-10',
    world: 1,
    index: 10,
    name: 'The Mega Brute',
    startSun: 300,
    firstWaveDelay: 16,
    rewardCoins: 500,
    boss: true,
    waves: [
      w('basic*2'),
      w('cone*2 vaulter'),
      w('basic*3 bucket'),
      w('flag basic*4 cone*2 imp*2', true),
      w('cone*2 bucket door'),
      w('brute'),
      w('basic*4 cone*2 balloon'),
      w('bucket*2 cone*2 reader'),
      w('flag basic*5 cone*3 bucket knight', true),
      w('cone*3 bucket*2 vaulter*2'),
      w('flag brute basic*5 cone*3 bucket*2 imp*3', true),
    ],
  },
];

/** Endless Sandbox: cycles through these waves forever, getting bigger each loop. */
export const SANDBOX_LEVEL: LevelDef = {
  id: 'sandbox',
  world: 0,
  index: 0,
  name: 'Plant Playground',
  startSun: 1000,
  firstWaveDelay: 8,
  rewardCoins: 0,
  waves: [
    w('basic*3'),
    w('cone*2 basic*2'),
    w('vaulter*2 imp*2'),
    w('bucket*2 door', true),
    w('balloon*2 reader*2'),
    w('knight cone*3'),
    w('imp*4 basic*3', true),
    w('door*2 bucket*2 balloon'),
    w('brute cone*2'),
    w('knight*2 reader*2 vaulter*2', true),
  ],
};

export function getLevel(id: string): LevelDef | undefined {
  if (id === 'sandbox') return SANDBOX_LEVEL;
  return LEVELS.find((l) => l.id === id);
}

export function nextLevelId(id: string): string | undefined {
  const i = LEVELS.findIndex((l) => l.id === id);
  return i >= 0 && i + 1 < LEVELS.length ? LEVELS[i + 1].id : undefined;
}

/** Stat multipliers granted by plant upgrade level (1..MAX_PLANT_LEVEL). */
export function levelMultipliers(level: number) {
  const l = Math.max(1, Math.min(MAX_PLANT_LEVEL, level)) - 1;
  return {
    damage: 1 + 0.12 * l,
    hp: 1 + 0.12 * l,
    sun: 1 + 0.05 * l,
    recharge: 1 - 0.04 * l,
    armTime: 1 - 0.06 * l,
  };
}

/** Cost to upgrade a plant from `level` to `level + 1`. */
export function upgradeCost(level: number) {
  return { coins: 250 * level, packets: 5 * level };
}
