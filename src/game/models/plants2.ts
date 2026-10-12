// Plant character builders for batch 2.
import * as THREE from 'three';
import { face, geo, type Rig } from './kit';
import { leafRing, mound, mushroom, peaHead, petalRing, stem } from './parts';
import type { Builder } from './plants';

const PI = Math.PI;

function spikeBall(r: Rig, n: number, radius: number, color: string, len: number, tip = '#ffffff', center: [number, number, number] = [0, 0, 0], squash = 1) {
  for (let i = 0; i < n; i++) {
    const a = i * 2.39996;
    const y = 1 - (i / (n - 1)) * 2;
    const rr = Math.sqrt(Math.max(0, 1 - y * y));
    const dir = new THREE.Vector3(Math.cos(a) * rr, y * squash, Math.sin(a) * rr).normalize();
    const e = new THREE.Euler().setFromQuaternion(new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir));
    r.add(geo.cone(6), color, { pos: [center[0] + dir.x * radius, center[1] + dir.y * radius, center[2] + dir.z * radius], rot: [e.x, e.y, e.z], scale: [len * 0.3, len, len * 0.3], top: tip });
  }
}

function dragon(r: Rig, scale: string, belly: string, crest: string, fire: boolean) {
  r.bone('body', 'root', [0, 0, 0]);
  mound(r);
  leafRing(r, { n: 4, color: fire ? '#3e8a2e' : '#3a8a7a', tip: fire ? '#7fcf4a' : '#9ae8d8' });
  r.add(geo.tube('dragneck', [[0, 0, 0], [0.06, 0.2, 0], [-0.04, 0.38, 0], [0.02, 0.5, 0]], 0.065, 0.7), scale, { top: belly });
  r.bone('head', 'body', [0.04, 0.55, 0]);
  r.add(geo.sphere(16), scale, { scale: [0.17, 0.14, 0.15], top: belly });
  r.add(geo.capsule(1.4), scale, { pos: [0.14, -0.02, 0], rot: [0, 0, -PI / 2], scale: [0.1, 0.12, 0.11], top: belly });
  for (const s of [1, -1]) r.add(geo.sphere(6), '#1a1a1a', { pos: [0.27, 0.01, s * 0.03], scale: 0.012, ol: 0 });
  if (fire) {
    // flame mane
    for (let i = 0; i < 5; i++) r.add(geo.cone(7), i % 2 ? '#ffb02a' : crest, { pos: [-0.1 + i * 0.025, 0.12 - i * 0.012, (i - 2) * 0.03], rot: [(i - 2) * 0.3, 0, 0.7 + i * 0.1], scale: [0.04, 0.16, 0.04], top: '#fff6b0' });
    for (const s of [1, -1]) r.add(geo.cone(6), '#f2e6c8', { pos: [-0.02, 0.12, s * 0.07], rot: [s * 0.4, 0, 0.5], scale: [0.02, 0.1, 0.02] });
  } else {
    // crystal antlers and an icicle beard
    for (const s of [1, -1]) {
      r.add(geo.cone(5), '#e8faff', { pos: [-0.04, 0.15, s * 0.06], rot: [s * 0.6, 0, 0.3], scale: [0.025, 0.16, 0.025], top: '#ffffff' });
      r.add(geo.cone(5), '#e8faff', { pos: [-0.06, 0.2, s * 0.1], rot: [s * 1.1, 0, 0.1], scale: [0.016, 0.08, 0.016] });
    }
    for (let i = 0; i < 4; i++) r.add(geo.cone(5), '#dff6ff', { pos: [0.12 + i * 0.025, -0.1, (i - 1.5) * 0.03], rot: [PI, 0, 0], scale: [0.015, 0.07 - i * 0.008, 0.015] });
    r.add(geo.sphere(10), '#c8f0ff', { pos: [-0.12, -0.02, 0], scale: [0.06, 0.08, 0.1] });
  }
  r.add(geo.box(), '#3a0d08', { pos: [0.2, -0.07, 0], scale: [0.14, 0.015, 0.1] });
  for (const z of [-0.035, 0.035]) r.add(geo.cone(5), '#ffffff', { pos: [0.24, -0.055, z], rot: [PI, 0, 0], scale: [0.012, 0.03, 0.012] });
  face(r, { at: [0.09, 0.05, 0], size: 0.04, spacing: 0.11, expression: 'fierce', mouth: 'none', skin: scale, iris: fire ? '#ffb02a' : '#7fd4ff', blinkBone: 'eyes', cheeks: null });
  return { muzzleY: 0.55 };
}

