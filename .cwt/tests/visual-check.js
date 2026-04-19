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

async function main() {
  fs.mkdirSync(OUT, { recursive: true });

  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1200, height: 900 } });

  // file:// pages can't hit route() cleanly for relative fetches —
  // monkey-patch window.fetch before the page script runs instead.
  await page.addInitScript(
    ({ plans, manifest }) => {
      const json = (body) =>
        new Response(JSON.stringify(body), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      window.fetch = (url) => {
        const u = String(url);
        if (/\/api\/plans\/[^/]+\/(approve|reject)$/.test(u)) return Promise.resolve(json({ ok: true }));
        if (/\/api\/plans$/.test(u) || u.includes("/api/plans?")) return Promise.resolve(json({ plans }));
        if (/\/api\/manifest$/.test(u)) return Promise.resolve(json(manifest));
        return Promise.resolve(json({}));
      };
    },
    { plans: FIXTURES.plans, manifest: MANIFEST }
  );

  await page.goto(DASHBOARD);
  await page.waitForFunction(() => document.querySelectorAll(".card").length > 0, { timeout: 5000 });

  const tabs = ["pending", "approved", "rejected", "all"];
  for (const tab of tabs) {
    await page.click(`.tab[data-filter="${tab}"]`);
    await page.waitForTimeout(150);
    const out = path.join(OUT, `dashboard-${tab}.png`);
    await page.screenshot({ path: out, fullPage: true });
    console.log(`  wrote ${path.relative(ROOT, out)}`);
  }

  // Smoke assertions
  await page.click(`.tab[data-filter="all"]`);
  await page.waitForTimeout(200);
  const summary = await page.evaluate(() => ({
    cards: document.querySelectorAll(".card").length,
    highScores: document.querySelectorAll(".score.high").length,
    lowScores: document.querySelectorAll(".score.low").length,
    exempt: document.querySelectorAll(".score.exempt").length,
    citesBadges: document.querySelectorAll(".cited").length,
    missingBadges: document.querySelectorAll(".uncited").length,
  }));
  console.log("\nassertions:", summary);

  const fail = [];
  if (summary.cards !== 4) fail.push(`expected 4 cards, got ${summary.cards}`);
  if (summary.highScores < 1) fail.push("expected >=1 high score pill");
  if (summary.lowScores < 1) fail.push("expected >=1 low score pill");
  if (summary.exempt < 1) fail.push("expected >=1 exempt pill");
  if (summary.citesBadges < 1) fail.push("expected >=1 cites list");
  if (summary.missingBadges < 1) fail.push("expected >=1 missing list");

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
