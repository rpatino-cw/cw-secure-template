// wizard.js — step navigation, answer state, live summary, renderers.
// Imports stacks.js for metadata, generator.js for zip output.

import {
  LANGUAGES, ARCHETYPES, CODE_STYLES, CODE_STYLE_SUBSTYLES, SCALE_TIERS, TRAFFIC_PATTERNS,
  DATABASES, INTEGRATION_SHAPES, API_SHAPES, QUEUE_SYSTEMS,
  DATA_CLASSIFICATIONS, AUTH_METHODS, SECRET_SYSTEMS,
  COMPLIANCE_FRAMEWORKS, DEPLOY_TARGETS, THEMES, FAMILIES, FAMILY_LANGS,
  FONT_PAIRS, WHY_TEXT,
  resolveAnswers,
} from './stacks.js';
import {
  scaleOutcome, dbPipeline, apiSurfaceDiagram, queueDiagram,
  securityChain, folderTreeGlow, flowchart, dependencyGraph,
  extractDirectoryPaths,
} from './visuals.js';
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
    stack: { family: null, language: null, archetype: null, style: 'modules', substyle: null },
    scale: { users: 'tier-2', pattern: 'steady', geo: 'single', volume: 'small' },
    database: { choice: null, migrations: null },
    integration: {
      shape: 'monolith', api: 'rest', externalApis: [], queue: 'none',
      outboundPipeline: { enabled: false, strictEgress: true },
    },
    security: { classification: null, auth: null, secrets: null, pii: false, compliance: [], deploy: null },
    theme: {
      id: 'cw-light', includeDashboard: true,
      customAccent: '#5b8def', fontPair: 'inter+jbm', tilt3d: true,
    },
    team: [{ name: '', role: 'dev', email: '', slack: '', owns: [] }],
  },
};
// Expose for the expansion layer below (custom events could also work,
// but window access keeps the expansion readable).
window.CW_WIZARD = { state, resolveAnswers };

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

// ============================================================
// EXPANSION LAYER — adds families, substyles, why-expanders,
// live visuals, outbound pipeline, role/owns pickers, folder
// tree glow, flowchart + dep graph, and custom theme card.
// Kept additive so if any of it fails the base wizard still works.
// ============================================================
try { bootExpansion(); } catch (err) { console.error('[wizard-expansion] boot failed', err); }

function bootExpansion() {
  injectExpansionCss();
  mountFamilyStep();
  mountSubstyleSection();
  mountWhyExpanders();
  mountStep3Visual();
  mountStep4Visual();
  mountStep5Enhancements();
  mountStep6Visual();
  mountStep7Enhancements();
  mountStep8Enhancements();
  wireSummaryRepaint();
}

