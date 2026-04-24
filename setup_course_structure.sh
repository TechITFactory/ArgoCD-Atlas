#!/usr/bin/env bash
# =============================================================================
# setup_course_structure.sh
# ArgoCD "Zero to Production" v2.0 — Course Structure Setup
# =============================================================================
set -euo pipefail

# ── Resolve script location so it works from any CWD ─────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"
MODULES_DIR="$ROOT_DIR/modules"

echo "==> Root directory : $ROOT_DIR"
echo "==> Modules directory: $MODULES_DIR"

# =============================================================================
# 1. CREATE module directories
# =============================================================================
MODULES=(
  "module-00-setup"
  "module-01-foundations"
  "module-02-app-sources"
  "module-03-sync-policies"
  "module-04-diff-drift"
  "module-05-security-rbac"
  "module-06-applicationsets"
  "module-07-secrets"
  "module-08-ci-integration"
  "module-09-notifications"
  "module-10-observability"
  "module-11-ha-dr"
  "module-12-capstone"
)

echo ""
echo "==> [1/4] Creating module directories..."
mkdir -p "$MODULES_DIR"
for mod in "${MODULES[@]}"; do
  mkdir -p "$MODULES_DIR/$mod"
  echo "    created: modules/$mod"
done

# =============================================================================
# 2. MOVE existing content based on filename keywords
# =============================================================================
echo ""
echo "==> [2/4] Moving existing files by keyword..."

declare -A KEYWORD_MAP=(
  ["setup"]="module-00-setup"
  ["foundation"]="module-01-foundations"
  ["architecture"]="module-01-foundations"
  ["install"]="module-01-foundations"
  ["crd"]="module-01-foundations"
  ["ingress"]="module-01-foundations"
  ["cli"]="module-01-foundations"
  ["helm"]="module-02-app-sources"
  ["kustomize"]="module-02-app-sources"
  ["monorepo"]="module-02-app-sources"
  ["plugin"]="module-02-app-sources"
  ["git-auth"]="module-02-app-sources"
  ["sync"]="module-03-sync-policies"
  ["hook"]="module-03-sync-policies"
  ["wave"]="module-03-sync-policies"
  ["phase"]="module-03-sync-policies"
  ["diff"]="module-04-diff-drift"
  ["drift"]="module-04-diff-drift"
  ["health"]="module-04-diff-drift"
  ["orphan"]="module-04-diff-drift"
  ["rbac"]="module-05-security-rbac"
  ["sso"]="module-05-security-rbac"
  ["security"]="module-05-security-rbac"
  ["project"]="module-05-security-rbac"
  ["appset"]="module-06-applicationsets"
  ["applicationset"]="module-06-applicationsets"
  ["generator"]="module-06-applicationsets"
  ["progressive"]="module-06-applicationsets"
  ["secret"]="module-07-secrets"
  ["sealed"]="module-07-secrets"
  ["vault"]="module-07-secrets"
  ["external-secret"]="module-07-secrets"
  ["ci"]="module-08-ci-integration"
  ["image-updater"]="module-08-ci-integration"
  ["writeback"]="module-08-ci-integration"
  ["notification"]="module-09-notifications"
  ["chatops"]="module-09-notifications"
  ["slack"]="module-09-notifications"
  ["prometheus"]="module-10-observability"
  ["grafana"]="module-10-observability"
  ["observ"]="module-10-observability"
  ["log"]="module-10-observability"
  ["debug"]="module-10-observability"
  ["ha"]="module-11-ha-dr"
  ["disaster"]="module-11-ha-dr"
  ["recovery"]="module-11-ha-dr"
  ["upgrade"]="module-11-ha-dr"
  ["scaling"]="module-11-ha-dr"
  ["capstone"]="module-12-capstone"
  ["review"]="module-12-capstone"
)

move_count=0
# Search for .md, .yaml, .yml, .sh, .json files in root (non-recursive, skip modules/)
while IFS= read -r -d '' file; do
  filename="$(basename "$file")"
  lower="${filename,,}"   # lowercase
  target_mod=""

  for keyword in "${!KEYWORD_MAP[@]}"; do
    if [[ "$lower" == *"$keyword"* ]]; then
      target_mod="${KEYWORD_MAP[$keyword]}"
      break
    fi
  done

  if [[ -n "$target_mod" ]]; then
    dest="$MODULES_DIR/$target_mod/$filename"
    if [[ ! -e "$dest" ]]; then
      mv "$file" "$dest"
      echo "    moved: $filename  →  modules/$target_mod/"
      ((move_count++)) || true
    else
      echo "    skip (exists): $filename  →  modules/$target_mod/"
    fi
  fi
done < <(find "$ROOT_DIR" -maxdepth 1 -type f \
  \( -name "*.md" -o -name "*.yaml" -o -name "*.yml" -o -name "*.sh" -o -name "*.json" \) \
  ! -name "COURSE-INDEX.md" \
  ! -name "setup_course_structure.sh" \
  -print0)

