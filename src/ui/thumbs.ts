// Renders 3D portraits of plants and zombies on demand (cached) for seed packets and the almanac.
import * as THREE from 'three';
import { ZOMBIES, type ZombieId } from '../game/config';
import { buildPlant } from '../game/models/plants';
import { buildZombie } from '../game/models/zombies';
import { disposeInstance } from '../game/models/kit';

const plantThumbs = new Map<string, string>();
const zombieThumbs = new Map<ZombieId, string>();
let renderer: THREE.WebGLRenderer | null = null;
let ctx: {
  target: THREE.WebGLRenderTarget;
  scene: THREE.Scene;
  camera: THREE.PerspectiveCamera;
  pixels: Uint8Array;
  canvas: HTMLCanvasElement;
  c2d: CanvasRenderingContext2D;
  img: ImageData;
} | null = null;
const SIZE = 160;

export function initThumbnails(r: THREE.WebGLRenderer) {
  renderer = r;
}

function setup() {
  if (ctx) return ctx;
  const scene = new THREE.Scene();
  scene.add(new THREE.HemisphereLight('#ffffff', '#6a8a5a', 2.4));
  const dir = new THREE.DirectionalLight('#ffffff', 1.5);
  dir.position.set(2, 4, 5);
  scene.add(dir);
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = SIZE;
  const c2d = canvas.getContext('2d')!;
  ctx = {
    target: new THREE.WebGLRenderTarget(SIZE, SIZE),
    scene,
    camera: new THREE.PerspectiveCamera(30, 1, 0.1, 50),
    pixels: new Uint8Array(SIZE * SIZE * 4),
    canvas,
    c2d,
    img: c2d.createImageData(SIZE, SIZE),
  };
  return ctx;
}

function shoot(obj: THREE.Object3D, minSize: number): string {
  if (!renderer) return '';
  const c = setup();
  c.scene.add(obj);
  obj.updateMatrixWorld(true);
  // Skinned meshes: compute bounds from the bind-pose geometry, transformed by the root.
  const box = new THREE.Box3();
  obj.traverse((o) => {
    const m = o as THREE.Mesh;
    if (m.isMesh && m.geometry) {
      m.geometry.computeBoundingBox();
      const bb = m.geometry.boundingBox!.clone().applyMatrix4(m.matrixWorld);
      box.union(bb);
    }
  });
  const center = box.getCenter(new THREE.Vector3());
  const h = Math.max(box.max.y - box.min.y, box.max.x - box.min.x, box.max.z - box.min.z, minSize);
  const dist = (h * 0.62) / Math.tan(THREE.MathUtils.degToRad(15));
  c.camera.position.set(center.x + dist * 0.12, center.y + dist * 0.14, center.z + dist);
  c.camera.lookAt(center);
  const prevTarget = renderer.getRenderTarget();
  const prevColor = new THREE.Color();
  renderer.getClearColor(prevColor);
  const prevAlpha = renderer.getClearAlpha();
  renderer.setRenderTarget(c.target);
  renderer.setClearColor(0x000000, 0);
  renderer.clear();
  renderer.render(c.scene, c.camera);
  renderer.readRenderTargetPixels(c.target, 0, 0, SIZE, SIZE, c.pixels);
  renderer.setRenderTarget(prevTarget);
  renderer.setClearColor(prevColor, prevAlpha);
  c.scene.remove(obj);
  for (let y = 0; y < SIZE; y++) {
    const src = (SIZE - 1 - y) * SIZE * 4;
    c.img.data.set(c.pixels.subarray(src, src + SIZE * 4), y * SIZE * 4);
  }
  c.c2d.putImageData(c.img, 0, 0);
  return c.canvas.toDataURL('image/png');
}

export function plantThumb(id: string): string {
  let url = plantThumbs.get(id);
  if (url === undefined) {
    const m = buildPlant(id);
    m.root.rotation.y = -0.6;
    url = shoot(m.root, 0.75);
    disposeInstance(m.inst);
    plantThumbs.set(id, url);
  }
  return url;
}

export function zombieThumb(id: ZombieId): string {
  let url = zombieThumbs.get(id);
  if (url === undefined) {
    const m = buildZombie(ZOMBIES[id]);
    m.root.rotation.y = Math.PI + 0.6;
    m.root.scale.setScalar(1);
    url = shoot(m.root, 1.3);
    disposeInstance(m.inst);
    zombieThumbs.set(id, url);
  }
  return url;
}

// ------------------------------------------------------------------ progressive loading

const queue: { id: string; zombie: boolean; img: HTMLImageElement }[] = [];
let pumping = false;

function pump() {
  if (pumping) return;
  pumping = true;
  const step = () => {
    const t0 = performance.now();
    // Render a few portraits per frame so big grids appear without freezing the UI.
    while (queue.length && performance.now() - t0 < 12) {
      const job = queue.shift()!;
      if (!job.img.isConnected && queue.length > 40) continue;
      job.img.src = job.zombie ? zombieThumb(job.id as ZombieId) : plantThumb(job.id);
      job.img.classList.remove('loading');
    }
    if (queue.length) requestAnimationFrame(step);
    else pumping = false;
  };
  requestAnimationFrame(step);
}

/** An <img> that shows the portrait immediately if cached, otherwise fills in shortly after. */
export function thumbImg(id: string, alt: string, zombie = false, cls = ''): HTMLImageElement {
  const img = document.createElement('img');
  img.alt = alt;
  img.draggable = false;
  if (cls) img.className = cls;
  const cached = zombie ? zombieThumbs.get(id as ZombieId) : plantThumbs.get(id);
  if (cached !== undefined) img.src = cached;
  else {
    img.classList.add('loading');
    img.src = 'data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==';
    queue.push({ id, zombie, img });
    pump();
  }
  return img;
}
