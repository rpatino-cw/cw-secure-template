// wizard.js — step navigation, answer state, live summary, renderers.
// Imports stacks.js for metadata, generator.js for zip output.

import {
  LANGUAGES, ARCHETYPES, CODE_STYLES, SCALE_TIERS, TRAFFIC_PATTERNS,
  DATABASES, INTEGRATION_SHAPES, API_SHAPES, QUEUE_SYSTEMS,
  DATA_CLASSIFICATIONS, AUTH_METHODS, SECRET_SYSTEMS,
  COMPLIANCE_FRAMEWORKS, DEPLOY_TARGETS, THEMES,
} from './stacks.js';
import { generateScaffold } from './generator.js';

const TOTAL_STEPS = 8;
const STEP_LABELS = [
  'Project basics',
  'Framework & architecture',
  'Scale planning',
  'Database',
  'Modularity & APIs',
  'Security posture',
  'Theme & team',
  'Review & generate',
];

const state = {
  currentStep: 1,
  answers: {
    project: { name: '', description: '', remote: '', launch: '' },
    stack: { language: null, archetype: null, style: 'modules' },
    scale: { users: 'tier-2', pattern: 'steady', geo: 'single', volume: 'small' },
    database: { choice: null, migrations: null },
    integration: { shape: 'monolith', api: 'rest', externalApis: [], queue: 'none' },
    security: { classification: null, auth: null, secrets: null, pii: false, compliance: [], deploy: null },
    theme: { id: 'cw-light', includeDashboard: true },
    team: [],
  },
};

// ============================================================
// Left nav renderer
// ============================================================
function renderStepNav() {
  const host = document.getElementById('steps-nav');
  host.innerHTML = STEP_LABELS.map((label, i) => {
    const n = i + 1;
    const isActive = n === state.currentStep;
    const isDone = n < state.currentStep;
    return `
      <button class="step-link ${isActive ? 'active' : ''} ${isDone ? 'done' : ''}" data-goto="${n}">
        <span class="num">${isDone ? '✓' : n}</span>
        <span>${label}</span>
      </button>`;
  }).join('');
  host.querySelectorAll('[data-goto]').forEach(btn => {
    btn.addEventListener('click', () => {
      const n = parseInt(btn.dataset.goto);
      if (n < state.currentStep || n === state.currentStep) goToStep(n);
    });
  });
}

