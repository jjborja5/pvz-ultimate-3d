extends Node
## Static game definitions: enemies, towers, spells, maps, modes, difficulties.
## Everything here is original content for Castle Dominion.

## Enemy roster. "model" is a UnitBaker config (rigged CC0 KayKit characters baked into frames).
## tint/tint_amount recolour the shared texture atlas; "ranged" units stop and shoot the walls.
const ENEMIES := {
	"goblin": {
		"name": "Goblin Raider", "hp": 34.0, "speed": 3.6, "damage": 2.0, "reward": 3,
		"scale": 0.78, "radius": 0.45, "attack_rate": 1.2, "model": "rogue",
		"tint": Color(0.45, 0.95, 0.35), "tint_amount": 0.55, "glow": Color(1.0, 0.9, 0.2),
	},
	"skeleton": {
		"name": "Bone Legionnaire", "hp": 55.0, "speed": 2.7, "damage": 3.0, "reward": 4,
		"scale": 0.95, "radius": 0.45, "attack_rate": 1.1, "model": "skel_minion",
		"tint": Color(1, 1, 1), "tint_amount": 0.0, "glow": Color(0.3, 0.9, 1.0),
	},
	"skeleton_warrior": {
		"name": "Grave Warden", "hp": 150.0, "speed": 2.1, "damage": 7.0, "reward": 9,
		"scale": 1.05, "radius": 0.55, "attack_rate": 0.9, "model": "skel_warrior", "armor": 0.2,
		"tint": Color(1, 1, 1), "tint_amount": 0.0, "glow": Color(0.3, 0.9, 1.0),
	},
	"skeleton_archer": {
		"name": "Crypt Marksman", "hp": 60.0, "speed": 2.5, "damage": 5.0, "reward": 6,
		"scale": 0.95, "radius": 0.45, "attack_rate": 0.6, "model": "skel_rogue", "ranged": 15.0,
		"projectile": "arrow", "tint": Color(1, 1, 1), "tint_amount": 0.0, "glow": Color(0.3, 0.9, 1.0),
	},
	"skeleton_mage": {
		"name": "Hexbone Caster", "hp": 90.0, "speed": 2.2, "damage": 9.0, "reward": 10,
		"scale": 1.0, "radius": 0.5, "attack_rate": 0.45, "model": "skel_mage", "ranged": 18.0,
		"projectile": "hex", "tint": Color(0.75, 0.6, 1.0), "tint_amount": 0.25, "glow": Color(0.7, 0.3, 1.0),
	},
	"orc": {
		"name": "Ironhide Orc", "hp": 120.0, "speed": 2.3, "damage": 6.0, "reward": 7,
		"scale": 1.12, "radius": 0.6, "attack_rate": 0.9, "model": "barbarian",
		"tint": Color(0.4, 0.75, 0.3), "tint_amount": 0.5, "glow": Color(1.0, 0.4, 0.1),
	},
	"demon": {
		"name": "Cinder Fiend", "hp": 210.0, "speed": 2.6, "damage": 9.0, "reward": 12,
		"scale": 1.18, "radius": 0.6, "attack_rate": 1.0, "model": "barbarian_2h",
		"tint": Color(1.0, 0.25, 0.15), "tint_amount": 0.7, "glow": Color(1.0, 0.45, 0.05), "emissive": 0.25,
	},
	"brute": {
		"name": "Mountain Ogre", "hp": 560.0, "speed": 1.5, "damage": 20.0, "reward": 30,
		"scale": 1.85, "radius": 0.95, "attack_rate": 0.6, "model": "barbarian",
		"tint": Color(0.75, 0.62, 0.45), "tint_amount": 0.55, "glow": Color(0.9, 0.7, 0.2),
	},
	"dark_knight": {
		"name": "Dread Knight", "hp": 340.0, "speed": 1.9, "damage": 14.0, "reward": 22,
		"scale": 1.15, "radius": 0.6, "attack_rate": 0.8, "model": "knight", "armor": 0.35,
		"tint": Color(0.45, 0.35, 0.6), "tint_amount": 0.65, "glow": Color(0.8, 0.2, 1.0),
	},
	"boss_molten": {
		"name": "Gorrakh, the Molten Tyrant", "hp": 9000.0, "speed": 1.05, "damage": 80.0, "reward": 600,
		"scale": 3.1, "radius": 1.6, "attack_rate": 0.5, "boss": true, "model": "barbarian_2h",
		"tint": Color(1.0, 0.35, 0.1), "tint_amount": 0.75, "glow": Color(1.0, 0.38, 0.02), "emissive": 0.6,
		"ability": "slam",
	},
	"boss_lich": {
		"name": "Vael'Zhur, the Hollow King", "hp": 7000.0, "speed": 1.3, "damage": 60.0, "reward": 500,
		"scale": 3.0, "radius": 1.5, "attack_rate": 0.7, "boss": true, "model": "skel_mage",
		"tint": Color(0.5, 0.9, 1.0), "tint_amount": 0.4, "glow": Color(0.25, 1.0, 0.85), "emissive": 0.3,
		"ability": "summon",
	},
	"boss_colossus": {
		"name": "Ossuarion, the Bone Colossus", "hp": 14000.0, "speed": 0.85, "damage": 110.0, "reward": 800,
		"scale": 3.6, "radius": 1.9, "attack_rate": 0.4, "boss": true, "model": "skel_warrior", "armor": 0.3,
		"tint": Color(0.9, 0.85, 0.7), "tint_amount": 0.2, "glow": Color(1.0, 0.2, 0.15), "emissive": 0.1,
		"ability": "slam",
	},
	"boss_warlord": {
		"name": "Malgrim, the Dread Warlord", "hp": 11000.0, "speed": 1.15, "damage": 90.0, "reward": 700,
		"scale": 3.0, "radius": 1.6, "attack_rate": 0.55, "boss": true, "model": "knight_2h", "armor": 0.25,
		"tint": Color(0.55, 0.12, 0.15), "tint_amount": 0.7, "glow": Color(1.0, 0.1, 0.1), "emissive": 0.15,
		"ability": "rally",
	},
}

