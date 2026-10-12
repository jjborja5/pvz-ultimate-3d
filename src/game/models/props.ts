// Pickups, lawn mowers and projectile meshes.
import * as THREE from 'three';
import type { ProjLook } from '../plants/types';
import { face, geo } from './kit';
import { staticMesh } from './zombies';

const PI = Math.PI;
const basicCache = new Map<string, THREE.MeshBasicMaterial>();
function glowMat(color: string, opacity = 0.5) {
  const key = color + opacity;
  let m = basicCache.get(key);
  if (!m) {
    m = new THREE.MeshBasicMaterial({ color, transparent: true, opacity, depthWrite: false, blending: THREE.AdditiveBlending });
    basicCache.set(key, m);
  }
  return m;
}
function solidMat(color: string) {
  const key = 'solid' + color;
  let m = basicCache.get(key);
  if (!m) {
    m = new THREE.MeshBasicMaterial({ color });
    basicCache.set(key, m);
  }
  return m;
}
const sphere = new THREE.SphereGeometry(1, 14, 10);
const coneG = new THREE.ConeGeometry(1, 1, 8);

export function buildSun(value = 50): THREE.Group {
  const g = new THREE.Group();
  const s = value >= 50 ? 1 : 0.7;
  const core = new THREE.Mesh(sphere, solidMat('#fff3a0'));
  core.scale.setScalar(0.16 * s);
  g.add(core);
  const halo = new THREE.Mesh(sphere, glowMat('#ffd21f', 0.55));
  halo.scale.setScalar(0.26 * s);
  g.add(halo);
  const halo2 = new THREE.Mesh(sphere, glowMat('#ffb31f', 0.25));
  halo2.scale.setScalar(0.38 * s);
  g.add(halo2);
  const rays = new THREE.Group();
  for (let i = 0; i < 10; i++) {
    const a = (i / 10) * PI * 2;
    const m = new THREE.Mesh(coneG, solidMat('#ffb31f'));
    m.position.set(Math.cos(a) * 0.3 * s, Math.sin(a) * 0.3 * s, 0);
    m.scale.set(0.05 * s, 0.14 * s, 0.02);
    m.rotation.z = a - PI / 2;
    rays.add(m);
  }
  g.add(rays);
  g.userData.rays = rays;
  return g;
}

export function buildPlantFood(): THREE.Object3D {
  const g = new THREE.Group();
  const halo = new THREE.Mesh(sphere, glowMat('#52ff5a', 0.4));
  halo.scale.setScalar(0.32);
  g.add(halo);
  g.add(
    staticMesh('plantfood', (r) => {
      r.add(geo.leaf(0.3, 0.2), '#2cb032', { pos: [-0.12, 0, 0], scale: [0.28, 0.5, 0.18], top: '#8fff7a', axis: 'x' });
      r.add(geo.leaf(0.3, 0.2), '#2cb032', { pos: [0.02, 0.02, 0], rot: [0, 1.2, 0.5], scale: [0.2, 0.5, 0.14], top: '#8fff7a', axis: 'x' });
      r.add(geo.tube('pfstem', [[-0.12, 0, 0], [-0.18, -0.06, 0], [-0.2, -0.12, 0]], 0.015), '#1f7a26');
      face(r, { at: [0.0, 0.03, 0.0], size: 0.03, spacing: 0.06, expression: 'happy', mouth: 'smile', skin: '#2cb032', cheeks: null });
    }),
  );
  return g;
}

export function buildCoin(gold: boolean): THREE.Object3D {
  return staticMesh(gold ? 'coin-gold' : 'coin-silver', (r) => {
    r.add(geo.cyl(18), gold ? '#ffcf33' : '#d9dde3', { rot: [PI / 2, 0, 0], scale: [0.16, 0.035, 0.16], top: gold ? '#fff27a' : '#ffffff' });
    r.add(geo.cyl(18), gold ? '#e8a910' : '#a9b0b8', { pos: [0, 0, 0.019], rot: [PI / 2, 0, 0], scale: [0.11, 0.005, 0.11] });
    r.add(geo.star(5, 0.45), gold ? '#fff27a' : '#ffffff', { pos: [0, 0, 0.024], scale: [0.06, 0.06, 0.01] });
  });
}

