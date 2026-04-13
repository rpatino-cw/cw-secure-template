# Architecture

Visual diagrams of how the CW Secure Template works. All diagrams render natively on GitHub.

---

## The 6-Layer Pipeline

How your code flows from editor to production.

```mermaid
flowchart LR
    A["Your Code\n+ Claude"] --> B["CLAUDE.md\n15 rules"]
    B --> C["Pre-commit\nSecrets + lint"]
    C --> D["Pre-push\nTests"]
    D --> E["CI Pipeline\nCodeQL + 80%"]
    E --> F["PR Review\nChecklist"]
    F --> G["Deploy\nHelm + Okta"]

    style A fill:#ede9fe,stroke:#8b5cf6,color:#1e1b2e
    style B fill:#fef9c3,stroke:#f59e0b,color:#1e1b2e
    style C fill:#d1fae5,stroke:#10b981,color:#1e1b2e
    style D fill:#d1fae5,stroke:#10b981,color:#1e1b2e
    style E fill:#dbeafe,stroke:#3b82f6,color:#1e1b2e
    style F fill:#fce7f3,stroke:#ec4899,color:#1e1b2e
    style G fill:#e0e7ff,stroke:#6366f1,color:#1e1b2e
```

---

## What Each Layer Catches

```mermaid
flowchart TD
    subgraph CLAUDE["CLAUDE.md + settings.json"]
        C1[Hardcoded secrets]
        C2[Missing auth]
        C3[eval/exec/pickle]
        C4[SQL injection]
        C5[Force-push blocked]
    end

    subgraph HOOKS["Pre-commit + Pre-push"]
        H1[Gitleaks: leaked keys]
        H2[Bandit: Python vulns]
        H3[Ruff: style issues]
        H4[Tests must pass]
    end

    subgraph CI["CI Pipeline"]
        I1[CodeQL deep analysis]
        I2[80% coverage gate]
        I3[Hook integrity check]
        I4[Middleware presence]
        I5[SBOM generation]
    end

    subgraph DEPLOY["Deploy"]
        D1[Non-root container]
        D2[Network policy]
        D3[Secrets from Doppler]
        D4[Health probes]
    end

    CLAUDE -->|escapes| HOOKS
    HOOKS -->|escapes| CI
    CI -->|escapes| DEPLOY

    style CLAUDE fill:#fef9c3,stroke:#f59e0b
    style HOOKS fill:#d1fae5,stroke:#10b981
    style CI fill:#dbeafe,stroke:#3b82f6
    style DEPLOY fill:#e0e7ff,stroke:#6366f1
```

---

## Authentication Flow

How Okta OIDC works in this template.

```mermaid
sequenceDiagram
    participant User
    participant App
    participant Okta
    participant JWKS

    User->>App: GET /api/data
    App->>App: Extract Bearer token from header

    alt DEV_MODE=true
        App->>App: Inject fake test user
        App-->>User: 200 + data
    else Production
        App->>JWKS: Fetch public keys (cached 1hr)
        JWKS-->>App: RSA public keys
        App->>App: Verify JWT signature + expiry + issuer + audience
        App->>App: Extract user claims + groups

        alt Valid token + authorized group
            App-->>User: 200 + data
        else Invalid token
            App-->>User: 401 Unauthorized
        else Wrong group
            App-->>User: 403 Forbidden
        end
    end
```

---

## Secret Flow

How secrets move from developer to production without touching code.

```mermaid
flowchart LR
    DEV["Developer\ngets API key"] --> ADD["make add-secret\n(hidden input)"]
    ADD --> ENV[".env file\n(gitignored)"]
    ENV --> CODE["Code reads\nos.environ['KEY']"]

    DEV2["Ops team"] --> DOP["Doppler\n(web UI)"]
    DOP --> ESO["External Secrets\nOperator"]
    ESO --> K8S["K8s Secret"]
    K8S --> POD["Pod reads\nos.environ['KEY']"]

    style ADD fill:#d1fae5,stroke:#10b981
    style ENV fill:#fef9c3,stroke:#f59e0b
    style DOP fill:#dbeafe,stroke:#3b82f6
    style ESO fill:#dbeafe,stroke:#3b82f6
    style K8S fill:#e0e7ff,stroke:#6366f1
```

---

## Middleware Stack (Python)

Order matters. First registered = outermost = runs first on request.

```mermaid
flowchart TD
    REQ["Incoming Request"] --> RID["Request ID\n(assigns trace UUID)"]
    RID --> SIZE["Request Size\n(rejects > 1MB)"]
    SIZE --> RATE["Rate Limit\n(100/min per IP)"]
    RATE --> HOST["Trusted Host\n(rejects unknown hosts)"]
    HOST --> CORS["CORS\n(rejects unknown origins)"]
    CORS --> HEADERS["Security Headers\n(nosniff, DENY, CSP, HSTS)"]
    HEADERS --> AUTH["Auth Dependency\n(validates JWT)"]
    AUTH --> HANDLER["Your Handler"]
    HANDLER --> RES["Response\n(+ X-Request-ID header)"]

    style RID fill:#dbeafe,stroke:#3b82f6
    style SIZE fill:#fce7f3,stroke:#ec4899
    style RATE fill:#fef9c3,stroke:#f59e0b
    style AUTH fill:#d1fae5,stroke:#10b981
    style HEADERS fill:#e0e7ff,stroke:#6366f1
```

