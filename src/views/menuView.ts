// Animated backyard diorama shown behind the menus.
import * as THREE from 'three';
import type { View } from '../app';
import { ZOMBIES, type PlantId, type ZombieId } from '../game/config';
import { buildEnvironment, colX, laneZ, type Environment } from '../game/environment';
import { buildPlant, buildZombie, type PlantModel, type ZombieModel } from '../game/models';

export class MenuView implements View {
  readonly scene = new THREE.Scene();
  readonly camera = new THREE.PerspectiveCamera(40, 16 / 9, 0.1, 100);
  private env: Environment;
  private plants: PlantModel[] = [];
  private zombies: ZombieModel[] = [];
  private t = 0;

  constructor(highQuality: boolean) {
    this.scene.background = new THREE.Color('#8fd3ff');
    this.scene.fog = new THREE.Fog('#8fd3ff', 18, 40);
    this.env = buildEnvironment(highQuality);
    this.scene.add(this.env.group);
    const layout: [PlantId, number, number][] = [
      ['sunflower', 0, 1],
      ['peashooter', 1, 1],
      ['wallnut', 3, 1],
      ['sunflower', 0, 2],
      ['repeater', 1, 2],
      ['potatomine', 4, 2],
      ['sunflower', 0, 3],
      ['snowpea', 1, 3],
      ['wallnut', 3, 3],
      ['cherrybomb', 2, 0],
      ['peashooter', 2, 4],
    ];
    for (const [id, col, lane] of layout) {
      const m = buildPlant(id);
      m.root.position.set(colX(col), 0.03, laneZ(lane));
      if (id === 'potatomine') m.head.position.y = 0;
      this.scene.add(m.root);
      this.plants.push(m);
    }
    const zs: [ZombieId, number, number][] = [
      ['basic', 6.2, 1],
      ['cone', 7.0, 2],
      ['bucket', 6.6, 3],
      ['flag', 7.6, 0],
      ['brute', 8.6, 4],
    ];
    for (const [id, col, lane] of zs) {
      const m = buildZombie(ZOMBIES[id]);
      m.root.position.set(colX(col), 0.03, laneZ(lane));
      this.scene.add(m.root);
      this.zombies.push(m);
    }
  }

  update(dt: number) {
    this.t += dt;
    const t = this.t;
    this.env.update(dt);
    this.plants.forEach((p, i) => {
      p.body.rotation.z = Math.sin(t * 2 + i) * 0.06;
      p.head.rotation.z = Math.sin(t * 1.5 + i) * 0.05;
    });
    this.zombies.forEach((z, i) => {
      const k = t * 3 + i;
      z.legL.rotation.z = Math.sin(k) * 0.3;
      z.legR.rotation.z = -Math.sin(k) * 0.3;
      z.armL.rotation.z = 1.25 + Math.sin(k) * 0.15;
      z.armR.rotation.z = 1.25 - Math.sin(k) * 0.15;
      z.head.rotation.z = Math.sin(t * 1.3 + i) * 0.15;
    });
    const a = Math.sin(t * 0.12) * 0.35;
    this.camera.position.set(Math.sin(a) * 9 + 1, 4.2, Math.cos(a) * 9);
    this.camera.lookAt(1, 0.4, 0);
  }

  resize(w: number, h: number) {
    this.camera.aspect = w / h;
    this.camera.fov = w / h < 1.2 ? 60 : 40;
    this.camera.updateProjectionMatrix();
  }

  dispose() {
    for (const z of this.zombies) for (const m of z.mats) m.dispose();
  }
}
