#!/bin/bash
################################################################################
# Hermes Portable - macOS Installer
# Same as Linux but optimized for Homebrew + macOS-specific paths
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_ROOT="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$BUNDLE_ROOT/data"
RUNTIME_DIR="$BUNDLE_ROOT/runtime"
NODE_DIR="$RUNTIME_DIR/node"
BIN_DIR="$RUNTIME_DIR/bin"
SERVICES_DIR="$BUNDLE_ROOT/services"
ROUTER9_DIR="$SERVICES_DIR/9router"
HERMES_DIR="$SERVICES_DIR/hermes"
INSTALLED_FLAG="$DATA_DIR/.installed"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_header() { echo ""; echo -e "${CYAN}=============================================${NC}"; echo -e "${CYAN} $1${NC}"; echo -e "${CYAN}=============================================${NC}"; }
log_step() { echo -e "${CYAN}==> $1${NC}"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_err() { echo -e "${RED}[X]${NC} $1"; }

log_header "Hermes Portable Installer (macOS)"

# Check if already installed
if [ -f "$INSTALLED_FLAG" ] && [ "$1" != "-Force" ]; then
    log_ok "Bundle already installed (found data/.installed)"
    echo "    Run: bash start.sh to launch"
    echo "    Or: pass -Force to reinstall"
    exit 0
fi

# Pre-flight
log_header "Step 1/6: Pre-flight checks (macOS)"
log_step "Checking Homebrew..."

if ! command -v brew &> /dev/null; then
    log_warn "Homebrew not installed"
    echo "    Install from: https://brew.sh"
    exit 1
fi

log_step "Installing dependencies via Homebrew..."
for pkg in node unzip python3; do
  if ! brew list "$pkg" &>/dev/null; then
    log_step "Installing $pkg..."
    brew install "$pkg"
  fi
done
log_ok "Dependencies ready"

# Create directories
mkdir -p "$DATA_DIR" "$RUNTIME_DIR" "$NODE_DIR" "$BIN_DIR"

# Step 2: Download runtimes (macOS-specific)
log_header "Step 2/6: Download runtimes (cloudflared for macOS)"
bash "$SCRIPT_DIR/download-runtimes.sh"

# Step 3: Install uv + Python venv
log_header "Step 3/6: Python environment (uv)"
log_step "Installing uv..."
pip3 install --user uv 2>/dev/null || pip install --user uv
UV_BIN=$(python3 -m site --user-base)/bin/uv
export PATH="$UV_BIN:$PATH"
log_ok "uv installed"

log_step "Creating Python venv..."
export UV_PYTHON_INSTALL_DIR="$DATA_DIR/.python"
export UV_CACHE_DIR="$DATA_DIR/.uv_cache"
export UV_PROJECT_ENVIRONMENT="$DATA_DIR/.venv"
$UV_BIN venv "$DATA_DIR/.venv" --python 3.11
log_ok "Python venv ready"

# Step 4: Build 9router (use system Node from Homebrew)
log_header "Step 4/6: Build 9router"
if [ ! -d "$ROUTER9_DIR" ]; then
  log_warn "9router source not found at $ROUTER9_DIR"
else
  cd "$ROUTER9_DIR"
  log_step "9router: npm install..."
  NODE_OPTIONS="--max-old-space-size=2048" npm install
  log_step "9router: npm run build..."
  NODE_ENV=production npm run build
  log_ok "9router built"
  cd "$BUNDLE_ROOT"
fi

# Step 5: Install Hermes + MCPs (macOS-aware: includes macOS-MCP)
log_header "Step 5/6: Install Hermes + MCPs"
if [ ! -d "$HERMES_DIR" ]; then
  log_warn "Hermes source not found at $HERMES_DIR"
else
  log_step "Installing Hermes with [portable-windows] + [portable-android] + [portable-macos]..."
  cd "$HERMES_DIR"
  # macOS can install all extras; platform markers will filter out Windows-only deps
  $UV_BIN pip install --python "$DATA_DIR/.venv" -e ".[portable-windows]" -e ".[portable-android]" -e ".[portable-macos]"
  log_ok "Hermes + all MCPs installed"
  cd "$BUNDLE_ROOT"
fi

# Step 6: Setup wizard
log_header "Step 6/6: Configuration"
SETUP_SCRIPT="$BUNDLE_ROOT/setup-portable.sh"
if [ -f "$SETUP_SCRIPT" ]; then
  log_step "Running setup wizard..."
  chmod +x "$SETUP_SCRIPT"
  "$SETUP_SCRIPT" Interactive
else
  log_warn "Setup wizard not found"
fi

# Mark installed
mkdir -p "$DATA_DIR"
cat > "$INSTALLED_FLAG" << EOF
{
  "installed_at": "$(date -u +'%Y-%m-%d %H:%M:%S')",
  "os": "$(uname -s)",
  "arch": "$(uname -m)",
  "bundle_root": "$BUNDLE_ROOT"
}
EOF

log_header "Installation Complete!"
echo ""
log_ok "Ready! Run: bash start.sh"
echo ""