const BOSS_TYPES := ["boss_molten", "boss_lich", "boss_colossus", "boss_warlord"]
const REGULAR_TYPES := ["goblin", "skeleton", "skeleton_warrior", "skeleton_archer", "skeleton_mage", "orc", "demon", "brute", "dark_knight"]

## Elite affixes roll on regular enemies in later waves.
const ELITES := {
	"giant": {"name": "Giant", "hp": 3.0, "scale": 1.35, "speed": 0.85, "aura": Color(1.0, 0.8, 0.2)},
	"swift": {"name": "Swift", "hp": 1.5, "scale": 1.0, "speed": 1.7, "aura": Color(0.3, 1.0, 0.5)},
	"armored": {"name": "Armored", "hp": 2.2, "scale": 1.1, "speed": 1.0, "armor": 0.4, "aura": Color(0.6, 0.7, 1.0)},
	"infernal": {"name": "Infernal", "hp": 2.0, "scale": 1.15, "speed": 1.1, "aura": Color(1.0, 0.3, 0.05)},
}

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
	"meteor_shower": {"name": "Meteor Rain", "cooldown": 30.0, "damage": 600.0, "radius": 5.0, "count": 14, "color": Color(1.0, 0.35, 0.05)},
	"firestorm": {"name": "Firestorm", "cooldown": 20.0, "damage": 90.0, "radius": 4.5, "duration": 6.0, "color": Color(1.0, 0.45, 0.1)},
	"frost_nova": {"name": "Frost Nova", "cooldown": 16.0, "damage": 140.0, "radius": 9.0, "color": Color(0.7, 0.95, 1.0)},
	"divine_wrath": {"name": "Divine Wrath", "cooldown": 40.0, "damage": 2500.0, "radius": 30.0, "color": Color(1.0, 0.9, 0.5)},
}
const SPELL_ORDER := ["fireball", "lightning", "ice_storm", "meteor", "meteor_shower", "firestorm", "frost_nova", "divine_wrath"]


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

