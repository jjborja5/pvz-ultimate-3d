// Procedural, original low-poly cartoon models built from primitives (no external assets).
import * as THREE from 'three';
import type { PlantId, ZombieDef } from './config';

// ---------- shared materials & geometry ----------

let gradient: THREE.DataTexture | null = null;
function toonGradient(): THREE.DataTexture {
  if (!gradient) {
    const data = new Uint8Array([90, 90, 90, 255, 180, 180, 180, 255, 255, 255, 255, 255]);
    gradient = new THREE.DataTexture(data, 3, 1, THREE.RGBAFormat);
    gradient.minFilter = THREE.NearestFilter;
    gradient.magFilter = THREE.NearestFilter;
    gradient.needsUpdate = true;
  }
  return gradient;
}

const matCache = new Map<string, THREE.Material>();

/** Shared cel-shaded material (do not mutate). */
export function toon(color: string): THREE.MeshToonMaterial {
  const key = 'toon:' + color;
  let m = matCache.get(key) as THREE.MeshToonMaterial | undefined;
  if (!m) {
    m = new THREE.MeshToonMaterial({ color, gradientMap: toonGradient() });
    matCache.set(key, m);
  }
  return m;
}

/** Per-instance material that can flash / tint independently. */
export function toonUnique(color: string): THREE.MeshToonMaterial {
  return new THREE.MeshToonMaterial({ color, gradientMap: toonGradient() });
}

export function basic(color: string, opts: THREE.MeshBasicMaterialParameters = {}): THREE.MeshBasicMaterial {
  const key = 'basic:' + color + JSON.stringify(opts);
  let m = matCache.get(key) as THREE.MeshBasicMaterial | undefined;
  if (!m) {
    m = new THREE.MeshBasicMaterial({ color, ...opts });
    matCache.set(key, m);
  }
  return m;
}

const geoCache = new Map<string, THREE.BufferGeometry>();
function geo<T extends THREE.BufferGeometry>(key: string, make: () => T): T {
  let g = geoCache.get(key) as T | undefined;
  if (!g) {
    g = make();
    geoCache.set(key, g);
  }
  return g;
}

export const G = {
  sphere: () => geo('sphere', () => new THREE.SphereGeometry(1, 18, 14)),
  sphereLo: () => geo('sphereLo', () => new THREE.SphereGeometry(1, 10, 8)),
  cyl: () => geo('cyl', () => new THREE.CylinderGeometry(1, 1, 1, 14)),
  cone: () => geo('cone', () => new THREE.ConeGeometry(1, 1, 16)),
  box: () => geo('box', () => new THREE.BoxGeometry(1, 1, 1)),
  torus: () => geo('torusArc', () => new THREE.TorusGeometry(1, 0.18, 6, 14, Math.PI)),
  ico: () => geo('ico', () => new THREE.IcosahedronGeometry(1, 0)),
};

type V3 = [number, number, number];

function mesh(
  g: THREE.BufferGeometry,
  m: THREE.Material,
  pos: V3 = [0, 0, 0],
  scale: V3 = [1, 1, 1],
  rot: V3 = [0, 0, 0],
  shadow = true,
): THREE.Mesh {
  const o = new THREE.Mesh(g, m);
  o.position.set(...pos);
  o.scale.set(...scale);
  o.rotation.set(...rot);
  o.castShadow = shadow;
  return o;
}

function ball(m: THREE.Material, pos: V3, r: number | V3, shadow = true) {
  const s: V3 = typeof r === 'number' ? [r, r, r] : r;
  return mesh(G.sphere(), m, pos, s, [0, 0, 0], shadow);
}

