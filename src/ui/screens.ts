// Menu screens and overlays (DOM over the 3D canvas).
import type { App } from '../app';
import { audio } from '../game/audio';
import {
  FAMILIES,
  LEVELS,
  MAX_PLANT_LEVEL,
  PLANTS,
  PLANT_LIST,
  WORLDS,
  ZOMBIES,
  ZOMBIE_ORDER,
  upgradeCost,
  type Family,
  type LevelDef,
  type PlantId,
  type ZombieId,
} from '../game/config';
import { plantStats } from '../game/plants/stats';
import { claimDaily, dailyRewards, dailyStatus } from '../game/daily';
import { rules, defaultSave, migrate, type UltimateSettings, type GameSettings } from '../game/save';
import { STANDALONE_URL, isEmbedded, isStandalone } from './platform';
import type { BattleView } from '../views/battleView';
import { clear, h } from './dom';
import { thumbImg } from './thumbs';

const click = () => audio.play('click');

function btn(label: string, onClick: () => void, cls = '') {
  return h('button', {
    class: 'btn ' + cls,
    text: label,
    onClick: () => {
      click();
      onClick();
    },
  });
}

function levelBadge(level: number) {
  return h('span', { class: 'lvl' + (level >= MAX_PLANT_LEVEL ? ' max' : ''), text: level >= MAX_PLANT_LEVEL ? 'MAX' : `Lv ${level}` });
}

/** Resource counters shown at the top of menu screens. */
function resources(app: App) {
  const r = rules(app.save);
  const fmt = (n: number) => (r.unlimitedCurrency ? '∞' : n.toLocaleString());
  return h(
    'div',
    { class: 'resources' },
    h('div', { class: 'res' }, '💎 ', h('b', { text: fmt(app.save.gems) })),
    h('div', { class: 'res' }, '🪙 ', h('b', { text: fmt(app.save.coins) })),
    h('div', { class: 'res' }, '🌰 ', h('b', { text: fmt(app.save.seedPackets) })),
    r.ultimate ? h('div', { class: 'res ult', text: '👑 Ultimate' }) : null,
  );
}

function topBar(app: App, title: string, back: () => void) {
  return h('div', { class: 'topbar' }, btn('◀ Back', back, 'small'), h('h2', { text: title }), resources(app));
}

function toggle(label: string, desc: string, value: boolean, onChange: (v: boolean) => void, locked = false) {
  const input = h('div', { class: 'switch' + (value ? ' on' : '') + (locked ? ' locked' : '') }, h('div', { class: 'knob' }));
  const row = h('div', { class: 'toggle-row' }, h('div', { class: 'toggle-text' }, h('b', { text: label }), h('small', { text: desc })), input);
  if (!locked) {
    row.addEventListener('click', () => {
      value = !value;
      input.classList.toggle('on', value);
      click();
      onChange(value);
    });
  }
  return row;
}

/** Horizontal row of family filter chips. */
function familyChips(selected: Family | 'all', onPick: (f: Family | 'all') => void) {
  const row = h('div', { class: 'chips scroll-x' });
  const all: (Family | 'all')[] = ['all', ...(Object.keys(FAMILIES) as Family[])];
  for (const f of all) {
    const count = f === 'all' ? PLANT_LIST.length : PLANT_LIST.filter((p) => p.family === f).length;
    const label = f === 'all' ? `🌱 All ${count}` : `${FAMILIES[f].emoji} ${FAMILIES[f].name} ${count}`;
    const chip = h('button', { class: 'chip' + (f === selected ? ' active' : ''), text: label });
    if (f !== 'all') chip.style.setProperty('--chip', FAMILIES[f].color);
    chip.addEventListener('click', () => {
      click();
      onPick(f);
    });
    row.append(chip);
  }
  return row;
}

// ------------------------------------------------------------------ title

