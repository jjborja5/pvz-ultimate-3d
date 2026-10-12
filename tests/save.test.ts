import { describe, expect, it } from 'vitest';
import { defaultSave, migrate, rules } from '../src/game/save';
import { claimDaily, dailyStatus } from '../src/game/daily';
import { MAX_PLANT_LEVEL, SANDBOX_SEED_SLOTS } from '../src/game/config';

describe('save data', () => {
  it('migrates a Phase 1 save without losing progress', () => {
    const v1 = {
      version: 1,
      coins: 1234,
      gems: 7,
      seedPackets: 9,
      completed: { '1-1': 2, '1-2': 1, '1-4': 1, '1-5': 3 },
      plantLevels: { peashooter: 3, notAPlant: 2 },
      lastLoadout: ['peashooter', 'sunflower', 'removedPlant'],
      ultimate: { enabled: false, unlimitedSun: true },
      settings: { music: false },
    };
    const s = migrate(v1);
    expect(s.version).toBe(2);
    expect(s.coins).toBe(1234);
    expect(s.gems).toBe(7);
    expect(s.seedPackets).toBe(9);
    // Old level 1-4 (Rush Hour) is now 1-5, old 1-5 (boss) is now 1-10.
    expect(s.completed).toEqual({ '1-1': 2, '1-2': 1, '1-5': 1, '1-10': 3 });
    expect(s.plantLevels).toEqual({ peashooter: 3 });
    expect(s.lastLoadout).toEqual(['peashooter', 'sunflower']);
    expect(s.ultimate.enabled).toBe(false);
    expect(s.ultimate.maxDamage).toBe(false);
    expect(s.settings.music).toBe(false);
    expect(s.settings.outlines).toBe(true);
  });

  it('keeps v2 saves as they are', () => {
    const s = defaultSave();
    s.completed = { '1-4': 1 };
    expect(migrate(JSON.parse(JSON.stringify(s))).completed).toEqual({ '1-4': 1 });
  });

  it('Ultimate rules: max levels, slots and sandbox slots', () => {
    const s = defaultSave();
    expect(rules(s).plantLevel('peashooter')).toBe(MAX_PLANT_LEVEL);
    expect(rules(s).seedSlots).toBe(8);
    expect(rules(s, { sandbox: true }).seedSlots).toBe(SANDBOX_SEED_SLOTS);
    s.ultimate.enabled = false;
    s.plantLevels.peashooter = 4;
    expect(rules(s).plantLevel('peashooter')).toBe(4);
    expect(rules(s).seedSlots).toBe(6);
    expect(rules(s).maxDamage).toBe(false);
  });
});

describe('daily rewards', () => {
  it('builds a streak on consecutive days and resets after a gap', () => {
    const s = defaultSave();
    const d1 = new Date(2026, 9, 10, 12);
    expect(dailyStatus(s, d1).claimable).toBe(true);
    claimDaily(s, d1);
    expect(s.daily.streak).toBe(1);
    expect(s.coins).toBe(250);
    expect(dailyStatus(s, d1).claimable).toBe(false);
    claimDaily(s, d1); // no double claim
    expect(s.coins).toBe(250);
    claimDaily(s, new Date(2026, 9, 11, 9));
    expect(s.daily.streak).toBe(2);
    expect(s.seedPackets).toBe(10);
    claimDaily(s, new Date(2026, 9, 14, 9));
    expect(s.daily.streak).toBe(1);
  });
});
