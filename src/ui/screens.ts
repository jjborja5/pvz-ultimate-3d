// Menu screens and overlays (DOM over the 3D canvas).
import type { App } from '../app';
import { audio } from '../game/audio';
import {
  LEVELS,
  MAX_PLANT_LEVEL,
  PLANTS,
  PLANT_ORDER,
  WORLDS,
  ZOMBIES,
  ZOMBIE_ORDER,
  levelMultipliers,
  type LevelDef,
  type PlantId,
  type ZombieId,
} from '../game/config';
import { rules, defaultSave, type UltimateSettings, type GameSettings } from '../game/save';
import type { BattleView } from '../views/battleView';
import { clear, h } from './dom';
import { plantThumb, zombieThumb } from './thumbs';

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

function stars(n: number) {
  return '★'.repeat(n) + '☆'.repeat(MAX_PLANT_LEVEL - n);
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

// ------------------------------------------------------------------ title

export function titleScreen(app: App) {
  const modes = [
    ['⚔️', 'Arena'],
    ['♾️', 'Survival'],
    ['🧪', 'Sandbox'],
  ];
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
      btn('▶  Play Adventure', () => app.showScreen('map'), 'big primary'),
      h(
        'div',
        { class: 'row' },
        btn('📖 Almanac', () => app.showScreen('almanac')),
        btn('👑 Ultimate', () => app.showScreen('ultimate'), 'gold'),
        btn('⚙️ Settings', () => app.showScreen('settings')),
      ),
      h(
        'div',
        { class: 'modes' },
        ...modes.map(([e, n]) => h('div', { class: 'mode-tile soon' }, h('span', { text: e }), h('b', { text: n }), h('small', { text: 'Coming soon' }))),
      ),
    ),
    resources(app),
    h('div', { class: 'footer', text: 'Unofficial fan-made game · original art & sound · Phase 1 build' }),
  );
}

// ------------------------------------------------------------------ world map

let selectedWorld = 1;

export function mapScreen(app: App) {
  const tabs = h('div', { class: 'world-tabs' });
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
      body.append(h('div', { class: 'soon-card' }, h('b', { text: 'Coming in a future update' }), h('p', { text: 'This world is planned but not built yet. World 1 is fully playable now.' })));
      return;
    }
    const path = h('div', { class: 'level-path' });
    levels.forEach((l) => {
      const done = app.save.completed[l.id] ?? 0;
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
          h('div', { class: 'ln-meta', text: `${l.waves.length} waves` + (done ? ' · ✅' : '') }),
        ),
      );
    });
    body.append(path);
  };
  render();
  return h('div', { class: 'screen map-screen' }, topBar(app, 'World Map', () => app.showScreen('title')), tabs, body);
}

// ------------------------------------------------------------------ almanac

