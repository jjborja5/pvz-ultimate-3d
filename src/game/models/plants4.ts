// Plant character builders for batch 4.
import * as THREE from 'three';
import { face, geo, type Rig } from './kit';
import { leafRing, mound, mushroom, peaHead, petalRing, pottedStem, stem } from './parts';
import type { Builder } from './plants';

const PI = Math.PI;

function pultArm(r: Rig, y: number, armColor: string, ammo: (r: Rig) => void) {
  r.bone('arm', 'head', [-0.08, y, 0], [0, 0, 0.6]);
  r.add(geo.tube('arm4:' + armColor, [[0, 0, 0], [-0.12, 0.1, 0], [-0.22, 0.16, 0]], 0.025), armColor);
  r.add(geo.lathe('basket4', [[0, 0], [0.9, 0.2], [1, 0.7], [0.85, 0.7], [0, 0.35]], 12), armColor, { pos: [-0.24, 0.15, 0], scale: [0.09, 0.07, 0.09] });
  ammo(r);
}

export const BUILDERS_B4: Record<string, Builder> = {
  rototurnip: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.28);
    r.bone('head', 'body', [0, 0.02, 0]);
    r.add(geo.lathe('turnip', [[0, 0], [0.3, 0.05], [0.8, 0.3], [1, 0.6], [0.8, 0.9], [0.3, 1], [0, 1.02]], 16), '#f2e8f2', { scale: [0.22, 0.4, 0.22], top: '#b04aa8' });
    r.bone('spin', 'head', [0, 0.42, 0]);
    for (let i = 0; i < 4; i++) {
      const a = (i / 4) * PI * 2 + PI / 4;
      r.add(geo.leaf(0.2, 0.2), '#4aa83a', { rot: [0, a, 0.25], scale: [0.26, 0.35, 0.12], top: '#9ae86a', axis: 'x' });
    }
    r.on('head');
    face(r, { at: [0.21, 0.22, 0], size: 0.045, spacing: 0.1, expression: 'crazy', mouth: 'grin', skin: '#e8c8e8', blinkBone: 'eyes' });
    return { muzzleY: 0.25 };
  },

  voltpea: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    pottedStem(r, 0.5, '#4a8a3a', '#5a8a3a');
    r.bone('head', 'body', [0, 0.56, 0]);
    peaHead(r, { color: '#ffd23f', light: '#fff6a0', rim: '#ffffff', crest: 'none', face: { expression: 'crazy', iris: '#7a3aff' } });
    r.on('head');
    for (let i = 0; i < 5; i++) r.add(geo.cone(5), '#c89a1a', { pos: [-0.05 - i * 0.02, 0.18, (i - 2) * 0.05], rot: [(i - 2) * 0.4, 0, 0.4], scale: [0.03, 0.14, 0.03], top: '#fff27a' });
    r.add(geo.cone(4), '#b98cff', { pos: [-0.18, 0.08, 0.05], rot: [0, 0, 1.5], scale: [0.025, 0.12, 0.025], ol: 0 });
    return { muzzleY: 0.56 };
  },

  goopea: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    pottedStem(r, 0.5, '#5a8a2a');
    r.bone('head', 'body', [0, 0.56, 0]);
    peaHead(r, { color: '#8fdf2a', light: '#d8ff7a', snout: 'flare', rim: '#c8ff5a', crest: 'none', face: { expression: 'smug', mouth: 'none', iris: '#3a6a0a' } });
    r.on('head');
    for (let i = 0; i < 4; i++) r.add(geo.capsule(2), '#a6ff3a', { pos: [0.02 + i * 0.07, -0.17 - (i % 2) * 0.03, (i - 1.5) * 0.06], scale: [0.025, 0.05, 0.025], top: '#d8ff9a' });
    r.add(geo.hemi(), '#a6ff3a', { pos: [-0.02, 0.15, 0], scale: [0.16, 0.08, 0.15], top: '#e8ffb0' });
    return { muzzleY: 0.56 };
  },

  peanut: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    r.bone('head', 'body', [0, 0.02, 0]);
    r.add(geo.sphere(16), '#d8a86a', { pos: [0, 0.2, 0], scale: [0.26, 0.22, 0.25], top: '#f0c890' });
    r.add(geo.sphere(16), '#d8a86a', { pos: [0, 0.5, 0], scale: [0.23, 0.2, 0.22], top: '#f0c890' });
    for (let i = 0; i < 10; i++) r.add(geo.sphere(6), '#b8884a', { pos: [Math.cos(i * 1.7) * 0.22, 0.12 + (i % 5) * 0.1, Math.sin(i * 1.7) * 0.22], scale: [0.02, 0.03, 0.02], ol: 0 });
    r.add(geo.lathe('pnsnout', [[0.45, 0], [0.4, 0.5], [0.55, 1], [0.42, 1.02]], 14), '#d8a86a', { pos: [0.18, 0.5, 0], rot: [0, 0, -PI / 2], scale: [0.18, 0.18, 0.18], top: '#f0c890' });
    r.add(geo.cyl(12), '#2a1a0a', { pos: [0.36, 0.5, 0], rot: [0, 0, -PI / 2], scale: [0.06, 0.01, 0.06], ol: 0 });
    face(r, { at: [0.2, 0.62, 0], size: 0.045, spacing: 0.1, expression: 'determined', mouth: 'none', skin: '#e0b07a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.5 };
  },

  magnetcap: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.26);
    r.bone('head', 'body', [0, 0.01, 0]);
    mushroom(r, { cap: '#8a3ad8', capTop: '#c88aff', stalk: '#e8dcf2', h: 0.22, capR: 0.22, flat: 0.75 });
    r.add(geo.torus(PI, 0.3), '#e82a2a', { pos: [0, 0.42, 0], rot: [0, PI / 2, 0], scale: 0.12 });
    for (const s of [1, -1]) r.add(geo.cyl(10), '#d8d8e0', { pos: [0, 0.42, s * 0.12], scale: [0.037, 0.06, 0.037] });
    face(r, { at: [0.12, 0.13, 0], size: 0.035, spacing: 0.08, expression: 'determined', mouth: 'smile', skin: '#e8dcf2', blinkBone: 'eyes' });
    return { muzzleY: 0.3 };
  },

  coconutcannon: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.32, '#c8a46a');
    for (let i = 0; i < 6; i++) r.add(geo.leaf(0.5, 0.2), '#4a9a3a', { pos: [0, 0.05, 0], rot: [0, i * 1.05, 1.0], scale: [0.4, 0.4, 0.14], top: '#9ae86a', axis: 'x' });
    r.bone('head', 'body', [0, 0.28, 0]);
    r.add(geo.sphere(16), '#6a4a2a', { scale: [0.22, 0.2, 0.2], top: '#9a7a4a' });
    r.add(geo.lathe('barrel', [[0.6, 0], [0.55, 0.6], [0.7, 0.95], [0.75, 1], [0.6, 1.02]], 14), '#5a3a1a', { pos: [0.1, 0.02, 0], rot: [0, 0, -PI / 2 + 0.15], scale: [0.14, 0.26, 0.14], top: '#8a6a3a' });
    r.add(geo.cyl(12), '#1a0a00', { pos: [0.36, 0.06, 0], rot: [0, 0, -PI / 2 + 0.15], scale: [0.08, 0.01, 0.08], ol: 0 });
    r.add(geo.hemi(), '#c8281a', { pos: [-0.02, 0.1, 0], rot: [0, 0, 0.2], scale: [0.2, 0.11, 0.19], top: '#ff5a3a' });
    r.add(geo.tube('bandknot', [[-0.18, 0.12, 0], [-0.26, 0.08, 0.04], [-0.3, 0.02, 0.06]], 0.02), '#c8281a');
    face(r, { at: [0.12, 0.0, 0.1], size: 0.035, spacing: 0.08, expression: 'smug', mouth: 'grin', skin: '#7a5a3a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.34 };
  },

  chilibean: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.24);
    r.bone('head', 'body', [0, 0.02, 0]);
    r.add(geo.capsule(1.1), '#b81a1a', { pos: [0, 0.2, 0], rot: [0.2, 0, -0.35], scale: [0.2, 0.17, 0.18], top: '#ff5a3a' });
    r.add(geo.tube('beanstem', [[0.02, 0.38, 0], [0.04, 0.44, 0], [0.09, 0.46, 0]], 0.015), '#3e8a2e');
    face(r, { at: [0.15, 0.24, 0], size: 0.04, spacing: 0.09, expression: 'smug', mouth: 'smirk', skin: '#c82a2a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.25 };
  },

  stinkonion: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.26);
    r.bone('head', 'body', [0, 0.02, 0]);
    r.add(geo.lathe('onion2', [[0, 0], [0.7, 0.06], [1, 0.38], [0.75, 0.75], [0.25, 0.92], [0.08, 1.1], [0, 1.15]], 16), '#8a3a8a', { scale: [0.25, 0.48, 0.25], top: '#d88ad8' });
    for (let i = 0; i < 5; i++) r.add(geo.torus(PI, 0.04), '#6a2a6a', { pos: [0, 0.18, 0], rot: [0, (i / 5) * PI, 0], scale: [0.25, 0.2, 0.25] });
    for (let i = 0; i < 3; i++) r.add(geo.tube('stink' + i, [[0, 0, 0], [0.04, 0.06, 0], [-0.02, 0.12, 0], [0.03, 0.18, 0]], 0.012), '#a6d83a', { pos: [-0.1 + i * 0.1, 0.56, (i - 1) * 0.08] });
    face(r, { at: [0.23, 0.22, 0], size: 0.05, spacing: 0.11, expression: 'worried', mouth: 'frown', skin: '#9a4a9a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.3 };
  },

  sniperpea: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    pottedStem(r, 0.5, '#4a6a2a', '#4a6a2a');
    r.bone('head', 'body', [0, 0.56, 0]);
    peaHead(r, { color: '#5a7a3a', light: '#9ab86a', snout: 'barrel', crest: 'none', face: { expression: 'cool', mouth: 'none' } });
    r.on('head');
    r.add(geo.cyl(12), '#2a2a2a', { pos: [0.04, 0.22, 0], rot: [0, 0, -PI / 2], scale: [0.035, 0.2, 0.035] });
    r.add(geo.cyl(12), '#9fdcff', { pos: [0.145, 0.22, 0], rot: [0, 0, -PI / 2], scale: [0.03, 0.01, 0.03], ol: 0 });
    r.add(geo.torus(PI * 2, 0.15), '#3a5a2a', { pos: [0, 0.08, 0], rot: [PI / 2, 0, 0], scale: [0.215, 0.215, 0.1] });
    for (let i = 0; i < 5; i++) r.add(geo.sphere(6), i % 2 ? '#3a4a1a' : '#7a8a3a', { pos: [Math.cos(i * 1.3) * 0.17, 0.05 + (i % 2) * 0.05, Math.sin(i * 1.3) * 0.17], scale: 0.035, ol: 0 });
    return { muzzleY: 0.56 };
  },

  stickysap: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    r.bone('head', 'body', [0, 0, 0]);
    r.add(geo.lathe('sap', [[0, 0.06], [0.6, 0.05], [0.9, 0.03], [1, 0]], 16), '#c8781a', { scale: [0.42, 1, 0.38], top: '#ffb04a' });
    for (let i = 0; i < 5; i++) r.add(geo.hemi(), '#ffc86a', { pos: [Math.cos(i * 1.4) * 0.2, 0.05, Math.sin(i * 1.4) * 0.18], scale: [0.04, 0.03, 0.04], ol: 0 });
    face(r, { at: [0.22, 0.07, 0], size: 0.03, spacing: 0.07, expression: 'happy', mouth: 'tongue', skin: '#e8982a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.1 };
  },

  tanglevine: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.28);
    r.bone('head', 'body', [0, 0, 0]);
    for (let i = 0; i < 3; i++) {
      const a = (i / 3) * PI * 2;
      const pts: [number, number, number][] = [];
      for (let k = 0; k <= 8; k++) pts.push([Math.cos(a + k * 0.8) * 0.12, k * 0.06, Math.sin(a + k * 0.8) * 0.12]);
      r.add(geo.tube('tangle' + i, pts, 0.03, 0.6, 24), '#3a7a2a', { top: '#7ab85a' });
    }
    for (let i = 0; i < 6; i++) r.add(geo.leaf(0.3, 0.2), '#4a9a3a', { pos: [Math.cos(i) * 0.12, 0.1 + i * 0.07, Math.sin(i) * 0.12], rot: [0, -i, 0.6], scale: [0.12, 0.3, 0.07], top: '#8ad86a', axis: 'x' });
    r.add(geo.sphere(14), '#4a8a2a', { pos: [0, 0.52, 0], scale: [0.11, 0.1, 0.11], top: '#8ac86a' });
    face(r, { at: [0.1, 0.53, 0], size: 0.03, spacing: 0.07, expression: 'smug', mouth: 'grin', skin: '#4a8a2a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.5 };
  },

  seedsower: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.28);
    r.bone('head', 'body', [0, 0.02, 0]);
    r.add(geo.lathe('sack', [[0, 0], [0.8, 0.05], [1, 0.4], [0.8, 0.8], [0.45, 0.95], [0.55, 1.05], [0.3, 1.1]], 14), '#c8a46a', { scale: [0.22, 0.42, 0.22], top: '#e8d0a0' });
    r.add(geo.torus(PI * 2, 0.2), '#8a5a2a', { pos: [0, 0.38, 0], rot: [PI / 2, 0, 0], scale: [0.1, 0.1, 0.05] });
    for (let i = 0; i < 4; i++) {
      r.add(geo.cyl(5), '#4a9a3a', { pos: [Math.cos(i * 1.6) * 0.04, 0.5, Math.sin(i * 1.6) * 0.04], rot: [Math.sin(i * 1.6) * 0.3, 0, -Math.cos(i * 1.6) * 0.3], scale: [0.01, 0.1, 0.01] });
      r.add(geo.leaf(0.2, 0.2), '#6ac84a', { pos: [Math.cos(i * 1.6) * 0.06, 0.55, Math.sin(i * 1.6) * 0.06], rot: [0, -i * 1.6, 0.5], scale: [0.08, 0.3, 0.05], top: '#b8f08a', axis: 'x' });
    }
    face(r, { at: [0.21, 0.22, 0], size: 0.045, spacing: 0.1, expression: 'happy', mouth: 'smile', skin: '#d8b47a', blinkBone: 'eyes' });
    return { muzzleY: 0.3 };
  },

  hibiscus: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r);
    leafRing(r, { n: 5, len: 0.3, width: 0.2 });
    stem(r, 0.42);
    r.bone('head', 'body', [0, 0.5, 0], [0, -0.5, 0]);
    petalRing(r, { n: 5, radius: 0.13, len: 0.2, width: 0.17, color: '#ff4a8a', tip: '#ffb0d0', curl: 0.25 });
    r.add(geo.sphere(14), '#ffd8e8', { scale: [0.07, 0.08, 0.08], top: '#ffffff' });
    r.add(geo.tube('stamen', [[0, 0, 0], [0.08, 0.04, 0], [0.16, 0.1, 0]], 0.012), '#ffe36a');
    r.add(geo.sphere(8), '#ff2a5a', { pos: [0.17, 0.11, 0], scale: 0.025 });
    r.add(geo.box(), '#ff2a2a', { pos: [-0.02, 0.12, 0], scale: [0.01, 0.06, 0.02], ol: 0 });
    r.add(geo.box(), '#ff2a2a', { pos: [-0.02, 0.12, 0], scale: [0.01, 0.02, 0.06], ol: 0 });
    face(r, { at: [0.065, -0.01, 0], size: 0.025, spacing: 0.06, expression: 'cute', mouth: 'smile', skin: '#ffd8e8', blinkBone: 'eyes' });
    return { muzzleY: 0.5 };
  },

  sunbean: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.24);
    r.bone('head', 'body', [0, 0.02, 0]);
    r.add(geo.capsule(1.1), '#ffcf1f', { pos: [0, 0.2, 0], rot: [0.2, 0, 0.3], scale: [0.2, 0.17, 0.18], top: '#fff6a0' });
    for (let i = 0; i < 6; i++) r.add(geo.cone(5), '#ffb31f', { pos: [Math.cos(i * 1.05) * 0.2, 0.2, Math.sin(i * 1.05) * 0.2], rot: [Math.sin(i * 1.05) * 1.57, 0, -Math.cos(i * 1.05) * 1.57], scale: [0.025, 0.06, 0.025], ol: 0 });
    face(r, { at: [0.16, 0.22, 0], size: 0.04, spacing: 0.09, expression: 'happy', mouth: 'grin', skin: '#ffd83a', blinkBone: 'eyes' });
    return { muzzleY: 0.25 };
  },

  doomcap: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.3, '#3a2a2a');
    r.bone('head', 'body', [0, 0.01, 0]);
    mushroom(r, { cap: '#2a1a3a', capTop: '#5a3a7a', stalk: '#5a4a5a', h: 0.26, capR: 0.3, spots: '#ff3a5a' });
    r.add(geo.torus(PI * 2, 0.12), '#ff3a5a', { pos: [0, 0.35, 0], rot: [PI / 2, 0, 0], scale: [0.25, 0.25, 0.05], ol: 0 });
    face(r, { at: [0.15, 0.15, 0], size: 0.04, spacing: 0.09, expression: 'fierce', mouth: 'fangs', skin: '#5a4a5a', iris: '#ff2a2a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.3 };
  },

  frostcap: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.24, '#8aa8b8');
    r.bone('head', 'body', [0, 0.01, 0]);
    mushroom(r, { cap: '#5ab8e8', capTop: '#e8faff', stalk: '#e8f4fa', h: 0.2, capR: 0.22, spots: '#ffffff' });
    for (let i = 0; i < 8; i++) {
      const a = (i / 8) * PI * 2;
      r.add(geo.cone(5), '#dff6ff', { pos: [Math.cos(a) * 0.2, 0.2, Math.sin(a) * 0.2], rot: [PI, 0, 0], scale: [0.02, 0.07 + (i % 2) * 0.03, 0.02] });
    }
    face(r, { at: [0.11, 0.11, 0], size: 0.032, spacing: 0.075, expression: 'cool', mouth: 'smirk', skin: '#e8f4fa', iris: '#2a6aa8', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.25 };
  },

  gustfern: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.28);
    r.bone('head', 'body', [0, 0, 0]);
    for (let i = 0; i < 5; i++) {
      const a = (i / 5) * PI * 2;
      const pts: [number, number, number][] = [];
      for (let k = 0; k <= 6; k++) {
        const t = k / 6;
        pts.push([Math.cos(a) * t * 0.3, 0.05 + Math.sin(t * PI * 0.9) * 0.35, Math.sin(a) * t * 0.3]);
      }
      r.add(geo.tube('frond' + i, pts, 0.015), '#3a8a3a');
      for (let k = 1; k < 6; k++) {
        const p = pts[k];
        r.add(geo.leaf(0.2, 0.1), '#5aaa4a', { pos: p, rot: [0, -a + PI / 2, 0.3], scale: [0.07, 0.3, 0.04], top: '#a8e88a', axis: 'x' });
        r.add(geo.leaf(0.2, 0.1), '#5aaa4a', { pos: p, rot: [0, -a - PI / 2, 0.3], scale: [0.07, 0.3, 0.04], top: '#a8e88a', axis: 'x' });
      }
    }
    r.add(geo.sphere(14), '#5aaa4a', { pos: [0, 0.22, 0], scale: [0.1, 0.1, 0.1], top: '#a8e88a' });
    for (const s of [1, -1]) r.add(geo.sphere(8), '#7ac86a', { pos: [0.06, 0.2, s * 0.06], scale: 0.045 });
    face(r, { at: [0.09, 0.23, 0], size: 0.028, spacing: 0.065, expression: 'determined', mouth: 'o', skin: '#5aaa4a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.25 };
  },

  pepperpult: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.3);
    leafRing(r, { n: 5, len: 0.32, color: '#3a8a2a' });
    r.bone('head', 'body', [0, 0.04, 0]);
    r.add(geo.lathe('pbody', [[0, 0], [0.8, 0.1], [1, 0.45], [0.7, 0.85], [0.2, 1]], 14), '#e8581a', { scale: [0.19, 0.4, 0.19], top: '#ffb04a' });
    r.add(geo.lathe('pepcap2', [[0, 0.1], [0.9, 0], [1, 0.3], [0.5, 0.6], [0, 1]], 10), '#3e8a2e', { pos: [0, 0.38, 0], scale: [0.13, 0.08, 0.13] });
    face(r, { at: [0.17, 0.22, 0], size: 0.045, spacing: 0.1, expression: 'fierce', mouth: 'teeth', skin: '#ff6a2a', blinkBone: 'eyes', cheeks: null });
    r.on('head');
    pultArm(r, 0.4, '#3a8a2a', (rr) => rr.add(geo.lathe('mini pepper', [[0, 0], [0.6, 0.2], [0.8, 0.7], [0, 1]], 10), '#e02028', { pos: [-0.24, 0.17, 0], rot: [0, 0, 1.2], scale: [0.04, 0.12, 0.04], top: '#ff8a4a' }));
    return { muzzleY: 0.45 };
  },

  toxicivy: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.26);
    r.bone('head', 'body', [0, 0, 0]);
    r.add(geo.tube('ivystem', [[0, 0, 0], [0.04, 0.15, 0], [-0.03, 0.3, 0], [0, 0.4, 0]], 0.025), '#5a3a6a');
    for (let i = 0; i < 3; i++) {
      const a = (i / 3) * PI * 2 + 0.5;
      r.add(geo.leaf(0.3, 0.35), '#5a9a2a', { pos: [0, 0.4, 0], rot: [0, a, 0.5], scale: [0.26, 0.5, 0.22], top: '#b05ad8', axis: 'x' });
    }
    for (let i = 0; i < 3; i++) r.add(geo.capsule(2), '#a6ff3a', { pos: [Math.cos(i * 2.1) * 0.18, 0.33, Math.sin(i * 2.1) * 0.18], scale: [0.02, 0.04, 0.02], ol: 0 });
    r.add(geo.sphere(12), '#7a4a9a', { pos: [0, 0.44, 0], scale: [0.09, 0.08, 0.09], top: '#c88aff' });
    face(r, { at: [0.08, 0.45, 0], size: 0.025, spacing: 0.06, expression: 'smug', mouth: 'smirk', skin: '#7a4a9a', iris: '#a6ff3a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.44 };
  },

  ricochetradish: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.26);
    r.bone('head', 'body', [0, 0.02, 0]);
    r.add(geo.lathe('radish', [[0, 0], [0.25, 0.1], [0.8, 0.35], [1, 0.6], [0.8, 0.9], [0.3, 1], [0, 1.02]], 16), '#e8283a', { scale: [0.2, 0.36, 0.2], top: '#ff6a7a' });
    r.add(geo.cone(8), '#f2e6e6', { pos: [0, -0.02, 0], rot: [PI, 0, 0], scale: [0.04, 0.08, 0.04] });
    for (let i = 0; i < 4; i++) r.add(geo.leaf(0.4, 0.15), '#3a9a3a', { pos: [0, 0.36, 0], rot: [0, i * 1.6, 1.25], scale: [0.24, 0.35, 0.1], top: '#8adf5a', axis: 'x' });
    r.add(geo.tube('sling', [[0.14, 0.15, 0.08], [0.24, 0.24, 0.05], [0.28, 0.32, 0]], 0.012), '#8a5a2a');
    face(r, { at: [0.19, 0.2, 0], size: 0.045, spacing: 0.1, expression: 'determined', mouth: 'grin', skin: '#ff4a5a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.25 };
  },

  timethyme: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.24);
    for (let i = 0; i < 4; i++) {
      const a = (i / 4) * PI * 2;
      r.add(geo.tube('thyme' + i, [[0, 0, 0], [Math.cos(a) * 0.06, 0.15, Math.sin(a) * 0.06], [Math.cos(a) * 0.1, 0.3, Math.sin(a) * 0.1]], 0.01), '#5a7a3a');
      for (let k = 0; k < 4; k++) r.add(geo.sphere(6), '#7aa85a', { pos: [Math.cos(a) * (0.03 + k * 0.025), 0.06 + k * 0.07, Math.sin(a) * (0.03 + k * 0.025)], scale: [0.02, 0.012, 0.02], ol: 0 });
    }
    r.bone('head', 'body', [0, 0.42, 0], [0, -0.55, 0]);
    r.add(geo.cyl(24), '#c8a838', { rot: [0, 0, -PI / 2], scale: [0.15, 0.05, 0.15], top: '#ffe36a' });
    r.add(geo.cyl(24), '#ffffff', { pos: [0.026, 0, 0], rot: [0, 0, -PI / 2], scale: [0.125, 0.005, 0.125], ol: 0 });
    for (let i = 0; i < 12; i++) r.add(geo.box(), '#2a2a2a', { pos: [0.03, Math.cos((i / 12) * PI * 2) * 0.11, Math.sin((i / 12) * PI * 2) * 0.11], scale: [0.004, 0.012, 0.012], ol: 0 });
    r.bone('spin', 'head', [0.032, 0, 0], [0, 0, 0]);
    r.add(geo.box(), '#c81a1a', { pos: [0, 0.04, 0], scale: [0.004, 0.09, 0.01], ol: 0 });
    r.on('head');
    face(r, { at: [0.03, -0.035, 0], size: 0.02, spacing: 0.06, expression: 'sleepy', mouth: 'smile', skin: '#ffffff', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.42 };
  },

  pineconepitcher: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.3);
    r.bone('head', 'body', [0, 0.02, 0]);
    for (let layer = 0; layer < 4; layer++) {
      r.add(geo.cone(10), layer % 2 ? '#2a6a3a' : '#3a7a4a', { pos: [0, 0.12 + layer * 0.1, 0], scale: [0.22 - layer * 0.045, 0.18, 0.22 - layer * 0.045], top: '#6ab86a' });
    }
    face(r, { at: [0.17, 0.2, 0], size: 0.04, spacing: 0.09, expression: 'happy', mouth: 'grin', skin: '#3a7a4a', blinkBone: 'eyes', cheeks: null });
    r.on('head');
    pultArm(r, 0.42, '#6a4a2a', (rr) => {
      for (let i = 0; i < 4; i++) rr.add(geo.cone(6), '#8a5a2a', { pos: [-0.24, 0.17 + i * 0.025, 0], scale: [0.05 - i * 0.008, 0.04, 0.05 - i * 0.008], top: '#c08a4a' });
    });
    return { muzzleY: 0.5 };
  },

  drumdaisy: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r);
    r.add(geo.cyl(16), '#d8281a', { pos: [0, 0.12, 0], scale: [0.16, 0.16, 0.16], top: '#ff5a3a' });
    r.add(geo.cyl(16), '#f2ead8', { pos: [0, 0.205, 0], scale: [0.165, 0.01, 0.165], ol: 0 });
    stem(r, 0.45, { color: '#3c9d3a' });
    r.bone('head', 'body', [0, 0.52, 0], [0, -0.55, 0]);
    petalRing(r, { n: 12, radius: 0.12, len: 0.13, width: 0.06, color: '#ffffff', tip: '#f2f2ff' });
    r.add(geo.sphere(14), '#ffcf1f', { scale: [0.07, 0.08, 0.08], top: '#fff27a' });
    face(r, { at: [0.065, 0.0, 0], size: 0.025, spacing: 0.06, expression: 'happy', mouth: 'grin', skin: '#ffcf1f', blinkBone: 'eyes', cheeks: null });
    for (const [name, z] of [
      ['armL', 0.06],
      ['armR', -0.06],
    ] as const) {
      r.bone(name, 'body', [0.02, 0.3, z], [0, 0, -0.3]);
      r.add(geo.cyl(6), '#c8a46a', { pos: [0.1, 0, 0], rot: [0, 0, -PI / 2 + 0.6], scale: [0.012, 0.22, 0.012] });
      r.add(geo.sphere(6), '#f2ead8', { pos: [0.2, -0.06, 0], scale: 0.02 });
    }
    return { muzzleY: 0.5 };
  },

  luckyclover: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.24);
    stem(r, 0.3, { color: '#3a8a3a' });
    r.bone('head', 'body', [0, 0.38, 0], [0, -0.6, 0]);
    for (let i = 0; i < 4; i++) {
      const a = (i / 4) * PI * 2 + PI / 4;
      for (const s of [1, -1]) r.add(geo.sphere(12), '#2aa84a', { pos: [0, Math.cos(a) * 0.1 + Math.cos(a + s * 0.5) * 0.03, Math.sin(a) * 0.1 + Math.sin(a + s * 0.5) * 0.03], rot: [a, 0, 0], scale: [0.02, 0.07, 0.065], top: '#8ae88a' });
    }
    r.add(geo.cyl(16), '#ffcf33', { pos: [0.02, 0, 0], rot: [0, 0, -PI / 2], scale: [0.07, 0.03, 0.07], top: '#fff27a' });
    face(r, { at: [0.04, 0.0, 0], size: 0.02, spacing: 0.045, expression: 'happy', mouth: 'smile', skin: '#ffcf33', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.38 };
  },

  dandelion: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.24);
    leafRing(r, { n: 5, len: 0.3, color: '#3a9a3a', curl: 0.2 });
    stem(r, 0.45, { color: '#5a9a4a', radius: 0.025 });
    r.bone('head', 'body', [0, 0.55, 0]);
    r.add(geo.sphere(12), '#c8a85a', { scale: 0.05 });
    for (let i = 0; i < 30; i++) {
      const a = i * 2.39996;
      const y = 1 - (i / 29) * 2;
      const rr = Math.sqrt(Math.max(0, 1 - y * y));
      const dir = new THREE.Vector3(Math.cos(a) * rr, y, Math.sin(a) * rr);
      const e = new THREE.Euler().setFromQuaternion(new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir));
      r.add(geo.cyl(4), '#f2f2f2', { pos: [dir.x * 0.08, dir.y * 0.08, dir.z * 0.08], rot: [e.x, e.y, e.z], scale: [0.004, 0.1, 0.004], ol: 0 });
      r.add(geo.sphere(6), '#ffffff', { pos: [dir.x * 0.14, dir.y * 0.14, dir.z * 0.14], scale: 0.022, ol: 0.3 });
    }
    face(r, { at: [0.045, 0.0, 0], size: 0.02, spacing: 0.045, expression: 'cute', mouth: 'o', skin: '#c8a85a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.55 };
  },
};
