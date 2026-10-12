// App shell: owns the WebGL renderer, the render loop, the save file and screen navigation.
import * as THREE from 'three';
import { audio } from './game/audio';
import { loadSave, writeSave, type SaveData } from './game/save';
import { initThumbnails } from './ui/thumbs';
import { clear } from './ui/dom';
import * as screens from './ui/screens';
import { MenuView } from './views/menuView';
import { BattleView } from './views/battleView';

export interface View {
  scene: THREE.Scene;
  camera: THREE.PerspectiveCamera;
  update(dt: number): void;
  resize(w: number, h: number): void;
  dispose(): void;
}

export class App {
  readonly renderer: THREE.WebGLRenderer;
  readonly ui: HTMLElement;
  save: SaveData;
  private view: View | null = null;
  private menuView: MenuView | null = null;
  private last = performance.now();
  private fpsFrames = 0;
  private fpsTime = 0;
  fps = 60;

  constructor(private canvas: HTMLCanvasElement, ui: HTMLElement) {
    this.ui = ui;
    this.save = loadSave();
    audio.setMusic(this.save.settings.music);
    audio.setSfx(this.save.settings.sfx);
    this.renderer = new THREE.WebGLRenderer({
      canvas,
      antialias: this.save.settings.highQuality,
      powerPreference: 'high-performance',
      alpha: false,
    });
    this.applyQuality();
    initThumbnails(this.renderer);

    const unlock = () => audio.unlock();
    window.addEventListener('pointerdown', unlock, { passive: true });
    window.addEventListener('touchend', unlock, { passive: true });
    window.addEventListener('resize', () => this.resize());
    window.visualViewport?.addEventListener('resize', () => this.resize());
    window.addEventListener('orientationchange', () => setTimeout(() => this.resize(), 250));
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) {
        audio.suspend();
        if (this.view instanceof BattleView) this.view.pause();
      } else audio.resume();
    });
    this.resize();
    this.renderer.setAnimationLoop(() => this.frame());
  }

  applyQuality() {
    const hq = this.save.settings.highQuality;
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, hq ? 2 : 1.25));
    this.renderer.shadowMap.enabled = hq;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.resize();
  }

  persist() {
    writeSave(this.save);
  }

  private resize() {
    const w = window.innerWidth;
    const h = window.innerHeight;
    this.renderer.setSize(w, h, false);
    this.canvas.style.width = w + 'px';
    this.canvas.style.height = h + 'px';
    this.view?.resize(w, h);
  }

  private frame() {
    const now = performance.now();
    const dt = Math.min(0.1, (now - this.last) / 1000);
    this.last = now;
    this.fpsFrames++;
    this.fpsTime += dt;
    if (this.fpsTime > 1) {
      this.fps = Math.round(this.fpsFrames / this.fpsTime);
      this.fpsFrames = 0;
      this.fpsTime = 0;
    }
    if (!this.view) return;
    this.view.update(dt);
    this.renderer.render(this.view.scene, this.view.camera);
  }

  private setView(v: View) {
    if (this.view && this.view !== this.menuView) this.view.dispose();
    this.view = v;
    this.resize();
  }

  /** Shared animated backyard used behind all menu screens. */
  private useMenuView() {
    if (!this.menuView) this.menuView = new MenuView(this.save.settings.highQuality);
    if (this.view !== this.menuView) this.setView(this.menuView);
    audio.playMusic('menu');
  }

  /** Called when graphics quality changes: rebuild scenes so shadows/materials refresh. */
  rebuildMenuView() {
    if (this.menuView) {
      const wasActive = this.view === this.menuView;
      this.menuView.dispose();
      this.menuView = null;
      if (wasActive) this.useMenuView();
    }
  }

  showScreen(name: 'title' | 'map' | 'almanac' | 'ultimate' | 'settings') {
    this.useMenuView();
    clear(this.ui);
    const el =
      name === 'title'
        ? screens.titleScreen(this)
        : name === 'map'
          ? screens.mapScreen(this)
          : name === 'almanac'
            ? screens.almanacScreen(this)
            : name === 'ultimate'
              ? screens.ultimateScreen(this)
              : screens.settingsScreen(this);
    this.ui.append(el);
  }

  startLevel(levelId: string) {
    clear(this.ui);
    const v = new BattleView(this, levelId);
    this.setView(v);
    audio.playMusic('battle');
  }
}