export function buildTrophy(): THREE.Object3D {
  const g = new THREE.Group();
  g.add(
    staticMesh('trophy', (r) => {
      r.add(geo.lathe('cup', [[0, 0.3], [0.5, 0.32], [0.95, 0.6], [1, 1], [0.9, 1]], 18), '#ffc928', { pos: [0, 0.1, 0], scale: [0.24, 0.45, 0.24], top: '#fff27a' });
      r.add(geo.cyl(10), '#e8a910', { pos: [0, 0.15, 0], scale: [0.04, 0.2, 0.04] });
      r.add(geo.rbox(0.2), '#7a4e26', { pos: [0, 0.0, 0], scale: [0.3, 0.1, 0.3], top: '#a87a4a' });
      for (const s of [1, -1]) r.add(geo.torus(PI, 0.2), '#ffc928', { pos: [0, 0.42, s * 0.24], rot: [0, 0, -PI / 2], scale: 0.1 });
      r.add(geo.star(5, 0.45), '#ffffff', { pos: [0.23, 0.4, 0], rot: [0, PI / 2, 0], scale: [0.07, 0.07, 0.02] });
    }),
  );
  const halo = new THREE.Mesh(sphere, glowMat('#fff3a0', 0.25));
  halo.scale.setScalar(0.6);
  halo.position.y = 0.35;
  g.add(halo);
  return g;
}

export function buildMower(): THREE.Object3D {
  return staticMesh('mower', (r) => {
    r.add(geo.rbox(0.3), '#d8312b', { pos: [0, 0.17, 0], scale: [0.44, 0.17, 0.36], top: '#ff6a5a' });
    r.add(geo.rbox(0.3), '#333333', { pos: [0.05, 0.28, 0], scale: [0.2, 0.09, 0.22] });
    r.add(geo.cyl(8), '#999999', { pos: [-0.3, 0.42, 0], rot: [0, 0, 0.9], scale: [0.02, 0.4, 0.02] });
    r.add(geo.cyl(8), '#222222', { pos: [-0.45, 0.56, 0], rot: [PI / 2, 0, 0], scale: [0.025, 0.3, 0.025] });
    for (const [x, z] of [
      [0.14, 0.18],
      [0.14, -0.18],
      [-0.14, 0.18],
      [-0.14, -0.18],
    ]) {
      r.add(geo.cyl(12), '#222222', { pos: [x, 0.08, z], rot: [PI / 2, 0, 0], scale: [0.08, 0.05, 0.08] });
      r.add(geo.cyl(12), '#bbbbbb', { pos: [x, 0.08, z * 1.08], rot: [PI / 2, 0, 0], scale: [0.04, 0.03, 0.04] });
    }
  });
}

// ------------------------------------------------------------------ projectiles

