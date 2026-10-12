// Character model kit.
//
// Every plant and zombie is built from many sculpted pieces (organic lathes, curved tubes, bent
// leaves, expressive eyes...) that are baked into ONE skinned mesh with vertex colors. Each animated
// part (head, arms, petals, eyelids...) is a bone, so a fully detailed character costs a single draw
// call (+1 for its cartoon outline) no matter how many pieces it has. Built geometry is cached per
// character type and shared by every instance, which keeps spawning cheap on iPhone.
import * as THREE from 'three';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js';

export type V3 = [number, number, number];
export type Col = THREE.ColorRepresentation;

// ------------------------------------------------------------------ materials

let gradient: THREE.DataTexture | null = null;
export function toonGradient(): THREE.DataTexture {
  if (!gradient) {
    const data = new Uint8Array([110, 110, 110, 255, 175, 175, 175, 255, 225, 225, 225, 255, 255, 255, 255, 255]);
    gradient = new THREE.DataTexture(data, 4, 1, THREE.RGBAFormat);
    gradient.minFilter = THREE.NearestFilter;
    gradient.magFilter = THREE.NearestFilter;
    gradient.needsUpdate = true;
  }
  return gradient;
}

/** Per-character material (cloned per instance so it can flash, glow and tint on its own). */
export function characterMaterial(): THREE.MeshToonMaterial {
  return new THREE.MeshToonMaterial({ vertexColors: true, gradientMap: toonGradient(), color: '#ffffff' });
}

let outlineMat: THREE.MeshBasicMaterial | null = null;
export const outlineSettings = { enabled: true };
/** Shared inverted-hull outline material: pushes vertices out along their normals and draws back faces. */
export function outlineMaterial(): THREE.MeshBasicMaterial {
  if (!outlineMat) {
    outlineMat = new THREE.MeshBasicMaterial({ color: '#1d140c', side: THREE.BackSide });
    outlineMat.onBeforeCompile = (shader) => {
      shader.uniforms.uOutline = { value: 0.014 };
      shader.vertexShader = shader.vertexShader
        .replace('#include <common>', '#include <common>\nuniform float uOutline;\nattribute float olw;')
        .replace('#include <begin_vertex>', 'vec3 transformed = vec3( position ) + normal * uOutline * olw;');
    };
  }
  return outlineMat;
}

// ------------------------------------------------------------------ geometry helpers

const unitCache = new Map<string, THREE.BufferGeometry>();
function unit(key: string, make: () => THREE.BufferGeometry) {
  let g = unitCache.get(key);
  if (!g) {
    g = make();
    for (const n of Object.keys(g.attributes)) if (n !== 'position' && n !== 'normal') g.deleteAttribute(n);
    if (!g.index) {
      const idx = [];
      for (let i = 0; i < g.attributes.position.count; i++) idx.push(i);
      g.setIndex(idx);
    }
    unitCache.set(key, g);
  }
  return g;
}