# =====================================================================================
# HEROES — rigged + animated CC0 KayKit adventurers, recoloured and re-equipped per hero.
# attack: kind (projectile visual), element, base damage / rate / range.
# ability: the hero's ultimate, triggered from the HUD portrait.
# =====================================================================================
const HERO_MAX_LEVEL := 60
const ABILITY_MAX_LEVEL := 10

const HEROES := {
	"archer": {
		"name": "Lyra Swiftwind", "title": "Ranger of the Vale", "class": "Archer", "model": "Rogue_Hooded",
		"keep": ["2H_Crossbow", "Rogue_Cape"], "tint": Color(0.45, 0.85, 0.4), "tint_amount": 0.35,
		"anims": {"idle": "2H_Ranged_Aiming", "attack": "2H_Ranged_Shoot", "cast": "Cheer"},
		"attack": {"kind": "arrow", "element": "physical", "damage": 34.0, "rate": 1.8, "range": 30.0, "multishot": 2},
		"ability": {"id": "arrow_storm", "name": "Arrow Storm", "cooldown": 12.0, "damage": 60.0, "radius": 8.0,
			"desc": "Darkens the sky with 80 enchanted arrows over a wide area."},
		"color": Color(0.4, 0.9, 0.4),
	},
	"fire_mage": {
		"name": "Ignis Emberheart", "title": "Archmage of Flame", "class": "Fire Mage", "model": "Mage",
		"keep": ["2H_Staff", "Mage_Hat", "Mage_Cape"], "tint": Color(1.0, 0.35, 0.15), "tint_amount": 0.5,
		"anims": {"idle": "Spellcasting", "attack": "Spellcast_Shoot", "cast": "Spellcast_Long"},
		"attack": {"kind": "fire", "element": "fire", "damage": 48.0, "rate": 0.9, "range": 26.0, "splash": 2.8},
		"ability": {"id": "firestorm", "name": "Firestorm", "cooldown": 16.0, "damage": 140.0, "radius": 5.0,
			"desc": "Three roaring fire tornadoes sweep down the lanes, burning everything."},
		"color": Color(1.0, 0.45, 0.15),
	},
	"ice_wizard": {
		"name": "Frostine Vale", "title": "Keeper of the Winter Spire", "class": "Ice Wizard", "model": "Mage",
		"keep": ["2H_Staff", "Mage_Hat", "Mage_Cape"], "tint": Color(0.55, 0.85, 1.0), "tint_amount": 0.55,
		"anims": {"idle": "Spellcasting", "attack": "Spellcast_Shoot", "cast": "Spellcast_Raise"},
		"attack": {"kind": "ice", "element": "ice", "damage": 30.0, "rate": 1.1, "range": 26.0, "splash": 2.4, "slow": 0.45},
		"ability": {"id": "glacial_spikes", "name": "Glacial Spikes", "cooldown": 14.0, "damage": 180.0, "radius": 3.0,
			"desc": "Erupts a field of ice spikes that impale and freeze the horde."},
		"color": Color(0.6, 0.9, 1.0),
	},
	"storm_sorcerer": {
		"name": "Voltaris", "title": "The Living Tempest", "class": "Lightning Sorcerer", "model": "Mage",
		"keep": ["1H_Wand", "Spellbook_open", "Mage_Hat"], "tint": Color(0.6, 0.45, 1.0), "tint_amount": 0.5,
		"anims": {"idle": "Spellcasting", "attack": "Spellcast_Shoot", "cast": "Spellcast_Summon"},
		"attack": {"kind": "chain", "element": "lightning", "damage": 36.0, "rate": 1.0, "range": 25.0, "chains": 5},
		"ability": {"id": "thunder_dome", "name": "Thunder Dome", "cooldown": 18.0, "damage": 120.0, "radius": 0.0,
			"desc": "Calls down 40 sky-bolts over four seconds on random enemies."},
		"color": Color(0.6, 0.6, 1.0),
	},
	"paladin": {
		"name": "Sir Aldric Dawnshield", "title": "Paladin of the Sun", "class": "Paladin", "model": "Knight",
		"keep": ["1H_Sword", "Badge_Shield", "Knight_Helmet", "Knight_Cape"], "tint": Color(1.0, 0.85, 0.4), "tint_amount": 0.4,
		"anims": {"idle": "Idle", "attack": "1H_Melee_Attack_Slice_Diagonal", "cast": "Cheer"},
		"attack": {"kind": "holy", "element": "holy", "damage": 55.0, "rate": 0.9, "range": 22.0, "splash": 2.0},
		"ability": {"id": "divine_judgment", "name": "Divine Judgment", "cooldown": 20.0, "damage": 500.0, "radius": 9.0,
			"desc": "A pillar of sunlight smites a huge area and restores the castle walls."},
		"color": Color(1.0, 0.85, 0.4),
	},
	"druid": {
		"name": "Thornwood", "title": "Voice of the Old Grove", "class": "Druid", "model": "Mage",
		"keep": ["2H_Staff", "Mage_Cape"], "tint": Color(0.5, 0.75, 0.3), "tint_amount": 0.55,
		"anims": {"idle": "Spellcasting", "attack": "Spellcast_Shoot", "cast": "Spellcast_Summon"},
		"attack": {"kind": "thorn", "element": "nature", "damage": 32.0, "rate": 1.2, "range": 24.0, "poison": 14.0},
		"ability": {"id": "wrath_of_grove", "name": "Wrath of the Grove", "cooldown": 16.0, "damage": 60.0, "radius": 10.0,
			"desc": "Roots erupt from the earth, binding and poisoning every enemy in the area."},
		"color": Color(0.5, 0.9, 0.35),
	},
	"necromancer": {
		"name": "Morvane the Pale", "title": "Lord of the Restless Dead", "class": "Necromancer", "model": "Rogue_Hooded",
		"keep": ["Knife", "Rogue_Cape"], "tint": Color(0.5, 0.3, 0.7), "tint_amount": 0.65,
		"anims": {"idle": "Idle", "attack": "Spellcast_Shoot", "cast": "Spellcast_Raise"},
		"attack": {"kind": "soul", "element": "shadow", "damage": 40.0, "rate": 1.0, "range": 26.0},
		"ability": {"id": "army_of_dead", "name": "Army of the Dead", "cooldown": 22.0, "damage": 45.0, "radius": 0.0,
			"desc": "Raises 14 spectral skeleton warriors who charge into the enemy lines."},
		"color": Color(0.7, 0.4, 1.0),
	},
	"engineer": {
		"name": "Brokk Ironbeard", "title": "Dwarven Siege Engineer", "class": "Dwarf Engineer", "model": "Barbarian",
		"keep": ["1H_Axe", "Barbarian_Hat"], "tint": Color(0.95, 0.6, 0.3), "tint_amount": 0.35, "scale": Vector3(1.15, 0.85, 1.15),
		"anims": {"idle": "Idle", "attack": "Throw", "cast": "Cheer"},
		"attack": {"kind": "bomb", "element": "physical", "damage": 70.0, "rate": 0.7, "range": 28.0, "splash": 3.2},
		"ability": {"id": "mortar_barrage", "name": "Mortar Barrage", "cooldown": 15.0, "damage": 260.0, "radius": 4.0,
			"desc": "Twelve dwarven mortar shells carpet-bomb the battlefield."},
		"color": Color(1.0, 0.6, 0.3),
	},
	"dragon_summoner": {
		"name": "Seraphine Wyrmcaller", "title": "Dragon Knight of Skyreach", "class": "Dragon Summoner", "model": "Knight",
		"keep": ["2H_Sword", "Knight_Cape"], "tint": Color(0.3, 0.85, 0.8), "tint_amount": 0.5,
		"anims": {"idle": "2H_Melee_Idle", "attack": "2H_Melee_Attack_Stab", "cast": "Cheer"},
		"attack": {"kind": "dragonfire", "element": "fire", "damage": 50.0, "rate": 1.0, "range": 27.0, "splash": 2.2},
		"ability": {"id": "elder_dragon", "name": "Summon Elder Dragon", "cooldown": 25.0, "damage": 160.0, "radius": 3.5,
			"desc": "An elder dragon sweeps over the lanes, breathing a river of fire."},
		"color": Color(0.3, 0.95, 0.85),
	},
}
const HERO_ORDER := ["archer", "fire_mage", "ice_wizard", "storm_sorcerer", "paladin", "druid", "necromancer", "engineer", "dragon_summoner"]
const TEAM_SIZE := 3