function injectExpansionCss() {
  const css = `
    .why-chip { display:inline-flex; align-items:center; gap:4px; margin-left:8px; padding:2px 8px; border-radius:999px; background:var(--bg-sunken); color:var(--text-tertiary); font-size:11px; font-weight:600; cursor:pointer; border:1px solid var(--border); transition: all var(--duration) var(--ease-out); }
    .why-chip:hover, .why-chip[aria-expanded="true"] { background:var(--accent-bg); color:var(--accent); border-color:var(--accent); }
    .why-chip::before { content:'?'; display:inline-flex; align-items:center; justify-content:center; width:12px; height:12px; border-radius:50%; background:currentColor; color:var(--bg-elevated); font-size:9px; font-weight:800; }
    .why-body { margin:8px 0 14px; padding:12px 14px; border-left:3px solid var(--accent); background:var(--accent-bg); border-radius:0 8px 8px 0; font-size:13px; line-height:1.55; color:var(--text-secondary); display:none; }
    .why-body.visible { display:block; animation: fadeIn var(--duration) var(--ease-out); }
    .why-body strong { color:var(--text-primary); display:block; margin-bottom:4px; font-size:13.5px; }
    .why-body ul { margin:0; padding-left:18px; }
    .why-body li { margin:3px 0; }

    .family-grid { display:grid; gap:12px; grid-template-columns:repeat(auto-fill,minmax(180px,1fr)); margin-bottom:28px; }
    .family-card { background:var(--bg-elevated); border:1px solid var(--border); border-radius:12px; padding:14px 16px; cursor:pointer; transition:all var(--duration) var(--ease-out); text-align:left; }
    .family-card:hover { border-color:var(--text-tertiary); transform:translateY(-1px); }
    .family-card.selected { border-color:var(--accent); background:var(--accent-bg); box-shadow:0 0 0 3px oklch(55% 0.14 290 / 0.1); }
    .family-card .ico { font-size:22px; margin-bottom:6px; }
    .family-card .lbl { font-weight:700; font-size:14px; margin-bottom:2px; }
    .family-card .sub { font-size:12px; color:var(--text-secondary); line-height:1.4; }
    .family-card .star { position:absolute; top:8px; right:10px; font-size:10px; color:var(--accent); font-weight:700; }
    .family-card { position:relative; }

    .cw-rec-badge { display:inline-block; padding:2px 6px; border-radius:4px; background:linear-gradient(135deg,#5b8def,#22d3ee); color:white; font-size:9px; font-weight:700; letter-spacing:0.05em; margin-left:6px; vertical-align:middle; }

    .substyle-section { margin-top:24px; padding-top:20px; border-top:1px dashed var(--border); }
    .substyle-grid { display:grid; gap:10px; grid-template-columns:repeat(auto-fill,minmax(220px,1fr)); margin-top:10px; }
    .substyle-card { background:var(--bg-elevated); border:1px solid var(--border); border-radius:10px; padding:12px 14px; cursor:pointer; text-align:left; transition:all var(--duration) var(--ease-out); }
    .substyle-card:hover { border-color:var(--text-tertiary); }
    .substyle-card.selected { border-color:var(--accent); background:var(--accent-bg); box-shadow:0 0 0 3px oklch(55% 0.14 290 / 0.1); }
    .substyle-card .lbl { font-weight:700; font-size:13px; }
    .substyle-card .blurb { font-size:11.5px; color:var(--text-secondary); margin-top:3px; line-height:1.45; }

    .visual-panel { margin-top:20px; padding:16px 20px; background:var(--bg-elevated); border:1px solid var(--border-subtle); border-radius:12px; }
    .visual-panel h4 { font-size:12px; text-transform:uppercase; letter-spacing:0.08em; color:var(--text-tertiary); margin-bottom:10px; font-weight:600; font-family:'DM Sans'; }
    .visual-panel svg { display:block; }

    .outbound-box { margin-top:18px; padding:14px 16px; border-radius:10px; border:1px dashed var(--border); background:var(--bg-sunken); }
    .outbound-box .row { display:flex; align-items:flex-start; gap:10px; }
    .outbound-box .expl { display:none; margin-top:10px; padding:10px 12px; background:var(--bg-elevated); border-radius:8px; font-size:12.5px; line-height:1.55; color:var(--text-secondary); border-left:3px solid var(--accent); }
    .outbound-box.enabled .expl { display:block; }
    .outbound-box .sub-toggle { display:none; margin-top:8px; }
    .outbound-box.enabled .sub-toggle { display:flex; align-items:center; gap:8px; }

    .theme-customize { display:none; margin-top:12px; padding:14px 16px; background:var(--bg-sunken); border-radius:10px; }
    .theme-customize.visible { display:grid; gap:10px; grid-template-columns:repeat(auto-fill,minmax(220px,1fr)); }
    .theme-customize label { font-size:11px; text-transform:uppercase; letter-spacing:0.06em; color:var(--text-tertiary); font-weight:600; display:block; margin-bottom:4px; }
    .theme-customize input[type="color"] { width:100%; height:36px; border:1px solid var(--border); border-radius:6px; background:transparent; cursor:pointer; padding:2px; }
    .theme-customize select { width:100%; padding:7px 10px; border:1px solid var(--border); border-radius:6px; background:var(--bg-elevated); font-size:13px; }

    .theme-preview-row.tilt-3d { perspective:900px; }
    .theme-preview-row.tilt-3d .theme-preview-render { transition: transform 420ms var(--ease-out); transform-style: preserve-3d; }
    .theme-preview-row.tilt-3d:hover .theme-preview-render { transform: rotateX(6deg) rotateY(-10deg) translateZ(12px); box-shadow: -18px 22px 48px oklch(22% 0.02 260 / 0.18); }
    @media (prefers-reduced-motion: reduce) { .theme-preview-row.tilt-3d:hover .theme-preview-render { transform:none; } }

    .team-table td select { width:100%; padding:6px 8px; border:1px solid var(--border); border-radius:5px; background:var(--bg-elevated); font-size:13px; }
    .owns-picker { position:relative; }
    .owns-chips { display:flex; flex-wrap:wrap; gap:4px; padding:6px; background:var(--bg-elevated); border:1px solid var(--border); border-radius:6px; min-height:34px; cursor:pointer; }
    .owns-chip { display:inline-flex; align-items:center; gap:4px; padding:2px 8px; background:var(--accent-bg); color:var(--accent); border-radius:4px; font-size:11px; font-weight:600; }
    .owns-chip .x { cursor:pointer; opacity:0.6; }
    .owns-chip .x:hover { opacity:1; }
    .owns-chips .ph { color:var(--text-tertiary); font-size:12px; font-style:italic; }
    .owns-menu { display:none; position:absolute; z-index:10; top:100%; left:0; right:0; max-height:220px; overflow-y:auto; background:var(--bg-elevated); border:1px solid var(--border); border-radius:6px; margin-top:4px; box-shadow:0 8px 24px oklch(22% 0.02 260 / 0.12); }
    .owns-menu.open { display:block; }
    .owns-menu .opt { padding:6px 10px; font-size:12px; font-family:'JetBrains Mono',monospace; cursor:pointer; border-bottom:1px solid var(--border-subtle); }
    .owns-menu .opt:hover { background:var(--bg-sunken); }
    .owns-menu .opt.checked { background:var(--accent-bg); color:var(--accent); font-weight:600; }
    .owns-menu .opt.checked::before { content:'✓ '; }

    .report-card { margin-top:18px; padding:18px 22px; background:var(--bg-elevated); border:1px solid var(--border); border-radius:12px; }
    .report-card h4 { font-size:12px; text-transform:uppercase; letter-spacing:0.08em; color:var(--text-tertiary); margin-bottom:10px; font-weight:600; }
    .report-card table { width:100%; border-collapse:collapse; font-size:13px; }
    .report-card td { padding:8px 6px; border-bottom:1px solid var(--border-subtle); }
    .report-card td:first-child { color:var(--text-secondary); font-weight:500; width:40%; }
    .report-card td:last-child { font-family:'JetBrains Mono',monospace; color:var(--text-primary); font-size:12px; }
    @media print {
      .sidebar-left, .sidebar-right, .step-footer, .why-chip, .build-overlay { display:none !important; }
      .shell { display:block; } main { max-width:100%; padding:0; }
      .step:not([data-step="8"]) { display:none !important; }
      .report-card, .visual-panel { break-inside:avoid; }
    }
  `;
  const style = document.createElement('style');
  style.textContent = css;
  document.head.appendChild(style);
}