export function almanacScreen(app: App) {
  let tab: 'plants' | 'zombies' = 'plants';
  let plant: PlantId = 'peashooter';
  let zombie: ZombieId = 'basic';
  const list = h('div', { class: 'alm-list' });
  const detail = h('div', { class: 'alm-detail' });
  const tabs = h('div', { class: 'alm-tabs' });
  const r = rules(app.save);

  const stat = (k: string, v: string) => h('div', { class: 'stat' }, h('small', { text: k }), h('b', { text: v }));

  const render = () => {
    clear(list);
    clear(detail);
    clear(tabs);
    tabs.append(
      h('button', { class: 'tab' + (tab === 'plants' ? ' active' : ''), text: '🌱 Plants', onClick: () => ((tab = 'plants'), click(), render()) }),
      h('button', { class: 'tab' + (tab === 'zombies' ? ' active' : ''), text: '🧟 Zombies', onClick: () => ((tab = 'zombies'), click(), render()) }),
    );
    if (tab === 'plants') {
      for (const id of PLANT_ORDER) {
        list.append(
          h(
            'button',
            { class: 'alm-card' + (id === plant ? ' active' : ''), onClick: () => ((plant = id), click(), render()) },
            h('img', { attrs: { src: plantThumb(id), alt: PLANTS[id].name } }),
            h('span', { text: PLANTS[id].name }),
          ),
        );
      }
      const d = PLANTS[plant];
      const lvl = r.plantLevel(plant);
      const m = levelMultipliers(lvl);
      const stats = [stat('Sun cost', String(d.cost)), stat('Recharge', `${(d.recharge * m.recharge).toFixed(1)}s`), stat('Toughness', d.toughness)];
      if (d.damage) stats.push(stat('Damage', `${Math.round(d.damage * m.damage)} × ${d.shots}`));
      if (d.blastDamage) stats.push(stat('Blast', String(Math.round(d.blastDamage * m.damage))));
      if (d.sunAmount) stats.push(stat('Sun', `${Math.round((d.sunAmount * m.sun) / 5) * 5} / ${d.sunInterval}s`));
      detail.append(
        h('img', { class: 'alm-big', attrs: { src: plantThumb(plant), alt: d.name } }),
        h('div', { class: 'alm-info' }, h('h3', { text: d.name }), h('div', { class: 'stars', text: `${stars(lvl)}  Level ${lvl}` }), h('div', { class: 'stats' }, ...stats), h('p', { text: d.blurb }), h('p', { class: 'pf-line', text: `🌿 Plant Food — ${d.plantFood}` }), h('small', { class: 'unlocked', text: '🔓 Unlocked' })),
      );
    } else {
      for (const id of ZOMBIE_ORDER) {
        list.append(
          h(
            'button',
            { class: 'alm-card' + (id === zombie ? ' active' : ''), onClick: () => ((zombie = id), click(), render()) },
            h('img', { attrs: { src: zombieThumb(id), alt: ZOMBIES[id].name } }),
            h('span', { text: ZOMBIES[id].name }),
          ),
        );
      }
      const d = ZOMBIES[zombie];
      detail.append(
        h('img', { class: 'alm-big', attrs: { src: zombieThumb(zombie), alt: d.name } }),
        h(
          'div',
          { class: 'alm-info' },
          h('h3', { text: d.name }),
          h('div', { class: 'stats' }, stat('Health', String(d.hp + d.armor)), stat('Toughness', d.toughness), stat('Speed', d.speedLabel), stat('Attack', d.smash ? 'Smash' : 'Chomp')),
          h('p', { text: d.blurb }),
        ),
      );
    }
  };
  render();
  return h('div', { class: 'screen almanac-screen' }, topBar(app, 'Almanac', () => app.showScreen('title')), tabs, h('div', { class: 'alm-body' }, list, detail));
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
      toggle('🪙 Unlimited Coins', 'Coin balance shows ∞', u.enabled, () => {}, true),
      toggle('🌰 Unlimited Seed Packets', 'Upgrade currency shows ∞', u.enabled, () => {}, true),
      toggle('♾️ Unlimited Rewards', 'All currencies are infinite', u.enabled, () => {}, true),
      toggle('🔓 All Plants Unlocked', 'Always on — every built plant is available', true, () => {}, true),
      toggle('☀️ Unlimited Sunlight', 'Plant anything, any time', u.unlimitedSun, set('unlimitedSun')),
      toggle('🌱 Unlimited Plant Food', 'Boost plants as often as you like', u.unlimitedPlantFood, set('unlimitedPlantFood')),
      toggle('⭐ Max Plant Upgrades', `All plants at level ${MAX_PLANT_LEVEL} (+100% dmg & health)`, u.maxUpgrades, set('maxUpgrades')),
      toggle('➕ Two Extra Seed Slots', '8 seed slots instead of 6', u.extraSlots, set('extraSlots')),
      toggle('⚡ Instant Recharge', 'Seed packets never need to recharge', u.instantRecharge, set('instantRecharge')),
      toggle('👑 Invincibility', 'Plants take no damage; the house is shielded', u.invincible, set('invincible')),
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
  const render = () => {
    clear(el);
    el.append(
      topBar(app, 'Ultimate Mode', () => app.showScreen('title')),
      h('div', { class: 'scroll' }, ultimatePanel(app, () => {
        const res = el.querySelector('.resources');
        res?.replaceWith(resources(app));
      })),
    );
  };
  render();
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
    if (k === 'highQuality') {
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
    toggle('☀️ Auto-collect Sun', 'Sun flies to you automatically', s.autoCollectSun, set('autoCollectSun')),
  );
}

export function settingsScreen(app: App) {
  const reset = btn(
    '🗑 Reset Progress',
    () => {
      if (confirm('Erase all progress and settings?')) {
        app.save = defaultSave();
        app.persist();
        app.showScreen('title');
      }
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
      h('div', { class: 'help' }, h('b', { text: 'How to play' }), h('p', { text: 'Tap a seed packet, then tap a lawn tile (or drag the packet onto the lawn). Tap or swipe over sun to collect it. Use 🌿 Plant Food then tap a plant to supercharge it. Use ⛏️ to dig up a plant. Survive every wave to win!' })),
      reset,
    ),
  );
}

