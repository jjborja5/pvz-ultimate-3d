// Zombie characters built on the rig kit: one skinned mesh per zombie plus detachable armor props.
import * as THREE from 'three';
import type { ZombieDef } from '../config';
import { cachedTemplate, characterMaterial, face, geo, instantiate, outlineMaterial, outlineSettings, Rig, type CharacterInstance, type RigTemplate } from './kit';

export interface ZombieModel {
  root: THREE.Group;
  inst: CharacterInstance;
  body: THREE.Bone;
  legL: THREE.Bone;
  legR: THREE.Bone;
  armL: THREE.Bone;
  armR: THREE.Bone;
  head: THREE.Bone;
  armor: THREE.Object3D | null;
  shield: THREE.Object3D | null;
  balloon: THREE.Object3D | null;
  makeHeadDebris(): THREE.Object3D;
}

const PI = Math.PI;

// ------------------------------------------------------------------ static (non-animated) props

let staticMat: THREE.MeshToonMaterial | null = null;
const staticCache = new Map<string, THREE.BufferGeometry>();

/** A rigid vertex-colored prop (armor, shields, debris) with an optional outline. */
export function staticMesh(key: string, build: (r: Rig) => void, outline = true): THREE.Object3D {
  let g = staticCache.get(key);
  if (!g) {
    const r = new Rig();
    build(r);
    g = r.build().geometry;
    staticCache.set(key, g);
  }
  if (!staticMat) staticMat = characterMaterial();
  const mesh = new THREE.Mesh(g, staticMat);
  mesh.castShadow = false;
  if (!outline || !outlineSettings.enabled) return mesh;
  const group = new THREE.Group();
  group.add(mesh);
  const o = new THREE.Mesh(g, outlineMaterial());
  group.add(o);
  return group;
}

function fromGeometry(g: THREE.BufferGeometry): THREE.Object3D {
  if (!staticMat) staticMat = characterMaterial();
  const group = new THREE.Group();
  group.add(new THREE.Mesh(g, staticMat));
  if (outlineSettings.enabled) group.add(new THREE.Mesh(g, outlineMaterial()));
  return group;
}

// ------------------------------------------------------------------ body

interface Look {
  skin: string;
  coat: string;
  pants: string;
  shirt: string;
  tie: string | null;
  shoes: string;
  hair: string;
  coatless?: boolean;
  big?: boolean;
}

function lookFor(def: ZombieDef): Look {
  const base: Look = { skin: def.skin, coat: def.coat, pants: '#4b4f6b', shirt: '#ece6d2', tie: '#c0282d', shoes: '#2c2420', hair: '#3b3020' };
  switch (def.id) {
    case 'vaulter':
      return { ...base, pants: '#c8463a', shirt: '#ffffff', tie: null, coatless: true, hair: '#2a2a2a' };
    case 'imp':
      return { ...base, pants: '#5a4a3a', shirt: '#d8c8a8', tie: null, coatless: true };
    case 'brute':
      return { ...base, pants: '#4a3a2a', shirt: '#8a7a6a', tie: null, coatless: true, big: true };
    case 'knight':
      return { ...base, pants: '#3a3a44', tie: null };
    case 'reader':
      return { ...base, coat: '#7a6a5a', tie: '#3a5a8a', hair: '#e8e8e8' };
    case 'balloon':
      return { ...base, tie: '#ffcf33' };
    default:
      return base;
  }
}