## Skins recolour the hero. "Classic" uses the hero's own tint.
const SKINS := [
	{"name": "Classic", "tint": Color(1, 1, 1), "amount": -1.0, "glow": 0.0},
	{"name": "Royal Gold", "tint": Color(1.0, 0.82, 0.3), "amount": 0.6, "glow": 0.1},
	{"name": "Shadowborn", "tint": Color(0.35, 0.25, 0.5), "amount": 0.75, "glow": 0.15},
	{"name": "Celestial", "tint": Color(0.75, 0.95, 1.0), "amount": 0.6, "glow": 0.45},
]

# =====================================================================================
# EQUIPMENT
# =====================================================================================
const SLOTS := ["weapon", "armor", "accessory"]
const RARITIES := [
	{"name": "Common", "color": Color(0.75, 0.75, 0.75), "mult": 1.0, "max_level": 10},
	{"name": "Rare", "color": Color(0.35, 0.6, 1.0), "mult": 1.6, "max_level": 20},
	{"name": "Epic", "color": Color(0.75, 0.4, 1.0), "mult": 2.4, "max_level": 30},
	{"name": "Legendary", "color": Color(1.0, 0.6, 0.15), "mult": 3.4, "max_level": 40},
	{"name": "Mythic", "color": Color(1.0, 0.25, 0.3), "mult": 4.8, "max_level": 50},
]
## Random item bases. Stats: atk (%), hp (castle %), aspd (%), crit (%), power (ability %), cdr (%)
const ITEM_BASES := {
	"weapon": [
		{"name": "Longsword", "stats": {"atk": 8.0}}, {"name": "Battle Staff", "stats": {"atk": 6.0, "power": 4.0}},
		{"name": "Hunting Bow", "stats": {"atk": 6.0, "aspd": 3.0}}, {"name": "Rune Wand", "stats": {"power": 8.0}},
		{"name": "War Axe", "stats": {"atk": 9.0, "crit": 1.0}}, {"name": "Warhammer", "stats": {"atk": 10.0}},
		{"name": "Crystal Orb", "stats": {"power": 6.0, "cdr": 1.0}},
	],
	"armor": [
		{"name": "Plate Armor", "stats": {"hp": 6.0}}, {"name": "Mage Robe", "stats": {"power": 5.0, "hp": 2.0}},
		{"name": "Leather Jerkin", "stats": {"aspd": 3.0, "hp": 2.0}}, {"name": "Scale Mail", "stats": {"hp": 5.0, "atk": 2.0}},
		{"name": "Shadow Mantle", "stats": {"crit": 2.0, "hp": 2.0}},
	],
	"accessory": [
		{"name": "Signet Ring", "stats": {"crit": 2.5}}, {"name": "Amulet", "stats": {"power": 5.0}},
		{"name": "Lucky Charm", "stats": {"crit": 1.5, "aspd": 2.0}}, {"name": "Circlet", "stats": {"cdr": 2.0}},
		{"name": "Relic", "stats": {"atk": 4.0, "power": 3.0}},
	],
}
## Named legendary / mythic items with unique effects (see Effects in hero.gd / battle mods).
const LEGENDARIES := {
	"emberfang": {"name": "Emberfang Greatsword", "slot": "weapon", "rarity": 3, "stats": {"atk": 14.0, "crit": 3.0},
		"effect": "ignite", "desc": "Attacks ignite enemies. +25% fire damage."},
	"frostheart": {"name": "Frostheart Staff", "slot": "weapon", "rarity": 3, "stats": {"atk": 10.0, "power": 8.0},
		"effect": "chill", "desc": "Attacks slow enemies by 30%. +25% ice damage."},
	"stormcaller": {"name": "Stormcaller Scepter", "slot": "weapon", "rarity": 3, "stats": {"atk": 9.0, "aspd": 6.0},
		"effect": "chain", "desc": "Attacks arc to 2 additional enemies."},
	"dawnbreaker": {"name": "Dawnbreaker", "slot": "weapon", "rarity": 3, "stats": {"atk": 15.0},
		"effect": "holy_boost", "desc": "+40% holy damage. Abilities repair the castle."},
	"wyrmbone": {"name": "Wyrmbone Longbow", "slot": "weapon", "rarity": 3, "stats": {"atk": 11.0, "aspd": 8.0},
		"effect": "multishot", "desc": "Fires 2 additional projectiles."},
	"soulreaver": {"name": "Soulreaver Scythe", "slot": "weapon", "rarity": 4, "stats": {"atk": 18.0, "crit": 5.0},
		"effect": "reap", "desc": "Kills have a 20% chance to raise a spectral ally."},
	"void_orb": {"name": "Orb of the Endless Void", "slot": "weapon", "rarity": 4, "stats": {"power": 18.0, "atk": 10.0},
		"effect": "void", "desc": "Attacks deal 2% of the target's max health."},
	"aegis": {"name": "Aegis of the First King", "slot": "armor", "rarity": 4, "stats": {"hp": 20.0},
		"effect": "fortress", "desc": "Castle takes 25% less damage."},
	"phoenix_mantle": {"name": "Phoenix Mantle", "slot": "armor", "rarity": 3, "stats": {"hp": 8.0, "cdr": 6.0},
		"effect": "rebirth", "desc": "Ability cooldowns 25% shorter."},
	"verdant_robe": {"name": "Robe of the Verdant Heart", "slot": "armor", "rarity": 3, "stats": {"power": 10.0, "hp": 6.0},
		"effect": "nature_boost", "desc": "+35% nature and shadow damage."},
	"crown_undying": {"name": "Crown of the Undying", "slot": "accessory", "rarity": 4, "stats": {"power": 20.0, "cdr": 5.0},
		"effect": "power", "desc": "+50% ability damage."},
	"eye_tempest": {"name": "Eye of the Tempest", "slot": "accessory", "rarity": 3, "stats": {"aspd": 12.0},
		"effect": "haste", "desc": "+25% attack speed."},
	"dragonheart": {"name": "Dragonheart Amulet", "slot": "accessory", "rarity": 3, "stats": {"atk": 8.0, "power": 8.0},
		"effect": "dragon", "desc": "+50% fire damage. The Elder Dragon breathes twice."},
	"midas_ring": {"name": "Ring of Midas", "slot": "accessory", "rarity": 3, "stats": {"crit": 4.0},
		"effect": "midas", "desc": "+50% gold from kills."},
}

