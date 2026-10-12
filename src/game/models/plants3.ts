// Plant character builders for batch 3.
import { face, geo, type Rig } from './kit';
import { leafRing, mound, mushroom, peaHead, petalRing, pottedStem, stem } from './parts';
import type { Builder } from './plants';

const PI = Math.PI;

function lobArm(r: Rig, parent: string, y: number, armColor: string, ammo: string, ammoTop: string) {
  r.bone('arm', parent, [-0.08, y, 0], [0, 0, 0.6]);
  r.add(geo.tube('arm3:' + armColor, [[0, 0, 0], [-0.12, 0.1, 0], [-0.22, 0.16, 0]], 0.025), armColor);
  r.add(geo.lathe('basket3', [[0, 0], [0.9, 0.2], [1, 0.7], [0.85, 0.7], [0, 0.35]], 12), armColor, { pos: [-0.24, 0.15, 0], scale: [0.09, 0.07, 0.09] });
  r.add(geo.sphere(10), ammo, { pos: [-0.24, 0.21, 0], scale: 0.07, top: ammoTop });
}

export const BUILDERS_B3: Record<string, Builder> = {
  rockpea: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.3, '#6a5a4a');
    leafRing(r, { n: 4, color: '#5a7a2a', tip: '#9aaa5a' });
    stem(r, 0.48, { color: '#5a7a3a' });
    r.bone('head', 'body', [0, 0.54, 0]);
    peaHead(r, { color: '#7a9a4a', light: '#b8c87a', snout: 'wide', crest: 'none', face: { expression: 'fierce', iris: '#5a3a1a' } });
    r.on('head');
    for (let i = 0; i < 6; i++) r.add(geo.capsule(2), '#3a2a1a', { pos: [-0.1 + i * 0.03, 0.2, (i - 2.5) * 0.04], rot: [(i - 2.5) * 0.25, 0, 0.5], scale: [0.03, 0.06, 0.03] });
    r.add(geo.capsule(3), '#f2ead8', { pos: [-0.02, 0.24, 0], rot: [PI / 2, 0, 0], scale: [0.02, 0.05, 0.02] });
    for (const z of [-0.06, 0.06]) r.add(geo.sphere(8), '#f2ead8', { pos: [-0.02, 0.24, z * 1.6], scale: 0.025 });
    return { muzzleY: 0.54 };
  },

  shadepea: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    pottedStem(r, 0.5, '#4a2a6a', '#3a2a5a');
    r.bone('head', 'body', [0, 0.56, 0]);
    peaHead(r, { color: '#4a2a7a', light: '#8a5ac8', rim: '#b04fff', crest: 'none', face: { expression: 'angry', iris: '#ff4aff' } });
    r.on('head');
    for (let i = 0; i < 4; i++) r.add(geo.cone(7), '#2a1a4a', { pos: [-0.14, 0.12 + i * 0.03, (i - 1.5) * 0.06], rot: [(i - 1.5) * 0.3, 0, 1.1], scale: [0.05, 0.18, 0.05], top: '#9a5ad8' });
    return { muzzleY: 0.56 };
  },

  ancientflower: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.3, '#6a5a4a');
    for (let i = 0; i < 5; i++) {
      const a = (i / 5) * PI * 2;
      r.add(geo.leaf(0.2, 0.1, 1.4), '#4a7a2a', { pos: [0, 0.05, 0], rot: [0, a, 0.3], scale: [0.36, 0.3, 0.12], top: '#8aaa4a', axis: 'x' });
    }
    stem(r, 0.6, { color: '#5a6a2a', radius: 0.06 });
    r.bone('head', 'body', [0, 0.68, 0], [0, -0.55, 0]);
    r.bone('petals', 'head', [0, 0, 0]);
    petalRing(r, { n: 10, radius: 0.2, len: 0.2, width: 0.11, color: '#e86a1a', tip: '#ffb02a', x: -0.01, curl: 0.05 });
    petalRing(r, { n: 10, radius: 0.16, len: 0.14, width: 0.09, color: '#c84a12', tip: '#ff8a2a', x: -0.03, offset: 0.3 });
    r.on('head');
    r.add(geo.lathe('afdisk', [[0, -0.6], [0.8, -0.5], [1, 0], [0.8, 0.5], [0, 0.6]], 18), '#6a3a12', { rot: [0, 0, -PI / 2], scale: [0.2, 0.13, 0.2], top: '#4a2a0a' });
    r.add(geo.cyl(18), '#ffb02a', { pos: [0.08, 0, 0], rot: [0, 0, -PI / 2], scale: [0.16, 0.01, 0.16] });
    face(r, { at: [0.085, 0.02, 0], size: 0.05, spacing: 0.11, expression: 'determined', mouth: 'grin', skin: '#ffb02a', blinkBone: 'eyes' });
    return { muzzleY: 0.68 };
  },

  moonblossom: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r);
    leafRing(r, { n: 4, color: '#3a7a8a', tip: '#8ad8e8' });
    stem(r, 0.45, { color: '#3a7a7a' });
    r.bone('head', 'body', [0, 0.52, 0], [0, -0.5, 0]);
    r.bone('petals', 'head', [0, 0, 0]);
    petalRing(r, { n: 8, radius: 0.13, len: 0.15, width: 0.1, color: '#c8d8ff', tip: '#ffffff', curl: 0.3 });
    r.on('head');
    r.add(geo.sphere(14), '#e8f0ff', { scale: [0.1, 0.12, 0.12], top: '#ffffff' });
    r.add(geo.torus(PI * 1.3, 0.3), '#ffe36a', { pos: [-0.02, 0.18, 0], rot: [0, PI / 2, 0.6], scale: 0.07, ol: 0.5 });
    face(r, { at: [0.09, 0.0, 0], size: 0.03, spacing: 0.075, expression: 'sleepy', mouth: 'smile', skin: '#e8f0ff', blinkBone: 'eyes' });
    return { muzzleY: 0.52 };
  },

  sunmint: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.24);
    r.bone('head', 'body', [0, 0, 0]);
    for (let layer = 0; layer < 3; layer++) {
      for (let i = 0; i < 4; i++) {
        const a = (i / 4) * PI * 2 + layer * 0.8;
        r.add(geo.leaf(0.3, 0.3), '#4ad87a', { pos: [0, 0.08 + layer * 0.12, 0], rot: [0, a, 0.7 - layer * 0.15], scale: [0.22 - layer * 0.04, 0.4, 0.13], top: '#c8ffd8', axis: 'x' });
      }
    }
    r.add(geo.sphere(14), '#ffd23f', { pos: [0, 0.48, 0], scale: 0.09, top: '#fff6b0' });
    for (let i = 0; i < 8; i++) r.add(geo.cone(5), '#ffb31f', { pos: [Math.cos(i * 0.785) * 0.12, 0.48, Math.sin(i * 0.785) * 0.12], rot: [Math.sin(i * 0.785) * 1.57, 0, -Math.cos(i * 0.785) * 1.57], scale: [0.02, 0.05, 0.02], ol: 0 });
    face(r, { at: [0.085, 0.49, 0], size: 0.025, spacing: 0.055, expression: 'happy', mouth: 'grin', skin: '#ffd23f', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.4 };
  },

  stonemine: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.32, '#6a5a4a');
    r.bone('head', 'body', [0, 0, 0]);
    r.add(geo.dodec(), '#8a8070', { pos: [0, 0.14, 0], scale: [0.22, 0.15, 0.2], top: '#b8b0a0' });
    r.add(geo.hemi(), '#5a8a3a', { pos: [-0.05, 0.24, 0.03], scale: [0.1, 0.03, 0.08], ol: 0 });
    face(r, { at: [0.2, 0.16, 0], size: 0.04, spacing: 0.09, expression: 'determined', mouth: 'teeth', skin: '#8a8070', blinkBone: 'eyes', cheeks: null });
    r.on('head');
    r.add(geo.capsule(3), '#f2ead8', { pos: [0, 0.34, 0], rot: [0, 0, 0.2], scale: [0.025, 0.04, 0.025] });
    r.bone('light', 'head', [0.02, 0.45, 0]);
    r.add(geo.sphere(8), '#ff5a2a', { scale: 0.035, top: '#ffd0a0', ol: 0 });
    return { muzzleY: 0.2 };
  },

  bouldernut: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    r.bone('head', 'body', [0, 0.02, 0]);
    r.add(geo.dodec(), '#7a7468', { pos: [0, 0.33, 0], scale: [0.33, 0.33, 0.31], top: '#b0a898' });
    r.add(geo.dodec(), '#6a6458', { pos: [-0.05, 0.12, 0.1], scale: [0.16, 0.12, 0.14] });
    for (let i = 0; i < 4; i++) r.add(geo.box(), '#3a362e', { pos: [0.25, 0.25 + i * 0.08, -0.15 + i * 0.1], rot: [0.5 * i, 0, 0.3], scale: [0.01, 0.1, 0.01], ol: 0 });
    r.add(geo.hemi(), '#4a8a2a', { pos: [-0.05, 0.6, 0], scale: [0.18, 0.06, 0.15], top: '#8acc5a' });
    face(r, { at: [0.3, 0.36, 0], size: 0.065, spacing: 0.15, expression: 'determined', mouth: 'frown', skin: '#8a8478', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.35 };
  },

  pomegrenade: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.3);
    leafRing(r, { n: 5, len: 0.32 });
    r.bone('head', 'body', [0, 0.04, 0]);
    r.add(geo.sphere(18), '#b8142a', { pos: [0, 0.24, 0], scale: [0.22, 0.2, 0.21], top: '#ff4a5a' });
    for (let i = 0; i < 6; i++) r.add(geo.cone(4), '#8a0a1a', { pos: [Math.cos(i) * 0.04, 0.47, Math.sin(i) * 0.04], rot: [Math.sin(i) * 0.5, 0, -Math.cos(i) * 0.5], scale: [0.025, 0.07, 0.025] });
    r.add(geo.torus(PI * 2, 0.15), '#c8c8c8', { pos: [-0.12, 0.38, 0.08], rot: [0.4, 0, 0.5], scale: 0.05 });
    face(r, { at: [0.21, 0.26, 0], size: 0.05, spacing: 0.11, expression: 'crazy', mouth: 'grin', skin: '#c81a2a', blinkBone: 'eyes', cheeks: null });
    r.on('head');
    lobArm(r, 'head', 0.4, '#4a8a2a', '#b8142a', '#ff6a6a');
    return { muzzleY: 0.5 };
  },

  firecrackerfig: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.25);
    r.bone('head', 'body', [0, 0, 0]);
    r.add(geo.lathe('fig', [[0, 0], [0.75, 0.08], [1, 0.4], [0.75, 0.75], [0.3, 0.95], [0, 1]], 16), '#6a2a6a', { scale: [0.22, 0.42, 0.22], top: '#c86ac8' });
    for (let i = 0; i < 5; i++) r.add(geo.box(), '#ffcf33', { pos: [0, 0.18, 0], rot: [0, (i / 5) * PI, 0], scale: [0.005, 0.32, 0.44], ol: 0 });
    r.add(geo.tube('figfuse', [[0, 0.4, 0], [0.04, 0.48, 0], [-0.02, 0.55, 0]], 0.015), '#3a2a1a');
    r.bone('light', 'head', [-0.02, 0.57, 0]);
    r.add(geo.star(5, 0.4), '#ffe36a', { scale: [0.04, 0.04, 0.02], ol: 0 });
    r.on('head');
    face(r, { at: [0.21, 0.2, 0], size: 0.045, spacing: 0.1, expression: 'smug', mouth: 'smirk', skin: '#8a3a8a', blinkBone: 'eyes' });
    return { muzzleY: 0.25 };
  },

  torchvine: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.3);
    r.bone('head', 'body', [0, 0, 0]);
    r.add(geo.lathe('stump', [[0.9, 0], [1, 0.1], [0.85, 0.5], [0.9, 0.95], [0.8, 1]], 14), '#7a4a2a', { scale: [0.22, 0.45, 0.22], top: '#a87a4a' });
    r.add(geo.cyl(14), '#c89a6a', { pos: [0, 0.45, 0], scale: [0.18, 0.01, 0.18], ol: 0 });
    for (let i = 0; i < 4; i++) r.add(geo.tube('vine' + i, [[0, 0.05, 0], [0.1, 0.2, 0.15], [0.05, 0.35, 0.18]], 0.012), '#3a8a2a', { rot: [0, i * 1.57, 0] });
    r.bone('spin', 'head', [0, 0.45, 0]);
    for (let i = 0; i < 6; i++) {
      const a = (i / 6) * PI * 2;
      r.add(geo.cone(7), i % 2 ? '#ffb02a' : '#ff5a1a', { pos: [Math.cos(a) * 0.08, 0.1, Math.sin(a) * 0.08], rot: [Math.sin(a) * 0.3, 0, -Math.cos(a) * 0.3], scale: [0.07, 0.22, 0.07], top: '#fff6b0', ol: 0 });
    }
    r.add(geo.cone(8), '#ffe36a', { pos: [0, 0.14, 0], scale: [0.07, 0.3, 0.07], top: '#ffffff', ol: 0 });
    r.on('head');
    face(r, { at: [0.21, 0.28, 0], size: 0.045, spacing: 0.1, expression: 'determined', mouth: 'grin', skin: '#8a5a3a', iris: '#ff7a1f', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.3 };
  },

  shockcurrant: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    r.bone('head', 'body', [0, 0, 0]);
    r.add(geo.lathe('cmat', [[0, 0.04], [0.8, 0.03], [1, 0]], 14), '#3a6a3a', { scale: [0.3, 1, 0.28] });
    const spots: [number, number, number][] = [
      [0.06, 0.07, 0.05],
      [-0.07, 0.07, -0.04],
      [0.0, 0.08, -0.12],
      [-0.1, 0.06, 0.1],
      [0.12, 0.06, -0.08],
    ];
    for (const p of spots) r.add(geo.sphere(10), '#c81a6a', { pos: p, scale: 0.06, top: '#ff7ac8' });
    for (let i = 0; i < 3; i++) r.add(geo.cone(4), '#ffe36a', { pos: [Math.cos(i * 2) * 0.14, 0.12, Math.sin(i * 2) * 0.14], rot: [0, 0, 0.5], scale: [0.012, 0.08, 0.012], ol: 0 });
    face(r, { at: [0.11, 0.09, 0.05], size: 0.022, spacing: 0.045, expression: 'crazy', mouth: 'grin', skin: '#c81a6a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.1 };
  },

  volttea: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.26);
    leafRing(r, { n: 4, len: 0.26, color: '#3a8a3a' });
    r.bone('head', 'body', [0, 0.02, 0]);
    r.add(geo.lathe('teapot', [[0, 0], [0.7, 0.04], [1, 0.4], [0.85, 0.85], [0.4, 1], [0, 1.02]], 16), '#5ab84a', { scale: [0.2, 0.38, 0.2], top: '#b8f08a' });
    r.add(geo.tube('spout', [[0.15, 0.12, 0], [0.24, 0.2, 0], [0.3, 0.3, 0]], 0.03, 0.6), '#5ab84a');
    r.add(geo.torus(PI, 0.2), '#4a9a3a', { pos: [-0.2, 0.2, 0], rot: [0, 0, PI / 2], scale: 0.08 });
    r.bone('spin', 'head', [0, 0.42, 0]);
    r.add(geo.cone(4), '#ffe36a', { rot: [0, 0, 0.3], scale: [0.04, 0.14, 0.04], top: '#ffffff', ol: 0 });
    r.add(geo.cone(4), '#ffe36a', { pos: [0.02, -0.08, 0], rot: [PI, 0, 0.3], scale: [0.03, 0.1, 0.03], ol: 0 });
    r.on('head');
    face(r, { at: [0.19, 0.2, 0], size: 0.045, spacing: 0.1, expression: 'crazy', mouth: 'teeth', skin: '#5ab84a', iris: '#ffcf1f', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.3 };
  },

  sunlens: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.26);
    for (let i = 0; i < 7; i++) r.add(geo.leaf(0.9, 0.05, 1.5), '#5aaa3a', { pos: [0, 0.02, 0], rot: [0, i * 0.9, 1.25], scale: [0.36, 0.25, 0.05], top: '#b8e86a', axis: 'x' });
    stem(r, 0.6, { color: '#6a5a3a', radius: 0.025, bend: 0.02 });
    r.bone('head', 'body', [0, 0.78, 0], [0, -0.6, 0]);
    r.add(geo.torus(PI * 2, 0.15), '#8a5a2a', { rot: [0, PI / 2, 0], scale: [0.17, 0.17, 0.17] });
    r.add(geo.cyl(20), '#bfeaff', { rot: [0, 0, -PI / 2], scale: [0.16, 0.02, 0.16], top: '#ffffff', ol: 0 });
    r.add(geo.sphere(6), '#ffffff', { pos: [0.02, 0.07, 0.06], scale: [0.01, 0.04, 0.02], ol: 0 });
    face(r, { at: [0.025, -0.02, 0], size: 0.05, spacing: 0.12, expression: 'happy', mouth: 'smile', skin: '#bfeaff', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.78 };
  },

  shadowlobber: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.3);
    leafRing(r, { n: 5, color: '#3a2a5a', tip: '#8a6ac8' });
    r.bone('head', 'body', [0, 0.04, 0]);
    r.add(geo.lathe('duskbud', [[0, 0], [0.8, 0.1], [1, 0.45], [0.6, 0.85], [0.2, 1]], 14), '#5a2a8a', { scale: [0.2, 0.42, 0.2], top: '#a86aff' });
    for (let i = 0; i < 5; i++) r.add(geo.leaf(0.2, 0.2), '#2a1a4a', { pos: [0, 0.38, 0], rot: [0, i * 1.26, 0.6], scale: [0.14, 0.3, 0.08], top: '#7a4ab8', axis: 'x' });
    face(r, { at: [0.18, 0.2, 0], size: 0.045, spacing: 0.1, expression: 'smug', mouth: 'smirk', skin: '#6a3a9a', iris: '#ff6aff', blinkBone: 'eyes', cheeks: null });
    r.on('head');
    lobArm(r, 'head', 0.36, '#3a2a5a', '#2a0a4a', '#b04fff');
    return { muzzleY: 0.45 };
  },

  gloomcap: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.3);
    r.bone('head', 'body', [0, 0.01, 0]);
    mushroom(r, { cap: '#3a1a5a', capTop: '#7a4aa8', stalk: '#b8a8c8', h: 0.22, capR: 0.28, spots: '#a6ff3a', flat: 0.7 });
    for (let i = 0; i < 6; i++) {
      const a = (i / 6) * PI * 2;
      r.add(geo.lathe('vent', [[0.5, 0], [0.4, 0.5], [0.7, 1]], 8), '#5a3a7a', { pos: [Math.cos(a) * 0.24, 0.2, Math.sin(a) * 0.24], rot: [Math.sin(a) * 1.2, 0, -Math.cos(a) * 1.2], scale: [0.04, 0.08, 0.04] });
    }
    face(r, { at: [0.15, 0.12, 0], size: 0.035, spacing: 0.085, expression: 'sleepy', mouth: 'frown', skin: '#b8a8c8', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.25 };
  },

  nightbloom: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.32);
    for (let i = 0; i < 6; i++) r.add(geo.leaf(0.6, 0.3), '#2a3a2a', { pos: [0, 0.05, 0], rot: [0, i * 1.05, 1.2], scale: [0.36, 0.5, 0.2], top: '#5a7a5a', axis: 'x' });
    r.bone('head', 'body', [0, 0.32, 0]);
    r.add(geo.capsule(1.2), '#3a1a4a', { scale: [0.22, 0.2, 0.2], top: '#7a3a9a' });
    for (let i = 0; i < 5; i++) r.add(geo.leaf(0.4, 0.3), '#5a2a7a', { pos: [0, 0.15, 0], rot: [0, i * 1.26, 0.5], scale: [0.2, 0.4, 0.14], top: '#b06aff', axis: 'x' });
    face(r, { at: [0.2, 0.03, 0], size: 0.05, spacing: 0.11, expression: 'fierce', mouth: 'fangs', skin: '#4a2a5a', iris: '#d8ff3a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.35 };
  },

  grimrose: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.26, '#3a2a2a');
    stem(r, 0.42, { color: '#2a3a2a' });
    for (let i = 0; i < 4; i++) r.add(geo.cone(4), '#1a2a1a', { pos: [0.03 * (i % 2 ? 1 : -1), 0.1 + i * 0.08, 0], rot: [0, 0, (i % 2 ? -1 : 1) * 1.3], scale: [0.012, 0.05, 0.012] });
    r.add(geo.leaf(0.3, 0.2), '#2a4a2a', { pos: [0, 0.2, 0], rot: [0, 0.6, 0.6], scale: [0.18, 0.4, 0.1], top: '#4a6a4a', axis: 'x' });
    r.bone('head', 'body', [0, 0.48, 0], [0, -0.5, 0]);
    petalRing(r, { n: 6, radius: 0.1, len: 0.14, width: 0.12, color: '#1a0a1a', tip: '#5a1a3a', curl: 0.45 });
    petalRing(r, { n: 5, radius: 0.06, len: 0.1, width: 0.1, color: '#2a0a2a', tip: '#8a1a4a', x: 0.03, offset: 0.4, curl: 0.5 });
    r.add(geo.sphere(14), '#3a0a2a', { scale: [0.09, 0.1, 0.1], top: '#8a1a4a' });
    face(r, { at: [0.08, 0.0, 0], size: 0.03, spacing: 0.065, expression: 'smug', mouth: 'smirk', skin: '#3a0a2a', iris: '#ff2a4a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.48 };
  },

  veilmint: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.24);
    r.bone('head', 'body', [0, 0, 0]);
    for (let layer = 0; layer < 3; layer++) {
      for (let i = 0; i < 4; i++) {
        const a = (i / 4) * PI * 2 + layer * 0.8 + 0.3;
        r.add(geo.leaf(0.25, 0.3), '#2a8a7a', { pos: [0, 0.08 + layer * 0.11, 0], rot: [0, a, 0.75 - layer * 0.15], scale: [0.22 - layer * 0.04, 0.4, 0.13], top: '#9affe8', axis: 'x' });
      }
    }
    r.add(geo.sphere(14), '#3aaa8a', { pos: [0, 0.44, 0], scale: 0.1, top: '#a8ffe8' });
    r.add(geo.torus(PI * 2, 0.25), '#1a1a2a', { pos: [0, 0.46, 0], rot: [PI / 2, 0, 0], scale: [0.1, 0.1, 0.06] });
    r.add(geo.tube('veiltail', [[-0.09, 0.46, 0], [-0.16, 0.42, 0.03], [-0.22, 0.36, 0.06]], 0.015), '#1a1a2a');
    face(r, { at: [0.09, 0.45, 0], size: 0.025, spacing: 0.055, expression: 'cool', mouth: 'none', skin: '#3aaa8a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.4 };
  },

  mindflower: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.28);
    leafRing(r, { n: 6, len: 0.3, width: 0.2, color: '#3a8a3a' });
    r.bone('head', 'body', [0, 0.06, 0]);
    for (let i = 0; i < 22; i++) {
      const a = i * 2.39996;
      const y = 1 - (i / 21);
      const rr = Math.sqrt(Math.max(0, 1 - y * y));
      r.add(geo.sphere(10), i % 3 ? '#ffb8d8' : '#ff8ac0', { pos: [Math.cos(a) * rr * 0.15, 0.18 + y * 0.15, Math.sin(a) * rr * 0.15], scale: 0.06, top: '#ffe8f2' });
    }
    face(r, { at: [0.17, 0.22, 0], size: 0.045, spacing: 0.1, expression: 'crazy', mouth: 'o', skin: '#ffb8d8', iris: '#8a3ad8', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.3 };
  },

  shrinkviolet: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.22);
    leafRing(r, { n: 3, len: 0.24, width: 0.18 });
    r.add(geo.tube('violetstem', [[0, 0, 0], [0.03, 0.2, 0], [0.12, 0.3, 0], [0.18, 0.28, 0]], 0.025), '#3c9d3a');
    r.bone('head', 'body', [0.18, 0.27, 0], [0, 0, -0.6]);
    petalRing(r, { n: 5, radius: 0.07, len: 0.11, width: 0.09, color: '#7a3ad8', tip: '#c88aff', curl: 0.2 });
    r.add(geo.sphere(12), '#ffe36a', { scale: 0.045, top: '#ffffff' });
    face(r, { at: [0.04, 0.0, 0], size: 0.02, spacing: 0.04, expression: 'worried', mouth: 'o', skin: '#ffe36a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.3 };
  },

  headbutt: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.28);
    r.bone('head', 'body', [0, 0.02, 0]);
    for (let ring = 0; ring < 2; ring++) {
      for (let i = 0; i < 7; i++) {
        const a = (i / 7) * PI * 2 + ring * 0.4;
        r.add(geo.leaf(0.5 - ring * 0.2, 0.3), ring ? '#5ab83a' : '#8ad85a', { pos: [0, 0.04 + ring * 0.04, 0], rot: [0, a, 0.8 - ring * 0.4], scale: [0.26, 0.45, 0.2], top: '#d8ffa8', axis: 'x' });
      }
    }
    r.add(geo.sphere(14), '#a8e87a', { pos: [0, 0.22, 0], scale: [0.15, 0.13, 0.15], top: '#e8ffc8' });
    r.add(geo.torus(PI * 2, 0.2), '#e8281a', { pos: [0, 0.3, 0], rot: [PI / 2, 0, -0.1], scale: [0.14, 0.14, 0.08] });
    face(r, { at: [0.14, 0.23, 0], size: 0.04, spacing: 0.09, expression: 'fierce', mouth: 'grin', skin: '#a8e87a', blinkBone: 'eyes', cheeks: null });
    r.on('head');
    lobArm(r, 'head', 0.36, '#5aa83a', '#a8e87a', '#e8ffc8');
    return { muzzleY: 0.45 };
  },

  frostbloom: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.26, '#8aa8b8');
    leafRing(r, { n: 4, color: '#3a8aa8', tip: '#c8f0ff' });
    stem(r, 0.3, { color: '#3a8aa8' });
    r.bone('head', 'body', [0, 0.38, 0]);
    for (let i = 0; i < 6; i++) {
      const a = (i / 6) * PI * 2;
      r.add(geo.cone(6), '#9fdcff', { pos: [Math.cos(a) * 0.08, 0.04, Math.sin(a) * 0.08], rot: [Math.sin(a) * 0.9, 0, -Math.cos(a) * 0.9], scale: [0.05, 0.2, 0.05], top: '#ffffff' });
    }
    r.add(geo.ico(), '#c8f0ff', { pos: [0, 0.06, 0], scale: 0.08, top: '#ffffff' });
    face(r, { at: [0.075, 0.07, 0], size: 0.025, spacing: 0.055, expression: 'cute', mouth: 'o', skin: '#c8f0ff', iris: '#2a6aa8', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.45 };
  },

  galekale: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.26);
    r.bone('head', 'body', [0, 0.02, 0]);
    for (let i = 0; i < 9; i++) {
      const a = (i / 9) * PI * 2;
      r.add(geo.leaf(0.7, 0.35), '#2a7a5a', { pos: [0, 0.05, 0], rot: [0, a, 1.15], scale: [0.36, 0.55, 0.2], top: '#7ad8a8', axis: 'x' });
    }
    r.add(geo.sphere(14), '#5ab88a', { pos: [0, 0.3, 0], scale: [0.14, 0.13, 0.14], top: '#a8f0c8' });
    for (const s of [1, -1]) r.add(geo.sphere(10), '#7ad8a8', { pos: [0.08, 0.27, s * 0.09], scale: [0.06, 0.055, 0.06] });
    face(r, { at: [0.13, 0.32, 0], size: 0.035, spacing: 0.08, expression: 'determined', mouth: 'o', skin: '#5ab88a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.32 };
  },

  fanclover: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.24);
    stem(r, 0.35, { color: '#3a8a3a' });
    r.bone('head', 'body', [0, 0.42, 0], [0, -0.6, 0]);
    r.bone('spin', 'head', [0.02, 0, 0], [0, 0, 0]);
    for (let i = 0; i < 4; i++) {
      const a = (i / 4) * PI * 2 + PI / 4;
      r.add(geo.sphere(14), '#3aaa4a', { pos: [0, Math.cos(a) * 0.12, Math.sin(a) * 0.12], rot: [a, 0, 0], scale: [0.025, 0.12, 0.1], top: '#9ae88a' });
    }
    r.on('head');
    r.add(geo.sphere(12), '#5abb5a', { pos: [0.04, 0, 0], scale: 0.06, top: '#c8f8b8' });
    face(r, { at: [0.09, 0.0, 0], size: 0.022, spacing: 0.05, expression: 'happy', mouth: 'o', skin: '#5abb5a', blinkBone: 'eyes', cheeks: null });
    return { muzzleY: 0.42 };
  },

  bulbbowler: (r) => {
    r.bone('body', 'root', [0, 0, 0]);
    mound(r, 0.28);
    r.bone('head', 'body', [0, 0.02, 0]);
    r.add(geo.lathe('onion', [[0, 0], [0.7, 0.08], [1, 0.4], [0.7, 0.75], [0.25, 0.92], [0.08, 1.1], [0, 1.15]], 16), '#e8a84a', { scale: [0.22, 0.4, 0.22], top: '#ffe0a0' });
    for (let i = 0; i < 4; i++) r.add(geo.torus(PI, 0.04), '#c88a3a', { pos: [0, 0.15, 0], rot: [0, (i / 4) * PI, 0], scale: [0.22, 0.17, 0.22] });
    for (let i = 0; i < 3; i++) r.add(geo.leaf(0.3, 0.1, 1.4), '#5aaa3a', { pos: [0, 0.44, 0], rot: [0, i * 2.1, 1.3], scale: [0.2, 0.2, 0.05], top: '#9ad86a', axis: 'x' });
    face(r, { at: [0.2, 0.2, 0], size: 0.045, spacing: 0.1, expression: 'determined', mouth: 'grin', skin: '#e8a84a', blinkBone: 'eyes' });
    r.on('head');
    r.bone('armL', 'head', [0.05, 0.18, 0.19], [0, 0, -0.3]);
    r.add(geo.sphere(14), '#ff9a3a', { pos: [0.1, 0, 0], scale: 0.08, top: '#fff27a' });
    return { muzzleY: 0.2 };
  },
};
