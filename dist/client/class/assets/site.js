/* Class site shell: sign-in, progress ticks, readiness checks, spaced recall and language.
   Works on the class server (sign-in, server progress, live points) and on a static host (browser storage only). */
(function () {
  'use strict';
  const TOKEN_KEY = 'lessonkit:class-token';
  const LANG_KEY = 'lessonkit:lang';
  const LANG_NAMES = { en: 'English', zh: '中文（简体）', es: 'Español', hi: 'हिन्दी' };
  const RECALL_DAYS = 2;
  const store = {
    get(k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
    set(k, v) { try { v == null ? localStorage.removeItem(k) : localStorage.setItem(k, v); } catch (e) { /* storage unavailable */ } },
    json(k) { try { return JSON.parse(localStorage.getItem(k) || 'null'); } catch (e) { return null; } },
  };
  const DEVICE = (() => { let d = store.get('lessonkit:device'); if (!d) { d = [...crypto.getRandomValues(new Uint8Array(12))].map((b) => b.toString(16).padStart(2, '0')).join(''); store.set('lessonkit:device', d); } return d; })();
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
  let classMode = false, me = null, progress = null, dict = null, lang = 'en';

  function toast(text) {
    const el = document.createElement('div'); el.className = 'toast'; el.setAttribute('role', 'status'); el.textContent = text;
    document.body.append(el); setTimeout(() => el.remove(), 2600);
  }
  const tr = (en) => (lang !== 'en' && dict && dict[lang] && dict[lang][en]) || en;
  async function api(path, opts = {}) {
    const token = store.get(TOKEN_KEY);
    const headers = Object.assign({ 'Content-Type': 'application/json', 'X-Device-Id': DEVICE }, token ? { Authorization: `Bearer ${token}` } : {});
    return fetch(path, Object.assign({ cache: 'no-store' }, opts, { headers }));
  }

  /* ---------- Language ---------- */
  // Material cards with language versions: play and open the reader's language, fall back to English.
  function applyAlternates() {
    $$('[data-alts]').forEach((card) => {
      let alts = null;
      try { alts = JSON.parse(card.dataset.alts); } catch (e) { return; }
      const pick = alts[lang] || alts.en;
      const audio = card.querySelector('audio');
      if (audio && audio.getAttribute('src') !== pick.href && audio.paused) { audio.setAttribute('src', pick.href); audio.load(); }
      const btn = card.querySelector('.m-actions .btn');
      if (btn) btn.setAttribute('href', pick.href);
      const meta = card.querySelector('.m-actions .meta');
      if (meta) meta.textContent = pick.meta + (alts[lang] && lang !== 'en' ? ' · AI' : '');
    });
  }
  function applyLang() {
    $$('[data-t]').forEach((el) => {
      if (el.dataset.en == null) el.dataset.en = el.textContent;
      el.textContent = tr(el.dataset.en);
    });
    applyAlternates();
    document.documentElement.lang = lang === 'zh' ? 'zh-Hans' : lang;
    $$('.ai-note').forEach((el) => { el.hidden = lang === 'en'; });
  }
  async function initLang() {
    const base = document.documentElement.dataset.base || '';
    try { const r = await fetch(`${base}/assets/site-i18n.json`, { cache: 'no-cache' }); if (r.ok) dict = await r.json(); } catch (e) { dict = null; }
    const langs = ['en', ...Object.keys(dict || {})];
    const sel = document.getElementById('site-lang');
    if (!sel || langs.length < 2) return;
    sel.replaceChildren(...langs.map((k) => new Option(LANG_NAMES[k] || k, k)));
    const want = store.get(LANG_KEY);
    lang = langs.includes(want) ? want : 'en';
    sel.value = lang;
    sel.closest('.lang').hidden = false;
    sel.addEventListener('change', () => { lang = sel.value; store.set(LANG_KEY, lang); applyLang(); paint(); });
    applyLang();
  }

  /* ---------- Account ---------- */
  function setAcct() {
    const btn = document.querySelector('.acct-btn');
    if (!btn) return;
    const label = btn.querySelector('.acct-label');
    const form = document.querySelector('.acct-form'), inBox = document.querySelector('.acct-in');
    if (me) {
      label.textContent = me.name.split(' ')[0];
      label.removeAttribute('data-t');
      btn.classList.add('in');
      form.hidden = true; inBox.hidden = false;
      inBox.querySelector('.acct-who').textContent = me.name;
      const live = Object.values((progress && progress.live) || {}).reduce((a, b) => a + b, 0);
      inBox.querySelector('.acct-pts').textContent = `${tr('Live points this term')}: ${live}`;
    } else {
      label.dataset.en = 'Sign in'; label.setAttribute('data-t', ''); label.textContent = tr('Sign in');
      btn.classList.remove('in');
      form.hidden = false; inBox.hidden = true;
    }
    $$('.me-line').forEach((el) => { el.textContent = me ? `${tr('Signed in as')} ${me.name}` : tr('Sign in to keep your work on any device.'); });
  }
  function initAcct() {
    const btn = document.querySelector('.acct-btn'), pop = document.getElementById('acct-pop');
    if (!btn || !pop) return;
    const toggle = (open) => { pop.hidden = !open; btn.setAttribute('aria-expanded', String(open)); if (open) { const i = pop.querySelector('input:not([hidden])'); if (i && !me) i.focus(); } };
    btn.addEventListener('click', () => toggle(pop.hidden));
    document.addEventListener('click', (e) => { if (!pop.hidden && !pop.contains(e.target) && !btn.contains(e.target)) toggle(false); });
    document.addEventListener('keydown', (e) => { if (e.key === 'Escape') toggle(false); });
    pop.querySelector('.acct-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const input = pop.querySelector('#acct-key'), msg = pop.querySelector('.acct-msg');
      msg.textContent = '';
      try {
        const r = await api('/api/login', { method: 'POST', body: JSON.stringify({ pin: input.value.trim() }) });
        if (r.status === 429) { msg.textContent = tr('Too many tries. Wait a minute and try again.'); return; }
        if (!r.ok) { msg.textContent = tr('That key was not found. Check your key slip.'); return; }
        const j = await r.json();
        store.set(TOKEN_KEY, j.token);
        input.value = '';
        document.dispatchEvent(new CustomEvent('class:signed-in'));
        await loadMe();
        toggle(false);
        toast(`${tr('Welcome')}, ${me ? me.name.split(' ')[0] : ''}`);
      } catch (err) { msg.textContent = tr('Could not reach the class computer.'); }
    });
    pop.querySelector('.acct-out').addEventListener('click', async () => {
      try { await api('/api/logout', { method: 'POST', body: '{}' }); } catch (e) { /* offline */ }
      store.set(TOKEN_KEY, null); me = null; progress = null;
      setAcct(); paint(); toggle(false);
    });
  }
  async function loadMe() {
    if (!store.get(TOKEN_KEY)) { me = null; setAcct(); return; }
    try {
      const r = await api('/api/progress');
      if (r.status === 401) { store.set(TOKEN_KEY, null); me = null; progress = null; }
      else if (r.ok) { progress = await r.json(); me = { name: progress.name }; }
    } catch (e) { /* offline: keep local progress */ }
    setAcct(); paint();
  }

  /* ---------- Progress ---------- */
  function lessonDone(id) {
    const loc = store.json(`lessonkit:${id}`);
    const local = loc && loc.res ? Object.keys(loc.res).length : 0;
    const srv = progress && progress.pages && progress.pages[id];
    return Math.max(local, srv && srv.done || 0);
  }
  function pnpFilled(id) {
    const loc = store.json(`lessonkit:${id}`);
    const local = loc && loc.fields ? Object.values(loc.fields).filter((v) => String(v).trim()).length + (loc.profile && loc.profile.first && loc.profile.last && loc.profile.netid ? 1 : 0) : 0;
    const srv = progress && progress.pages && progress.pages[id];
    return Math.max(local, srv && srv.filled || 0);
  }
  function setBar(el, done, total, text) {
    const bar = el.querySelector('.bar i'), pt = el.querySelector('.ptext');
    const frac = total ? Math.min(1, done / total) : 0;
    if (bar) bar.style.width = `${Math.round(frac * 100)}%`;
    if (pt) pt.textContent = text != null ? text : `${done} / ${total}`;
    el.classList.toggle('complete', total > 0 && done >= total);
  }
  function paint() {
    $$('[data-page-id]').forEach((el) => setBar(el, lessonDone(el.dataset.pageId), Number(el.dataset.graded)));
    $$('[data-pnp-export]').forEach((el) => {
      const exported = progress && progress.exports && progress.exports[el.dataset.pnpExport];
      const total = Number(el.dataset.pnpTotal || 0);
      if (el.dataset.pnpId) {
        const n = pnpFilled(el.dataset.pnpId);
        setBar(el, n, total, exported ? `✓ ${tr('Exported')}` : n ? `${n} / ${total}` : tr('Not started'));
      } else {
        const pt = el.querySelector('.ptext');
        if (pt) pt.textContent = exported ? `✓ ${tr('Exported')}` : '';
      }
    });
    $$('[data-live-session]').forEach((el) => {
      const pts = progress && progress.live && progress.live[el.dataset.liveSession] || 0;
      const pt = el.querySelector('.ptext'); if (pt) pt.textContent = String(pts);
    });
    paintRecall();
  }

  /* ---------- Readiness check and spaced recall ---------- */
  const checkKey = (s) => `classsite:check:${s}`;
  function paintRecall() {
    const now = Date.now();
    $$('[data-recall]').forEach((el) => {
      const h = store.json(checkKey(el.dataset.recall)) || [];
      if (!h.length) { el.textContent = tr('Take the readiness check first.'); return; }
      const last = h[h.length - 1];
      const due = h.length < 2 && now - h[0].at >= RECALL_DAYS * 864e5;
      el.textContent = h.length >= 2 ? `${tr('Recall done')}: ${h[0].score}/3 → ${last.score}/3` : due ? tr('Due now: retake the readiness check.') : `${tr('Come back on')} ${new Date(h[0].at + RECALL_DAYS * 864e5).toLocaleDateString()}`;
    });
    $$('[data-due]').forEach((el) => {
      const h = store.json(checkKey(el.dataset.due)) || [];
      el.hidden = !(h.length === 1 && now - h[0].at >= RECALL_DAYS * 864e5);
    });
  }
  function initChecks() {
    $$('[data-check]').forEach((card) => {
      const form = card.querySelector('.check-form'), result = card.querySelector('.check-result');
      const show = (score) => {
        result.hidden = false;
        result.querySelector('.score').textContent = `${score} / 3`;
        const path = score >= 3 ? 'stretch' : score === 2 ? 'bridge' : 'core';
        $$('.path', result).forEach((p) => { p.hidden = p.dataset.path !== path; });
      };
      const hist = store.json(checkKey(card.dataset.check)) || [];
      if (hist.length) show(hist[hist.length - 1].score);
      form.addEventListener('submit', (e) => {
        e.preventDefault();
        let score = 0, answered = 0;
        $$('.q', form).forEach((q, qi) => {
          const pick = form.querySelector(`input[name="q${qi}"]:checked`);
          $$('.fb', q).forEach((f) => { f.hidden = true; });
          q.classList.remove('right', 'wrong');
          if (!pick) return;
          answered += 1;
          const ok = pick.value === q.dataset.answer;
          if (ok) score += 1;
          q.classList.add(ok ? 'right' : 'wrong');
          const fb = q.querySelector(`.fb[data-fb="${pick.value}"]`); if (fb) fb.hidden = false;
        });
        if (answered < 3) { toast(tr('Answer all three questions first.')); return; }
        const h = store.json(checkKey(card.dataset.check)) || [];
        h.push({ score, at: Date.now() });
        store.set(checkKey(card.dataset.check), JSON.stringify(h.slice(-6)));
        show(score);
        paintRecall();
      });
    });
  }

  /* ---------- Small things ---------- */
  function initCopy() {
    $$('[data-copy]').forEach((b) => b.addEventListener('click', async () => {
      try { await navigator.clipboard.writeText(b.dataset.copy); toast(tr('Copied')); }
      catch (e) { const code = b.parentElement.querySelector('code'); if (code) { const r = document.createRange(); r.selectNodeContents(code); const s = getSelection(); s.removeAllRanges(); s.addRange(r); } }
    }));
  }
  async function detectClass() {
    if (document.documentElement.dataset.target === 'public') return;
    try {
      const r = await fetch('/api/ping', { cache: 'no-store' });
      const j = r.ok ? await r.json() : null;
      classMode = !!(j && j.app);
    } catch (e) { classMode = false; }
    $$('[data-class-only]').forEach((el) => { el.hidden = !classMode; });
    if (classMode) { initAcct(); await loadMe(); }
  }
  // Refresh ticks when the student comes back from a lesson tab.
  window.addEventListener('storage', (e) => { if (e.key && e.key.startsWith('lessonkit:')) paint(); });
  document.addEventListener('visibilitychange', () => { if (!document.hidden) { if (classMode && me) loadMe(); else paint(); } });

  initChecks(); initCopy(); paint();
  initLang().then(() => detectClass()).then(() => applyLang());
})();
