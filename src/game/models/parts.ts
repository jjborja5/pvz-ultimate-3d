// Reusable sculpted plant parts built on the rig kit.
import { face, geo, type Col, type FaceOpts, type Rig, type V3 } from './kit';

/** Dirt mound with little grass tufts at the base of a plant. */
export function mound(r: Rig, radius = 0.3, color: Col = '#7a5230') {
  r.add(geo.lathe('mound', [[0, 0.07], [0.5, 0.06], [0.85, 0.035], [1, 0]], 18), color, { scale: [radius, 1, radius], top: '#9a6a3a' });
  for (let i = 0; i < 5; i++) {
    const a = i * 1.3 + 0.4;
    r.add(geo.leaf(0.6, 0.05, 1.4), '#4f9f3e', {
      pos: [Math.cos(a) * radius * 0.8, 0.03, Math.sin(a) * radius * 0.8],
      rot: [0, -a, 1.2],
      scale: [0.09, 0.4, 0.03],
      top: '#7fcf5a',
      axis: 'x',
    });
  }
}

/** Ring of leaves around the stem base. */
export function leafRing(r: Rig, o: { n?: number; color?: Col; tip?: Col; len?: number; width?: number; y?: number; tilt?: number; curl?: number; offset?: number } = {}) {
  const n = o.n ?? 4;
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2 + (o.offset ?? 0.3);
    r.add(geo.leaf(o.curl ?? 0.35, 0.12), o.color ?? '#3e9a3a', {
      pos: [Math.cos(a) * 0.04, o.y ?? 0.06, -Math.sin(a) * 0.04],
      rot: [0, a, o.tilt ?? 0.25],
      scale: [o.len ?? 0.3, 0.35, o.width ?? 0.16],
      top: o.tip ?? '#6fcf4a',
      axis: 'x',
    });
  }
}

/** A gently curved stem from the ground to `h`. */
export function stem(r: Rig, h: number, o: { color?: Col; radius?: number; bend?: number; key?: string } = {}) {
  const bend = o.bend ?? 0.04;
  r.add(geo.tube(`stem${h}:${bend}`, [[0, 0, 0], [bend, h * 0.35, 0], [-bend * 0.5, h * 0.7, 0], [0, h, 0]], 1, 0.75, 8), o.color ?? '#3c9d3a', {
    scale: [o.radius ?? 0.05, 1, o.radius ?? 0.05],
    top: '#5fbf4a',
  });
}

export interface PeaHeadOpts {
  color: Col;
  light?: Col;
  size?: number;
  snout?: 'barrel' | 'flare' | 'wide' | 'none' | 'short';
  rim?: Col;
  face?: Partial<FaceOpts>;
  /** Extra: head crest leaves. */
  crest?: 'leaf' | 'leaves' | 'none';
  crestColor?: Col;
}

/** The classic pod head: round head + barrel snout on the current bone (origin = head center). */
export function peaHead(r: Rig, o: PeaHeadOpts): number {
  const s = o.size ?? 0.21;
  r.add(geo.sphere(18), o.color, { scale: [s, s * 1.02, s * 0.98], top: o.light ?? o.color });
  const snout = o.snout ?? 'barrel';
  let tip = s;
  if (snout !== 'none') {
    const prof: [number, number][] =
      snout === 'flare'
        ? [[0.5, 0], [0.42, 0.4], [0.45, 0.75], [0.62, 1], [0.48, 1.02]]
        : snout === 'wide'
          ? [[0.6, 0], [0.55, 0.5], [0.7, 0.9], [0.75, 1], [0.6, 1.02]]
          : snout === 'short'
            ? [[0.55, 0], [0.5, 0.5], [0.6, 0.9], [0.5, 1]]
            : [[0.45, 0], [0.4, 0.5], [0.48, 0.85], [0.55, 1], [0.42, 1.02]];
    const len = snout === 'short' ? s * 0.7 : s * 1.15;
    r.add(geo.lathe('snout:' + snout, prof, 16), o.color, { pos: [s * 0.55, -s * 0.05, 0], rot: [0, 0, -Math.PI / 2], scale: [s, len, s], top: o.rim ?? o.light ?? o.color });
    r.add(geo.cyl(14), '#14210f', { pos: [s * 0.55 + len * 1.0, -s * 0.05, 0], rot: [0, 0, -Math.PI / 2], scale: [s * 0.32, 0.01, s * 0.32] });
    tip = s * 0.55 + len;
  }
  const crest = o.crest ?? 'leaf';
  if (crest !== 'none') {
    const n = crest === 'leaves' ? 2 : 1;
    for (let i = 0; i < n; i++) {
      r.add(geo.leaf(0.5, 0.1), o.crestColor ?? '#2f8a2c', {
        pos: [-s * 0.7, s * (0.35 + i * 0.25), (i - (n - 1) / 2) * 0.08],
        rot: [0, Math.PI, -0.5 - i * 0.3],
        scale: [s * 1.1, 0.4, s * 0.55],
        top: '#5fbf4a',
        axis: 'x',
      });
    }
  }
  face(r, {
    at: [s * 0.6, s * 0.2, 0],
    size: s * 0.34,
    spacing: s * 1.08,
    expression: 'happy',
    mouth: 'none',
    skin: o.color,
    cheeks: null,
    blinkBone: 'eyes',
    ...o.face,
  });
  return tip;
}

