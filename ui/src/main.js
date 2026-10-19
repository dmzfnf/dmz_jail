import './style.css';

const $ = (s) => document.querySelector(s);
const post = (name, data = {}) =>
  fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data)
  }).catch(() => {});

let players = [], jailed = [], selected = null, settings = { min: 1, max: 240, times: [], reasons: [] };

const clock = (s) => {
  s = Math.max(0, Math.floor(s));
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
  const p = (n) => String(n).padStart(2, '0');
  return h ? `${h}:${p(m)}:${p(sec)}` : `${p(m)}:${p(sec)}`;
};
const el = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; };

function renderPlayers() {
  const q = $('#search').value.trim().toLowerCase();
  const ul = $('#players'); ul.innerHTML = '';
  const shown = players.filter((p) => !q || p.name.toLowerCase().includes(q) || String(p.id) === q);
  if (!shown.length) { ul.append(el('li', 'empty', 'Aucun joueur trouvé.')); return; }
  shown.forEach((p) => {
    const li = el('li', p.id === selected ? 'selected' : '');
    li.append(el('span', 'pid', '#' + p.id), el('span', 'name', p.name));
    if (p.jailed) li.append(el('span', 'tag', 'En prison'));
    li.onclick = () => { selected = selected === p.id ? null : p.id; renderPlayers(); updateSummary(); };
    ul.append(li);
  });
}

const pct = (j) => Math.min(100, Math.max(0, (j.remaining / j.total) * 100));

function renderJailed() {
  $('#count').textContent = jailed.length;
  const ul = $('#jailed'); ul.innerHTML = '';
  if (!jailed.length) { ul.append(el('li', 'empty', 'Aucun détenu pour le moment.')); return; }
  jailed.forEach((j) => {
    const li = el('li', 'inmate');
    const top = el('div', 'inmate-top');
    const right = el('div', 'inmate-right');
    const timer = el('div', 'inmate-timer');
    timer.append(el('span', 'inmate-timer-label', 'Temps restant'), (j.timeEl = el('span', 'inmate-time', clock(j.remaining))));
    const btn = el('button', 'release', 'Libérer');
    btn.onclick = () => post('release', { license: j.license });
    right.append(timer, btn);
    top.append(el('span', 'name', j.name), el('span', j.online ? 'status' : 'status offline', j.online ? 'En ligne' : 'Hors ligne'), right);
    const bar = el('div', 'mini-bar'); const fill = el('div');
    j.fillEl = fill; fill.style.width = pct(j) + '%'; bar.append(fill);
    li.append(top, el('div', 'inmate-meta', `Motif : ${j.reason} — par ${j.by}`), bar);
    ul.append(li);
  });
}

setInterval(() => {
  if ($('#menu').classList.contains('hidden')) return;
  jailed.forEach((j) => {
    if (!j.online || !j.timeEl) return;
    j.remaining = Math.max(0, j.remaining - 1);
    j.timeEl.textContent = clock(j.remaining);
    j.fillEl.style.width = pct(j) + '%';
  });
}, 1000);
setInterval(() => {
  if (!$('#menu').classList.contains('hidden') && !$('#tab-list').classList.contains('hidden')) post('refresh');
}, 5000);

function minutes() { return Math.floor(Number($('#minutes').value)) || 0; }
function valid() { const m = minutes(); return selected !== null && m >= settings.min && m <= settings.max; }

function updateSummary() {
  const box = $('#summary'); box.innerHTML = '';
  const p = players.find((x) => x.id === selected);
  const m = minutes();
  if (!p) box.textContent = 'Sélectionnez un joueur pour continuer.';
  else if (m < settings.min || m > settings.max) box.textContent = `La durée doit être comprise entre ${settings.min} et ${settings.max} minutes.`;
  else {
    const reason = $('#reason').value.trim() || 'Non précisé';
    const b1 = el('b', '', p.name), b2 = el('b', '', `${m} min`), b3 = el('b', '', reason);
    box.append('Vous allez emprisonner ', b1, ' pendant ', b2, '. Motif : ', b3, '.');
  }
  $('#btn-jail').disabled = !valid();
  document.querySelectorAll('#time-chips .chip').forEach((c) => c.classList.toggle('on', Number(c.dataset.v) === m));
  const rv = $('#reason').value.trim();
  document.querySelectorAll('#reason-chips .chip').forEach((c) => c.classList.toggle('on', c.textContent === rv));
}