export function titleScreen(app: App) {
  const daily = dailyStatus(app.save);
  return h(
    'div',
    { class: 'screen title-screen' },
    h(
      'div',
      { class: 'logo' },
      h('div', { class: 'logo-main', html: '<span class="lp">PLANTS</span> <span class="lv">vs.</span> <span class="lz">ZOMBIES</span>' }),
      h('div', { class: 'logo-sub', text: 'ULTIMATE 3D EDITION' }),
    ),
    h(
      'div',
      { class: 'title-menu' },
      h('div', { class: 'row' }, btn('▶  Adventure', () => app.showScreen('map'), 'big primary'), btn('🧪 Plant Playground', () => app.startLevel('sandbox'), 'big sandbox')),
      h(
        'div',
        { class: 'row' },
        btn(`🌱 Plants (${PLANT_LIST.length})`, () => app.showScreen('almanac')),
        btn('👑 Ultimate', () => app.showScreen('ultimate'), 'gold'),
        btn(daily.claimable ? '🎁 Daily Reward!' : '🎁 Daily', () => app.ui.append(dailyModal(app)), daily.claimable ? 'gift pulse' : 'gift'),
        btn('⚙️', () => app.showScreen('settings')),
      ),
      isStandalone() ? null : btn('📲 Play Fullscreen', () => app.ui.append(installModal(app)), 'small install'),
      h(
        'div',
        { class: 'modes' },
        ...[
          ['⚔️', 'Arena'],
          ['♾️', 'Survival'],
          ['🧩', 'Mini-games'],
        ].map(([e, n]) => h('div', { class: 'mode-tile soon' }, h('span', { text: e }), h('b', { text: n }), h('small', { text: 'Coming soon' }))),
      ),
    ),
    resources(app),
    h('div', { class: 'footer', text: 'Unofficial fan-made game · original art & sound · Phase 2 build' }),
  );
}

/** How to get true fullscreen: open the standalone site and add it to the Home Screen. */
export function installModal(_app: App) {
  const overlay = h('div', { class: 'overlay install' });
  const embedded = isEmbedded();
  const copy = btn('Copy link', () => {
    const done = () => (copy.textContent = 'Copied!');
    navigator.clipboard?.writeText(STANDALONE_URL).then(done, () => {
      const range = document.createRange();
      range.selectNodeContents(link);
      getSelection()?.removeAllRanges();
      getSelection()?.addRange(range);
    });
  }, 'small');
  const link = h('a', { class: 'install-link', text: STANDALONE_URL, attrs: { href: STANDALONE_URL, target: '_blank', rel: 'noopener' } });
  overlay.append(
    h(
      'div',
      { class: 'panel scroll' },
      h('h2', { text: '📲 Play Fullscreen' }),
      embedded
        ? h('p', { text: 'You are playing inside another app’s viewer, which adds its own bars. For the full-screen game, open the standalone version in Safari:' })
        : h('p', { text: 'Add the game to your Home Screen to play without Safari’s bars:' }),
      h('div', { class: 'row' }, link, copy),
      h(
        'ol',
        { class: 'install-steps' },
        h('li', { text: 'Open the link above in Safari.' }),
        h('li', { html: 'Tap the <b>Share</b> button (square with an up arrow).' }),
        h('li', { html: 'Scroll down and tap <b>Add to Home Screen</b>, then <b>Add</b>.' }),
        h('li', { text: 'Launch “PvZ Ultimate” from its icon and turn your iPhone sideways. It runs fullscreen, works offline, and keeps its own save.' }),
      ),
      h('p', { class: 'note', text: 'Your progress is stored per website. To bring it along, use Settings → Transfer Progress: copy the code here, then load it in the Home Screen app.' }),
      btn('Close', () => overlay.remove(), 'primary'),
    ),
  );
  return overlay;
}

