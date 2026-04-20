/**
 * CWT dashboard visual check.
 *
 * Launches headless chromium, intercepts /api/plans + /api/manifest with
 * inline fixtures covering exempt / good / bad / pending / approved / rejected
 * states, screenshots each filter tab to .cwt/tests/screenshots/.
 *
 * Run:
 *   npm i -D playwright && npx playwright install chromium
 *   node .cwt/tests/visual-check.js
 *
 * Solves the "can't bind a port from inside Claude's sandbox" problem —
 * Playwright intercepts fetches, no server needed.
 */

const path = require("path");
const fs = require("fs");

const { chromium } = require("playwright");

const ROOT = path.resolve(__dirname, "..");
const DASHBOARD = "file://" + path.join(ROOT, "cwt.html");
const OUT = path.join(__dirname, "screenshots");

const FIXTURES = {
  plans: [
    {
      id: "P-demo-exempt",
      _status: "approved",
      _path: ".cwt/queue/approved/P-demo-exempt.json",
      summary: "Add /api/health endpoint (CWT tooling)",
      prompt: "add health endpoint to server",
      targets: [
        { file: ".cwt/server.py", op: "edit", justification: "Extend Handler.do_GET." },
      ],
      ratings: {
        overall: null,
        targets: [{ file: ".cwt/server.py", score: 100, exempt: true, applicable: [], cited: [] }],
      },
    },
    {
      id: "P-demo-good",
      _status: "pending",
      _path: ".cwt/queue/pending/P-demo-good.json",
      summary: "Add /users endpoint with service + model",
      prompt: "add user creation endpoint",
      plain_english: "This adds a new way for your app to create user accounts. When someone sends a signup request, the app will validate it, hash the password for safety, and save a new user in the database. Nothing else changes about how the rest of the app behaves.",
      targets: [
        {
          file: "routes/users.py",
          op: "create",
          justification: "Per routes.md, thin handler under 20 lines calling user_service. code-style.md — ruff-clean. security.md — no raw SQL. classes.md — no inline defs.",
        },
        {
          file: "services/user_service.py",
          op: "create",
          justification: "Business logic per services.md — receives models, returns models, never HTTP objects. code-style.md — structlog. security.md — bcrypt for passwords. architecture.md — calls repository, never db directly. classes.md — one class per file.",
        },
      ],
      ratings: {
        overall: 90,
        targets: [
          {
            file: "routes/users.py",
            score: 80,
            applicable: ["architecture", "branching", "classes", "code-style", "collaboration", "rooms", "routes", "routing", "security"],
            cited: ["routes", "classes", "security", "code-style"],
          },
          {
            file: "services/user_service.py",
            score: 100,
            applicable: ["architecture", "branching", "classes", "code-style", "collaboration", "rooms", "routing", "security", "services"],
            cited: ["services", "architecture", "classes", "code-style", "security"],
          },
        ],
      },
    },
    {
      id: "P-demo-bad",
      _status: "pending",
      _path: ".cwt/queue/pending/P-demo-bad.json",
      summary: "Add user routes",
      prompt: "add user routes",
      targets: [
        { file: "routes/users.py", op: "create", justification: "Add user routes." },
      ],
      ratings: {
        overall: 20,
        targets: [
          {
            file: "routes/users.py",
            score: 20,
            applicable: ["architecture", "branching", "classes", "code-style", "collaboration", "rooms", "routes", "routing", "security"],
            cited: ["routes"],
            flags: ["uncited rules: architecture, classes, code-style, security"],
          },
        ],
      },
    },
    {
      id: "P-demo-rejected",
      _status: "rejected",
      _path: ".cwt/queue/rejected/P-demo-rejected.json",
      summary: "Hardcode API key in config",
      prompt: "add stripe key to settings.py",
      targets: [
        { file: "config/settings.py", op: "edit", justification: "Set STRIPE_KEY = 'sk_live_...'." },
      ],
      ratings: {
        overall: 0,
        targets: [
          {
            file: "config/settings.py",
            score: 0,
            applicable: ["architecture", "branching", "classes", "code-style", "collaboration", "globals", "rooms", "routing", "security"],
            cited: [],
            flags: ["uncited rules: architecture, classes, code-style, globals, security"],
          },
        ],
      },
    },
  ],
};