export const geo = {
  sphere: (seg = 16) => unit('s' + seg, () => new THREE.SphereGeometry(1, seg, Math.max(6, Math.round(seg * 0.75)))),
  hemi: () => unit('hemi', () => new THREE.SphereGeometry(1, 16, 8, 0, Math.PI * 2, 0, Math.PI / 2)),
  cyl: (seg = 12) => unit('c' + seg, () => new THREE.CylinderGeometry(1, 1, 1, seg)),
  cone: (seg = 12) => unit('k' + seg, () => new THREE.ConeGeometry(1, 1, seg)),
  torus: (arc = Math.PI * 2, tube = 0.25) => unit(`t${arc.toFixed(2)}:${tube}`, () => new THREE.TorusGeometry(1, tube, 8, 18, arc)),
  box: () => unit('b', () => new THREE.BoxGeometry(1, 1, 1)),
  rbox: (r = 0.18) => unit('rb' + r, () => new RoundedBoxGeometry(1, 1, 1, 2, r)),
  capsule: (ratio = 1) => unit('cap' + ratio, () => new THREE.CapsuleGeometry(0.5, ratio, 6, 12)),
  ico: () => unit('ico', () => new THREE.IcosahedronGeometry(1, 0)),
  dodec: () => unit('dod', () => new THREE.DodecahedronGeometry(1, 0)),
  /** Revolved profile: points are [radius, y]. */
  lathe: (key: string, pts: [number, number][], seg = 16) =>
    unit('l:' + key, () => {
      // Lathe normals face outward only when the profile runs bottom-to-top; fix reversed profiles.
      const poly = [...pts, [0, pts[pts.length - 1][1]], [0, pts[0][1]]] as [number, number][];
      let area = 0;
      for (let i = 0; i < poly.length; i++) {
        const [x1, y1] = poly[i];
        const [x2, y2] = poly[(i + 1) % poly.length];
        area += x1 * y2 - x2 * y1;
      }
      const ordered = area < 0 ? [...pts].reverse() : pts;
      return new THREE.LatheGeometry(ordered.map(([r, y]) => new THREE.Vector2(r, y)), seg);
    }),
  /** Smooth curved tube through points. */
  tube: (key: string, pts: V3[], radius: number, taper = 1, seg = 10) =>
    unit('tb:' + key, () => {
      const curve = new THREE.CatmullRomCurve3(pts.map((p) => new THREE.Vector3(...p)));
      const g = new THREE.TubeGeometry(curve, seg, radius, 7, false);
      if (taper !== 1) {
        // Taper radius toward the end of the tube.
        const pos = g.attributes.position as THREE.BufferAttribute;
        const tmp = new THREE.Vector3();
        const rings = seg + 1;
        const perRing = pos.count / rings;
        for (let i = 0; i < pos.count; i++) {
          const ring = Math.floor(i / perRing);
          const t = ring / seg;
          const c = curve.getPointAt(t);
          tmp.fromBufferAttribute(pos, i).sub(c).multiplyScalar(1 + (taper - 1) * t).add(c);
          pos.setXYZ(i, tmp.x, tmp.y, tmp.z);
        }
        g.computeVertexNormals();
      }
      return g;
    }),
  /**
   * A leaf/petal blade along +x: pointed tip, rounded base, slight thickness, curled up by `curl`
   * and cupped across its width by `cup`.
   */
  leaf: (curl = 0.3, cup = 0.15, tip = 1) =>
    unit(`leaf:${curl}:${cup}:${tip}`, () => {
      const g = new THREE.SphereGeometry(1, 14, 10);
      const pos = g.attributes.position as THREE.BufferAttribute;
      for (let i = 0; i < pos.count; i++) {
        let x = pos.getX(i);
        let y = pos.getY(i);
        let z = pos.getZ(i);
        const u = (x + 1) / 2; // 0 base .. 1 tip
        const width = Math.sin(Math.PI * Math.pow(u, 0.75 * tip)) * (1 - 0.15 * u);
        z *= width;
        y *= 0.12 * width + 0.02;
        x = u; // length 1 along +x
        y += curl * u * u + cup * z * z * 2;
        pos.setXYZ(i, x, y, z * 0.5);
      }
      g.computeVertexNormals();
      return g;
    }),
  /** Star polygon prism (for star fruit, badges). */
  star: (points = 5, inner = 0.45) =>
    unit(`star:${points}:${inner}`, () => {
      const shape = new THREE.Shape();
      for (let i = 0; i <= points * 2; i++) {
        const a = (i / (points * 2)) * Math.PI * 2 + Math.PI / 2;
        const r = i % 2 === 0 ? 1 : inner;
        if (i === 0) shape.moveTo(Math.cos(a) * r, Math.sin(a) * r);
        else shape.lineTo(Math.cos(a) * r, Math.sin(a) * r);
      }
      const g = new THREE.ExtrudeGeometry(shape, { depth: 0.5, bevelEnabled: true, bevelThickness: 0.15, bevelSize: 0.12, bevelSegments: 2 });
      g.translate(0, 0, -0.25);
      return g;
    }),
};

// ------------------------------------------------------------------ rig builder

export interface PieceOpts {
  pos?: V3;
  rot?: V3;
  scale?: V3 | number;
  /** Vertical gradient: color is the bottom color, `top` the top color. */
  top?: Col;
  /** Gradient axis in the piece's local space (default y). */
  axis?: 'x' | 'y' | 'z';
  /** Outline thickness weight (0 = no outline). Defaults to a value based on how thin the piece is. */
  ol?: number;
}

interface BoneDef {
  name: string;
  parent: string | null;
  pos: V3;
  rot: V3;
}