function dailyModal(app: App) {
  const st = dailyStatus(app.save);
  const overlay = h('div', { class: 'overlay daily' });
  const rewards = dailyRewards();
  const grid = h(
    'div',
    { class: 'daily-grid' },
    ...rewards.map((r, i) => {
      const day = i + 1;
      const done = day <= st.streakShown && !(st.claimable && day === st.nextDay);
      const next = st.claimable && day === st.nextDay;
      return h('div', { class: 'daily-day' + (done ? ' done' : '') + (next ? ' next' : '') }, h('small', { text: `Day ${day}` }), h('b', { text: r.icon }), h('span', { text: r.label }));
    }),
  );
  const close = () => {
    overlay.remove();
    app.showScreen('title');
  };
  overlay.append(
    h(
      'div',
      { class: 'panel' },
      h('h2', { text: '🎁 Daily Rewards' }),
      h('p', { text: st.claimable ? 'Come back every day to grow your streak!' : 'Already claimed today. See you tomorrow!' }),
      grid,
      h(
        'div',
        { class: 'row' },
        st.claimable
          ? btn(
              'Claim!',
              () => {
                const got = claimDaily(app.save);
                app.persist();
                audio.play('coin');
                overlay.querySelector('p')!.textContent = `You got ${got.label}!`;
                setTimeout(close, 900);
              },
              'primary',
            )
          : null,
        btn('Close', close),
      ),
    ),
  );
  return overlay;
}

// ------------------------------------------------------------------ world map

let selectedWorld = 1;

export function mapScreen(app: App) {
  const tabs = h('div', { class: 'world-tabs scroll-x' });
  const body = h('div', { class: 'world-body' });
  const render = () => {
    clear(tabs);
    clear(body);
    for (const w of WORLDS) {
      tabs.append(
        h(
          'button',
          {
            class: 'world-tab' + (w.id === selectedWorld ? ' active' : '') + (w.available ? '' : ' soon'),
            onClick: () => {
              click();
              selectedWorld = w.id;
              render();
            },
          },
          h('span', { class: 'we', text: w.emoji }),
          h('span', { text: w.name }),
        ),
      );
    }
    const world = WORLDS.find((w) => w.id === selectedWorld)!;
    const levels = LEVELS.filter((l) => l.world === world.id);
    body.append(h('div', { class: 'world-head' }, h('h3', { text: `${world.emoji} World ${world.id}: ${world.name}` }), h('small', { text: world.theme })));
    if (!levels.length) {
      body.append(h('div', { class: 'soon-card' }, h('b', { text: 'Coming in a future update' }), h('p', { text: 'This world is planned with its own mechanics, zombies and boss. World 1 is playable now, and every plant can be tested in the Plant Playground.' })));
      return;
    }
    const path = h('div', { class: 'level-grid scroll' });
    levels.forEach((l) => {
      const done = app.save.completed[l.id] ?? 0;
      const kinds = [...new Set(l.waves.flatMap((w) => w.zombies))];
      path.append(
        h(
          'button',
          {
            class: 'level-node' + (done ? ' done' : '') + (l.boss ? ' boss' : ''),
            onClick: () => {
              click();
              app.startLevel(l.id);
            },
          },
          h('div', { class: 'ln-num', text: l.boss ? '💀' : String(l.index) }),
          h('div', { class: 'ln-name', text: l.name }),
          h('div', { class: 'ln-meta', text: `${l.waves.length} waves · ${kinds.length} zombie types` + (done ? ' · ✅' : '') }),
        ),
      );
    });
    body.append(path);
  };
  render();
  return h('div', { class: 'screen map-screen' }, topBar(app, 'World Map', () => app.showScreen('title')), tabs, body);
}

// ------------------------------------------------------------------ plant collection + zombie almanac

let collTab: 'plants' | 'zombies' = 'plants';
let collFamily: Family | 'all' = 'all';
let collPlant: PlantId = 'peashooter';
let collZombie: ZombieId = 'basic';

