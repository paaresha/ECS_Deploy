#!/usr/bin/env bash

# ─────────────────────────────────────────────────────────────────────────────
# setup.sh – One-time local bootstrap:
#   1. Verify tool versions
#   2. Create Python venv + install deps
#   3. Build Docker image locally
#   4. Run tests
#   5. (Optional) Initialize Terraform
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log()  { echo "$(date -u '+%H:%M:%S') [INFO]  $*"; }
ok()   { echo "$(date -u '+%H:%M:%S') [OK]    $*"; }
err()  { echo "$(date -u '+%H:%M:%S') [ERROR] $*" >&2; exit 1; }
sep()  { echo; printf '─%.0s' {1..60}; echo; }

# ── 1. Check tool versions ────────────────────────────────────────────────────
sep; log "Checking prerequisites …"

check_tool() {
  local cmd="$1" min_ver="$2"
  if command -v "$cmd" &>/dev/null; then
    ok "$cmd found: $(${cmd} --version 2>&1 | head -1)"
  else
    err "$cmd not found. Minimum required: $min_ver"
  fi
}

check_tool python3   "3.10"
check_tool pip       "22"
check_tool docker    "24"
check_tool aws       "2"
check_tool terraform "1.8"
check_tool jq        "1.6"

# ── 2. Python virtual environment ─────────────────────────────────────────────
sep; log "Setting up Python virtual environment …"

cd "$ROOT"
if [[ ! -d ".venv" ]]; then
  python3 -m venv .venv
fi

# shellcheck disable=SC1091
source .venv/bin/activate
pip install --quiet --upgrade pip
pip install --quiet -r app/src/requirements.txt
pip install --quiet -r app/tests/requirements-test.txt
ok "Python dependencies installed"

# ── 3. Run tests ──────────────────────────────────────────────────────────────
sep; log "Running test suite …"
pytest --tb=short -q
ok "All tests passed"

# ── 4. Build Docker image ─────────────────────────────────────────────────────
sep; log "Building Docker image …"
docker build \
  --build-arg APP_VERSION="local-$(git rev-parse --short HEAD 2>/dev/null || echo 'dev')" \
  --build-arg GIT_COMMIT="$(git rev-parse HEAD 2>/dev/null || echo 'unknown')" \
  --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  -t cicd-demo-api:local \
  .
ok "Docker image built: cicd-demo-api:local"

# ── 5. Run container health check ─────────────────────────────────────────────
sep; log "Starting container and running health check …"
CID=$(docker run -d --rm -p 18080:8080 -e ENVIRONMENT=local cicd-demo-api:local)
sleep 5

HTTP_STATUS=$(curl -sf -o /dev/null -w "%{http_code}" http://localhost:18080/health || echo "000")
docker stop "$CID" 2>/dev/null || true

if [[ "$HTTP_STATUS" == "200" ]]; then
  ok "Container health check passed (HTTP $HTTP_STATUS)"
else
  err "Container health check FAILED (HTTP $HTTP_STATUS)"
fi

# ── 6. Terraform init (optional) ──────────────────────────────────────────────
if [[ "${INIT_TERRAFORM:-false}" == "true" ]]; then
  sep; log "Initializing Terraform (dev) …"
  cd "$ROOT/terraform/environments/dev"
  terraform init -backend=false
  terraform validate
  ok "Terraform validated"
fi

sep
ok "✅ Setup complete! You are ready to push to GitHub."
log "Next steps:"
log "  1. Add GitHub Secrets (see README.md § Secrets)"
log "  2. git push origin develop   → triggers dev pipeline"
log "  3. git push origin main      → triggers prod pipeline"