// ---------------- Family step ----------------
function mountFamilyStep() {
  const step2 = document.querySelector('.step[data-step="2"]');
  if (!step2) return;
  // Insert family grid right after the lede.
  const lede = step2.querySelector('.lede');
  const familySection = document.createElement('div');
  familySection.id = 'family-section';
  familySection.style.marginBottom = '28px';
  familySection.innerHTML = `
    <h3 style="font-size:20px;margin-bottom:8px;">What kind of project is this?</h3>
    <p style="color:var(--text-secondary);font-size:14px;margin-bottom:16px;">This narrows recommendations — you can still pick anything below.</p>
    <div class="family-grid" id="family-grid"></div>
  `;
  lede.insertAdjacentElement('afterend', familySection);
  renderFamilies();
}

function renderFamilies() {
  const host = document.getElementById('family-grid');
  if (!host) return;
  host.innerHTML = FAMILIES.map(f => `
    <button class="family-card ${state.answers.stack.family === f.id ? 'selected' : ''}" data-family="${f.id}">
      ${f.recommended ? '<span class="star">★ DEFAULT</span>' : ''}
      <div class="ico">${f.icon}</div>
      <div class="lbl">${f.label}</div>
      <div class="sub">${f.blurb}</div>
    </button>
  `).join('');
  host.querySelectorAll('[data-family]').forEach(btn => {
    btn.addEventListener('click', () => {
      state.answers.stack.family = btn.dataset.family;
      renderFamilies();
      // Re-render language list with the family's preferred order.
      reorderLanguagesByFamily();
    });
  });
}

function reorderLanguagesByFamily() {
  const fam = state.answers.stack.family;
  if (!fam) { renderLanguages(); return; }
  const preferred = FAMILY_LANGS[fam] || [];
  const host = document.getElementById('lang-grid');
  const order = [...preferred, ...LANGUAGES.map(l => l.id).filter(id => !preferred.includes(id))];
  const ordered = order.map(id => LANGUAGES.find(l => l.id === id)).filter(Boolean);
  host.innerHTML = ordered.map(lang => `
    <button class="card ${state.answers.stack.language === lang.id ? 'selected' : ''}" data-lang="${lang.id}">
      ${lang.recommended ? '<span class="badge">Recommended</span>' : ''}
      ${lang.cwRecommended ? '<span class="cw-rec-badge">CW ★</span>' : ''}
      <div class="icon">${lang.icon}</div>
      <h3>${lang.name}</h3>
      <div class="blurb">${lang.blurb}</div>
    </button>
  `).join('');
  host.querySelectorAll('[data-lang]').forEach(btn => {
    btn.addEventListener('click', () => {
      state.answers.stack.language = btn.dataset.lang;
      state.answers.stack.archetype = null;
      reorderLanguagesByFamily();
      renderArchetypesWithCwBadge();
      document.getElementById('archetype-section').style.display = 'block';
      document.getElementById('style-section').style.display = 'none';
      updateStep2NextButton();
      renderSummary();
    });
  });
}