# =====================================================================================
# DEFENSES — traps, barriers and walls placed on the battlefield.
# =====================================================================================
const DEFENSES := {
	"spike_trap": {"name": "Spike Trap", "desc": "Iron spikes thrust up through the ground at anything above.",
		"cost": [80, 120, 180], "damage": [30.0, 50.0, 85.0], "interval": 1.0, "radius": 2.2, "kind": "trap"},
	"barrel_trap": {"name": "Blast Barrel", "desc": "Explodes when enemies come close, then is restocked.",
		"cost": [100, 150, 230], "damage": [240.0, 400.0, 650.0], "radius": [4.0, 4.6, 5.4], "rearm": 7.0, "kind": "trap"},
	"frost_rune": {"name": "Frost Rune", "desc": "A glyph of winter that slows and chills enemies passing over.",
		"cost": [90, 140, 210], "damage": [8.0, 14.0, 24.0], "slow": [0.4, 0.5, 0.65], "radius": 3.2, "kind": "trap"},
	"barrier": {"name": "Arcane Barrier", "desc": "A shimmering wall of force that blocks the lane and regenerates.",
		"cost": [150, 220, 330], "hp": [900.0, 1800.0, 3600.0], "regen": [15.0, 30.0, 60.0], "width": 7.0, "kind": "blocker"},
	"wall": {"name": "Stone Wall", "desc": "A fortified stone wall that holds enemies in place.",
		"cost": [120, 180, 270], "hp": [1600.0, 3200.0, 6400.0], "regen": [0.0, 0.0, 10.0], "width": 6.0, "kind": "blocker"},
}
const DEFENSE_ORDER := ["spike_trap", "barrel_trap", "frost_rune", "barrier", "wall"]
const DEFENSE_MAX_LEVEL := 3

