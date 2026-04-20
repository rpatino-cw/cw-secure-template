// stacks.js — framework, archetype, and database metadata for the setup wizard.
// Pure data. Read by wizard.js + generator.js.

// Framework families narrow what's surfaced first. A family scopes recommended
// languages/archetypes but never hides options — every choice is still available.
export const FAMILIES = [
  { id: 'backend-api',   label: 'Backend API / service', icon: '⚙️',  recommended: true, blurb: 'HTTP APIs, background workers, internal services.' },
  { id: 'fullstack-web', label: 'Full-stack web app',    icon: '🌐',  blurb: 'Server-rendered UI + API in one deployable.' },
  { id: 'frontend-only', label: 'Frontend / SPA',        icon: '🎨',  blurb: 'Static site or SPA against an existing API.' },
  { id: 'cli-tool',      label: 'CLI / operator tool',   icon: '⚡',  blurb: 'Local command-line utility, no server.' },
  { id: 'data-pipeline', label: 'Data / batch pipeline', icon: '📊',  blurb: 'Scheduled ETL or event stream processing.' },
  { id: 'bare-minimum',  label: 'Bare minimum',          icon: '🧱',  blurb: 'Just CW security + CI — pick your own stack.' },
];

// Map of which languages are "native" to each family. Used to prioritize the
// display order; non-native langs still appear at the bottom.
export const FAMILY_LANGS = {
  'backend-api':   ['python', 'go', 'node'],
  'fullstack-web': ['node', 'python'],
  'frontend-only': ['node'],
  'cli-tool':      ['python', 'go'],
  'data-pipeline': ['python', 'go'],
  'bare-minimum':  ['python', 'go', 'node'],
};

export const LANGUAGES = [
  {
    id: 'python',
    name: 'Python / FastAPI',
    blurb: 'Async HTTP, strict typing via Pydantic, great for APIs + background work.',
    icon: '🐍',
    recommended: true,
    cwRecommended: true,
    chainguardBase: 'cgr.dev/coreweave/python:3.13',
    pkgFile: 'pyproject.toml',
    rootDir: 'python/',
  },
  {
    id: 'go',
    name: 'Go',
    blurb: 'Single static binary, stdlib HTTP, predictable perf — ideal for services that must not flake.',
    icon: '🐹',
    chainguardBase: 'cgr.dev/coreweave/go:1.25',
    pkgFile: 'go.mod',
    rootDir: 'go/',
  },
  {
    id: 'node',
    name: 'Node.js / TypeScript',
    blurb: 'Next.js for full-stack, Express or Hono for APIs. First-class CW Chainguard base image.',
    icon: '🟢',
    cwRecommended: true,
    chainguardBase: 'cgr.dev/coreweave/node:22',
    pkgFile: 'package.json',
    rootDir: 'node/',
  },
];

