// Static game data: plants, zombies, worlds and levels.
// Everything here is plain data so new content can be added without touching the engine.

export const COLS = 9;
export const LANES = 5;
export const MAX_PLANT_LEVEL = 5;
export const BASE_SEED_SLOTS = 6;
export const ULTIMATE_EXTRA_SLOTS = 2;
export const BASE_PLANT_FOOD_MAX = 3;

export type PlantId =
  | 'peashooter'
  | 'sunflower'
  | 'wallnut'
  | 'snowpea'
  | 'cherrybomb'
  | 'potatomine'
  | 'repeater';

export type PlantKind = 'shooter' | 'producer' | 'wall' | 'instant' | 'mine';

export interface PlantDef {
  id: PlantId;
  name: string;
  kind: PlantKind;
  cost: number;
  /** Seconds before the seed packet can be used again. */
  recharge: number;
  /** Fraction of the recharge that is already done when a level starts (1 = ready). */
  startReady: number;
  hp: number;
  /** Shooters */
  fireInterval?: number;
  damage?: number;
  shots?: number;
  slow?: boolean;
  /** Producers */
  sunAmount?: number;
  sunInterval?: number;
  /** Instants / mines */
  blastDamage?: number;
  blastRadius?: number;
  armTime?: number;
  fuse?: number;
  color: string;
  blurb: string;
  plantFood: string;
  toughness: string;
}

export const PLANTS: Record<PlantId, PlantDef> = {
  peashooter: {
    id: 'peashooter',
    name: 'Peashooter',
    kind: 'shooter',
    cost: 100,
    recharge: 7.5,
    startReady: 1,
    hp: 300,
    fireInterval: 1.4,
    damage: 20,
    shots: 1,
    color: '#5fd35a',
    blurb: 'Fires peas at zombies in its lane. Reliable, cheap and always ready to defend the lawn.',
    plantFood: 'Pea Gatling: unleashes a storm of peas.',
    toughness: 'Typical',
  },
  sunflower: {
    id: 'sunflower',
    name: 'Sunflower',
    kind: 'producer',
    cost: 50,
    recharge: 7.5,
    startReady: 1,
    hp: 300,
    sunAmount: 50,
    sunInterval: 24,
    color: '#ffd23f',
    blurb: 'Gathers extra sunlight so you can plant more. Plant lots of these early on!',
    plantFood: 'Sun Burst: instantly produces 150 sun.',
    toughness: 'Typical',
  },
  wallnut: {
    id: 'wallnut',
    name: 'Wall-nut',
    kind: 'wall',
    cost: 50,
    recharge: 20,
    startReady: 0.4,
    hp: 4000,
    color: '#c58a4a',
    blurb: 'A sturdy shell that blocks zombies while your attackers do the work.',
    plantFood: 'Iron Shell: fully heals and gains a metal armor layer.',
    toughness: 'Very High',
  },
  snowpea: {
    id: 'snowpea',
    name: 'Snow Pea',
    kind: 'shooter',
    cost: 175,
    recharge: 7.5,
    startReady: 1,
    hp: 300,
    fireInterval: 1.4,
    damage: 20,
    shots: 1,
    slow: true,
    color: '#7fd4ff',
    blurb: 'Shoots frozen peas that damage and chill zombies, halving their speed.',
    plantFood: 'Deep Freeze: freezes every zombie in its lane and fires a flurry.',
    toughness: 'Typical',
  },
  cherrybomb: {
    id: 'cherrybomb',
    name: 'Cherry Bomb',
    kind: 'instant',
    cost: 150,
    recharge: 35,
    startReady: 0.5,
    hp: 9999,
    blastDamage: 1800,
    blastRadius: 1.5,
    fuse: 1.1,
    color: '#ff4a4a',
    blurb: 'Explodes moments after planting, destroying every zombie in a 3x3 area.',
    plantFood: 'Already explosive — plant food not needed!',
    toughness: 'Instant',
  },
  potatomine: {
    id: 'potatomine',
    name: 'Potato Mine',
    kind: 'mine',
    cost: 25,
    recharge: 20,
    startReady: 0.5,
    hp: 300,
    blastDamage: 1800,
    blastRadius: 0.6,
    armTime: 12,
    color: '#d8a86a',
    blurb: 'Takes a while to arm, then blows up the first zombie that steps on it.',
    plantFood: 'Instant Arm: becomes armed immediately.',
    toughness: 'Low',
  },
  repeater: {
    id: 'repeater',
    name: 'Repeater',
    kind: 'shooter',
    cost: 200,
    recharge: 7.5,
    startReady: 1,
    hp: 300,
    fireInterval: 1.4,
    damage: 20,
    shots: 2,
    color: '#2fa84f',
    blurb: 'Fires two peas at a time. Double the peas, double the fun.',
    plantFood: 'Pea Typhoon: a massive double-barrel barrage.',
    toughness: 'Typical',
  },
};

export const PLANT_ORDER: PlantId[] = [
  'peashooter',
  'sunflower',
  'wallnut',
  'potatomine',
  'cherrybomb',
  'snowpea',
  'repeater',
];

export type ZombieId = 'basic' | 'flag' | 'cone' | 'bucket' | 'brute';