export function almanacScreen(app: App) {
  const tabs = h('div', { class: 'alm-tabs' });
  const chips = h('div', { class: 'alm-chips' });
  const list = h('div', { class: 'alm-list' });
  const detail = h('div', { class: 'alm-detail scroll' });

  const stat = (k: string, v: string) => h('div', { class: 'stat' }, h('small', { text: k }), h('b', { text: v }));

  const renderPlantDetail = () => {
    clear(detail);
    const r = rules(app.save);
    const d = PLANTS[collPlant];
    const lvl = r.plantLevel(collPlant);
    const fam = FAMILIES[d.family];
    const stats = plantStats(d, lvl).map((l) => stat(l.label, l.value));
    const upgrade = h('div', { class: 'upgrade' });
    if (r.ultimate && app.save.ultimate.maxUpgrades) {
      upgrade.append(h('small', { text: '⭐ Max level from Ultimate Mode' }));
    } else if (lvl >= MAX_PLANT_LEVEL) {
      upgrade.append(h('small', { text: '⭐ Fully upgraded!' }));
    } else {
      const cost = upgradeCost(lvl);
      const free = r.unlimitedCurrency;
      const can = free || (app.save.coins >= cost.coins && app.save.seedPackets >= cost.packets);
      const now = plantStats(d, lvl);
      const diff = plantStats(d, lvl + 1)
        .map((s) => ({ s, before: now.find((n) => n.label === s.label)?.value }))
        .filter((x) => x.before !== undefined && x.before !== x.s.value)
        .map((x) => `${x.s.label} ${x.before} → ${x.s.value}`);
      const b = btn(
        free ? `Upgrade to Lv ${lvl + 1} (free)` : `Upgrade · 🪙${cost.coins} 🌰${cost.packets}`,
        () => {
          if (!can) return audio.play('error');
          if (!free) {
            app.save.coins -= cost.coins;
            app.save.seedPackets -= cost.packets;
          }
          app.save.plantLevels[collPlant] = lvl + 1;
          app.persist();
          audio.play('plantfood');
          renderPlantDetail();
          renderList();
        },
        can ? 'primary small' : 'small',
      );
      b.disabled = !can;
      upgrade.append(h('small', { class: 'next', text: diff.slice(0, 3).join(' · ') || 'Stronger stats' }), b);
    }
    detail.append(
      h(
        'div',
        { class: 'alm-hero' },
        thumbImg(collPlant, d.name, false, 'alm-big'),
        h('div', { class: 'alm-title' }, h('h3', { text: d.name }), h('div', { class: 'fam', text: `${fam.emoji} ${fam.name} · ${d.role}`, style: { background: fam.color } }), h('div', { class: 'lvlrow' }, levelBadge(lvl), h('small', { class: 'unlocked', text: '🔓 Unlocked' }))),
      ),
      h('p', { class: 'ability', text: d.ability }),
      h('div', { class: 'stats' }, ...stats),
      h('p', { class: 'pf-line', text: `🌿 Plant Food — ${d.pfText}` }),
      upgrade,
      h('p', { class: 'blurb', text: `“${d.blurb}”` }),
    );
  };

  const renderList = () => {
    clear(list);
    const r = rules(app.save);
    if (collTab === 'plants') {
      for (const d of PLANT_LIST.filter((p) => collFamily === 'all' || p.family === collFamily)) {
        const card = h('button', { class: 'alm-card' + (d.id === collPlant ? ' active' : '') }, thumbImg(d.id, d.name), h('span', { text: d.name }), levelBadge(r.plantLevel(d.id)));
        card.addEventListener('click', () => {
          click();
          collPlant = d.id;
          renderList();
          renderPlantDetail();
        });
        list.append(card);
      }
    } else {
      for (const id of ZOMBIE_ORDER) {
        const card = h('button', { class: 'alm-card' + (id === collZombie ? ' active' : '') }, thumbImg(id, ZOMBIES[id].name, true), h('span', { text: ZOMBIES[id].name }));
        card.addEventListener('click', () => {
          click();
          collZombie = id;
          renderList();
          renderZombieDetail();
        });
        list.append(card);
      }
    }
  };

  const renderZombieDetail = () => {
    clear(detail);
    const d = ZOMBIES[collZombie];
    detail.append(
      h(
        'div',
        { class: 'alm-hero' },
        thumbImg(collZombie, d.name, true, 'alm-big'),
        h('div', { class: 'alm-title' }, h('h3', { text: d.name }), h('div', { class: 'fam', text: d.boss ? '💀 Boss' : '🧟 Zombie', style: { background: d.boss ? '#c8281a' : '#6b7a5a' } })),
      ),
      h('div', { class: 'stats' }, stat('Health', String(d.hp + d.armor + (d.shield ?? 0))), stat('Toughness', d.toughness), stat('Speed', d.speedLabel), stat('Attack', d.smash ? 'Smash' : 'Chomp')),
      h('p', { text: d.blurb }),
      h('p', { class: 'pf-line', text: `💡 Counter: ${d.counter}` }),
    );
  };

  const render = () => {
    clear(tabs);
    clear(chips);
    tabs.append(
      h('button', { class: 'tab' + (collTab === 'plants' ? ' active' : ''), text: `🌱 Plants (${PLANT_LIST.length})`, onClick: () => ((collTab = 'plants'), click(), render()) }),
      h('button', { class: 'tab' + (collTab === 'zombies' ? ' active' : ''), text: `🧟 Zombies (${ZOMBIE_ORDER.length})`, onClick: () => ((collTab = 'zombies'), click(), render()) }),
    );
    if (collTab === 'plants') {
      chips.append(
        familyChips(collFamily, (f) => {
          collFamily = f;
          if (f !== 'all' && PLANTS[collPlant].family !== f) collPlant = PLANT_LIST.find((p) => p.family === f)!.id;
          render();
        }),
      );
      renderPlantDetail();
    } else renderZombieDetail();
    renderList();
  };
  render();
  return h('div', { class: 'screen almanac-screen' }, topBar(app, 'Collection', () => app.showScreen('title')), tabs, chips, h('div', { class: 'alm-body' }, list, detail));
}