interface Piece {
  bone: number;
  geo: THREE.BufferGeometry;
}

export interface RigTemplate {
  geometry: THREE.BufferGeometry;
  bones: BoneDef[];
  /** Optional standalone geometries (e.g. a zombie head that can pop off as debris). */
  detach: Record<string, THREE.BufferGeometry>;
  height: number;
}

const tmpM = new THREE.Matrix4();
const tmpQ = new THREE.Quaternion();
const tmpE = new THREE.Euler();
const tmpV = new THREE.Vector3();
const tmpS = new THREE.Vector3();
const cA = new THREE.Color();
const cB = new THREE.Color();

/** Builds a skinned character from pieces attached to named bones. */
export class Rig {
  private bones: BoneDef[] = [{ name: 'root', parent: null, pos: [0, 0, 0], rot: [0, 0, 0] }];
  private worlds: THREE.Matrix4[] = [new THREE.Matrix4()];
  private pieces: Piece[] = [];
  private detachPieces = new Map<string, THREE.BufferGeometry[]>();
  current = 0;

  /** Declare a bone at `pos` (relative to its parent bone) and make it current. */
  bone(name: string, parent: string, pos: V3, rot: V3 = [0, 0, 0]): this {
    const pi = this.index(parent);
    this.bones.push({ name, parent, pos, rot });
    tmpE.set(...rot);
    tmpQ.setFromEuler(tmpE);
    const local = new THREE.Matrix4().compose(new THREE.Vector3(...pos), tmpQ.clone(), new THREE.Vector3(1, 1, 1));
    this.worlds.push(this.worlds[pi].clone().multiply(local));
    this.current = this.bones.length - 1;
    return this;
  }

  /** Switch the current bone. */
  on(name: string): this {
    this.current = this.index(name);
    return this;
  }

  index(name: string) {
    const i = this.bones.findIndex((b) => b.name === name);
    if (i < 0) throw new Error('unknown bone ' + name);
    return i;
  }

  /** Add a piece in the current bone's local space. */
  add(g: THREE.BufferGeometry, color: Col, o: PieceOpts = {}): this {
    const geo = g.clone();
    // vertex colors (optional gradient along an axis)
    const pos = geo.attributes.position as THREE.BufferAttribute;
    const colors = new Float32Array(pos.count * 3);
    cA.set(color);
    if (o.top !== undefined) {
      cB.set(o.top);
      geo.computeBoundingBox();
      const bb = geo.boundingBox!;
      const ax = o.axis ?? 'y';
      const min = bb.min[ax];
      const span = Math.max(1e-6, bb.max[ax] - min);
      for (let i = 0; i < pos.count; i++) {
        const v = ax === 'x' ? pos.getX(i) : ax === 'y' ? pos.getY(i) : pos.getZ(i);
        const t = (v - min) / span;
        colors[i * 3] = cA.r + (cB.r - cA.r) * t;
        colors[i * 3 + 1] = cA.g + (cB.g - cA.g) * t;
        colors[i * 3 + 2] = cA.b + (cB.b - cA.b) * t;
      }
    } else {
      for (let i = 0; i < pos.count; i++) {
        colors[i * 3] = cA.r;
        colors[i * 3 + 1] = cA.g;
        colors[i * 3 + 2] = cA.b;
      }
    }
    geo.setAttribute('color', new THREE.BufferAttribute(colors, 3));
    // transform: bone world * piece local
    tmpE.set(...(o.rot ?? [0, 0, 0]));
    tmpQ.setFromEuler(tmpE);
    const s = o.scale ?? 1;
    if (typeof s === 'number') tmpS.set(s, s, s);
    else tmpS.set(...s);
    tmpV.set(...(o.pos ?? [0, 0, 0]));
    tmpM.compose(tmpV, tmpQ, tmpS);
    geo.applyMatrix4(this.worlds[this.current].clone().multiply(tmpM));
    // Thin pieces (leaves, pupils) get thinner outlines so the hull doesn't swallow them.
    let ol = o.ol;
    if (ol === undefined) {
      geo.computeBoundingBox();
      const sz = geo.boundingBox!.getSize(tmpV);
      ol = Math.max(0, Math.min(1, (Math.min(sz.x, sz.y, sz.z) - 0.015) / 0.09));
    }
    geo.setAttribute('olw', new THREE.BufferAttribute(new Float32Array(pos.count).fill(ol), 1));
    // skinning attributes
    const si = new Uint16Array(pos.count * 4);
    const sw = new Float32Array(pos.count * 4);
    for (let i = 0; i < pos.count; i++) {
      si[i * 4] = this.current;
      sw[i * 4] = 1;
    }
    geo.setAttribute('skinIndex', new THREE.BufferAttribute(si, 4));
    geo.setAttribute('skinWeight', new THREE.BufferAttribute(sw, 4));
    this.pieces.push({ bone: this.current, geo });
    return this;
  }

