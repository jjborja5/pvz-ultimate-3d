// Data model for plants. Every plant is plain data: a behavior spec (what it does on the lawn),
// a Plant Food spec, stats and almanac text. The engine (battle.ts + plants/behaviors.ts)
// interprets the specs, so each plant's gameplay is defined in one readable place.

export type Family =
  | 'pea'
  | 'sun'
  | 'nut'
  | 'boom'
  | 'fire'
  | 'ice'
  | 'volt'
  | 'lob'
  | 'shadow'
  | 'brawl'
  | 'spore'
  | 'wind'
  | 'bloom';

export const FAMILIES: Record<Family, { name: string; emoji: string; color: string; blurb: string }> = {
  pea: { name: 'Pod Squad', emoji: '🟢', color: '#4fc34a', blurb: 'Straight-shooting projectile plants.' },
  sun: { name: 'Sunshine', emoji: '☀️', color: '#ffc928', blurb: 'Make sun so you can plant more.' },
  nut: { name: 'Bulwark', emoji: '🛡️', color: '#b9773b', blurb: 'Tough plants that hold the line.' },
  boom: { name: 'Kaboom', emoji: '💥', color: '#e2463a', blurb: 'Explosive one-shot plants.' },
  fire: { name: 'Blaze', emoji: '🔥', color: '#ff7a1f', blurb: 'Burn zombies over time and melt ice.' },
  ice: { name: 'Frost', emoji: '❄️', color: '#7fd4ff', blurb: 'Chill and freeze zombies in place.' },
  volt: { name: 'Voltage', emoji: '⚡', color: '#b98cff', blurb: 'Lasers, lightning and energy beams.' },
  lob: { name: 'Lobbers', emoji: '🥬', color: '#8fcf3a', blurb: 'Arc shots over shields and walls.' },
  shadow: { name: 'Mystic', emoji: '🌙', color: '#7a4fc3', blurb: 'Shadow magic, hypnosis and curses.' },
  brawl: { name: 'Brawlers', emoji: '🥊', color: '#d9622b', blurb: 'Close-range melee fighters.' },
  spore: { name: 'Spores', emoji: '🍄', color: '#c07ad8', blurb: 'Mushrooms with odd talents.' },
  wind: { name: 'Gust', emoji: '🌬️', color: '#9ad8c8', blurb: 'Push, pull and redirect zombies.' },
  bloom: { name: 'Support', emoji: '💚', color: '#5fd3a0', blurb: 'Heal, boost and assist other plants.' },
};

export type ProjLook =
  | 'pea'
  | 'snow'
  | 'fire'
  | 'goo'
  | 'shadow'
  | 'rock'
  | 'volt'
  | 'kernel'
  | 'butter'
  | 'cabbage'
  | 'melon'
  | 'wmelon'
  | 'star'
  | 'spike'
  | 'bulb'
  | 'boomerang'
  | 'thistle'
  | 'bomb'
  | 'plasma'
  | 'spore'
  | 'coconut'
  | 'pinecone'
  | 'head'
  | 'grape'
  | 'seed'
  | 'pepper'
  | 'arrow'
  | 'bubble'
  | 'mega';

export interface ProjSpec {
  look: ProjLook;
  damage: number;
  speed?: number;
  path?: 'straight' | 'lob' | 'homing' | 'boomerang' | 'bounce';
  /** Number of extra zombies the projectile passes through (Infinity = all). */
  pierce?: number;
  /** Splash radius in tiles around the impact point. */
  splash?: number;
  /** Fraction of damage dealt to splashed zombies. */
  splashFrac?: number;
  /** Chill duration (halves speed). */
  slow?: number;
  /** Freeze duration (stops completely). */
  freeze?: number;
  /** Burn damage per second for 3s. Also thaws chill. */
  burn?: number;
  /** Stun duration and chance (0..1). */
  stun?: number;
  stunChance?: number;
  /** Push the zombie back this many tiles. */
  knockback?: number;
  /** Target takes +X damage from everything for 5s (e.g. 0.5 = +50%). */
  weaken?: number;
  /** Poison damage per second for 4s, ignores armor. */
  poison?: number;
  /** Electric arc that jumps to N more zombies. */
  chain?: number;
  /** Can hit flying zombies. */
  air?: boolean;
  /** Max travel distance in tiles. */
  range?: number;
  scale?: number;
  /** On impact split into shards that hit the lanes above and below. */
  split?: boolean;
}

