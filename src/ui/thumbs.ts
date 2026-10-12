// Renders each plant and zombie model once into an image used for seed packets and the almanac.
import * as THREE from 'three';
import { PLANT_ORDER, ZOMBIES, ZOMBIE_ORDER, type PlantId, type ZombieId } from '../game/config';
import { buildPlant, buildZombie } from '../game/models';

const plantThumbs = new Map<PlantId, string>();
const zombieThumbs = new Map<ZombieId, string>();

export function plantThumb(id: PlantId) {
  return plantThumbs.get(id) ?? '';
}
export function zombieThumb(id: ZombieId) {
  return zombieThumbs.get(id) ?? '';
}

export function renderThumbnails(renderer: THREE.WebGLRenderer) {
  const size = 192;
  const target = new THREE.WebGLRenderTarget(size, size);
  const scene = new THREE.Scene();
  scene.add(new THREE.HemisphereLight('#ffffff', '#6a8a5a', 2.2));
  const dir = new THREE.DirectionalLight('#ffffff', 1.6);
  dir.position.set(2, 4, 5);
  scene.add(dir);
  const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 50);
  const pixels = new Uint8Array(size * size * 4);
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = size;
  const ctx = canvas.getContext('2d')!;
  const img = ctx.createImageData(size, size);

  const shoot = (obj: THREE.Object3D, height: number) => {
    scene.add(obj);
    const box = new THREE.Box3().setFromObject(obj);
    const center = box.getCenter(new THREE.Vector3());
    const h = Math.max(box.max.y - box.min.y, box.max.x - box.min.x, height);
    const dist = (h * 0.62) / Math.tan(THREE.MathUtils.degToRad(15));
    camera.position.set(center.x + dist * 0.15, center.y + dist * 0.12, center.z + dist);
    camera.lookAt(center);
    const prevTarget = renderer.getRenderTarget();
    const prevClear = renderer.getClearAlpha();
    renderer.setRenderTarget(target);
    renderer.setClearColor(0x000000, 0);
    renderer.clear();
    renderer.render(scene, camera);
    renderer.readRenderTargetPixels(target, 0, 0, size, size, pixels);
    renderer.setRenderTarget(prevTarget);
    renderer.setClearAlpha(prevClear);
    scene.remove(obj);
    // Flip vertically (GL origin is bottom-left).
    for (let y = 0; y < size; y++) {
      const src = (size - 1 - y) * size * 4;
      img.data.set(pixels.subarray(src, src + size * 4), y * size * 4);
    }
    ctx.putImageData(img, 0, 0);
    return canvas.toDataURL('image/png');
  };

  for (const id of PLANT_ORDER) {
    const m = buildPlant(id);
    m.root.rotation.y = -0.6;
    plantThumbs.set(id, shoot(m.root, 0.7));
  }
  for (const id of ZOMBIE_ORDER) {
    const m = buildZombie(ZOMBIES[id]);
    m.root.rotation.y = Math.PI + 0.6;
    zombieThumbs.set(id, shoot(m.root, 1.2));
    for (const mat of m.mats) mat.dispose();
  }
  target.dispose();
}