export const ARCHETYPES = {
  python: [
    {
      id: 'py-monolith-api',
      name: 'Monolith API',
      blurb: 'Single FastAPI service. Routes → services → repositories → Postgres.',
      scaleCeiling: '10k concurrent users per instance',
      setupTime: '5 min',
      teamSize: '1–5 devs',
      whenToPick: 'Internal dashboard, CRUD admin, webhook receiver, any API under 10k QPS.',
      defaultBlueprint: 'api-service',
      tree: [
        ['python/', 'dir'],
        ['  src/', 'dir'],
        ['    main.py', 'entry', 'FastAPI app factory, middleware, routes mounted'],
        ['    config/', 'dir', 'Settings (BaseSettings), constants'],
        ['    models/', 'dir', 'Pydantic request/response + SQLAlchemy tables'],
        ['    routes/', 'dir', 'One file per resource — thin handlers only'],
        ['    services/', 'dir', 'Business logic — no HTTP, no raw SQL'],
        ['    repositories/', 'dir', 'Parameterized queries only'],
        ['    middleware/', 'dir', 'auth, ratelimit, requestid, requestsize'],
        ['    utils/', 'dir'],
        ['  tests/', 'dir', 'pytest — 80% coverage gate'],
        ['  migrations/', 'dir', 'Alembic'],
        ['  pyproject.toml', 'file'],
        ['  Dockerfile', 'file', 'Chainguard multi-stage, non-root'],
      ],
    },
    {
      id: 'py-api-workers',
      name: 'API + Background Workers',
      blurb: 'FastAPI for requests, Celery/RQ for async jobs, Redis as broker.',
      scaleCeiling: '50k QPS with horizontal workers',
      setupTime: '15 min',
      teamSize: '2–8 devs',
      whenToPick: 'Email sends, report generation, long-running imports, any job > 2s.',
      defaultBlueprint: 'batch-processor',
      tree: [
        ['python/', 'dir'],
        ['  src/', 'dir'],
        ['    main.py', 'entry', 'API entrypoint'],
        ['    worker.py', 'entry', 'Celery worker boot'],
        ['    tasks/', 'dir', '@celery.task definitions — pure functions'],
        ['    routes/', 'dir'],
        ['    services/', 'dir', 'Services enqueue tasks — never call them directly'],
        ['    repositories/', 'dir'],
        ['    middleware/', 'dir'],
        ['  tests/', 'dir'],
        ['  pyproject.toml', 'file'],
        ['  Dockerfile.api', 'file'],
        ['  Dockerfile.worker', 'file'],
      ],
    },
    {
      id: 'py-api-stream',
      name: 'API + SSE / WebSocket',
      blurb: 'FastAPI with streaming responses. LLM chat, live dashboards, progress feeds.',
      scaleCeiling: '5k concurrent long-lived connections per instance',
      setupTime: '10 min',
      teamSize: '1–4 devs',
      whenToPick: 'Chat interfaces, live progress UIs, event streams to a frontend.',
      defaultBlueprint: 'chat-assistant',
      tree: [
        ['python/', 'dir'],
        ['  src/', 'dir'],
        ['    main.py', 'entry'],
        ['    routes/', 'dir'],
        ['      stream.py', 'file', 'SSE/WebSocket endpoints'],
        ['    services/', 'dir', 'Token budgeting, backpressure'],
        ['    middleware/', 'dir'],
        ['  tests/', 'dir'],
        ['  pyproject.toml', 'file'],
      ],
    },
  ],
  go: [
    {
      id: 'go-stdlib-http',
      name: 'stdlib HTTP Service',
      blurb: 'net/http only. Zero framework. Timeouts, graceful shutdown, structured logs.',
      scaleCeiling: '100k QPS per instance',
      setupTime: '5 min',
      teamSize: '1–5 devs',
      whenToPick: 'Small services where every dependency is a liability. Webhook targets, sidecars.',
      defaultBlueprint: 'api-service',
      tree: [
        ['go/', 'dir'],
        ['  main.go', 'entry', 'wires config → logger → DB → server'],
        ['  cmd/', 'dir'],
        ['  internal/', 'dir'],
        ['    config/', 'dir'],
        ['    models/', 'dir'],
        ['    routes/', 'dir'],
        ['    services/', 'dir'],
        ['    repositories/', 'dir'],
        ['    middleware/', 'dir', 'auth, ratelimit, requestid, headers'],
        ['  migrations/', 'dir', 'golang-migrate or pgx migrate'],
        ['  go.mod', 'file'],
        ['  Dockerfile', 'file', 'Chainguard multi-stage'],
      ],
    },
    {
      id: 'go-chi-router',
      name: 'stdlib + chi router',
      blurb: 'Same as stdlib plus go-chi for route groups, URL params, nested middleware.',
      scaleCeiling: '100k QPS per instance',
      setupTime: '7 min',
      teamSize: '2–8 devs',
      whenToPick: 'APIs with 10+ routes and auth groups. Still no framework bloat.',
      defaultBlueprint: 'admin-tool',
      tree: [
        ['go/', 'dir'],
        ['  main.go', 'entry'],
        ['  internal/', 'dir'],
        ['    routes/', 'dir', 'r := chi.NewRouter() here'],
        ['    services/', 'dir'],
        ['    repositories/', 'dir'],
        ['    middleware/', 'dir'],
        ['  go.mod', 'file'],
      ],
    },
    {
      id: 'go-worker',
      name: 'Worker (no HTTP)',
      blurb: 'Long-running consumer. Reads a queue, does work, commits. No HTTP server.',
      scaleCeiling: 'Scales with queue partitions',
      setupTime: '5 min',
      teamSize: '1–3 devs',
      whenToPick: 'Event consumers, batch jobs, ETL. Nothing to expose, nothing to protect via auth.',
      defaultBlueprint: 'batch-processor',
      tree: [
        ['go/', 'dir'],
        ['  main.go', 'entry', 'Queue client + worker loop + SIGTERM handling'],
        ['  internal/', 'dir'],
        ['    handlers/', 'dir', 'One handler per message type'],
        ['    services/', 'dir'],
        ['    repositories/', 'dir'],
        ['  go.mod', 'file'],
      ],
    },
  ],
  node: [
    {
      id: 'node-next-app-router',
      name: 'Next.js · App Router',
      blurb: 'Next 14+ App Router, React Server Components, streaming SSR. CW recommended for internal web apps.',
      cwRecommended: true,
      scaleCeiling: '20k QPS per instance (RSC cached)',
      setupTime: '10 min',
      teamSize: '1–5 devs',
      whenToPick: 'Internal dashboards, admin UIs, anything with a UI + API in one deployable.',
      defaultBlueprint: 'api-service',
      tree: [
        ['node/', 'dir'],
        ['  src/', 'dir'],
        ['    app/', 'dir', 'App Router pages + route handlers'],
        ['      layout.tsx', 'entry', 'Root layout, auth gate, CSP headers'],
        ['      page.tsx', 'entry', 'Home page (server component)'],
        ['      api/', 'dir', 'Route handlers — thin, call services'],
        ['    server/', 'dir'],
        ['      services/', 'dir', 'Business logic — no HTTP, no fetch'],
        ['      repositories/', 'dir', 'Parameterized queries only'],
        ['      middleware/', 'dir', 'auth, rate limit, request id'],
        ['    lib/', 'dir', 'Pure helpers, types'],
        ['  tests/', 'dir', 'Vitest — 80% coverage gate'],
        ['  package.json', 'file'],
        ['  tsconfig.json', 'file'],
        ['  next.config.ts', 'file'],
        ['  Dockerfile', 'file', 'Chainguard node:22, non-root'],
      ],
    },
    {
      id: 'node-next-pages-router',
      name: 'Next.js · Pages Router',
      blurb: 'Legacy Pages Router. Pick only for existing teams migrating in — new apps should use App Router.',
      scaleCeiling: '15k QPS per instance',
      setupTime: '10 min',
      teamSize: '1–5 devs',
      whenToPick: 'Team already runs Pages Router elsewhere. Not recommended for new work.',
      defaultBlueprint: 'api-service',
      tree: [
        ['node/', 'dir'],
        ['  src/', 'dir'],
        ['    pages/', 'dir', 'One file per route + api/'],
        ['      _app.tsx', 'entry'],
        ['      api/', 'dir'],
        ['    server/', 'dir'],
        ['    lib/', 'dir'],
        ['  tests/', 'dir'],
        ['  package.json', 'file'],
      ],
    },
    {
      id: 'node-express-api',
      name: 'Express + TypeScript API',
      blurb: 'Plain REST API. Express + zod validation. No UI.',
      scaleCeiling: '30k QPS per instance',
      setupTime: '5 min',
      teamSize: '1–4 devs',
      whenToPick: 'Pure backend service, webhook receiver, internal API. No frontend.',
      defaultBlueprint: 'api-service',
      tree: [
        ['node/', 'dir'],
        ['  src/', 'dir'],
        ['    index.ts', 'entry', 'Express app factory + middleware + route mount'],
        ['    routes/', 'dir'],
        ['    services/', 'dir'],
        ['    repositories/', 'dir'],
        ['    middleware/', 'dir'],
        ['  tests/', 'dir'],
        ['  package.json', 'file'],
        ['  tsconfig.json', 'file'],
      ],
    },
    {
      id: 'node-hono-edge',
      name: 'Hono · edge runtime',
      blurb: 'Minimal router, fast cold start. Great for functions, webhooks, and low-latency proxies.',
      scaleCeiling: '50k QPS per instance, sub-ms overhead',
      setupTime: '5 min',
      teamSize: '1–3 devs',
      whenToPick: 'Webhook receivers, LLM proxies, anything where cold start matters.',
      defaultBlueprint: 'api-service',
      tree: [
        ['node/', 'dir'],
        ['  src/', 'dir'],
        ['    index.ts', 'entry', 'Hono app with route groups + middleware'],
        ['    routes/', 'dir'],
        ['    services/', 'dir'],
        ['    middleware/', 'dir'],
        ['  tests/', 'dir'],
        ['  package.json', 'file'],
        ['  tsconfig.json', 'file'],
      ],
    },
  ],
};