// ------------------------------------------------------------------ ultimate

function ultimatePanel(app: App, onChange?: () => void) {
  const u = app.save.ultimate;
  const set = (k: keyof UltimateSettings) => (v: boolean) => {
    u[k] = v;
    app.persist();
    onChange?.();
  };
  const grid = h('div', { class: 'ult-grid' });
  const fill = () => {
    clear(grid);
    grid.append(
      toggle('💎 Unlimited Gems', 'Gem balance shows ∞', u.enabled, () => {}, true),
      toggle('🪙 Unlimited Coins', 'Upgrades are free', u.enabled, () => {}, true),
      toggle('🌰 Unlimited Seed Packets', 'Upgrade currency shows ∞', u.enabled, () => {}, true),
      toggle('🎁 Unlimited Rewards', 'All currencies are infinite', u.enabled, () => {}, true),
      toggle(`🔓 All ${PLANT_LIST.length} Plants Unlocked`, 'Always on — every built plant is available', true, () => {}, true),
      toggle('☀️ Unlimited Sunlight', 'Plant anything, any time', u.unlimitedSun, set('unlimitedSun')),
      toggle('🌱 Unlimited Plant Food', 'Boost plants as often as you like', u.unlimitedPlantFood, set('unlimitedPlantFood')),
      toggle('⭐ Maximum Plant Levels', `All plants at level ${MAX_PLANT_LEVEL} (+108% damage & health)`, u.maxUpgrades, set('maxUpgrades')),
      toggle('➕ Two Extra Seed Slots', '8 seed slots instead of 6', u.extraSlots, set('extraSlots')),
      toggle('⚡ Instant Recharge', 'Seed packets never need to recharge', u.instantRecharge, set('instantRecharge')),
      toggle('🛡️ Plant Invincibility', 'Plants take no damage; the house is shielded', u.invincible, set('invincible')),
      toggle('💥 Maximum Damage', 'Every plant hits 100× harder', u.maxDamage, set('maxDamage')),
    );
    grid.classList.toggle('disabled', !u.enabled);
  };
  fill();
  const master = toggle('👑 ULTIMATE MODE', 'Master switch for every perk below', u.enabled, (v) => {
    u.enabled = v;
    app.persist();
    fill();
    onChange?.();
  });
  master.classList.add('master');
  return h('div', { class: 'ult-panel' }, master, grid);
}