function eye(parent: THREE.Object3D, pos: V3, r: number, angry = false) {
  const white = ball(toon('#ffffff'), pos, r, false);
  const pupil = ball(basic('#141414'), [pos[0] + r * 0.65, pos[1], pos[2]], r * 0.55, false);
  parent.add(white, pupil);
  if (angry) {
    const brow = mesh(G.box(), basic('#1d3b17'), [pos[0] + r * 0.4, pos[1] + r * 1.05, pos[2]], [r * 0.6, r * 0.35, r * 2.1], [
      pos[2] > 0 ? -0.5 : 0.5,
      0,
      0,
    ]);
    parent.add(brow);
  }
}

// ---------- plants ----------

export interface PlantModel {
  root: THREE.Group;
  body: THREE.Group;
  head: THREE.Object3D;
  /** Projectile spawn point (shooters). */
  muzzle: THREE.Object3D;
  parts: Record<string, THREE.Object3D>;
}

function dirtMound(g: THREE.Group) {
  g.add(mesh(G.sphereLo(), toon('#7a5230'), [0, 0, 0], [0.3, 0.07, 0.3]));
}

function baseLeaves(g: THREE.Group, color: string, n = 3) {
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2 + 0.4;
    g.add(mesh(G.sphere(), toon(color), [Math.cos(a) * 0.18, 0.05, Math.sin(a) * 0.18], [0.2, 0.035, 0.09], [0, -a, 0.15]));
  }
}

function stem(g: THREE.Group, color: string, h: number) {
  g.add(mesh(G.cyl(), toon(color), [0, h / 2, 0], [0.045, h, 0.045]));
}

function buildPeaPlant(opts: { head: string; dark: string; snoutRim: string; crest?: 'ice' | 'leaves'; angry?: boolean }): PlantModel {
  const root = new THREE.Group();
  const body = new THREE.Group();
  root.add(body);
  dirtMound(body);
  baseLeaves(body, opts.dark, 4);
  stem(body, opts.dark, 0.5);
  const head = new THREE.Group();
  head.position.set(0, 0.55, 0);
  body.add(head);
  head.add(ball(toon(opts.head), [0, 0, 0], 0.22));
  head.add(mesh(G.cyl(), toon(opts.head), [0.24, 0.0, 0], [0.095, 0.24, 0.095], [0, 0, -Math.PI / 2]));
  head.add(mesh(G.cyl(), toon(opts.snoutRim), [0.36, 0.0, 0], [0.11, 0.04, 0.11], [0, 0, -Math.PI / 2]));
  head.add(mesh(G.cyl(), basic('#1b2b16'), [0.381, 0.0, 0], [0.07, 0.01, 0.07], [0, 0, -Math.PI / 2], false));
  eye(head, [0.13, 0.08, 0.095], 0.055, opts.angry);
  eye(head, [0.13, 0.08, -0.095], 0.055, opts.angry);
  // back leaf / crest
  if (opts.crest === 'ice') {
    for (let i = -1; i <= 1; i++) {
      head.add(mesh(G.cone(), toon('#dff6ff'), [-0.05 + i * 0.07, 0.24 - Math.abs(i) * 0.03, 0], [0.05, 0.16, 0.05], [0, 0, i * 0.35]));
    }
  } else {
    const n = opts.crest === 'leaves' ? 2 : 1;
    for (let i = 0; i < n; i++) {
      head.add(
        mesh(G.sphere(), toon(opts.dark), [-0.22, 0.1 + i * 0.07, (i - (n - 1) / 2) * 0.1], [0.14, 0.04, 0.07], [0, 0, 0.6 + i * 0.25]),
      );
    }
  }
  const muzzle = new THREE.Object3D();
  muzzle.position.set(0.4, 0, 0);
  head.add(muzzle);
  return { root, body, head, muzzle, parts: {} };
}

