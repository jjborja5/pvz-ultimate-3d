// Lightweight particle system: one InstancedMesh draws every particle in a single draw call.
import * as THREE from 'three';

interface P {
  alive: boolean;
  pos: THREE.Vector3;
  vel: THREE.Vector3;
  life: number;
  maxLife: number;
  size: number;
  gravity: number;
  color: THREE.Color;
  grow: number;
}

const MAX = 600;

export class Particles {
  readonly mesh: THREE.InstancedMesh;
  private pool: P[] = [];
  private next = 0;
  private dummy = new THREE.Object3D();
  private rings: { mesh: THREE.Mesh; life: number; max: number; size: number }[] = [];
  private ringGeo = new THREE.SphereGeometry(1, 16, 12);

  constructor(private scene: THREE.Object3D) {
    const geo = new THREE.IcosahedronGeometry(1, 0);
    const mat = new THREE.MeshBasicMaterial({ color: '#ffffff' });
    this.mesh = new THREE.InstancedMesh(geo, mat, MAX);
    this.mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    this.mesh.frustumCulled = false;
    for (let i = 0; i < MAX; i++) {
      this.pool.push({
        alive: false,
        pos: new THREE.Vector3(),
        vel: new THREE.Vector3(),
        life: 0,
        maxLife: 1,
        size: 0.05,
        gravity: 0,
        color: new THREE.Color(),
        grow: 0,
      });
      this.dummy.scale.setScalar(0);
      this.dummy.updateMatrix();
      this.mesh.setMatrixAt(i, this.dummy.matrix);
      this.mesh.setColorAt(i, new THREE.Color('#ffffff'));
    }
    scene.add(this.mesh);
  }

  burst(
    at: THREE.Vector3,
    opts: {
      count: number;
      colors: string[];
      speed?: number;
      up?: number;
      size?: number;
      life?: number;
      gravity?: number;
      spread?: number;
      grow?: number;
    },
  ) {
    const speed = opts.speed ?? 2;
    for (let i = 0; i < opts.count; i++) {
      const p = this.pool[this.next];
      this.next = (this.next + 1) % MAX;
      p.alive = true;
      const s = opts.spread ?? 0.05;
      p.pos.set(at.x + (Math.random() - 0.5) * s, at.y + (Math.random() - 0.5) * s, at.z + (Math.random() - 0.5) * s);
      const a = Math.random() * Math.PI * 2;
      const e = Math.random() * Math.PI - Math.PI / 2;
      const v = speed * (0.4 + Math.random() * 0.6);
      p.vel.set(Math.cos(a) * Math.cos(e) * v, Math.abs(Math.sin(e)) * v + (opts.up ?? 1), Math.sin(a) * Math.cos(e) * v);
      p.maxLife = p.life = (opts.life ?? 0.6) * (0.6 + Math.random() * 0.6);
      p.size = (opts.size ?? 0.05) * (0.6 + Math.random() * 0.8);
      p.gravity = opts.gravity ?? 6;
      p.grow = opts.grow ?? 0;
      p.color.set(opts.colors[(Math.random() * opts.colors.length) | 0]);
    }
  }

  /** Expanding translucent shockwave sphere (explosions, plant food). */
  ring(at: THREE.Vector3, color: string, size: number, life = 0.45) {
    const mat = new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.7, depthWrite: false });
    const m = new THREE.Mesh(this.ringGeo, mat);
    m.position.copy(at);
    m.scale.setScalar(0.01);
    this.scene.add(m);
    this.rings.push({ mesh: m, life, max: life, size });
  }

  update(dt: number) {
    for (let i = 0; i < MAX; i++) {
      const p = this.pool[i];
      if (!p.alive) continue;
      p.life -= dt;
      if (p.life <= 0) {
        p.alive = false;
        this.dummy.scale.setScalar(0);
        this.dummy.position.set(0, -100, 0);
      } else {
        p.vel.y -= p.gravity * dt;
        p.vel.multiplyScalar(1 - Math.min(1, 1.5 * dt));
        p.pos.addScaledVector(p.vel, dt);
        if (p.pos.y < 0.02 && p.gravity > 0) {
          p.pos.y = 0.02;
          p.vel.y *= -0.3;
          p.vel.x *= 0.6;
          p.vel.z *= 0.6;
        }
        const t = p.life / p.maxLife;
        this.dummy.position.copy(p.pos);
        this.dummy.scale.setScalar(p.size * (p.grow ? 1 + (1 - t) * p.grow : Math.min(1, t * 2.5)));
        this.dummy.rotation.set(p.life * 5, p.life * 3, 0);
      }
      this.dummy.updateMatrix();
      this.mesh.setMatrixAt(i, this.dummy.matrix);
      this.mesh.setColorAt(i, p.color);
    }
    this.mesh.instanceMatrix.needsUpdate = true;
    if (this.mesh.instanceColor) this.mesh.instanceColor.needsUpdate = true;

    for (let i = this.rings.length - 1; i >= 0; i--) {
      const r = this.rings[i];
      r.life -= dt;
      const t = 1 - r.life / r.max;
      r.mesh.scale.setScalar(0.1 + t * r.size);
      (r.mesh.material as THREE.MeshBasicMaterial).opacity = 0.7 * (1 - t);
      if (r.life <= 0) {
        this.scene.remove(r.mesh);
        (r.mesh.material as THREE.Material).dispose();
        this.rings.splice(i, 1);
      }
    }
  }

  dispose() {
    this.mesh.geometry.dispose();
    (this.mesh.material as THREE.Material).dispose();
    this.mesh.dispose();
    this.ringGeo.dispose();
    for (const r of this.rings) (r.mesh.material as THREE.Material).dispose();
  }
}
