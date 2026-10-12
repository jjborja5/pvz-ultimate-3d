// Plant characters. Each plant has its own sculpted builder; all are baked to one skinned mesh.
import * as THREE from 'three';
import { cachedTemplate, face, geo, instantiate, Rig, type CharacterInstance } from './kit';
import { leafRing, mound, mushroom, peaHead, petalRing, pottedStem, stem } from './parts';
import { BUILDERS_B2 } from './plants2';
import { BUILDERS_B3 } from './plants3';
import { BUILDERS_B4 } from './plants4';

export interface PlantModel {
  root: THREE.Group;
  inst: CharacterInstance;
  body: THREE.Bone;
  head: THREE.Bone;
  headRest: THREE.Vector3;
  eyes: THREE.Bone | null;
  bones: Record<string, THREE.Bone>;
  muzzleY: number;
}

export interface ModelMeta {
  muzzleY: number;
}

export type Builder = (r: Rig) => ModelMeta;

const PI = Math.PI;

// ------------------------------------------------------------------ batch 1 builders

function peaPlant(r: Rig, o: Parameters<typeof peaHead>[1] & { h?: number; leaf?: string; stemColor?: string }) {
  const h = o.h ?? 0.5;
  r.bone('body', 'root', [0, 0, 0]);
  pottedStem(r, h, o.leaf, o.stemColor);
  r.bone('head', 'body', [0, h + 0.06, 0]);
  peaHead(r, o);
  return { muzzleY: h + 0.06 };
}

function sunflowerHead(r: Rig, scale = 1, faceOpts: Parameters<typeof face>[1] | null = null) {
  r.add(geo.lathe('sfdisk', [[0, -0.6], [0.8, -0.5], [1, 0], [0.8, 0.5], [0, 0.6]], 20), '#9a5a1a', { rot: [0, 0, -PI / 2], scale: [0.17 * scale, 0.12 * scale, 0.17 * scale], top: '#6a3a10', axis: 'y' });
  r.add(geo.cyl(20), '#ffd23f', { pos: [0.075 * scale, 0, 0], rot: [0, 0, -PI / 2], scale: [0.135 * scale, 0.01, 0.135 * scale] });
  face(r, faceOpts ?? { at: [0.08 * scale, 0.02 * scale, 0], size: 0.044 * scale, spacing: 0.095 * scale, expression: 'happy', mouth: 'smile', skin: '#ffd23f', blinkBone: scale === 1 ? 'eyes' : undefined });
}