function buildSunflower(): PlantModel {
  const root = new THREE.Group();
  const body = new THREE.Group();
  root.add(body);
  dirtMound(body);
  baseLeaves(body, '#3e9a3a', 4);
  stem(body, '#3e9a3a', 0.55);
  const head = new THREE.Group();
  head.position.set(0, 0.62, 0);
  head.rotation.y = -0.7; // face the camera a bit more
  body.add(head);
  const petals = new THREE.Group();
  for (let i = 0; i < 12; i++) {
    const a = (i / 12) * Math.PI * 2;
    petals.add(mesh(G.sphere(), toon('#ffcc1f'), [0, Math.sin(a) * 0.24, Math.cos(a) * 0.24], [0.03, 0.12, 0.06], [a, 0, 0]));
  }
  head.add(petals);
  head.add(mesh(G.cyl(), toon('#b06a22'), [0.02, 0, 0], [0.17, 0.07, 0.17], [0, 0, -Math.PI / 2]));
  head.add(mesh(G.cyl(), toon('#ffe066'), [0.05, 0, 0], [0.14, 0.03, 0.14], [0, 0, -Math.PI / 2], false));
  eye(head, [0.07, 0.04, 0.05], 0.03);
  eye(head, [0.07, 0.04, -0.05], 0.03);
  head.add(mesh(G.torus(), basic('#5a2d0a'), [0.075, -0.03, 0], [0.05, 0.05, 0.05], [Math.PI, Math.PI / 2, 0], false));
  head.add(ball(toon('#ff8fa0'), [0.07, -0.01, 0.1], [0.01, 0.02, 0.025], false));
  head.add(ball(toon('#ff8fa0'), [0.07, -0.01, -0.1], [0.01, 0.02, 0.025], false));
  const muzzle = new THREE.Object3D();
  head.add(muzzle);
  return { root, body, head, muzzle, parts: { petals } };
}

function buildWallnut(): PlantModel {
  const root = new THREE.Group();
  const body = new THREE.Group();
  root.add(body);
  const head = new THREE.Group();
  head.position.set(0, 0.36, 0);
  body.add(head);
  head.add(ball(toon('#b9773b'), [0, 0, 0], [0.3, 0.38, 0.3]));
  head.add(ball(toon('#d49a5c'), [0.12, 0.05, 0], [0.2, 0.26, 0.22], false));
  for (const [x, y, z] of [
    [-0.05, 0.25, 0.18],
    [0.0, -0.2, -0.2],
    [-0.15, 0.1, -0.2],
  ] as V3[]) {
    head.add(ball(toon('#8a5427'), [x, y, z], [0.05, 0.04, 0.05], false));
  }
  eye(head, [0.24, 0.08, 0.08], 0.06);
  eye(head, [0.24, 0.08, -0.08], 0.06);
  head.add(mesh(G.box(), basic('#4b2a10'), [0.29, -0.1, 0], [0.01, 0.025, 0.1], [0, 0, 0], false));
  const crack1 = new THREE.Group();
  crack1.add(mesh(G.box(), basic('#3b1d08'), [0.27, 0.2, 0.05], [0.01, 0.12, 0.015], [0.5, 0, 0.3], false));
  crack1.add(mesh(G.box(), basic('#3b1d08'), [0.25, -0.02, -0.15], [0.01, 0.1, 0.015], [-0.6, 0, 0], false));
  crack1.visible = false;
  const crack2 = new THREE.Group();
  crack2.add(mesh(G.box(), basic('#3b1d08'), [0.2, 0.26, -0.12], [0.01, 0.14, 0.02], [-0.8, 0, 0.3], false));
  crack2.add(mesh(G.box(), basic('#3b1d08'), [0.27, -0.2, 0.1], [0.01, 0.14, 0.02], [0.9, 0, 0], false));
  crack2.visible = false;
  head.add(crack1, crack2);
  const shell = mesh(G.sphere(), new THREE.MeshToonMaterial({ color: '#c9d4dd', gradientMap: toonGradient(), transparent: true, opacity: 0.55 }), [0, 0, 0], [0.36, 0.44, 0.36]);
  shell.visible = false;
  head.add(shell);
  return { root, body, head, muzzle: new THREE.Object3D(), parts: { crack1, crack2, shell } };
}