// Mark CW-recommended archetypes explicitly (mirrors cwRecommended on the
// language). Lets wizard render a star next to the default pick.
['py-api-workers', 'go-chi-router', 'node-next-app-router'].forEach(id => {
  for (const langId of Object.keys(ARCHETYPES)) {
    const match = ARCHETYPES[langId].find(a => a.id === id);
    if (match) match.cwRecommended = true;
  }
});

export const CODE_STYLES = [
  {
    id: 'modules',
    name: 'Module-first (recommended)',
    blurb: 'Functions grouped by domain. Each file is a flat namespace of related functions.',
    recommended: true,
    substyles: ['layered', 'feature-folders', 'vertical-slice'],
    sample: `# services/user_service.py
def create_user(data, db):
    if exists(data.email, db): raise ValueError("dup")
    return save(User(...), db)

def update_user(id, data, db):
    ...`,
  },
  {
    id: 'oop',
    name: 'Object-oriented',
    blurb: 'Classes with methods. Good for stateful services, connection managers, adapters.',
    substyles: ['mvc', 'hexagonal', 'clean-arch', 'ddd-light', 'ddd-strict', 'active-record', 'data-mapper'],
    sample: `class UserService:
    def __init__(self, db): self.db = db
    def create(self, data): ...
    def update(self, id, data): ...

service = UserService(db)`,
  },
  {
    id: 'functional',
    name: 'Functional / pure',
    blurb: 'No classes. All pure functions, explicit dependencies. Easiest to test.',
    substyles: ['pipeline-rop', 'effect-system', 'fp-lite'],
    sample: `def create_user(data, db): ...

# compose
pipeline = [validate, check_dup, hash_pw, insert]
user = reduce(lambda d, f: f(d, db), pipeline, data)`,
  },
];

