# Castle Dominion: phone builds (iOS + Android)

One shared Godot 4.5.1 codebase. Phone-specific behaviour (graphics preset, safe area, frame
cap, back button, pause on background) is chosen at runtime. No gameplay or God Mode feature
is removed on any platform.

| | Samsung Galaxy A21 | iPhone 11 Pro Max |
|---|---|---|
| Package | Signed APK (`CastleDominion.apk`), arm64-v8a + armeabi-v7a | Xcode project (`CastleDominion-iOS-Xcode.zip`) |
| Built here? | **Yes**, signed and verified | **Project only**: an `.ipa` needs macOS + Xcode, which this Linux environment does not have |
| Default graphics | **Low** (auto-detected: Android with < 7 GB RAM) | **High** (auto-detected: iOS) |
| Renderer | Vulkan Mobile; Godot falls back to OpenGL ES 3 automatically if the Vulkan driver fails | Metal (via MoltenVK) |
| Min OS | Android 7.0 (API 24), target API 35 | iOS 14.0 |
| Orientation | Portrait | Portrait |
| Saves | `user://castle_dominion.cfg` in app storage, saved atomically and on backgrounding | Same, in the app's sandbox |

## Install on the Samsung Galaxy A21

1. Copy `CastleDominion.apk` to the phone: download it on the phone, or connect a USB cable and copy it into `Download`.
2. Open **My Files → Downloads** and tap `CastleDominion.apk`.
3. If Android asks, allow **Install unknown apps** for My Files (or your browser), then go back and tap the APK again.
4. Tap **Install**. If Google Play Protect warns about an unknown developer, choose **More details → Install anyway**. The app is signed with your own personal key, not a Play Store key.
5. Open **Castle Dominion**. The first launch shows the title splash, then the menu.

**Updating later:** a newer APK installs over the old one only if it is signed with the **same keystore**. Keep the keystore file and its password safe (they are delivered separately and are deliberately **not** in the public repository). If the key is lost, uninstall the old app first; that also deletes its saves.

With USB debugging enabled you can also install with `adb install -r CastleDominion.apk`.

## Install on the iPhone 11 Pro Max

Apple only lets you install apps you build yourself through Xcode on a Mac. You need:

- A **Mac** with **macOS 14 (Sonoma) or newer** and **Xcode 16 or newer** (free from the Mac App Store).
- An **Apple ID**. A free account works: the app then expires after **7 days** and needs re-running from Xcode. A paid Apple Developer Program membership ($99/year) gives 1-year installs and TestFlight.
- A USB cable for the iPhone.

Steps:

1. Unzip `CastleDominion-iOS-Xcode.zip` on the Mac and open `ios/CastleDominion.xcodeproj` in Xcode.
2. Xcode → **Settings → Accounts** → add your Apple ID.
3. Select the **CastleDominion** target → **Signing & Capabilities**:
   - leave **Automatically manage signing** on;
   - set **Team** to your Apple ID / Personal Team (this replaces the placeholder team `ABCDE12345`);
   - if Xcode says the bundle ID is unavailable, change `io.castledominion.godmode` to something unique, e.g. `io.<yourname>.castledominion`.
4. On the iPhone, turn on **Settings → Privacy & Security → Developer Mode** and restart when asked (iOS 16+).
5. Connect the iPhone, pick it as the run destination at the top of Xcode, and press **Run** (⌘R).
6. The first time, iOS blocks the app: open **Settings → General → VPN & Device Management**, tap your developer profile and **Trust** it. Then open Castle Dominion.

Alternative: install Godot 4.5.1 + its export templates on the Mac, open this repository and use **Project → Export → iOS**. That produces the same Xcode project, and with your Team ID filled in it can export a signed `.ipa` directly.

## Graphics presets

Change the preset at any time in **Settings → Graphics Quality**. The game picks the recommended
preset on first launch.

| | Low (Galaxy A21) | Medium | High (iPhone 11 Pro Max) |
|---|---|---|---|
| 3D resolution | 75% of screen, ≤ 0.65 MP (A21: about 540×1200) | 85%, ≤ 1.3 MP | 100%, ≤ 2.3 MP (iPhone 11 Pro Max: about 83% of 1242×2688) |
| Frame cap | 30 FPS (toggle in Settings) | 60 | 60 |
| Dynamic shadows | Off (soft blob shadows under units stay) | On, 1024 map | On, 2048 map, 2 cascades |
| Bloom (glow) | Off | On | On |
| Lighting | Sun + ambient only; no fill light, no decorative tower/brazier lights; max 2 impact flashes at once | Full | Full |
| Height fog, cloud shadows, weather | Off | On | On |
| Particles | 35% counts and FX budget | 70% | 100% |
| MSAA | Off | Off | 2× |
| Enemy detail | Low-poly frames beyond ~8 m in front of the camera; max 40 high-detail units | ~16 m, 90 units | ~20 m, 140 units |
| Enemy animation | Distant (low-poly) units animate at half frame rate | Same | Same |

The art style (KayKit characters, castle masonry, spell effects, bosses) is the same in every preset.

## Touch controls (no keyboard or mouse needed)