export interface ZombieDef {
  id: ZombieId;
  name: string;
  hp: number;
  armor: number;
  armorType: 'none' | 'cone' | 'bucket';
  /** Tiles per second. */
  speed: number;
  /** Damage per second while eating. */
  eatDps: number;
  /** Brutes smash plants instead of eating them. */
  smash?: boolean;
  scale: number;
  skin: string;
  coat: string;
  blurb: string;
  toughness: string;
  speedLabel: string;
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
  },
  bucket: {
    id: 'bucket',
    name: 'Buckethead Zombie',
    hp: 190,
    armor: 1100,
    armorType: 'bucket',
    speed: 0.21,
    eatDps: 100,
    scale: 1,
    skin: '#94b282',
    coat: '#5a4a6a',
    blurb: 'Wears a metal pail that soaks up an impressive number of peas.',
    toughness: 'High',
    speedLabel: 'Basic',
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
    scale: 1.5,
    skin: '#7f9c70',
    coat: '#3f3a34',
    blurb: 'A towering boss zombie that flattens plants with a giant log club.',
    toughness: 'Boss',
    speedLabel: 'Slow',
  },
};

export const ZOMBIE_ORDER: ZombieId[] = ['basic', 'flag', 'cone', 'bucket', 'brute'];

export interface WaveDef {
  zombies: ZombieId[];
  /** Huge (flag) wave — announced with a banner. */
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
  /** Seconds before the first wave arrives. */
  firstWaveDelay: number;
  boss?: boolean;
}

export interface WorldDef {
  id: number;
  name: string;
  theme: string;
  emoji: string;
  available: boolean;
}

export const WORLDS: WorldDef[] = [
  { id: 1, name: 'Sunrise Meadow', theme: 'A sunny suburban backyard', emoji: '🌻', available: true },
  { id: 2, name: "Pharaoh's Dunes", theme: 'Desert tombs and sandstorms', emoji: '🏜️', available: false },
  { id: 3, name: 'Buccaneer Bay', theme: 'Pirate ships and planks', emoji: '🏴‍☠️', available: false },
  { id: 4, name: 'Dusty Frontier', theme: 'Mine carts and cacti', emoji: '🤠', available: false },
  { id: 5, name: 'Glacier Gorge', theme: 'Ice blocks and blizzards', emoji: '🧊', available: false },
  { id: 6, name: 'Emerald Jungle', theme: 'Vines and ancient ruins', emoji: '🌴', available: false },
  { id: 7, name: 'Neon Tomorrow', theme: 'Robots and power tiles', emoji: '🤖', available: false },
  { id: 8, name: 'Shadow Kingdom', theme: 'Castles and dark magic', emoji: '🏰', available: false },
  { id: 9, name: 'Tidal Shores', theme: 'Waves and water lanes', emoji: '🌊', available: false },
  { id: 10, name: 'Primal Valley', theme: 'Dinosaurs and lava', emoji: '🦖', available: false },
  { id: 11, name: 'Midnight Rooftops', theme: 'Moonlit city rooftops', emoji: '🌙', available: false },
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
    waves: [
      w('basic'),
      w('basic*2'),
      w('cone'),
      w('flag basic*3 cone', true),
      w('basic*2 cone'),
      w('basic*3'),
      w('cone*2 basic'),
      w('flag basic*4 cone*2', true),
    ],
  },
  {
    id: '1-3',
    world: 1,
    index: 3,
    name: 'Pail Patrol',
    startSun: 150,
    firstWaveDelay: 16,
    rewardCoins: 200,
    waves: [
      w('basic*2'),
      w('basic cone'),
      w('basic*3'),
      w('bucket'),
      w('flag basic*3 cone*2', true),
      w('basic*2 cone'),
      w('cone*2 bucket'),
      w('basic*4'),
      w('cone*2 basic*2'),
      w('flag basic*4 cone*2 bucket', true),
    ],
  },
  {
    id: '1-4',
    world: 1,
    index: 4,
    name: 'Rush Hour',
    startSun: 200,
    firstWaveDelay: 16,
    rewardCoins: 250,
    waves: [
      w('basic*2'),
      w('cone basic'),
      w('basic*3 cone'),
      w('bucket basic'),
      w('flag basic*4 cone*2', true),
      w('cone*2 basic*2'),
      w('bucket cone basic'),
      w('basic*5'),
      w('bucket*2 cone'),
      w('flag basic*5 cone*3 bucket', true),
      w('cone*3 bucket'),
      w('flag basic*6 cone*3 bucket*2', true),
    ],
  },
  {
    id: '1-5',
    world: 1,
    index: 5,
    name: 'The Mega Brute',
    startSun: 250,
    firstWaveDelay: 16,
    rewardCoins: 500,
    boss: true,
    waves: [
      w('basic*2'),
      w('cone*2'),
      w('basic*3 bucket'),
      w('flag basic*4 cone*2', true),
      w('cone*2 bucket'),
      w('brute'),
      w('basic*4 cone*2'),
      w('bucket*2 cone*2'),
      w('flag basic*5 cone*3 bucket', true),
      w('cone*3 bucket*2'),
      w('flag brute basic*5 cone*3 bucket*2', true),
    ],
  },
];

export function getLevel(id: string): LevelDef | undefined {
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
    damage: 1 + 0.25 * l,
    hp: 1 + 0.25 * l,
    sun: 1 + 0.1 * l,
    recharge: 1 - 0.08 * l,
    armTime: 1 - 0.12 * l,
  };
}
