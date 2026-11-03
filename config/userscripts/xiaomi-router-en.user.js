// ==UserScript==
// @name         Xiaomi router: English
// @namespace    simple_nix
// @version      1.0
// @description  Translate the Xiaomi router's Chinese-only admin pages to English.
// @match        http://192.168.31.1/*
// @run-at       document-start
// @all-frames   true
// @grant        none
// ==/UserScript==

(function () {
  'use strict';

  // Whole strings first; any Chinese left after that gets the same table
  // applied piece by piece (longest first), so strings that combine known
  // parts still translate.
  const DICT = {
    // Login page
    '小米路由器': 'Xiaomi Router',
    '欢迎使用小米路由器': 'Welcome to Xiaomi Router',
    '扫描二维码，下载米家APP': 'Scan the QR code to get the Mi Home app',
    '随时随地管理你的路由器': 'Manage your router from anywhere',
    '官方网站': 'Official website',
    '使用小米WiFi APP管理您的路由器': 'Manage your router with the Xiaomi WiFi app',
    '易用': 'Easy',
    '全新小米WiFi APP 极简操作，享受生活': 'The new Xiaomi WiFi app: simple to use',
    '安全': 'Secure',
    '7x24小时安全防护 一键拉黑蹭网老王': '24/7 protection, block WiFi freeloaders in one tap',
    '加速': 'Fast',
    '提高带宽，游戏加速 团战胜人一筹': 'More bandwidth, faster gaming',
    '赚钱': 'Earn',
    '分享WiFi赚点钱 欢迎老王来蹭网': 'Share your WiFi and earn a little',
    '现在安装': 'Install now',
    '我已安装，现在打开': 'Already installed, open it',
    '本地管理小米路由器': 'Manage the router locally',
    '官方微博': 'Weibo',
    '官方微信': 'WeChat',
    '用户社区': 'Community',
    '常见问题': 'FAQ',
    '服务热线': 'Support hotline',
    '修改路由器名称': 'Rename router',
    '系统升级': 'System update',
    '下载米家APP': 'Get the Mi Home app',
    '重启': 'Reboot',
    '注销': 'Log out',
    '请输入路由器管理密码': 'Router admin password',
    '登录': 'Log in',
    '密码错误': 'Wrong password',

    // Top menu
    '路由状态': 'Status',
    '存储功能': 'Storage',
    '常用设置': 'Settings',
    '高级设置': 'Advanced',
    '添加Mesh子路由': 'Add Mesh node',

    // Status page
    '终端设备': 'Devices',
    '互联网': 'Internet',
    '带宽': 'Bandwidth ',
    '频段': 'band',
    'Wi-Fi名称': 'Wi-Fi name',
    'Wi-Fi密码': 'Wi-Fi password',
    '连接设备数量': 'Connected devices',
    '设置': 'Settings',
    '路由器型号': 'Router model',
    '系统ROM版本': 'ROM version',
    'MAC地址': 'MAC address',
    'Xiaomi路由器': 'Xiaomi Router ',
    '路由器': 'router',
    '稳定版': 'stable',
    '外网状态': 'internet status',
    '连接类型': 'Connection type',
    'IP地址': 'IP address',
    '网关地址': 'Gateway',
    '外网带宽': 'internet bandwidth',
    '下载带宽': 'Download bandwidth',
    '上传带宽': 'Upload bandwidth',
    '手工设置': 'Set manually',
    '双WAN模式下，不支持在此处设置外网带宽': 'In dual-WAN mode, internet bandwidth can\'t be set here',
    '系统版本': 'System version',
    '检测到最新版本为': 'New firmware available: ',
    '点击此处立即升级': 'update now',
    '你的浏览器禁止了Javascript功能，会造成无法使用系统进行路由器管理，请开启。':
      'JavaScript is disabled in your browser; enable it to manage the router.',

    // Common buttons
    '确定': 'OK',
    '取消': 'Cancel',
    '保存': 'Save',
    '应用': 'Apply',
    '关闭': 'Close',
    '返回': 'Back',

    // Chinese punctuation left between translated pieces
    '：': ': ',
    '，': ', ',
    '。': '. ',
    '（': ' (',
    '）': ')',
  };

  // Matched only as a whole string: single characters that would wrongly
  // hit names (e.g. the router's own name "FastInet (家)").
  const EXACT = {
    '台': 'devices',
  };

  const ZH = /[㐀-鿿。（），：]/;
  const keys = Object.keys(DICT).sort((a, b) => b.length - a.length);
  const escape = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const PIECES = new RegExp(keys.map(escape).join('|'), 'g');

  function tr(s) {
    if (!s || !ZH.test(s)) return s;
    const t = s.trim();
    const whole = EXACT[t] || DICT[t];
    if (whole) return s.replace(t, whole);
    return s.replace(PIECES, (m) => DICT[m]).replace(/ {2,}/g, ' ');
  }

  const ATTRS = ['placeholder', 'title', 'alt', 'aria-label', 'value'];

  function fixAttrs(el) {
    for (const a of ATTRS) {
      // value: only on buttons; never rewrite what a user typed into a field.
      if (a === 'value' && !(el.tagName === 'INPUT' && /^(button|submit|reset)$/i.test(el.type))) continue;
      const v = el.getAttribute(a);
      if (v) { const n = tr(v); if (n !== v) el.setAttribute(a, n); }
    }
  }

  function fixText(node) {
    const p = node.parentElement;
    if (p && (p.tagName === 'SCRIPT' || p.tagName === 'STYLE' || p.tagName === 'TEXTAREA')) return;
    const v = node.nodeValue, n = tr(v);
    if (n !== v) node.nodeValue = n;
  }

  function walk(root) {
    if (root.nodeType === Node.TEXT_NODE) return fixText(root);
    if (root.nodeType !== Node.ELEMENT_NODE) return;
    fixAttrs(root);
    const w = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT);
    for (let n; (n = w.nextNode());) {
      if (n.nodeType === Node.TEXT_NODE) fixText(n); else fixAttrs(n);
    }
  }

  function fixTitle() {
    const n = tr(document.title);
    if (n !== document.title) document.title = n;
  }

  new MutationObserver((muts) => {
    for (const m of muts) {
      if (m.type === 'characterData') fixText(m.target);
      else if (m.type === 'attributes') fixAttrs(m.target);
      else m.addedNodes.forEach(walk);
    }
    fixTitle();
  }).observe(document, {
    subtree: true, childList: true, characterData: true,
    attributes: true, attributeFilter: ATTRS,
  });

  if (document.documentElement) walk(document.documentElement);
  fixTitle();
})();
