// Where the game is running: Home Screen app, Safari tab, or embedded in another page (e.g. an artifact viewer).
export const STANDALONE_URL = 'https://jjborja5.github.io/pvz-ultimate-3d/';

export function isStandalone() {
  const nav = navigator as Navigator & { standalone?: boolean };
  return nav.standalone === true || (typeof matchMedia !== 'undefined' && (matchMedia('(display-mode: standalone)').matches || matchMedia('(display-mode: fullscreen)').matches));
}

export function isEmbedded() {
  try {
    return window.self !== window.top;
  } catch {
    return true;
  }
}

export function isIOS() {
  return /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
}

export function registerServiceWorker() {
  if (!import.meta.env.PROD || isEmbedded() || !('serviceWorker' in navigator) || location.protocol !== 'https:') return;
  navigator.serviceWorker.register('./sw.js').catch(() => {});
}