export function ultimateScreen(app: App) {
  const el = h('div', { class: 'screen ult-screen' });
  el.append(
    topBar(app, 'Ultimate Mode', () => app.showScreen('title')),
    h(
      'div',
      { class: 'scroll' },
      ultimatePanel(app, () => {
        el.querySelector('.resources')?.replaceWith(resources(app));
      }),
    ),
  );
  return el;
}

// ------------------------------------------------------------------ settings

function settingsPanel(app: App, inBattle = false) {
  const s = app.save.settings;
  const set = (k: keyof GameSettings) => (v: boolean) => {
    s[k] = v;
    app.persist();
    if (k === 'music') audio.setMusic(v);
    if (k === 'sfx') audio.setSfx(v);
    if (k === 'highQuality' || k === 'outlines') {
      app.applyQuality();
      if (!inBattle) app.rebuildMenuView();
    }
  };
  return h(
    'div',
    { class: 'settings-panel' },
    toggle('🎵 Music', 'Procedural soundtrack', s.music, set('music')),
    toggle('🔊 Sound Effects', 'Tip: flip the iPhone silent switch off to hear sound', s.sfx, set('sfx')),
    toggle('✨ High Quality Graphics', 'Shadows, anti-aliasing and full resolution', s.highQuality, set('highQuality')),
    toggle('🖍️ Cartoon Outlines', 'Ink outlines on characters (turn off for more speed)', s.outlines, set('outlines')),
    toggle('☀️ Auto-collect Sun', 'Sun flies to you automatically', s.autoCollectSun, set('autoCollectSun')),
  );
}

export function settingsScreen(app: App) {
  let armed = false;
  const reset = btn(
    '🗑 Reset Progress',
    () => {
      if (!armed) {
        armed = true;
        reset.textContent = '⚠️ Tap again to erase everything';
        setTimeout(() => {
          armed = false;
          reset.textContent = '🗑 Reset Progress';
        }, 3000);
        return;
      }
      app.save = defaultSave();
      app.persist();
      app.showScreen('title');
    },
    'danger small',
  );
  return h(
    'div',
    { class: 'screen settings-screen' },
    topBar(app, 'Settings', () => app.showScreen('title')),
    h(
      'div',
      { class: 'scroll' },
      settingsPanel(app),
      h(
        'div',
        { class: 'help' },
        h('b', { text: 'How to play' }),
        h('p', { text: 'Tap a seed packet, then tap a lawn tile (or drag the packet onto the lawn). Tap or swipe over sun to collect it. Use 🌿 Plant Food then tap a plant to trigger its super ability. Use ⛏️ to dig up a plant. Pumpkin Shell can be planted on top of other plants. Survive every wave to win!' }),
      ),
      transferPanel(app),
      reset,
    ),
  );
}

