#!/usr/bin/env node

/**
 * vibe-arch CLI — Scaffold a team vibe coding project
 *
 * Usage:
 *   npx vibe-arch init
 *   npx vibe-arch init --name my-app --stack python --profile balanced
 */

const fs = require('fs');
const path = require('path');
const readline = require('readline');

const STACKS = ['python', 'go', 'both'];
const PROFILES = ['hackathon', 'balanced', 'strict', 'production'];
const TEMPLATE_DIR = path.join(__dirname, '..', 'templates');

function ask(rl, question) {
  return new Promise(resolve => rl.question(question, resolve));
}

function copyDir(src, dest) {
  if (!fs.existsSync(dest)) fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDir(srcPath, destPath);
    } else {
      // Don't overwrite existing files
      if (!fs.existsSync(destPath)) {
        fs.copyFileSync(srcPath, destPath);
      }
    }
  }
}

async function init(args) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

  console.log('');
  console.log('  vibe-arch — Team Vibe Coding Framework');
  console.log('  ───────────────────────────────────────');
  console.log('');

  // Parse CLI flags or prompt interactively
  let name = args.name;
  let stack = args.stack;
  let profile = args.profile;

  if (!name) {
    name = await ask(rl, '  Project name: ');
    if (!name.trim()) name = path.basename(process.cwd());
  }

  if (!stack) {
    console.log('');
    console.log('  Stack:');
    console.log('    1. Python (FastAPI + SQLAlchemy)');
    console.log('    2. Go (stdlib + pgx)');
    console.log('    3. Both');
    const choice = await ask(rl, '\n  Pick a number: ');
    stack = STACKS[parseInt(choice) - 1] || 'python';
  }

  if (!profile) {
    console.log('');
    console.log('  Enforcement level:');
    console.log('    1. Hackathon (fast, relaxed)');
    console.log('    2. Balanced (recommended)');
    console.log('    3. Strict (tighter quality gates)');
    console.log('    4. Production (blocks on quality issues)');
    const choice = await ask(rl, '\n  Pick a number: ');
    profile = PROFILES[parseInt(choice) - 1] || 'balanced';
  }

  rl.close();

  const dest = process.cwd();
  console.log('');
  console.log(`  Scaffolding ${name} (${stack}, ${profile})...`);

  // Copy template files
  const templateRoot = path.join(TEMPLATE_DIR, 'base');
  if (fs.existsSync(templateRoot)) {
    copyDir(templateRoot, dest);
    console.log('  Created .claude/rules/ (18 files)');
    console.log('  Created .claude/settings.json');
    console.log('  Created scripts/guard.sh (6 modules)');
  } else {
    console.log('  Warning: template files not found at', templateRoot);
    console.log('  Clone the full repo instead: git clone https://github.com/rpatino-cw/cw-secure-template');
  }

  // Create team.json with current user as lead
  const username = process.env.USER || process.env.USERNAME || 'lead';
  const today = new Date().toISOString().split('T')[0];
  const teamJson = {
    version: 1,
    members: {
      [username]: {
        room: stack === 'go' ? 'go-dev' : 'py-dev',
        tier: 'lead',
        joined: today
      }
    }
  };
  fs.writeFileSync(path.join(dest, 'team.json'), JSON.stringify(teamJson, null, 2) + '\n');
  console.log('  Created team.json (you\'re the lead)');

  // Set enforcement profile
  fs.writeFileSync(path.join(dest, '.enforcement-profile'), profile + '\n');
  console.log(`  Set profile: ${profile}`);

  // Set stack lock if not "both"
  if (stack !== 'both') {
    fs.writeFileSync(path.join(dest, '.stack'), stack + '\n');
    console.log(`  Stack locked to: ${stack}`);
  }

  console.log('');
  console.log('  Done. Run:');
  console.log('    make help     — see available commands');
  console.log('    make join     — add team members');
  console.log('    make start    — run your app');
  console.log('');
}

// Parse arguments
const rawArgs = process.argv.slice(2);
const command = rawArgs[0];

if (command === 'init') {
  const flags = {};
  for (let i = 1; i < rawArgs.length; i += 2) {
    const key = rawArgs[i].replace(/^--/, '');
    flags[key] = rawArgs[i + 1];
  }
  init(flags).catch(err => {
    console.error('  Error:', err.message);
    process.exit(1);
  });
} else {
  console.log('');
  console.log('  vibe-arch — Team Vibe Coding Framework');
  console.log('');
  console.log('  Commands:');
  console.log('    vibe-arch init                    Interactive setup');
  console.log('    vibe-arch init --name my-app      With flags');
  console.log('');
  console.log('  Options:');
  console.log('    --name       Project name');
  console.log('    --stack      python | go | both');
  console.log('    --profile    hackathon | balanced | strict | production');
  console.log('');
}
