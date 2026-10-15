#!/usr/bin/env bash
# Downloads the CC0 KayKit asset subset used by Castle Dominion into assets/kaykit/.
# All packs are by Kay Lousberg (https://kaylousberg.com), licensed CC0 1.0.
# The files are committed to the repo; this script documents provenance and can re-fetch them.
set -euo pipefail
cd "$(dirname "$0")/.."
RAW=https://raw.githubusercontent.com/KayKit-Game-Assets
OUT=assets/kaykit

get() { # repo path dest
  mkdir -p "$(dirname "$3")"
  [ -s "$3" ] || curl -sSf --retry 3 -o "$3" "$RAW/$1/main/$2" || { echo "FAILED $2"; return 1; }
}

# --- Characters (rigged + animated) ---
A=KayKit-Character-Pack-Adventures-1.0; AP=addons/kaykit_character_pack_adventures
for c in Knight Barbarian Mage Rogue Rogue_Hooded; do get $A $AP/Characters/gltf/$c.glb $OUT/characters/$c.glb; done
get $A LICENSE.txt $OUT/characters/LICENSE_adventurers.txt
S=KayKit-Character-Pack-Skeletons-1.0; SP=addons/kaykit_character_pack_skeletons
for c in Skeleton_Minion Skeleton_Warrior Skeleton_Rogue Skeleton_Mage; do get $S $SP/Characters/gltf/$c.glb $OUT/characters/$c.glb; done
get $S LICENSE.txt $OUT/characters/LICENSE_skeletons.txt
for w in Skeleton_Blade Skeleton_Axe Skeleton_Staff Skeleton_Crossbow Skeleton_Shield_Large_A Skeleton_Shield_Small_A; do
  get $S $SP/Assets/gltf/$w.gltf $OUT/characters/weapons/$w.gltf; get $S $SP/Assets/gltf/$w.bin $OUT/characters/weapons/$w.bin; done
get $S $SP/Assets/gltf/skeleton_texture.png $OUT/characters/weapons/skeleton_texture.png

# --- Medieval Hexagon (castle, towers, nature) ---
H=KayKit-Medieval-Hexagon-Pack-1.0; HP=addons/kaykit_medieval_hexagon_pack/Assets/gltf
hexget() { # subdir name
  get $H $HP/$1/$2.gltf $OUT/hexagon/$2.gltf
  get $H $HP/$1/$2.bin $OUT/hexagon/$2.bin
}
get $H $HP/buildings/blue/hexagons_medieval.png $OUT/hexagon/hexagons_medieval.png
get $H LICENSE.txt $OUT/hexagon/LICENSE.txt
for col in blue red green yellow; do
  for b in tower_A tower_B tower_base tower_catapult; do hexget buildings/$col building_${b}_$col; done
done
for b in castle archeryrange barracks church home_A home_B windmill blacksmith tavern market well; do hexget buildings/blue building_${b}_blue; done
for b in wall_straight wall_straight_gate wall_corner_A_outside wall_corner_A_inside wall_corner_B_outside wall_corner_B_inside \
         building_destroyed building_scaffolding fence_stone_straight fence_wood_straight projectile_catapult building_bridge_A building_dirt; do
  hexget buildings/neutral $b; done
for n in mountain_A mountain_B mountain_C mountain_A_grass mountain_B_grass mountain_C_grass mountain_A_grass_trees mountain_B_grass_trees \
         mountain_C_grass_trees hills_A hills_B hills_C hills_A_trees hills_B_trees hills_C_trees hill_single_A hill_single_B hill_single_C \
         tree_single_A tree_single_B trees_A_large trees_A_medium trees_A_small trees_B_large trees_B_medium trees_B_small \
         rock_single_A rock_single_B rock_single_C rock_single_D rock_single_E cloud_big cloud_small; do hexget decoration/nature $n; done
for p in flag_blue flag_red flag_green flag_yellow barrel crate_A_big crate_B_big tent weaponrack target bucket_arrows sack \
         resource_stone resource_lumber ladder wheelbarrow; do hexget decoration/props $p; done

# --- Dungeon Remastered (traps, barriers, loot, torches) ---
D=KayKit-Dungeon-Remastered-1.0; DP=addons/kaykit_dungeon_remastered/Assets
get $D $DP/texture/dungeon_texture.png $OUT/dungeon/dungeon_texture.png
get $D LICENSE.txt $OUT/dungeon/LICENSE.txt
for d in torch_mounted torch_lit banner_patternA_blue banner_patternA_red banner_shield_blue banner_thin_blue barrier barrier_column barrier_half \
         barrel_large barrel_large_decorated barrel_small_stack coin coin_stack_large coin_stack_medium column pillar pillar_decorated rubble_large rubble_half \
         wall wall_broken wall_cracked wall_gated sword_shield_gold sword_shield_broken keg crates_stacked box_large; do
  get $D $DP/gltf/$d.gltf.glb $OUT/dungeon/$d.glb; done
for d in chest chest_gold floor_tile_big_spikes; do get $D $DP/gltf/$d.glb $OUT/dungeon/$d.glb; done

# --- Halloween Bits (graveyard ruins) ---
W=KayKit-Halloween-Bits-1.0; WP=addons/kaykit_halloween_bits/Assets/gltf
get $W $WP/halloweenbits_texture.png $OUT/halloween/halloweenbits_texture.png
get $W LICENSE.txt $OUT/halloween/LICENSE.txt
for h in arch arch_gate crypt grave_A grave_A_destroyed grave_B gravestone gravemarker_A tree_dead_large tree_dead_medium tree_dead_small \
         skull ribcage bone_A bone_B fence fence_broken fence_pillar_broken pillar shrine_candles lantern_standing post_skull post_lantern \
         tree_pine_orange_large tree_pine_orange_medium tree_pine_yellow_large; do
  get $W $WP/$h.gltf $OUT/halloween/$h.gltf; get $W $WP/$h.bin $OUT/halloween/$h.bin; done
echo "assets fetched"
