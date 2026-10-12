// The backyard battlefield: lawn grid, house, street, fence, scenery and lighting.
import * as THREE from 'three';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import { COLS, LANES } from './config';
import { toonGradient } from './models/kit';

// Scenery uses simple shared cel-shaded materials (merged into a few draw calls below).
const matCache = new Map<string, THREE.MeshToonMaterial>();
function toon(color: string) {
  let m = matCache.get(color);
  if (!m) {
    m = new THREE.MeshToonMaterial({ color, gradientMap: toonGradient() });
    matCache.set(color, m);
  }
  return m;
}
const geoCache = new Map<string, THREE.BufferGeometry>();
function cached(key: string, make: () => THREE.BufferGeometry) {
  let g = geoCache.get(key);
  if (!g) geoCache.set(key, (g = make()));
  return g;
}
const G = {
  sphere: () => cached('sphere', () => new THREE.SphereGeometry(1, 18, 14)),
  sphereLo: () => cached('sphereLo', () => new THREE.SphereGeometry(1, 10, 8)),
  cyl: () => cached('cyl', () => new THREE.CylinderGeometry(1, 1, 1, 14)),
  cone: () => cached('cone', () => new THREE.ConeGeometry(1, 1, 16)),
  box: () => cached('box', () => new THREE.BoxGeometry(1, 1, 1)),
};

export const TILE = 1;
/** World x of a column center. */
export const colX = (col: number) => (col - (COLS - 1) / 2) * TILE;
/** World z of a lane center. */
export const laneZ = (lane: number) => (lane - (LANES - 1) / 2) * TILE;
export const BOARD_LEFT = colX(0) - 0.5;
export const BOARD_RIGHT = colX(COLS - 1) + 0.5;

function box(color: string, size: [number, number, number], pos: [number, number, number], shadow = false) {
  const m = new THREE.Mesh(G.box(), toon(color));
  m.scale.set(...size);
  m.position.set(...pos);
  m.castShadow = shadow;
  m.receiveShadow = true;
  return m;
}

export interface Environment {
  group: THREE.Group;
  sunLight: THREE.DirectionalLight;
  clouds: THREE.Group;
  update(dt: number): void;
}

