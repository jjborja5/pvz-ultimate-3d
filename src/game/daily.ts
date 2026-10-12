// Daily login rewards: a 7-day streak that resets if a day is missed.
import type { SaveData } from './save';

export interface DailyReward {
  icon: string;
  label: string;
  coins?: number;
  gems?: number;
  packets?: number;
}

const REWARDS: DailyReward[] = [
  { icon: '🪙', label: '250 coins', coins: 250 },
  { icon: '🌰', label: '10 seed packets', packets: 10 },
  { icon: '💎', label: '2 gems', gems: 2 },
  { icon: '🪙', label: '500 coins', coins: 500 },
  { icon: '🌰', label: '20 seed packets', packets: 20 },
  { icon: '💎', label: '5 gems', gems: 5 },
  { icon: '🏆', label: '1000 coins + 10 gems', coins: 1000, gems: 10 },
];

export function dailyRewards() {
  return REWARDS;
}

function dayKey(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

export function dailyStatus(save: SaveData, now = new Date()) {
  const today = dayKey(now);
  const y = new Date(now);
  y.setDate(y.getDate() - 1);
  const yesterday = dayKey(y);
  const claimable = save.daily.lastClaim !== today;
  const continuing = save.daily.lastClaim === yesterday;
  const nextStreak = claimable ? (continuing ? save.daily.streak + 1 : 1) : save.daily.streak;
  const nextDay = ((nextStreak - 1) % REWARDS.length) + 1;
  // How many day tiles to show as already collected this week.
  const streakShown = claimable ? (continuing ? ((save.daily.streak - 1) % REWARDS.length) + 1 : 0) : nextDay;
  return { claimable, nextDay, streakShown };
}

export function claimDaily(save: SaveData, now = new Date()): DailyReward {
  const st = dailyStatus(save, now);
  if (!st.claimable) return { icon: '', label: 'nothing (already claimed)' };
  const reward = REWARDS[st.nextDay - 1];
  const y = new Date(now);
  y.setDate(y.getDate() - 1);
  save.daily.streak = save.daily.lastClaim === dayKey(y) ? save.daily.streak + 1 : 1;
  save.daily.lastClaim = dayKey(now);
  save.coins += reward.coins ?? 0;
  save.gems += reward.gems ?? 0;
  save.seedPackets += reward.packets ?? 0;
  return reward;
}