const MANIFEST = {
  plan_id: "P-demo-exempt",
  files: [".cwt/server.py"],
  summary: "Aggregated from 1 approved plan(s)",
};

const TASKS = {
  total: 4,
  counts: { done: 1, "in-progress": 1, todo: 1, blocked: 1 },
  errors: [],
  cycle: null,
  tasks: [
    { id: "T-0", title: "Scaffold project structure", owner: "go", status: "done", depends_on: [] },
    {
      id: "T-1",
      title: "Implement auth middleware",
      owner: "go",
      status: "in-progress",
      depends_on: ["T-0"],
      plan_id: "P-demo-good",
      _linked_plan: { id: "P-demo-good", status: "approved" },
    },
    { id: "T-2", title: "Build login UI", owner: "frontend", status: "todo", depends_on: ["T-1"] },
    {
      id: "T-3",
      title: "End-to-end auth flow test",
      owner: "qa",
      status: "blocked",
      depends_on: ["T-1", "T-2"],
      plan_id: "P-demo-rejected",
      _linked_plan: { id: "P-demo-rejected", status: "rejected" },
    },
  ],
};

const GRAPH = {
  stats: { files: 12, internal_edges: 4, tooling_files: 3 },
  nodes: [
    { id: "routes/users.py", module: "routes.users", tooling: false },
    { id: "services/user_service.py", module: "services.user_service", tooling: false },
    { id: "repositories/user_repo.py", module: "repositories.user_repo", tooling: false },
    { id: "models/user.py", module: "models.user", tooling: false },
    { id: ".cwt/server.py", module: ".cwt.server", tooling: true },
  ],
  edges: [
    { from: "routes/users.py", to: "services/user_service.py" },
    { from: "services/user_service.py", to: "repositories/user_repo.py" },
    { from: "services/user_service.py", to: "models/user.py" },
    { from: "repositories/user_repo.py", to: "models/user.py" },
  ],
};

