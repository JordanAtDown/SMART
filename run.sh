#!/usr/bin/env bash
# Lance SMART en activant automatiquement le venv installe par install.sh.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/.venv/bin/activate"
cd "$ROOT_DIR/src"
exec python main.py "$@"