// Deeper picks within a parent code style. Generator emits additional folders
// for some of these (hexagonal, clean-arch, mvc, ddd-*) to match the pattern.
export const CODE_STYLE_SUBSTYLES = {
  // Module-first
  layered:          { name: 'Layered',         blurb: 'routes → services → repos. Matches the existing rules/ files — lowest friction pick.' },
  'feature-folders':{ name: 'Feature folders', blurb: 'Group files by feature, not by layer. Easier to delete a feature cleanly.' },
  'vertical-slice': { name: 'Vertical slice',  blurb: 'One request = one folder. Minimal cross-file coupling; heavier duplication.' },
  // OOP
  mvc:              { name: 'MVC',             blurb: 'Classic controller/model/view. Cheapest to hire for, dated but ubiquitous.' },
  hexagonal:        { name: 'Hexagonal / Ports & Adapters', blurb: 'Domain core + swappable adapters. Best for heavy testing and multi-driver services.' },
  'clean-arch':     { name: 'Clean Architecture', blurb: 'Four-ring dependency rule (entities → use cases → adapters → frameworks). Good for long-lived services.' },
  'ddd-light':      { name: 'DDD (light)',     blurb: 'Entities + value objects + services. Ubiquitous-language friendly without heavy machinery.' },
  'ddd-strict':     { name: 'DDD (strict)',    blurb: 'Aggregates + repositories + domain events. Multi-month investment; pick only if modeling complexity justifies it.' },
  'active-record':  { name: 'Active Record',   blurb: 'Models know how to save themselves. Fastest to write; couples domain to persistence.' },
  'data-mapper':    { name: 'Data Mapper',     blurb: 'Models are dumb; mappers persist them. Safer for evolving schemas.' },
  // Functional
  'pipeline-rop':   { name: 'Railway-oriented pipelines', blurb: 'Result chains with explicit error tracks. Great for validation + side-effect orchestration.' },
  'effect-system':  { name: 'Effect system',   blurb: 'Effects as values (fx-ts, Effect, etc.). Reserved for experienced FP teams.' },
  'fp-lite':        { name: 'FP-lite',         blurb: 'Pure helpers + immutable data; imperative glue is fine. Pragmatic middle ground.' },
};

export const SCALE_TIERS = [
  { id: 'tier-1', label: '1–100 users', infra: 'Single VM or k8s pod. $20–50/mo.', warning: null },
  { id: 'tier-2', label: '100–10k users', infra: '2+ pods behind Traefik. Postgres primary. $100–400/mo.', warning: null },
  { id: 'tier-3', label: '10k–1M users', infra: 'Multi-pod k8s deployment, read replicas, Redis cache.', warning: 'Requires load testing and on-call rotation before launch.' },
  { id: 'tier-4', label: '1M+ users', infra: 'Multi-region, sharded DB, event-driven architecture.', warning: 'Requires AppSec review + capacity planning meeting before approval.' },
];

