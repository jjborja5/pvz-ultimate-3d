// Human-readable stat lines for the almanac and upgrade screens, derived from behavior specs.
import { levelMultipliers } from '../config';
import type { Effect, PlantDef, ProjSpec } from './types';

export interface StatLine {
  label: string;
  value: string;
}

const r = (n: number) => (n >= 100 ? Math.round(n).toString() : (Math.round(n * 10) / 10).toString());

function projExtras(p: ProjSpec, out: StatLine[]) {
  if (p.splash) out.push({ label: 'Splash', value: `${p.splash} tiles` });
  if (p.slow) out.push({ label: 'Chill', value: `${p.slow}s` });
  if (p.freeze) out.push({ label: 'Freeze', value: `${p.freeze}s` });
  if (p.burn) out.push({ label: 'Burn', value: `${p.burn}/s` });
  if (p.poison) out.push({ label: 'Poison', value: `${p.poison}/s` });
  if (p.stun) out.push({ label: 'Stun', value: `${p.stun}s${p.stunChance !== undefined && p.stunChance < 1 ? ` (${Math.round(p.stunChance * 100)}%)` : ''}` });
  if (p.knockback) out.push({ label: 'Knockback', value: `${p.knockback} tiles` });
  if (p.weaken) out.push({ label: 'Weaken', value: `+${Math.round(p.weaken * 100)}%` });
  if (p.chain) out.push({ label: 'Chains', value: `${p.chain}` });
  if (p.pierce) out.push({ label: 'Pierce', value: p.pierce === Infinity ? 'All' : `${p.pierce}` });
  if (p.air) out.push({ label: 'Anti-air', value: 'Yes' });
}

function effectLines(e: Effect, dmg: number, out: StatLine[]) {
  switch (e.type) {
    case 'blast':
      out.push({ label: 'Blast', value: r(e.damage * dmg) }, { label: 'Area', value: `${e.lanes * 2 + 1} lanes × ${r(e.radius * 2)} tiles` });
      break;
    case 'laneFire':
      out.push({ label: 'Lane fire', value: r(e.damage * dmg) });
      break;
    case 'freezeArea':
    case 'freezeAll':
      out.push({ label: 'Freeze', value: `${e.duration}s` });
      break;
    case 'lavaPool':
      out.push({ label: 'Impact', value: r(e.damage * dmg) }, { label: 'Lava', value: `${e.dps}/s for ${e.duration}s` });
      break;
    case 'giveSun':
      out.push({ label: 'Sun', value: `${e.amount}` });
      break;
    case 'grapes':
      out.push({ label: 'Grapes', value: `${e.count} × ${r(e.damage * dmg)}` });
      break;
    case 'stunEater':
      out.push({ label: 'Stun', value: `${e.duration}s` });
      break;
    default:
      break;
  }
}

