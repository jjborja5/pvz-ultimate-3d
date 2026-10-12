// Transient visual effects: beams, lightning, glows, pools, craters, wind and tints.
import * as THREE from 'three';
import { BOARD_LEFT, BOARD_RIGHT } from './environment';

interface Item {
  obj: THREE.Object3D;
  life: number;
  max: number;
  mats: THREE.MeshBasicMaterial[];
  opacity: number;
  grow?: number;
  drift?: THREE.Vector3;
}

const box = new THREE.BoxGeometry(1, 1, 1);
const sphere = new THREE.SphereGeometry(1, 16, 10);
const disc = new THREE.CircleGeometry(1, 24);

export class Fx {
  private items: Item[] = [];

  constructor(private root: THREE.Object3D) {}

  private mat(color: string, opacity: number, additive = true) {
    return new THREE.MeshBasicMaterial({ color, transparent: true, opacity, depthWrite: false, blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending });
  }

  private push(obj: THREE.Object3D, life: number, mats: THREE.MeshBasicMaterial[], opacity: number, extra: Partial<Item> = {}) {
    this.root.add(obj);
    this.items.push({ obj, life, max: life, mats, opacity, ...extra });
  }

  /** Straight energy beam between two points. */
  beam(from: THREE.Vector3, to: THREE.Vector3, color: string, width: number, life = 0.3) {
    const g = new THREE.Group();
    const len = from.distanceTo(to);
    const core = new THREE.Mesh(box, this.mat('#ffffff', 0.9));
    const glow = new THREE.Mesh(box, this.mat(color, 0.6));
    core.scale.set(len, width * 0.35, width * 0.35);
    glow.scale.set(len, width, width);
    g.add(glow, core);
    g.position.copy(from).lerp(to, 0.5);
    g.lookAt(to);
    g.rotateY(Math.PI / 2);
    this.push(g, life, [core.material as THREE.MeshBasicMaterial, glow.material as THREE.MeshBasicMaterial], 0.9);
  }

  /** Jagged lightning bolt. */
  lightning(from: THREE.Vector3, to: THREE.Vector3, color: string) {
    const g = new THREE.Group();
    const mats = [this.mat(color, 0.9), this.mat('#ffffff', 1)];
    const pts: THREE.Vector3[] = [from.clone()];
    const n = 6;
    for (let i = 1; i < n; i++) {
      const p = from.clone().lerp(to, i / n);
      p.x += (Math.random() - 0.5) * 0.25;
      p.y += (Math.random() - 0.5) * 0.25;
      p.z += (Math.random() - 0.5) * 0.25;
      pts.push(p);
    }
    pts.push(to.clone());
    for (let i = 0; i < pts.length - 1; i++) {
      const a = pts[i];
      const b = pts[i + 1];
      for (const [m, w] of [
        [mats[0], 0.07],
        [mats[1], 0.025],
      ] as const) {
        const seg = new THREE.Mesh(box, m);
        seg.scale.set(a.distanceTo(b) + 0.02, w, w);
        seg.position.copy(a).lerp(b, 0.5);
        seg.lookAt(b);
        seg.rotateY(Math.PI / 2);
        g.add(seg);
      }
    }
    this.push(g, 0.22, mats, 1);
  }

  /** Soft expanding glow sphere. */
  glowBurst(at: THREE.Vector3, color: string, size: number) {
    const m = new THREE.Mesh(sphere, this.mat(color, 0.55));
    m.position.copy(at);
    m.scale.setScalar(size * 0.3);
    this.push(m, 0.35, [m.material as THREE.MeshBasicMaterial], 0.55, { grow: size });
  }

  /** Scorch mark left by a crater-making explosion. */
  crater(at: THREE.Vector3, life: number) {
    const m = new THREE.Mesh(disc, this.mat('#2a1a10', 0.8, false));
    m.rotation.x = -Math.PI / 2;
    m.position.copy(at);
    m.scale.setScalar(0.45);
    this.push(m, life, [m.material as THREE.MeshBasicMaterial], 0.8);
  }

  /** Glowing hazard pool on a tile (lava, goo). */
  pool(at: THREE.Vector3, color: string, life: number) {
    const g = new THREE.Group();
    const a = new THREE.Mesh(disc, this.mat(color, 0.85, false));
    const b = new THREE.Mesh(disc, this.mat('#ffe36a', 0.6));
    a.rotation.x = b.rotation.x = -Math.PI / 2;
    a.scale.setScalar(0.45);
    b.scale.setScalar(0.25);
    b.position.y = 0.005;
    g.add(a, b);
    g.position.copy(at);
    this.push(g, life, [a.material as THREE.MeshBasicMaterial, b.material as THREE.MeshBasicMaterial], 0.85);
  }

  /** Flash along a whole lane. */
  laneFlash(z: number, color: string) {
    const m = new THREE.Mesh(box, this.mat(color, 0.6));
    m.scale.set(BOARD_RIGHT - BOARD_LEFT + 1, 0.5, 0.8);
    m.position.set((BOARD_LEFT + BOARD_RIGHT) / 2, 0.3, z);
    this.push(m, 0.5, [m.material as THREE.MeshBasicMaterial], 0.6);
  }

  /** Gust of wind streaks across a lane (or the whole lawn). */
  wind(z: number, fromX: number, color: string, all: boolean) {
    const g = new THREE.Group();
    const mats: THREE.MeshBasicMaterial[] = [];
    const n = all ? 18 : 6;
    for (let i = 0; i < n; i++) {
      const mat = this.mat(color, 0.6);
      mats.push(mat);
      const s = new THREE.Mesh(box, mat);
      s.scale.set(1.2 + Math.random(), 0.03, 0.03);
      s.position.set(fromX + Math.random() * 3, 0.3 + Math.random() * 1, (all ? (Math.random() - 0.5) * 5 : z + (Math.random() - 0.5) * 0.7));
      g.add(s);
    }
    this.push(g, 0.6, mats, 0.6, { drift: new THREE.Vector3(8, 0, 0) });
  }

  /** Brief colored wash over the whole lawn. */
  screenTint(color: string, life: number) {
    const m = new THREE.Mesh(box, this.mat(color, 0.35));
    m.scale.set(16, 0.05, 8);
    m.position.set(0, 1.2, 0);
    this.push(m, life, [m.material as THREE.MeshBasicMaterial], 0.35);
  }

  update(dt: number) {
    for (let i = this.items.length - 1; i >= 0; i--) {
      const it = this.items[i];
      it.life -= dt;
      const t = Math.max(0, it.life / it.max);
      for (const m of it.mats) m.opacity = it.opacity * Math.min(1, t * 2.5);
      if (it.grow) it.obj.scale.setScalar(it.grow * (0.3 + (1 - t) * 0.9));
      if (it.drift) it.obj.position.addScaledVector(it.drift, dt);
      if (it.life <= 0) {
        it.obj.removeFromParent();
        for (const m of it.mats) m.dispose();
        this.items.splice(i, 1);
      }
    }
  }

  dispose() {
    for (const it of this.items) for (const m of it.mats) m.dispose();
    this.items.length = 0;
  }
}