export const TRAFFIC_PATTERNS = [
  { id: 'steady', label: 'Steady', blurb: 'Constant load. Easiest to size.' },
  { id: 'spiky', label: 'Spiky', blurb: 'Bursts 10×+ baseline. Needs autoscale or queue buffer.' },
  { id: 'batch', label: 'Batch', blurb: 'Predictable windows. Schedule-driven.' },
  { id: 'event', label: 'Event-driven', blurb: 'Consumer reacts to upstream. Scales with queue depth.' },
];

export const DATABASES = [
  {
    id: 'postgres',
    name: 'PostgreSQL',
    recommended: true,
    acid: 'Full ACID',
    scale: '100k+ QPS, horizontal read replicas',
    difficulty: 2,
    cost: '$',
    cwPolicy: 'Approved for Restricted data',
    whenToPick: 'Default. Relational data, financial records, anything needing transactions.',
    warning: null,
    pipeline: ['App', 'Connection pool', 'pgBouncer', 'Primary', 'Read replicas', 'Nightly backup → S3'],
    migrations: { python: 'alembic', go: 'golang-migrate' },
  },
  {
    id: 'mysql',
    name: 'MySQL / MariaDB',
    acid: 'Full ACID',
    scale: '50k+ QPS',
    difficulty: 2,
    cost: '$',
    cwPolicy: 'Approved — prefer Postgres unless there\'s a reason',
    whenToPick: 'Existing MySQL ecosystem, WordPress-adjacent, ORM quirks that favor MySQL.',
    warning: 'Less feature-rich than Postgres for JSON / full-text / array columns.',
    pipeline: ['App', 'Connection pool', 'Primary', 'Read replicas', 'Backup → S3'],
    migrations: { python: 'alembic', go: 'golang-migrate' },
  },
  {
    id: 'sqlite',
    name: 'SQLite',
    acid: 'Full ACID (single writer)',
    scale: '< 1k writes/sec, read-heavy',
    difficulty: 1,
    cost: 'Free',
    cwPolicy: 'NOT approved for Restricted data. Dev/test only.',
    whenToPick: 'Local-only tools, embedded state. Never for production multi-user apps.',
    warning: 'Single-writer. No horizontal scaling. Data lives on one disk — back up manually.',
    pipeline: ['App → local .db file → manual backup'],
    migrations: { python: 'alembic', go: 'golang-migrate' },
  },
  {
    id: 'redis',
    name: 'Redis (cache / queue only)',
    acid: 'No — in-memory key/value',
    scale: '1M+ ops/sec',
    difficulty: 2,
    cost: '$$',
    cwPolicy: 'Approved as cache/queue — never primary store for Restricted data',
    whenToPick: 'Session cache, rate limit counters, Celery broker, short-lived state.',
    warning: 'Not durable by default. Treat as cache only.',
    pipeline: ['App → Redis (master) → replica → AOF persistence'],
    migrations: { python: null, go: null },
  },
  {
    id: 'mongodb',
    name: 'MongoDB',
    acid: 'Transactions since 4.0, but not default',
    scale: '50k+ ops/sec sharded',
    difficulty: 3,
    cost: '$$$',
    cwPolicy: 'REQUIRES AppSec review for Restricted data',
    whenToPick: 'Document-heavy data that genuinely doesn\'t fit rows (rare). Avoid if unsure.',
    warning: 'Schema drift is common. Most teams regret picking Mongo over Postgres JSONB.',
    pipeline: ['App → Mongo primary → replica set → backup'],
    migrations: { python: null, go: null },
  },
  {
    id: 'none',
    name: 'None (stateless)',
    acid: 'N/A',
    scale: 'Bounded by compute only',
    difficulty: 1,
    cost: 'Free',
    cwPolicy: 'N/A — no data at rest',
    whenToPick: 'Pure compute services, webhook forwarders, LLM proxies, stateless transforms.',
    warning: null,
    pipeline: ['App (stateless) → logs → nothing persisted'],
    migrations: { python: null, go: null },
  },
];

export const INTEGRATION_SHAPES = [
  { id: 'monolith', label: 'Monolith', blurb: 'One deployable. Simplest ops. Default unless you have a reason.' },
  { id: 'modular', label: 'Modular monolith', blurb: 'One deployable, internal modules with clear boundaries. Good pre-split.' },
  { id: 'micro', label: 'Microservices', blurb: 'Multiple deployables. Only pick if you have an ops team.' },
];