function buildZombieTemplate(def: ZombieDef): RigTemplate {
  const L = lookFor(def);
  const r = new Rig();
  r.bone('body', 'root', [0, 0, 0]);

  // Legs
  for (const [name, z] of [
    ['legL', 0.095],
    ['legR', -0.095],
  ] as const) {
    r.bone(name, 'body', [0, 0.55, z]);
    r.add(geo.capsule(4), L.pants, { pos: [0, -0.25, 0], scale: [0.13, 0.11, 0.13], top: L.pants });
    r.add(geo.rbox(0.35), L.shoes, { pos: [0.05, -0.52, 0], scale: [0.24, 0.08, 0.13], top: '#4a3a30' });
    if (def.id === 'imp' || def.id === 'basic') r.add(geo.box(), L.skin, { pos: [0.01, -0.36, z > 0 ? 0.04 : -0.04], scale: [0.04, 0.08, 0.02] }); // torn pant leg
    r.on('body');
  }

  // Torso
  const hunch = -0.12;
  r.bone('torso', 'body', [0, 0.8, 0], [0, 0, hunch]);
  if (L.coatless) {
    r.add(geo.rbox(0.3), L.shirt, { scale: [0.22, 0.46, 0.36], top: L.shirt });
    if (def.id === 'vaulter') r.add(geo.box(), '#c8463a', { pos: [0.112, 0.05, 0], scale: [0.01, 0.2, 0.04] });
  } else {
    r.add(geo.rbox(0.3), L.coat, { scale: [0.24, 0.5, 0.4], top: L.coat });
    r.add(geo.box(), L.shirt, { pos: [0.11, 0.03, 0], scale: [0.03, 0.44, 0.15] });
    // lapels
    for (const s of [1, -1]) r.add(geo.box(), L.coat, { pos: [0.125, 0.1, s * 0.07], rot: [s * 0.35, 0, 0], scale: [0.02, 0.22, 0.05], top: '#000000' });
    if (L.tie) {
      r.add(geo.box(), L.tie, { pos: [0.13, 0.08, 0], scale: [0.025, 0.26, 0.05] });
      r.add(geo.box(), L.tie, { pos: [0.13, 0.2, 0], scale: [0.03, 0.05, 0.07] });
    }
    // torn patch + pocket
    r.add(geo.box(), '#3a2a20', { pos: [0.122, -0.14, -0.13], scale: [0.01, 0.07, 0.06] });
    r.add(geo.box(), L.skin, { pos: [-0.12, -0.05, 0.1], scale: [0.01, 0.08, 0.06] });
  }
  r.add(geo.rbox(0.3), '#2a2018', { pos: [0, -0.24, 0], scale: [0.25, 0.05, 0.41] }); // belt
  r.add(geo.box(), '#c8a838', { pos: [0.13, -0.24, 0], scale: [0.02, 0.04, 0.05] });
  // neck
  r.add(geo.cyl(10), L.skin, { pos: [0.01, 0.27, 0], scale: [0.06, 0.08, 0.06] });

  // Arms
  for (const [name, z] of [
    ['armL', 0.23],
    ['armR', -0.23],
  ] as const) {
    r.bone(name, 'body', [0, 0.98, z], [0, 0, 1.3]);
    r.add(geo.capsule(3), L.coatless ? L.skin : L.coat, { pos: [0, -0.13, 0], scale: [0.11, 0.075, 0.11] });
    r.add(geo.capsule(3), L.skin, { pos: [0, -0.32, 0], scale: [0.085, 0.06, 0.085] });
    r.add(geo.sphere(10), L.skin, { pos: [0, -0.43, 0], scale: [0.055, 0.06, 0.05] });
    for (let f = -1; f <= 1; f++) r.add(geo.capsule(2), L.skin, { pos: [0.015, -0.49, f * 0.022], rot: [f * 0.2, 0, 0], scale: [0.022, 0.03, 0.022] });
    r.on('body');
  }

  // Head
  r.bone('head', 'body', [0.05, 1.06, 0]);
  r.add(geo.sphere(16), L.skin, { pos: [0, 0.16, 0], scale: [0.17, 0.19, 0.165], top: L.skin });
  r.add(geo.sphere(12), L.skin, { pos: [0.06, 0.03, 0], scale: [0.12, 0.075, 0.125] }); // jaw
  r.add(geo.capsule(2), L.skin, { pos: [0.165, 0.13, 0], rot: [0, 0, -0.3], scale: [0.04, 0.04, 0.035] }); // nose
  for (const s of [1, -1]) r.add(geo.sphere(8), L.skin, { pos: [0, 0.15, s * 0.165], scale: [0.03, 0.05, 0.02] }); // ears
  r.add(geo.box(), '#5a7a4a', { pos: [0.1, 0.27, 0.05], rot: [0.3, 0, 0], scale: [0.005, 0.07, 0.01] }); // stitch
  face(r, { at: [0.15, 0.17, 0], size: 0.048, spacing: 0.12, expression: 'zombie', mouth: 'zombie', skin: L.skin, cheeks: null, mouthDrop: 0.12, iris: '#d8d0a0' });
  r.on('head');
  if (def.id !== 'imp' && def.id !== 'brute') {
    for (let i = 0; i < 4; i++) r.add(geo.capsule(2), L.hair, { pos: [-0.05 + i * 0.03, 0.33, -0.06 + i * 0.04], rot: [0.3 * (i - 1.5), 0, 0.3], scale: [0.025, 0.05, 0.025] });
  }
  if (def.id === 'reader') {
    for (const s of [1, -1]) r.add(geo.torus(PI * 2, 0.15), '#2a2a2a', { pos: [0.16, 0.2, s * 0.06], rot: [0, PI / 2, 0], scale: 0.04 });
  }
  if (def.id === 'vaulter') r.add(geo.torus(PI * 2, 0.2), '#ffffff', { pos: [0, 0.26, 0], rot: [PI / 2, 0, -0.15], scale: [0.17, 0.17, 0.08] });
  if (def.id === 'imp' || def.id === 'brute') r.add(geo.hemi(), '#b0302a', { pos: [0, 0.22, 0], rot: [0, 0, -0.15], scale: [0.175, 0.13, 0.17] });
  if (def.id === 'balloon') {
    for (const s of [1, -1]) r.add(geo.cyl(10), '#8a6a3a', { pos: [0.13, 0.25, s * 0.06], rot: [0, 0, -PI / 2], scale: [0.04, 0.03, 0.04] });
    r.add(geo.box(), '#5a3a1a', { pos: [0.05, 0.25, 0], scale: [0.2, 0.025, 0.34] });
  }
  r.markDetachable('head');

  // Hand-held props that are part of the skinned body
  if (def.id === 'flag') {
    r.on('armR');
    r.add(geo.cyl(8), '#6b4a2a', { pos: [0.45, -0.45, 0], rot: [0, 0, -PI / 2], scale: [0.02, 1.0, 0.02] });
    r.add(geo.box(), '#c3262e', { pos: [0.85, -0.45, 0.22], scale: [0.32, 0.03, 0.4] });
    r.add(geo.sphere(10), '#f5e9c8', { pos: [0.85, -0.43, 0.22], scale: [0.09, 0.012, 0.09] });
    r.add(geo.sphere(8), '#ff9a9a', { pos: [0.85, -0.42, 0.22], scale: [0.05, 0.012, 0.03] });
  }
  if (def.id === 'brute') {
    r.on('armL');
    r.add(geo.capsule(4), '#7a4e26', { pos: [0, -0.7, 0], scale: [0.12, 0.12, 0.12], top: '#9a6a3a' });
    r.add(geo.lathe('club', [[0.6, 0], [1, 0.5], [0.9, 1]], 10), '#8f5d2e', { pos: [0, -1.0, 0], scale: [0.14, 0.25, 0.14] });
  }
  if (def.id === 'vaulter') {
    r.on('armL');
    r.add(geo.cyl(8), '#c8a838', { pos: [0, -0.45, -0.2], rot: [PI / 2, 0, 0], scale: [0.018, 1.3, 0.018] });
  }
  return r.build();
}