function renderArchetypesWithCwBadge() {
  if (!state.answers.stack.language) return;
  const archs = ARCHETYPES[state.answers.stack.language];
  const host = document.getElementById('arch-grid');
  host.innerHTML = archs.map(a => `
    <button class="card ${state.answers.stack.archetype === a.id ? 'selected' : ''}" data-arch="${a.id}">
      ${a.cwRecommended ? '<span class="cw-rec-badge" style="position:absolute;top:12px;right:12px;">CW ★</span>' : ''}
      <h3>${a.name}</h3>
      <div class="blurb">${a.blurb}</div>
    </button>
  `).join('');
  host.querySelectorAll('[data-arch]').forEach(btn => {
    btn.addEventListener('click', () => {
      state.answers.stack.archetype = btn.dataset.arch;
      renderArchetypesWithCwBadge();
      renderArchetypePreview();
      renderCodeStyles();
      document.getElementById('style-section').style.display = 'block';
      updateStep2NextButton();
      mountSubstyleSection();
      renderSummary();
    });
  });
  if (state.answers.stack.archetype) renderArchetypePreview();
}

// ---------------- Substyle picker ----------------
function mountSubstyleSection() {
  const styleSection = document.getElementById('style-section');
  if (!styleSection) return;
  // Create it if missing.
  let sub = document.getElementById('substyle-section');
  if (!sub) {
    sub = document.createElement('div');
    sub.id = 'substyle-section';
    sub.className = 'substyle-section';
    sub.style.display = 'none';
    sub.innerHTML = `
      <h4 style="font-size:14px;font-weight:700;margin-bottom:4px;">Go deeper: pick a pattern</h4>
      <p style="font-size:12.5px;color:var(--text-secondary);margin-bottom:8px;">Optional. This fine-tunes the folder layout the generator emits.</p>
      <div class="substyle-grid" id="substyle-grid"></div>
    `;
    styleSection.appendChild(sub);
  }
  renderSubstyles();
  // Wire re-render when the parent style changes.
  document.querySelectorAll('#style-grid [data-style]').forEach(btn => {
    btn.addEventListener('click', () => { setTimeout(renderSubstyles, 10); });
  });
}

function renderSubstyles() {
  const style = CODE_STYLES.find(s => s.id === state.answers.stack.style);
  const section = document.getElementById('substyle-section');
  const grid = document.getElementById('substyle-grid');
  if (!style || !style.substyles || !grid) { if (section) section.style.display = 'none'; return; }
  section.style.display = 'block';
  grid.innerHTML = style.substyles.map(id => {
    const sub = CODE_STYLE_SUBSTYLES[id];
    if (!sub) return '';
    return `
      <button class="substyle-card ${state.answers.stack.substyle === id ? 'selected' : ''}" data-sub="${id}">
        <div class="lbl">${sub.name}</div>
        <div class="blurb">${sub.blurb}</div>
      </button>
    `;
  }).join('');
  grid.querySelectorAll('[data-sub]').forEach(btn => {
    btn.addEventListener('click', () => {
      state.answers.stack.substyle = btn.dataset.sub === state.answers.stack.substyle ? null : btn.dataset.sub;
      renderSubstyles();
      renderSummary();
    });
  });
}

// ---------------- Why expanders ----------------
function mountWhyExpanders() {
  for (const [stepId, questions] of Object.entries(WHY_TEXT)) {
    for (const [qId, info] of Object.entries(questions)) {
      const label = findQuestionLabel(stepId, qId);
      if (!label) continue;
      if (label.querySelector('.why-chip')) continue;
      const chip = document.createElement('button');
      chip.className = 'why-chip';
      chip.type = 'button';
      chip.setAttribute('aria-expanded', 'false');
      chip.textContent = 'why';
      const body = document.createElement('div');
      body.className = 'why-body';
      body.innerHTML = `<strong>${info.headline}</strong><ul>${info.bullets.map(b => `<li>${b}</li>`).join('')}</ul>`;
      chip.addEventListener('click', () => {
        const open = body.classList.toggle('visible');
        chip.setAttribute('aria-expanded', String(open));
      });
      label.appendChild(chip);
      label.insertAdjacentElement('afterend', body);
    }
  }
}

function findQuestionLabel(stepId, qId) {
  const step = document.querySelector(`.step[data-step="${stepId}"]`);
  if (!step) return null;
  // Map question ids to the label text they live under.
  const map = {
    '2': { family: 'What kind of project is this?', language: 'Pick your stack.', archetype: 'Archetype', style: 'Code style', substyle: 'Go deeper: pick a pattern' },
    '3': { users: 'Concurrent users', pattern: 'Traffic pattern', geo: 'Geographic reach', volume: 'Data volume' },
    '4': { choice: 'Pick a database.', migrations: 'Migrations tool' },
    '5': { shape: 'Deployable shape', api: 'API exposed by this service', queue: 'Queue / event system', outbound: 'Secure outbound API pipeline' },
    '6': { classification: 'Data classification', auth: 'Auth method', secrets: 'Secret management', pii: 'Handles PII / PHI', compliance: 'Compliance frameworks (multi-select)', deploy: 'Deployment target' },
    '7': { theme: 'Theme', roster: 'Team roster', owns: 'Owns' },
  };
  const needle = map[stepId]?.[qId];
  if (!needle) return null;
  const candidates = step.querySelectorAll('label, h3, h4');
  for (const el of candidates) {
    if (el.textContent.trim().toLowerCase().startsWith(needle.toLowerCase()) && !el.closest('.why-body')) return el;
  }
  return null;
}