export function plantStats(def: PlantDef, level: number): StatLine[] {
  const m = levelMultipliers(level);
  const out: StatLine[] = [
    { label: 'Sun cost', value: String(def.cost) },
    { label: 'Recharge', value: `${r(def.recharge * m.recharge)}s` },
  ];
  const b = def.behavior;
  if (!def.untargetable) out.push({ label: 'Health', value: r(def.hp * (b.type === 'instant' ? 1 : m.hp)) });
  switch (b.type) {
    case 'shoot':
      out.push({ label: 'Damage', value: `${r(b.proj.damage * m.damage)}${(b.shots ?? 1) > 1 ? ` × ${b.shots}` : ''}` }, { label: 'Fire rate', value: `${b.interval}s` });
      if (b.lanes && b.lanes.length > 1) out.push({ label: 'Lanes', value: `${b.lanes.length}` });
      if (b.dirs) out.push({ label: 'Directions', value: `${b.dirs.length}` });
      if (b.back) out.push({ label: 'Backward', value: `${b.back}` });
      if (b.range) out.push({ label: 'Range', value: `${b.range} tiles` });
      if (b.sunCost) out.push({ label: 'Sun per shot', value: `${b.sunCost}` });
      if (b.charge) out.push({ label: 'Charge', value: `${b.charge}s` });
      projExtras(b.proj, out);
      break;
    case 'lob':
      out.push({ label: 'Damage', value: r(b.proj.damage * m.damage) }, { label: 'Fire rate', value: `${b.interval}s` });
      projExtras(b.proj, out);
      break;
    case 'produce':
      out.push({ label: 'Sun', value: `${Math.round((b.amount * m.sun) / 5) * 5}${(b.count ?? 1) > 1 ? ` × ${b.count}` : ''}` }, { label: 'Every', value: `${b.interval}s` });
      if (b.growAfter) out.push({ label: 'Grows after', value: `${b.growAfter}s` });
      break;
    case 'wall':
      if (b.thorns) out.push({ label: 'Thorns', value: `${r(b.thorns * m.damage)}/s` });
      if (b.regen) out.push({ label: 'Regen', value: `${b.regen}/s` });
      if (b.knockbacks) out.push({ label: 'Knockbacks', value: `${b.knockbacks}` });
      if (b.explodeOnDeath) out.push({ label: 'Death blast', value: r(b.explodeOnDeath.damage * m.damage) });
      if (b.tall) out.push({ label: 'Blocks vaulting', value: 'Yes' });
      if (b.smashProof) out.push({ label: 'Smash-proof', value: 'Yes' });
      if (b.stunOnBite) out.push({ label: 'Stun biters', value: `${b.stunOnBite}s` });
      if (b.shoot) out.push({ label: 'Damage', value: r(b.shoot.proj.damage * m.damage) });
      break;
    case 'instant':
      effectLines(b.effect, m.damage, out);
      break;
    case 'mine':
      if (b.arm) out.push({ label: 'Arm time', value: `${r(b.arm * m.armTime)}s` });
      out.push({ label: 'Trigger', value: b.trigger === 'contact' ? 'Stepped on' : 'Eaten' });
      effectLines(b.effect, m.damage, out);
      break;
    case 'melee':
      out.push({ label: 'Damage', value: r(b.damage * m.damage) }, { label: 'Hit rate', value: `${b.interval}s` }, { label: 'Reach', value: `${b.front} front / ${b.back} back` });
      break;
    case 'beam':
      out.push({ label: 'Damage', value: r(b.damage * m.damage) }, { label: 'Rate', value: `${b.interval}s` });
      if (b.chain) out.push({ label: 'Chains', value: `${b.chain}` });
      if (b.sunCost) out.push({ label: 'Sun per shot', value: `${b.sunCost}` });
      if (b.range) out.push({ label: 'Range', value: `${b.range} tiles` });
      break;
    case 'grab':
      out.push({ label: 'Reach', value: `${b.range} tiles` });
      if (b.chew) out.push({ label: 'Chew time', value: `${b.chew}s` });
      if (b.interval) out.push({ label: 'Cooldown', value: `${b.interval}s` });
      break;
    case 'aura':
      out.push({ label: 'Damage', value: r(b.damage * m.damage) }, { label: 'Pulse', value: `${b.interval}s` }, { label: 'Area', value: `${b.lanes * 2 + 1} lanes × ${r(b.radius * 2)} tiles` });
      break;
    case 'ground':
      out.push({ label: 'Damage', value: `${r(b.dps * m.damage)}/s` });
      if (b.slow) out.push({ label: 'Chill', value: `${b.slow}s` });
      break;
    case 'support':
      if (b.interval) out.push({ label: 'Every', value: `${b.interval}s` });
      if (b.amount) out.push({ label: 'Power', value: `${b.amount}` });
      if (b.radius) out.push({ label: 'Range', value: `${b.radius} tiles` });
      break;
    case 'overlay':
      out.push({ label: 'Placement', value: 'On top of plants' });
      break;
  }
  return out;
}