export const BUILDERS: Record<string, Builder> = {
  peashooter: (r) => peaPlant(r, { color: '#5fcf4f', light: '#9aef6a' }),

  sunflower: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r);
    leafRing(r, { n: 4, color: '#3e9a3a', len: 0.32 });
    stem(r, 0.55, { bend: 0.05 });
    r.add(geo.leaf(0.3, 0.1), '#3e9a3a', { pos: [0, 0.3, 0], rot: [0, 0.5, 0.5], scale: [0.2, 0.3, 0.1], top: '#6fcf4a', axis: 'x' });
    r.bone('head', 'body', [0, 0.64, 0], [0, -0.55, 0]);
    r.bone('petals', 'head', [0, 0, 0]);
    petalRing(r, { n: 14, radius: 0.18, len: 0.16, width: 0.09, color: '#ffb31f', tip: '#ffe36a', x: -0.01 });
    petalRing(r, { n: 14, radius: 0.15, len: 0.13, width: 0.08, color: '#ff9a1f', tip: '#ffcf33', x: -0.03, offset: 0.22 });
    r.on('head');
    sunflowerHead(r);
    return { muzzleY: 0.64 };
  },

  wallnut: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    r.bone('head', 'body', [0, 0.02, 0]);
    r.add(geo.lathe('nut', [[0, 0], [0.55, 0.04], [0.9, 0.25], [1, 0.5], [0.95, 0.75], [0.7, 0.95], [0.35, 1.04], [0, 1.06]], 20), '#a8662f', { scale: [0.34, 0.62, 0.32], top: '#d8954e' });
    for (let i = 0; i < 9; i++) {
      const a = i * 2.1;
      const y = 0.1 + (i % 4) * 0.12;
      r.add(geo.sphere(8), '#8a5023', { pos: [Math.cos(a) * 0.31, y, Math.sin(a) * 0.3], scale: [0.03, 0.045, 0.03] });
    }
    r.add(geo.leaf(0.4, 0.1), '#4f9f3e', { pos: [-0.02, 0.64, 0], rot: [0, 0.4, 1.1], scale: [0.14, 0.4, 0.08], top: '#7fcf5a', axis: 'x' });
    face(r, { at: [0.32, 0.38, 0], size: 0.075, spacing: 0.15, expression: 'determined', mouth: 'frown', skin: '#c07a3a', cheeks: null, blinkBone: 'eyes' });
    return { muzzleY: 0.4 };
  },

  potatomine: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.32);
    r.bone('head', 'body', [0, 0, 0]);
    r.add(geo.sphere(16), '#c99a5b', { pos: [0, 0.13, 0], scale: [0.25, 0.17, 0.22], top: '#e8c08a' });
    for (const [x, y, z] of [
      [0.05, 0.27, 0.1],
      [-0.12, 0.22, -0.06],
      [0.1, 0.16, -0.16],
      [-0.15, 0.12, 0.12],
    ]) {
      r.add(geo.sphere(8), '#9c6e38', { pos: [x, y, z], scale: [0.025, 0.015, 0.025] });
    }
    face(r, { at: [0.22, 0.17, 0], size: 0.045, spacing: 0.09, expression: 'happy', mouth: 'grin', skin: '#c99a5b', blinkBone: 'eyes' });
    r.on('head');
    r.add(geo.tube('antenna', [[0, 0.28, 0], [0.02, 0.36, 0], [-0.01, 0.45, 0]], 0.012), '#666666');
    r.bone('light', 'head', [-0.01, 0.48, 0]);
    r.add(geo.sphere(10), '#ff2a2a', { scale: 0.04, top: '#ff9a8a' });
    return { muzzleY: 0.2 };
  },

  cherrybomb: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    r.bone('head', 'body', [0, 0, 0]);
    r.add(geo.tube('cherrystem1', [[0.03, 0.34, 0.14], [0.02, 0.5, 0.08], [0, 0.62, 0]], 0.018), '#3e8a2e');
    r.add(geo.tube('cherrystem2', [[-0.03, 0.34, -0.14], [-0.02, 0.5, -0.08], [0, 0.62, 0]], 0.018), '#3e8a2e');
    r.add(geo.leaf(0.3, 0.12), '#4fae3a', { pos: [0, 0.62, 0], rot: [0, -0.4, 0.4], scale: [0.18, 0.35, 0.1], top: '#8fdf5a', axis: 'x' });
    for (const side of [1, -1]) {
      const z = 0.15 * side;
      const x = 0.03 * side;
      r.add(geo.sphere(18), '#c8141e', { pos: [x, 0.2, z], scale: 0.19, top: '#ff4a4a' });
      r.add(geo.sphere(8), '#ffb0b0', { pos: [x + 0.08, 0.3, z + 0.04], scale: [0.04, 0.03, 0.03] });
      face(r, { at: [x + 0.17, 0.22, z], size: 0.042, spacing: 0.09, expression: 'fierce', mouth: 'teeth', skin: '#d8202a', cheeks: null, blinkBone: side === 1 ? 'eyes' : undefined });
      r.on('head');
    }
    return { muzzleY: 0.3 };
  },

  snowpea: (r) => {
    const m = peaPlant(r, { color: '#7fd0ff', light: '#d8f4ff', rim: '#ffffff', crest: 'none', leaf: '#3e9a8a', face: { expression: 'cool', mouth: 'none', iris: '#2a6aa8' } });
    r.on('head');
    for (let i = -1; i <= 1; i++) {
      r.add(geo.cone(6), '#e8faff', { pos: [-0.06 + i * 0.07, 0.2 - Math.abs(i) * 0.03, 0], rot: [0, 0, i * 0.35], scale: [0.045, 0.17, 0.045], top: '#ffffff' });
    }
    r.add(geo.cone(6), '#bfefff', { pos: [-0.18, 0.08, 0.05], rot: [0.4, 0, 1.2], scale: [0.035, 0.12, 0.035] });
    return m;
  },

  repeater: (r) => peaPlant(r, { color: '#2fa84f', light: '#6fd86a', crest: 'leaves', crestColor: '#1f6e2c', leaf: '#226e2c', face: { expression: 'angry' } }),

  tripea: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    pottedStem(r, 0.38);
    r.add(geo.tube('tribranch1', [[0, 0.36, 0], [0.02, 0.45, 0.12], [0, 0.5, 0.22]], 0.04), '#3c9d3a');
    r.add(geo.tube('tribranch2', [[0, 0.36, 0], [0.02, 0.45, -0.12], [0, 0.5, -0.22]], 0.04), '#3c9d3a');
    r.add(geo.tube('tribranch3', [[0, 0.36, 0], [0, 0.48, 0], [0, 0.6, 0]], 0.04), '#3c9d3a');
    r.bone('head', 'body', [0, 0.62, 0]);
    peaHead(r, { color: '#5fcf4f', light: '#9aef6a', size: 0.16, crest: 'none' });
    r.on('head');
    for (const z of [0.24, -0.24]) {
      r.bone(z > 0 ? 'side1' : 'side2', 'head', [0, -0.1, z]);
      peaHead(r, { color: '#55c64a', light: '#8fe866', size: 0.15, crest: 'none', face: { blinkBone: undefined, expression: z > 0 ? 'happy' : 'determined' } });
      r.on('head');
    }
    return { muzzleY: 0.55 };
  },

  peekapea: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    pottedStem(r, 0.5);
    r.bone('head', 'body', [0, 0.56, 0]);
    peaHead(r, { color: '#5fcf4f', light: '#9aef6a', size: 0.19, crest: 'none' });
    r.on('head');
    r.bone('back', 'head', [-0.1, 0, 0], [0, PI, 0]);
    peaHead(r, { color: '#4bb84a', light: '#86e06a', size: 0.17, crest: 'none', face: { expression: 'worried', blinkBone: undefined } });
    return { muzzleY: 0.56 };
  },

  emberpea: (r) => {
    const m = peaPlant(r, { color: '#ff6a1f', light: '#ffd23f', rim: '#ffe36a', crest: 'none', leaf: '#5a8a2a', face: { expression: 'fierce', iris: '#8a1a0a' } });
    r.on('head');
    for (let i = 0; i < 5; i++) {
      r.add(geo.cone(8), i % 2 ? '#ffb02a' : '#ff4a1a', { pos: [-0.12 + i * 0.03, 0.2 + (i % 2) * 0.03, (i - 2) * 0.05], rot: [(i - 2) * 0.25, 0, 0.6], scale: [0.06, 0.2 - Math.abs(i - 2) * 0.03, 0.06], top: '#ffe36a' });
    }
    return m;
  },

  gatlingpod: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    pottedStem(r, 0.5, '#2f7a2c');
    r.bone('head', 'body', [0, 0.56, 0]);
    peaHead(r, { color: '#3fa840', light: '#7fd86a', snout: 'none', crest: 'none', face: { expression: 'determined' } });
    r.on('head');
    r.add(geo.hemi(), '#4a5a2a', { pos: [0, 0.03, 0], scale: [0.235, 0.2, 0.235], top: '#6a7a3a' });
    r.add(geo.cyl(16), '#3a4a1a', { pos: [0, 0.04, 0], scale: [0.25, 0.02, 0.25] });
    r.add(geo.cyl(12), '#555555', { pos: [0.25, -0.03, 0], rot: [0, 0, -PI / 2], scale: [0.09, 0.08, 0.09], top: '#888888' });
    for (let i = 0; i < 4; i++) {
      const a = (i / 4) * PI * 2 + 0.4;
      r.add(geo.cyl(8), '#4a4a4a', { pos: [0.37, -0.03 + Math.cos(a) * 0.045, Math.sin(a) * 0.045], rot: [0, 0, -PI / 2], scale: [0.025, 0.22, 0.025], top: '#9a9a9a' });
    }
    return { muzzleY: 0.53 };
  },

  doublebloom: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r);
    leafRing(r, { n: 5 });
    stem(r, 0.4);
    r.add(geo.tube('db1', [[0, 0.38, 0], [0, 0.5, 0.1], [0, 0.6, 0.2]], 0.04), '#3c9d3a');
    r.add(geo.tube('db2', [[0, 0.38, 0], [0, 0.5, -0.1], [0, 0.6, -0.2]], 0.04), '#3c9d3a');
    r.bone('head', 'body', [0, 0.64, 0], [0, -0.55, 0]);
    for (const z of [0.21, -0.21]) {
      r.bone(z > 0 ? 'f1' : 'f2', 'head', [0, 0, z]);
      petalRing(r, { n: 12, radius: 0.13, len: 0.12, width: 0.07, color: '#ffb31f', tip: '#ffe36a' });
      sunflowerHead(r, 0.75, { at: [0.06, 0.015, 0], size: 0.028, spacing: 0.064, expression: z > 0 ? 'happy' : 'cute', mouth: z > 0 ? 'smile' : 'tongue', skin: '#ffd23f', blinkBone: z > 0 ? 'eyes' : undefined });
      r.on('head');
    }
    return { muzzleY: 0.64 };
  },

  sunspore: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.22);
    r.bone('head', 'body', [0, 0.02, 0]);
    mushroom(r, { cap: '#ff9a1f', capTop: '#ffe36a', h: 0.22, capR: 0.2, spots: '#fff6b0' });
    face(r, { at: [0.11, 0.12, 0], size: 0.035, spacing: 0.07, expression: 'sleepy', mouth: 'smile', skin: '#f2e6c8', blinkBone: 'eyes' });
    return { muzzleY: 0.3 };
  },

  towernut: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    r.bone('head', 'body', [0, 0.02, 0]);
    r.add(geo.lathe('tallnut', [[0, 0], [0.6, 0.02], [0.92, 0.15], [1, 0.4], [0.97, 0.7], [0.85, 0.9], [0.55, 1.0], [0, 1.03]], 20), '#9a5a2a', { scale: [0.3, 1.18, 0.28], top: '#d8954e' });
    for (let i = 0; i < 12; i++) {
      const a = i * 2.3;
      r.add(geo.sphere(8), '#7a4520', { pos: [Math.cos(a) * 0.28, 0.12 + (i % 6) * 0.17, Math.sin(a) * 0.27], scale: [0.03, 0.05, 0.03] });
    }
    r.add(geo.box(), '#f0e6d0', { pos: [0.27, 0.95, 0.06], rot: [0.4, 0, 0], scale: [0.02, 0.05, 0.16] });
    face(r, { at: [0.28, 0.82, 0], size: 0.065, spacing: 0.14, expression: 'determined', mouth: 'smirk', skin: '#b06a32', cheeks: null, blinkBone: 'eyes' });
    return { muzzleY: 0.6 };
  },

  blazepepper: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.22);
    r.bone('head', 'body', [0, 0.02, 0]);
    r.add(geo.lathe('pepper', [[0, 0], [0.35, 0.08], [0.7, 0.35], [0.9, 0.65], [0.85, 0.85], [0.55, 0.98], [0, 1]], 16), '#d8141e', { scale: [0.15, 0.62, 0.15], top: '#ff5a3a' });
    r.add(geo.lathe('pepcap', [[0, 0.1], [0.9, 0], [1, 0.3], [0.5, 0.6], [0.2, 0.8], [0, 1]], 10), '#3e8a2e', { pos: [0, 0.6, 0], scale: [0.13, 0.1, 0.13], top: '#6fcf4a' });
    r.add(geo.tube('pepstem', [[0, 0.68, 0], [0.03, 0.75, 0], [0.07, 0.78, 0]], 0.02), '#3e8a2e');
    face(r, { at: [0.135, 0.42, 0], size: 0.045, spacing: 0.09, expression: 'angry', mouth: 'teeth', skin: '#e02028', cheeks: null, blinkBone: 'eyes' });
    return { muzzleY: 0.4 };
  },

  buttercob: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r);
    leafRing(r, { n: 5, color: '#5a9a2a', len: 0.34 });
    r.bone('head', 'body', [0, 0.05, 0]);
    r.add(geo.lathe('cob', [[0, 0], [0.7, 0.05], [0.95, 0.3], [1, 0.6], [0.85, 0.85], [0.45, 1], [0, 1.02]], 18), '#ffcf33', { scale: [0.15, 0.48, 0.15], top: '#ffe98a' });
    for (let row = 0; row < 7; row++) {
      for (let k = 0; k < 6; k++) {
        const a = (k / 6) * PI * 2 + row * 0.5;
        const y = 0.06 + row * 0.055;
        const rr = 0.145 * Math.sin(Math.min(PI * 0.98, ((y + 0.02) / 0.5) * PI * 0.9 + 0.3));
        r.add(geo.sphere(6), '#ffd84a', { pos: [Math.cos(a) * rr, y, Math.sin(a) * rr], scale: 0.026 });
      }
    }
    for (const side of [1, -1]) {
      r.add(geo.leaf(0.7, 0.2), '#7ab83a', { pos: [0, 0.02, side * 0.06], rot: [side * 0.3, side * 1.4, 1.35], scale: [0.4, 0.35, 0.13], top: '#c8e87a', axis: 'x' });
    }
    face(r, { at: [0.14, 0.26, 0], size: 0.045, spacing: 0.095, expression: 'happy', mouth: 'grin', skin: '#ffcf33', blinkBone: 'eyes' });
    r.on('head');
    r.bone('arm', 'head', [-0.05, 0.4, 0], [0, 0, 0.6]);
    r.add(geo.tube('cobarm', [[0, 0, 0], [-0.1, 0.12, 0], [-0.2, 0.18, 0]], 0.02), '#5a9a2a');
    r.add(geo.lathe('basket', [[0, 0], [0.9, 0.2], [1, 0.6], [0.8, 0.6], [0, 0.3]], 10), '#7ab83a', { pos: [-0.22, 0.17, 0], scale: [0.08, 0.06, 0.08] });
    r.add(geo.rbox(0.3), '#ffe36a', { pos: [-0.22, 0.21, 0], scale: [0.08, 0.03, 0.06] });
    return { muzzleY: 0.5 };
  },

  melonmortar: (r) => melonPult(r, '#4fa83a', '#2a7a27', '#ff5a6a', false),
  frostmelon: (r) => melonPult(r, '#6fc8c8', '#2a8a9a', '#c8f4ff', true),

  punchchoy: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r);
    r.bone('head', 'body', [0, 0.02, 0]);
    for (let i = 0; i < 6; i++) {
      const a = (i / 6) * PI * 2;
      r.add(geo.capsule(3), '#f2f6e8', { pos: [Math.cos(a) * 0.07, 0.22, Math.sin(a) * 0.07], rot: [Math.sin(a) * 0.2, 0, -Math.cos(a) * 0.2], scale: [0.07, 0.18, 0.05], top: '#d8ecc0' });
      r.add(geo.leaf(0.1, 0.25), '#3a9a3a', { pos: [Math.cos(a) * 0.08, 0.32, Math.sin(a) * 0.08], rot: [0, -a, 1.3], scale: [0.36, 0.5, 0.2], top: '#7fd86a', axis: 'x' });
    }
    r.add(geo.sphere(14), '#e8f2d8', { pos: [0, 0.38, 0], scale: [0.15, 0.17, 0.14], top: '#ffffff' });
    face(r, { at: [0.13, 0.4, 0], size: 0.045, spacing: 0.095, expression: 'fierce', mouth: 'grin', skin: '#e8f2d8', blinkBone: 'eyes' });
    for (const [name, z] of [
      ['armL', 0.17],
      ['armR', -0.17],
    ] as const) {
      r.bone(name, 'head', [0, 0.3, z], [0, 0, -0.3]);
      r.add(geo.tube('choyarm', [[0, 0, 0], [0.06, 0.06, 0], [0.12, 0.1, 0]], 0.03), '#5aaa3a');
      r.add(geo.sphere(12), '#3a9a3a', { pos: [0.16, 0.12, 0], scale: [0.08, 0.07, 0.08], top: '#7fd86a' });
      r.on('head');
    }
    return { muzzleY: 0.4 };
  },

  beambean: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r);
    leafRing(r, { n: 3, len: 0.3 });
    stem(r, 0.32, { bend: 0.06 });
    r.bone('head', 'body', [0, 0.45, 0]);
    r.add(geo.sphere(18), '#5ab83a', { rot: [0, 0, -0.35], scale: [0.2, 0.25, 0.18], top: '#9ae86a' });
    r.add(geo.sphere(12), '#4aa82a', { pos: [-0.08, -0.12, 0], scale: [0.12, 0.12, 0.13] });
    r.add(geo.torus(PI * 2, 0.22), '#2a2a3a', { pos: [0.0, 0.07, 0], rot: [PI / 2, 0, 0.1], scale: [0.195, 0.175, 0.12] });
    r.add(geo.cyl(16), '#3a3a4a', { pos: [0.17, 0.07, 0], rot: [0, 0, -PI / 2], scale: [0.085, 0.06, 0.085] });
    r.add(geo.cyl(16), '#ff3ad8', { pos: [0.2, 0.07, 0], rot: [0, 0, -PI / 2], scale: [0.065, 0.01, 0.065], top: '#ffb0f0', ol: 0 });
    face(r, { at: [0.2, 0.07, 0], size: 0.035, spacing: 0.0001, expression: 'determined', mouth: 'none', skin: '#5ab83a', iris: '#ff2ad0', cheeks: null, blinkBone: 'eyes', eyeHeight: 0.0 });
    r.on('head');
    r.add(geo.torus(PI, 0.22), '#1f4a1a', { pos: [0.18, -0.08, 0], rot: [PI, PI / 2, 0], scale: 0.04 });
    return { muzzleY: 0.5 };
  },

  zapreed: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.25);
    for (let i = 0; i < 4; i++) {
      const a = i * 1.6;
      r.add(geo.leaf(0.9, 0.05, 1.5), '#4a9a5a', { pos: [Math.cos(a) * 0.03, 0.03, Math.sin(a) * 0.03], rot: [0, -a, 1.3], scale: [0.5, 0.25, 0.06], top: '#8ad88a', axis: 'x' });
    }
    stem(r, 0.45, { color: '#4a8a4a', radius: 0.03 });
    r.bone('head', 'body', [0, 0.45, 0]);
    r.add(geo.capsule(2.4), '#7a4a2a', { pos: [0, 0.2, 0], scale: [0.11, 0.11, 0.11], top: '#a87a4a' });
    r.add(geo.cone(8), '#c8a8ff', { pos: [0, 0.47, 0], scale: [0.03, 0.14, 0.03], top: '#ffffff' });
    for (let i = 0; i < 3; i++) r.add(geo.torus(PI * 2, 0.12), '#b98cff', { pos: [0, 0.12 + i * 0.1, 0], rot: [PI / 2, 0, 0], scale: [0.115, 0.115, 0.06] });
    face(r, { at: [0.1, 0.24, 0], size: 0.035, spacing: 0.075, expression: 'crazy', mouth: 'grin', skin: '#7a4a2a', iris: '#8a3aff', blinkBone: 'eyes' });
    return { muzzleY: 0.65 };
  },

  starsprout: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r);
    leafRing(r, { n: 4, len: 0.26 });
    stem(r, 0.22);
    r.bone('head', 'body', [0, 0.42, 0], [0, -0.5, 0]);
    r.add(geo.star(5, 0.45), '#ffcf1f', { rot: [0, PI / 2, 0], scale: [0.23, 0.23, 0.18], top: '#fff27a' });
    face(r, { at: [0.08, 0.02, 0], size: 0.04, spacing: 0.085, expression: 'happy', mouth: 'grin', skin: '#ffcf1f', blinkBone: 'eyes' });
    return { muzzleY: 0.42 };
  },

  seekerthistle: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r);
    leafRing(r, { n: 5, len: 0.3, color: '#4a8a3a' });
    stem(r, 0.32);
    r.bone('head', 'body', [0, 0.46, 0]);
    r.add(geo.sphere(16), '#9a4fd8', { scale: [0.16, 0.18, 0.16], top: '#d8a8ff' });
    for (let i = 0; i < 18; i++) {
      const a = i * 2.39996;
      const y = 1 - (i / 17) * 1.6;
      const rr = Math.sqrt(Math.max(0, 1 - y * y));
      const dir = new THREE.Vector3(Math.cos(a) * rr, y, Math.sin(a) * rr);
      const q = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir);
      const e = new THREE.Euler().setFromQuaternion(q);
      r.add(geo.cone(6), '#e8d0ff', { pos: [dir.x * 0.17, dir.y * 0.18, dir.z * 0.16], rot: [e.x, e.y, e.z], scale: [0.02, 0.09, 0.02], top: '#ffffff' });
    }
    r.add(geo.lathe('thistlebase', [[0.6, 0], [1, 0.4], [0.7, 0.8], [0.2, 1]], 12), '#4a8a3a', { pos: [0, -0.2, 0], scale: [0.14, 0.12, 0.14], top: '#7ab85a' });
    face(r, { at: [0.15, 0.03, 0], size: 0.045, spacing: 0.09, expression: 'determined', mouth: 'smirk', skin: '#9a4fd8', blinkBone: 'eyes' });
    return { muzzleY: 0.46 };
  },

  hypnocap: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.24);
    r.bone('head', 'body', [0, 0.02, 0]);
    mushroom(r, { cap: '#c03ad8', capTop: '#ff7ae8', stalk: '#f2e0f2', h: 0.24, capR: 0.24, spots: '#7affe8' });
    r.add(geo.torus(PI * 2, 0.15), '#ffe36a', { pos: [0, 0.38, 0], rot: [PI / 2, 0, 0], scale: [0.14, 0.14, 0.05] });
    face(r, { at: [0.12, 0.12, 0], size: 0.04, spacing: 0.08, expression: 'crazy', mouth: 'o', skin: '#f2e0f2', iris: '#c03ad8', blinkBone: 'eyes' });
    return { muzzleY: 0.3 };
  },

  frostlettuce: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    r.bone('head', 'body', [0, 0, 0]);
    r.add(geo.sphere(16), '#bff0d8', { pos: [0, 0.14, 0], scale: [0.2, 0.15, 0.2], top: '#e8fff4' });
    for (let ring = 0; ring < 2; ring++) {
      const n = 7 + ring * 2;
      for (let i = 0; i < n; i++) {
        const a = (i / n) * PI * 2 + ring * 0.3;
        r.add(geo.leaf(0.6 - ring * 0.2, 0.25), ring ? '#7fd8b0' : '#a8ecd0', {
          pos: [Math.cos(a) * 0.05, 0.04 + ring * 0.02, -Math.sin(a) * 0.05],
          rot: [0, a, 0.9 - ring * 0.5],
          scale: [0.26 + ring * 0.04, 0.4, 0.18],
          top: '#e8fffa',
          axis: 'x',
        });
      }
    }
    for (let i = 0; i < 4; i++) r.add(geo.cone(5), '#e8faff', { pos: [Math.cos(i * 1.6) * 0.14, 0.22, Math.sin(i * 1.6) * 0.14], rot: [0.3, 0, 0.3 * (i % 2 ? 1 : -1)], scale: [0.02, 0.07, 0.02] });
    face(r, { at: [0.19, 0.17, 0], size: 0.04, spacing: 0.085, expression: 'cute', mouth: 'smile', skin: '#bff0d8', iris: '#2a7aa8', blinkBone: 'eyes' });
    return { muzzleY: 0.2 };
  },

  ...BUILDERS_B2,
  ...BUILDERS_B3,
  ...BUILDERS_B4,
};