// ---------------- Step 3 visual ----------------
function mountStep3Visual() {
  const step3 = document.querySelector('.step[data-step="3"]');
  const callout = step3?.querySelector('#scale-callout');
  if (!callout) return;
  const panel = document.createElement('div');
  panel.className = 'visual-panel';
  panel.id = 'scale-visual-panel';
  panel.innerHTML = `<h4>Outcome preview</h4><div id="scale-visual">${scaleOutcome(state.answers)}</div>`;
  callout.insertAdjacentElement('afterend', panel);
}

function repaintScaleVisual() {
  const host = document.getElementById('scale-visual');
  if (host) host.innerHTML = scaleOutcome(state.answers);
}

// ---------------- Step 4 visual ----------------
function mountStep4Visual() {
  const step4 = document.querySelector('.step[data-step="4"]');
  const pipe = step4?.querySelector('#db-pipeline');
  if (!pipe) return;
  const panel = document.createElement('div');
  panel.className = 'visual-panel';
  panel.id = 'db-visual-panel';
  panel.innerHTML = `<h4>Data pipeline (visual)</h4><div id="db-visual"></div>`;
  pipe.insertAdjacentElement('afterend', panel);
}

function repaintDbVisual() {
  const host = document.getElementById('db-visual');
  if (!host) return;
  const db = DATABASES.find(d => d.id === state.answers.database.choice);
  host.innerHTML = db ? dbPipeline(state.answers, db) : '<div style="color:var(--text-tertiary);font-size:13px;font-style:italic;">Pick a database to see the pipeline.</div>';
}

// ---------------- Step 5 enhancements ----------------
function mountStep5Enhancements() {
  const step5 = document.querySelector('.step[data-step="5"]');
  if (!step5) return;
  // API visual after the api-grid field.
  const apiField = step5.querySelector('.field:has(#api-grid)') || step5.querySelectorAll('.field')[1];
  if (apiField) {
    const panel = document.createElement('div');
    panel.className = 'visual-panel';
    panel.id = 'api-visual-panel';
    panel.innerHTML = `<h4>API surface comparison</h4><div id="api-visual">${apiSurfaceDiagram(state.answers)}</div>`;
    apiField.insertAdjacentElement('afterend', panel);
  }
  // Queue visual after the queue-grid field.
  const queueField = step5.querySelector('.field:has(#queue-grid)') || step5.querySelectorAll('.field')[3];
  if (queueField) {
    const panel = document.createElement('div');
    panel.className = 'visual-panel';
    panel.id = 'queue-visual-panel';
    panel.innerHTML = `<h4>Queue / event system</h4><div id="queue-visual">${queueDiagram(state.answers)}</div>`;
    queueField.insertAdjacentElement('afterend', panel);
  }
  // Outbound pipeline toggle right before the step footer.
  const footer = step5.querySelector('.step-footer');
  if (footer) {
    const box = document.createElement('div');
    box.className = 'outbound-box';
    box.id = 'outbound-box';
    box.innerHTML = `
      <label class="toggle" style="margin:0;"><input type="checkbox" id="outbound-enabled"><span class="switch"></span><span><strong>Secure outbound API pipeline</strong> — this service calls external APIs</span></label>
      <div class="expl">
        Wires an <code class="mono">egress</code> middleware with TLS enforcement, a timeout budget, and a circuit breaker.
        Pre-commit blocks raw <code class="mono">fetch</code> / <code class="mono">requests</code> / <code class="mono">http.Client</code> outside that module so a popped dependency can't phone home.
        Adds <code class="mono">EGRESS_ALLOWLIST</code> to <code class="mono">.env.example</code> and an integration test that fails if an egress call escapes the middleware.
      </div>
      <label class="toggle sub-toggle"><input type="checkbox" id="outbound-strict" checked><span class="switch"></span><span>Enforce strict egress — only allowlisted hostnames pass</span></label>
    `;
    footer.insertAdjacentElement('beforebegin', box);
    const enabledInput = box.querySelector('#outbound-enabled');
    const strictInput = box.querySelector('#outbound-strict');
    enabledInput.checked = state.answers.integration.outboundPipeline.enabled;
    strictInput.checked = state.answers.integration.outboundPipeline.strictEgress;
    if (enabledInput.checked) box.classList.add('enabled');
    enabledInput.addEventListener('change', () => {
      state.answers.integration.outboundPipeline.enabled = enabledInput.checked;
      box.classList.toggle('enabled', enabledInput.checked);
      renderSummary();
    });
    strictInput.addEventListener('change', () => {
      state.answers.integration.outboundPipeline.strictEgress = strictInput.checked;
    });
  }
}