echo "    total files moved: $move_count"

# =============================================================================
# 3. CREATE day markdown files (no-overwrite)
# =============================================================================
echo ""
echo "==> [3/4] Creating day markdown files..."

create_day() {
  local mod="$1"
  local file="$2"
  local path="$MODULES_DIR/$mod/$file"
  if [[ ! -f "$path" ]]; then
    # Derive a human-readable title from filename
    title="${file%.md}"             # strip extension
    title="${title//-/ }"           # dashes → spaces
    # Capitalise each word
    title="$(echo "$title" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); print}')"

    cat > "$path" <<EOF
# $title

> **Module:** $mod
> **File:** $file

## Overview

_Add your notes for this day here._

## Key Concepts

-

## Lab / Exercise

_Steps go here._

## References

-
EOF
    echo "    created: modules/$mod/$file"
  else
    echo "    exists : modules/$mod/$file  (skipped)"
  fi
}

# module-00-setup
create_day "module-00-setup"         "day-00-lab-setup.md"

# module-01-foundations
create_day "module-01-foundations"   "day-01-architecture.md"
create_day "module-01-foundations"   "day-02-install-ui.md"
create_day "module-01-foundations"   "day-03-core-crds.md"
create_day "module-01-foundations"   "day-04-config-management.md"
create_day "module-01-foundations"   "day-05-secure-access-ingress.md"
create_day "module-01-foundations"   "day-06-cli-mastery.md"

# module-02-app-sources
create_day "module-02-app-sources"   "day-07-git-auth-private.md"
create_day "module-02-app-sources"   "day-08-directory-monorepo.md"
create_day "module-02-app-sources"   "day-09-helm-integration.md"
create_day "module-02-app-sources"   "day-10-kustomize-overlays.md"
create_day "module-02-app-sources"   "day-11-plugins-tooling.md"

# module-03-sync-policies
create_day "module-03-sync-policies" "day-12-manual-auto-sync.md"
create_day "module-03-sync-policies" "day-13-sync-options.md"
create_day "module-03-sync-policies" "day-14-phases-waves.md"
create_day "module-03-sync-policies" "day-15-hooks.md"
create_day "module-03-sync-policies" "day-16-sync-windows.md"

# module-04-diff-drift
create_day "module-04-diff-drift"    "day-17-drift-detection.md"
create_day "module-04-diff-drift"    "day-18-diff-strategies.md"
create_day "module-04-diff-drift"    "day-19-diff-ignore.md"
create_day "module-04-diff-drift"    "day-20-health-orphans.md"

# module-05-security-rbac
create_day "module-05-security-rbac" "day-21-sso-concepts.md"
create_day "module-05-security-rbac" "day-22-sso-setup.md"
create_day "module-05-security-rbac" "day-23-rbac-policy.md"
create_day "module-05-security-rbac" "day-24-project-isolation.md"

# module-06-applicationsets
create_day "module-06-applicationsets" "day-25-appset-theory.md"
create_day "module-06-applicationsets" "day-26-list-git-generators.md"
create_day "module-06-applicationsets" "day-27-cluster-generator.md"
create_day "module-06-applicationsets" "day-28-progressive-sync.md"

# module-07-secrets
create_day "module-07-secrets"       "day-29-secrets-intro.md"
create_day "module-07-secrets"       "day-30-sealed-secrets.md"
create_day "module-07-secrets"       "day-31-external-secrets.md"

# module-08-ci-integration
create_day "module-08-ci-integration" "day-32-ci-handover.md"
create_day "module-08-ci-integration" "day-33-image-updater.md"
create_day "module-08-ci-integration" "day-34-git-writeback.md"

# module-09-notifications
create_day "module-09-notifications" "day-35-notifications.md"
create_day "module-09-notifications" "day-36-chatops.md"

# module-10-observability
create_day "module-10-observability" "day-37-prometheus-metrics.md"
create_day "module-10-observability" "day-38-grafana.md"
create_day "module-10-observability" "day-39-logs-debugging.md"

# module-11-ha-dr
create_day "module-11-ha-dr"         "day-40-ha-scaling.md"
create_day "module-11-ha-dr"         "day-41-disaster-recovery.md"
create_day "module-11-ha-dr"         "day-42-upgrades.md"

# module-12-capstone
create_day "module-12-capstone"      "day-43-design.md"
create_day "module-12-capstone"      "day-44-implementation.md"
create_day "module-12-capstone"      "day-45-review.md"

# =============================================================================
# 4. CREATE COURSE-INDEX.md
# =============================================================================
echo ""
echo "==> [4/4] Creating COURSE-INDEX.md..."

COURSE_INDEX="$ROOT_DIR/COURSE-INDEX.md"

if [[ ! -f "$COURSE_INDEX" ]]; then
cat > "$COURSE_INDEX" <<'MARKDOWN'
# ArgoCD — Zero to Production (v2.0)
## Full Course Syllabus