/** Standard planted pea-family body: mound, leaves, stem; returns head height. */
export function pottedStem(r: Rig, h = 0.5, leafColor: Col = '#3e9a3a', stemColor: Col = '#3c9d3a') {
  mound(r);
  leafRing(r, { color: leafColor, n: 4 });
  stem(r, h, { color: stemColor });
}

/** Ring of petals in the y-z plane (flower facing +x). */
export function petalRing(r: Rig, o: { n: number; radius: number; len: number; width: number; color: Col; tip?: Col; x?: number; offset?: number; curl?: number }) {
  for (let i = 0; i < o.n; i++) {
    const a = (i / o.n) * Math.PI * 2 + (o.offset ?? 0);
    // Leaf points along +x; rotate so it points radially in the y-z plane.
    r.add(geo.leaf(o.curl ?? 0.15, 0.08), o.color, {
      pos: [o.x ?? 0, Math.cos(a) * o.radius, Math.sin(a) * o.radius],
      rot: [a, 0, Math.PI / 2],
      scale: [o.len, 0.3, o.width],
      top: o.tip ?? o.color,
      axis: 'x',
    });
  }
}

/** Mushroom: stalk + cap with spots on the current bone. */
export function mushroom(r: Rig, o: { cap: Col; capTop?: Col; stalk?: Col; capR?: number; h?: number; spots?: Col; flat?: number }) {
  const h = o.h ?? 0.32;
  const cr = o.capR ?? 0.25;
  r.add(geo.lathe('stalk', [[0.62, 0], [0.55, 0.3], [0.5, 0.7], [0.55, 1]], 14), o.stalk ?? '#f2e6c8', { scale: [cr * 0.55, h, cr * 0.55], top: '#fffaf0' });
  r.add(geo.lathe('cap', [[0, 1], [0.45, 0.95], [0.8, 0.75], [1, 0.42], [1.02, 0.25], [0.85, 0.15], [0.3, 0.2], [0, 0.22]], 18), o.cap, {
    pos: [0, h * 0.85, 0],
    scale: [cr, cr * (o.flat ?? 0.85), cr],
    top: o.capTop ?? o.cap,
  });
  if (o.spots) {
    for (let i = 0; i < 6; i++) {
      const a = i * 1.1;
      const el = 0.55 + (i % 2) * 0.25;
      r.add(geo.sphere(8), o.spots, {
        pos: [Math.cos(a) * cr * Math.cos(el) * 0.95, h * 0.85 + cr * (o.flat ?? 0.85) * (0.3 + Math.sin(el) * 0.62), Math.sin(a) * cr * Math.cos(el) * 0.95],
        scale: [cr * 0.17, cr * 0.08, cr * 0.17],
      });
    }
  }
}

export function v(x: number, y: number, z: number): V3 {
  return [x, y, z];
}
