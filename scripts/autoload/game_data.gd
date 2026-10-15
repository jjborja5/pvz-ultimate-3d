extends Node
## Static game definitions: enemies, towers, spells, maps, modes, difficulties.
## Everything here is original content for Castle Dominion.

const ENEMIES := {
	"goblin": {
		"name": "Goblin Raider", "hp": 34.0, "speed": 3.4, "damage": 2.0, "reward": 3,
		"scale": 0.75, "radius": 0.45, "attack_rate": 1.0,
	},
	"skeleton": {
		"name": "Bone Legionnaire", "hp": 55.0, "speed": 2.7, "damage": 3.0, "reward": 4,
		"scale": 0.95, "radius": 0.45, "attack_rate": 1.1,
	},
	"orc": {
		"name": "Ironhide Orc", "hp": 110.0, "speed": 2.2, "damage": 6.0, "reward": 7,
		"scale": 1.1, "radius": 0.6, "attack_rate": 0.9,
	},
	"demon": {
		"name": "Cinder Fiend", "hp": 190.0, "speed": 2.5, "damage": 9.0, "reward": 12,
		"scale": 1.15, "radius": 0.6, "attack_rate": 1.0,
	},
	"brute": {
		"name": "Mountain Ogre", "hp": 520.0, "speed": 1.5, "damage": 20.0, "reward": 30,
		"scale": 1.7, "radius": 0.95, "attack_rate": 0.6,
	},
	"boss_molten": {
		"name": "Gorrakh, the Molten Tyrant", "hp": 9000.0, "speed": 1.05, "damage": 80.0, "reward": 600,
		"scale": 2.2, "radius": 1.4, "attack_rate": 0.5, "boss": true,
	},
	"boss_lich": {
		"name": "Vael'Zhur, the Hollow King", "hp": 7000.0, "speed": 1.3, "damage": 60.0, "reward": 500,
		"scale": 2.0, "radius": 1.3, "attack_rate": 0.7, "boss": true,
	},
}

const BOSS_TYPES := ["boss_molten", "boss_lich"]
const REGULAR_TYPES := ["goblin", "skeleton", "orc", "demon", "brute"]

## Tower stats are per level (index 0 == level 1). Five visual tiers.
const TOWERS := {
	"archer": {
		"name": "Archer Tower", "desc": "Rapid volleys of arrows. Reliable single-target damage.",
		"cost": [60, 90, 140, 220, 340],
		"damage": [14.0, 20.0, 29.0, 42.0, 60.0],
		"rate": [1.6, 1.9, 2.2, 2.6, 3.2],
		"range": [16.0, 17.0, 18.0, 19.5, 21.0],
		"multishot": [1, 1, 2, 2, 3],
		"color": Color(0.35, 0.75, 0.35),
	},
	"cannon": {
		"name": "Cannon Tower", "desc": "Heavy shells that explode on impact, hitting groups.",
		"cost": [90, 130, 200, 300, 460],
		"damage": [40.0, 58.0, 85.0, 120.0, 175.0],
		"rate": [0.45, 0.5, 0.55, 0.6, 0.7],
		"range": [18.0, 19.0, 20.0, 21.0, 23.0],
		"splash": [2.6, 2.9, 3.2, 3.6, 4.2],
		"color": Color(0.55, 0.55, 0.6),
	},
	"lightning": {
		"name": "Storm Spire", "desc": "Chain lightning arcs between nearby enemies.",
		"cost": [110, 160, 240, 360, 540],
		"damage": [26.0, 36.0, 50.0, 70.0, 100.0],
		"rate": [0.8, 0.9, 1.0, 1.15, 1.35],
		"range": [15.0, 16.0, 17.0, 18.0, 20.0],
		"chains": [3, 4, 5, 7, 9],
		"color": Color(0.45, 0.65, 1.0),
	},
	"fire": {
		"name": "Inferno Brazier", "desc": "Hurls fire orbs that burn enemies over time.",
		"cost": [100, 150, 220, 330, 500],
		"damage": [22.0, 31.0, 44.0, 62.0, 88.0],
		"rate": [0.9, 1.0, 1.1, 1.25, 1.45],
		"range": [14.0, 15.0, 16.0, 17.0, 18.5],
		"splash": [2.0, 2.2, 2.5, 2.8, 3.2],
		"burn": [8.0, 12.0, 17.0, 24.0, 34.0],
		"color": Color(1.0, 0.45, 0.15),
	},
	"ice": {
		"name": "Frost Obelisk", "desc": "Shards of ice that slow and freeze enemies.",
		"cost": [80, 120, 180, 270, 400],
		"damage": [12.0, 17.0, 24.0, 34.0, 48.0],
		"rate": [1.0, 1.1, 1.2, 1.35, 1.5],
		"range": [14.0, 15.0, 16.0, 17.0, 18.5],
		"splash": [1.6, 1.8, 2.1, 2.4, 2.8],
		"slow": [0.35, 0.4, 0.45, 0.5, 0.6],
		"color": Color(0.6, 0.9, 1.0),
	},
}
const TOWER_ORDER := ["archer", "cannon", "lightning", "fire", "ice"]
const TOWER_MAX_LEVEL := 5