# =====================================================================================
# ROGUELIKE BLESSINGS + COMBOS (per battle)
# =====================================================================================
const BLESSINGS := {
	"archer_mastery": {"name": "Eagle Eye", "desc": "Archer towers deal +40% damage.", "tags": ["physical"], "mods": {"tower_archer": 0.4}},
	"volley": {"name": "Volley", "desc": "Archer towers fire 1 extra arrow.", "tags": ["physical"], "mods": {"archer_extra": 1.0}},
	"heavy_shells": {"name": "Heavy Shells", "desc": "Cannon damage +35% and splash +40%.", "tags": ["physical"], "mods": {"tower_cannon": 0.35, "cannon_splash": 0.4}},
	"storm_conduit": {"name": "Storm Conduit", "desc": "Lightning chains to 3 more enemies.", "tags": ["lightning"], "mods": {"chains": 3.0}},
	"inferno": {"name": "Inferno", "desc": "Burning damage +60%. Fire damage +20%.", "tags": ["fire"], "mods": {"burn": 0.6, "el_fire": 0.2}},
	"permafrost": {"name": "Permafrost", "desc": "Ice slows 20% more and can freeze.", "tags": ["ice"], "mods": {"slow": 0.2, "freeze": 0.12}},
	"arcane_power": {"name": "Arcane Power", "desc": "Spells deal +50% damage.", "tags": ["arcane"], "mods": {"spell": 0.5}},
	"quick_cast": {"name": "Quick Cast", "desc": "Spell cooldowns 40% shorter.", "tags": ["arcane"], "mods": {"spell_cd": 0.4}},
	"hero_fury": {"name": "Battle Fury", "desc": "Heroes attack 35% faster.", "tags": ["hero"], "mods": {"hero_aspd": 0.35}},
	"hero_might": {"name": "Heroic Might", "desc": "Heroes deal +40% damage.", "tags": ["hero"], "mods": {"hero_dmg": 0.4}},
	"ability_haste": {"name": "Ancient Focus", "desc": "Hero ability cooldowns 30% shorter.", "tags": ["hero"], "mods": {"ability_cd": 0.3}},
	"golden_touch": {"name": "Golden Touch", "desc": "+50% gold from every kill.", "tags": ["wealth"], "mods": {"gold": 0.5}},
	"treasure_hunter": {"name": "Treasure Hunter", "desc": "Loot drops twice as often.", "tags": ["wealth"], "mods": {"loot": 1.0}},
	"meteor_rain": {"name": "Meteor Rain", "desc": "Every 18s a meteor strikes the densest crowd.", "tags": ["fire"], "mods": {"auto_meteor": 1.0}},
	"thunderclap": {"name": "Thunderclap", "desc": "Every 10s lightning strikes 6 enemies.", "tags": ["lightning"], "mods": {"auto_thunder": 1.0}},
	"frost_aura": {"name": "Frost Aura", "desc": "Enemies near the walls are slowed by 40%.", "tags": ["ice"], "mods": {"wall_slow": 0.4}},
	"fortify": {"name": "Fortify", "desc": "Castle and defenses +50% health, fully repaired.", "tags": ["defense"], "mods": {"fortify": 0.5}},
	"sharpened": {"name": "Sharpened Steel", "desc": "Traps deal +80% damage.", "tags": ["defense", "physical"], "mods": {"trap": 0.8}},
	"giant_slayer": {"name": "Giant Slayer", "desc": "+40% damage to bosses and elites.", "tags": ["physical"], "mods": {"boss_dmg": 0.4}},
	"critical": {"name": "Deadly Precision", "desc": "15% chance for any hit to deal 2.5x damage.", "tags": ["physical"], "mods": {"crit": 0.15}},
	"holy_light": {"name": "Holy Light", "desc": "Holy damage +60%.", "tags": ["holy"], "mods": {"el_holy": 0.6}},
	"plague": {"name": "Plaguebringer", "desc": "Nature and shadow damage +50%.", "tags": ["nature"], "mods": {"el_nature": 0.5, "el_shadow": 0.5}},
	"overclock": {"name": "Overclock", "desc": "Towers attack 25% faster.", "tags": ["defense"], "mods": {"tower_aspd": 0.25}},
	"executioner": {"name": "Executioner", "desc": "Non-boss enemies below 15% health are slain.", "tags": ["physical"], "mods": {"execute": 0.15}},
}
const COMBOS := {
	"steam_burst": {"name": "Steam Burst", "needs": ["fire", "ice"], "desc": "Fire hitting slowed enemies erupts in scalding steam (+splash)."},
	"superconductor": {"name": "Superconductor", "needs": ["lightning", "ice"], "desc": "Lightning deals double damage to slowed or frozen enemies."},
	"wildfire": {"name": "Wildfire", "needs": ["fire", "lightning"], "desc": "Lightning sets enemies ablaze."},
	"shatter": {"name": "Shatter", "needs": ["ice", "physical"], "desc": "Frozen enemies take triple physical damage."},
	"divine_storm": {"name": "Divine Storm", "needs": ["holy", "lightning"], "desc": "Lightning kills repair the castle."},
	"war_economy": {"name": "War Economy", "needs": ["wealth", "defense"], "desc": "Defenses cost nothing."},
	"hero_legend": {"name": "Living Legend", "needs": ["hero", "arcane"], "desc": "Hero abilities also cast a free Fireball."},
}
const BLESSING_EVERY := 3   # waves between blessing picks