export function buildEnvironment(highQuality: boolean): Environment {
  const group = new THREE.Group();

  // Ground
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(60, 40), toon('#4f8f3a'));
  ground.rotation.x = -Math.PI / 2;
  ground.position.y = -0.02;
  ground.receiveShadow = true;
  group.add(ground);

  // Lawn tiles (checkerboard with gentle per-lane variation)
  const tileGeo = new THREE.BoxGeometry(TILE, 0.06, TILE);
  const light = ['#7fd04e', '#79c94a', '#82d453', '#76c647', '#7ccd4d'];
  const dark = ['#68b83c', '#63b138', '#6bbd40', '#60ad36', '#66b53b'];
  for (let lane = 0; lane < LANES; lane++) {
    for (let col = 0; col < COLS; col++) {
      const t = new THREE.Mesh(tileGeo, toon((lane + col) % 2 === 0 ? light[lane] : dark[lane]));
      t.position.set(colX(col), 0, laneZ(lane));
      t.receiveShadow = true;
      group.add(t);
    }
  }
  // Lawn border
  group.add(box('#8a6a3d', [COLS + 0.3, 0.05, 0.12], [0, 0.0, laneZ(0) - 0.56]));
  group.add(box('#8a6a3d', [COLS + 0.3, 0.05, 0.12], [0, 0.0, laneZ(LANES - 1) + 0.56]));

  // House on the left
  const house = new THREE.Group();
  house.position.set(BOARD_LEFT - 2.3, 0, 0);
  house.add(box('#efe2c4', [2.2, 2.4, 7.4], [0, 1.2, 0], true));
  for (let i = 0; i < 6; i++) house.add(box('#e2d2b0', [2.22, 0.04, 7.42], [0, 0.3 + i * 0.38, 0]));
  const roof = new THREE.Mesh(new THREE.CylinderGeometry(1.9, 1.9, 7.9, 3), toon('#b5463a'));
  roof.rotation.x = Math.PI / 2;
  roof.rotation.y = Math.PI / 2;
  roof.position.set(0, 2.9, 0);
  roof.scale.set(1, 1, 0.75);
  roof.castShadow = true;
  house.add(roof);
  house.add(box('#7a4a2a', [0.08, 1.1, 0.7], [1.11, 0.55, 0]));
  house.add(box('#ffd65a', [0.04, 0.06, 0.06], [1.17, 0.55, 0.22]));
  for (const z of [-2.2, 2.2]) {
    house.add(box('#a8d8ff', [0.06, 0.7, 0.9], [1.11, 1.4, z]));
    house.add(box('#ffffff', [0.08, 0.08, 1.0], [1.12, 1.4, z]));
    house.add(box('#ffffff', [0.08, 0.8, 0.08], [1.12, 1.4, z]));
  }
  house.add(box('#9a9a9a', [0.7, 0.12, 1.2], [1.4, 0.06, 0]));
  group.add(house);

  // Patio strip where the mowers wait
  group.add(box('#c9b48a', [0.75, 0.04, LANES + 0.4], [BOARD_LEFT - 0.42, 0.0, 0]));

  // Sidewalk + street on the right
  group.add(box('#bfbfb5', [0.8, 0.08, 12], [BOARD_RIGHT + 0.45, 0.0, 0]));
  group.add(box('#55555c', [5, 0.04, 14], [BOARD_RIGHT + 3.3, -0.0, 0]));
  for (let i = -3; i <= 3; i++) group.add(box('#f1d24a', [0.12, 0.05, 0.9], [BOARD_RIGHT + 3.3, 0.0, i * 2]));

  // Back fence
  const fence = new THREE.Group();
  for (let x = BOARD_LEFT - 1; x <= BOARD_RIGHT + 0.6; x += 0.45) {
    fence.add(box('#f3ead8', [0.14, 0.9, 0.06], [x, 0.45, 0], highQuality));
    const tip = new THREE.Mesh(G.cone(), toon('#f3ead8'));
    tip.scale.set(0.1, 0.12, 0.04);
    tip.position.set(x, 0.96, 0);
    fence.add(tip);
  }
  fence.add(box('#e6dcc6', [BOARD_RIGHT - BOARD_LEFT + 1.8, 0.07, 0.04], [0, 0.3, 0.05]));
  fence.add(box('#e6dcc6', [BOARD_RIGHT - BOARD_LEFT + 1.8, 0.07, 0.04], [0, 0.7, 0.05]));
  fence.position.z = laneZ(0) - 0.95;
  group.add(fence);

  // Trees & bushes behind the fence
  const rand = mulberry(7);
  for (let i = 0; i < 9; i++) {
    const x = -7 + i * 1.9 + rand() * 0.8;
    const z = laneZ(0) - 2.2 - rand() * 1.5;
    const tree = new THREE.Group();
    const trunk = new THREE.Mesh(G.cyl(), toon('#7a5230'));
    trunk.scale.set(0.12, 1.2, 0.12);
    trunk.position.y = 0.6;
    tree.add(trunk);
    const greens = ['#3f8f3a', '#4c9e3f', '#367f33'];
    for (let k = 0; k < 3; k++) {
      const leaf = new THREE.Mesh(G.sphere(), toon(greens[k]));
      const s = 0.55 + rand() * 0.3;
      leaf.scale.set(s, s * 0.9, s);
      leaf.position.set((rand() - 0.5) * 0.6, 1.4 + k * 0.3, (rand() - 0.5) * 0.5);
      leaf.castShadow = highQuality;
      tree.add(leaf);
    }
    tree.position.set(x, 0, z);
    group.add(tree);
  }
  for (let i = 0; i < 14; i++) {
    const b = new THREE.Mesh(G.sphere(), toon(i % 2 ? '#4f9f3e' : '#5aab45'));
    const s = 0.3 + rand() * 0.2;
    b.scale.set(s * 1.3, s, s);
    b.position.set(BOARD_LEFT - 0.5 + i * 0.75, 0.15, laneZ(0) - 1.25);
    group.add(b);
  }
  // Front hedge
  for (let i = 0; i < 16; i++) {
    const b = new THREE.Mesh(G.sphere(), toon(i % 2 ? '#3f8f3a' : '#4a9a3d'));
    b.scale.set(0.45, 0.22, 0.3);
    b.position.set(BOARD_LEFT - 1.2 + i * 0.75, 0.1, laneZ(LANES - 1) + 1.0);
    group.add(b);
  }
  // Flowers sprinkled outside the lawn
  const petal = ['#ff7fb0', '#ffd23f', '#ffffff', '#b98cff'];
  for (let i = 0; i < 24; i++) {
    const f = new THREE.Mesh(G.sphere(), toon(petal[i % petal.length]));
    f.scale.setScalar(0.05);
    f.position.set(BOARD_LEFT + rand() * (BOARD_RIGHT - BOARD_LEFT), 0.06, laneZ(0) - 0.75 + (i % 2 ? 0 : laneZ(LANES - 1) * 2 + 1.5));
    group.add(f);
  }

  mergeStatic(group);

  // Clouds
  const clouds = new THREE.Group();
  for (let i = 0; i < 6; i++) {
    const c = new THREE.Group();
    for (let k = 0; k < 4; k++) {
      const s = new THREE.Mesh(G.sphereLo(), toon('#ffffff'));
      s.scale.set(0.9 + rand() * 0.5, 0.5 + rand() * 0.3, 0.6);
      s.position.set(k * 0.8, rand() * 0.3, 0);
      c.add(s);
    }
    c.position.set(-14 + i * 5.5, 5 + rand() * 1.5, -10 - rand() * 3);
    clouds.add(c);
  }
  group.add(clouds);

  // Lights
  const hemi = new THREE.HemisphereLight('#dff3ff', '#5a7a3a', 1.6);
  group.add(hemi);
  const sunLight = new THREE.DirectionalLight('#fff4dc', 2.2);
  sunLight.position.set(-3, 9, 6);
  sunLight.target.position.set(0, 0, 0);
  group.add(sunLight, sunLight.target);
  if (highQuality) {
    sunLight.castShadow = true;
    sunLight.shadow.mapSize.set(1024, 1024);
    const cam = sunLight.shadow.camera;
    cam.left = -8;
    cam.right = 8;
    cam.top = 6;
    cam.bottom = -6;
    cam.near = 1;
    cam.far = 25;
    sunLight.shadow.bias = -0.0015;
    sunLight.shadow.normalBias = 0.02;
  }

  return {
    group,
    sunLight,
    clouds,
    update(dt: number) {
      for (const c of clouds.children) {
        c.position.x += dt * 0.15;
        if (c.position.x > 16) c.position.x = -16;
      }
    },
  };
}