| Action | Touch |
|---|---|
| Build a tower | Tap a glowing pad, then pick a tower in the sheet |
| Upgrade / sell | Tap a tower |
| Traps, barriers, walls | **BUILD** button, then tap the battlefield |
| Hero ultimate | Tap a hero portrait |
| Spell | Tap a spell, then tap the battlefield; **1/2 >** pages through the 8 spells |
| Focus fire | Tap an enemy |
| Camera | Drag to pan, pinch to zoom |
| God Mode dashboard, boss spawning | **Crown** button (tabs: Powers, Tuning, Battle (incl. boss spawning), World, Unlocks) |
| Pause / resume | **II** button. Leaving the app (home, call) auto-pauses; the Android back gesture pauses or resumes, closes the God panel, and in menus returns to the home screen |
| Save | Automatic after every change, when the app goes to the background, plus **Save Game** in the pause menu and Settings |

## Measuring performance on your phones

**Settings → Run Performance Benchmark** loads a fully built battle with the current preset and
holds 100, 300 and 600 enemies for 8 s each. It reports:

- average FPS, 1% low FPS, average and worst frame time;
- draw calls, triangles and horde simulation time;
- RAM and VRAM use;
- startup time and battle load time.

**Copy Results** puts the report on the clipboard. It is also saved as `benchmark_<preset>.txt` in the app's data folder.

**Settings → Show FPS / Performance Overlay** shows FPS, frame time, enemy count, draw calls, RAM and VRAM live during battles.

## Rebuilding

```bash
tools/build_mobile.sh all        # or: android | ios
```

The script prebakes character animation frames and FX textures into `assets/prebaked/`, then
exports both platforms. Android signing comes from environment variables (never commit the
keystore):

```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/path/castle_dominion_release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=castledominion
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=...
```

Godot's editor settings must point `export/android/android_sdk_path` at an SDK folder containing
`platform-tools/adb` and `build-tools/<version>/apksigner` (a full Android Studio SDK works; this
environment used Ubuntu's `adb`, `apksigner` and `zipalign` packages because Google's SDK
download host is blocked here).

## Build and test report (this environment)

**Environment:** Linux x86_64 (4 cores), Godot 4.5.1-stable with official export templates (SHA-512 verified), OpenJDK 21, Ubuntu `apksigner` 31.0.2 / `adb` 34 / `zipalign`. There is **no macOS and no Xcode** here, and Google's Android SDK download host is blocked, so no emulator or simulator is available.

| Package | Result |
|---|---|
| `CastleDominion.apk` | 131.8 MB. Signed (APK Signature Scheme v2 + v3) and passes `apksigner verify`. `io.castledominion.godmode` 0.5.0 (code 1), min SDK 24 / target 35, `arm64-v8a` + `armeabi-v7a`, portrait, only permission VIBRATE. Requires Vulkan 1.0 in the manifest; Godot falls back to OpenGL ES 3 at runtime if Vulkan fails. |
| `CastleDominion-iOS-Xcode.zip` | 184.5 MB. Xcode project, automatic signing, iPhone-only, iOS 14.0+, portrait-only, `UIRequiresFullScreen`, app icons generated, Metal via MoltenVK, `PrivacyInfo.xcprivacy` included. Not compiled: needs Xcode on a Mac. |

Verification done here:

- **Exported package run (not the editor project):** the Android export pack, started from an empty save folder like a first install, boots to the menu and plays a scripted battle with no script errors. The script builds towers and defenses, spawns 150 enemies and the Molten Tyrant boss, casts all hero ultimates and three spells, and finishes with 150 kills. The shipped animation cache was used: no bake cache was created on disk. Checked on Vulkan Mobile (High, iPhone 19.5:9 aspect with a simulated 44/34 px notch and home indicator) and on OpenGL Compatibility (Low preset). See `docs/screenshots/mobile_*.png`.
- **Automated tests:** compile check (34 scripts), smoke test, Phase 2/3 test, modes test (every mode on every map), Phase 4 test, and the new `tests/mobile_test.tscn` (26 checks: presets, pixel budget, frame caps, safe-area math, atomic saves, back button, God panel close, God Mode defaults, export presets, benchmark stages up to 600 enemies). All pass.
- **Startup in the export pack on the CPU software renderer:** 10.4 s (OpenGL) to 12.4–18.2 s (Vulkan), mostly shader compilation on a software rasterizer. Phones compile shaders on the GPU driver, so expect different numbers; the in-game benchmark reports the real figure.

**Not verified (needs your phones):**

- Installing and launching on the physical Galaxy A21 and iPhone 11 Pro Max.
- Real FPS, frame times, memory, thermals and battery. The 30 FPS (A21) and 30–60 FPS (iPhone) targets are **unconfirmed**. Run Settings → Run Performance Benchmark on each phone.
- Whether the A21's PowerVR GE8320 Vulkan driver renders correctly or Godot falls back to OpenGL.
- Real multi-touch feel (pinch zoom, drag thresholds, scrolling long lists) and the actual notch insets reported by iOS.
- Compiling the Xcode project and signing it with your Apple ID.