function buildCherry(): PlantModel {
  const root = new THREE.Group();
  const body = new THREE.Group();
  root.add(body);
  const head = new THREE.Group();
  body.add(head);
  for (const z of [0.15, -0.15]) {
    const c = new THREE.Group();
    c.position.set(z > 0 ? 0.03 : -0.03, 0.2, z);
    c.add(ball(toon('#e8242e'), [0, 0, 0], 0.19));
    c.add(ball(toon('#ff8a8a'), [0.08, 0.08, 0.03], 0.05, false));
    eye(c, [0.14, 0.05, 0.06], 0.04, true);
    eye(c, [0.14, 0.05, -0.06], 0.04, true);
    c.add(mesh(G.box(), basic('#3a0a0a'), [0.18, -0.06, 0], [0.01, 0.03, 0.09], [0, 0, 0], false));
    head.add(c);
  }
  head.add(mesh(G.cyl(), toon('#3e8a2e'), [0, 0.47, 0.07], [0.02, 0.32, 0.02], [0.45, 0, 0]));
  head.add(mesh(G.cyl(), toon('#3e8a2e'), [0, 0.47, -0.07], [0.02, 0.32, 0.02], [-0.45, 0, 0]));
  head.add(mesh(G.sphere(), toon('#4fae3a'), [0.05, 0.63, 0], [0.13, 0.03, 0.06], [0, 0, 0.3]));
  return { root, body, head, muzzle: new THREE.Object3D(), parts: {} };
}

function buildPotatoMine(): PlantModel {
  const root = new THREE.Group();
  const body = new THREE.Group();
  root.add(body);
  dirtMound(body);
  const head = new THREE.Group();
  body.add(head);
  head.add(ball(toon('#c99a5b'), [0, 0.12, 0], [0.24, 0.17, 0.22]));
  for (const [x, y, z] of [
    [0.05, 0.25, 0.1],
    [-0.12, 0.2, -0.06],
    [0.1, 0.16, -0.14],
  ] as V3[]) {
    head.add(ball(toon('#9c6e38'), [x, y, z], 0.03, false));
  }
  eye(head, [0.19, 0.17, 0.06], 0.04);
  eye(head, [0.19, 0.17, -0.06], 0.04);
  head.add(mesh(G.cyl(), toon('#777777'), [0, 0.38, 0], [0.012, 0.18, 0.012]));
  const light = ball(basic('#ff2a2a'), [0, 0.48, 0], 0.04, false);
  head.add(light);
  return { root, body, head, muzzle: new THREE.Object3D(), parts: { light } };
}

export function buildPlant(id: PlantId): PlantModel {
  let m: PlantModel;
  switch (id) {
    case 'peashooter':
      m = buildPeaPlant({ head: '#63d35a', dark: '#3c9d3a', snoutRim: '#4fbf48' });
      break;
    case 'snowpea':
      m = buildPeaPlant({ head: '#8fdcff', dark: '#3c9d3a', snoutRim: '#e8f8ff', crest: 'ice' });
      break;
    case 'repeater':
      m = buildPeaPlant({ head: '#3cb04f', dark: '#226e2c', snoutRim: '#2f9a40', crest: 'leaves', angry: true });
      break;
    case 'sunflower':
      m = buildSunflower();
      break;
    case 'wallnut':
      m = buildWallnut();
      break;
    case 'cherrybomb':
      m = buildCherry();
      break;
    case 'potatomine':
      m = buildPotatoMine();
      break;
  }
  m.root.rotation.y = -0.45; // turn toward the camera while still facing the zombies
  return m;
}

// ---------- zombies ----------

export interface ZombieModel {
  root: THREE.Group;
  body: THREE.Group;
  legL: THREE.Group;
  legR: THREE.Group;
  armL: THREE.Group;
  armR: THREE.Group;
  head: THREE.Group;
  armor: THREE.Object3D | null;
  /** Materials that flash white when hit / tint blue when chilled. */
  mats: THREE.MeshToonMaterial[];
  baseColors: THREE.Color[];
}