/** Copy the save as a code, or load a code, to move progress between the artifact and the Home Screen app. */
function transferPanel(app: App) {
  const area = h('textarea', { class: 'transfer', attrs: { rows: '3', spellcheck: 'false', placeholder: 'Paste a progress code here, then tap Load', id: 'transfer-code' } }) as HTMLTextAreaElement;
  const status = h('small', { text: '' });
  const encode = () => btoa(unescape(encodeURIComponent(JSON.stringify(app.save))));
  let armed = false;
  return h(
    'div',
    { class: 'help' },
    h('b', { text: '📦 Transfer Progress' }),
    h('p', { text: 'Copy your progress code here, then paste it into the game on another website (for example the Home Screen app).' }),
    area,
    h(
      'div',
      { class: 'row', style: 'justify-content:flex-start' },
      btn(
        'Copy my code',
        () => {
          area.value = encode();
          area.select();
          navigator.clipboard?.writeText(area.value).then(
            () => (status.textContent = 'Copied! Paste it into the other copy of the game.'),
            () => (status.textContent = 'Code selected — use Copy from the menu.'),
          );
        },
        'small',
      ),
      btn(
        'Load code',
        () => {
          let data: Record<string, unknown>;
          try {
            data = JSON.parse(decodeURIComponent(escape(atob(area.value.trim()))));
          } catch {
            status.textContent = 'That code is not valid. Copy it again and paste the whole thing.';
            return;
          }
          if (!armed) {
            armed = true;
            status.textContent = 'Tap Load again to replace this device’s progress.';
            setTimeout(() => (armed = false), 4000);
            return;
          }
          app.save = migrate(data);
          app.persist();
          status.textContent = 'Progress loaded!';
        },
        'small primary',
      ),
    ),
    status,
  );
}

// ------------------------------------------------------------------ seed select

let seedFamily: Family | 'all' = 'all';

export function seedSelectScreen(app: App, level: LevelDef, slots: number, onStart: (loadout: PlantId[]) => void, onBack: () => void) {
  const r = rules(app.save);
  let chosen = app.save.lastLoadout.filter((p) => !!PLANTS[p]).slice(0, slots);
  const slotRow = h('div', { class: 'slot-row scroll-x' });
  const chipBox = h('div', { class: 'seed-chips' });
  const grid = h('div', { class: 'seed-grid' });
  const go = btn("Let's Rock!", () => onStart(chosen), 'primary rock');

  const renderSlots = () => {
    clear(slotRow);
    for (let i = 0; i < slots; i++) {
      const id = chosen[i];
      slotRow.append(
        id
          ? h(
              'button',
              { class: 'slot filled', onClick: () => ((chosen = chosen.filter((c) => c !== id)), click(), renderSlots(), renderGrid()) },
              thumbImg(id, PLANTS[id].name),
              h('div', { class: 'cost', text: String(PLANTS[id].cost) }),
            )
          : h('div', { class: 'slot empty' }),
      );
    }
    go.disabled = chosen.length === 0;
  };
  const renderGrid = () => {
    clear(grid);
    for (const d of PLANT_LIST.filter((p) => seedFamily === 'all' || p.family === seedFamily)) {
      const inUse = chosen.includes(d.id);
      const card = h(
        'button',
        { class: 'seed-card' + (inUse ? ' used' : '') + (level.feature === d.id ? ' featured' : '') },
        thumbImg(d.id, d.name),
        h('div', { class: 'sc-name', text: d.name }),
        h('div', { class: 'sc-cost', text: `☀️${d.cost}` }),
        h('div', { class: 'sc-lvl', text: `${r.plantLevel(d.id)}` }),
      );
      card.addEventListener('click', () => {
        if (inUse) chosen = chosen.filter((c) => c !== d.id);
        else if (chosen.length < slots) chosen = [...chosen, d.id];
        else return audio.play('error');
        audio.play('select');
        renderSlots();
        renderGrid();
      });
      grid.append(card);
    }
  };
  const renderChips = () => {
    clear(chipBox);
    chipBox.append(
      familyChips(seedFamily, (f) => {
        seedFamily = f;
        renderChips();
        renderGrid();
      }),
    );
  };
  renderSlots();
  renderChips();
  renderGrid();

  const kinds = [...new Set(level.waves.flatMap((w) => w.zombies))] as ZombieId[];
  const zlist = h('div', { class: 'zlist scroll' }, ...kinds.map((z) => h('div', { class: 'zitem' }, thumbImg(z, ZOMBIES[z].name, true), h('span', { text: ZOMBIES[z].name }))));
  const tip = level.feature && PLANTS[level.feature] ? h('div', { class: 'tip', text: `💡 Try ${PLANTS[level.feature].name}!` }) : null;

  return h(
    'div',
    { class: 'screen seed-screen' },
    h('div', { class: 'seed-head' }, btn('◀', onBack, 'small'), h('h2', { text: level.id === 'sandbox' ? '🧪 Plant Playground' : `${level.id} · ${level.name}` }), h('div', { class: 'ult-chip', text: `${slots} slots` + (r.ultimate ? ' 👑' : '') }), tip),
    slotRow,
    h('div', { class: 'seed-body' }, h('div', { class: 'seed-panel' }, chipBox, h('div', { class: 'seed-scroll scroll' }, grid)), h('div', { class: 'zombie-panel' }, h('small', { class: 'label', text: level.id === 'sandbox' ? 'Endless waves of' : 'Zombies here' }), zlist)),
    go,
  );
}