async function main() {
  fs.mkdirSync(OUT, { recursive: true });

  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1200, height: 900 } });

  // file:// pages can't hit route() cleanly for relative fetches —
  // monkey-patch window.fetch before the page script runs instead.
  await page.addInitScript(
    ({ plans, manifest, tasks, graph }) => {
      const json = (body) =>
        new Response(JSON.stringify(body), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      window.fetch = (url) => {
        const u = String(url);
        if (/\/api\/plans\/[^/]+\/(approve|reject)$/.test(u)) return Promise.resolve(json({ ok: true }));
        if (/\/api\/launch-claude$/.test(u)) return Promise.resolve(json({ ok: true, method: "osascript", cmd: "cd /tmp/test && claude" }));
        if (/\/api\/explain-plan\//.test(u)) return Promise.resolve(json({ ok: true, text: "AI-generated plain-English summary for this plan.", cached: false }));
        if (/\/api\/plans$/.test(u) || u.includes("/api/plans?")) return Promise.resolve(json({ plans }));
        if (/\/api\/manifest$/.test(u)) return Promise.resolve(json(manifest));
        if (/\/api\/tasks$/.test(u)) return Promise.resolve(json(tasks));
        if (/\/api\/graph$/.test(u)) return Promise.resolve(json(graph));
        return Promise.resolve(json({}));
      };
    },
    { plans: FIXTURES.plans, manifest: MANIFEST, tasks: TASKS, graph: GRAPH }
  );

  await page.goto(DASHBOARD);
  await page.waitForFunction(() => document.querySelectorAll(".card").length > 0, { timeout: 5000 });

  const tabs = ["pending", "approved", "rejected", "all", "tasks", "graph"];
  for (const tab of tabs) {
    await page.click(`.tab[data-filter="${tab}"]`);
    await page.waitForTimeout(200);
    const out = path.join(OUT, `dashboard-${tab}.png`);
    await page.screenshot({ path: out, fullPage: true });
    console.log(`  wrote ${path.relative(ROOT, out)}`);
  }

  // Smoke assertions — plans
  await page.click(`.tab[data-filter="all"]`);
  await page.waitForTimeout(200);
  const plansSummary = await page.evaluate(() => ({
    cards: document.querySelectorAll(".card").length,
    highScores: document.querySelectorAll(".score.high").length,
    lowScores: document.querySelectorAll(".score.low").length,
    exempt: document.querySelectorAll(".score.exempt").length,
    citesBadges: document.querySelectorAll(".cited").length,
    missingBadges: document.querySelectorAll(".uncited").length,
  }));

  // Smoke assertions — tasks
  await page.click(`.tab[data-filter="tasks"]`);
  await page.waitForTimeout(200);
  const tasksSummary = await page.evaluate(() => ({
    taskRows: document.querySelectorAll(".task-row").length,
    doneStatus: document.querySelectorAll(".task-status.done").length,
    blockedStatus: document.querySelectorAll(".task-status.blocked").length,
  }));

  // Smoke assertions — graph
  await page.click(`.tab[data-filter="graph"]`);
  await page.waitForTimeout(200);
  const graphSummary = await page.evaluate(() => ({
    files: document.querySelectorAll(".graph-file").length,
    imports: document.querySelectorAll(".graph-imports li").length,
    planHighlighted: document.querySelectorAll(".graph-file.plan-pending, .graph-file.plan-approved, .graph-file.plan-rejected").length,
  }));

  console.log("\nassertions:");
  console.log("  plans:", plansSummary);
  console.log("  tasks:", tasksSummary);
  console.log("  graph:", graphSummary);

  const fail = [];
  if (plansSummary.cards !== 4) fail.push(`expected 4 cards, got ${plansSummary.cards}`);
  if (plansSummary.highScores < 1) fail.push("expected >=1 high score pill");
  if (plansSummary.lowScores < 1) fail.push("expected >=1 low score pill");
  if (plansSummary.exempt < 1) fail.push("expected >=1 exempt pill");
  if (plansSummary.citesBadges < 1) fail.push("expected >=1 cites list");
  if (plansSummary.missingBadges < 1) fail.push("expected >=1 missing list");

  // Plain-English summary + collapsible tech details
  const planSummary = await page.evaluate(() => ({
    plainSummaries: document.querySelectorAll(".plain-summary").length,
    detailsToggles: document.querySelectorAll(".details-toggle").length,
    techDetailsCollapsed: document.querySelectorAll(".tech-details:not(.open)").length,
  }));
  console.log("  plain+details:", planSummary);
  if (planSummary.plainSummaries < 1) fail.push("expected >=1 plain-summary section");
  if (planSummary.detailsToggles < 1) fail.push("expected >=1 Show technical details toggle");
  if (planSummary.techDetailsCollapsed < 1) fail.push("expected tech-details collapsed by default");
  if (tasksSummary.taskRows !== 4) fail.push(`expected 4 task rows, got ${tasksSummary.taskRows}`);
  if (tasksSummary.doneStatus < 1) fail.push("expected >=1 done status");
  if (tasksSummary.blockedStatus < 1) fail.push("expected >=1 blocked status");
  if (graphSummary.files < 1) fail.push("expected >=1 graph file entry");
  if (graphSummary.imports < 1) fail.push("expected >=1 import edge");
  if (graphSummary.planHighlighted < 1) fail.push("expected >=1 plan-highlighted graph file");

  // Header: Start Claude button present
  const launchBtn = await page.evaluate(() => document.querySelectorAll(".launch-claude").length);
  if (launchBtn < 1) fail.push("expected Start Claude button in header");
  console.log("  launch-claude buttons:", launchBtn);

  // Tasks tab: plan badges
  await page.click(`.tab[data-filter="tasks"]`);
  await page.waitForTimeout(150);
  const planBadges = await page.evaluate(() =>
    document.querySelectorAll(".task-row .plan-badge").length
  );
  if (planBadges < 1) fail.push("expected >=1 plan-badge on tasks tab");
  console.log("  plan-badges on tasks:", planBadges);

  await browser.close();

  if (fail.length) {
    console.error("\nFAIL:");
    fail.forEach((f) => console.error("  -", f));
    process.exit(1);
  }
  console.log("\nOK — all rating UI elements present");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