export function buildZombie(def: ZombieDef): ZombieModel {
  const mats: THREE.MeshToonMaterial[] = [];
  const u = (c: string) => {
    const m = toonUnique(c);
    mats.push(m);
    return m;
  };
  const skin = u(def.skin);
  const coat = u(def.coat);
  const pants = u(def.id === 'brute' ? '#4a3a2a' : '#4b4f6b');
  const shirt = toon('#e9e4d4');

  const root = new THREE.Group();
  const body = new THREE.Group();
  root.add(body);

  const legs: THREE.Group[] = [];
  for (const z of [0.09, -0.09]) {
    const leg = new THREE.Group();
    leg.position.set(0, 0.55, z);
    leg.add(mesh(G.cyl(), pants, [0, -0.25, 0], [0.065, 0.5, 0.065]));
    leg.add(mesh(G.box(), toon('#2c2420'), [0.05, -0.52, 0], [0.2, 0.07, 0.11]));
    body.add(leg);
    legs.push(leg);
  }
  // torso
  const torso = new THREE.Group();
  torso.position.set(0, 0.8, 0);
  torso.rotation.z = -0.12; // zombie hunch
  body.add(torso);
  torso.add(mesh(G.box(), coat, [0, 0, 0], [0.22, 0.48, 0.38]));
  torso.add(mesh(G.box(), shirt, [0.105, 0.02, 0], [0.02, 0.42, 0.14], [0, 0, 0], false));
  torso.add(mesh(G.box(), toon('#c0282d'), [0.12, 0.04, 0], [0.025, 0.28, 0.05], [0, 0, 0], false));

  const arms: THREE.Group[] = [];
  for (const z of [0.22, -0.22]) {
    const arm = new THREE.Group();
    arm.position.set(0, 0.97, z);
    arm.rotation.z = 1.3;
    arm.add(mesh(G.cyl(), coat, [0, -0.13, 0], [0.055, 0.26, 0.055]));
    arm.add(mesh(G.cyl(), skin, [0, -0.32, 0], [0.04, 0.16, 0.04]));
    arm.add(ball(skin, [0, -0.42, 0], 0.055));
    body.add(arm);
    arms.push(arm);
  }

  const head = new THREE.Group();
  head.position.set(0.04, 1.06, 0);
  body.add(head);
  head.add(ball(skin, [0, 0.15, 0], [0.17, 0.18, 0.16]));
  head.add(ball(skin, [0.06, 0.03, 0], [0.11, 0.07, 0.12])); // jaw
  // eyes: mismatched for character
  const ew = ball(toon('#fffbe0'), [0.13, 0.19, 0.06], 0.05, false);
  const ew2 = ball(toon('#fffbe0'), [0.13, 0.19, -0.06], 0.037, false);
  head.add(ew, ew2);
  head.add(ball(basic('#2b1a14'), [0.172, 0.19, 0.06], 0.022, false));
  head.add(ball(basic('#2b1a14'), [0.162, 0.19, -0.06], 0.018, false));
  head.add(mesh(G.box(), basic('#3a1414'), [0.15, 0.04, 0], [0.03, 0.035, 0.12], [0, 0, 0], false));
  head.add(mesh(G.box(), toon('#f4f0d8'), [0.165, 0.065, 0.025], [0.015, 0.02, 0.025], [0, 0, 0], false));
  // hair tufts
  head.add(ball(toon('#3b3020'), [-0.06, 0.32, 0.02], [0.05, 0.03, 0.05], false));
  head.add(ball(toon('#3b3020'), [-0.1, 0.28, -0.06], [0.05, 0.03, 0.04], false));

  let armor: THREE.Object3D | null = null;
  if (def.armorType === 'cone') {
    const c = new THREE.Group();
    c.position.set(-0.01, 0.3, 0);
    c.rotation.z = -0.15;
    c.add(mesh(G.cone(), toon('#ff8a1e'), [0, 0.16, 0], [0.15, 0.36, 0.15]));
    c.add(mesh(G.cyl(), toon('#ffffff'), [0, 0.13, 0], [0.11, 0.05, 0.11], [0, 0, 0], false));
    c.add(mesh(G.box(), toon('#e86e10'), [0, -0.01, 0], [0.32, 0.03, 0.32]));
    head.add(c);
    armor = c;
  } else if (def.armorType === 'bucket') {
    const b = new THREE.Group();
    b.position.set(-0.01, 0.31, 0);
    b.rotation.z = -0.12;
    b.add(mesh(G.cyl(), toon('#a7b0b8'), [0, 0.04, 0], [0.165, 0.24, 0.165]));
    b.add(mesh(G.cyl(), toon('#7e878f'), [0, 0.16, 0], [0.17, 0.025, 0.17]));
    b.add(mesh(G.cyl(), toon('#7e878f'), [0, -0.06, 0], [0.18, 0.025, 0.18]));
    head.add(b);
    armor = b;
  }

  if (def.id === 'flag') {
    const flag = new THREE.Group();
    flag.position.set(0, -0.42, 0);
    flag.add(mesh(G.cyl(), toon('#6b4a2a'), [0.45, 0, 0], [0.02, 1.0, 0.02], [0, 0, -Math.PI / 2]));
    const banner = new THREE.Group();
    banner.position.set(0.85, 0, 0.22);
    banner.add(mesh(G.box(), toon('#c3262e'), [0, 0, 0], [0.32, 0.03, 0.4]));
    banner.add(mesh(G.cyl(), toon('#f5e9c8'), [0, 0.02, 0], [0.1, 0.01, 0.1], [0, 0, 0], false));
    flag.add(banner);
    arms[1].add(flag);
  }
  if (def.id === 'brute') {
    const club = new THREE.Group();
    club.position.set(0, -0.44, 0);
    club.add(mesh(G.cyl(), toon('#7a4e26'), [0, -0.25, 0], [0.07, 0.6, 0.07]));
    club.add(mesh(G.cyl(), toon('#8f5d2e'), [0, -0.55, 0], [0.1, 0.18, 0.1]));
    arms[0].add(club);
    // belt & bandana for a distinct boss silhouette
    torso.add(mesh(G.box(), toon('#2a2018'), [0, -0.22, 0], [0.24, 0.06, 0.4], [0, 0, 0], false));
    head.add(mesh(G.cyl(), toon('#b0302a'), [0, 0.24, 0], [0.175, 0.06, 0.165], [0, 0, -0.1], false));
  }

  root.scale.setScalar(def.scale);
  root.rotation.y = Math.PI + 0.45; // face -x (toward the house), turned toward camera
  return {
    root,
    body,
    legL: legs[0],
    legR: legs[1],
    armL: arms[0],
    armR: arms[1],
    head,
    armor,
    mats,
    baseColors: mats.map((m) => m.color.clone()),
  };
}