# =====================================================================================
# PERMANENT UPGRADES (Upgrades menu)
# =====================================================================================
const UPGRADES := {
	"castle_hp": {"name": "Fortified Walls", "desc": "+10% castle health per level.", "max": 20, "per": 0.10, "group": "Castle"},
	"castle_armor": {"name": "Reinforced Stone", "desc": "-3% damage taken per level.", "max": 10, "per": 0.03, "group": "Castle"},
	"defense_hp": {"name": "Master Masons", "desc": "+8% barrier and wall health per level.", "max": 15, "per": 0.08, "group": "Castle"},
	"start_gold": {"name": "War Chest", "desc": "+40 starting gold per level.", "max": 10, "per": 40.0, "group": "Economy"},
	"kill_gold": {"name": "Bounty Hunters", "desc": "+5% gold from kills per level.", "max": 20, "per": 0.05, "group": "Economy"},
	"loot_luck": {"name": "Fortune's Favor", "desc": "+5% chance of higher-rarity loot per level.", "max": 10, "per": 0.05, "group": "Economy"},
	"tower_damage": {"name": "Tempered Arrows", "desc": "+5% tower damage per level.", "max": 20, "per": 0.05, "group": "Towers"},
	"tower_speed": {"name": "Swift Mechanisms", "desc": "+3% tower attack speed per level.", "max": 15, "per": 0.03, "group": "Towers"},
	"trap_damage": {"name": "Cruel Contraptions", "desc": "+6% trap damage per level.", "max": 15, "per": 0.06, "group": "Towers"},
	"spell_power": {"name": "Arcane Study", "desc": "+6% spell damage per level.", "max": 20, "per": 0.06, "group": "Magic"},
	"spell_cooldown": {"name": "Mana Wells", "desc": "-3% spell cooldown per level.", "max": 10, "per": 0.03, "group": "Magic"},
	"hero_damage": {"name": "Heroic Training", "desc": "+5% hero damage per level.", "max": 20, "per": 0.05, "group": "Heroes"},
	"hero_xp": {"name": "Veteran Mentors", "desc": "+10% hero experience per level.", "max": 10, "per": 0.10, "group": "Heroes"},
}
const UPGRADE_ORDER := ["castle_hp", "castle_armor", "defense_hp", "start_gold", "kill_gold", "loot_luck", "tower_damage",
	"tower_speed", "trap_damage", "spell_power", "spell_cooldown", "hero_damage", "hero_xp"]


func upgrade_cost(id: String, level: int) -> int:
	return int(150.0 * pow(level + 1, 1.6))


func hero_xp_to_next(level: int) -> int:
	return int(100.0 * pow(level, 1.45))
