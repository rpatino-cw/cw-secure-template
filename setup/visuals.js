// visuals.js — pure SVG generators for the setup wizard.
// Every function takes an `answers` object (or resolved context) and returns
// an SVG string. No DOM dependencies, no side effects. Consumed by wizard.js.
//
// Shared palette. All visuals pull from `--accent` / `--text-primary` via
// CSS when rendered inside the wizard, but fall back to these hexes when
// SVG is embedded standalone (review step PDF export, etc.).
const C = {
  bg: '#f5efe4',
  elev: '#ffffff',
  line: '#d9cdb6',
  text: '#1a1a2e',
  muted: '#7a6f5a',
  accent: '#5b8def',
  pass: '#2f9e6b',
  warn: '#c78a00',
  crit: '#c73030',
  dim: '#b0a899',
};

const SVG_DEFS = `
  <defs>
    <linearGradient id="grad-accent" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="var(--accent, #5b8def)" stop-opacity="1"/>
      <stop offset="100%" stop-color="var(--accent, #5b8def)" stop-opacity="0.35"/>
    </linearGradient>
    <linearGradient id="grad-pass" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="#2f9e6b"/>
      <stop offset="100%" stop-color="#4bbf8a"/>
    </linearGradient>
    <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation="3" result="blur"/>
      <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
    <filter id="softshadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="1" stdDeviation="1.5" flood-opacity="0.12"/>
    </filter>
  </defs>
`;