// ---------- props & pickups ----------

export function buildSun(): THREE.Group {
  const g = new THREE.Group();
  g.add(mesh(G.sphere(), basic('#fff3a0'), [0, 0, 0], [0.16, 0.16, 0.16], [0, 0, 0], false));
  g.add(mesh(G.sphere(), basic('#ffd21f', { transparent: true, opacity: 0.55, depthWrite: false }), [0, 0, 0], [0.24, 0.24, 0.24], [0, 0, 0], false));
  const rays = new THREE.Group();
  for (let i = 0; i < 10; i++) {
    const a = (i / 10) * Math.PI * 2;
    rays.add(mesh(G.cone(), basic('#ffb31f'), [Math.cos(a) * 0.3, Math.sin(a) * 0.3, 0], [0.05, 0.14, 0.02], [0, 0, a - Math.PI / 2], false));
  }
  g.add(rays);
  g.userData.rays = rays;
  return g;
}

export function buildPlantFood(): THREE.Group {
  const g = new THREE.Group();
  g.add(mesh(G.sphere(), basic('#52ff5a', { transparent: true, opacity: 0.4, depthWrite: false }), [0, 0, 0], [0.3, 0.3, 0.3], [0, 0, 0], false));
  g.add(mesh(G.sphere(), toon('#39d43f'), [0, 0, 0], [0.18, 0.07, 0.12], [0, 0, 0.5], false));
  g.add(mesh(G.sphere(), toon('#2cb032'), [0.05, 0.07, 0], [0.14, 0.05, 0.09], [0, 0.8, 0.9], false));
  g.add(mesh(G.cyl(), toon('#1f7a26'), [-0.13, -0.06, 0], [0.015, 0.12, 0.015], [0, 0, 0.9], false));
  return g;
}