function repaintApiVisual() { const h = document.getElementById('api-visual'); if (h) h.innerHTML = apiSurfaceDiagram(state.answers); }
function repaintQueueVisual() { const h = document.getElementById('queue-visual'); if (h) h.innerHTML = queueDiagram(state.answers); }

// ---------------- Step 6 visual ----------------
function mountStep6Visual() {
  const step6 = document.querySelector('.step[data-step="6"]');
  const footer = step6?.querySelector('.step-footer');
  if (!footer) return;
  const panel = document.createElement('div');
  panel.className = 'visual-panel';
  panel.id = 'security-visual-panel';
  panel.innerHTML = `<h4>Security chain — request flow</h4><div id="security-visual">${securityChain(state.answers)}</div>`;
  footer.insertAdjacentElement('beforebegin', panel);
}

function repaintSecurityVisual() {
  const h = document.getElementById('security-visual');
  if (h) h.innerHTML = securityChain(state.answers);
}

// ---------------- Step 7 enhancements ----------------
function mountStep7Enhancements() {
  // Custom theme card's customize block.
  const customizeBlock = document.createElement('div');
  customizeBlock.className = 'theme-customize';
  customizeBlock.id = 'theme-customize';
  customizeBlock.innerHTML = `
    <div><label>Accent color</label><input type="color" id="custom-accent" value="${state.answers.theme.customAccent}"></div>
    <div><label>Font pair</label><select id="custom-fonts">${FONT_PAIRS.map(f => `<option value="${f.id}">${f.label}</option>`).join('')}</select></div>
    <div><label><input type="checkbox" id="custom-tilt" ${state.answers.theme.tilt3d ? 'checked' : ''}> 3D tilt preview on hover</label></div>
    <div style="grid-column: 1 / -1; padding-top:6px; font-size:12px; color:var(--text-tertiary);">These ride into <code class="mono">project-dashboard.html</code> as CSS vars — picking here is picking there.</div>
  `;
  const themeGrid = document.getElementById('theme-grid');
  themeGrid.insertAdjacentElement('afterend', customizeBlock);
  const showCustomize = () => {
    const isCustom = state.answers.theme.id === 'custom';
    customizeBlock.classList.toggle('visible', isCustom);
    document.documentElement.style.setProperty('--accent', isCustom ? state.answers.theme.customAccent : '');
    // 3D tilt class
    document.querySelectorAll('.theme-preview-row').forEach(el => {
      el.classList.toggle('tilt-3d', state.answers.theme.tilt3d);
    });
  };
  showCustomize();
  themeGrid.addEventListener('click', () => setTimeout(showCustomize, 10));
  customizeBlock.querySelector('#custom-accent').addEventListener('input', (e) => {
    state.answers.theme.customAccent = e.target.value;
    document.documentElement.style.setProperty('--accent', e.target.value);
    renderSummary();
  });
  customizeBlock.querySelector('#custom-fonts').addEventListener('change', (e) => {
    state.answers.theme.fontPair = e.target.value;
  });
  customizeBlock.querySelector('#custom-tilt').addEventListener('change', (e) => {
    state.answers.theme.tilt3d = e.target.checked;
    showCustomize();
  });
  // Upgrade team rendering to a role select + owns multi-select.
  upgradeTeamTable();
  // Add folder-tree-glow preview.
  addFolderTreePreview();
}

function upgradeTeamTable() {
  const origRender = renderTeam;
  // Replace the onclick renderer by patching the function indirectly.
  window.renderTeamV2 = function() {
    const host = document.getElementById('team-rows');
    if (state.answers.team.length === 0) state.answers.team.push({ name: '', role: 'dev', email: '', slack: '', owns: [] });
    // Normalize legacy string owns to arrays.
    state.answers.team.forEach(m => { if (typeof m.owns === 'string') m.owns = m.owns ? m.owns.split(',').map(s => s.trim()).filter(Boolean) : []; });
    const roleOpts = ['dev', 'reviewer', 'approver', 'secops', 'eng-mgr', 'external'];
    host.innerHTML = state.answers.team.map((m, i) => `
      <tr data-idx="${i}">
        <td><input data-f="name" value="${escapeHtml(m.name || '')}" placeholder="Romeo Patino"></td>
        <td><select data-f="role">${roleOpts.map(r => `<option value="${r}" ${m.role === r ? 'selected' : ''}>${r}</option>`).join('')}</select></td>
        <td><input data-f="email" value="${escapeHtml(m.email || '')}" placeholder="rpatino@coreweave.com"></td>
        <td><input data-f="slack" value="${escapeHtml(m.slack || '')}" placeholder="@rpatino"></td>
        <td class="owns-picker-cell"></td>
        <td><button class="remove-row" data-remove="${i}">×</button></td>
      </tr>
    `).join('');
    host.querySelectorAll('tr').forEach((tr, i) => {
      tr.querySelectorAll('input,select').forEach(inp => {
        inp.addEventListener('input', () => {
          state.answers.team[i][inp.dataset.f] = inp.value.trim();
          renderSummary();
          repaintFolderTree();
        });
        inp.addEventListener('change', () => {
          state.answers.team[i][inp.dataset.f] = inp.value.trim();
          renderSummary();
          repaintFolderTree();
        });
      });
      tr.querySelector('[data-remove]').addEventListener('click', () => {
        state.answers.team.splice(i, 1);
        window.renderTeamV2();
        renderSummary();
        repaintFolderTree();
      });
      mountOwnsPicker(tr.querySelector('.owns-picker-cell'), i);
    });
  };
  window.renderTeamV2();
  const addBtn = document.getElementById('add-teammate');
  addBtn.onclick = () => {
    state.answers.team.push({ name: '', role: 'dev', email: '', slack: '', owns: [] });
    window.renderTeamV2();
  };
}