export const API_SHAPES = [
  { id: 'rest', label: 'REST', blurb: 'HTTP + JSON. Default.' },
  { id: 'graphql', label: 'GraphQL', blurb: 'One endpoint, flexible queries. Adds complexity.' },
  { id: 'grpc', label: 'gRPC', blurb: 'Service-to-service, typed contracts. Internal only.' },
  { id: 'none', label: 'No public API', blurb: 'Worker-only or internal-only.' },
];

export const QUEUE_SYSTEMS = [
  { id: 'none', label: 'None', blurb: 'Synchronous only.' },
  { id: 'redis-streams', label: 'Redis Streams', blurb: 'Lightweight. Good for < 10k msgs/sec.' },
  { id: 'rabbitmq', label: 'RabbitMQ', blurb: 'Feature-rich. Routing, dead letter, priority.' },
  { id: 'kafka', label: 'Kafka', blurb: 'High throughput event log. Ops-heavy.' },
];

export const DATA_CLASSIFICATIONS = [
  { id: 'public', label: 'Public', blurb: 'Marketing pages, public docs. No impact if disclosed.', strict: false },
  { id: 'proprietary', label: 'Proprietary', blurb: 'Internal business info. Default for most internal apps.', strict: false },
  { id: 'restricted', label: 'Restricted', blurb: 'Customer data, financial, PII. Requires encryption at rest + audit logging.', strict: true },
  { id: 'highly-restricted', label: 'Highly Restricted', blurb: 'Regulated, legal, critical secrets. Requires AppSec review before launch.', strict: true },
];

export const AUTH_METHODS = [
  { id: 'okta-oidc', label: 'Okta OIDC (web users)', blurb: 'Default for any UI or API humans touch.', recommended: true },
  { id: 'okta-client-creds', label: 'Okta Client Credentials', blurb: 'Service-to-service only. No user identity.' },
  { id: 'okta-device', label: 'Okta Device Authorization', blurb: 'CLI tools. User signs in from browser.' },
  { id: 'none', label: 'No auth (healthz + public only)', blurb: 'Extremely rare. Needs AppSec justification.' },
];

export const SECRET_SYSTEMS = [
  { id: 'doppler', label: 'Doppler + External Secrets Operator', blurb: 'CW standard. Per-app project, dev/stg/prod configs.', recommended: true },
  { id: 'env', label: 'Plain .env (local only)', blurb: 'Fine for local dev. Not acceptable for production.' },
  { id: 'vault', label: 'HashiCorp Vault', blurb: 'Only pick if your team already runs Vault.' },
];

export const COMPLIANCE_FRAMEWORKS = [
  { id: 'soc2', label: 'SOC 2', blurb: 'Adds audit-log tests + access review evidence.' },
  { id: 'iso27001', label: 'ISO 27001', blurb: 'Adds risk register + incident evidence.' },
  { id: 'iso27701', label: 'ISO 27701', blurb: 'Privacy overlay on 27001. Requires DSR support.' },
  { id: 'none', label: 'None (internal only)', blurb: 'Still follows CW standards — no external attestation.' },
];

export const DEPLOY_TARGETS = [
  { id: 'core-internal', label: 'core-internal cluster', blurb: 'Most internal apps. Traefik + BlastShield + Okta.', recommended: true },
  { id: 'core-services', label: 'core-services cluster', blurb: 'Platform/shared services. Stricter review.' },
  { id: 'local', label: 'Local only (never deployed)', blurb: 'Developer tools, scripts. No k8s manifests generated.' },
];

export function resolveAnswers(answers) {
  const lang = LANGUAGES.find(l => l.id === answers.stack.language);
  return {
    lang,
    arch: lang ? ARCHETYPES[lang.id].find(a => a.id === answers.stack.archetype) : null,
    db: DATABASES.find(d => d.id === answers.database.choice) || DATABASES.find(d => d.id === 'none'),
    cls: DATA_CLASSIFICATIONS.find(c => c.id === answers.security.classification),
    auth: AUTH_METHODS.find(a => a.id === answers.security.auth),
    secrets: SECRET_SYSTEMS.find(s => s.id === answers.security.secrets),
    deploy: DEPLOY_TARGETS.find(d => d.id === answers.security.deploy),
    style: CODE_STYLES.find(s => s.id === answers.stack.style),
    tier: SCALE_TIERS.find(t => t.id === answers.scale.users),
    pattern: TRAFFIC_PATTERNS.find(p => p.id === answers.scale.pattern),
    shape: INTEGRATION_SHAPES.find(s => s.id === answers.integration.shape),
    api: API_SHAPES.find(a => a.id === answers.integration.api),
    queue: QUEUE_SYSTEMS.find(q => q.id === answers.integration.queue),
    theme: THEMES.find(t => t.id === answers.theme.id),
    teammates: answers.team.filter(m => m.name),
  };
}