function melonPult(r: Rig, rind: string, stripe: string, flesh: string, frosty: boolean): ModelMeta {
  r.bone('body', 'root', [0, 0, 0]);
  mound(r, 0.32);
  leafRing(r, { n: 5, len: 0.36, width: 0.2, color: frosty ? '#3a9a8a' : '#3e9a3a', tip: frosty ? '#bff0e8' : '#6fcf4a' });
  r.bone('head', 'body', [0, 0.04, 0]);
  r.add(geo.sphere(18), rind, { pos: [0, 0.25, 0], scale: [0.26, 0.23, 0.26], top: frosty ? '#c8f4f0' : '#8fdf6a' });
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * PI;
    r.add(geo.torus(PI, 0.05), stripe, { pos: [0, 0.25, 0], rot: [0, a, 0], scale: [0.262, 0.232, 0.262] });
  }
  face(r, { at: [0.25, 0.27, 0], size: 0.065, spacing: 0.13, expression: frosty ? 'cool' : 'happy', mouth: 'grin', skin: rind, blinkBone: 'eyes' });
  r.on('head');
  r.bone('arm', 'head', [-0.1, 0.42, 0], [0, 0, 0.6]);
  r.add(geo.tube('melarm', [[0, 0, 0], [-0.12, 0.12, 0], [-0.26, 0.2, 0]], 0.028), frosty ? '#3a8a7a' : '#4a8a2a');
  r.add(geo.lathe('mbasket', [[0, 0], [0.9, 0.2], [1, 0.7], [0.85, 0.7], [0, 0.35]], 12), frosty ? '#5ab8a8' : '#6aaa3a', { pos: [-0.28, 0.19, 0], scale: [0.12, 0.08, 0.12] });
  r.add(geo.sphere(12), flesh, { pos: [-0.28, 0.26, 0], scale: [0.1, 0.08, 0.1], top: frosty ? '#ffffff' : '#ff8a9a' });
  if (frosty) for (let i = 0; i < 3; i++) r.add(geo.cone(5), '#ffffff', { pos: [-0.3 + i * 0.03, 0.33, (i - 1) * 0.04], scale: [0.02, 0.06, 0.02] });
  return { muzzleY: 0.55 };
}

// ------------------------------------------------------------------ instancing

const meta = new Map<string, ModelMeta>();

export function hasPlantModel(id: string) {
  return id in BUILDERS;
}

export function buildPlant(id: string): PlantModel {
  const builder = BUILDERS[id] ?? BUILDERS.peashooter;
  const t = cachedTemplate('plant:' + id, () => {
    const r = new Rig();
    const m = builder(r);
    meta.set(id, m);
    return r.build();
  });
  const inst = instantiate(t);
  const bones = inst.bones;
  inst.root.rotation.y = -0.45; // turn toward the camera while still facing the zombies
  const head = bones.head ?? bones.body;
  return {
    root: inst.root,
    inst,
    body: bones.body ?? bones.root,
    head,
    headRest: head.position.clone(),
    eyes: bones.eyes ?? null,
    bones,
    muzzleY: meta.get(id)?.muzzleY ?? 0.5,
  };
}