const wrap = (w, h, body) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="100%" preserveAspectRatio="xMidYMid meet" role="img" aria-hidden="false">${SVG_DEFS}${body}</svg>`;

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));

// ============================================================
// C1 — Scale outcome (step 3)
// Shows pods, cache layer, regions. Sidebar lists what CI enforces.
// ============================================================
export function scaleOutcome(answers) {
  const userTier = answers.scale.users;
  const pattern = answers.scale.pattern;
  const geo = answers.scale.geo;
  const volume = answers.scale.volume;

  const podCount = { 'tier-1': 1, 'tier-2': 3, 'tier-3': 8, 'tier-4': 16 }[userTier] || 3;
  const cacheOn = pattern === 'spiky' || userTier === 'tier-3' || userTier === 'tier-4';
  const cacheLabel = cacheOn ? (userTier === 'tier-4' ? 'Redis (multi-AZ)' : 'Redis') : 'No cache';
  const regions = geo === 'global' ? 4 : geo === 'multi' ? 2 : 1;

  // Pods
  const podW = 26, podH = 36, podGap = 6;
  const podStartX = 60, podY = 60;
  const pods = Array.from({ length: Math.min(podCount, 12) }, (_, i) => {
    const x = podStartX + i * (podW + podGap);
    return `<g transform="translate(${x},${podY})">
      <rect width="${podW}" height="${podH}" rx="5" fill="url(#grad-accent)" stroke="var(--accent, ${C.accent})" stroke-width="1.2" filter="url(#softshadow)"/>
      <text x="${podW/2}" y="${podH/2 + 4}" text-anchor="middle" font-size="10" font-family="ui-monospace, SFMono-Regular, monospace" fill="white" font-weight="600">pod</text>
    </g>`;
  }).join('');
  const podOverflow = podCount > 12 ? `<text x="${podStartX + 12 * (podW+podGap) + 4}" y="${podY + 24}" font-size="12" fill="${C.muted}">+ ${podCount-12} more</text>` : '';

  // Cache layer
  const cacheY = 130;
  const cacheBox = cacheOn ? `
    <rect x="60" y="${cacheY}" width="200" height="36" rx="8" fill="none" stroke="var(--accent, ${C.accent})" stroke-width="1.5" stroke-dasharray="4 3"/>
    <text x="160" y="${cacheY + 22}" text-anchor="middle" font-size="12" fill="var(--text-primary, ${C.text})" font-weight="600">${cacheLabel}</text>
  ` : `
    <text x="60" y="${cacheY + 22}" font-size="11" fill="${C.dim}" font-style="italic">no cache — steady traffic</text>
  `;

  // Regions
  const regionY = 190;
  const regionPins = Array.from({ length: regions }, (_, i) => {
    const x = 60 + i * 56;
    return `<g transform="translate(${x},${regionY})">
      <circle r="8" fill="var(--accent, ${C.accent})"/>
      <circle r="14" fill="none" stroke="var(--accent, ${C.accent})" stroke-width="1" opacity="0.35"/>
      <text x="0" y="28" text-anchor="middle" font-size="10" fill="${C.muted}">${geo === 'single' ? 'single' : 'r' + (i+1)}</text>
    </g>`;
  }).join('');

  // CI sidebar
  const ciLines = [
    `• pods min/max: ${Math.max(1, Math.floor(podCount/2))} / ${podCount * 2}`,
    `• response budget: ${userTier === 'tier-1' ? '500' : userTier === 'tier-2' ? '200' : '100'} ms`,
    cacheOn ? `• cache hit-rate gate: ≥ 80%` : null,
    regions > 1 ? `• replication lag gate: < 100ms` : null,
    volume === 'large' ? `• storage audit: sharding plan required` : null,
  ].filter(Boolean);
  const sidebar = ciLines.map((l, i) => `<text x="320" y="${75 + i * 18}" font-size="11" fill="var(--text-secondary, ${C.muted})" font-family="ui-monospace, SFMono-Regular, monospace">${esc(l)}</text>`).join('');

  return wrap(540, 240, `
    <text x="20" y="30" font-size="12" font-weight="700" letter-spacing="0.05em" fill="var(--text-secondary, ${C.muted})">INFRASTRUCTURE</text>
    <text x="20" y="${podY + 22}" font-size="11" fill="${C.muted}">pods</text>
    ${pods}${podOverflow}
    <text x="20" y="${cacheY + 22}" font-size="11" fill="${C.muted}">cache</text>
    ${cacheBox}
    <text x="20" y="${regionY + 4}" font-size="11" fill="${C.muted}">regions</text>
    ${regionPins}
    <line x1="300" y1="50" x2="300" y2="220" stroke="${C.line}" stroke-width="1"/>
    <text x="320" y="50" font-size="12" font-weight="700" letter-spacing="0.05em" fill="var(--text-secondary, ${C.muted})">CI WILL ENFORCE</text>
    ${sidebar}
  `);
}

// ============================================================
// C2 — Database pipeline (step 4)
// ============================================================
export function dbPipeline(answers, db) {
  if (!db) return '';
  const stages = db.pipeline || [];
  const hasMigrations = !!answers.database.migrations && answers.database.migrations !== 'none';
  const migrationsTool = answers.database.migrations || 'manual';

  const boxW = 110, boxH = 38, gap = 20, y = 60;
  const totalW = stages.length * boxW + (stages.length - 1) * gap;
  const startX = Math.max(20, (540 - totalW) / 2);

  const boxes = stages.map((s, i) => {
    const x = startX + i * (boxW + gap);
    const isDb = /primary|local|mongo|redis/i.test(s);
    return `
      <rect x="${x}" y="${y}" width="${boxW}" height="${boxH}" rx="6"
        fill="${isDb ? 'var(--accent, ' + C.accent + ')' : C.elev}"
        fill-opacity="${isDb ? '0.15' : '1'}"
        stroke="${isDb ? 'var(--accent, ' + C.accent + ')' : C.line}" stroke-width="1.2"/>
      <text x="${x + boxW/2}" y="${y + boxH/2 + 4}" text-anchor="middle" font-size="10.5"
        fill="var(--text-primary, ${C.text})" font-weight="${isDb ? 600 : 500}">${esc(s)}</text>
      ${i < stages.length - 1 ? `<path d="M ${x + boxW + 2} ${y + boxH/2} L ${x + boxW + gap - 2} ${y + boxH/2}" stroke="${C.muted}" stroke-width="1.2" marker-end="url(#arrow-m)"/>` : ''}
    `;
  }).join('');

  const migBox = hasMigrations ? `
    <g transform="translate(${startX}, 130)">
      <rect width="${totalW}" height="44" rx="6" fill="none" stroke="var(--accent, ${C.accent})" stroke-width="1.3" stroke-dasharray="5 3"/>
      <text x="16" y="18" font-size="10.5" font-weight="700" fill="${C.muted}" letter-spacing="0.08em">MIGRATIONS</text>
      <text x="16" y="34" font-size="12" font-weight="600" fill="var(--text-primary, ${C.text})">${esc(migrationsTool)} — versioned schema changes, run in CI before every deploy</text>
    </g>
  ` : '';

  const explain = [
    'App → driver → DB. The driver is the phone line.',
    hasMigrations ? `${migrationsTool} = version control for your schema.` : 'No migrations tool — manual SQL only.',
    'Backup = the escape hatch when someone drops a table at 2am.',
  ];

  return wrap(540, 230, `
    <defs><marker id="arrow-m" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path d="M 0 0 L 10 5 L 0 10 z" fill="${C.muted}"/></marker></defs>
    <text x="20" y="30" font-size="12" font-weight="700" letter-spacing="0.05em" fill="var(--text-secondary, ${C.muted})">DATA PIPELINE</text>
    ${boxes}${migBox}
    ${explain.map((e, i) => `<text x="20" y="${200 + i * 12}" font-size="10.5" fill="${C.muted}">• ${esc(e)}</text>`).join('')}
  `);
}

// ============================================================
// C3 — API surface diagram (step 5)
// Four small panels; selected one is filled with accent, others are dim.
// ============================================================
export function apiSurfaceDiagram(answers) {
  const sel = answers.integration.api;
  const shapes = [
    { id: 'rest', label: 'REST', wire: 'GET /users', blurb: 'HTTP + JSON' },
    { id: 'graphql', label: 'GraphQL', wire: '{ user(id) { ... } }', blurb: 'one endpoint, flex queries' },
    { id: 'grpc', label: 'gRPC', wire: 'rpc GetUser(id)', blurb: 'typed, internal' },
    { id: 'none', label: 'No public API', wire: '— worker-only —', blurb: 'consumer only' },
  ];
  const panelW = 125, panelH = 100, gap = 8;
  const startX = 10;

  const panels = shapes.map((s, i) => {
    const isSel = s.id === sel;
    const x = startX + i * (panelW + gap);
    return `
      <g transform="translate(${x}, 50)">
        <rect width="${panelW}" height="${panelH}" rx="8"
          fill="${isSel ? 'var(--accent, ' + C.accent + ')' : C.elev}"
          fill-opacity="${isSel ? '0.12' : '1'}"
          stroke="${isSel ? 'var(--accent, ' + C.accent + ')' : C.line}"
          stroke-width="${isSel ? '1.6' : '1'}"/>
        <text x="${panelW/2}" y="22" text-anchor="middle" font-size="13" font-weight="700" fill="var(--text-primary, ${C.text})">${esc(s.label)}</text>
        <circle cx="26" cy="55" r="10" fill="${isSel ? 'var(--accent, ' + C.accent + ')' : C.dim}"/>
        <text x="26" y="58" text-anchor="middle" font-size="9" fill="white" font-weight="700">cli</text>
        <path d="M 38 55 L ${panelW - 38} 55" stroke="${isSel ? 'var(--accent, ' + C.accent + ')' : C.dim}" stroke-width="1.5" stroke-dasharray="${isSel ? '0' : '3 2'}"/>
        <rect x="${panelW - 36}" y="45" width="22" height="20" rx="3" fill="${isSel ? 'var(--accent, ' + C.accent + ')' : C.dim}"/>
        <text x="${panelW - 25}" y="58" text-anchor="middle" font-size="9" fill="white" font-weight="700">svc</text>
        <text x="${panelW/2}" y="78" text-anchor="middle" font-size="9.5" font-family="ui-monospace, monospace" fill="${isSel ? C.accent : C.muted}">${esc(s.wire)}</text>
        <text x="${panelW/2}" y="92" text-anchor="middle" font-size="10" fill="${C.muted}">${esc(s.blurb)}</text>
      </g>
    `;
  }).join('');

  return wrap(540, 170, `
    <text x="10" y="30" font-size="12" font-weight="700" letter-spacing="0.05em" fill="var(--text-secondary, ${C.muted})">API SURFACE — CLIENT TALKS TO YOUR SERVICE</text>
    ${panels}
  `);
}

// ============================================================
// C4 — Queue diagram (step 5)
// ============================================================
export function queueDiagram(answers) {
  const sel = answers.integration.queue;
  const queues = [
    { id: 'none', label: 'None', blurb: 'sync only' },
    { id: 'redis-streams', label: 'Redis Streams', blurb: '< 10k msg/s' },
    { id: 'rabbitmq', label: 'RabbitMQ', blurb: 'routing, DLQ' },
    { id: 'kafka', label: 'Kafka', blurb: 'event log' },
  ];
  const panelW = 125, panelH = 80, gap = 8;
  const panels = queues.map((q, i) => {
    const isSel = q.id === sel;
    const x = 10 + i * (panelW + gap);
    return `
      <g transform="translate(${x}, 40)">
        <rect width="${panelW}" height="${panelH}" rx="8"
          fill="${isSel ? 'var(--accent, ' + C.accent + ')' : C.elev}"
          fill-opacity="${isSel ? '0.12' : '1'}"
          stroke="${isSel ? 'var(--accent, ' + C.accent + ')' : C.line}"
          stroke-width="${isSel ? '1.6' : '1'}"/>
        <text x="${panelW/2}" y="18" text-anchor="middle" font-size="12" font-weight="700" fill="var(--text-primary, ${C.text})">${esc(q.label)}</text>
        ${q.id === 'none' ? `
          <circle cx="32" cy="46" r="8" fill="${C.dim}"/>
          <path d="M 42 46 L ${panelW-42} 46" stroke="${C.dim}" stroke-width="1.5"/>
          <circle cx="${panelW-32}" cy="46" r="8" fill="${C.dim}"/>
        ` : `
          <circle cx="26" cy="46" r="8" fill="${isSel ? 'var(--accent, ' + C.accent + ')' : C.dim}"/>
          <text x="26" y="49" text-anchor="middle" font-size="8" fill="white" font-weight="700">prd</text>
          <rect x="${panelW/2 - 14}" y="38" width="28" height="18" rx="3" fill="${isSel ? 'var(--accent, ' + C.accent + ')' : C.dim}"/>
          <text x="${panelW/2}" y="50" text-anchor="middle" font-size="8" fill="white" font-weight="700">queue</text>
          <circle cx="${panelW-26}" cy="46" r="8" fill="${isSel ? 'var(--accent, ' + C.accent + ')' : C.dim}"/>
          <text x="${panelW-26}" y="49" text-anchor="middle" font-size="8" fill="white" font-weight="700">cns</text>
          <path d="M 36 46 L ${panelW/2 - 16} 46" stroke="${isSel ? 'var(--accent, ' + C.accent + ')' : C.dim}" stroke-width="1.5"/>
          <path d="M ${panelW/2 + 14} 46 L ${panelW - 36} 46" stroke="${isSel ? 'var(--accent, ' + C.accent + ')' : C.dim}" stroke-width="1.5"/>
        `}
        <text x="${panelW/2}" y="72" text-anchor="middle" font-size="10" fill="${C.muted}">${esc(q.blurb)}</text>
      </g>
    `;
  }).join('');
  return wrap(540, 140, `
    <text x="10" y="25" font-size="12" font-weight="700" letter-spacing="0.05em" fill="var(--text-secondary, ${C.muted})">QUEUE / EVENT SYSTEM</text>
    ${panels}
  `);
}

// ============================================================
// C5 — Security chain (step 6)
// Vertical pipeline: each node lights up based on which security answers apply.
// ============================================================
export function securityChain(answers) {
  const s = answers.security;
  const nodes = [
    { id: 'input',   label: 'User input',              active: true },
    { id: 'auth',    label: `Auth (${s.auth || 'not set'})`, active: !!s.auth && s.auth !== 'none' },
    { id: 'rate',    label: 'Rate limit',              active: true },
    { id: 'pii',     label: 'PII scanner + redact',    active: s.pii },
    { id: 'enc',     label: 'Encryption middleware',   active: s.pii || (s.classification === 'restricted' || s.classification === 'highly-restricted') },
    { id: 'audit',   label: 'Audit log',               active: s.compliance.includes('soc2') || s.classification === 'highly-restricted' },
    { id: 'db',      label: 'Database / storage',      active: true },
  ];
  const nodeH = 34, gap = 10, startY = 40;
  const boxes = nodes.map((n, i) => {
    const y = startY + i * (nodeH + gap);
    const color = n.active ? 'var(--accent, ' + C.accent + ')' : C.dim;
    return `
      <g transform="translate(100, ${y})">
        <rect width="340" height="${nodeH}" rx="7"
          fill="${n.active ? 'var(--accent, ' + C.accent + ')' : C.elev}" fill-opacity="${n.active ? '0.12' : '1'}"
          stroke="${color}" stroke-width="${n.active ? '1.5' : '1'}"/>
        <circle cx="18" cy="${nodeH/2}" r="6" fill="${color}"/>
        <text x="36" y="${nodeH/2 + 4}" font-size="12" fill="var(--text-primary, ${C.text})" font-weight="${n.active ? 600 : 400}">${esc(n.label)}</text>
        ${n.active ? '<text x="322" y="'+ (nodeH/2 + 4) +'" font-size="10" fill="' + C.pass + '" font-weight="700">ACTIVE</text>' : '<text x="322" y="'+ (nodeH/2 + 4) +'" font-size="10" fill="'+ C.dim +'">off</text>'}
      </g>
      ${i < nodes.length - 1 ? `<path d="M 270 ${y + nodeH} L 270 ${y + nodeH + gap}" stroke="${n.active && nodes[i+1].active ? 'var(--accent, ' + C.accent + ')' : C.dim}" stroke-width="1.5"/>` : ''}
    `;
  }).join('');
  return wrap(540, startY + nodes.length * (nodeH + gap) + 20, `
    <text x="20" y="28" font-size="12" font-weight="700" letter-spacing="0.05em" fill="var(--text-secondary, ${C.muted})">SECURITY CHAIN — REQUEST FLOW</text>
    ${boxes}
  `);
}

// ============================================================
// C6 — Folder tree ownership glow (step 7)
// Renders tree with per-owner glow. `ownership` is Map(path → {name, accent}).
// ============================================================
export function folderTreeGlow(tree, ownership) {
  if (!tree || !tree.length) return '<div style="color:var(--text-tertiary);padding:12px;">Pick an archetype first to see the folder tree.</div>';
  const rows = tree.map(entry => {
    const [name, type] = entry;
    const trimmed = name.trim();
    const indent = (name.match(/^ +/) || [''])[0].length;
    const key = trimmed.replace(/\/$/, '');
    const owner = ownership.get(key);
    const glowStyle = owner ? `box-shadow: 0 0 14px ${owner.accent}, inset 0 0 0 1px ${owner.accent}; background: ${owner.accent}11; border-radius: 4px;` : '';
    const chip = (owner && owner.name) ? `<span class="owner-chip" style="background:${owner.accent};color:white;padding:1px 6px;border-radius:3px;font-size:10px;font-weight:600;margin-left:8px;">${esc(owner.name.split(/\s+/).map(p=>p[0]).join('').slice(0,2).toUpperCase())}</span>` : '';
    const cls = type === 'dir' ? 'dir' : type === 'entry' ? 'entry' : '';
    return `<div class="tree-line" data-path="${esc(key)}" style="padding:3px 6px; ${glowStyle}"><span style="color:transparent">${'·'.repeat(indent)}</span><span class="${cls}">${esc(trimmed)}</span>${chip}</div>`;
  }).join('');
  return `<div class="tree-glow" style="font-family:ui-monospace,monospace;font-size:12px;line-height:1.55;">${rows}</div>`;
}

// ============================================================
// C7 — Request flowchart (step 8)
// ============================================================
export function flowchart(answers, resolved) {
  const { lang, arch, db, api } = resolved;
  const langId = lang?.id || 'python';
  const ext = langId === 'python' ? 'py' : langId === 'go' ? 'go' : 'ts';
  const stages = [
    { label: 'Client',       file: api?.label || 'HTTP' },
    { label: 'Middleware',   file: `middleware/auth.${ext}` },
    { label: 'Route',        file: `routes/*.${ext}` },
    { label: 'Service',      file: `services/*.${ext}` },
    { label: 'Repository',   file: `repositories/*.${ext}` },
    { label: 'Database',     file: db?.name || 'none' },
  ];
  const w = 120, h = 70, gap = 14;
  const rowW = stages.length * w + (stages.length - 1) * gap;
  const startX = (900 - rowW) / 2;

  const boxes = stages.map((s, i) => {
    const x = startX + i * (w + gap);
    return `
      <g class="flow-node" style="animation-delay:${i * 100}ms">
        <rect x="${x}" y="60" width="${w}" height="${h}" rx="10" fill="${C.elev}" stroke="var(--accent, ${C.accent})" stroke-width="1.3" filter="url(#softshadow)"/>
        <text x="${x + w/2}" y="86" text-anchor="middle" font-size="13" font-weight="700" fill="var(--text-primary, ${C.text})">${esc(s.label)}</text>
        <text x="${x + w/2}" y="104" text-anchor="middle" font-size="10" font-family="ui-monospace, monospace" fill="${C.muted}">${esc(s.file)}</text>
        ${i < stages.length - 1 ? `<path d="M ${x + w + 2} 95 L ${x + w + gap - 2} 95" stroke="var(--accent, ${C.accent})" stroke-width="1.8" marker-end="url(#arrow-big)"/>` : ''}
      </g>
    `;
  }).join('');

  return wrap(900, 180, `
    <defs><marker id="arrow-big" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="8" markerHeight="8" orient="auto"><path d="M 0 0 L 10 5 L 0 10 z" fill="var(--accent, ${C.accent})"/></marker></defs>
    <style>
      .flow-node { opacity: 0; transform: translateX(-8px); animation: flow-in 380ms cubic-bezier(.16,1,.3,1) forwards; }
      @keyframes flow-in { to { opacity: 1; transform: translateX(0); } }
      @media (prefers-reduced-motion: reduce) { .flow-node { opacity: 1; transform: none; animation: none; } }
    </style>
    <text x="20" y="30" font-size="12" font-weight="700" letter-spacing="0.05em" fill="var(--text-secondary, ${C.muted})">REQUEST LIFECYCLE — WHICH FILE HANDLES WHAT</text>
    ${boxes}
  `);
}

// ============================================================
// C8 — Dependency graph (step 8)
// Polar-ish neural network look. Nodes = modules, edges = allowed deps.
// ============================================================
export function dependencyGraph(answers, resolved) {
  const hasQueue = answers.integration.queue !== 'none';
  const hasExternal = answers.integration.externalApis && answers.integration.externalApis.length > 0;
  const hasOutbound = answers.integration.outboundPipeline?.enabled;
  const hasDb = resolved.db && resolved.db.id !== 'none';

  const cx = 260, cy = 180, r1 = 80, r2 = 150;
  const nodes = [
    { id: 'config',     label: 'config',     x: cx,           y: cy - r2, ring: 'outer' },
    { id: 'middleware', label: 'middleware', x: cx + r2*0.87, y: cy - r2*0.5, ring: 'outer' },
    { id: 'routes',     label: 'routes',     x: cx + r2*0.87, y: cy + r2*0.5, ring: 'outer' },
    { id: 'services',   label: 'services',   x: cx,           y: cy, ring: 'core' },
    { id: 'repos',      label: 'repos',      x: cx - r2*0.87, y: cy + r2*0.5, ring: 'outer' },
    { id: 'models',     label: 'models',     x: cx - r2*0.87, y: cy - r2*0.5, ring: 'outer' },
    ...(hasDb ? [{ id: 'db', label: resolved.db.name, x: cx - r2 - 30, y: cy, ring: 'external' }] : []),
    ...(hasQueue ? [{ id: 'queue', label: 'queue', x: cx + r2 + 30, y: cy - 40, ring: 'external' }] : []),
    ...(hasOutbound || hasExternal ? [{ id: 'egress', label: 'egress', x: cx + r2 + 30, y: cy + 40, ring: 'external' }] : []),
  ];

  const edges = [
    ['routes', 'services'],
    ['services', 'repos'],
    ['services', 'models'],
    ['repos', 'models'],
    ['middleware', 'routes'],
    ['config', 'services'],
    ['config', 'middleware'],
    ...(hasDb ? [['repos', 'db']] : []),
    ...(hasQueue ? [['services', 'queue']] : []),
    ...(hasOutbound || hasExternal ? [['services', 'egress']] : []),
  ];

  const findNode = (id) => nodes.find(n => n.id === id);
  const edgeLines = edges.map(([a, b], i) => {
    const na = findNode(a), nb = findNode(b);
    if (!na || !nb) return '';
    return `<line x1="${na.x}" y1="${na.y}" x2="${nb.x}" y2="${nb.y}" stroke="var(--accent, ${C.accent})" stroke-opacity="0.3" stroke-width="1.2" class="dep-edge" style="animation-delay:${i*40}ms"/>`;
  }).join('');

  const nodeCircles = nodes.map((n, i) => {
    const size = n.ring === 'core' ? 18 : n.ring === 'external' ? 12 : 14;
    const fill = n.ring === 'core' ? 'var(--accent, ' + C.accent + ')' : n.ring === 'external' ? C.muted : C.elev;
    return `
      <g class="dep-node" style="animation-delay:${i*60}ms">
        <circle cx="${n.x}" cy="${n.y}" r="${size+4}" fill="${fill}" fill-opacity="0.15"/>
        <circle cx="${n.x}" cy="${n.y}" r="${size}" fill="${fill}" stroke="var(--accent, ${C.accent})" stroke-width="1.5"/>
        <text x="${n.x}" y="${n.y + size + 16}" text-anchor="middle" font-size="11" font-weight="600" fill="var(--text-primary, ${C.text})">${esc(n.label)}</text>
      </g>
    `;
  }).join('');

  return wrap(540, 380, `
    <style>
      .dep-edge { opacity: 0; animation: edge-in 520ms ease-out forwards; }
      .dep-node { opacity: 0; transform: scale(0.7); transform-origin: center; animation: node-pop 480ms cubic-bezier(.16,1,.3,1) forwards; }
      @keyframes edge-in { to { opacity: 0.6; } }
      @keyframes node-pop { to { opacity: 1; transform: scale(1); } }
      @media (prefers-reduced-motion: reduce) { .dep-edge, .dep-node { opacity: 1; transform: none; animation: none; } }
    </style>
    <text x="20" y="30" font-size="12" font-weight="700" letter-spacing="0.05em" fill="var(--text-secondary, ${C.muted})">MODULE DEPENDENCY GRAPH</text>
    ${edgeLines}
    ${nodeCircles}
  `);
}

// ============================================================
// Helpers for wizard.js — extract paths from a tree for the owns picker.
// ============================================================
export function extractDirectoryPaths(tree) {
  if (!tree) return [];
  return tree
    .filter(([, type]) => type === 'dir')
    .map(([name]) => name.trim().replace(/\/$/, ''))
    .filter(Boolean);
}
