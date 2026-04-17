// wizard.js — step navigation, answer state, live summary, renderers.
// Imports stacks.js for metadata, generator.js for zip output.

import {
  LANGUAGES, ARCHETYPES, CODE_STYLES, SCALE_TIERS, TRAFFIC_PATTERNS,
  DATABASES, INTEGRATION_SHAPES, API_SHAPES, QUEUE_SYSTEMS,
  DATA_CLASSIFICATIONS, AUTH_METHODS, SECRET_SYSTEMS,
  COMPLIANCE_FRAMEWORKS, DEPLOY_TARGETS, THEMES,
  resolveAnswers,
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
    team: [{ name: '', role: 'dev', email: '', slack: '', owns: '' }],
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
      if (n <= state.currentStep) goToStep(n);
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
  const ready = state.answers.stack.language && state.answers.stack.archetype;
  btn.disabled = !ready;
  btn.title = ready ? '' : state.answers.stack.language ? 'Pick an archetype to continue' : 'Pick a language to continue';
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

const SCALE_MISMATCHES = [
  { arch: 'go-worker', tier: 'tier-4', message: 'stdlib worker at 1M+ users needs queue-partitioned workers. Consider API + queue archetype.' },
];

function updateScaleCallout() {
  const tier = SCALE_TIERS.find(t => t.id === state.answers.scale.users);
  const pattern = TRAFFIC_PATTERNS.find(p => p.id === state.answers.scale.pattern);
  const arch = state.answers.stack.archetype;
  const callout = document.getElementById('scale-callout');
  let html = `<strong>Infrastructure:</strong> ${tier.infra}`;
  if (pattern.id === 'spiky') html += ` <br><strong>Spiky traffic:</strong> generator will add queue buffer + autoscale hints to CLAUDE.md.`;
  if (tier.warning) html += ` <br><strong>Heads up:</strong> ${tier.warning}`;
  const mismatch = SCALE_MISMATCHES.find(m => m.arch === arch && m.tier === tier.id);
  if (mismatch) html += ` <br><strong>Mismatch:</strong> ${mismatch.message}`;
  callout.innerHTML = html;
  callout.style.display = 'block';
}

// ============================================================
// Step 4 — Databases
// ============================================================
const SETUP_TIER = ['', 'trivial', 'trivial', 'moderate', 'complex', 'complex'];

function renderDatabases() {
  const host = document.getElementById('db-grid');
  host.innerHTML = DATABASES.map(db => {
    const blocked = db.cwPolicy.includes('NOT approved');
    const review = db.cwPolicy.includes('REQUIRES');
    return `
    <tr class="${state.answers.database.choice === db.id ? 'selected' : ''}" data-db="${db.id}">
      <td class="name">
        ${db.name}
        ${db.recommended ? '<span class="tag">Default</span>' : ''}
        ${review ? '<span class="tag warn-badge">Review</span>' : ''}
        <span class="sub">${db.whenToPick}</span>
      </td>
      <td class="meta">${db.acid}</td>
      <td class="meta">${db.scale}</td>
      <td><span class="setup-tier ${SETUP_TIER[db.difficulty] || 'moderate'}">${SETUP_TIER[db.difficulty] || 'moderate'}</span></td>
      <td class="meta">${db.cost}</td>
      <td class="policy ${blocked ? 'blocked' : ''}">${db.cwPolicy}${db.warning ? ` <br><em style="opacity:0.8">${db.warning}</em>` : ''}</td>
    </tr>`;
  }).join('');
  host.querySelectorAll('[data-db]').forEach(row => {
    row.addEventListener('click', () => {
      state.answers.database.choice = row.dataset.db;
      const db = DATABASES.find(d => d.id === row.dataset.db);
      const lang = state.answers.stack.language;
      state.answers.database.migrations = db.migrations[lang] || null;
      renderDatabases();
      renderDatabasePipeline();
      renderMigrationsField();
      const nextBtn = document.querySelector('.step[data-step="4"] [data-next]');
      nextBtn.disabled = false;
      nextBtn.title = '';
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
  renderClassificationScale();
  renderChoiceList('sec-auth', AUTH_METHODS, 'auth', 'security');
  renderChoiceList('sec-secrets', SECRET_SYSTEMS, 'secrets', 'security');
  renderChoiceList('sec-deploy', DEPLOY_TARGETS, 'deploy', 'security');
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
  const classification = DATA_CLASSIFICATIONS.find(c => c.id === s.classification);
  const envWithStrict = classification?.strict && s.secrets === 'env';
  const authlessNonPublic = s.auth === 'none' && classification && classification.id !== 'public';

  const segments = [
    { key: 'Classification', filled: !!s.classification, fail: false },
    { key: 'Auth', filled: !!s.auth, fail: authlessNonPublic },
    { key: 'Secrets', filled: !!s.secrets, fail: envWithStrict },
    { key: 'Deploy', filled: !!s.deploy, fail: false },
    { key: 'Compliance', filled: s.compliance.length > 0, fail: false },
  ];
  const filledCount = segments.filter(x => x.filled).length;

  const host = document.getElementById('compliance-segments');
  host.innerHTML = segments.map(seg => {
    const cls = seg.fail ? 'critical' : seg.filled ? 'pass' : '';
    return `<div class="compliance-seg ${cls}">${seg.key}</div>`;
  }).join('');

  let label, color;
  if (filledCount < segments.length) {
    label = 'Answer the questions →';
    color = 'var(--text-secondary)';
  } else if (envWithStrict) {
    label = 'Blocked — Restricted data cannot use plain .env';
    color = 'var(--critical)';
  } else if (authlessNonPublic) {
    label = 'Warning — no auth on non-public data';
    color = 'var(--warn)';
  } else {
    label = 'Aligned with CW policies';
    color = 'var(--pass)';
  }
  const labelEl = document.getElementById('compliance-label');
  labelEl.textContent = label;
  labelEl.style.color = color;
  document.getElementById('compliance-detail').textContent = `${filledCount} of ${segments.length} answered`;
}

// ============================================================
// Step 7 — Theme + team
// ============================================================
function renderThemes() {
  const host = document.getElementById('theme-grid');
  host.innerHTML = THEMES.map(t => {
    const isDark = t.id === 'cw-dark';
    const subText = isDark ? 'oklch(75% 0.02 260)' : 'oklch(45% 0.02 260)';
    const chipBg = isDark ? 'oklch(18% 0.02 260)' : 'oklch(94% 0.012 80)';
    return `
    <div class="theme-preview-row ${state.answers.theme.id === t.id ? 'selected' : ''}" data-theme="${t.id}">
      <div class="theme-preview-meta">
        <h4>${t.label}</h4>
        <div style="font-size:12px;color:var(--text-tertiary);margin-top:4px">Accent <code style="color:${t.accent}">${t.accent}</code></div>
        ${t.recommended ? '<span class="tag">Default</span>' : ''}
      </div>
      <div class="theme-preview-render" style="background:${t.bg};color:${t.text}">
        <div class="mock-h" style="color:${t.text}">project-dashboard</div>
        <div class="mock-text" style="color:${subText}">Internal billing service · Generated 2026-04-17</div>
        <div class="mock-pill" style="background:${t.accent};color:${isDark ? t.bg : 'white'}">● Aligned</div>
        <div class="mock-bar" style="background:${chipBg}"></div>
      </div>
    </div>`;
  }).join('');
  host.querySelectorAll('[data-theme]').forEach(row => {
    row.addEventListener('click', () => {
      state.answers.theme.id = row.dataset.theme;
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
  if (state.answers.team.length === 0) state.answers.team.push({ name: '', role: 'dev', email: '', slack: '', owns: '' });
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

function renderClassificationScale() {
  const host = document.getElementById('sec-classification');
  const selected = state.answers.security.classification;
  const risks = { public: 1, proprietary: 2, restricted: 3, 'highly-restricted': 4 };
  host.innerHTML = DATA_CLASSIFICATIONS.map(c => `
    <div class="classification-row ${selected === c.id ? 'selected' : ''}" data-val="${c.id}" data-risk="${risks[c.id]}">
      <div class="risk-bar"></div>
      <div class="body">
        <h4>${c.label}</h4>
        <div class="blurb">${c.blurb}</div>
      </div>
      ${c.strict ? '<span class="tag-strict">Strict</span>' : ''}
    </div>
  `).join('');
  host.querySelectorAll('[data-val]').forEach(row => {
    row.addEventListener('click', () => {
      state.answers.security.classification = row.dataset.val;
      renderClassificationScale();
      updateComplianceScore();
      renderSummary();
    });
  });
}

function renderChoiceList(hostId, options, key, ns) {
  const host = document.getElementById(hostId);
  host.innerHTML = options.map(o => {
    const hasRec = o.recommended;
    const hasStrict = o.strict;
    return `
    <div class="choice-row ${state.answers[ns][key] === o.id ? 'selected' : ''}" data-val="${o.id}">
      <div class="radio-dot"></div>
      <div class="body">
        <div class="name">${o.label}</div>
        <div class="blurb">${o.blurb}</div>
      </div>
      ${hasRec ? '<span class="meta-tag">Recommended</span>' : ''}
      ${hasStrict ? '<span class="meta-tag warn-tag">Strict</span>' : ''}
    </div>`;
  }).join('');
  host.querySelectorAll('[data-val]').forEach(row => {
    row.addEventListener('click', () => {
      state.answers[ns][key] = row.dataset.val;
      renderChoiceList(hostId, options, key, ns);
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
function summaryRows(a) {
  const r = resolveAnswers(a);
  const memberCount = r.teammates.length;
  return [
    ['Name', a.project.name || '—'],
    ['Stack', r.lang ? `${r.lang.name}${r.arch ? ' · ' + r.arch.name : ''}` : '—'],
    ['Style', r.style?.name || '—'],
    ['Users', r.tier?.label || '—'],
    ['Database', r.db?.name || '—'],
    ['Shape', r.shape?.label || '—'],
    ['API', r.api?.label || '—'],
    ['Queue', r.queue?.label || '—'],
    ['Classification', r.cls?.label || '—'],
    ['Auth', r.auth?.label || '—'],
    ['Secrets', r.secrets?.label || '—'],
    ['Deploy', r.deploy?.label || '—'],
    ['Team size', `${memberCount} member${memberCount === 1 ? '' : 's'}`],
  ];
}

function renderSummary() {
  const host = document.getElementById('summary-host');
  const a = state.answers;
  const r = resolveAnswers(a);
  const teamCount = r.teammates.length;

  const layers = [
    {
      label: 'Deployment',
      value: r.deploy?.label || '—',
      filled: !!r.deploy,
      accent: 'info',
    },
    {
      label: 'API surface',
      value: r.api ? `${r.api.label}${r.queue && r.queue.id !== 'none' ? ' + ' + r.queue.label : ''}` : '—',
      filled: !!r.api,
      accent: 'info',
    },
    {
      label: 'Stack',
      value: r.lang ? `${r.lang.name}${r.arch ? ' · ' + r.arch.name : ''}` : '—',
      filled: !!r.lang,
      accent: 'pass',
    },
    {
      label: 'Database',
      value: r.db?.name || '—',
      filled: !!r.db && r.db.id !== 'none' ? true : r.db?.id === 'none',
      accent: 'pass',
    },
    {
      label: 'Auth',
      value: r.auth?.label || '—',
      filled: !!r.auth,
      accent: r.auth?.id === 'none' ? 'warn' : 'pass',
    },
    {
      label: 'Secrets',
      value: r.secrets?.label || '—',
      filled: !!r.secrets,
      accent: r.secrets?.id === 'env' && r.cls?.strict ? 'critical' : 'pass',
    },
    {
      label: 'Classification',
      value: r.cls?.label || '—',
      filled: !!r.cls,
      accent: r.cls?.strict ? 'warn' : 'info',
    },
    {
      label: 'Team',
      value: teamCount === 0 ? 'Solo' : `${teamCount} member${teamCount === 1 ? '' : 's'}`,
      filled: teamCount > 0 || !!r.lang,
      accent: 'info',
    },
  ];

  host.innerHTML = layers.map(l => `
    <div class="stack-layer ${l.filled ? 'filled accent-' + l.accent : ''}">
      <div class="layer-label">${l.label}</div>
      <div class="layer-value">${escapeHtml(l.value)}</div>
    </div>
  `).join('') + (r.cls?.strict ? `
    <div class="stack-layer strict-banner" style="margin-top: 10px;">
      <div class="layer-label">⚠ Strict mode</div>
      <div class="layer-value">Guards flipped to strict</div>
    </div>
  ` : '');
}

// ============================================================
// Final review
// ============================================================
function evaluatePolicy(a, r) {
  if (r.cls?.strict && a.security.secrets === 'env') {
    return { status: 'critical', message: '<strong>Blocked:</strong> Restricted data with plain .env secrets violates CW policy. Switch to Doppler in step 6.' };
  }
  if (a.security.auth === 'none' && r.cls && r.cls.id !== 'public') {
    return { status: 'warn', message: '<strong>Warning:</strong> No auth configured but data is not Public. AppSec will reject this.' };
  }
  if (r.cls) {
    return { status: 'pass', message: '<strong>Ready.</strong> Configuration aligns with CW standards — scaffold will include the right guards.' };
  }
  return null;
}

function renderFinalReview() {
  const host = document.getElementById('final-summary-host');
  const a = state.answers;
  const r = resolveAnswers(a);
  const verdict = evaluatePolicy(a, r);
  const teammates = r.teammates;

  host.innerHTML = (verdict ? `<div class="alert ${verdict.status}">${verdict.message}</div>` : '') + `
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
        <tr><td>Language</td><td>${escapeHtml(r.lang?.name) || '—'}</td></tr>
        <tr><td>Archetype</td><td>${escapeHtml(r.arch?.name) || '—'}</td></tr>
        <tr><td>Style</td><td>${escapeHtml(r.style?.name) || '—'}</td></tr>
        <tr><td>Database</td><td>${escapeHtml(r.db?.name) || '—'}${a.database.migrations ? ` · migrations: ${escapeHtml(a.database.migrations)}` : ''}</td></tr>
        <tr><td>API shape</td><td>${escapeHtml(r.api?.label) || '—'}</td></tr>
        <tr><td>Queue</td><td>${escapeHtml(r.queue?.label) || '—'}</td></tr>
        <tr><td>External APIs</td><td>${a.integration.externalApis.length ? escapeHtml(a.integration.externalApis.join(', ')) : '—'}</td></tr>
      </table>
    </div>
    <div class="final-summary">
      <h3>Security</h3>
      <table>
        <tr><td>Classification</td><td>${escapeHtml(r.cls?.label) || '—'}</td></tr>
        <tr><td>Auth</td><td>${escapeHtml(r.auth?.label) || '—'}</td></tr>
        <tr><td>Secrets</td><td>${escapeHtml(r.secrets?.label) || '—'}</td></tr>
        <tr><td>PII/PHI</td><td>${a.security.pii ? 'Yes' : 'No'}</td></tr>
        <tr><td>Compliance</td><td>${a.security.compliance.length ? escapeHtml(a.security.compliance.join(', ')) : '—'}</td></tr>
        <tr><td>Deploy target</td><td>${escapeHtml(r.deploy?.label) || '—'}</td></tr>
      </table>
    </div>
    <div class="final-summary">
      <h3>Scale</h3>
      <table>
        <tr><td>Users</td><td>${escapeHtml(r.tier?.label) || '—'}</td></tr>
        <tr><td>Traffic</td><td>${escapeHtml(r.pattern?.label) || '—'}</td></tr>
        <tr><td>Geography</td><td>${escapeHtml(a.scale.geo)}</td></tr>
        <tr><td>Data volume</td><td>${escapeHtml(a.scale.volume)}</td></tr>
      </table>
    </div>
    <div class="final-summary">
      <h3>Team (${teammates.length})</h3>
      ${teammates.length === 0 ? '<p style="color:var(--text-tertiary);font-size:13px;">Solo project. rooms.json will be skipped.</p>' : `
        <table>
          ${teammates.map(m => `
            <tr><td>${escapeHtml(m.name)} (${escapeHtml(m.role)})</td><td>${escapeHtml(m.owns || 'shared')}</td></tr>
          `).join('')}
        </table>
      `}
    </div>
  `;

  document.getElementById('generate-btn').disabled = verdict?.status === 'critical';
}

// ============================================================
// Generate + copy
// ============================================================
document.getElementById('generate-btn').addEventListener('click', async () => {
  const btn = document.getElementById('generate-btn');
  btn.disabled = true;
  try {
    await runGenerateWithOverlay();
    btn.textContent = '✓ Downloaded';
    setTimeout(() => { btn.textContent = 'Generate scaffold ZIP'; btn.disabled = false; }, 2200);
  } catch (err) {
    btn.textContent = 'Error — check console';
    btn.style.background = 'var(--critical)';
    console.error(err);
  }
});

async function runGenerateWithOverlay() {
  const overlay = document.getElementById('build-overlay');
  const log = document.getElementById('build-log');
  const summary = document.getElementById('build-summary');
  const title = document.getElementById('build-title');
  overlay.classList.add('visible');
  log.innerHTML = '';
  summary.style.display = 'none';
  summary.innerHTML = '';
  title.textContent = 'Assembling scaffold…';

  const r = resolveAnswers(state.answers);
  const strict = r.cls?.strict;
  const teamCount = r.teammates.length;
  const steps = [
    { path: 'README.md · CLAUDE.md · SECURITY-REPORT.md', tag: 'core' },
    { path: `.claude/settings.local.json · ${strict ? 'strict mode' : 'standard guards'}`, tag: 'guards' },
    { path: `.env.example · ${r.secrets?.id === 'doppler' ? 'Doppler + ESO' : 'plain .env (local only)'}`, tag: 'secrets' },
    { path: `${r.lang?.rootDir || 'python/'}src/main · middleware · routes/health`, tag: 'code' },
    { path: `.pre-commit-config.yaml · .github/workflows/ci.yml`, tag: 'ci' },
    teamCount > 1 ? { path: `rooms.json · ${teamCount} teammates`, tag: 'rooms' } : null,
    state.answers.theme.includeDashboard ? { path: `project-dashboard.html`, tag: 'dashboard' } : null,
  ].filter(Boolean);

  // Stream the log lines
  for (let i = 0; i < steps.length; i++) {
    const s = steps[i];
    const line = document.createElement('div');
    line.className = 'line';
    line.style.animationDelay = `${i * 90}ms`;
    line.innerHTML = `<span class="check">✓</span><span class="path">${escapeHtml(s.path)}</span>`;
    log.appendChild(line);
    await new Promise(r => setTimeout(r, 90));
  }

  // Build the actual zip while the last animation plays
  await generateScaffold(state.answers);

  // Show summary
  const fileCount = 28 + (teamCount > 1 ? 1 : 0) + (state.answers.theme.includeDashboard ? 1 : 0) + (r.db?.id !== 'none' ? 4 : 0);
  const guardCount = strict ? 8 : 6;
  const nextActions = strict ? 5 : 3;
  title.textContent = 'Ready.';
  summary.innerHTML = `
    <div class="stat"><div class="k">Files</div><div class="v">${fileCount}+</div></div>
    <div class="stat"><div class="k">Guards on</div><div class="v">${guardCount}</div></div>
    <div class="stat"><div class="k">Pre-launch actions</div><div class="v">${nextActions}</div></div>
    <div class="stat"><div class="k">Classification</div><div class="v">${r.cls?.label || '—'}</div></div>
  `;
  summary.style.display = 'flex';

  // Let user see the summary briefly before dismissing
  await new Promise(r => setTimeout(r, 1100));
  overlay.classList.remove('visible');
}

document.getElementById('copy-summary').addEventListener('click', async () => {
  const md = summaryAsMarkdown(state.answers);
  await navigator.clipboard.writeText(md);
  const btn = document.getElementById('copy-summary');
  btn.textContent = '✓ Copied';
  setTimeout(() => { btn.textContent = 'Copy summary'; }, 1500);
});

function summaryAsMarkdown(a) {
  const r = resolveAnswers(a);
  return `# ${a.project.name} — Setup Summary

- **Language:** ${r.lang?.name || '—'}
- **Archetype:** ${r.arch?.name || '—'}
- **Style:** ${r.style?.name || '—'}
- **Database:** ${r.db?.name || '—'}
- **Classification:** ${r.cls?.label || '—'}
- **Auth:** ${r.auth?.label || '—'}
- **Secrets:** ${r.secrets?.label || '—'}
- **Deploy:** ${r.deploy?.label || '—'}
- **Team:** ${r.teammates.length} members
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