export function buildCoin(gold: boolean): THREE.Group {
  const g = new THREE.Group();
  g.add(mesh(G.cyl(), toon(gold ? '#ffcf33' : '#d9dde3'), [0, 0, 0], [0.16, 0.03, 0.16], [Math.PI / 2, 0, 0], false));
  g.add(mesh(G.cyl(), toon(gold ? '#e8a910' : '#a9b0b8'), [0, 0, 0.017], [0.1, 0.005, 0.1], [Math.PI / 2, 0, 0], false));
  return g;
}

export function buildTrophy(): THREE.Group {
  const g = new THREE.Group();
  const gold = toon('#ffc928');
  g.add(mesh(G.cyl(), gold, [0, 0.35, 0], [0.22, 0.3, 0.22]));
  g.add(mesh(G.cyl(), gold, [0, 0.1, 0], [0.04, 0.25, 0.04]));
  g.add(mesh(G.cyl(), toon('#7a4e26'), [0, -0.05, 0], [0.18, 0.1, 0.18]));
  g.add(mesh(G.torus(), gold, [0, 0.38, 0.22], [0.1, 0.1, 0.1], [0, 0, -Math.PI / 2]));
  g.add(mesh(G.torus(), gold, [0, 0.38, -0.22], [0.1, 0.1, 0.1], [0, 0, -Math.PI / 2]));
  g.add(mesh(G.sphere(), basic('#fff3a0', { transparent: true, opacity: 0.3, depthWrite: false }), [0, 0.3, 0], [0.6, 0.6, 0.6], [0, 0, 0], false));
  return g;
}

export function buildMower(): THREE.Group {
  const g = new THREE.Group();
  g.add(mesh(G.box(), toon('#d8312b'), [0, 0.16, 0], [0.42, 0.16, 0.34]));
  g.add(mesh(G.box(), toon('#333333'), [0.05, 0.27, 0], [0.18, 0.08, 0.2]));
  g.add(mesh(G.cyl(), toon('#999999'), [-0.3, 0.42, 0], [0.02, 0.4, 0.02], [0, 0, 0.9]));
  g.add(mesh(G.cyl(), toon('#222222'), [-0.45, 0.56, 0], [0.025, 0.3, 0.025], [Math.PI / 2, 0, 0]));
  for (const [x, z] of [
    [0.14, 0.18],
    [0.14, -0.18],
    [-0.14, 0.18],
    [-0.14, -0.18],
  ]) {
    g.add(mesh(G.cyl(), toon('#222222'), [x, 0.08, z], [0.08, 0.05, 0.08], [Math.PI / 2, 0, 0]));
  }
  return g;
}

export function buildPea(kind: 'pea' | 'snow'): THREE.Mesh {
  const m = mesh(G.sphere(), toon(kind === 'snow' ? '#a8e8ff' : '#7ae86a'), [0, 0, 0], [0.1, 0.1, 0.1], [0, 0, 0], false);
  return m;
}