---

## `.claude/` Folder Structure

How Claude Code reads project configuration.

```mermaid
flowchart TD
    SESSION["Claude Code Session"] --> LOAD["Loads project config"]
    LOAD --> CM["CLAUDE.md\n15 security rules"]
    LOAD --> SETTINGS[".claude/settings.json\nPermissions: allow/deny/ask"]
    LOAD --> RULES[".claude/rules/\n4 files, glob-matched"]
    LOAD --> MEMORY[".claude/MEMORY.md\nProject context"]

    SETTINGS --> DENY["DENIED:\nforce-push, --no-verify,\neval, rm -rf"]

    USER["User types prompt"] --> RULES
    USER --> CM
    USER --> CMD{Slash command?}

    CMD -->|/project:check| CHECK[".claude/commands/check.md"]
    CMD -->|/project:add-endpoint| ENDPOINT[".claude/commands/add-endpoint.md"]
    CMD -->|/project:security-review| REVIEW[".claude/commands/security-review.md"]
    CMD -->|Code change| SKILL[".claude/skills/security-review/\nAuto-triggers"]

    REVIEW -.->|Can spawn| AGENT1[".claude/agents/\nsecurity-auditor.md"]
    CHECK -.->|Can spawn| AGENT2[".claude/agents/\ncode-reviewer.md"]

    style CM fill:#fef9c3,stroke:#f59e0b
    style SETTINGS fill:#fce7f3,stroke:#ec4899
    style DENY fill:#fee2e2,stroke:#f87171
    style RULES fill:#dbeafe,stroke:#3b82f6
    style SKILL fill:#d1fae5,stroke:#10b981
```

---

## Deployment Architecture

How the app runs in production on CW infrastructure.

```mermaid
flowchart TD
    GH["GitHub\n(CW org repo)"] -->|push to main| ARGO["ArgoCD\n(auto-sync)"]
    ARGO --> HELM["Helm Chart\n(deploy/helm/)"]
    HELM --> NS["K8s Namespace\n(core-internal)"]

    subgraph NS["core-internal cluster"]
        SVC["Service\n(ClusterIP)"]
        DEP["Deployment\n(3 replicas)"]
        SA["ServiceAccount\n(no auto-mount)"]
        NP["NetworkPolicy\n(default-deny)"]
        ES["ExternalSecret\n(Doppler → K8s)"]
        PDB["PDB\n(minAvailable: 1)"]

        DEP --> POD1["Pod 1\n(non-root, read-only FS)"]
        DEP --> POD2["Pod 2"]
        DEP --> POD3["Pod 3"]
    end

    TRAEFIK["Traefik\n(internal ingress)"] --> SVC
    BLAST["BlastShield\n+ Okta OIDC"] --> TRAEFIK
    DOPPLER["Doppler"] --> ES

    style ARGO fill:#dbeafe,stroke:#3b82f6
    style BLAST fill:#fef9c3,stroke:#f59e0b
    style DOPPLER fill:#d1fae5,stroke:#10b981
    style NP fill:#fce7f3,stroke:#ec4899
```

---

## "Can't Break It" — Escape Route Map

Every bypass attempt and what catches it.

```mermaid
flowchart LR
    A1["Skip hooks\n--no-verify"] -->|caught by| B1["CI timestamp check"]
    A2["Delete CLAUDE.md"] -->|caught by| B2["CI hook-integrity"]
    A3["Remove rate limiter"] -->|caught by| B3["CI middleware check"]
    A4["Hardcode secret"] -->|caught by| B4["Gitleaks\n(hook + CI)"]
    A5["Push without tests"] -->|caught by| B5["Pre-push hook"]
    A6["Commit to main"] -->|caught by| B6["Branch protection"]
    A7["Force push"] -->|caught by| B7["settings.json\ndeny list"]
    A8["Ask Claude to\nbypass rules"] -->|caught by| B8["CLAUDE.md\nanti-jailbreak"]

    style A1 fill:#fee2e2,stroke:#f87171
    style A2 fill:#fee2e2,stroke:#f87171
    style A3 fill:#fee2e2,stroke:#f87171
    style A4 fill:#fee2e2,stroke:#f87171
    style A5 fill:#fee2e2,stroke:#f87171
    style A6 fill:#fee2e2,stroke:#f87171
    style A7 fill:#fee2e2,stroke:#f87171
    style A8 fill:#fee2e2,stroke:#f87171
    style B1 fill:#d1fae5,stroke:#10b981
    style B2 fill:#d1fae5,stroke:#10b981
    style B3 fill:#d1fae5,stroke:#10b981
    style B4 fill:#d1fae5,stroke:#10b981
    style B5 fill:#d1fae5,stroke:#10b981
    style B6 fill:#d1fae5,stroke:#10b981
    style B7 fill:#d1fae5,stroke:#10b981
    style B8 fill:#d1fae5,stroke:#10b981
```
