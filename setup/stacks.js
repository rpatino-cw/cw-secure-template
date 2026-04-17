// stacks.js — framework, archetype, and database metadata for the setup wizard.
// Pure data. Read by wizard.js + generator.js.

export const LANGUAGES = [
  {
    id: 'python',
    name: 'Python / FastAPI',
    blurb: 'Async HTTP, strict typing via Pydantic, great for APIs + background work.',
    icon: '🐍',
    recommended: true,
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
};

export const CODE_STYLES = [
  {
    id: 'modules',
    name: 'Module-first (recommended)',
    blurb: 'Functions grouped by domain. Each file is a flat namespace of related functions.',
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
    sample: `def create_user(data, db): ...

# compose
pipeline = [validate, check_dup, hash_pw, insert]
user = reduce(lambda d, f: f(d, db), pipeline, data)`,
  },
];

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

export const THEMES = [
  { id: 'cw-light', label: 'CW Light (default)', recommended: true, bg: '#f5efe4', accent: '#5b8def', text: '#1a1a2e' },
  { id: 'cw-dark', label: 'CW Dark', bg: '#0a1628', accent: '#22d3ee', text: '#e5edf5' },
  { id: 'mono', label: 'Minimal mono', bg: '#ffffff', accent: '#111111', text: '#111111' },
];