export const THEMES = [
  { id: 'cw-light', label: 'CW Light (default)', recommended: true, bg: '#f5efe4', accent: '#5b8def', text: '#1a1a2e', mode: 'light' },
  { id: 'cw-dark', label: 'CW Dark', bg: '#0a1628', accent: '#22d3ee', text: '#e5edf5', mode: 'dark' },
  { id: 'mono', label: 'Minimal mono', bg: '#ffffff', accent: '#111111', text: '#111111', mode: 'light' },
  { id: 'sunset', label: 'Sunset', bg: '#1a0f1e', accent: '#ff8a5c', text: '#f5e6da', mode: 'dark' },
  { id: 'matrix', label: 'Matrix', bg: '#000000', accent: '#00ff88', text: '#c6f5d4', mode: 'dark' },
  { id: 'custom', label: 'Custom — pick your own', customizable: true, bg: '#0f172a', accent: '#5b8def', text: '#e5edf5', mode: 'dark' },
];

// Font pairings for the UI + code font pickers in the Custom theme card.
export const FONT_PAIRS = [
  { id: 'inter+jbm',  uiFont: 'Inter',     codeFont: 'JetBrains Mono', label: 'Inter + JetBrains Mono' },
  { id: 'plex+plex',  uiFont: 'IBM Plex Sans', codeFont: 'IBM Plex Mono', label: 'IBM Plex (matched)' },
  { id: 'geist',      uiFont: 'Geist',     codeFont: 'Geist Mono', label: 'Geist (matched)' },
  { id: 'system',     uiFont: 'system-ui', codeFont: 'ui-monospace', label: 'System (no web fonts)' },
];

