// ==UserScript==
// @name         eda.yandex.ru: always light theme
// @namespace    simple_nix
// @version      1.0
// @description  Make eda.yandex.ru ignore the system dark theme and stay light.
// @match        https://eda.yandex.ru/*
// @match        https://*.eda.yandex.ru/*
// @run-at       document-start
// @grant        unsafeWindow
// @grant        GM_xmlhttpRequest
// @connect      self
// @connect      yandex.ru
// @connect      yandex.net
// @connect      yastatic.net
// ==/UserScript==

(function () {
  'use strict';

  // "dark" becomes a query that never matches; "light" one that always does.
  const NEVER = 'prefers-color-scheme: __never';
  const ALWAYS = 'min-width: 0px';
  const DARK = /prefers-color-scheme\s*:\s*dark/gi;
  const LIGHT = /prefers-color-scheme\s*:\s*light/gi;
  const fix = (s) => String(s).replace(DARK, NEVER).replace(LIGHT, ALWAYS);
  const mentions = (s) => /prefers-color-scheme/i.test(s);

  // 1. JavaScript: window.matchMedia('(prefers-color-scheme: dark)') -> false.
  const W = typeof unsafeWindow !== 'undefined' ? unsafeWindow : window;
  const origMatchMedia = W.matchMedia.bind(W);
  W.matchMedia = function (q) { return origMatchMedia(fix(q)); };

  // 2. Native form controls / scrollbars.
  const base = document.createElement('style');
  base.textContent = ':root { color-scheme: light only !important; }';
  (document.head || document.documentElement).appendChild(base);

  // 3. CSS: rewrite @media (prefers-color-scheme: ...) rules.
  const done = new WeakSet();

  function fixRules(rules) {
    for (const r of rules) {
      if (r.media && mentions(r.media.mediaText)) r.media.mediaText = fix(r.media.mediaText);
      if (r.cssRules) fixRules(r.cssRules);
      if (r.styleSheet) fixSheet(r.styleSheet); // @import
    }
  }

  function fixSheet(sheet) {
    if (!sheet || done.has(sheet)) return;
    let rules;
    try {
      rules = sheet.cssRules;
    } catch (e) {
      done.add(sheet);
      refetch(sheet); // cross-origin: the browser won't let us read it
      return;
    }
    if (!rules) return;
    done.add(sheet);
    fixRules(rules);
  }

  // Cross-origin sheet: download it ourselves, rewrite, swap it in.
  function refetch(sheet) {
    const href = sheet.href;
    const node = sheet.ownerNode;
    if (!href || !node) return;
    GM_xmlhttpRequest({
      method: 'GET',
      url: href,
      onload(res) {
        if (res.status !== 200 || !mentions(res.responseText)) return;
        const css = fix(res.responseText).replace(
          /url\(\s*(['"]?)([^'")]+)\1\s*\)/g,
          (m, q, u) => (/^(data:|https?:|\/\/|#)/.test(u) ? m : `url("${new URL(u, href)}")`)
        );
        const style = document.createElement('style');
        style.textContent = css;
        node.after(style);
        done.add(style.sheet);
        sheet.disabled = true;
      },
    });
  }

  function scan() {
    for (const s of document.styleSheets) fixSheet(s);
  }

  // Styles keep arriving while the app loads; rescan when they do.
  new MutationObserver((muts) => {
    for (const m of muts) {
      for (const n of m.addedNodes) {
        if (n.nodeName === 'LINK') n.addEventListener('load', scan, { once: true });
      }
    }
    scan();
  }).observe(document.documentElement, { childList: true, subtree: true });

  document.addEventListener('DOMContentLoaded', scan);
  window.addEventListener('load', scan);
  // CSS-in-JS can add rules without adding nodes; a few late passes catch those.
  [1000, 3000, 8000].forEach((t) => setTimeout(() => {
    for (const s of document.styleSheets) { if (s.ownerNode && s.ownerNode.tagName === 'STYLE') done.delete(s); }
    scan();
  }, t));
})();