const PROJ: Record<ProjLook, { color: string; top?: string; glow?: string; shape: 'ball' | 'star' | 'spike' | 'leafy' | 'cube' | 'lumpy' | 'cone' }> = {
  pea: { color: '#5fd84a', top: '#c8ff9a', shape: 'ball' },
  mega: { color: '#5fd84a', top: '#c8ff9a', shape: 'ball' },
  snow: { color: '#9fe0ff', top: '#ffffff', glow: '#bff0ff', shape: 'ball' },
  fire: { color: '#ff6a1f', top: '#ffe36a', glow: '#ff8a2a', shape: 'ball' },
  goo: { color: '#8fdf2a', top: '#d8ff7a', glow: '#a6ff3a', shape: 'lumpy' },
  shadow: { color: '#5a2a8a', top: '#b04fff', glow: '#9a3aff', shape: 'ball' },
  rock: { color: '#8a7a6a', top: '#b8a898', shape: 'lumpy' },
  volt: { color: '#d8b8ff', top: '#ffffff', glow: '#b98cff', shape: 'ball' },
  kernel: { color: '#ffd23f', top: '#fff6b0', shape: 'lumpy' },
  butter: { color: '#ffe36a', top: '#fffbe0', shape: 'cube' },
  cabbage: { color: '#7fcf3a', top: '#d8f8a8', shape: 'leafy' },
  melon: { color: '#3a9a2a', top: '#8fdf6a', shape: 'ball' },
  wmelon: { color: '#5ac8c0', top: '#e8ffff', glow: '#bff0ff', shape: 'ball' },
  star: { color: '#ffcf1f', top: '#fff6b0', shape: 'star' },
  spike: { color: '#c8e8a8', top: '#ffffff', shape: 'spike' },
  bulb: { color: '#ff9a3a', top: '#fff27a', glow: '#ffcf6a', shape: 'ball' },
  boomerang: { color: '#ff5a8a', top: '#ffb0c8', shape: 'star' },
  thistle: { color: '#c08aff', top: '#ffffff', shape: 'spike' },
  bomb: { color: '#c8142a', top: '#ff6a6a', shape: 'lumpy' },
  plasma: { color: '#e8ff6a', top: '#ffffff', glow: '#c8ff3a', shape: 'ball' },
  spore: { color: '#d89aff', top: '#ffffff', glow: '#e0b0ff', shape: 'lumpy' },
  coconut: { color: '#7a4a2a', top: '#a87a4a', shape: 'lumpy' },
  pinecone: { color: '#8a5a2a', top: '#c08a4a', shape: 'cone' },
  head: { color: '#7fd86a', top: '#e8ffd8', shape: 'leafy' },
  grape: { color: '#8a3ad8', top: '#d8a8ff', shape: 'ball' },
  seed: { color: '#c8a85a', top: '#fff6b0', shape: 'lumpy' },
  pepper: { color: '#e02028', top: '#ffb04a', glow: '#ff6a1f', shape: 'cone' },
  arrow: { color: '#a8784a', top: '#e8e8e8', shape: 'spike' },
  bubble: { color: '#9fe8ff', top: '#ffffff', glow: '#c8f4ff', shape: 'ball' },
};

export function projectileMesh(look: ProjLook, scale = 1): THREE.Object3D {
  const p = PROJ[look] ?? PROJ.pea;
  const body = staticMesh(
    'proj:' + look,
    (r) => {
      switch (p.shape) {
        case 'ball':
          r.add(geo.sphere(12), p.color, { scale: 0.1, top: p.top });
          r.add(geo.sphere(6), '#ffffff', { pos: [0.04, 0.05, 0.03], scale: 0.025 });
          break;
        case 'lumpy':
          r.add(geo.dodec(), p.color, { scale: 0.1, top: p.top });
          break;
        case 'cube':
          r.add(geo.rbox(0.3), p.color, { scale: [0.17, 0.08, 0.13], top: p.top });
          break;
        case 'star':
          r.add(geo.star(5, 0.45), p.color, { rot: [PI / 2, 0, 0], scale: [0.13, 0.13, 0.06], top: p.top });
          break;
        case 'spike':
          r.add(geo.cone(8), p.color, { rot: [0, 0, -PI / 2], scale: [0.04, 0.24, 0.04], top: p.top });
          break;
        case 'leafy':
          r.add(geo.sphere(10), p.color, { scale: [0.12, 0.11, 0.12], top: p.top });
          for (let i = 0; i < 4; i++) r.add(geo.leaf(0.3, 0.2), p.color, { rot: [0, i * 1.57, 0.4], scale: [0.12, 0.3, 0.09], top: p.top, axis: 'x' });
          break;
        case 'cone':
          r.add(geo.lathe('pcone', [[0, 0], [0.6, 0.2], [1, 0.6], [0.6, 0.9], [0, 1]], 10), p.color, { rot: [0, 0, -PI / 2], scale: [0.09, 0.22, 0.09], top: p.top });
          break;
      }
    },
    false,
  );
  const g = new THREE.Group();
  g.add(body);
  if (p.glow) {
    const halo = new THREE.Mesh(sphere, glowMat(p.glow, 0.45));
    halo.scale.setScalar(0.17);
    g.add(halo);
  }
  g.scale.setScalar(scale);
  return g;
}