function mountOwnsPicker(cell, memberIdx) {
  if (!cell) return;
  const member = state.answers.team[memberIdx];
  const archTree = currentArchTree();
  const dirs = extractDirectoryPaths(archTree).map(d => d.replace(/\/$/, ''));
  const render = () => {
    const chips = (member.owns || []).map((o, i) => `<span class="owns-chip">${escapeHtml(o)}<span class="x" data-off="${i}">×</span></span>`).join('');
    const ph = chips ? '' : '<span class="ph">click to assign folders</span>';
    const menu = dirs.map(d => `<div class="opt ${member.owns.includes(d) ? 'checked' : ''}" data-dir="${escapeHtml(d)}">${escapeHtml(d)}</div>`).join('');
    cell.innerHTML = `
      <div class="owns-picker">
        <div class="owns-chips">${chips}${ph}</div>
        <div class="owns-menu">${menu}</div>
      </div>
    `;
    const wrap = cell.querySelector('.owns-picker');
    const chipsBox = cell.querySelector('.owns-chips');
    const menuBox = cell.querySelector('.owns-menu');
    chipsBox.addEventListener('click', (e) => {
      if (e.target.classList.contains('x')) {
        const idx = parseInt(e.target.dataset.off);
        member.owns.splice(idx, 1);
        render();
        repaintFolderTree();
        renderSummary();
        return;
      }
      menuBox.classList.toggle('open');
    });
    menuBox.addEventListener('click', (e) => {
      const opt = e.target.closest('.opt');
      if (!opt) return;
      const dir = opt.dataset.dir;
      const idx = member.owns.indexOf(dir);
      if (idx >= 0) member.owns.splice(idx, 1); else member.owns.push(dir);
      render();
      repaintFolderTree();
      renderSummary();
    });
    document.addEventListener('click', (e) => {
      if (!wrap.contains(e.target)) menuBox.classList.remove('open');
    });
  };
  render();
}

function currentArchTree() {
  const lang = state.answers.stack.language;
  if (!lang) return null;
  const arch = ARCHETYPES[lang]?.find(a => a.id === state.answers.stack.archetype);
  return arch?.tree || null;
}

function addFolderTreePreview() {
  const step7 = document.querySelector('.step[data-step="7"]');
  const footer = step7?.querySelector('.step-footer');
  if (!footer) return;
  const panel = document.createElement('div');
  panel.className = 'visual-panel';
  panel.id = 'folder-preview-panel';
  panel.innerHTML = `<h4>Ownership preview — directories glow with the owner's accent</h4><div id="folder-preview"></div>`;
  footer.insertAdjacentElement('beforebegin', panel);
  repaintFolderTree();
}

function repaintFolderTree() {
  const host = document.getElementById('folder-preview');
  if (!host) return;
  const tree = currentArchTree();
  const accents = ['#5b8def', '#ef4444', '#22d3ee', '#f59e0b', '#8b5cf6', '#10b981'];
  const ownership = new Map();
  state.answers.team.forEach((m, i) => {
    if (!m.name || !m.owns) return;
    const accent = accents[i % accents.length];
    (Array.isArray(m.owns) ? m.owns : []).forEach(dir => {
      ownership.set(dir.replace(/\/$/, ''), { name: m.name, accent });
    });
  });
  host.innerHTML = folderTreeGlow(tree, ownership);
}