function armorProp(def: ZombieDef): THREE.Object3D | null {
  switch (def.armorType) {
    case 'cone':
      return staticMesh('cone', (r) => {
        r.add(geo.cone(16), '#ff7a12', { pos: [0, 0.18, 0], scale: [0.16, 0.38, 0.16], top: '#ffb04a' });
        r.add(geo.cyl(16), '#ffffff', { pos: [0, 0.14, 0], scale: [0.115, 0.05, 0.115] });
        r.add(geo.rbox(0.2), '#e06a10', { pos: [0, -0.01, 0], scale: [0.34, 0.035, 0.34] });
      });
    case 'bucket':
      return staticMesh('bucket', (r) => {
        r.add(geo.lathe('bucket', [[0.8, 0], [1, 0.95], [1.05, 1], [0, 1]], 18), '#9aa4ac', { pos: [0, -0.06, 0], scale: [0.17, 0.26, 0.17], top: '#d0d8de' });
        r.add(geo.torus(PI * 2, 0.15), '#7e878f', { pos: [0, 0.18, 0], rot: [PI / 2, 0, 0], scale: [0.18, 0.18, 0.12] });
        r.add(geo.torus(PI, 0.1), '#7e878f', { pos: [0, 0.05, 0], rot: [0, PI / 2, PI], scale: [0.19, 0.12, 0.12] });
        r.add(geo.box(), '#6a737a', { pos: [0.12, 0.12, 0.05], rot: [0, 0, 0.3], scale: [0.005, 0.04, 0.05] });
      });
    case 'knight':
      return staticMesh('knight', (r) => {
        // helmet (positioned at head height relative to the body bone)
        r.add(geo.sphere(16), '#9aa0aa', { pos: [0.05, 1.24, 0], scale: [0.2, 0.22, 0.195], top: '#e0e6ee' });
        r.add(geo.box(), '#2a2a2a', { pos: [0.24, 1.22, 0], scale: [0.02, 0.025, 0.24] });
        r.add(geo.box(), '#8a9098', { pos: [0.24, 1.18, 0], scale: [0.025, 0.12, 0.03] });
        r.add(geo.cone(8), '#c8282d', { pos: [0.02, 1.5, 0], rot: [0, 0, 0.3], scale: [0.05, 0.18, 0.02] });
        // breastplate + shoulder guards
        r.add(geo.rbox(0.35), '#8a9098', { pos: [0.02, 0.83, 0], rot: [0, 0, -0.12], scale: [0.28, 0.42, 0.44], top: '#d8dee6' });
        for (const s of [1, -1]) r.add(geo.hemi(), '#9aa0aa', { pos: [0, 1.0, s * 0.24], scale: [0.11, 0.08, 0.11], top: '#e0e6ee' });
      });
    case 'paper':
      return staticMesh('paper', (r) => {
        r.add(geo.box(), '#f2efe4', { pos: [0, 0, 0], scale: [0.02, 0.36, 0.42] });
        for (let i = 0; i < 5; i++) r.add(geo.box(), '#8a8a8a', { pos: [0.012, 0.12 - i * 0.055, 0.02], scale: [0.005, 0.02, 0.3 - (i % 2) * 0.1] });
        r.add(geo.box(), '#2a2a2a', { pos: [0.012, 0.15, -0.12], scale: [0.006, 0.06, 0.12] });
      });
    default:
      return null;
  }
}