// ------------------------------------------------------------------ seed select

export function seedSelectScreen(app: App, level: LevelDef, onStart: (loadout: PlantId[]) => void, onBack: () => void) {
  const r = rules(app.save);
  const slots = r.seedSlots;
  let chosen = app.save.lastLoadout.filter((p) => PLANT_ORDER.includes(p)).slice(0, slots);
  const slotRow = h('div', { class: 'slot-row' });
  const grid = h('div', { class: 'seed-grid' });
  const go = btn("Let's Rock!", () => onStart(chosen), 'primary rock');

  const render = () => {
    clear(slotRow);
    clear(grid);
    for (let i = 0; i < slots; i++) {
      const id = chosen[i];
      slotRow.append(
        id
          ? h(
              'button',
              { class: 'slot filled', onClick: () => ((chosen = chosen.filter((c) => c !== id)), click(), render()) },
              h('img', { attrs: { src: plantThumb(id), alt: PLANTS[id].name } }),
              h('div', { class: 'cost', text: String(PLANTS[id].cost) }),
            )
          : h('div', { class: 'slot empty' }),
      );
    }
    for (const id of PLANT_ORDER) {
      const inUse = chosen.includes(id);
      grid.append(
        h(
          'button',
          {
            class: 'seed-card' + (inUse ? ' used' : ''),
            onClick: () => {
              if (inUse) chosen = chosen.filter((c) => c !== id);
              else if (chosen.length < slots) chosen = [...chosen, id];
              else return audio.play('error');
              audio.play('select');
              render();
            },
          },
          h('img', { attrs: { src: plantThumb(id), alt: PLANTS[id].name } }),
          h('div', { class: 'sc-name', text: PLANTS[id].name }),
          h('div', { class: 'sc-cost', text: `☀️${PLANTS[id].cost}` }),
          h('div', { class: 'sc-stars', text: '★'.repeat(r.plantLevel(id)) }),
        ),
      );
    }
    go.disabled = chosen.length === 0;
  };
  render();

  const kinds = [...new Set(level.waves.flatMap((w) => w.zombies))] as ZombieId[];
  const zlist = h('div', { class: 'zlist' }, ...kinds.map((z) => h('div', { class: 'zitem' }, h('img', { attrs: { src: zombieThumb(z), alt: ZOMBIES[z].name } }), h('span', { text: ZOMBIES[z].name }))));

  return h(
    'div',
    { class: 'screen seed-screen' },
    h('div', { class: 'seed-head' }, btn('◀', onBack, 'small'), h('h2', { text: `${level.id} · ${level.name}` }), r.ultimate ? h('div', { class: 'ult-chip', text: `👑 ${slots} slots` }) : null),
    slotRow,
    h('div', { class: 'seed-body' }, h('div', { class: 'seed-panel' }, h('small', { class: 'label', text: 'Choose your plants' }), grid), h('div', { class: 'zombie-panel' }, h('small', { class: 'label', text: 'Zombies here' }), zlist)),
    go,
  );
}

// ------------------------------------------------------------------ pause & results

export function pauseMenu(app: App, view: BattleView, handlers: { resume: () => void; restart: () => void; quit: () => void }) {
  const ult = h('div', { class: 'scroll pause-scroll' }, ultimatePanel(app, () => view.applyRules()), settingsPanel(app, true));
  return h(
    'div',
    { class: 'overlay pause' },
    h(
      'div',
      { class: 'panel' },
      h('h2', { text: 'Paused' }),
      h('div', { class: 'row' }, btn('▶ Resume', handlers.resume, 'primary'), btn('↻ Restart', handlers.restart), btn('🗺 Map', handlers.quit)),
      ult,
    ),
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
        o.won && o.gems ? h('div', { class: 'stat' }, h('small', { text: 'Gems' }), h('b', { text: `+${o.gems}` })) : null,
      ),
      h('div', { class: 'row' }, o.won && o.next ? btn('Next Level ▶', o.next, 'primary') : null, btn(o.won ? '↻ Replay' : '↻ Try Again', o.retry, o.won ? '' : 'primary'), btn('🗺 World Map', o.map)),
    ),
  );
}