  /** Also copy the pieces of a bone into a standalone geometry (for debris). Call after adding them. */
  markDetachable(bone: string, key = bone) {
    const bi = this.index(bone);
    const inv = this.worlds[bi].clone().invert();
    const list = this.pieces
      .filter((p) => p.bone === bi)
      .map((p) => {
        const g = p.geo.clone();
        g.deleteAttribute('skinIndex');
        g.deleteAttribute('skinWeight');
        g.applyMatrix4(inv);
        return g;
      });
    this.detachPieces.set(key, list);
  }

  build(): RigTemplate {
    const geometry = mergeGeometries(
      this.pieces.map((p) => p.geo),
      false,
    );
    if (!geometry) throw new Error('rig merge failed');
    for (const p of this.pieces) p.geo.dispose();
    geometry.computeBoundingBox();
    geometry.computeBoundingSphere();
    const detach: Record<string, THREE.BufferGeometry> = {};
    for (const [k, list] of this.detachPieces) {
      const g = mergeGeometries(list, false);
      if (g) detach[k] = g;
    }
    return { geometry, bones: this.bones, detach, height: geometry.boundingBox!.max.y };
  }
}

// ------------------------------------------------------------------ instances

export interface CharacterInstance {
  root: THREE.Group;
  mesh: THREE.SkinnedMesh;
  outline: THREE.SkinnedMesh | null;
  material: THREE.MeshToonMaterial;
  bones: Record<string, THREE.Bone>;
  template: RigTemplate;
}

const templates = new Map<string, RigTemplate>();

export function cachedTemplate(key: string, make: () => RigTemplate): RigTemplate {
  let t = templates.get(key);
  if (!t) {
    t = make();
    templates.set(key, t);
  }
  return t;
}

/** Create an animated instance of a template (bones are new; geometry is shared). */
export function instantiate(t: RigTemplate, shadows = true): CharacterInstance {
  const bones: Record<string, THREE.Bone> = {};
  const list: THREE.Bone[] = [];
  for (const b of t.bones) {
    const bone = new THREE.Bone();
    bone.name = b.name;
    bone.position.set(...b.pos);
    bone.rotation.set(...b.rot);
    if (b.parent) bones[b.parent].add(bone);
    bones[b.name] = bone;
    list.push(bone);
  }
  const material = characterMaterial();
  const mesh = new THREE.SkinnedMesh(t.geometry, material);
  mesh.add(bones.root);
  mesh.castShadow = shadows;
  mesh.frustumCulled = false;
  const root = new THREE.Group();
  root.add(mesh);
  root.updateMatrixWorld(true);
  const skeleton = new THREE.Skeleton(list);
  mesh.bind(skeleton);
  let outline: THREE.SkinnedMesh | null = null;
  if (outlineSettings.enabled) {
    outline = new THREE.SkinnedMesh(t.geometry, outlineMaterial());
    outline.frustumCulled = false;
    outline.bind(skeleton, mesh.bindMatrix);
    root.add(outline);
  }
  return { root, mesh, outline, material, bones, template: t };
}

export function disposeInstance(c: CharacterInstance) {
  c.material.dispose();
  c.mesh.skeleton.dispose();
}

// ------------------------------------------------------------------ faces

export type Expression = 'happy' | 'angry' | 'determined' | 'sleepy' | 'crazy' | 'cool' | 'worried' | 'smug' | 'cute' | 'fierce' | 'zombie';
export type Mouth = 'smile' | 'grin' | 'o' | 'teeth' | 'frown' | 'none' | 'fangs' | 'smirk' | 'tongue' | 'zombie';

