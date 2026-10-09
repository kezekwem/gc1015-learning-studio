/* Study mode: the session notes beside the interactive lesson or lab, moving together.
   The framed page (lesson.html?embed=study) reports each screen it shows; the notes highlight and scroll to the
   sections that screen cites. "Practice" buttons in the notes send the frame to the screens that use a section. */
(function () {
  'use strict';
  const data = JSON.parse(document.getElementById('study-data').textContent);
  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
  const el = (tag, attrs = {}, ...kids) => {
    const n = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs)) {
      if (v == null || v === false) continue;
      if (k.startsWith('on')) n.addEventListener(k.slice(2), v);
      else if (k === 'class') n.className = v;
      else if (k === 'html') n.innerHTML = v;
      else n.setAttribute(k, v === true ? '' : v);
    }
    for (const c of kids.flat()) if (c != null && c !== false) n.append(c instanceof Node ? c : document.createTextNode(String(c)));
    return n;
  };
  const store = {
    get(k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch (e) { /* storage unavailable */ } },
    json(k) { try { return JSON.parse(localStorage.getItem(k) || 'null'); } catch (e) { return null; } },
  };
  const frame = $('#st-frame'), body = $('.st-notes-body'), toc = $('#st-toc'), here = $('.st-here'), main = $('.st-main');
  let page = data.pages[new URLSearchParams(location.search).get('p')] ? new URLSearchParams(location.search).get('p') : Object.keys(data.pages)[0];
  let notes = null, current = null, follow = store.get('study:follow') !== 'off', userScrollAt = 0, autoScrolling = false;

  /* ---------- Layout: split, mobile panes ---------- */
  const narrow = () => matchMedia('(max-width: 900px)').matches;
  function pane(which) { main.dataset.pane = which; $$('.st-tabs button').forEach((b) => b.setAttribute('aria-selected', String(b.dataset.pane === which))); }
  $$('.st-tabs button').forEach((b) => b.addEventListener('click', () => pane(b.dataset.pane)));
  const split = Number(store.get('study:split')) || 42;
  main.style.setProperty('--split', `${split}%`);
  const divider = $('.st-divider');
  divider.addEventListener('pointerdown', (e) => {
    divider.setPointerCapture(e.pointerId);
    main.classList.add('dragging');
    const move = (ev) => {
      const r = main.getBoundingClientRect();
      const pct = Math.min(70, Math.max(24, ((ev.clientX - r.left) / r.width) * 100));
      main.style.setProperty('--split', `${pct.toFixed(1)}%`);
    };
    const up = () => { main.classList.remove('dragging'); divider.removeEventListener('pointermove', move); store.set('study:split', parseFloat(main.style.getPropertyValue('--split'))); };
    divider.addEventListener('pointermove', move);
    divider.addEventListener('pointerup', up, { once: true });
  });
  divider.addEventListener('keydown', (e) => {
    if (e.key !== 'ArrowLeft' && e.key !== 'ArrowRight') return;
    const now = parseFloat(main.style.getPropertyValue('--split')) || 42;
    const next = Math.min(70, Math.max(24, now + (e.key === 'ArrowRight' ? 3 : -3)));
    main.style.setProperty('--split', `${next}%`); store.set('study:split', next);
  });
  const followBox = $('#st-follow');
  followBox.checked = follow;
  followBox.addEventListener('change', () => { follow = followBox.checked; store.set('study:follow', follow ? 'on' : 'off'); if (follow && current) reveal(current.refs[0]); });
  body.addEventListener('scroll', () => { if (!autoScrolling) userScrollAt = Date.now(); }, { passive: true });

  /* ---------- Notes ---------- */
  function doneSet() {
    const s = notes && store.json(`lessonkit:${notes.lesson}`);
    return new Set(Object.keys((s && s.res) || {}));
  }
  function render() {
    body.replaceChildren();
    toc.replaceChildren(el('option', { value: '' }, 'Jump to a section'));
    if (!notes) { body.append(el('p', { class: 'muted' }, 'Notes are not available for this page.')); return; }
    $('.st-notes-title').textContent = notes.title;
    const done = doneSet();
    notes.sections.forEach((sec) => {
      const uses = notes.practise[sec.id] || [];
      const finished = uses.length && uses.every((u) => done.has(u.id));
      toc.append(el('option', { value: sec.id }, `${sec.level > 2 ? '   ' : ''}${finished ? '✓ ' : ''}${sec.short || sec.title}`));
      const practise = uses.length ? el('div', { class: 'st-practise' }, el('span', {}, 'Practice'),
        uses.map((u) => el('button', { type: 'button', class: `st-go${done.has(u.id) ? ' done' : ''}`, 'data-screen': u.id, title: u.title, onclick: () => goScreen(u.i) },
          done.has(u.id) ? '✓ ' : '', `Screen ${u.i + 1}`, u.tier !== 'Core' ? el('small', {}, u.tier) : null))) : null;
      body.append(el('section', { class: `st-sec lvl${sec.level}${finished ? ' finished' : ''}`, 'data-sec': sec.id, id: `n-${sec.id}` },
        el(sec.level <= 2 ? 'h2' : 'h3', { html: sec.title }), practise, el('div', { class: 'st-content', html: sec.html })));
    });
    if (current) mark(current);
  }
  // Ticks change as the student answers; update them in place so a click in the notes is never lost to a redraw.
  function updateDone() {
    if (!notes) return;
    const done = doneSet();
    $$('.st-go', body).forEach((b) => {
      const ok = done.has(b.dataset.screen);
      if (ok === b.classList.contains('done')) return;
      b.classList.toggle('done', ok);
      if (ok) b.prepend('✓ ');
    });
    notes.sections.forEach((sec, k) => {
      const uses = notes.practise[sec.id] || [];
      const finished = uses.length > 0 && uses.every((u) => done.has(u.id));
      const node = body.querySelector(`[data-sec="${CSS.escape(sec.id)}"]`);
      if (node) node.classList.toggle('finished', finished);
      const opt = toc.options[k + 1];
      if (opt) opt.textContent = `${sec.level > 2 ? '   ' : ''}${finished ? '✓ ' : ''}${sec.short || sec.title}`;
    });
  }
  function reveal(id, flash) {
    const sec = id && body.querySelector(`[data-sec="${CSS.escape(id)}"]`);
    if (!sec) return;
    autoScrolling = true;
    body.scrollTo({ top: sec.offsetTop - 8, behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' });
    setTimeout(() => { autoScrolling = false; }, 700);
    if (flash) { sec.classList.remove('flash'); void sec.offsetWidth; sec.classList.add('flash'); }
  }
  function mark(sc) {
    $$('.st-sec.here', body).forEach((s) => s.classList.remove('here'));
    $$('.st-go.on', body).forEach((b) => b.classList.remove('on'));
    sc.refs.forEach((r) => { const s = body.querySelector(`[data-sec="${CSS.escape(r)}"]`); if (s) s.classList.add('here'); });
    $$(`.st-go[data-screen="${CSS.escape(sc.id)}"]`, body).forEach((b) => b.classList.add('on'));
    here.hidden = false;
    $('.st-here-text').textContent = `Screen ${sc.i + 1}: ${sc.title}`;
    $('.st-here-refs').textContent = sc.refs.length ? `Notes: ${sc.refs.map((r) => (notes.sections.find((x) => x.id === r) || {}).short || r).join(', ')}` : 'No notes cited on this screen';
  }
  function goScreen(i) {
    frame.contentWindow.postMessage({ type: 'lk:go', i }, location.origin);
    if (narrow()) pane('practice');
  }

  /* ---------- Messages from the framed lesson ---------- */
  window.addEventListener('message', (e) => {
    if (e.origin !== location.origin || !e.data || !notes || e.data.lesson !== notes.lesson) return;
    const m = e.data;
    if (m.type === 'lk:screen') {
      current = m;
      updateDone();
      mark(m);
      // Follow along only when the student is not reading elsewhere in the notes right now.
      if (follow && m.refs.length && Date.now() - userScrollAt > 6000 && !narrow()) reveal(m.refs[0]);
    }
    if (m.type === 'lk:ref') {
      if (narrow()) pane('notes');
      userScrollAt = 0;
      reveal(m.id, true);
    }
  });
  $('.st-here-back').addEventListener('click', () => { if (current) { if (narrow()) pane('practice'); } });
  $('.st-here-notes').addEventListener('click', () => { if (current && current.refs[0]) { userScrollAt = 0; reveal(current.refs[0], true); } });
  toc.addEventListener('change', () => { if (toc.value) { userScrollAt = Date.now(); reveal(toc.value, true); toc.value = ''; } });

  /* ---------- Lesson / lab switch ---------- */
  async function load(p) {
    page = p;
    const cfg = data.pages[p];
    $$('.st-switch button').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.page === p)));
    history.replaceState(null, '', `?p=${p}`);
    current = null; here.hidden = true;
    frame.src = `${cfg.src}?embed=study`;
    frame.title = cfg.title;
    try { const r = await fetch(cfg.notes, { cache: 'no-cache' }); notes = r.ok ? await r.json() : null; } catch (e) { notes = null; }
    render();
  }
  $$('.st-switch button').forEach((b) => b.addEventListener('click', () => { if (b.dataset.page !== page) load(b.dataset.page); }));
  window.addEventListener('storage', (e) => { if (notes && e.key === `lessonkit:${notes.lesson}`) updateDone(); });
  pane('practice');
  load(page);
})();