// ---------------- Step 8 enhancements ----------------
function mountStep8Enhancements() {
  const step8 = document.querySelector('.step[data-step="8"]');
  const summaryHost = step8?.querySelector('#final-summary-host');
  if (!summaryHost) return;
  // Visual panels above the summary table, only populated on step-8 entry.
  const visPanel = document.createElement('div');
  visPanel.id = 'final-visuals';
  visPanel.innerHTML = `
    <div class="visual-panel"><h4>Request lifecycle</h4><div id="final-flowchart"></div></div>
    <div class="visual-panel"><h4>Module dependency graph</h4><div id="final-depgraph"></div></div>
    <div class="report-card" id="final-report-card"><h4>Every answer → what it ships</h4><div id="final-report-body"></div></div>
  `;
  summaryHost.insertAdjacentElement('beforebegin', visPanel);
  // Print-to-PDF button next to the existing generate button.
  const genBtn = document.getElementById('generate-btn');
  if (genBtn && !document.getElementById('print-pdf')) {
    const print = document.createElement('button');
    print.id = 'print-pdf';
    print.className = 'btn-secondary';
    print.textContent = 'Print / save as PDF';
    print.onclick = () => window.print();
    genBtn.insertAdjacentElement('beforebegin', print);
  }
}

function repaintStep8Visuals() {
  const resolved = resolveAnswers(state.answers);
  const fc = document.getElementById('final-flowchart');
  const dg = document.getElementById('final-depgraph');
  const rc = document.getElementById('final-report-body');
  if (fc) fc.innerHTML = flowchart(state.answers, resolved);
  if (dg) dg.innerHTML = dependencyGraph(state.answers, resolved);
  if (rc) rc.innerHTML = reportCardRows(state.answers, resolved);
}

function reportCardRows(a, r) {
  const rows = [
    ['Language', `${r.lang?.name || '—'} → ${r.lang?.rootDir || ''}`],
    ['Archetype', `${r.arch?.name || '—'} → folder tree + entry point`],
    ['Code style', a.stack.substyle ? `${r.style?.name} · ${CODE_STYLE_SUBSTYLES[a.stack.substyle]?.name}` : (r.style?.name || '—')],
    ['Scale tier', `${r.tier?.label || '—'} → pod min/max + CI budget gates`],
    ['Database', `${r.db?.name || '—'} → ${a.database.migrations ? 'migrations: ' + a.database.migrations : 'no migrations'}`],
    ['API', `${r.api?.label || '—'} → routes/ file shape + content-type guard`],
    ['Queue', r.queue?.id === 'none' ? 'None (synchronous)' : `${r.queue?.label} → worker entry + idempotency rule`],
    ['Outbound pipeline', a.integration.outboundPipeline.enabled ? `middleware/egress.* emitted · strict=${a.integration.outboundPipeline.strictEgress}` : 'not configured'],
    ['Classification', `${r.cls?.label || '—'} → ${r.cls?.strict ? 'strict guards on' : 'standard guards'}`],
    ['Auth', `${r.auth?.label || '—'} → middleware auto-wired`],
    ['Secrets', `${r.secrets?.label || '—'} → ${r.secrets?.id === 'doppler' ? 'doppler.yaml + ESO manifest' : '.env.example only'}`],
    ['PII / PHI', a.security.pii ? 'scanner + redactor + DSR hooks' : 'off'],
    ['Compliance', a.security.compliance.length ? a.security.compliance.join(' · ') : 'none'],
    ['Deploy', `${r.deploy?.label || '—'}`],
    ['Theme', `${r.theme?.label || '—'}${a.theme.id === 'custom' ? ` · accent ${a.theme.customAccent}` : ''}`],
    ['Team', r.teammates.length ? `${r.teammates.length} member(s) → rooms.json` : 'solo — rooms.json skipped'],
  ];
  return `<table>${rows.map(([k, v]) => `<tr><td>${escapeHtml(k)}</td><td>${escapeHtml(v)}</td></tr>`).join('')}</table>`;
}

// ---------------- Cross-cutting repaint hooks ----------------
function wireSummaryRepaint() {
  const orig = renderSummary;
  window.renderSummaryV2 = () => {
    orig();
    repaintScaleVisual();
    repaintDbVisual();
    repaintApiVisual();
    repaintQueueVisual();
    repaintSecurityVisual();
    repaintFolderTree();
  };
  // Monkey-patch only by installing an observer — renderSummary is called by
  // every state-mutating handler, so we listen for DOM mutations on the summary
  // host and repaint visuals after each.
  const host = document.getElementById('summary-host');
  if (!host) return;
  const obs = new MutationObserver(() => {
    repaintScaleVisual();
    repaintDbVisual();
    repaintApiVisual();
    repaintQueueVisual();
    repaintSecurityVisual();
    repaintFolderTree();
  });
  obs.observe(host, { childList: true, subtree: true });
}

// Hook into step navigation: repaint step-8 visuals when entering step 8.
const origGoToStep = goToStep;
window.addEventListener('cw-wizard-step', () => {});  // placeholder
// Shadow the original navigation by observing the DOM attribute change on the step 8 panel.
const step8Observer = new MutationObserver(() => {
  if (document.querySelector('.step[data-step="8"].active')) repaintStep8Visuals();
});
const step8 = document.querySelector('.step[data-step="8"]');
if (step8) step8Observer.observe(step8, { attributes: true, attributeFilter: ['class'] });