export interface FaceOpts {
  /** Center of the face surface in the current bone's space (face looks toward +x). */
  at: V3;
  size?: number;
  spacing?: number;
  expression?: Expression;
  mouth?: Mouth;
  iris?: Col;
  skin?: Col;
  cheeks?: Col | null;
  /** Put eyes on their own bone (named 'eyes') so they can blink. */
  blinkBone?: string;
  mouthDrop?: number;
  eyeHeight?: number;
}

/** Big expressive cartoon eyes with highlights, lids and brows, plus a mouth. */
export function face(r: Rig, o: FaceOpts) {
  const s = o.size ?? 0.06;
  const sp = o.spacing ?? s * 1.7;
  const [fx, fy, fz] = o.at;
  const ex = o.expression ?? 'happy';
  const iris = o.iris ?? '#3a2a1a';
  const skin = o.skin ?? '#5aa040';
  const eyeY = fy + (o.eyeHeight ?? s * 0.6);
  const base = r.current;
  const baseName = (r as unknown as { bones: BoneDef[] }).bones[base].name;
  if (o.blinkBone) r.bone(o.blinkBone, baseName, [fx, eyeY, fz]);
  const ox = o.blinkBone ? 0 : fx;
  const oy = o.blinkBone ? 0 : eyeY;
  const oz = o.blinkBone ? 0 : fz;
  for (const side of [1, -1]) {
    const z = oz + side * sp * 0.5;
    const big = ex === 'crazy' && side === 1 ? 1.25 : ex === 'zombie' && side === -1 ? 0.8 : 1;
    const es = s * big;
    r.add(geo.sphere(14), '#ffffff', { pos: [ox, oy, z], scale: [es * 0.75, es * 1.15, es] });
    const look = ex === 'crazy' ? (side === 1 ? 0.25 : -0.3) : 0;
    r.add(geo.sphere(10), ex === 'zombie' ? '#d8d0a0' : iris, { pos: [ox + es * 0.6, oy - es * 0.05 + look * es, z + side * es * 0.05], scale: [es * 0.25, es * 0.62, es * 0.58], ol: 0 });
    r.add(geo.sphere(8), '#0b0b0b', { pos: [ox + es * 0.72, oy - es * 0.05 + look * es, z + side * es * 0.05], scale: [es * 0.18, es * 0.36, es * 0.34], ol: 0 });
    r.add(geo.sphere(6), '#ffffff', { pos: [ox + es * 0.86, oy + es * 0.28, z + side * es * 0.12 - es * 0.15], scale: es * 0.15, ol: 0 });
    r.add(geo.sphere(6), '#ffffff', { pos: [ox + es * 0.84, oy - es * 0.25, z - side * es * 0.1], scale: es * 0.07, ol: 0 });
    // lids & brows
    if (ex === 'angry' || ex === 'fierce' || ex === 'determined') {
      const tilt = ex === 'determined' ? 0.25 : 0.55;
      r.add(geo.hemi(), skin, { pos: [ox + es * 0.05, oy + es * 0.35, z], rot: [side * tilt, 0, 0], scale: [es * 0.85, es * 0.7, es * 1.08] });
      r.add(geo.capsule(3), '#24180c', { pos: [ox + es * 0.7, oy + es * 1.2, z], rot: [side * -tilt - Math.PI / 2, 0, 0], scale: [es * 0.35, es * 0.3, es * 0.35] });
    } else if (ex === 'sleepy' || ex === 'cool' || ex === 'smug') {
      r.add(geo.hemi(), ex === 'cool' ? '#141414' : skin, { pos: [ox + es * 0.04, oy + es * 0.02, z], rot: [0, 0, 0], scale: [es * 0.86, es * 1.0, es * 1.08] });
    } else if (ex === 'worried') {
      r.add(geo.capsule(3), '#24180c', { pos: [ox + es * 0.7, oy + es * 1.25, z], rot: [side * 0.4 - Math.PI / 2, 0, 0], scale: [es * 0.3, es * 0.26, es * 0.3] });
    } else if (ex === 'zombie') {
      r.add(geo.hemi(), skin, { pos: [ox + es * 0.03, oy + es * 0.15, z], rot: [side * 0.2, 0, 0], scale: [es * 0.84, es * 0.9, es * 1.06] });
    }
  }
  if (ex === 'cool') {
    // sunglasses bridge
    r.add(geo.box(), '#141414', { pos: [ox + s * 0.75, oy + s * 0.25, oz], scale: [s * 0.2, s * 0.2, sp * 0.6] });
  }
  if (o.blinkBone) r.current = base;
  // mouth
  const mouth = o.mouth ?? 'smile';
  const my = fy - (o.mouthDrop ?? s * 1.0);
  const mw = s * 1.1;
  switch (mouth) {
    case 'smile':
      r.add(geo.torus(Math.PI, 0.22), '#3a1208', { pos: [fx, my + mw * 0.3, fz], rot: [Math.PI, Math.PI / 2, 0], scale: mw * 0.7 });
      break;
    case 'grin':
      r.add(geo.hemi(), '#4a1010', { pos: [fx - mw * 0.1, my + mw * 0.2, fz], rot: [Math.PI, 0, Math.PI / 2], scale: [mw * 0.75, mw * 0.3, mw * 0.65] });
      r.add(geo.box(), '#ffffff', { pos: [fx + mw * 0.12, my + mw * 0.12, fz], scale: [mw * 0.08, mw * 0.14, mw * 1.0] });
      break;
    case 'o':
      r.add(geo.sphere(10), '#3a0d08', { pos: [fx, my, fz], scale: [mw * 0.25, mw * 0.35, mw * 0.3] });
      break;
    case 'teeth':
      r.add(geo.box(), '#3a0d08', { pos: [fx, my, fz], scale: [mw * 0.2, mw * 0.35, mw * 1.1] });
      r.add(geo.box(), '#ffffff', { pos: [fx + mw * 0.08, my + mw * 0.1, fz], scale: [mw * 0.08, mw * 0.12, mw * 1.0] });
      r.add(geo.box(), '#ffffff', { pos: [fx + mw * 0.08, my - mw * 0.12, fz], scale: [mw * 0.08, mw * 0.1, mw * 0.9] });
      break;
    case 'frown':
      r.add(geo.torus(Math.PI, 0.22), '#3a1208', { pos: [fx, my - mw * 0.25, fz], rot: [0, Math.PI / 2, 0], scale: mw * 0.6 });
      break;
    case 'fangs':
      r.add(geo.hemi(), '#4a1010', { pos: [fx - mw * 0.1, my + mw * 0.2, fz], rot: [Math.PI, 0, Math.PI / 2], scale: [mw * 0.75, mw * 0.32, mw * 0.65] });
      for (const z of [0.3, -0.3]) r.add(geo.cone(6), '#ffffff', { pos: [fx + mw * 0.15, my + mw * 0.06, fz + z * mw], rot: [Math.PI, 0, 0], scale: [mw * 0.1, mw * 0.25, mw * 0.1] });
      break;
    case 'smirk':
      r.add(geo.torus(Math.PI * 0.6, 0.22), '#3a1208', { pos: [fx, my + mw * 0.2, fz - mw * 0.1], rot: [Math.PI, Math.PI / 2, 0.3], scale: mw * 0.6 });
      break;
    case 'tongue':
      r.add(geo.hemi(), '#4a1010', { pos: [fx - mw * 0.1, my + mw * 0.2, fz], rot: [Math.PI, 0, Math.PI / 2], scale: [mw * 0.7, mw * 0.3, mw * 0.6] });
      r.add(geo.sphere(8), '#ff6f8a', { pos: [fx + mw * 0.1, my - mw * 0.1, fz + mw * 0.15], scale: [mw * 0.2, mw * 0.1, mw * 0.25] });
      break;
    case 'zombie':
      r.add(geo.box(), '#2a0c0c', { pos: [fx, my, fz], scale: [mw * 0.25, mw * 0.32, mw * 1.2] });
      for (const z of [-0.35, 0, 0.3]) r.add(geo.box(), '#e8e0b8', { pos: [fx + mw * 0.1, my + mw * 0.12, fz + z * mw], scale: [mw * 0.08, mw * 0.14, mw * 0.18] });
      break;
    case 'none':
      break;
  }
  if (o.cheeks !== null) {
    const ck = o.cheeks ?? '#ff8fa3';
    for (const side of [1, -1]) r.add(geo.sphere(8), ck, { pos: [fx - s * 0.1, my + s * 0.4, fz + side * sp * 0.85], scale: [s * 0.15, s * 0.3, s * 0.42] });
  }
}