export const BUILDERS_B2: Record<string, Builder> = {
  snapjaw: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r);
    leafRing(r, { n: 5, len: 0.34 });
    r.add(geo.tube('jawstem', [[0, 0, 0], [-0.08, 0.2, 0], [0.02, 0.38, 0]], 0.05), '#3c9d3a', { top: '#5fbf4a' });
    r.bone('head', 'body', [0.02, 0.42, 0], [0, 0, -0.2]);
    r.add(geo.hemi(), '#8a2ad8', { pos: [0.08, 0.02, 0], rot: [0, 0, -PI / 2], scale: [0.2, 0.22, 0.19], top: '#c87aff' });
    for (let i = 0; i < 5; i++) r.add(geo.cone(5), '#ffffff', { pos: [0.18, -0.01, -0.12 + i * 0.06], rot: [PI, 0, 0], scale: [0.02, 0.06, 0.02] });
    for (let i = 0; i < 4; i++) r.add(geo.cone(6), '#5a1a8a', { pos: [-0.08, 0.14 + i * 0.02, -0.08 + i * 0.05], rot: [0, 0, 0.8], scale: [0.03, 0.1, 0.03] });
    face(r, { at: [0.12, 0.13, 0], size: 0.04, spacing: 0.13, expression: 'angry', mouth: 'none', skin: '#8a2ad8', iris: '#ffcf33', blinkBone: 'eyes', cheeks: null });
    r.on('head');
    r.bone('jaw', 'head', [-0.06, -0.02, 0]);
    r.add(geo.hemi(), '#7a1ac8', { pos: [0.14, 0, 0], rot: [PI, 0, -PI / 2], scale: [0.2, 0.18, 0.18], top: '#a85ae8' });
    r.add(geo.hemi(), '#ff6a8a', { pos: [0.14, 0.02, 0], rot: [PI, 0, -PI / 2], scale: [0.17, 0.13, 0.15] });
    for (let i = 0; i < 5; i++) r.add(geo.cone(5), '#ffffff', { pos: [0.26, 0.03, -0.12 + i * 0.06], scale: [0.02, 0.06, 0.02] });
    return { muzzleY: 0.42 };
  },

  squashling: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.3);
    r.bone('head', 'body', [0, 0.02, 0]);
    r.add(geo.lathe('squash', [[0, 0], [0.75, 0.06], [1, 0.3], [0.95, 0.55], [0.6, 0.8], [0.5, 0.95], [0.25, 1]], 18), '#6fae2a', { scale: [0.29, 0.5, 0.27], top: '#c8e85a' });
    for (let i = 0; i < 6; i++) r.add(geo.torus(PI, 0.05), '#4a8a1a', { pos: [0, 0.2, 0], rot: [0, (i / 6) * PI, 0], scale: [0.285, 0.2, 0.285] });
    r.add(geo.tube('sqstem', [[0, 0.48, 0], [0.02, 0.56, 0], [-0.03, 0.62, 0]], 0.03), '#5a7a2a');
    face(r, { at: [0.26, 0.26, 0], size: 0.06, spacing: 0.13, expression: 'angry', mouth: 'frown', skin: '#7fbe3a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.3 };
  },

  thornmat: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    r.bone('head', 'body', [0, 0, 0]);
    r.add(geo.lathe('mat', [[0, 0.05], [0.7, 0.04], [1, 0]], 16), '#4a8a2a', { scale: [0.42, 1, 0.38], top: '#7aba4a' });
    for (let i = 0; i < 16; i++) {
      const a = i * 1.7;
      const d = 0.08 + (i % 4) * 0.08;
      r.add(geo.cone(5), '#e8f0d0', { pos: [Math.cos(a) * d, 0.08, Math.sin(a) * d], rot: [Math.sin(a) * 0.3, 0, Math.cos(a) * 0.3], scale: [0.025, 0.11, 0.025], top: '#ffffff' });
    }
    face(r, { at: [0.2, 0.06, 0], size: 0.03, spacing: 0.07, expression: 'smug', mouth: 'smirk', skin: '#5a9a3a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.1 };
  },

  puffcap: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.2);
    r.bone('head', 'body', [0, 0.01, 0]);
    mushroom(r, { cap: '#a85ad8', capTop: '#e0a8ff', stalk: '#f2e6f2', h: 0.13, capR: 0.15, spots: '#ffffff' });
    face(r, { at: [0.08, 0.075, 0], size: 0.028, spacing: 0.058, expression: 'cute', mouth: 'o', skin: '#f2e6f2', blinkBone: 'eyes' });
    return { muzzleY: 0.12 };
  },

  fumecap: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.26);
    r.bone('head', 'body', [0, 0.01, 0]);
    mushroom(r, { cap: '#7a3ab8', capTop: '#c08aff', stalk: '#e8d8f0', h: 0.28, capR: 0.22, spots: '#d8ff7a', flat: 0.65 });
    r.add(geo.lathe('fumenose', [[0.5, 0], [0.35, 0.4], [0.6, 0.85], [0.9, 1], [0.6, 1.02]], 14), '#d8c8e8', { pos: [0.1, 0.17, 0], rot: [0, 0, -PI / 2], scale: [0.08, 0.2, 0.08], top: '#f2eaf8' });
    r.add(geo.cyl(12), '#2a1a3a', { pos: [0.305, 0.17, 0], rot: [0, 0, -PI / 2], scale: [0.06, 0.01, 0.06], ol: 0 });
    face(r, { at: [0.12, 0.27, 0], size: 0.032, spacing: 0.08, expression: 'determined', mouth: 'none', skin: '#e8d8f0', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.2 };
  },

  needlecactus: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.26, '#c8a46a');
    r.bone('head', 'body', [0, 0, 0]);
    r.add(geo.capsule(2.2), '#3a9a5a', { pos: [0, 0.4, 0], scale: [0.2, 0.17, 0.2], top: '#7ad88a' });
    for (const s of [1, -1]) {
      r.add(geo.capsule(1.5), '#3a9a5a', { pos: [0, 0.38, s * 0.16], rot: [s * -0.2, 0, 0], scale: [0.09, 0.1, 0.09], top: '#7ad88a' });
    }
    for (let i = 0; i < 6; i++) r.add(geo.box(), '#2a7a4a', { pos: [Math.cos(i) * 0.098, 0.4, Math.sin(i) * 0.098], rot: [0, -i, 0], scale: [0.005, 0.5, 0.01] });
    for (let i = 0; i < 14; i++) {
      const a = i * 2.2;
      r.add(geo.cone(4), '#ffffff', { pos: [Math.cos(a) * 0.1, 0.25 + (i % 5) * 0.08, Math.sin(a) * 0.1], rot: [Math.sin(a) * 1.4, 0, -Math.cos(a) * 1.4], scale: [0.01, 0.05, 0.01] });
    }
    r.add(geo.sphere(10), '#ff5a8a', { pos: [0, 0.66, 0], scale: [0.06, 0.04, 0.06], top: '#ffb0c8' });
    face(r, { at: [0.095, 0.48, 0], size: 0.035, spacing: 0.075, expression: 'happy', mouth: 'smile', skin: '#3a9a5a', blinkBone: 'eyes' });
    return { muzzleY: 0.48 };
  },

  garlunk: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.26);
    r.bone('head', 'body', [0, 0.02, 0]);
    r.add(geo.lathe('garlic', [[0, 0], [0.6, 0.05], [1, 0.35], [0.85, 0.7], [0.3, 0.92], [0.12, 1.1], [0, 1.15]], 18), '#f2ecd8', { scale: [0.25, 0.45, 0.24], top: '#ffffff' });
    for (let i = 0; i < 6; i++) r.add(geo.torus(PI, 0.04), '#d8c8a8', { pos: [0, 0.16, 0], rot: [0, (i / 6) * PI, 0], scale: [0.25, 0.18, 0.25] });
    for (let i = 0; i < 3; i++) r.add(geo.cyl(5), '#c8b88a', { pos: [(i - 1) * 0.02, -0.01, 0.02 * i], rot: [0.3 * (i - 1), 0, 0.2], scale: [0.006, 0.05, 0.006] });
    face(r, { at: [0.23, 0.2, 0], size: 0.05, spacing: 0.11, expression: 'smug', mouth: 'tongue', skin: '#e8e0c8', blinkBone: 'eyes' });
    return { muzzleY: 0.3 };
  },

  boomerose: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r);
    leafRing(r, { n: 4 });
    stem(r, 0.45);
    for (let i = 0; i < 4; i++) r.add(geo.cone(4), '#2f7a2a', { pos: [0.03 * (i % 2 ? 1 : -1), 0.12 + i * 0.08, 0], rot: [0, 0, (i % 2 ? -1 : 1) * 1.3], scale: [0.012, 0.04, 0.012] });
    r.bone('head', 'body', [0, 0.52, 0], [0, -0.5, 0]);
    petalRing(r, { n: 6, radius: 0.12, len: 0.14, width: 0.12, color: '#e8285a', tip: '#ff8aa8', curl: 0.4 });
    petalRing(r, { n: 5, radius: 0.07, len: 0.1, width: 0.1, color: '#c81a4a', tip: '#ff6a8a', x: 0.03, offset: 0.4, curl: 0.5 });
    r.add(geo.sphere(14), '#e8285a', { scale: [0.1, 0.11, 0.11], top: '#ff7a9a' });
    face(r, { at: [0.09, 0.0, 0], size: 0.03, spacing: 0.07, expression: 'determined', mouth: 'smile', skin: '#e8285a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.52 };
  },

  cabbagelobber: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.3);
    leafRing(r, { n: 5, len: 0.34, color: '#5aaa3a' });
    r.bone('head', 'body', [0, 0.04, 0]);
    r.add(geo.sphere(16), '#8fd85a', { pos: [0, 0.2, 0], scale: [0.2, 0.18, 0.2], top: '#d8f8a8' });
    for (let i = 0; i < 8; i++) {
      const a = (i / 8) * PI * 2;
      r.add(geo.leaf(0.6, 0.3), '#6fc83a', { pos: [Math.cos(a) * 0.06, 0.1, -Math.sin(a) * 0.06], rot: [0, a, 1.1], scale: [0.24, 0.45, 0.2], top: '#c8f08a', axis: 'x' });
    }
    face(r, { at: [0.18, 0.22, 0], size: 0.045, spacing: 0.1, expression: 'happy', mouth: 'grin', skin: '#8fd85a', blinkBone: 'eyes' });
    r.on('head');
    r.bone('arm', 'head', [-0.08, 0.35, 0], [0, 0, 0.6]);
    r.add(geo.tube('cabarm', [[0, 0, 0], [-0.12, 0.1, 0], [-0.22, 0.16, 0]], 0.025), '#4a9a2a');
    r.add(geo.lathe('cbasket', [[0, 0], [0.9, 0.2], [1, 0.7], [0.85, 0.7], [0, 0.35]], 12), '#6aaa3a', { pos: [-0.24, 0.15, 0], scale: [0.09, 0.07, 0.09] });
    r.add(geo.sphere(10), '#8fd85a', { pos: [-0.24, 0.21, 0], scale: 0.07, top: '#d8f8a8' });
    return { muzzleY: 0.5 };
  },

  hexnut: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    r.bone('head', 'body', [0, 0.02, 0]);
    r.add(geo.cyl(6), '#5a3a8a', { pos: [0, 0.34, 0], rot: [0, 0, PI / 2], scale: [0.32, 0.34, 0.32], top: '#9a6ad8' });
    r.add(geo.cyl(6), '#c8a8ff', { pos: [0, 0.34, 0], rot: [0, 0, PI / 2], scale: [0.2, 0.36, 0.2], ol: 0.2 });
    r.add(geo.cyl(12), '#2a1a4a', { pos: [0, 0.34, 0], rot: [0, 0, PI / 2], scale: [0.09, 0.37, 0.09], ol: 0 });
    for (let i = 0; i < 6; i++) {
      const a = (i / 6) * PI * 2 + PI / 6;
      r.add(geo.sphere(6), '#7affe8', { pos: [0.17, 0.34 + Math.cos(a) * 0.27, Math.sin(a) * 0.27], scale: 0.025, ol: 0 });
    }
    face(r, { at: [0.18, 0.4, 0], size: 0.05, spacing: 0.13, expression: 'cool', mouth: 'smirk', skin: '#7a5ab8', iris: '#7affe8', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.35 };
  },

  spikydurian: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    r.bone('head', 'body', [0, 0.02, 0]);
    r.add(geo.sphere(18), '#9aaa3a', { pos: [0, 0.32, 0], scale: [0.3, 0.32, 0.29], top: '#d8e86a' });
    spikeBall(r, 26, 0.29, '#7a8a2a', 0.1, '#e8f08a', [0, 0.32, 0], 1.05);
    r.add(geo.tube('durstem', [[0, 0.6, 0], [0.02, 0.68, 0], [0.06, 0.72, 0]], 0.025), '#6a5a2a');
    face(r, { at: [0.29, 0.34, 0], size: 0.06, spacing: 0.14, expression: 'fierce', mouth: 'fangs', skin: '#aabb4a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.35 };
  },

  leafguard: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.3);
    r.bone('head', 'body', [0, 0.02, 0]);
    r.add(geo.capsule(1.6), '#e83a6a', { pos: [0, 0.32, 0], scale: [0.15, 0.17, 0.14], top: '#ff8aa8' });
    for (let i = 0; i < 3; i++) {
      const a = -0.8 + i * 0.8;
      r.add(geo.leaf(0.5, 0.35), '#3a9a3a', { pos: [-0.04, 0.2 + i * 0.12, 0], rot: [a, PI, 0.9], scale: [0.4, 0.5, 0.32], top: '#9ae86a', axis: 'x' });
    }
    for (let i = 0; i < 3; i++) r.add(geo.box(), '#c81a4a', { pos: [0.13, 0.15 + i * 0.12, 0], scale: [0.01, 0.08, 0.01] });
    face(r, { at: [0.15, 0.4, 0], size: 0.045, spacing: 0.1, expression: 'determined', mouth: 'grin', skin: '#ff6a8a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.35 };
  },

  pumpkinshell: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    r.bone('head', 'body', [0, 0, 0]);
    // A hollow ring of fat ribs: taller at the back, low at the front so the plant inside shows.
    for (let i = 0; i < 12; i++) {
      const a = (i / 12) * PI * 2;
      const front = (Math.cos(a) + 1) / 2; // 1 = facing zombies/camera side
      const h = 0.44 - front * 0.2;
      r.add(geo.sphere(14), i % 2 ? '#ff8a1f' : '#f07a12', { pos: [Math.cos(a) * 0.27, h * 0.5, Math.sin(a) * 0.27], rot: [0, -a, 0], scale: [0.11, h * 0.55, 0.13], top: '#ffb04a' });
    }
    r.add(geo.tube('pumpstem', [[-0.3, 0.42, 0], [-0.32, 0.5, 0], [-0.28, 0.56, 0]], 0.03), '#5a7a2a');
    r.add(geo.leaf(0.3, 0.1), '#4f9f3e', { pos: [-0.3, 0.52, 0], rot: [0, 1, 0.3], scale: [0.16, 0.3, 0.1], top: '#7fcf5a', axis: 'x' });
    face(r, { at: [-0.06, 0.36, 0.33], size: 0.04, spacing: 0.08, expression: 'happy', mouth: 'grin', skin: '#ff8a1f', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.3 };
  },

  boomnut: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    r.bone('head', 'body', [0, 0.02, 0]);
    r.add(geo.lathe('bnut', [[0, 0], [0.55, 0.04], [0.92, 0.28], [1, 0.52], [0.9, 0.8], [0.55, 0.98], [0, 1.02]], 20), '#c8281a', { scale: [0.33, 0.6, 0.31], top: '#ff6a3a' });
    for (let i = 0; i < 7; i++) {
      const a = i * 2.1;
      r.add(geo.sphere(8), '#8a1a10', { pos: [Math.cos(a) * 0.3, 0.12 + (i % 3) * 0.14, Math.sin(a) * 0.29], scale: [0.03, 0.04, 0.03] });
    }
    r.add(geo.tube('fuse', [[0, 0.6, 0], [-0.04, 0.68, 0], [0.02, 0.74, 0]], 0.015), '#3a2a1a');
    r.bone('light', 'head', [0.02, 0.76, 0]);
    r.add(geo.sphere(8), '#ffe36a', { scale: 0.04, top: '#ffffff', ol: 0 });
    r.on('head');
    face(r, { at: [0.31, 0.35, 0], size: 0.065, spacing: 0.14, expression: 'crazy', mouth: 'grin', skin: '#d8382a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.35 };
  },

  goldenbud: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.24);
    leafRing(r, { n: 4, color: '#8a9a2a', tip: '#e8e86a' });
    stem(r, 0.3, { color: '#8a9a2a' });
    r.bone('head', 'body', [0, 0.38, 0]);
    for (let i = 0; i < 6; i++) {
      const a = (i / 6) * PI * 2;
      r.add(geo.leaf(-0.3, 0.3), '#ffcf1f', { pos: [Math.cos(a) * 0.03, -0.02, -Math.sin(a) * 0.03], rot: [0, a, 1.15], scale: [0.24, 0.45, 0.16], top: '#fff6b0', axis: 'x' });
    }
    r.add(geo.sphere(14), '#ffd84a', { pos: [0, 0.1, 0], scale: [0.12, 0.14, 0.12], top: '#fffbe0' });
    face(r, { at: [0.11, 0.1, 0], size: 0.035, spacing: 0.075, expression: 'happy', mouth: 'grin', skin: '#ffd84a', blinkBone: 'eyes' });
    return { muzzleY: 0.45 };
  },

  vigorlily: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.24);
    leafRing(r, { n: 3, len: 0.36, width: 0.22, color: '#3aaa6a', tip: '#8ae8aa' });
    stem(r, 0.32, { color: '#3aaa6a' });
    r.bone('head', 'body', [0, 0.38, 0]);
    for (let i = 0; i < 6; i++) {
      const a = (i / 6) * PI * 2;
      r.add(geo.leaf(0.45, 0.25), i % 2 ? '#ffffff' : '#ffd0e8', { pos: [0, 0, 0], rot: [0, a, 0.9], scale: [0.22, 0.4, 0.13], top: '#ff7ab8', axis: 'x' });
    }
    r.add(geo.sphere(12), '#5aff7a', { pos: [0, 0.08, 0], scale: 0.07, top: '#c8ffc8' });
    face(r, { at: [0.065, 0.08, 0], size: 0.022, spacing: 0.05, expression: 'cute', mouth: 'smile', skin: '#5aff7a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.45 };
  },

  flamedragon: (r) => dragon(r, '#e8381a', '#ffb04a', '#ffe36a', true),
  frostdragon: (r) => dragon(r, '#3a8ac8', '#c8f0ff', '#ffffff', false),

  grapeburst: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.24);
    r.bone('head', 'body', [0, 0, 0]);
    const pts: [number, number, number][] = [];
    for (let layer = 0; layer < 4; layer++) {
      const n = 6 - layer;
      for (let i = 0; i < n; i++) {
        const a = (i / n) * PI * 2 + layer * 0.5;
        pts.push([Math.cos(a) * (0.17 - layer * 0.035), 0.12 + layer * 0.1, Math.sin(a) * (0.17 - layer * 0.035)]);
      }
    }
    for (const p of pts) r.add(geo.sphere(10), '#7a2ac8', { pos: p, scale: 0.075, top: '#c88aff' });
    r.add(geo.tube('grapestem', [[0, 0.42, 0], [0.02, 0.5, 0], [-0.02, 0.56, 0]], 0.02), '#5a7a2a');
    r.add(geo.leaf(0.3, 0.15), '#4f9f3e', { pos: [0, 0.5, 0], rot: [0, 0.6, 0.4], scale: [0.18, 0.4, 0.12], top: '#8fdf5a', axis: 'x' });
    face(r, { at: [0.2, 0.2, 0], size: 0.045, spacing: 0.1, expression: 'crazy', mouth: 'grin', skin: '#8a3ad8', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.3 };
  },

  magmaguava: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.26, '#3a2a2a');
    r.bone('head', 'body', [0, 0, 0]);
    r.add(geo.sphere(18), '#3a3a2a', { pos: [0, 0.24, 0], scale: [0.24, 0.22, 0.23], top: '#6a6a4a' });
    for (let i = 0; i < 9; i++) {
      const a = i * 0.9;
      r.add(geo.box(), '#ff6a1f', { pos: [Math.cos(a) * 0.22, 0.16 + (i % 3) * 0.08, Math.sin(a) * 0.21], rot: [0, -a, 0.6 * (i % 2 ? 1 : -1)], scale: [0.012, 0.1, 0.02], ol: 0 });
    }
    r.add(geo.hemi(), '#ff8a1f', { pos: [0, 0.4, 0], scale: [0.12, 0.06, 0.12], top: '#ffe36a', ol: 0 });
    face(r, { at: [0.22, 0.25, 0], size: 0.05, spacing: 0.11, expression: 'angry', mouth: 'teeth', skin: '#4a4a3a', iris: '#ff5a1f', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.3 };
  },

  wasabilash: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.28);
    r.bone('head', 'body', [0, 0, 0]);
    r.add(geo.lathe('wasabi', [[0, 0], [0.8, 0.05], [1, 0.3], [0.75, 0.75], [0.4, 1]], 14), '#9ae84a', { scale: [0.18, 0.42, 0.18], top: '#d8ff9a' });
    for (let i = 0; i < 6; i++) r.add(geo.torus(PI * 2, 0.08), '#7ac83a', { pos: [0, 0.06 + i * 0.06, 0], rot: [PI / 2, 0, 0], scale: [0.16 - i * 0.015, 0.16 - i * 0.015, 0.05] });
    for (let i = 0; i < 4; i++) r.add(geo.leaf(0.4, 0.2), '#3a9a3a', { pos: [0, 0.4, 0], rot: [0, i * 1.6, 1.1], scale: [0.22, 0.4, 0.15], top: '#8fdf5a', axis: 'x' });
    face(r, { at: [0.15, 0.24, 0], size: 0.04, spacing: 0.09, expression: 'fierce', mouth: 'grin', skin: '#9ae84a', blinkBone: 'eyes', cheeks: null });
    for (const [name, z] of [
      ['armL', 0.15],
      ['armR', -0.15],
    ] as const) {
      r.bone(name, 'head', [0, 0.28, z], [0, 0, -0.3]);
      r.add(geo.tube('whip', [[0, 0, 0], [0.1, 0.1, 0], [0.2, 0.05, 0], [0.28, 0.12, 0]], 0.018, 0.4), '#5aaa2a');
      r.on('head');
    }
    return { muzzleY: 0.3 };
  },

  pokeokra: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.26);
    leafRing(r, { n: 4, len: 0.28 });
    r.bone('head', 'body', [0, 0.04, 0]);
    r.add(geo.lathe('okra', [[0, 0], [0.8, 0.1], [1, 0.4], [0.7, 0.8], [0.2, 1.0], [0, 1.05]], 10), '#4a9a3a', { pos: [0, 0.02, 0], scale: [0.14, 0.55, 0.14], top: '#9ad86a' });
    face(r, { at: [0.13, 0.28, 0], size: 0.04, spacing: 0.085, expression: 'determined', mouth: 'smirk', skin: '#5aaa4a', blinkBone: 'eyes', cheeks: null });
    r.bone('armL', 'head', [0.05, 0.22, 0.12], [0, 0, -0.3]);
    r.add(geo.lathe('okraspear', [[0, 0], [0.8, 0.1], [1, 0.3], [0.5, 0.85], [0, 1]], 8), '#3a8a2a', { rot: [0, 0, -PI / 2], scale: [0.04, 0.24, 0.04], top: '#7ac85a' });
    return { muzzleY: 0.3 };
  },

  stormberry: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.24);
    leafRing(r, { n: 4, len: 0.26 });
    stem(r, 0.25);
    r.bone('head', 'body', [0, 0.38, 0]);
    r.add(geo.sphere(18), '#3a4ac8', { scale: 0.16, top: '#8a9aff' });
    r.add(geo.star(5, 0.5), '#2a2a7a', { pos: [0, 0.15, 0], rot: [PI / 2, 0, 0], scale: [0.05, 0.05, 0.02] });
    r.bone('spin', 'head', [0, 0.36, 0]);
    for (let i = 0; i < 5; i++) {
      const a = (i / 5) * PI * 2;
      r.add(geo.sphere(10), '#c8d0e0', { pos: [Math.cos(a) * 0.1, (i % 2) * 0.03, Math.sin(a) * 0.1], scale: [0.09, 0.06, 0.08], top: '#ffffff' });
    }
    r.add(geo.cone(4), '#ffe36a', { pos: [0.05, -0.1, 0], rot: [0, 0, 0.4], scale: [0.02, 0.12, 0.02], ol: 0 });
    r.on('head');
    face(r, { at: [0.14, 0.02, 0], size: 0.04, spacing: 0.09, expression: 'worried', mouth: 'o', skin: '#3a4ac8', iris: '#ffe36a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.4 };
  },

  plasmacitrus: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r);
    leafRing(r, { n: 4, color: '#4a8a5a' });
    stem(r, 0.3, { color: '#5a6a7a' });
    r.bone('head', 'body', [0, 0.44, 0]);
    r.add(geo.sphere(18), '#ffb01f', { scale: [0.2, 0.19, 0.19], top: '#ffe36a' });
    r.add(geo.torus(PI * 2, 0.12), '#6a7a8a', { rot: [PI / 2, 0, 0], scale: [0.21, 0.21, 0.1] });
    r.add(geo.cyl(16), '#8a9aaa', { pos: [0.18, 0, 0], rot: [0, 0, -PI / 2], scale: [0.11, 0.08, 0.11], top: '#c8d8e8' });
    r.add(geo.cyl(16), '#c8ff3a', { pos: [0.225, 0, 0], rot: [0, 0, -PI / 2], scale: [0.08, 0.01, 0.08], ol: 0 });
    for (const s of [1, -1]) r.add(geo.cone(6), '#8a9aaa', { pos: [-0.05, 0.17, s * 0.08], rot: [s * 0.4, 0, 0.3], scale: [0.03, 0.09, 0.03] });
    face(r, { at: [0.13, 0.11, 0], size: 0.035, spacing: 0.13, expression: 'determined', mouth: 'none', skin: '#ffb01f', iris: '#3a8a2a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.44 };
  },

  hexhazel: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r);
    leafRing(r, { n: 5, color: '#5a3a8a', tip: '#9a7ad8' });
    stem(r, 0.32, { color: '#5a4a3a' });
    r.bone('head', 'body', [0, 0.44, 0]);
    petalRing(r, { n: 8, radius: 0.1, len: 0.12, width: 0.04, color: '#ffcf33', tip: '#fff27a', x: -0.02 });
    r.add(geo.sphere(16), '#d88aff', { scale: [0.12, 0.13, 0.12], top: '#f0c8ff' });
    r.add(geo.cyl(16), '#2a1a4a', { pos: [0, 0.1, 0], scale: [0.18, 0.015, 0.18] });
    r.add(geo.cone(12), '#2a1a4a', { pos: [-0.02, 0.24, 0], rot: [0, 0, 0.25], scale: [0.1, 0.28, 0.1], top: '#5a3a8a' });
    r.add(geo.cyl(12), '#ffcf33', { pos: [0, 0.13, 0], scale: [0.095, 0.02, 0.095], ol: 0 });
    r.add(geo.star(5, 0.45), '#ffe36a', { pos: [0.06, 0.2, 0.03], rot: [0, PI / 2, 0], scale: [0.03, 0.03, 0.01], ol: 0 });
    face(r, { at: [0.1, 0.0, 0], size: 0.032, spacing: 0.08, expression: 'smug', mouth: 'smirk', skin: '#d88aff', iris: '#3aaa5a', blinkBone: 'eyes' });
    return { muzzleY: 0.44 };
  },
};

// Silence unused-import lint for helpers reserved for future builders.
void peaHead;