> **Duration:** 46 days (Day 00 – Day 45)
> **Goal:** Take an engineer from zero ArgoCD knowledge to confidently running
> production-grade GitOps pipelines.

---

## Module 00 — Lab Setup (1 day)

| Day | Topic |
|-----|-------|
| 00  | Lab setup — local cluster, ArgoCD install, tooling |

---

## Module 01 — Foundations (6 days)

| Day | Topic |
|-----|-------|
| 01  | ArgoCD architecture deep-dive |
| 02  | Install & UI walkthrough |
| 03  | Core CRDs (Application, AppProject) |
| 04  | Config management overview |
| 05  | Secure access & Ingress |
| 06  | CLI mastery (`argocd` command reference) |

---

## Module 02 — App Sources (5 days)

| Day | Topic |
|-----|-------|
| 07  | Git auth & private repos |
| 08  | Directory sources & monorepo patterns |
| 09  | Helm integration |
| 10  | Kustomize overlays |
| 11  | Plugins & custom tooling (CMP) |

---

## Module 03 — Sync Policies (5 days)

| Day | Topic |
|-----|-------|
| 12  | Manual vs automated sync |
| 13  | Sync options (prune, self-heal, replace) |
| 14  | Sync phases & waves |
| 15  | Resource hooks (PreSync, Sync, PostSync, SyncFail) |
| 16  | Sync windows |

---

## Module 04 — Diff & Drift (4 days)

| Day | Topic |
|-----|-------|
| 17  | Drift detection mechanics |
| 18  | Diff strategies |
| 19  | Ignoring diffs (ignoreDifferences) |
| 20  | Health checks & orphaned resources |

---

## Module 05 — Security & RBAC (4 days)

| Day | Topic |
|-----|-------|
| 21  | SSO concepts (OIDC, SAML) |
| 22  | SSO setup (Dex / external providers) |
| 23  | RBAC policy (roles, groups, permissions) |
| 24  | AppProject isolation & resource whitelists |

---

## Module 06 — ApplicationSets (4 days)

| Day | Topic |
|-----|-------|
| 25  | ApplicationSet theory & controller |
| 26  | List & Git generators |
| 27  | Cluster generator & multi-cluster patterns |
| 28  | Progressive sync strategies (RolloutSteps) |

---

## Module 07 — Secrets (3 days)

| Day | Topic |
|-----|-------|
| 29  | Secrets in GitOps — intro & anti-patterns |
| 30  | Sealed Secrets |
| 31  | External Secrets Operator (ESO) |

---

## Module 08 — CI Integration (3 days)

| Day | Topic |
|-----|-------|
| 32  | CI → CD handover patterns |
| 33  | ArgoCD Image Updater |
| 34  | Git write-back strategy |

---

## Module 09 — Notifications (2 days)

| Day | Topic |
|-----|-------|
| 35  | ArgoCD Notifications — triggers & templates |
| 36  | ChatOps integration (Slack, Teams, PagerDuty) |

---

## Module 10 — Observability (3 days)

| Day | Topic |
|-----|-------|
| 37  | Prometheus metrics & alerting |
| 38  | Grafana dashboards |
| 39  | Logs & debugging techniques |

---

## Module 11 — HA & Disaster Recovery (3 days)

| Day | Topic |
|-----|-------|
| 40  | High-availability setup & horizontal scaling |
| 41  | Disaster recovery & backup strategies |
| 42  | ArgoCD upgrades & maintenance |

---

## Module 12 — Capstone (3 days)

| Day | Topic |
|-----|-------|
| 43  | Design — plan a production GitOps platform |
| 44  | Implementation — build & deploy |
| 45  | Review — peer review, retrospective, next steps |

---

## Directory Structure

```
modules/
├── module-00-setup           (Day 00)
├── module-01-foundations     (Days 01–06)
├── module-02-app-sources     (Days 07–11)
├── module-03-sync-policies   (Days 12–16)
├── module-04-diff-drift      (Days 17–20)
├── module-05-security-rbac   (Days 21–24)
├── module-06-applicationsets (Days 25–28)
├── module-07-secrets         (Days 29–31)
├── module-08-ci-integration  (Days 32–34)
├── module-09-notifications   (Days 35–36)
├── module-10-observability   (Days 37–39)
├── module-11-ha-dr           (Days 40–42)
└── module-12-capstone        (Days 43–45)
```

---

*Generated by `setup_course_structure.sh` — ArgoCD Zero to Production v2.0*
MARKDOWN
  echo "    created: COURSE-INDEX.md"
else
  echo "    exists : COURSE-INDEX.md  (skipped)"
fi

# =============================================================================
# Done
# =============================================================================
echo ""
echo "============================================================"
echo " Course structure setup complete!"
echo " Run: tree modules/  to verify the layout."
echo "============================================================"
