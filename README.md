# 🌱🧟 Plants vs. Zombies — Ultimate 3D Edition

An unofficial, fan-made, mobile-first **3D lane tower-defense game** inspired by the colorful cartoon
tower-defense genre. It is built for **iPhone Safari in landscape** with Three.js, TypeScript and Vite.

All models are built in code from simple 3D shapes, all sound and music is synthesized live with the
Web Audio API, and there are no copied artwork, model, music or sound files.

> **Status: Phase 1.** A complete, playable vertical slice: one world with 5 levels, 7 plants,
> 5 zombie types (including a boss) and the Ultimate Mode foundation. See the [roadmap](#roadmap) for what's next.

---

## ✅ What works (Phase 1)

**Battlefield & combat**
- A 3D backyard with a 5-lane × 9-column lawn, a house, a street, a fence, trees, drifting clouds, cel-shaded lighting and real-time shadows.
- Plants shoot real projectiles that travel down the lane, hit zombies and burst into particles.
- Zombies walk, eat plants, flash when hit, turn blue when chilled, lose their cone or bucket when it breaks, and lose their heads when they die. Explosions char them.
- One lawn mower per lane is your last line of defense. If a zombie gets past it, you lose.
- Sun falls from the sky, and Sunflowers make more. **Tap or swipe** over sun to collect it.
- Waves get harder. Huge waves are announced with a banner and a siren, and the last one is the **FINAL WAVE**. A progress meter shows flags for the huge waves.
- **Win** by defeating every wave and tapping the trophy. **Lose** if a zombie reaches the house.
- Plant Food: some zombies glow green and drop it. Each plant has its own power-up.
- Shovel to dig up plants, a 1×/2× speed toggle, and a pause menu.

**Plants (7):** Peashooter, Sunflower, Wall-nut (cracks as it gets damaged), Potato Mine (arms, then explodes), Cherry Bomb (3×3 blast), Snow Pea (slows), Repeater (fires two peas).

**Zombies (5):** Shambler, Banner (flag), Conehead, Buckethead, and the **Mega Brute** boss (smashes plants with a log club).

**Campaign & menus**
- Title screen with an animated 3D backyard.
- World map with all 11 planned worlds. **World 1 "Sunrise Meadow" is playable with 5 levels**, and its final level is a boss level. The other worlds are clearly marked "coming in a future update".
- Seed selection before each level, with a preview of the level's zombies standing on the street.
- An Almanac for plants and zombies, with 3D-rendered portraits, stats, upgrade stars and descriptions.
- A Settings screen: music, sound effects, graphics quality, auto-collect sun, how to play, and reset progress.
- Arena, Survival and Sandbox appear on the title screen as "Coming soon". They are **not built yet**.

**👑 Ultimate Mode** is on by default. It is saved automatically, and you can toggle each perk from the Ultimate screen or from the in-battle pause menu:

| Perk | Status |
|---|---|
| 💎 Unlimited Gems / 🪙 Coins / 🌰 Seed Packets / ♾️ Rewards | ✅ The balances show ∞. Gems, coins and seed packets are earned and saved, but nothing spends them yet because the shop is planned for a later phase. |
| ☀️ Unlimited Sunlight | ✅ Plant anything, any time |
| 🌱 Unlimited Plant Food | ✅ |
| 🔓 All plants unlocked | ✅ Always. All implemented content is available immediately. |
| ⭐ Maximum plant upgrades | ✅ All plants at level 5 (+100% damage and health, faster recharge, more sun) |
| ➕ Two additional seed slots | ✅ 8 slots instead of 6 |
| ⚡ Instant recharge (optional) | ✅ |
| 👑 Invincibility (optional) | ✅ Plants take no damage, and a shield protects the house |

**Saving:** progress, currencies, your last plant loadout, Ultimate Mode perks and settings are saved automatically in the browser's local storage.

**Mobile:** landscape layout with a "rotate your iPhone" prompt in portrait. It respects the notch and safe areas, blocks pinch and double-tap zoom, can be added to the Home Screen as a full-screen app, caps the pixel ratio for performance, merges the static scenery into a handful of draw calls, and has a Low graphics option.

## 📱 How to play on your iPhone

**Play from GitHub Pages (a permanent link that works once the PR is merged)**
1. In Safari, open the repository on github.com → **Settings** → **Pages** → under *Build and deployment* set **Source = GitHub Actions** (one-time).
2. Merge the Phase 1 pull request. The *Deploy to GitHub Pages* workflow publishes the game to
   `https://jjborja5.github.io/pvz-ultimate-3d/` (the Actions tab shows progress).
3. Open that link in Safari, turn the phone sideways and play.
4. Optional: tap **Share → Add to Home Screen** to get a full-screen app icon with no Safari bars.

**Tips:** flip the iPhone's silent switch off to hear sound, because iOS mutes web audio in silent mode. Sound starts after your first tap.

### Controls
- **Plant:** tap a seed packet, then tap a lawn tile, or drag the packet onto the lawn.
- **Collect sun:** tap it, or swipe your finger across it.
- **Plant Food:** tap 🌿, then tap a plant.
- **Shovel:** tap ⛏️, then tap a plant.
- **⏸** pauses the game and gives quick access to Ultimate Mode toggles. **1×/2×** changes the game speed.

## 🛠 Development

```bash
npm install
npm run dev          # local dev server (also reachable from a phone on the same Wi-Fi)
npm run check        # typecheck + unit tests + production build
npm run build        # multi-file build in dist/ (used by GitHub Pages)
npm run build:single # one self-contained HTML file in dist-single/
```

Tests (`tests/`) run the battle simulation headlessly:
- core rules: winning, losing, mowers, invincibility, sun costs, recharge, plant food, cherry bomb area
- a **balance test** where a scripted player beats every level *without* Ultimate Mode

### Project structure
```
src/
  main.ts              boot, iOS gesture handling
  app.ts               renderer, render loop, save, screen navigation
  styles.css           all UI styling (mobile landscape first)
  game/
    config.ts          data: plants, zombies, worlds, levels, upgrade multipliers
    battle.ts          the battle simulation (no DOM, unit-testable)
    models.ts          procedural cel-shaded 3D models
    environment.ts     backyard scene, lighting, static-mesh merging
    particles.ts       instanced particle system + shockwaves
    audio.ts           synthesized sound effects and music
    save.ts            save data, Ultimate Mode rules
  views/
    battleView.ts      battle camera, touch input, HUD, flow
    menuView.ts        animated menu backdrop
  ui/
    screens.ts         title, map, almanac, ultimate, settings, seed select, pause, results
    thumbs.ts          renders 3D portraits for seed packets and the almanac
    dom.ts             tiny DOM helper
```

Adding content is mostly data: a new level is a list of waves in `config.ts`, and a new plant or zombie is a `config.ts` entry plus a model builder in `models.ts`.

## 🗺 Roadmap

Planned, **not yet implemented**:
- **Phase 2:** more plants (e.g. lobbers, area attackers and support plants) and more zombies, plus more levels for World 1. A shop and upgrade screen will spend coins, gems and seed packets.
- **Phase 3+:** the remaining 10 themed worlds, each with its own environment, mechanics, zombies and boss.
- Arena, Survival (endless) and Sandbox modes.
- Star challenges per level, more boss battles, Zen-garden style extras.
- Better audio, more animations and more particle polish.

---
*Unofficial fan project for personal use. Not affiliated with or endorsed by any game publisher. All art and sound are original and generated in code.*
