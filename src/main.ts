import './styles.css';
import { App } from './app';
import { registerServiceWorker } from './ui/platform';

// Block iOS Safari pinch-zoom / double-tap zoom / long-press callouts during play.
document.addEventListener('gesturestart', (e) => e.preventDefault());
document.addEventListener('dblclick', (e) => e.preventDefault());
document.addEventListener('contextmenu', (e) => e.preventDefault());
document.addEventListener(
  'touchmove',
  (e) => {
    const t = e.target as HTMLElement;
    if (!t.closest('.scroll, .scroll-x, .world-tabs, .alm-list, .seed-grid, .zlist, .seed-panel, .alm-detail, .packets, textarea')) e.preventDefault();
  },
  { passive: false },
);

function boot() {
  const canvas = document.getElementById('game') as HTMLCanvasElement;
  const ui = document.getElementById('ui') as HTMLElement;
  const loading = document.getElementById('loading');
  try {
    const app = new App(canvas, ui);
    app.showScreen('title');
    (window as unknown as { __app: App }).__app = app;
  } catch (err) {
    console.error(err);
    ui.innerHTML = `<div class="fatal"><b>Could not start 3D graphics.</b><p>${String((err as Error)?.message ?? err)}</p><p>Make sure WebGL is enabled in Safari settings.</p></div>`;
  } finally {
    loading?.remove();
  }
}

registerServiceWorker();

// Let the loading screen paint first.
requestAnimationFrame(() => setTimeout(boot, 30));