// ------------------------------------------------------------------ pause & results

export function pauseMenu(app: App, view: BattleView, handlers: { resume: () => void; restart: () => void; quit: () => void }) {
  const ult = h('div', { class: 'scroll pause-scroll' }, ultimatePanel(app, () => view.applyRules()), settingsPanel(app, true));
  return h(
    'div',
    { class: 'overlay pause' },
    h('div', { class: 'panel' }, h('h2', { text: 'Paused' }), h('div', { class: 'row' }, btn('▶ Resume', handlers.resume, 'primary'), btn('↻ Restart', handlers.restart), btn('🗺 Map', handlers.quit)), ult),
  );
}

export function resultsScreen(
  app: App,
  o: {
    won: boolean;
    level: LevelDef;
    stats: { killed: number; planted: number; sunCollected: number; plantFoodUsed: number };
    coins: number;
    gems: number;
    packets: number;
    next?: () => void;
    retry: () => void;
    map: () => void;
  },
) {
  const r = rules(app.save);
  return h(
    'div',
    { class: 'overlay results ' + (o.won ? 'won' : 'lost') },
    h(
      'div',
      { class: 'panel' },
      h('div', { class: 'res-icon', text: o.won ? '🏆' : '🧠' }),
      h('h2', { text: o.won ? 'Level Complete!' : 'The zombies broke in!' }),
      h('p', { text: o.won ? `You defended ${o.level.id} · ${o.level.name}` : 'Your brains were snacked on. Try a new strategy!' }),
      h(
        'div',
        { class: 'stats' },
        h('div', { class: 'stat' }, h('small', { text: 'Zombies' }), h('b', { text: String(o.stats.killed) })),
        h('div', { class: 'stat' }, h('small', { text: 'Planted' }), h('b', { text: String(o.stats.planted) })),
        h('div', { class: 'stat' }, h('small', { text: 'Sun' }), h('b', { text: String(o.stats.sunCollected) })),
        o.won ? h('div', { class: 'stat' }, h('small', { text: 'Coins' }), h('b', { text: r.unlimitedCurrency ? `+${o.coins} (∞)` : `+${o.coins}` })) : null,
        o.won ? h('div', { class: 'stat' }, h('small', { text: 'Seed packets' }), h('b', { text: `+${o.packets}` })) : null,
        o.won && o.gems ? h('div', { class: 'stat' }, h('small', { text: 'Gems' }), h('b', { text: `+${o.gems}` })) : null,
      ),
      h('div', { class: 'row' }, o.won && o.next ? btn('Next Level ▶', o.next, 'primary') : null, btn(o.won ? '↻ Replay' : '↻ Try Again', o.retry, o.won ? '' : 'primary'), btn('🗺 World Map', o.map)),
    ),
  );
}
