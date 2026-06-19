#!/bin/bash
################################################################################
# Hermes Portable - Linux Installer
# ONE-TIME setup: downloads Node.js, uv, cloudflared, builds 9router,
# installs Hermes + MCPs, generates config
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
NC='\033[0m' # No Color

log_header() { echo -e "\n${CYAN}=============================================${NC}"; echo -e "${CYAN} $1${NC}"; echo -e "${CYAN}=============================================${NC}"; }
log_step() { echo -e "${CYAN}==> $1${NC}"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_err() { echo -e "${RED}[X]${NC} $1"; }

log_header "Hermes Portable Installer (Linux)"

# Check if already installed
if [ -f "$INSTALLED_FLAG" ] && [ "$1" != "-Force" ]; then
    log_ok "Bundle already installed (found data/.installed)"
    echo "    Run: bash start.sh to launch"
    echo "    Or: pass -Force to reinstall"
    exit 0
fi

# Pre-flight
log_header "Step 1/6: Pre-flight checks"
log_step "Checking dependencies..."

for cmd in curl unzip python3; do
  if ! command -v "$cmd" &> /dev/null; then
    log_err "$cmd not found. Install with:"
    case "$cmd" in
      curl)
        echo "    Ubuntu/Debian: sudo apt-get install curl"
        echo "    CentOS/RHEL: sudo yum install curl"
        echo "    macOS: brew install curl"
        ;;
      unzip)
        echo "    Ubuntu/Debian: sudo apt-get install unzip"
        echo "    CentOS/RHEL: sudo yum install unzip"
        echo "    macOS: brew install unzip"
        ;;
      python3)
        echo "    Ubuntu/Debian: sudo apt-get install python3 python3-pip"
        echo "    CentOS/RHEL: sudo yum install python3 python3-pip"
        echo "    macOS: brew install python3"
        ;;
    esac
    exit 1
  fi
done
log_ok "Dependencies OK"

# Create directories
mkdir -p "$DATA_DIR" "$RUNTIME_DIR" "$NODE_DIR" "$BIN_DIR"

# Step 2: Download runtimes
log_header "Step 2/6: Download runtimes (Node.js, cloudflared)"
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
log_ok "Python venv ready: $DATA_DIR/.venv"

# Step 4: Build 9router
log_header "Step 4/6: Build 9router"
if [ ! -d "$ROUTER9_DIR" ]; then
  log_warn "9router source not found at $ROUTER9_DIR"
  log_warn "Copy 9router-master into services/9router/ before installing"
else
  cd "$ROUTER9_DIR"
  log_step "9router: npm install (this may take a few minutes)..."
  NODE_OPTIONS="--max-old-space-size=2048" npm install
  log_step "9router: npm run build..."
  NODE_ENV=production npm run build
  log_ok "9router built"
  cd "$BUNDLE_ROOT"
fi

# Step 5: Install Hermes
log_header "Step 5/6: Install Hermes + MCPs"
if [ ! -d "$HERMES_DIR" ]; then
  log_warn "Hermes source not found at $HERMES_DIR"
  log_warn "Copy hermes core into services/hermes/ before installing"
else
  log_step "Installing Hermes with [portable-windows] + [portable-android] extras..."
  cd "$HERMES_DIR"
  $UV_BIN pip install --python "$DATA_DIR/.venv" -e ".[portable-windows]" -e ".[portable-android]"
  log_ok "Hermes + MCPs installed"
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