/**
 * Bake every static mesh into one merged mesh per material (and shadow setting) so the whole
 * backyard costs a handful of draw calls instead of hundreds — important on mobile GPUs.
 */
function mergeStatic(group: THREE.Group) {
  group.updateMatrixWorld(true);
  const buckets = new Map<string, { mat: THREE.Material; cast: boolean; geos: THREE.BufferGeometry[] }>();
  const remove: THREE.Mesh[] = [];
  group.traverse((o) => {
    const m = o as THREE.Mesh;
    if (!m.isMesh || Array.isArray(m.material)) return;
    const key = m.material.uuid + (m.castShadow ? ':c' : '');
    let b = buckets.get(key);
    if (!b) buckets.set(key, (b = { mat: m.material, cast: m.castShadow, geos: [] }));
    const g = m.geometry.index ? m.geometry.toNonIndexed() : m.geometry.clone();
    for (const name of Object.keys(g.attributes)) if (!['position', 'normal', 'uv'].includes(name)) g.deleteAttribute(name);
    g.applyMatrix4(m.matrixWorld);
    b.geos.push(g);
    remove.push(m);
  });
  for (const m of remove) m.removeFromParent();
  for (const b of buckets.values()) {
    const merged = mergeGeometries(b.geos, false);
    for (const g of b.geos) g.dispose();
    if (!merged) continue;
    const mesh = new THREE.Mesh(merged, b.mat);
    mesh.castShadow = b.cast;
    mesh.receiveShadow = true;
    group.add(mesh);
  }
}

/** Small deterministic PRNG so scenery looks the same every time. */
export function mulberry(seed: number) {
  let a = seed;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