function goToStep(n) {
  if (n < 1 || n > TOTAL_STEPS) return;
  document.querySelectorAll('.step').forEach(s => s.classList.remove('active'));
  document.querySelector(`.step[data-step="${n}"]`).classList.add('active');
  state.currentStep = n;
  renderStepNav();
  renderSummary();
  if (n === 8) renderFinalReview();
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

// ============================================================
// Step navigation handlers
// ============================================================
document.querySelectorAll('[data-next]').forEach(btn => {
  btn.addEventListener('click', () => {
    captureStep(state.currentStep);
    goToStep(state.currentStep + 1);
  });
});
document.querySelectorAll('[data-back]').forEach(btn => {
  btn.addEventListener('click', () => goToStep(state.currentStep - 1));
});

function captureStep(n) {
  if (n === 1) {
    state.answers.project.name = document.getElementById('proj-name').value.trim() || 'my-new-service';
    state.answers.project.description = document.getElementById('proj-desc').value.trim();
    state.answers.project.remote = document.getElementById('proj-remote').value.trim();
    state.answers.project.launch = document.getElementById('proj-launch').value;
  }
  if (n === 5) {
    const raw = document.getElementById('ext-apis').value.trim();
    state.answers.integration.externalApis = raw ? raw.split(',').map(s => s.trim()).filter(Boolean) : [];
  }
}

// ============================================================
// Step 2 — Languages, archetypes, code style
// ============================================================
function renderLanguages() {
  const host = document.getElementById('lang-grid');
  host.innerHTML = LANGUAGES.map(lang => `
    <button class="card ${state.answers.stack.language === lang.id ? 'selected' : ''}" data-lang="${lang.id}">
      ${lang.recommended ? '<span class="badge">Recommended</span>' : ''}
      <div class="icon">${lang.icon}</div>
      <h3>${lang.name}</h3>
      <div class="blurb">${lang.blurb}</div>
    </button>
  `).join('');
  host.querySelectorAll('[data-lang]').forEach(btn => {
    btn.addEventListener('click', () => {
      state.answers.stack.language = btn.dataset.lang;
      state.answers.stack.archetype = null;
      renderLanguages();
      renderArchetypes();
      document.getElementById('archetype-section').style.display = 'block';
      document.getElementById('style-section').style.display = 'none';
      updateStep2NextButton();
      renderSummary();
    });
  });
}

function renderArchetypes() {
  if (!state.answers.stack.language) return;
  const archs = ARCHETYPES[state.answers.stack.language];
  const host = document.getElementById('arch-grid');
  host.innerHTML = archs.map(a => `
    <button class="card ${state.answers.stack.archetype === a.id ? 'selected' : ''}" data-arch="${a.id}">
      <h3>${a.name}</h3>
      <div class="blurb">${a.blurb}</div>
    </button>
  `).join('');
  host.querySelectorAll('[data-arch]').forEach(btn => {
    btn.addEventListener('click', () => {
      state.answers.stack.archetype = btn.dataset.arch;
      renderArchetypes();
      renderArchetypePreview();
      renderCodeStyles();
      document.getElementById('style-section').style.display = 'block';
      updateStep2NextButton();
      renderSummary();
    });
  });
  if (state.answers.stack.archetype) renderArchetypePreview();
}

function renderArchetypePreview() {
  const archs = ARCHETYPES[state.answers.stack.language];
  const a = archs.find(x => x.id === state.answers.stack.archetype);
  if (!a) return;
  const panel = document.getElementById('arch-preview');
  panel.classList.add('visible');
  panel.innerHTML = `
    <div class="preview-grid">
      <div>
        <h4>Folder structure</h4>
        <div class="tree">${renderTree(a.tree)}</div>
      </div>
      <div>
        <h4>Request flow</h4>
        <div class="stack-diagram">
          <div class="stack-layer layer-client">HTTP request</div>
          <div class="arrow">↓</div>
          <div class="stack-layer layer-middleware">middleware (auth · rate limit · request id)</div>
          <div class="arrow">↓</div>
          <div class="stack-layer layer-route">routes/ (thin — 10–20 lines)</div>
          <div class="arrow">↓</div>
          <div class="stack-layer layer-service">services/ (business logic)</div>
          <div class="arrow">↓</div>
          <div class="stack-layer layer-repo">repositories/ (parameterized queries)</div>
          <div class="arrow">↓</div>
          <div class="stack-layer layer-db">database</div>
        </div>
      </div>
    </div>
    <div class="meta-row">
      <div class="meta"><div class="k">Scale ceiling</div><div class="v">${a.scaleCeiling}</div></div>
      <div class="meta"><div class="k">Setup time</div><div class="v">${a.setupTime}</div></div>
      <div class="meta"><div class="k">Team size</div><div class="v">${a.teamSize}</div></div>
    </div>
    <div class="why-pick"><strong>When to pick this:</strong> ${a.whenToPick}</div>
  `;
}

function renderTree(tree) {
  return tree.map(entry => {
    const [name, type, hint] = entry;
    const indent = (name.match(/^ +/) || [''])[0];
    const trimmed = name.trim();
    const cls = type === 'dir' ? 'dir' : type === 'entry' ? 'entry' : '';
    const hintHtml = hint ? `<span class="hint">   ← ${hint}</span>` : '';
    return `${indent}<span class="${cls}">${trimmed}</span>${hintHtml}`;
  }).join('\n');
}

function renderCodeStyles() {
  const host = document.getElementById('style-grid');
  host.innerHTML = CODE_STYLES.map(s => `
    <button class="card ${state.answers.stack.style === s.id ? 'selected' : ''}" data-style="${s.id}">
      <h3>${s.name}</h3>
      <div class="blurb">${s.blurb}</div>
      <pre class="tree" style="margin-top: 10px; font-size: 11px;">${escapeHtml(s.sample)}</pre>
    </button>
  `).join('');
  host.querySelectorAll('[data-style]').forEach(btn => {
    btn.addEventListener('click', () => {
      state.answers.stack.style = btn.dataset.style;
      renderCodeStyles();
      updateStep2NextButton();
      renderSummary();
    });
  });
}

function updateStep2NextButton() {
  const btn = document.querySelector('.step[data-step="2"] [data-next]');
  btn.disabled = !(state.answers.stack.language && state.answers.stack.archetype);
}

// ============================================================
// Step 3 — Scale
// ============================================================
function renderScale() {
  renderRadioChips('scale-users', SCALE_TIERS, 'users', 'scale');
  const geoOpts = [
    { id: 'single', label: 'Single region' },
    { id: 'multi', label: 'Multi-region' },
    { id: 'global', label: 'Global' },
  ];
  const volumeOpts = [
    { id: 'small', label: '< 10 GB' },
    { id: 'mid', label: '10 GB – 1 TB' },
    { id: 'large', label: '1 TB+' },
  ];
  renderRadioChips('scale-pattern', TRAFFIC_PATTERNS, 'pattern', 'scale');
  renderRadioChips('scale-geo', geoOpts, 'geo', 'scale');
  renderRadioChips('scale-volume', volumeOpts, 'volume', 'scale');
  updateScaleCallout();
}

function updateScaleCallout() {
  const tier = SCALE_TIERS.find(t => t.id === state.answers.scale.users);
  const pattern = TRAFFIC_PATTERNS.find(p => p.id === state.answers.scale.pattern);
  const callout = document.getElementById('scale-callout');
  let html = `<strong>Infrastructure:</strong> ${tier.infra}`;
  if (pattern.id === 'spiky') html += ` <br><strong>Spiky traffic:</strong> generator will add queue buffer + autoscale hints to CLAUDE.md.`;
  if (tier.warning) html += ` <br><strong>Heads up:</strong> ${tier.warning}`;
  // Archetype mismatch warnings
  const arch = state.answers.stack.archetype;
  if (arch === 'go-worker' && tier.id === 'tier-4') {
    html += ` <br><strong>Mismatch:</strong> stdlib worker at 1M+ users needs queue-partitioned workers. Consider API + queue archetype.`;
  }
  callout.innerHTML = html;
  callout.style.display = 'block';
}

// ============================================================
// Step 4 — Databases
// ============================================================
function renderDatabases() {
  const host = document.getElementById('db-grid');
  host.innerHTML = DATABASES.map(db => `
    <button class="card db-card ${state.answers.database.choice === db.id ? 'selected' : ''}" data-db="${db.id}">
      ${db.recommended ? '<span class="badge">Default</span>' : ''}
      ${db.cwPolicy.includes('NOT approved') || db.cwPolicy.includes('REQUIRES') ? '<span class="badge warn-badge">Review</span>' : ''}
      <h3>${db.name}</h3>
      <div class="blurb">${db.whenToPick}</div>
      <div class="matrix">
        <div class="k">ACID</div><div class="v">${db.acid}</div>
        <div class="k">Scale</div><div class="v">${db.scale}</div>
        <div class="k">Setup</div><div class="v">${'●'.repeat(db.difficulty)}${'○'.repeat(5 - db.difficulty)}</div>
        <div class="k">Cost</div><div class="v">${db.cost}</div>
      </div>
      <div style="margin-top:10px;font-size:11px;color:var(--text-tertiary);"><strong>CW policy:</strong> ${db.cwPolicy}</div>
      ${db.warning ? `<div class="warn-line">${db.warning}</div>` : ''}
    </button>
  `).join('');
  host.querySelectorAll('[data-db]').forEach(btn => {
    btn.addEventListener('click', () => {
      state.answers.database.choice = btn.dataset.db;
      const db = DATABASES.find(d => d.id === btn.dataset.db);
      const lang = state.answers.stack.language;
      state.answers.database.migrations = db.migrations[lang] || null;
      renderDatabases();
      renderDatabasePipeline();
      renderMigrationsField();
      document.querySelector('.step[data-step="4"] [data-next]').disabled = false;
      renderSummary();
    });
  });
}

function renderDatabasePipeline() {
  const db = DATABASES.find(d => d.id === state.answers.database.choice);
  if (!db) return;
  const host = document.getElementById('db-pipeline');
  host.classList.add('visible');
  host.innerHTML = `
    <h4 style="font-size:12px;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-tertiary);margin-bottom:10px;">Data pipeline</h4>
    <div class="pipe-chain">
      ${db.pipeline.map((n, i) => `
        <div class="pipe-node">${n}</div>
        ${i < db.pipeline.length - 1 ? '<span class="pipe-arrow">→</span>' : ''}
      `).join('')}
    </div>
  `;
}

function renderMigrationsField() {
  const db = DATABASES.find(d => d.id === state.answers.database.choice);
  const lang = state.answers.stack.language;
  const field = document.getElementById('migrations-field');
  const sel = document.getElementById('migrations-tool');
  if (!db || !db.migrations[lang]) {
    field.style.display = 'none';
    return;
  }
  field.style.display = 'block';
  const tool = db.migrations[lang];
  sel.innerHTML = `<option value="${tool}">${tool}</option><option value="none">None — manual SQL</option>`;
  sel.value = state.answers.database.migrations || tool;
  sel.onchange = () => { state.answers.database.migrations = sel.value; };
}

// ============================================================
// Step 5 — Integration
// ============================================================
function renderIntegration() {
  renderRadioChips('shape-grid', INTEGRATION_SHAPES, 'shape', 'integration');
  renderRadioChips('api-grid', API_SHAPES, 'api', 'integration');
  renderRadioChips('queue-grid', QUEUE_SYSTEMS, 'queue', 'integration');
}

// ============================================================
// Step 6 — Security
// ============================================================
function renderSecurity() {
  renderCardChoice('sec-classification', DATA_CLASSIFICATIONS, 'classification', 'security');
  renderCardChoice('sec-auth', AUTH_METHODS, 'auth', 'security');
  renderCardChoice('sec-secrets', SECRET_SYSTEMS, 'secrets', 'security');
  renderCardChoice('sec-deploy', DEPLOY_TARGETS, 'deploy', 'security');
  renderMultiChips('sec-compliance', COMPLIANCE_FRAMEWORKS, 'compliance', 'security');
  document.getElementById('sec-pii').checked = state.answers.security.pii;
  document.getElementById('sec-pii').onchange = (e) => {
    state.answers.security.pii = e.target.checked;
    updateComplianceScore();
    renderSummary();
  };
  updateComplianceScore();
}

function updateComplianceScore() {
  const s = state.answers.security;
  const filled = [s.classification, s.auth, s.secrets, s.deploy].filter(Boolean).length + (s.pii !== null ? 1 : 0) + (s.compliance.length > 0 ? 1 : 0);
  const total = 6;
  const pct = Math.round(filled / total * 100);
  // Risk assessment
  let score = pct;
  let label = 'Answer the questions →';
  let color = 'var(--border)';
  if (filled === total) {
    const classification = DATA_CLASSIFICATIONS.find(c => c.id === s.classification);
    const usingEnv = s.secrets === 'env';
    if (classification?.strict && usingEnv) {
      label = 'BLOCKED — Restricted data cannot use plain .env';
      color = 'var(--critical)';
      score = 30;
    } else if (s.auth === 'none' && classification?.id !== 'public') {
      label = 'WARNING — No auth with non-public data';
      color = 'var(--warn)';
      score = 60;
    } else {
      label = 'Aligned with CW policies';
      color = 'var(--pass)';
      score = 100;
    }
  }
  const ring = document.getElementById('compliance-ring');
  ring.style.background = `conic-gradient(${color} ${score * 3.6}deg, var(--border) 0deg)`;
  document.getElementById('compliance-pct').textContent = `${score}%`;
  document.getElementById('compliance-label').textContent = label;
  document.getElementById('compliance-label').style.color = color;
  document.getElementById('compliance-detail').textContent = `${filled} of ${total} sections answered`;
}

// ============================================================
// Step 7 — Theme + team
// ============================================================
function renderThemes() {
  const host = document.getElementById('theme-grid');
  host.innerHTML = THEMES.map(t => `
    <button class="card ${state.answers.theme.id === t.id ? 'selected' : ''}" data-theme="${t.id}" style="background:${t.bg};color:${t.text};border-color:${state.answers.theme.id === t.id ? t.accent : 'var(--border)'};">
      ${t.recommended ? '<span class="badge">Default</span>' : ''}
      <h3 style="color:${t.text};">${t.label}</h3>
      <div class="blurb" style="color:${t.text};opacity:0.7;">Accent: <span style="color:${t.accent};font-weight:600;">${t.accent}</span></div>
    </button>
  `).join('');
  host.querySelectorAll('[data-theme]').forEach(btn => {
    btn.addEventListener('click', () => {
      state.answers.theme.id = btn.dataset.theme;
      renderThemes();
      renderSummary();
    });
  });
  document.getElementById('include-dashboard').onchange = (e) => {
    state.answers.theme.includeDashboard = e.target.checked;
    renderSummary();
  };
  renderTeam();
  document.getElementById('add-teammate').onclick = addTeammate;
}

function renderTeam() {
  const host = document.getElementById('team-rows');
  if (state.answers.team.length === 0) addTeammate();
  host.innerHTML = state.answers.team.map((m, i) => `
    <tr data-idx="${i}">
      <td><input data-f="name" value="${m.name || ''}" placeholder="Romeo Patino"></td>
      <td><input data-f="role" value="${m.role || ''}" placeholder="lead / dev / reviewer"></td>
      <td><input data-f="email" value="${m.email || ''}" placeholder="rpatino@coreweave.com"></td>
      <td><input data-f="slack" value="${m.slack || ''}" placeholder="@rpatino"></td>
      <td><input data-f="owns" value="${m.owns || ''}" placeholder="python/routes/, services/"></td>
      <td><button class="remove-row" data-remove="${i}">×</button></td>
    </tr>
  `).join('');
  host.querySelectorAll('tr').forEach(tr => {
    const idx = parseInt(tr.dataset.idx);
    tr.querySelectorAll('input').forEach(inp => {
      inp.addEventListener('input', () => {
        state.answers.team[idx][inp.dataset.f] = inp.value.trim();
        renderSummary();
      });
    });
    tr.querySelector('[data-remove]').addEventListener('click', () => {
      state.answers.team.splice(idx, 1);
      if (state.answers.team.length === 0) state.answers.team.push({});
      renderTeam();
      renderSummary();
    });
  });
}

function addTeammate() {
  state.answers.team.push({ name: '', role: 'dev', email: '', slack: '', owns: '' });
  renderTeam();
}

// ============================================================
// Shared renderers
// ============================================================
function renderRadioChips(hostId, options, key, ns) {
  const host = document.getElementById(hostId);
  host.innerHTML = options.map(o => `
    <button class="radio-chip ${state.answers[ns][key] === o.id ? 'selected' : ''}" data-val="${o.id}" title="${(o.blurb || '').replace(/"/g, '&quot;')}">
      ${o.label}
    </button>
  `).join('');
  host.querySelectorAll('[data-val]').forEach(btn => {
    btn.addEventListener('click', () => {
      state.answers[ns][key] = btn.dataset.val;
      renderRadioChips(hostId, options, key, ns);
      if (ns === 'scale') updateScaleCallout();
      renderSummary();
    });
  });
}

function renderCardChoice(hostId, options, key, ns) {
  const host = document.getElementById(hostId);
  host.innerHTML = options.map(o => `
    <button class="card ${state.answers[ns][key] === o.id ? 'selected' : ''}" data-val="${o.id}">
      ${o.recommended ? '<span class="badge">Recommended</span>' : ''}
      ${o.strict ? '<span class="badge warn-badge">Strict</span>' : ''}
      <h3>${o.label}</h3>
      <div class="blurb">${o.blurb}</div>
    </button>
  `).join('');
  host.querySelectorAll('[data-val]').forEach(btn => {
    btn.addEventListener('click', () => {
      state.answers[ns][key] = btn.dataset.val;
      renderCardChoice(hostId, options, key, ns);
      if (ns === 'security') updateComplianceScore();
      renderSummary();
    });
  });
}

function renderMultiChips(hostId, options, key, ns) {
  const host = document.getElementById(hostId);
  host.innerHTML = options.map(o => `
    <button class="radio-chip ${state.answers[ns][key].includes(o.id) ? 'selected' : ''}" data-val="${o.id}" title="${(o.blurb || '').replace(/"/g, '&quot;')}">
      ${o.label}
    </button>
  `).join('');
  host.querySelectorAll('[data-val]').forEach(btn => {
    btn.addEventListener('click', () => {
      const arr = state.answers[ns][key];
      const v = btn.dataset.val;
      const i = arr.indexOf(v);
      if (i >= 0) arr.splice(i, 1); else arr.push(v);
      renderMultiChips(hostId, options, key, ns);
      if (ns === 'security') updateComplianceScore();
      renderSummary();
    });
  });
}

// ============================================================
// Live summary
// ============================================================
function renderSummary() {
  const host = document.getElementById('summary-host');
  const a = state.answers;
  const lang = LANGUAGES.find(l => l.id === a.stack.language);
  const arch = a.stack.language ? ARCHETYPES[a.stack.language].find(x => x.id === a.stack.archetype) : null;
  const db = DATABASES.find(d => d.id === a.database.choice);
  const cls = DATA_CLASSIFICATIONS.find(c => c.id === a.security.classification);
  const rows = [
    ['Name', a.project.name || '—'],
    ['Stack', lang ? `${lang.name}${arch ? ' · ' + arch.name : ''}` : '—'],
    ['Style', CODE_STYLES.find(s => s.id === a.stack.style)?.name || '—'],
    ['Users', SCALE_TIERS.find(s => s.id === a.scale.users)?.label || '—'],
    ['Database', db?.name || '—'],
    ['Shape', INTEGRATION_SHAPES.find(s => s.id === a.integration.shape)?.label || '—'],
    ['API', API_SHAPES.find(s => s.id === a.integration.api)?.label || '—'],
    ['Queue', QUEUE_SYSTEMS.find(s => s.id === a.integration.queue)?.label || '—'],
    ['Classification', cls?.label || '—'],
    ['Auth', AUTH_METHODS.find(x => x.id === a.security.auth)?.label || '—'],
    ['Secrets', SECRET_SYSTEMS.find(x => x.id === a.security.secrets)?.label || '—'],
    ['Deploy', DEPLOY_TARGETS.find(x => x.id === a.security.deploy)?.label || '—'],
    ['Team size', `${a.team.filter(m => m.name).length} member${a.team.filter(m => m.name).length === 1 ? '' : 's'}`],
  ];
  host.innerHTML = rows.map(([k, v]) => `
    <div class="summary-item">
      <div class="k">${k}</div>
      <div class="v ${v === '—' ? 'empty' : ''}">${escapeHtml(v)}</div>
    </div>
  `).join('');
}

// ============================================================
// Final review
// ============================================================
function renderFinalReview() {
  const host = document.getElementById('final-summary-host');
  const a = state.answers;
  const lang = LANGUAGES.find(l => l.id === a.stack.language);
  const arch = lang ? ARCHETYPES[a.stack.language].find(x => x.id === a.stack.archetype) : null;
  const db = DATABASES.find(d => d.id === a.database.choice);
  const cls = DATA_CLASSIFICATIONS.find(c => c.id === a.security.classification);
  const usingEnvForRestricted = cls?.strict && a.security.secrets === 'env';

  const alerts = [];
  if (usingEnvForRestricted) {
    alerts.push(`<div class="alert critical"><strong>Blocked:</strong> Restricted data with plain .env secrets violates CW policy. Switch to Doppler in step 6.</div>`);
  }
  if (a.security.auth === 'none' && cls && cls.id !== 'public') {
    alerts.push(`<div class="alert warn"><strong>Warning:</strong> No auth configured but data is not Public. AppSec will reject this.</div>`);
  }
  if (alerts.length === 0 && cls) {
    alerts.push(`<div class="alert pass"><strong>Ready.</strong> Configuration aligns with CW standards — scaffold will include the right guards.</div>`);
  }

  host.innerHTML = alerts.join('') + `
    <div class="final-summary">
      <h3>Project</h3>
      <table>
        <tr><td>Name</td><td>${escapeHtml(a.project.name)}</td></tr>
        <tr><td>Description</td><td>${escapeHtml(a.project.description) || '—'}</td></tr>
        <tr><td>Remote</td><td>${escapeHtml(a.project.remote) || '—'}</td></tr>
        <tr><td>Launch target</td><td>${escapeHtml(a.project.launch) || '—'}</td></tr>
      </table>
    </div>
    <div class="final-summary">
      <h3>Stack</h3>
      <table>
        <tr><td>Language</td><td>${lang?.name || '—'}</td></tr>
        <tr><td>Archetype</td><td>${arch?.name || '—'}</td></tr>
        <tr><td>Style</td><td>${CODE_STYLES.find(s => s.id === a.stack.style)?.name}</td></tr>
        <tr><td>Database</td><td>${db?.name || '—'} ${a.database.migrations ? `· migrations: ${a.database.migrations}` : ''}</td></tr>
        <tr><td>API shape</td><td>${API_SHAPES.find(s => s.id === a.integration.api)?.label}</td></tr>
        <tr><td>Queue</td><td>${QUEUE_SYSTEMS.find(s => s.id === a.integration.queue)?.label}</td></tr>
        <tr><td>External APIs</td><td>${a.integration.externalApis.length ? a.integration.externalApis.join(', ') : '—'}</td></tr>
      </table>
    </div>
    <div class="final-summary">
      <h3>Security</h3>
      <table>
        <tr><td>Classification</td><td>${cls?.label || '—'}</td></tr>
        <tr><td>Auth</td><td>${AUTH_METHODS.find(x => x.id === a.security.auth)?.label || '—'}</td></tr>
        <tr><td>Secrets</td><td>${SECRET_SYSTEMS.find(x => x.id === a.security.secrets)?.label || '—'}</td></tr>
        <tr><td>PII/PHI</td><td>${a.security.pii ? 'Yes' : 'No'}</td></tr>
        <tr><td>Compliance</td><td>${a.security.compliance.length ? a.security.compliance.join(', ') : '—'}</td></tr>
        <tr><td>Deploy target</td><td>${DEPLOY_TARGETS.find(x => x.id === a.security.deploy)?.label || '—'}</td></tr>
      </table>
    </div>
    <div class="final-summary">
      <h3>Scale</h3>
      <table>
        <tr><td>Users</td><td>${SCALE_TIERS.find(s => s.id === a.scale.users)?.label}</td></tr>
        <tr><td>Traffic</td><td>${TRAFFIC_PATTERNS.find(p => p.id === a.scale.pattern)?.label}</td></tr>
        <tr><td>Geography</td><td>${a.scale.geo}</td></tr>
        <tr><td>Data volume</td><td>${a.scale.volume}</td></tr>
      </table>
    </div>
    <div class="final-summary">
      <h3>Team (${a.team.filter(m => m.name).length})</h3>
      ${a.team.filter(m => m.name).length === 0 ? '<p style="color:var(--text-tertiary);font-size:13px;">Solo project. rooms.json will be skipped.</p>' : `
        <table>
          ${a.team.filter(m => m.name).map(m => `
            <tr><td>${escapeHtml(m.name)} (${escapeHtml(m.role)})</td><td>${escapeHtml(m.owns || 'shared')}</td></tr>
          `).join('')}
        </table>
      `}
    </div>
  `;

  document.getElementById('generate-btn').disabled = usingEnvForRestricted;
}

// ============================================================
// Generate + copy
// ============================================================
document.getElementById('generate-btn').addEventListener('click', async () => {
  const btn = document.getElementById('generate-btn');
  btn.disabled = true;
  btn.textContent = 'Building zip…';
  try {
    await generateScaffold(state.answers);
    btn.textContent = '✓ Downloaded';
    setTimeout(() => { btn.textContent = 'Generate scaffold ZIP'; btn.disabled = false; }, 2000);
  } catch (err) {
    btn.textContent = 'Error — check console';
    btn.style.background = 'var(--critical)';
    console.error(err);
  }
});

document.getElementById('copy-summary').addEventListener('click', async () => {
  const md = summaryAsMarkdown(state.answers);
  await navigator.clipboard.writeText(md);
  const btn = document.getElementById('copy-summary');
  btn.textContent = '✓ Copied';
  setTimeout(() => { btn.textContent = 'Copy summary'; }, 1500);
});

function summaryAsMarkdown(a) {
  const lang = LANGUAGES.find(l => l.id === a.stack.language);
  const arch = lang ? ARCHETYPES[a.stack.language].find(x => x.id === a.stack.archetype) : null;
  const db = DATABASES.find(d => d.id === a.database.choice);
  return `# ${a.project.name} — Setup Summary

- **Language:** ${lang?.name || '—'}
- **Archetype:** ${arch?.name || '—'}
- **Style:** ${CODE_STYLES.find(s => s.id === a.stack.style)?.name}
- **Database:** ${db?.name || '—'}
- **Classification:** ${DATA_CLASSIFICATIONS.find(c => c.id === a.security.classification)?.label || '—'}
- **Auth:** ${AUTH_METHODS.find(x => x.id === a.security.auth)?.label || '—'}
- **Secrets:** ${SECRET_SYSTEMS.find(x => x.id === a.security.secrets)?.label || '—'}
- **Deploy:** ${DEPLOY_TARGETS.find(x => x.id === a.security.deploy)?.label || '—'}
- **Team:** ${a.team.filter(m => m.name).length} members
`;
}

// ============================================================
// Utilities
// ============================================================
function escapeHtml(s) {
  return String(s || '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
}

// ============================================================
// Boot
// ============================================================
renderStepNav();
renderLanguages();
renderScale();
renderDatabases();
renderIntegration();
renderSecurity();
renderThemes();
renderSummary();