export function buildZombie(def: ZombieDef): ZombieModel {
  const t = cachedTemplate('zombie:' + def.id, () => buildZombieTemplate(def));
  const inst = instantiate(t);
  const b = inst.bones;
  let armor = armorProp(def);
  if (armor) {
    if (def.armorType === 'knight') b.body.add(armor);
    else if (def.armorType === 'paper') {
      armor.position.set(0.32, 0.92, 0);
      b.body.add(armor);
    } else {
      armor.position.set(-0.01, 0.31, 0);
      armor.rotation.z = -0.15;
      b.head.add(armor);
    }
  }
  let shield: THREE.Object3D | null = null;
  if (def.shield) {
    shield = staticMesh('door', (r) => {
      r.add(geo.rbox(0.1), '#7a7a7a', { scale: [0.04, 0.95, 0.62], top: '#a0a0a0' });
      r.add(geo.box(), '#c8d0d8', { pos: [0.01, 0.05, 0], scale: [0.03, 0.75, 0.48] });
      for (let i = 0; i < 6; i++) r.add(geo.box(), '#8a9098', { pos: [0.026, -0.3 + i * 0.12, 0], scale: [0.004, 0.006, 0.48] });
      r.add(geo.sphere(8), '#c8a838', { pos: [0.04, 0, -0.24], scale: 0.025 });
    });
    shield.position.set(0.36, 0.72, 0);
    b.body.add(shield);
  }
  let balloon: THREE.Object3D | null = null;
  if (def.flying) {
    balloon = staticMesh('balloon', (r) => {
      r.add(geo.cyl(4), '#e8e8e8', { pos: [0, 0.4, 0], scale: [0.006, 0.8, 0.006] });
      r.add(geo.lathe('balloon', [[0, 0], [0.25, 0.05], [0.8, 0.35], [1, 0.65], [0.85, 0.9], [0.4, 1.02], [0, 1.04]], 16), '#ff3a5a', { pos: [0, 0.75, 0], scale: [0.28, 0.6, 0.28], top: '#ff9aaa' });
      r.add(geo.sphere(8), '#ffffff', { pos: [0.12, 1.15, 0.1], scale: [0.05, 0.08, 0.03] });
    });
    balloon.position.set(0, -0.45, 0);
    b.armL.add(balloon);
  }
  if (armor === null) armor = null;
  inst.root.rotation.y = PI + 0.45; // face -x (toward the house), turned toward camera
  inst.root.scale.setScalar(def.scale);
  return {
    root: inst.root,
    inst,
    body: b.body,
    legL: b.legL,
    legR: b.legR,
    armL: b.armL,
    armR: b.armR,
    head: b.head,
    armor,
    shield,
    balloon,
    makeHeadDebris: () => fromGeometry(t.detach.head),
  };
}