function buildChips() {
  const t = $('#time-chips'); t.innerHTML = '';
  settings.times.forEach((v) => {
    const c = el('button', 'chip', v >= 60 ? `${v / 60} h` : `${v} min`); c.dataset.v = v;
    c.onclick = () => { $('#minutes').value = minutes() === v ? '' : v; updateSummary(); }; t.append(c);
  });
  const r = $('#reason-chips'); r.innerHTML = '';
  settings.reasons.forEach((v) => {
    const c = el('button', 'chip', v); c.onclick = () => { $('#reason').value = $('#reason').value.trim() === v ? '' : v; updateSummary(); }; r.append(c);
  });
}

function switchTab(name) {
  document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('active', t.dataset.tab === name));
  $('#tab-new').classList.toggle('hidden', name !== 'new');
  $('#tab-list').classList.toggle('hidden', name !== 'list');
}

function setData(d) {
  players = d.players || []; jailed = d.jailed || [];
  if (selected !== null && !players.some((p) => p.id === selected)) selected = null;
  renderPlayers(); renderJailed(); updateSummary();
}

function closeMenu() { post('close'); }

document.querySelectorAll('.tab').forEach((t) => (t.onclick = () => { switchTab(t.dataset.tab); post('refresh'); }));
$('#btn-close').onclick = closeMenu;
$('#search').oninput = renderPlayers;
$('#minutes').oninput = updateSummary;
$('#reason').oninput = updateSummary;
$('#btn-jail').onclick = () => {
  if (!valid()) return;
  post('jail', { target: selected, minutes: minutes(), reason: $('#reason').value.trim() });
  $('#reason').value = ''; updateSummary();
};
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !$('#menu').classList.contains('hidden')) closeMenu(); });

function toast(kind, text) {
  const t = el('div', 'toast ' + (kind || 'info'), text);
  $('#toasts').append(t);
  setTimeout(() => t.remove(), 4500);
}

let clockLen = 0;
function setDigit(box, val) {
  const old = box.dataset.v;
  if (old === val) return;
  box.dataset.v = val;
  box.innerHTML = '';
  if (old === undefined) { box.append(el('span', 'd', val)); return; }
  box.append(el('span', 'd out', old), el('span', 'd in', val));
}

function renderClock(sec) {
  sec = Math.max(0, Math.floor(sec));
  const mm = String(Math.floor(sec / 60)).padStart(2, '0');
  const ss = String(sec % 60).padStart(2, '0');
  const root = $('#hud-time');
  if (clockLen !== mm.length) {
    clockLen = mm.length;
    root.innerHTML = '';
    for (let i = 0; i < mm.length; i++) root.append(el('div', 'digit'));
    root.append(el('div', 'colon', ':'));
    root.append(el('div', 'digit'), el('div', 'digit'));
  }
  const boxes = root.querySelectorAll('.digit');
  (mm + ss).split('').forEach((ch, i) => setDigit(boxes[i], ch));
}

function showProgress(label, duration) {
  $('#progress-label').textContent = label;
  const f = $('#progress-fill'); f.style.transition = 'none'; f.style.width = '0';
  $('#progress').classList.remove('hidden');
  void f.offsetWidth;
  f.style.transition = `width ${duration}ms linear`; f.style.width = '100%';
}

window.addEventListener('message', (e) => {
  const d = e.data;
  switch (d.action) {
    case 'open':
      settings = d.settings; selected = null;
      $('#search').value = ''; $('#reason').value = ''; $('#minutes').value = Math.min(10, settings.max);
      buildChips(); switchTab('new'); setData(d);
      $('#menu').classList.remove('hidden');
      break;
    case 'data': setData(d); break;
    case 'close': $('#menu').classList.add('hidden'); break;
    case 'hud':
      $('#hud').classList.toggle('hidden', !d.show);
      if (d.show) {
        $('#hud-staff').textContent = d.by || '';
        $('#hud-reason').textContent = d.reason || '';
        renderClock(d.remaining);
      }
      break;
    case 'progress':
      if (d.show) showProgress(d.label, d.duration); else $('#progress').classList.add('hidden');
      break;
    case 'toast': toast(d.kind, d.text); break;
  }
});