// Why-this-question explainers. Keyed by stepId → questionId → { headline, bullets[] }.
// Rendered by renderWhy(stepId, qId) in wizard.js behind a "?" toggle.
export const WHY_TEXT = {
  2: {
    family:    { headline: 'What kind of thing are you building?', bullets: ['Different families get different recommended stacks.', 'You can still pick anything — this only reorders the list.', 'Bare-minimum skips the language tree entirely.'] },
    language:  { headline: 'Language choice drives the whole scaffold tree.', bullets: ['Chainguard base image, package file, and lint/test tooling all follow from here.', 'CW-recommended picks are battle-tested at CoreWeave.', 'You can mix languages later via additional microservices.'] },
    archetype: { headline: 'Archetype = folder layout + entry point.', bullets: ['It locks in the starting shape of your service.', 'Picks whether you get a worker, a stream endpoint, or a classic REST API.', 'Every archetype is guard-compatible — no Wild West templates.'] },
    style:     { headline: 'How do you want your code organized?', bullets: ['Module-first is the low-friction default and matches the rules/ directory.', 'OOP and Functional unlock a second picker for deeper conventions.', 'The generator emits sample files in the pattern you picked.'] },
    substyle:  { headline: 'Deeper architectural pattern within your style.', bullets: ['Hexagonal, DDD, Clean Arch — these shape testing and long-term maintenance cost.', 'The generator adds matching folders (adapters/, aggregates/, use_cases/, etc.).', 'Pick "layered" or skip this if you want the lowest-friction option.'] },
  },
  3: {
    users:   { headline: 'Concurrent user count sets your infra floor.', bullets: ['1–100: a single pod is fine.', '10k+: horizontal autoscaling + read replicas kick in.', '1M+: multi-region + AppSec review required — the wizard flags it.'] },
    pattern: { headline: 'Traffic shape determines whether you need a queue.', bullets: ['Steady: simplest sizing.', 'Spiky: we add an autoscale hint and warn if you have no queue buffer.', 'Event-driven: pair with a queue system in step 5.'] },
    geo:     { headline: 'How far apart are your users?', bullets: ['Single region: default, cheapest.', 'Multi-region: adds CDN config + replication hints.', 'Global: adds edge + latency budget notes to CLAUDE.md.'] },
    volume:  { headline: 'Data volume shapes your DB tier and backup plan.', bullets: ['< 10 GB: any DB, nightly backup is fine.', '10 GB – 1 TB: read replicas + point-in-time recovery recommended.', '1 TB+: sharding or columnar storage discussion required.'] },
  },
  4: {
    choice:     { headline: 'Pick a database — or go stateless.', bullets: ['Postgres is the default for transactional data.', 'SQLite is dev-only and auto-flagged for Restricted data.', 'Redis and Mongo have specific "only pick if…" guidance in the row.'] },
    migrations: { headline: 'Migrations = version control for your schema.', bullets: ['Alembic (Python) and golang-migrate (Go) are the CW defaults.', 'Manual SQL is allowed for tiny projects, but every schema change still needs a file.', 'The scaffold wires the tool into make check so migrations can\'t drift.'] },
  },
  5: {
    shape: { headline: 'One deployable or many?', bullets: ['Monolith is the default — simpler ops, faster iteration.', 'Modular monolith keeps boundaries inside one deployable.', 'Microservices is a last resort — only pick if you already have an ops team.'] },
    api:   { headline: 'How do clients talk to your service?', bullets: ['REST: HTTP + JSON, default, easiest to debug.', 'GraphQL: one endpoint, more complex server.', 'gRPC: internal service-to-service, typed contracts.', 'No public API: worker-only or internal-only.'] },
    queue: { headline: 'Queues absorb bursts and decouple producers from consumers.', bullets: ['None: synchronous only — fine for low-traffic reads.', 'Redis Streams: lightweight, < 10k msgs/sec.', 'RabbitMQ: feature-rich routing, dead-lettering, priorities.', 'Kafka: high-throughput event log, ops-heavy.'] },
    outbound: { headline: 'Do you call external APIs?', bullets: ['If yes, we wire an egress middleware with TLS enforcement.', 'Strict mode adds an allowlist — only listed hostnames go through.', 'Pre-commit blocks raw fetch/requests calls outside the middleware.', 'Drops your blast radius if a dependency gets popped.'] },
  },
  6: {
    classification: { headline: 'Data classification = CW\'s blast-radius scale.', bullets: ['Public / Proprietary / Restricted / Highly Restricted.', 'Restricted+ flips strict guards on automatically (encryption, audit logs, AppSec review).', 'Pick conservatively — downgrading later is easier than upgrading after a breach.'] },
    auth:           { headline: 'How do users prove who they are?', bullets: ['Okta OIDC is the CW default for any UI.', 'Client credentials is service-to-service only.', 'Device auth is for CLIs.', '"No auth" is effectively blocked for any non-Public data.'] },
    secrets:        { headline: 'Where do secrets live?', bullets: ['Doppler + External Secrets Operator is the CW standard — never in code or git.', 'Plain .env is local-only. Pre-commit blocks committing .env.', 'Vault only if your team already runs it.'] },
    pii:            { headline: 'Handles personal / health data?', bullets: ['Turns on gitleaks + detect-secrets + a PII regex scanner in pre-commit.', 'Adds encryption middleware stub + redaction helpers.', 'Adds data-subject-request hooks (export, deletion) to the scaffold.'] },
    compliance:     { headline: 'Which frameworks must this service align with?', bullets: ['SOC 2: adds audit-log tests + access-review evidence hooks.', 'ISO 27001: risk register + incident evidence.', 'ISO 27701: privacy overlay on 27001 — DSR support required.', '"None" still follows CW standards; just no external attestation.'] },
    deploy:         { headline: 'Which cluster will this run on?', bullets: ['core-internal: default for internal apps. Traefik + BlastShield + Okta OIDC.', 'core-services: stricter review; platform/shared services.', 'Local-only: no k8s manifests generated.'] },
  },
  7: {
    theme:      { headline: 'Theme shapes the generated dashboard look.', bullets: ['CW Light / CW Dark / Mono match the framework.', 'Custom lets you pick accent color + UI font + code font.', '3D tilt preview is CSS-only — no runtime cost.'] },
    roster:     { headline: 'Your teammates become room owners in rooms.json.', bullets: ['Each person scopes editable directories.', 'Multiple Claude sessions see the rooms — prevents cross-edits.', 'Leave blank for a solo project; rooms.json is skipped entirely.'] },
    owns:       { headline: 'Which directories does this person own?', bullets: ['Click to pick from the archetype\'s actual folder tree.', 'Unowned folders stay dim; owned folders glow with that person\'s accent color in the preview below.', 'Multiple people can share an area — it flags as shared.'] },
  },
};