const SPELLS := {
	"fireball": {"name": "Fireball", "cooldown": 4.0, "damage": 160.0, "radius": 3.5, "color": Color(1.0, 0.5, 0.1)},
	"lightning": {"name": "Chain Storm", "cooldown": 6.0, "damage": 120.0, "chains": 12, "color": Color(0.5, 0.7, 1.0)},
	"ice_storm": {"name": "Ice Storm", "cooldown": 10.0, "damage": 30.0, "radius": 6.0, "duration": 4.0, "color": Color(0.7, 0.95, 1.0)},
	"meteor": {"name": "Meteor", "cooldown": 14.0, "damage": 900.0, "radius": 7.0, "color": Color(1.0, 0.3, 0.05)},
}
const SPELL_ORDER := ["fireball", "lightning", "ice_storm", "meteor"]

## Map palettes drive the procedural world builder.
const MAPS := {
	"verdant_pass": {
		"name": "Verdant Pass", "desc": "Forested hills guarding the kingdom's western road.",
		"grass": Color(0.33, 0.58, 0.24), "grass2": Color(0.45, 0.68, 0.28), "path": Color(0.62, 0.5, 0.34),
		"rock": Color(0.4, 0.42, 0.34), "peak": Color(0.52, 0.52, 0.48),
		"sky_top": Color(0.28, 0.48, 0.85), "sky_horizon": Color(0.78, 0.86, 0.95),
		"sun": Color(1.0, 0.94, 0.82), "sun_energy": 1.4, "ambient": Color(0.6, 0.68, 0.8),
		"fog": Color(0.75, 0.82, 0.92), "trees": 260, "tree_style": "mixed", "rocks": 70,
		"lava": false, "ruins": 4, "hill": 9.0, "embers": false,
	},
	"molten_abyss": {
		"name": "Molten Abyss", "desc": "Rivers of lava split a blackened volcanic plain.",
		"grass": Color(0.22, 0.17, 0.16), "grass2": Color(0.3, 0.2, 0.16), "path": Color(0.36, 0.27, 0.22),
		"rock": Color(0.18, 0.15, 0.15), "peak": Color(0.3, 0.2, 0.18),
		"sky_top": Color(0.18, 0.06, 0.05), "sky_horizon": Color(0.85, 0.35, 0.12),
		"sun": Color(1.0, 0.6, 0.4), "sun_energy": 1.1, "ambient": Color(0.6, 0.35, 0.3),
		"fog": Color(0.45, 0.16, 0.08), "trees": 40, "tree_style": "dead", "rocks": 140,
		"lava": true, "ruins": 3, "hill": 12.0, "embers": true,
	},
	"shattered_ruins": {
		"name": "Shattered Ruins", "desc": "A fallen citadel's battlefield, haunted by the dead.",
		"grass": Color(0.42, 0.45, 0.3), "grass2": Color(0.5, 0.48, 0.33), "path": Color(0.55, 0.5, 0.42),
		"rock": Color(0.52, 0.5, 0.48), "peak": Color(0.6, 0.58, 0.55),
		"sky_top": Color(0.3, 0.3, 0.45), "sky_horizon": Color(0.85, 0.72, 0.6),
		"sun": Color(1.0, 0.82, 0.62), "sun_energy": 1.2, "ambient": Color(0.62, 0.6, 0.7),
		"fog": Color(0.7, 0.62, 0.6), "trees": 90, "tree_style": "dead", "rocks": 100,
		"lava": false, "ruins": 26, "hill": 7.0, "embers": false,
	},
	"skyspire_peaks": {
		"name": "Skyspire Peaks", "desc": "Snow-capped mountains above the clouds.",
		"grass": Color(0.42, 0.55, 0.38), "grass2": Color(0.85, 0.88, 0.92), "path": Color(0.6, 0.56, 0.5),
		"rock": Color(0.45, 0.46, 0.5), "peak": Color(0.95, 0.97, 1.0),
		"sky_top": Color(0.2, 0.42, 0.85), "sky_horizon": Color(0.88, 0.93, 1.0),
		"sun": Color(1.0, 0.98, 0.95), "sun_energy": 1.5, "ambient": Color(0.7, 0.78, 0.92),
		"fog": Color(0.85, 0.9, 0.98), "trees": 200, "tree_style": "pine", "rocks": 90,
		"lava": false, "ruins": 2, "hill": 22.0, "embers": false,
	},
}
const MAP_ORDER := ["verdant_pass", "molten_abyss", "shattered_ruins", "skyspire_peaks"]

const MODES := {
	"campaign": {"name": "Campaign", "desc": "Hold the castle through 30 escalating waves.", "waves": 30, "auto_waves": true},
	"endless": {"name": "Endless Survival", "desc": "Infinite waves. How long can the walls stand?", "waves": 0, "auto_waves": true},
	"boss_rush": {"name": "Boss Rush", "desc": "Every wave is led by a tyrant.", "waves": 15, "auto_waves": true},
	"sandbox": {"name": "Sandbox", "desc": "No waves. Spawn anything from the God Mode panel.", "waves": 0, "auto_waves": false},
	"playground": {"name": "God Mode Playground", "desc": "Endless chaos with every god power active.", "waves": 0, "auto_waves": true},
}
const MODE_ORDER := ["campaign", "endless", "boss_rush", "sandbox", "playground"]

const DIFFICULTIES := [
	{"name": "Squire", "hp": 0.7, "count": 0.8},
	{"name": "Knight", "hp": 1.0, "count": 1.0},
	{"name": "Warlord", "hp": 1.5, "count": 1.3},
	{"name": "Nightmare", "hp": 2.3, "count": 1.7},
]
