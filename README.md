# 🌱🧟 Plants vs. Zombies — Ultimate 3D Edition

An unofficial, fan-made, mobile-first **3D lane tower-defense game** inspired by the colorful cartoon
tower-defense genre. It is built for **iPhone Safari in landscape** with Three.js, TypeScript and Vite.

All models are built in code from simple 3D shapes, all sound and music is synthesized live with the
Web Audio API, and there are no copied artwork, model, music or sound files.

> **Status: Phase 2.** **100 playable plants**, each with its own 3D character, ability and Plant Food
> power, 11 zombie types, a 10-level World 1, an endless **Plant Playground** sandbox, plant upgrades,
> Power-ups, daily rewards and the full Ultimate Mode. Worlds 2–11 are still to come. See the [roadmap](#roadmap).

---

## ✅ What works (Phase 2)

### 🌱 100 plants, all playable
Every plant has a unique 3D model, its own ability, health, sun cost, recharge time, upgrade stats (levels 1–10),
a Plant Food super ability, an almanac entry and a working seed packet. Each one is placed in a real battle in
the automated tests and has to prove that its signature mechanic works.

| Family | Plants |
|---|---|
| 🟢 Pod Squad (13) | Peashooter, Repeater, Tri-Pea, Peek-a-Pea, Gatling Pod, Star Sprout, Seeker Thistle, Needle Cactus, Boomerose, Rock Pea, Roto Turnip, Sniper Pea, Ricochet Radish |
| ☀️ Sunshine (8) | Sunflower, Double Bloom, Golden Bud, Ancient Sunflower, Moon Blossom, Sun-mint, Sun Bean, Lucky Clover |
| 🛡️ Bulwark (9) | Wall-nut, Tower Nut, Hex Nut, Spiky Durian, Leaf Guard, Pumpkin Shell, Boulder Nut, Pea-nut, Stink Onion |
| 💥 Kaboom (9) | Potato Mine, Cherry Bomb, Boom Nut, Grapeburst, Stone Mine, Pomegrenade, Firecracker Fig, Coconut Cannon, Doom Cap |
| 🔥 Blaze (8) | Ember Pea, Blaze Pepper, Flame Dragon, Magma Guava, Torch Vine, Sun Lens, Chili Bean, Pepper Pult |
| ❄️ Frost (6) | Snow Pea, Frost Melon, Frostbite Lettuce, Frost Dragon, Frost Bloom, Frost Cap |
| ⚡ Voltage (7) | Beam Bean, Zap Reed, Storm Berry, Plasma Citrus, Shock Currant, Volt Tea, Volt Pea |
| 🥬 Lobbers (5) | Butter Cob, Melon Mortar, Cabbage Lobber, Headbutt Lettuce, Pinecone Pitcher |
| 🌙 Mystic (10) | Hypno Cap, Hex Hazel, Shade Pea, Shadow Lobber, Nightbloom, Grim Rose, Veil-mint, Mind Flower, Shrink Violet, Toxic Ivy |
| 🥊 Brawlers (7) | Punch Choy, Snapjaw, Squashling, Thornmat, Wasabi Lash, Poke Okra, Bulb Bowler |
| 🍄 Spores (6) | Sunspore, Puffcap, Fumecap, Gloomcap, Goo Pea, Magnet Cap |
| 🌬️ Gust (8) | Garlunk, Gale Kale, Fan Clover, Sticky Sap, Tangle Vine, Gust Fern, Time Thyme, Dandelion Drifter |
| 💚 Support (4) | Vigor Lily, Seed Sower, Healing Hibiscus, Drum Daisy |

Gameplay roles include straight, three-lane, backward, five-way, diagonal and homing shooters, lobbers that arc
over shields, splash, burn, chill, freeze, poison, stun, knockback and weaken effects, chain lightning, lane
lasers, sun-powered beams, sniping, melee brawlers, devouring, squashing, transforming zombies into plants,
hypnosis, shrinking, wind and lane-diverting, walls with thorns, regeneration, knockback, explosions or stun,
overlay armor (Pumpkin Shell), sun and Plant Food producers, healers, attack-speed and damage auras, fire
conversion (Torch Vine), ground hazards, lava pools and craters.

Names, designs and models are original. They are inspired by the *roles* of PvZ2 plants (for example, Tri-Pea is
the three-lane role and Snapjaw is the devourer role); no artwork was copied.

### 🎨 New character art system
- Every character is sculpted in code from organic shapes: lathed bodies, curved tube stems, bent leaves and
  petals, gradients, and big expressive eyes with highlights, lids and brows, plus mouths and cheeks.
- Cartoon ink outlines (can be switched off in Settings for extra speed).
- Idle sway, blinking, attack recoil, lobbing arms, punches, chomping jaws, growing, swelling before
  explosions, burrowing mines and a Plant Food glow.
- Each character is one skinned mesh with bones, so a detailed plant or zombie costs only 1–2 draw calls.
  Characters use soft contact shadows, and the scenery shadow map is rendered once. Together these halve
  the triangle count, which helps on iPhone.

### 🧟 Zombies (11)
Shambler, Banner, Conehead, Buckethead, **Pole Jumper** (vaults over plants unless they're tall walls),
**Scrappy Imp** (fast), **Balloon** (flies over plants; needs anti-air, wind or explosions), **Screen Door** (its shield blocks
straight shots; lobbers fly over it), **Iron Knight** (metal armor), **Newsreader** (enrages when the paper
breaks) and the **Mega Brute** boss (smash-proof plants survive it).

### 🎮 Modes & meta
- **Adventure:** World 1 *Sunrise Meadow* now has 10 levels with new zombies and a boss finale. Each level
  suggests a featured plant.
- **Plant Playground:** an endless sandbox with 10 seed slots and growing waves, for testing all 100 plants.
- **Plant Collection:** filter by 13 plant families, read the stats, and upgrade plants with coins and seed
  packets. Upgrades are free with Ultimate Mode.
- **Power-ups:** Power Zap, Power Toss and Power Snow. Tap or swipe zombies for 5 seconds. They cost 500 coins
  each, or are free with Ultimate Mode.
- **Daily rewards:** a 7-day streak of coins, seed packets and gems.
- Zombie almanac with counter tips.
- Arena, Survival and Mini-games appear on the title screen as "Coming soon". They are **not built yet**.

### 👑 Ultimate Unlimited Edition
Every perk can be switched on or off individually, from the Ultimate screen or from the in-battle pause menu,
and the settings are saved automatically.

| Perk | Status |
|---|---|
| 💎 Unlimited Gems / 🪙 Coins / 🌰 Seed Packets / 🎁 Rewards | ✅ The balances show ∞, and upgrades and power-ups are free |
| ☀️ Unlimited Sunlight | ✅ |
| 🌱 Unlimited Plant Food | ✅ |
| 🔓 All implemented plants unlocked | ✅ Always (all 100) |
| ⭐ Maximum plant levels | ✅ Every plant at level 10 |
| ➕ Two extra seed slots | ✅ 8 slots (the sandbox always has 10) |
| ⚡ Instant recharge | ✅ Optional |
| 🛡️ Plant invincibility | ✅ Optional |
| 💥 Maximum damage | ✅ Optional (plants hit 100× harder) |

### 💾 Saves
Progress, currencies, upgrades, loadout, Ultimate settings and the daily streak are saved automatically.
Phase 1 saves are migrated: levels you beat are mapped to the new level numbers, and nothing is lost.

## 📱 How to play on your iPhone

**Play from GitHub Pages (a permanent link that works once the PR is merged)**
1. In Safari, open the repository on github.com → **Settings** → **Pages** → under *Build and deployment* set **Source = GitHub Actions** (one-time).
2. Merge the pull request(s) into `main`. The *Deploy to GitHub Pages* workflow publishes the game to
   `https://jjborja5.github.io/pvz-ultimate-3d/` (the Actions tab shows progress).
3. Open that link in Safari, turn the phone sideways and play.
4. Optional: tap **Share → Add to Home Screen** to get a full-screen app icon with no Safari bars.

**Tips:** flip the iPhone's silent switch off to hear sound, because iOS mutes web audio in silent mode. Sound starts after your first tap.

### Controls
- **Plant:** tap a seed packet, then tap a lawn tile, or drag the packet onto the lawn.
- **Collect sun:** tap it, or swipe your finger across it.
- **Plant Food:** tap 🌿, then tap a plant.
- **Shovel:** tap ⛏️, then tap a plant.
- **Power-ups:** tap ⚡ 🖐️ or ❄️ (bottom left), then tap or swipe zombies for 5 seconds.
- **⏸** pauses the game and gives quick access to Ultimate Mode toggles. **1×/2×** changes the game speed.

## 🛠 Development

```bash
npm install
npm run dev          # local dev server (also reachable from a phone on the same Wi-Fi)
npm run check        # typecheck + unit tests + production build
npm run build        # multi-file build in dist/ (used by GitHub Pages)
npm run build:single # one self-contained HTML file in dist-single/
```

Tests (`tests/`, 405 tests) run the battle simulation headlessly:
- `plants.test.ts`: every one of the 100 plants has valid data, a distinct model and a unique behavior.
  It acts on zombies in a real battle, and its Plant Food works.
- `mechanics1-4.test.ts`: each plant's signature mechanic, one batch of 25 per file, plus power-ups.
- `battle.test.ts`: core rules (win, lose, mowers, invincibility, sun, recharge).
- `balance.test.ts`: a scripted player beats every World 1 level *without* Ultimate Mode.
- `save.test.ts`: Phase 1 → Phase 2 save migration, Ultimate rules and daily rewards.

### Project structure
```
src/
  main.ts              boot, iOS gesture handling
  app.ts               renderer, render loop, save, screen navigation
  styles.css           all UI styling (mobile landscape first)
  game/
    config.ts          data: zombies, worlds, levels, upgrade costs/multipliers
    battle.ts          the battle simulation (no DOM, unit-testable)
    plants/            plant types, batch1-4 data (100 plants), behavior interpreter, stats
    models/            rig kit (skinned meshes, faces, outlines), plant/zombie/prop builders
    fx.ts              beams, lightning, glows, pools, craters, wind
    daily.ts           daily reward streak
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
- **Worlds 2–11**, each with its own environment, special mechanics (for example sand tiles, planks and
  cannons, mine carts, power tiles, gravestones, water lanes, frozen tiles, gold tiles, music events, dino
  helpers), world-specific zombies and a boss.
- Arena, Survival challenge series, mini-games and special challenge levels.
- Star challenges for each level and more advanced wave scripting.
- Pushing the collection past 100 plants, plus more zombie types.

---
*Unofficial fan project for personal use. Not affiliated with or endorsed by any game publisher. All art and sound are original and generated in code.*