export type Effect =
  | { type: 'blast'; radius: number; lanes: number; damage: number; fire?: boolean; crater?: number; color?: string; dx?: number }
  | { type: 'laneFire'; damage: number; lanes?: number }
  | { type: 'freezeAll'; duration: number; damage: number }
  | { type: 'freezeArea'; radius: number; lanes: number; duration: number; damage: number; dx?: number }
  | { type: 'shrink'; radius: number; lanes: number }
  | { type: 'blowAll'; distance: number }
  | { type: 'blowLane'; distance: number; chill: number }
  | { type: 'giveSun'; amount: number }
  | { type: 'givePlantFood'; amount: number }
  | { type: 'boostProducers' }
  | { type: 'conceal'; duration: number }
  | { type: 'lavaPool'; duration: number; dps: number; damage: number }
  | { type: 'grapes'; count: number; damage: number }
  | { type: 'hypnoEater' }
  | { type: 'stunEater'; duration: number; radius: number }
  | { type: 'sunEater'; amount: number }
  | { type: 'globalSlow'; duration: number }
  | { type: 'drag' }
  | { type: 'stunAll'; duration: number; damage: number }
  | { type: 'strikeAll'; damage: number }
  | { type: 'laser'; lanes: number; damage: number }
  | { type: 'summonAlly'; zombie: 'basic' | 'cone' | 'bucket' | 'brute' | 'knight' }
  | { type: 'laneStrike'; damage: number; color: string; lanes?: number; burn?: number }
  | { type: 'healAll'; amount: number }
  | { type: 'transformArea'; radius: number; lanes: number; count?: number }
  | { type: 'hypnoArea'; radius: number; lanes: number; count?: number }
  | { type: 'magnetAll'; damage: number }
  | { type: 'rootLanes'; lanes: number; duration: number; damage: number }
  | { type: 'poisonLanes'; lanes: number; dps: number; damage: number }
  | { type: 'chainStorm'; hops: number; damage: number }
  | { type: 'laneSmash'; count: number; damage: number };

export type Behavior =
  | {
      type: 'shoot';
      proj: ProjSpec;
      interval: number;
      /** Burst size and gap between shots in a burst. */
      shots?: number;
      gap?: number;
      /** Extra lanes to fire into (e.g. [-1, 0, 1]). Default [0]. */
      lanes?: number[];
      /** Shots fired backwards. */
      back?: number;
      /** Fixed directions [dx, dz] for multi-direction shooters (star, diagonals). */
      dirs?: [number, number][];
      /** Detection range in tiles (default whole lane). */
      range?: number;
      /** Sun spent per shot (paid unless sun is unlimited). */
      sunCost?: number;
      /** Seconds to charge before each shot (shown as a glow). */
      charge?: number;
      /** Target any zombie on the lawn (homing). */
      anywhere?: boolean;
      /** Target the furthest zombie in the lane. */
      furthest?: boolean;
      /** Only shoots flying zombies first if present. */
      antiAir?: boolean;
    }
  | { type: 'lob'; proj: ProjSpec; interval: number; shots?: number; gap?: number; furthest?: boolean }
  | { type: 'produce'; amount: number; interval: number; growAfter?: number; grownAmount?: number; count?: number }
  | {
      type: 'wall';
      thorns?: number;
      regen?: number;
      knockbacks?: number;
      explodeOnDeath?: { radius: number; lanes: number; damage: number };
      smashProof?: boolean;
      tall?: boolean;
      stunOnBite?: number;
      shoot?: { proj: ProjSpec; interval: number };
    }
  | { type: 'instant'; fuse: number; effect: Effect }
  | { type: 'mine'; arm: number; trigger: 'contact' | 'eaten'; effect: Effect; reusable?: number }
  | { type: 'melee'; interval: number; damage: number; front: number; back: number; lanes: number; knockback?: number; slow?: number; burn?: number }
  | { type: 'beam'; kind: 'laser' | 'chain' | 'random' | 'lens' | 'breath' | 'snipe'; interval: number; damage: number; chain?: number; range?: number; lanes?: number; sunCost?: number; burn?: number; slow?: number; freeze?: number; strikes?: number }
  | { type: 'grab'; kind: 'devour' | 'squash' | 'drag' | 'transform'; range: number; chew?: number; interval?: number }
  | { type: 'aura'; interval: number; damage: number; radius: number; lanes: number; slow?: number; poison?: number; stun?: number; burn?: number; whenAttacked?: boolean }
  | { type: 'ground'; dps: number; slow?: number; stuck?: number; shock?: boolean; spikes?: boolean }
  | { type: 'overlay' }
  | {
      type: 'support';
      kind: 'heal' | 'haste' | 'producerBoost' | 'damageBoost' | 'fireConvert' | 'summon' | 'globalSlow' | 'divert' | 'magnet' | 'hypnoAura' | 'wind' | 'coins';
      interval?: number;
      amount?: number;
      radius?: number;
    };

export type PlantFood =
  | { type: 'barrage'; duration: number; interval: number; proj?: Partial<ProjSpec>; lanes?: number[] }
  | { type: 'megaShot'; proj: ProjSpec; count?: number }
  | { type: 'sun'; amount: number }
  | { type: 'armor' }
  | { type: 'effect'; effect: Effect }
  | { type: 'arm'; copies?: number }
  | { type: 'boost'; duration: number; factor: number }
  | { type: 'combo'; parts: PlantFood[] }
  | { type: 'none' };

export interface PlantDef {
  id: string;
  name: string;
  /** Gameplay role this plant is inspired by (shown in the almanac as its archetype). */
  role: string;
  family: Family;
  cost: number;
  recharge: number;
  /** Fraction of recharge already complete at level start (1 = ready). */
  startReady: number;
  hp: number;
  behavior: Behavior;
  pf: PlantFood;
  pfText: string;
  blurb: string;
  /** Short gameplay summary for the almanac card. */
  ability: string;
  /** Batch number this plant was added in (1..4). */
  batch: number;
  /** Not eaten by zombies (ground plants, instants). */
  untargetable?: boolean;
  /** Can be planted on top of another plant (pumpkin shell). */
  overlay?: boolean;
  /** Plant Food cannot be used on it. */
  noPlantFood?: boolean;
}
