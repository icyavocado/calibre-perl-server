(() => {
  const dbName = 'cps-main';
  const dbVersion = 2;
  const htmlStoreName = 'html-cache';
  const metaStoreName = 'meta';
  const state = {
    htmlCache: new Map(),
    htmlRequests: new Map(),
    dbPromise: null,
  };

  const pageLinkSelector = 'a[href]';
  const browserBackSelector = 'a[data-browser-back]';
  const assetVersion = document.querySelector('meta[name="cps-asset-version"]')?.content || '0';

  function pageAuthState() {
    return document.querySelector('meta[name="cps-auth-state"]')?.content || 'anonymous';
  }

  function canUsePersistentHtmlCache() {
    return pageAuthState() !== 'authenticated';
  }

  function isCacheablePageRequest(url) {
    if (url.origin !== window.location.origin) {
      return false;
    }

    if (url.hash) {
      return false;
    }

    if (url.pathname.startsWith('/css/') || url.pathname.startsWith('/js/')) {
      return false;
    }

    if (url.pathname.startsWith('/download/')) {
      return false;
    }

    if (url.pathname === '/login') {
      return false;
    }

    if (url.pathname === '/logout') {
      return false;
    }

    const extensionMatch = url.pathname.match(/\.([a-z0-9]+)$/i);
    if (extensionMatch) {
      return false;
    }

    return true;
  }

  function getCacheableHref(link) {
    const href = link.getAttribute('href');
    if (!href) {
      return null;
    }

    const url = new URL(href, window.location.origin);
    return isCacheablePageRequest(url) ? url.toString() : null;
  }

  function openDb() {
    if (!('indexedDB' in window)) {
      return Promise.resolve(null);
    }

    if (state.dbPromise) {
      return state.dbPromise;
    }

    state.dbPromise = new Promise((resolve, reject) => {
      const request = window.indexedDB.open(dbName, dbVersion);

      request.onupgradeneeded = () => {
        const db = request.result;
        if (!db.objectStoreNames.contains(htmlStoreName)) {
          db.createObjectStore(htmlStoreName);
        }
        if (!db.objectStoreNames.contains(metaStoreName)) {
          db.createObjectStore(metaStoreName);
        }
      };

      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    }).catch(() => null);

    return state.dbPromise;
  }

  function openStore(db, storeName, mode) {
    if (!db.objectStoreNames.contains(storeName)) {
      return null;
    }

    const transaction = db.transaction(storeName, mode);
    return transaction.objectStore(storeName);
  }

  async function readMetaValue(key) {
    const db = await openDb();
    if (!db) {
      return null;
    }

    return new Promise((resolve) => {
      const store = openStore(db, metaStoreName, 'readonly');
      if (!store) {
        resolve(null);
        return;
      }

      const request = store.get(key);
      request.onsuccess = () => resolve(request.result ?? null);
      request.onerror = () => resolve(null);
    });
  }

  async function writeMetaValue(key, value) {
    const db = await openDb();
    if (!db) {
      return;
    }

    await new Promise((resolve) => {
      const store = openStore(db, metaStoreName, 'readwrite');
      if (!store) {
        resolve();
        return;
      }

      const transaction = store.transaction;
      store.put(value, key);
      transaction.oncomplete = () => resolve();
      transaction.onerror = () => resolve();
      transaction.onabort = () => resolve();
    });
  }

  async function clearHtmlCacheStore() {
    state.htmlCache.clear();

    const db = await openDb();
    if (!db) {
      return;
    }

    await new Promise((resolve) => {
      const store = openStore(db, htmlStoreName, 'readwrite');
      if (!store) {
        resolve();
        return;
      }

      const transaction = store.transaction;
      store.clear();
      transaction.oncomplete = () => resolve();
      transaction.onerror = () => resolve();
      transaction.onabort = () => resolve();
    });
  }

  async function ensureHtmlCacheVersion() {
    const storedVersion = await readMetaValue('assetVersion');
    if (storedVersion === assetVersion) {
      return;
    }

    await clearHtmlCacheStore();
    await writeMetaValue('assetVersion', assetVersion);
  }

  async function loadStoredHtml(cacheKey) {
    if (state.htmlCache.has(cacheKey)) {
      return state.htmlCache.get(cacheKey);
    }

    const db = await openDb();
    if (!db) {
      return null;
    }

    return new Promise((resolve) => {
      const store = openStore(db, htmlStoreName, 'readonly');
      if (!store) {
        resolve(null);
        return;
      }

      const request = store.get(cacheKey);

      request.onsuccess = () => {
        const html = typeof request.result === 'string' ? request.result : null;
        if (html) {
          state.htmlCache.set(cacheKey, html);
        }
        resolve(html);
      };

      request.onerror = () => resolve(null);
    });
  }

  async function storeHtml(cacheKey, html) {
    state.htmlCache.set(cacheKey, html);

    const db = await openDb();
    if (!db) {
      return;
    }

    await new Promise((resolve) => {
      const store = openStore(db, htmlStoreName, 'readwrite');
      if (!store) {
        resolve();
        return;
      }

      const transaction = store.transaction;
      store.put(html, cacheKey);
      transaction.oncomplete = () => resolve();
      transaction.onerror = () => resolve();
      transaction.onabort = () => resolve();
    });
  }

  function preloadHtml(href) {
    const url = new URL(href, window.location.origin);

    if (!isCacheablePageRequest(url)) {
      return Promise.resolve(null);
    }

    const cacheKey = `${pageAuthState()}:${url.toString()}`;

    if (state.htmlRequests.has(cacheKey)) {
      return state.htmlRequests.get(cacheKey);
    }

    const request = Promise.resolve(canUsePersistentHtmlCache() ? loadStoredHtml(cacheKey) : null)
      .then((cachedHtml) => {
        if (cachedHtml) {
          return cachedHtml;
        }

        return fetch(cacheKey, {
          credentials: 'same-origin',
          headers: {
            'X-Requested-With': 'prefetch',
          },
        })
          .then((response) => {
            if (!response.ok) {
              throw new Error(`prefetch failed: ${response.status}`);
            }

            return response.text();
          })
          .then(async (html) => {
            if (canUsePersistentHtmlCache()) {
              await storeHtml(cacheKey, html);
            }
            return html;
          });
      })
      .catch(() => null)
      .finally(() => {
        state.htmlRequests.delete(cacheKey);
      });

    state.htmlRequests.set(cacheKey, request);
    return request;
  }

  function isVisible(element) {
    const rect = element.getBoundingClientRect();
    return rect.bottom > 0 && rect.right > 0 && rect.top < window.innerHeight && rect.left < window.innerWidth;
  }

  function collectVisibleLinks() {
    const seen = new Set();
    const priorityLinks = [];
    const normalLinks = [];

    document.querySelectorAll(pageLinkSelector).forEach((link) => {
      const href = getCacheableHref(link);
      if (!href || seen.has(href) || !isVisible(link)) {
        return;
      }

      seen.add(href);

      if (link.dataset.prefetchPriority === 'high') {
        priorityLinks.push(href);
        return;
      }

      normalLinks.push(href);
    });

    return { priorityLinks, normalLinks };
  }

  function wirePreloadIntent(link) {
    const href = getCacheableHref(link);
    if (!href) {
      return;
    }

    const triggerPreload = () => {
      preloadHtml(href);
    };

    link.addEventListener('mouseenter', triggerPreload, { passive: true });
    link.addEventListener('focus', triggerPreload, { passive: true });
    link.addEventListener('touchstart', triggerPreload, { passive: true });
    link.addEventListener('pointerdown', triggerPreload, { passive: true });
  }

  function renderPrefetchedHtml(url, html) {
    window.history.pushState({}, '', url);
    document.open();
    document.write(html);
    document.close();
  }

  function reusePrefetchedHtml(event) {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) {
      return;
    }

    const link = event.target.closest(pageLinkSelector);
    if (!link) {
      return;
    }

    const url = getCacheableHref(link);
    if (!url) {
      return;
    }

    const cacheKey = `${pageAuthState()}:${url}`;

    event.preventDefault();

    Promise.resolve(state.htmlRequests.get(cacheKey))
      .then((pendingHtml) => pendingHtml || (canUsePersistentHtmlCache() ? loadStoredHtml(cacheKey) : null))
      .then((html) => {
        if (html) {
          renderPrefetchedHtml(url, html);
          return;
        }

        window.location.href = url;
      })
      .catch(() => {
        window.location.href = url;
      });
  }

  function handleBrowserBack(event) {
    const link = event.target.closest(browserBackSelector);
    if (!link) {
      return;
    }

    if (window.history.length > 1) {
      event.preventDefault();
      window.history.back();
    }
  }

  async function init() {
    const seen = new Set();

    await ensureHtmlCacheVersion();

    document.querySelectorAll(pageLinkSelector).forEach((link) => {
      const href = link.getAttribute('href');
      if (!href || seen.has(link)) {
        return;
      }

      seen.add(link);
      wirePreloadIntent(link);
    });

    document.addEventListener('click', handleBrowserBack);
    document.addEventListener('click', reusePrefetchedHtml);
    const { priorityLinks, normalLinks } = collectVisibleLinks();
    await Promise.all(priorityLinks.map((href) => preloadHtml(href)));
    normalLinks.forEach((href) => {
      preloadHtml(href);
    });
  }

  window.cpsMain = state;
  init();
})();
